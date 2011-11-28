/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "config.h"

#include <sys/param.h>
#include <sys/stat.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <wired/wired.h>

#include "accounts.h"
#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "transfers.h"

#define WD_FILES_COMMENT_FIELD_SEPARATOR	"\34"
#define WD_FILES_COMMENT_SEPARATOR			"\35"


enum _wd_files_fts_action {
	WD_FILES_FTS_KEEP,
	WD_FILES_FTS_IGNORE,
	WD_FILES_FTS_SKIP,
	WD_FILES_FTS_ERROR
};
typedef enum _wd_files_fts_action			wd_files_fts_action_t;


static wi_file_offset_t						wd_files_count_path(wi_string_t *);

static void									wd_files_move_thread(wi_runtime_instance_t *);

static void									wd_files_search_index(wi_string_t *);
static void									wd_files_search_live(wi_string_t *, wi_string_t *query, const char *);

static void									wd_files_update_index(wi_timer_t *);
static void									wd_files_index_thread(wi_runtime_instance_t *);
static void									wd_files_index_path(wi_string_t *, wi_file_t *, const char *);

static wd_file_type_t						wd_files_type_with_stat(wi_string_t *path, struct stat *sbp);

static void									wd_files_clear_comment(wi_string_t *);
static wi_boolean_t							wd_files_read_comment(wi_file_t *, wi_string_t **, wi_string_t **);

static WI_FTS *								wd_files_fts_open(wi_string_t *);
static WI_FTS *								wd_files_fts_open_sorted(wi_string_t *);
static wd_files_fts_action_t				wd_files_fts_action(WI_FTSENT *, int *);
static int									wd_files_fts_namecmp(const WI_FTSENT **, const WI_FTSENT **);


static wi_timer_t							*wd_files_index_timer;
static wi_rwlock_t							*wd_files_index_lock;
static wi_lock_t							*wd_files_indexer_lock;
static unsigned int							wd_files_index_level;
static wi_set_t								*wd_files_index_set;

unsigned int								wd_files_count, wd_files_unique_count;
unsigned int								wd_directories_count, wd_directories_unique_count;
wi_file_offset_t							wd_files_size, wd_files_unique_size;


void wd_init_files(void) {
	wd_files_index_lock = wi_rwlock_init(wi_rwlock_alloc());
	wd_files_indexer_lock = wi_lock_init(wi_lock_alloc());
	
	wd_files_index_timer = wi_timer_init_with_function(wi_timer_alloc(),
													   wd_files_update_index,
													   0.0,
													   true);
}



void wd_config_files(void) {
	if(wd_settings.index && wd_settings.indextime > 0.0)
		wi_timer_reschedule(wd_files_index_timer, wd_settings.indextime);
	else
		wi_timer_invalidate(wd_files_index_timer);
}



#pragma mark -

void wd_files_list_path(wi_string_t *path, wi_boolean_t recursive) {
	wd_client_t				*client = wd_client();
	WI_FTS					*fts = NULL;
	WI_FTSENT				*p;
	wi_string_t				*realpath, *filepath, *virtualpath, *string;
	wi_file_statfs_t		sfb;
	wi_file_offset_t		size, available;
	wd_file_type_t			type, pathtype;
	wd_files_fts_action_t	action;
	struct stat				sb;
	unsigned int			pathlength;
	int						err;
	wi_boolean_t			root, upload;
	
	root = wi_is_equal(path, WI_STR("/"));
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);

	/* check for drop box privileges */
	pathtype = wd_files_type(realpath);
	
	if(!client->account->view_dropboxes) {
		if(pathtype == WD_FILE_TYPE_DROPBOX)
			goto done;
	}

	fts = wd_files_fts_open_sorted(realpath);
	
	if(!fts) {
		wi_log_warn(WI_STR("Could not open %@: %s"),
			realpath, strerror(errno));
		wd_reply_error();

		goto err;
	}
	
	pathlength = wi_string_length(realpath);
	
	if(pathlength == 1)
		pathlength--;
	
	while((p = wi_fts_read(fts))) {
		/* skip item? */
		action = wd_files_fts_action(p, &err);
		
		switch(action) {
			case WD_FILES_FTS_KEEP:
				break;
				
			case WD_FILES_FTS_IGNORE:
				continue;
				break;
				
			case WD_FILES_FTS_SKIP:
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
				break;
			
			case WD_FILES_FTS_ERROR:
				wi_log_warn(WI_STR("Could not list %s: %s"),
					p->fts_path, strerror(err));

				continue;
				break;
		}
		
		/* skip if we're not recursive */
		if(!recursive && p->fts_level > 1) {
			wi_fts_set(fts, p, WI_FTS_SKIP);

			continue;
		}
		
		/* create real path */
		filepath = wi_string_with_cstring(p->fts_path);
		
		/* create virtual path */
		virtualpath = wi_string_substring_from_index(filepath, pathlength);
		
		if(!root)
			wi_string_insert_string_at_index(virtualpath, path, 0);
		
		/* if it's a Mac alias, resolve real path */
		if(wi_file_is_alias_cpath(p->fts_path))
			wi_string_resolve_aliases_in_path(filepath);

		if(!wi_file_stat(filepath, &sb)) {
			if(!wi_file_lstat(filepath, &sb)) {
				wi_log_warn(WI_STR("Could not list %@: %m"), filepath);
				wi_fts_set(fts, p, WI_FTS_SKIP);

				continue;
			}
		}

		/* get file type & size */
		type = wd_files_type_with_stat(filepath, &sb);

		switch(type) {
			case WD_FILE_TYPE_DROPBOX:
				size = 0;
				break;

			case WD_FILE_TYPE_DIR:
			case WD_FILE_TYPE_UPLOADS:
				size = wd_files_count_path(filepath);
				break;

			case WD_FILE_TYPE_FILE:
			default:
				size = sb.st_size;
				break;
		}
		
		/* reply file message */
		string = wi_date_iso8601_string(wi_date_with_time(sb.st_mtime));
		
		wd_reply(410, WI_STR("%#@%c%u%c%llu%c%#@%c%#@"),
				 virtualpath,		WD_FIELD_SEPARATOR,
				 type,				WD_FIELD_SEPARATOR,
				 size,				WD_FIELD_SEPARATOR,
				 string,			WD_FIELD_SEPARATOR,
				 string);
		
		/* check for drop box privileges */
		if(recursive && !client->account->view_dropboxes) {
			if(type == WD_FILE_TYPE_DROPBOX) {
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
			}
		}
	}
	
done:
	/* if client can upload, get amount of free space */
	if(client->account->upload_anywhere)
		upload = true;
	else if(pathtype == WD_FILE_TYPE_DROPBOX || pathtype == WD_FILE_TYPE_UPLOADS)
		upload = client->account->upload;
	else
		upload = false;

	if(upload && wi_file_statfs(realpath, &sfb))
		available = (wi_file_offset_t) sfb.f_bavail * (wi_file_offset_t) sfb.f_frsize;
	else
		available = 0;
	
	wd_reply(411, WI_STR("%#@%c%llu"),
			 path,		WD_FIELD_SEPARATOR,
			 available);

err:
	if(fts)
		wi_fts_close(fts);
}



static wi_file_offset_t wd_files_count_path(wi_string_t *path) {
	WI_FTS					*fts;
	WI_FTSENT				*p;
	wi_file_offset_t		count = 0;
	wd_files_fts_action_t	action;
	int						err;
	
	fts = wd_files_fts_open(path);

	if(!fts) {
		wi_log_warn(WI_STR("Could not open %@: %s"),
			path, strerror(errno));
		wd_reply_error();

		return 0;
	}
	
	while((p = wi_fts_read(fts))) {
		/* skip item? */
		action = wd_files_fts_action(p, &err);
		
		switch(action) {
			case WD_FILES_FTS_KEEP:
				break;
				
			case WD_FILES_FTS_IGNORE:
			case WD_FILES_FTS_ERROR:
				continue;
				break;
				
			case WD_FILES_FTS_SKIP:
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
				break;
		}
		
		/* skip recursion */
		if(p->fts_level > 1) {
			wi_fts_set(fts, p, WI_FTS_SKIP);

			continue;
		}
		
		count++;
	}
	
	wi_fts_close(fts);
	
	return count;
}




void wd_files_stat_path(wi_string_t *path) {
	wd_client_t			*client = wd_client();
	wi_string_t			*realpath, *checksum, *comment, *string;
	wi_file_offset_t	size;
	wd_file_type_t		type;
	struct stat			sb;
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);
	
	if(!wi_file_stat(realpath, &sb)) {
		if(!wi_file_lstat(realpath, &sb)) {
			wi_log_warn(WI_STR("Could not read %@: %m"), realpath);
			wd_reply_error();
			
			return;
		}
	}

	type = wd_files_type_with_stat(realpath, &sb);
	checksum = NULL;
	comment = wd_files_comment(path);
	
	switch(type) {
		case WD_FILE_TYPE_DROPBOX:
			if(client->account->view_dropboxes)
				size = wd_files_count_path(realpath);
			else
				size = 0;
			break;

		case WD_FILE_TYPE_DIR:
		case WD_FILE_TYPE_UPLOADS:
			size = wd_files_count_path(realpath);
			break;

		case WD_FILE_TYPE_FILE:
		default:
			size = sb.st_size;
			checksum = wi_file_sha1(realpath, WD_FILES_CHECKSUM_SIZE);
			break;
	}
	
	string = wi_date_iso8601_string(wi_date_with_time(sb.st_mtime));
	
	wd_reply(402, WI_STR("%#@%c%u%c%llu%c%#@%c%#@%c%#@%c%#@"),
			 path,			WD_FIELD_SEPARATOR,
			 type,			WD_FIELD_SEPARATOR,
			 size,			WD_FIELD_SEPARATOR,
			 string,		WD_FIELD_SEPARATOR,
			 string,		WD_FIELD_SEPARATOR,
			 checksum,		WD_FIELD_SEPARATOR,
			 comment);
}



wi_boolean_t wd_files_create_path(wi_string_t *path, wd_file_type_t type) {
	wi_string_t		*realpath;
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);
	
	if(!wi_file_create_directory(realpath, 0777)) {
		wi_log_warn(WI_STR("Could not create %@: %m"), realpath);
		wd_reply_error();

		return false;
	}

	if(type != WD_FILE_TYPE_DIR)
		wd_files_set_type(path, type);
	
	return true;
}



wi_boolean_t wd_files_delete_path(wi_string_t *path) {
	wi_string_t		*realpath, *component;
	wi_boolean_t	result;
	
	realpath	= wd_files_real_path(path);
	component	= wi_string_last_path_component(realpath);

	wi_string_delete_last_path_component(realpath);
	wi_string_resolve_aliases_in_path(realpath);
	wi_string_append_path_component(realpath, component);
	
	result = wi_file_delete(realpath);
	
	if(result) {
		wd_files_clear_comment(path);
	} else {
		wi_log_warn(WI_STR("Could not delete %@: %m"), realpath);
		wd_reply_error();
	}
	
	return result;
}



wi_boolean_t wd_files_move_path(wi_string_t *frompath, wi_string_t *topath) {
	wi_array_t			*array;
	wi_string_t			*component, *realfrompath, *realtopath;
	struct stat			sb;
	wi_boolean_t		result = false;
	
	realfrompath	= wd_files_real_path(frompath);
	realtopath		= wd_files_real_path(topath);
	component		= wi_string_last_path_component(realfrompath);

	wi_string_delete_last_path_component(realfrompath);
	wi_string_resolve_aliases_in_path(realfrompath);
	wi_string_resolve_aliases_in_path(realtopath);
	wi_string_append_path_component(realfrompath, component);
	
	if(!wi_file_lstat(realfrompath, &sb)) {
		wi_log_warn(WI_STR("Could not read %@: %m"), realfrompath);
		wd_reply_error();

		return false;
	}

	if(wi_file_lstat(realtopath, &sb)) {
		wd_reply(521, WI_STR("File or Directory Exists"));

		return false;
	}
	
	result = wi_file_rename(realfrompath, realtopath);
	
	if(result) {
		wd_files_move_comment(frompath, topath);
	} else {
		if(wi_error_code() == EXDEV) {
			array = wi_array_init_with_data(wi_array_alloc(),
											frompath,
											topath,
											realfrompath,
											realtopath,
											(void *) NULL);
			
			if(!wi_thread_create_thread(wd_files_move_thread, array))
				wd_reply(500, WI_STR("Command Failed"));
			
			wi_release(array);
		} else {
			wi_log_warn(WI_STR("Could not rename %@ to %@: %m"),
				realfrompath, realtopath);
			wd_reply_error();
		}
	}
	
	return result;
}



static void wd_files_move_thread(wi_runtime_instance_t *argument) {
	wi_pool_t		*pool;
	wi_array_t		*array = argument;
	wi_string_t		*frompath, *topath, *realfrompath, *realtopath;
	
	pool			= wi_pool_init(wi_pool_alloc());
	frompath		= WI_ARRAY(array, 0);
	topath			= WI_ARRAY(array, 1);
	realfrompath	= WI_ARRAY(array, 2);
	realtopath		= WI_ARRAY(array, 3);
	
	if(wi_file_copy(realfrompath, realtopath)) {
		if(wi_file_delete(realfrompath)) {
			wd_files_move_comment(frompath, topath);
		} else {
			wi_log_warn(WI_STR("Could not delete %@: %m"), realfrompath);
		}
	} else {
		wi_log_warn(WI_STR("Could not copy %@: %m"), realfrompath);
	}
	
	wi_release(pool);
}



#pragma mark -

void wd_files_search(wi_string_t *query) {
	if(wi_is_equal(wd_settings.searchmethod, WI_STR("index")) && wd_settings.index)
		wd_files_search_index(query);
	else
		wd_files_search_live(wd_files_real_path(WI_STR("/")), query, NULL);
}



static void wd_files_search_live(wi_string_t *path, wi_string_t *query, const char *pathprefix) {
	wd_client_t				*client = wd_client();
	WI_FTS					*fts;
	WI_FTSENT				*p;
	wi_string_t				*filepath, *virtualpath, *name, *string;
	wi_file_offset_t		size;
	wd_files_fts_action_t	action;
	wd_file_type_t			type;
	struct stat				sb;
	unsigned int			pathlength;
	int						err;
	wi_boolean_t			alias, recurse;

	fts = wd_files_fts_open(path);

	if(!fts) {
		wi_log_warn(WI_STR("Could not open %@: %s"),
			path, strerror(errno));

		if(!pathprefix)
			wd_reply_error();
		
		return;
	}
	
	pathlength = wi_string_length(path);
	
	if(pathlength == 1)
		pathlength--;
	
	while((p = wi_fts_read(fts))) {
		/* skip item? */
		action = wd_files_fts_action(p, &err);
		
		switch(action) {
			case WD_FILES_FTS_KEEP:
				break;
				
			case WD_FILES_FTS_IGNORE:
				continue;
				break;
				
			case WD_FILES_FTS_SKIP:
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
				break;
				
			case WD_FILES_FTS_ERROR:
				wi_log_warn(WI_STR("Could not search %s: %s"),
					p->fts_path, strerror(err));

				continue;
				break;
		}
		
		/* create and resolve aliased path */
		filepath	= wi_string_with_cstring(p->fts_path);
		virtualpath	= wi_string_substring_from_index(filepath, pathlength);
		alias		= wi_file_is_alias_cpath(p->fts_path);
		
		if(alias)
			wi_string_resolve_aliases_in_path(filepath);

		if(!wi_file_stat(filepath, &sb)) {
			if(!wi_file_lstat(filepath, &sb)) {
				wi_fts_set(fts, p, WI_FTS_SKIP);

				continue;
			}
		}
		
		recurse = (alias && S_ISDIR(sb.st_mode));
		
		/* get file type */
		type = wd_files_type_with_stat(filepath, &sb);
		name = wi_string_with_cstring(p->fts_name);
		
		if(wi_string_contains_string(name, query, WI_STRING_CASE_INSENSITIVE)) {
			/* matched, get size */
			switch(type) {
				case WD_FILE_TYPE_DROPBOX:
					if(client->account->view_dropboxes)
						size = wd_files_count_path(filepath);
					else
						size = 0;
					break;
					
				case WD_FILE_TYPE_DIR:
				case WD_FILE_TYPE_UPLOADS:
					size = wd_files_count_path(filepath);
					break;
					
				case WD_FILE_TYPE_FILE:
				default:
					size = sb.st_size;
					break;
			}
			
			/* reply file record */
			string = wi_date_iso8601_string(wi_date_with_time(sb.st_mtime));
			
			wd_reply(420, WI_STR("%#s%#@%c%u%c%llu%c%#@%c%#@"),
					 pathprefix,
					 virtualpath,			WD_FIELD_SEPARATOR,
					 type,					WD_FIELD_SEPARATOR,
					 size,					WD_FIELD_SEPARATOR,
					 string,				WD_FIELD_SEPARATOR,
					 string);
		}
		
		/* skip files in drop boxes */
		if(type == WD_FILE_TYPE_DROPBOX && !client->account->view_dropboxes) {
			wi_fts_set(fts, p, WI_FTS_SKIP);

			continue;
		}

		/* recurse into alias directory */
		if(recurse)
			wd_files_search_live(filepath, query, p->fts_path + pathlength);
	}
	
	if(!pathprefix)
		wd_reply(421, WI_STR("Done"));
	
	wi_fts_close(fts);
}



static void wd_files_search_index(wi_string_t *query) {
	wd_client_t		*client = wd_client();
	wi_pool_t		*pool = NULL;
	wi_file_t		*file;
	wi_string_t		*string;
	wi_range_t		range;
	unsigned int	i = 0, pathlength, index;
	
	wi_rwlock_rdlock(wd_files_index_lock);
	
	file = wi_file_for_reading(wd_settings.index);
	
	if(!file) {
		wi_log_warn(WI_STR("Could not open %@: %m"), wd_settings.index);
		wd_reply_error();

		goto end;
	}
	
	if(client->account->files)
		pathlength = wi_string_length(client->account->files);
	else
		pathlength = 0;
	
	range.location = 0;
	
	while(true) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		string = wi_file_read_line(file);
		
		if(!string)
			break;
		
		index = wi_string_index_of_char(string, WD_FIELD_SEPARATOR, 0);
		
		if(index != WI_NOT_FOUND) {
			range.length = index;
			
			if(wi_string_index_of_string_in_range(string, query, WI_STRING_CASE_INSENSITIVE, range) != WI_NOT_FOUND) {
				wi_string_delete_characters_to_index(string, index + pathlength + 1);
				
				wd_reply(420, WI_STR("%@"), string);
			}
		}

		if(++i % 100 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}

	wi_release(pool);

end:
	wd_reply(421, WI_STR("Done"));
	
	wi_rwlock_unlock(wd_files_index_lock);
}



#pragma mark -

static void wd_files_update_index(wi_timer_t *timer) {
	wd_files_index(true);
}



void wd_files_index(wi_boolean_t force) {
	struct stat			sb;
	wi_time_interval_t	interval;
	wi_boolean_t		index = true;
	
	if(!force) {
		if(wi_file_stat(wd_settings.index, &sb)) {
			interval = wi_date_time_interval_since_now(wi_date_with_time(sb.st_mtime));
			
			if(interval < wd_settings.indextime) {
				wi_log_info(WI_STR("Reusing existing index created %.2f seconds ago"), interval);
				
				index = false;
			}
		}
	}
	
	if(index) {
		if(!wi_thread_create_thread_with_priority(wd_files_index_thread, NULL, 0.0))
			wi_log_warn(WI_STR("Could not create a thread for index: %m"));
	}
}



static void wd_files_index_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wi_file_t			*file;
	wi_string_t			*path, *realpath;
	wi_time_interval_t	interval;
	unsigned int		count, capacity;
	
	pool = wi_pool_init(wi_pool_alloc());

	if(wi_lock_trylock(wd_files_indexer_lock)) {
		wi_log_info(WI_STR("Indexing files..."));

		interval = wi_time_interval();
		count = wd_files_unique_count + wd_directories_unique_count;

		if(count > 100)
			capacity = 100 + (count / 100.0f);
		else if(count > 0)
			capacity = count;
		else
			capacity = 100;

		wd_files_count			= wd_files_unique_count = 0;
		wd_files_size			= wd_files_unique_size = 0;
		wd_files_index_level	= 0;
		wd_files_index_set		= wi_set_init_with_capacity(wi_set_alloc(), capacity);

		path = wi_string_with_format(WI_STR("%@~"), wd_settings.index);
		file = wi_file_for_writing(path);
		
		if(!file) {
			wi_log_warn(WI_STR("Could not open %@: %m"), path);

			goto end;
		}
		
		realpath = wi_string_by_resolving_aliases_in_path(wd_settings.files);
		wd_files_index_path(realpath, file, NULL);
		
		wi_rwlock_wrlock(wd_files_index_lock);

		if(wi_file_rename(path, wd_settings.index)) {
			wi_log_info(WI_STR("Indexed %u %s (%u unique) and %u %s (%u unique) for a total of %llu %s (%llu unique) in %.2f seconds"),
				wd_files_count,
				wd_files_count == 1
					? "file"
					: "files",
				wd_files_unique_count,
				wd_directories_count,
				wd_directories_count == 1
					? "directory"
					: "directories",
				wd_directories_unique_count,
				wd_files_size,
				wd_files_size == 1
					? "byte"
					: "bytes",
				wd_files_unique_size,
				wi_time_interval() - interval);
		} else {
			wi_log_warn(WI_STR("Could not rename %@ to %@: %m"),
				path, wd_settings.index);
		}
		
		wi_rwlock_unlock(wd_files_index_lock);
		
end:
		wi_release(wd_files_index_set);

		wi_lock_unlock(wd_files_indexer_lock);
	}
	
	wi_release(pool);
}



static void wd_files_index_path(wi_string_t *path, wi_file_t *file, const char *pathprefix) {
	wi_pool_t				*pool;
	WI_FTS					*fts = NULL;
	WI_FTSENT				*p;
	wi_string_t				*filepath, *virtualpath, *string;
	wi_number_t				*number;
	wi_file_offset_t		size;
	wd_file_type_t			type;
	wd_files_fts_action_t	action;
	struct stat				sb;
	int						err;
	unsigned int			i = 0, pathlength;
	wi_boolean_t			alias, recurse;
	
	pool = wi_pool_init(wi_pool_alloc());

	if(++wd_files_index_level > WD_FILES_MAX_LEVEL) {
		wi_log_warn(WI_STR("Skipping index of %@: %s"),
			path, "Directory too deep");

		goto end;
	}

	fts = wd_files_fts_open(path);

	if(!fts) {
		wi_log_warn(WI_STR("Could not open %@: %s"),
			path, strerror(errno));

		goto end;
	}
	
	pathlength = wi_string_length(path);
	
	if(pathlength == 1)
		pathlength--;
	
	while((p = wi_fts_read(fts))) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		/* skip item? */
		action = wd_files_fts_action(p, &err);
		
		switch(action) {
			case WD_FILES_FTS_KEEP:
				break;
				
			case WD_FILES_FTS_IGNORE:
				continue;
				break;
				
			case WD_FILES_FTS_SKIP:
				wi_fts_set(fts, p, WI_FTS_SKIP);
				
				continue;
				break;
				
			case WD_FILES_FTS_ERROR:
				wi_log_warn(WI_STR("Skipping index of %s: %s"),
					p->fts_path, strerror(err));

				continue;
				break;
		}

		/* create and resolve aliased path */
		filepath	= wi_string_with_cstring(p->fts_path);
		virtualpath	= wi_string_substring_from_index(filepath, pathlength);
		alias		= wi_file_is_alias_cpath(p->fts_path);
		
		if(alias)
			wi_string_resolve_aliases_in_path(filepath);

		if(!wi_file_stat(filepath, &sb)) {
			if(!wi_file_lstat(filepath, &sb)) {
				wi_log_warn(WI_STR("Skipping index of %@: %m"), filepath);
				wi_fts_set(fts, p, WI_FTS_SKIP);

				goto next;
			}
		}
		
		recurse = (alias && S_ISDIR(sb.st_mode));
		
		/* get file type & size */
		type = wd_files_type_with_stat(filepath, &sb);

		switch(type) {
			case WD_FILE_TYPE_DROPBOX:
				size = 0;
				break;

			case WD_FILE_TYPE_DIR:
			case WD_FILE_TYPE_UPLOADS:
				size = wd_files_count_path(filepath);
				break;

			case WD_FILE_TYPE_FILE:
			default:
				size = sb.st_size;
				break;
		}
		
		/* write file record */
		string = wi_date_iso8601_string(wi_date_with_time(sb.st_mtime));
		
		wi_file_write(file, WI_STR("%#s%c%#s%#@%c%u%c%llu%c%#@%c%#@\n"),
					  p->fts_name,			WD_FIELD_SEPARATOR,
					  pathprefix,
					  virtualpath,			WD_FIELD_SEPARATOR,
					  type,					WD_FIELD_SEPARATOR,
					  size,					WD_FIELD_SEPARATOR,
					  string,				WD_FIELD_SEPARATOR,
					  string);

		/* track unique inodes */
		number = wi_number_with_value(WI_NUMBER_INO_T, &sb.st_ino);
		
		if(!wi_set_contains_data(wd_files_index_set, number)) {
			if(S_ISDIR(sb.st_mode)) {
				wd_directories_unique_count++;
			} else {
				wd_files_unique_count++;
				wd_files_unique_size += size;
			}

			wi_set_add_data(wd_files_index_set, number);
		}

		if(S_ISDIR(sb.st_mode)) {
			wd_directories_count++;
		} else {
			wd_files_count++;
			wd_files_size += size;
		}
		
		/* skip files in drop boxes */
		if(type == WD_FILE_TYPE_DROPBOX) {
			wi_fts_set(fts, p, WI_FTS_SKIP);

			goto next;
		}

		/* recurse into alias directory */
		if(recurse)
			wd_files_index_path(filepath, file, p->fts_path + pathlength);
		
next:
		if(++i % 100 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}

end:
	wd_files_index_level--;
	
	if(fts)
		wi_fts_close(fts);
	
	wi_release(pool);
}



#pragma mark -

wd_file_type_t wd_files_type(wi_string_t *path) {
	struct stat		sb;
	
	if(!wi_file_stat(path, &sb)) {
		wi_log_warn(WI_STR("Could not read %@: %m"), path);
		
		return WD_FILE_TYPE_FILE;
	}
	
	return wd_files_type_with_stat(path, &sb);
}



static wd_file_type_t wd_files_type_with_stat(wi_string_t *path, struct stat *sbp) {
	wi_string_t		*typepath, *string;
	
	if(!S_ISDIR(sbp->st_mode))
		return WD_FILE_TYPE_FILE;
	
	typepath	= wi_string_by_appending_path_component(path, WI_STR(WD_FILES_META_TYPE_PATH));
	string		= wi_autorelease(wi_string_init_with_contents_of_file(wi_string_alloc(), typepath));
	
	if(!string)
		return WD_FILE_TYPE_DIR;
	
	wi_string_delete_surrounding_whitespace(string);
	
	return wi_string_uint32(string);
}



void wd_files_set_type(wi_string_t *path, wd_file_type_t type) {
	wi_string_t		*realpath, *metapath, *typepath;
	
	realpath = wd_files_real_path(path);
	wi_string_resolve_aliases_in_path(realpath);

	metapath = wi_string_by_appending_path_component(realpath, WI_STR(WD_FILES_META_PATH));
	typepath = wi_string_by_appending_path_component(realpath, WI_STR(WD_FILES_META_TYPE_PATH));
	
	if(type != WD_FILE_TYPE_DIR) {
		if(!wi_file_create_directory(metapath, 0777)) {
			if(wi_error_code() != EEXIST) {
				wi_log_warn(WI_STR("Could not create %@: %m"), metapath);
				wd_reply_error();

				return;
			}
		}
		
		if(!wi_string_write_to_file(wi_string_with_format(WI_STR("%u\n"), type), typepath))
			wi_log_warn(WI_STR("Could not write to %@: %m"), typepath);
	} else {
		/* if resetting to regular directory, just remove type file */
		if(wi_file_delete(typepath)) {
			/* clean up .wired (will fail unless empty) */
			(void) rmdir(wi_string_cstring(metapath));
		}
	}
	
}



#pragma mark -

wi_string_t * wd_files_comment(wi_string_t *path) {
	wi_file_t		*file;
	wi_string_t		*name, *dirpath, *realdirpath, *commentpath;
	wi_string_t		*eachname, *eachcomment, *comment = NULL;
	
	name		= wi_string_last_path_component(path);
	dirpath		= wi_string_by_deleting_last_path_component(path);
	realdirpath	= wd_files_real_path(dirpath);

	wi_string_resolve_aliases_in_path(realdirpath);
	
	commentpath	= wi_string_by_appending_path_component(realdirpath, WI_STR(WD_FILES_META_COMMENTS_PATH));
	file		= wi_file_for_reading(commentpath);
	
	if(!file)
		return NULL;

	while(wd_files_read_comment(file, &eachname, &eachcomment)) {
		if(wi_is_equal(name, eachname)) {
			comment = wi_retain(eachcomment);
			
			break;
		}
	}

	return wi_autorelease(comment);
}



void wd_files_set_comment(wi_string_t *path, wi_string_t *comment) {
	wi_file_t		*file, *tmpfile;
	wi_string_t		*name, *dirpath, *realdirpath, *metapath, *commentpath;
	wi_string_t		*string, *eachname, *eachcomment;
	unsigned int	comments = 0;
	
	name		= wi_string_last_path_component(path);
	dirpath		= wi_string_by_deleting_last_path_component(path);
	realdirpath	= wd_files_real_path(dirpath);

	wi_string_resolve_aliases_in_path(realdirpath);
	
	metapath	= wi_string_by_appending_path_component(realdirpath, WI_STR(WD_FILES_META_PATH));
	commentpath	= wi_string_by_appending_path_component(realdirpath, WI_STR(WD_FILES_META_COMMENTS_PATH));
	
	if(comment && wi_string_length(comment) > 0) {
		if(!wi_file_create_directory(metapath, 0777)) {
			if(wi_error_code() != EEXIST) {
				wi_log_warn(WI_STR("Could not create %@: %m"), metapath);
				wd_reply_error();
				
				return;
			}
		}
	}
	
	file = wi_file_for_updating(commentpath);
	
	if(!file)
		return;
	
	tmpfile = wi_file_temporary_file();
	
	if(!tmpfile) {
		wi_log_warn(WI_STR("Could not create a temporary file: %m"));

		return;
	}
	
	if(comment && wi_string_length(comment) > 0) {
		wi_file_write(tmpfile, WI_STR("%#@%s%#@%s"),
					  name,		WD_FILES_COMMENT_FIELD_SEPARATOR,
					  comment,	WD_FILES_COMMENT_SEPARATOR);
	}
	
	while(wd_files_read_comment(file, &eachname, &eachcomment)) {
		if(!wi_is_equal(name, eachname)) {
			wi_file_write(tmpfile, WI_STR("%#@%s%#@%s"),
						  eachname,		WD_FILES_COMMENT_FIELD_SEPARATOR,
						  eachcomment,	WD_FILES_COMMENT_SEPARATOR);
		}
		
		comments++;
	}
	
	if(comments > 1 || (comment && wi_string_length(comment) > 0)) {
		wi_file_truncate(file, 0);
		wi_file_seek(tmpfile, 0);
	
		while((string = wi_file_read(tmpfile, WI_FILE_BUFFER_SIZE)))
			wi_file_write(file, WI_STR("%@"), string);
	} else {
		/* clearing comment, and there are no more comments in the file, remove */
		wi_file_close(file);
		wi_file_close(tmpfile);
		
		if(wi_file_delete(commentpath)) {
			/* clean up .wired (will fail unless empty) */
			(void) rmdir(wi_string_cstring(metapath));
		}
	}
}



static void wd_files_clear_comment(wi_string_t *path) {
	wd_files_set_comment(path, NULL);
}



void wd_files_move_comment(wi_string_t *frompath, wi_string_t *topath) {
	wi_string_t		*comment;
	
	comment = wd_files_comment(frompath);
	
	if(comment) {
		wd_files_set_comment(frompath, NULL);
		wd_files_set_comment(topath, comment);
	}
}



static wi_boolean_t wd_files_read_comment(wi_file_t *file, wi_string_t **name, wi_string_t **comment) {
	wi_array_t		*array;
	wi_string_t		*string;

	string = wi_file_read_to_string(file, WI_STR(WD_FILES_COMMENT_SEPARATOR));
	
	if(string) {
		array = wi_string_components_separated_by_string(string, WI_STR(WD_FILES_COMMENT_FIELD_SEPARATOR));
	
		if(wi_array_count(array) == 2) {
			*name		= WI_ARRAY(array, 0);
			*comment	= WI_ARRAY(array, 1);
			
			return true;
		}
	}
	
	return false;
}



#pragma mark -

wi_boolean_t wd_files_path_is_valid(wi_string_t *path) {
	if(wi_string_has_prefix(path, WI_STR(".")))
		return false;

	if(wi_string_contains_string(path, WI_STR("/.."), 0))
        return false;

	if(wi_string_contains_string(path, WI_STR("../"), 0))
        return false;

	return true;
}



wi_boolean_t wd_files_path_is_dropbox(wi_string_t *path) {
	wi_string_t		*realpath, *dirpath;
	wi_array_t		*array;
	wd_file_type_t	type;
	unsigned int	i, count;
	wi_boolean_t	result = false;
	
	realpath = wd_files_real_path(WI_STR("/"));
	wi_string_resolve_aliases_in_path(realpath);
	
	dirpath = wi_copy(path);
	wi_string_delete_last_path_component(dirpath);

	array = wi_string_path_components(dirpath);
	count = wi_array_count(array);
	
	for(i = 0; i < count; i++) {
		wi_string_append_path_component(realpath, WI_ARRAY(array, i));
		
		type = wd_files_type(realpath);

		if(type == WD_FILE_TYPE_DROPBOX) {
			result = true;
			
			break;
		}
	}
	
	wi_release(dirpath);
	
	return result;
}



wi_string_t * wd_files_real_path(wi_string_t *path) {
	wd_client_t		*client = wd_client();
	wi_string_t		*realpath;
	
	if(client && client->account->files)
		realpath = wi_string_with_format(WI_STR("%@/%@/%@"), wd_settings.files, client->account->files, path);
	else
		realpath = wi_string_with_format(WI_STR("%@/%@"), wd_settings.files, path);
	
	wi_string_normalize_path(realpath);
	
	return realpath;
}



#pragma mark -

static WI_FTS * wd_files_fts_open(wi_string_t *path) {
	WI_FTS		*fts;
	char		*paths[2];
	
	paths[0] = (char *) wi_string_cstring(path);
	paths[1] = NULL;

	errno = 0;
	fts = wi_fts_open(paths, WI_FTS_LOGICAL | WI_FTS_NOSTAT, NULL);
	
	if(fts && errno != 0) {
		wi_fts_close(fts);
		
		fts = NULL;
	}
	
	return fts;
}



static WI_FTS * wd_files_fts_open_sorted(wi_string_t *path) {
	WI_FTS		*fts;
	char		*paths[2];
	
	paths[0] = (char *) wi_string_cstring(path);
	paths[1] = NULL;
	
	errno = 0;
	fts = wi_fts_open(paths, WI_FTS_LOGICAL | WI_FTS_NOSTAT, wd_files_fts_namecmp);

	if(fts && errno != 0) {
		wi_fts_close(fts);
		
		fts = NULL;
	}
	
	return fts;
}



static wd_files_fts_action_t wd_files_fts_action(WI_FTSENT *p, int *err) {
	/* skip root */
	if(p->fts_level == 0)
		return WD_FILES_FTS_IGNORE;

	/* skip when level reached */
	if(p->fts_level > WD_FILES_MAX_LEVEL)
		return WD_FILES_FTS_SKIP;
		
	/* skip fts errors */
	switch(p->fts_info) {
		case WI_FTS_DC:
			*err = ELOOP;
			
			return WD_FILES_FTS_ERROR;
			break;

		case WI_FTS_DP:
			return WD_FILES_FTS_SKIP;
			break;

		case WI_FTS_DNR:
		case WI_FTS_ERR:
			*err = p->fts_errno;
			
			return WD_FILES_FTS_ERROR;
			break;
	}

	/* skip . files */
	if(p->fts_name[0] == '.') {
		if(!wd_settings.showdotfiles)
			return WD_FILES_FTS_SKIP;
	}
		
	/* skip regular expression */
	if(wd_settings.ignoreexpression) {
		if(wi_regexp_match_cstring(wd_settings.ignoreexpression, p->fts_name))
			return WD_FILES_FTS_SKIP;
	}
			
	/* skip mac invisibles */
	if(!wd_settings.showinvisiblefiles) {
		if(wi_file_is_invisible_cpath(p->fts_path))
			return WD_FILES_FTS_SKIP;
	}
	
	return WD_FILES_FTS_KEEP;
}



static int wd_files_fts_namecmp(const WI_FTSENT **a, const WI_FTSENT **b) {
	return strcasecmp((*a)->fts_name, (*b)->fts_name);
}
