/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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
#include <sys/mount.h>
#include <sys/fcntl.h>
#include <sys/time.h>
#ifdef HAVE_SYS_VFS_H
#include <sys/vfs.h>
#endif
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <ctype.h>
#include <libgen.h>
#include <fts.h>
#include <dirent.h>
#include <pthread.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <regex.h>

#include "accounts.h"
#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


wd_list_t					wd_transfers;

pthread_mutex_t				wd_index_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t				wd_indexer_mutex = PTHREAD_MUTEX_INITIALIZER;

unsigned int				wd_files_count;
unsigned long long			wd_files_size;


void wd_list_path(char *path) {
	wd_client_t			*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	struct statfs		buf;
	struct stat			sb;
	FTS					*fts = NULL;
	FTSENT				*p, *chp, *cur;
	unsigned long long	size;
	char				file_time[WD_DATETIME_SIZE];
	char				real_path[MAXPATHLEN], wired_path[MAXPATHLEN], *paths[2];
	bool				upload = false;
	wd_file_type_t		type;
	int					view_dropboxes;
	
	/* get real access path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac aliases */
	wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	/* check type */
	switch(wd_get_type(real_path, NULL)) {
		case WD_FILE_TYPE_DROPBOX:
			/* check for drop box privilege */
			if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1)
				goto last;

			/* FALLTHROUGH */
		
		case WD_FILE_TYPE_UPLOADS:
			/* check for upload privilege */
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD) == 1)
				upload = true;
			break;
		
		default:
			/* check for upload anywhere privilege */
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD_ANYWHERE) == 1)
				upload = true;
			break;
	}
	
	/* file system stat it */
	memset(&buf, 0, sizeof(buf));
	
	if(upload) {
		if(statfs(real_path, &buf) < 0) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_file_error();

			goto end;
		}
	}
	
	/* create argument vector */
	paths[0] = real_path;
	paths[1] = NULL;

	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, wd_fts_namecmp);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();

		goto end;
	}

	/* check if we can enter drop boxes */
	view_dropboxes = wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES);

	/* traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);

		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip . files */
				if(!wd_settings.showdotfiles) {
					if(cur->fts_name[0] == '.') {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
				
				/* skip regular expression */
				if(WD_REGEXP_MATCH(wd_settings.ignoreexpression, cur->fts_name)) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);

#ifdef HAVE_CARBON_CARBON_H
				/* skip mac invisibles */
				if(!wd_settings.showinvisiblefiles) {
					if(wd_apple_is_invisible(real_path)) {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
#endif
				
#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* resolve mac aliases */
				wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

				/* stat */
				if(stat(real_path, &sb) < 0) {
					if(lstat(real_path, &sb) < 0) {
						fts_set(fts, cur, FTS_SKIP);
					
						continue;
					}
				}
				
				/* get the file type */
				type = wd_get_type(real_path, &sb);
				
				switch(type) {
					case WD_FILE_TYPE_DROPBOX:
						if(view_dropboxes == 1)
							size = wd_count_path(real_path);
						else
							size = 0;
						break;

					case WD_FILE_TYPE_DIR:
					case WD_FILE_TYPE_UPLOADS:
						size = wd_count_path(real_path);
						break;
					
					case WD_FILE_TYPE_FILE:
					default:
						size = sb.st_size;
						break;
				}
				
				/* create display path */
				snprintf(wired_path, sizeof(wired_path), "%s%s%s",
					path,
					path[strlen(path) - 1] == '/'
						? "" /* skip extra '/' */
						: "/",
					cur->fts_name);

				/* format time strings */
				wd_time_to_iso8601(sb.st_mtime, file_time, sizeof(file_time));
			
				/* reply a 410 for each file */
				wd_reply(410, "%s%c%u%c%llu%c%s%c%s",
						 wired_path,
						 WD_FIELD_SEPARATOR,
						 type,
						 WD_FIELD_SEPARATOR,
						 size,
						 WD_FIELD_SEPARATOR,
						 file_time,
						 WD_FIELD_SEPARATOR,
						 file_time);
			}
			
			/* don't do recursive listings */
			fts_set(fts, p, FTS_SKIP);
		}
	}

last:
	wd_reply(411, "%s%c%llu",
			 path,
			 WD_FIELD_SEPARATOR,
			 (unsigned long long) buf.f_bavail * (unsigned long long) buf.f_bsize);

end:
	/* clean up */
	if(fts)
		fts_close(fts);
}



unsigned long long wd_count_path(char *path) {
	FTS					*fts = NULL;
	FTSENT				*p, *chp, *cur;
	char				real_path[MAXPATHLEN], *paths[2];
	unsigned long long	size = 0;

	/* create argument vector */
	paths[0] = path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);
		
		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip . files */
				if(!wd_settings.showdotfiles) {
					if(cur->fts_name[0] == '.') {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}

				/* skip regular expression */
				if(WD_REGEXP_MATCH(wd_settings.ignoreexpression, cur->fts_name)) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);
				
#ifdef HAVE_CARBON_CARBON_H
				/* skip mac invisibles */
				if(!wd_settings.showinvisiblefiles) {
					if(wd_apple_is_invisible(real_path)) {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
#endif
				
				size++;
			}

			/* don't do recursive listings */
			fts_set(fts, p, FTS_SKIP);
		}
	}
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	return size;
}



void wd_stat_path(char *path) {
	FILE					*fp;
	SHA_CTX					c;
	struct stat				sb;
	size_t					bytes;
	char					real_path[MAXPATHLEN];
	char					file_time[WD_DATETIME_SIZE], comment[WD_COMMENT_SIZE], buffer[BUFSIZ];
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], sha_output[SHA_DIGEST_LENGTH * 2 + 1];
	unsigned long long		size;
	wd_file_type_t			type;
	int						i, total = 0;

	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	/* stat the actual file */
	if(stat(real_path, &sb) < 0) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();

		return;
	}
	
	/* get file type */
	type = wd_get_type(real_path, &sb);

	switch(type) {
		case WD_FILE_TYPE_DIR:
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			size = wd_count_path(real_path);
			break;
		
		case WD_FILE_TYPE_FILE:
		default:
			size = sb.st_size;
			break;
	}
	
	/* get file comment */
	wd_get_comment(real_path, comment, sizeof(comment));
	
	/* format time strings */
	wd_time_to_iso8601(sb.st_mtime, file_time, sizeof(file_time));
	
	/* zero out checksum */
	memset(sha_output, 0, sizeof(sha_output));

	/* calculate a SHA-1 checksum for files */
	if(type == WD_FILE_TYPE_FILE) {
		/* open the file */
		fp = fopen(real_path, "r");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s",
				real_path, strerror(errno));
			wd_file_error();

			return;
		}
		
		SHA1_Init(&c);
	
		if(size >= WD_CHECKSUM_SIZE) {
			/* don't read the entire file for checksum, as that will take
			   quite some time */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp))) {
				SHA1_Update(&c, buffer, bytes);
				total += bytes;
				
				if(total >= WD_CHECKSUM_SIZE)
					break;
			}
		} else {
			/* the file is small enough, checksum it all */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp)))
				SHA1_Update(&c, buffer, bytes);
		}
		
		SHA1_Final(sha, &c);
	
		/* map into hex characters */
		for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
			sha_output[i+i]		= hex[sha[i] >> 4];
			sha_output[i+i+1]	= hex[sha[i] & 0x0F];
		}
		
		sha_output[i+i] = '\0';

		fclose(fp);
	}
	
	/* send the info message */
	wd_reply(402, "%s%c%u%c%llu%c%s%c%s%c%s%c%s",
			 path,
			 WD_FIELD_SEPARATOR,
			 type,
			 WD_FIELD_SEPARATOR,
			 size,
			 WD_FIELD_SEPARATOR,
			 file_time,
			 WD_FIELD_SEPARATOR,
			 file_time,
			 WD_FIELD_SEPARATOR,
			 sha_output,
			 WD_FIELD_SEPARATOR,
			 comment);
}



void wd_create_path(char *path) {
	char	real_path[MAXPATHLEN], dir[MAXPATHLEN], base[MAXPATHLEN];

	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

	/* get the parent directory */
	strlcpy(dir, wd_dirname(real_path), sizeof(dir));
	strlcpy(base, wd_basename(real_path), sizeof(base));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(dir, dir, sizeof(dir));
#endif
	
	/* create new real path */
	snprintf(real_path, sizeof(real_path), "%s/%s",
		dir,
		base);
	
	/* create the path */
	if(mkdir(real_path, 0755) < 0) {
		wd_log(LOG_WARNING, "Could not create %s: %s",
			real_path, strerror(errno));
		wd_file_error();

		return;
	}
}



void wd_move_path(char *from, char *to) {
	wd_move_record_t	*move;
	pthread_t			thread;
	struct stat			sb;
	char				dir[MAXPATHLEN], base[MAXPATHLEN];

	/* get real paths */
	move = (wd_move_record_t *) malloc(sizeof(wd_move_record_t));
	snprintf(move->from, sizeof(move->from), ".%s", from);
	snprintf(move->to, sizeof(move->to), ".%s", to);

	/* get the parent directory */
	strlcpy(dir, wd_dirname(move->to), sizeof(dir));
	strlcpy(base, wd_basename(move->to), sizeof(base));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac aliases */
	if(!wd_apple_is_alias(move->from))
		wd_apple_resolve_alias_path(move->from, move->from, sizeof(move->from));

	wd_apple_resolve_alias_path(dir, dir, sizeof(dir));
#endif
	
	/* don't do this */
	if(base[0] == '.') {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* create new real path */
	snprintf(move->to, sizeof(move->to), "%s/%s",
		dir,
		base);

	/* check for existing file */
	if(stat(move->to, &sb) == 0) {
		wd_reply(521, "File or directory exists");
		
		goto end;
	}
	
	/* move the file/directory */
	if(rename(move->from, move->to) == 0) {
		/* success, move the comment */
		wd_move_comment(move->from, move->to);

		goto end;
	}
	
	if(errno != EXDEV) {
		/* log real error */
		wd_log(LOG_WARNING, "Could not rename %s to %s: %s",
			move->from, move->to, strerror(errno));
		wd_file_error();
		
		goto end;
	} else {
		/* detach a thread to copy across file systems */
		if(pthread_create(&thread, NULL, wd_move_thread, move) < 0) {
			wd_file_error();
			
			goto end;
		}
		
		/* skip end */
		return;
	}

end:
	/* clean up */
	if(move)
		free(move);
}



int wd_delete_path(char *path) {
	char			real_path[MAXPATHLEN];
	struct stat		sb;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

	if(lstat(real_path, &sb) < 0) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();

		return -1;
	}
	
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	if(!S_ISLNK(sb.st_mode) && !wd_apple_is_alias(real_path)) {
		wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
		
		if(stat(real_path, &sb) < 0) {
			wd_log(LOG_WARNING, "Could not open %s: %s", real_path, strerror(errno));
			wd_file_error();
	
			return -1;
		}
	}
#endif
		
	/* remove the top-level file comment */
	wd_clear_comment(real_path);

	if(S_ISDIR(sb.st_mode)) {
		/* recursively delete this path */
		return wd_delete_paths(real_path);
	} else {
		/* delete the file */
		if(unlink(real_path) < 0) {
			wd_log(LOG_WARNING, "Could not delete %s: %s",
				real_path, strerror(errno));
			wd_file_error();

			return -1;
		}
	}
	
	return 1;
}



int wd_delete_paths(char *real_path) {
	FTS			*fts = NULL;
	FTSENT		*p;
	char		*paths[2];
	bool		error = false;
	int			result = -1;
	
	/* create argument vector */
	paths[0] = real_path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		switch(p->fts_info) {
			/* pre-order directory, skip */
			case FTS_D:
				break;
				
			/* post-order (empty) directories */
			case FTS_DP:
			case FTS_DNR:
				if(rmdir(p->fts_path) < 0)
					error = true;
				break;
			
			/* catch-all */
			default:
				if(unlink(p->fts_accpath) < 0)
					error = true;
				break;
		}
	}
	
	/* single error message */
	if(error) {
		wd_log(LOG_WARNING, "Could not delete %s: %s", real_path, strerror(errno));
		wd_file_error();
	}
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	return result;
}



#pragma mark -

void wd_search_files(char *query) {
	if(strcmp(wd_settings.searchmethod, "live") == 0)
		wd_search_files_path(".", query, true, NULL);
	else if(strcmp(wd_settings.searchmethod, "index") == 0)
		wd_search_files_index(query);
}



void wd_search_files_path(char *path, char *query, bool root, char *prefix) {
	wd_client_t			*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	struct stat			sb;
	FTS					*fts = NULL;
	FTSENT				*p, *chp, *cur;
	char				file_time[WD_DATETIME_SIZE];
	char				real_path[MAXPATHLEN], wired_path[MAXPATHLEN], *paths[2];
	unsigned long long	size;
	wd_file_type_t		type;
	int					view_dropboxes;
	
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	bool				alias;
#endif

	/* build a custom argv for fts_open() */
	paths[0] = path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, wd_fts_namecmp);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			path, strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* check if we can enter drop boxes */
	view_dropboxes = wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES);
	
	/* now traverse the directory */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);
		
		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip very deep levels */
				if(cur->fts_level >= 10) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}

				/* skip . files */
				if(!wd_settings.showdotfiles) {
					if(cur->fts_name[0] == '.') {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
				
				/* skip regular expression */
				if(WD_REGEXP_MATCH(wd_settings.ignoreexpression, cur->fts_name)) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);

#ifdef HAVE_CARBON_CARBON_H
				/* skip mac invisibles */
				if(!wd_settings.showinvisiblefiles) {
					if(wd_apple_is_invisible(real_path)) {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
#endif

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* resolve mac aliases */
				alias = wd_apple_is_alias(real_path);
				
				if(alias)
					wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

				/* stat */
				if(stat(real_path, &sb) < 0) {
					if(lstat(real_path, &sb) < 0) {
						fts_set(fts, cur, FTS_SKIP);
					
						continue;
					}
				}

				/* create display path */
				if(prefix) {
					snprintf(wired_path, sizeof(wired_path), "%s%s",
						prefix,
						real_path + strlen(path));
				} else {
					snprintf(wired_path, sizeof(wired_path), "%s%s%s",
						cur->fts_path + 1, /* skip '.' */
						cur->fts_path[strlen(cur->fts_path) - 1] == '/'
							? "" /* skip extra '/' */
							: "/",
						cur->fts_name);
				}

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* check if the mac alias points to a directory */
				if(alias && S_ISDIR(sb.st_mode))
					wd_search_files_path(real_path, query, false, wired_path);
#endif

				/* get the file type */
				type = wd_get_type(real_path, &sb);

				/* check for a match */
				if(strcasestr(cur->fts_name, query)) {
					switch(type) {
						case WD_FILE_TYPE_DROPBOX:
							if(view_dropboxes == 1)
								size = wd_count_path(real_path);
							else
								size = 0;
							break;
						
						case WD_FILE_TYPE_DIR:
						case WD_FILE_TYPE_UPLOADS:
							size = wd_count_path(real_path);
							break;
						
						case WD_FILE_TYPE_FILE:
						default:
							size = sb.st_size;
							break;
					}

					/* format time strings */
					wd_time_to_iso8601(sb.st_mtime, file_time, sizeof(file_time));

					/* reply a 420 for each file */
					wd_reply(420, "%s%c%u%c%llu%c%s%c%s",
							 wired_path,
							 WD_FIELD_SEPARATOR,
							 type,
							 WD_FIELD_SEPARATOR,
							 size,
							 WD_FIELD_SEPARATOR,
							 file_time,
							 WD_FIELD_SEPARATOR,
							 file_time);
				}

				/* check if we should enter drop boxes */
				if(type == WD_FILE_TYPE_DROPBOX && view_dropboxes != 1)
					fts_set(fts, cur, FTS_SKIP);
			}
		}
	}

	/* reply end marker */
	if(root)
		wd_reply(421, "Done");

end:
	if(fts)
		fts_close(fts);
}



void wd_search_files_index(char *query) {
	FILE		*fp = NULL;
	char		buffer[BUFSIZ];
	char		*p, *record;

	/* lock */
	pthread_mutex_lock(&wd_index_mutex);

	/* open index file */
	fp = fopen(wd_settings.index, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.index, strerror(errno));
		wd_file_error();

		goto end;
	}

	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak if any */
		if((p = strchr(buffer, '\n')))
			*p = '\0';
		
		/* copy the record */
		record = strdup(buffer);
		
		/* extract file path part */
		if((p = strchr(buffer, WD_FIELD_SEPARATOR)))
			*p = '\0';
		
		/* check for a match */
		if(strcasestr(wd_basename(buffer), query)) {
			/* reply a 420 for each file */
			wd_reply(420, "%s", record);
		}
		
		free(record);
	}
	
	/* reply end marker */
	wd_reply(421, "Done");
	
end:
	/* clean up */
	if(fp)
		fclose(fp);

	/* lock */
	pthread_mutex_unlock(&wd_index_mutex);

}



#pragma mark -

void wd_index_files(void) {
	struct sched_param		param;
	pthread_attr_t			attr;
	pthread_t				thread;
	int						err;
	
	/* set lower priority for index thread */
	pthread_attr_init(&attr);
	param.sched_priority = 0;
	pthread_attr_setschedpolicy(&attr, SCHED_OTHER);
	pthread_attr_setschedparam(&attr, &param);

	/* detach index thread */
	if((err = pthread_create(&thread, &attr, wd_index_files_thread, NULL)) < 0) {
		wd_log(LOG_WARNING, "Could not create a thread for index: %s",
			strerror(err));
	}
}



void * wd_index_files_thread(void *arg) {
	/* we only want one of this thread */
	pthread_mutex_lock(&wd_indexer_mutex);

	/* reset */
	wd_files_count = 0;
	wd_files_size = 0;
	
	/* log */
	wd_log_l(LOG_INFO, "Indexing files...");
	
	/* enter recursive indexer */
	wd_index_files_path(".", true, NULL, NULL);
	
	/* log */
	wd_log_l(LOG_INFO, "Indexed %llu %s in %u %s",
		wd_files_size,
		wd_files_size == 1
			? "byte"
			: "bytes",
		wd_files_count,
		wd_files_count == 1
			? "file"
			: "files");

	/* unlock */
	pthread_mutex_unlock(&wd_indexer_mutex);

	return NULL;
}



void wd_index_files_path(char *path, bool root, FILE *fp, char *prefix) {
	struct stat			sb;
	FTS					*fts = NULL;
	FTSENT				*p, *chp, *cur;
	char				file_time[WD_DATETIME_SIZE];
	char				index[MAXPATHLEN], *paths[2];
	char				real_path[MAXPATHLEN], wired_path[MAXPATHLEN];
	unsigned long long	size;
	wd_file_type_t		type;
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	bool				alias;
#endif

	/* open index file */
	if(root) {
		snprintf(index, sizeof(index), "%s~", wd_settings.index);
		fp = fopen(index, "w");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s",
				index, strerror(errno));
	
			goto end;
		}
	}
	
	/* build a custom argv for fts_open() */
	paths[0] = path;
	paths[1] = NULL;
	
	/* follow symbolic links | don't change directory | don't stat */
	fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
	
	if(!fts) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			path, strerror(errno));

		goto end;
	}

	/* now traverse the files */
	while((p = fts_read(fts)) != NULL) {
		/* get children */
		chp = fts_children(fts, 0);
		
		if(chp != NULL) {
			for(cur = chp; cur != NULL; cur = cur->fts_link) {
				/* skip very deep levels */
				if(cur->fts_level >= 10) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}

				/* skip . files */
				if(!wd_settings.showdotfiles) {
					if(cur->fts_name[0] == '.') {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
				
				/* skip regular expression */
				if(WD_REGEXP_MATCH(wd_settings.ignoreexpression, cur->fts_name)) {
					fts_set(fts, cur, FTS_SKIP);
					
					continue;
				}
				
				/* get a real access path */
				snprintf(real_path, sizeof(real_path), "%s/%s",
					cur->fts_path,
					cur->fts_name);

#ifdef HAVE_CARBON_CARBON_H
				/* skip mac invisibles */
				if(!wd_settings.showinvisiblefiles) {
					if(wd_apple_is_invisible(real_path)) {
						fts_set(fts, cur, FTS_SKIP);
						
						continue;
					}
				}
#endif

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* resolve mac aliases */
				alias = wd_apple_is_alias(real_path);
				
				if(alias)
					wd_apple_resolve_alias(real_path, real_path, sizeof(real_path));
#endif

				/* stat */
				if(stat(real_path, &sb) < 0) {
					if(lstat(real_path, &sb) < 0) {
						fts_set(fts, cur, FTS_SKIP);
					
						continue;
					}
				}

				/* create display path */
				if(prefix) {
					snprintf(wired_path, sizeof(wired_path), "%s%s",
						prefix,
						real_path + strlen(path));
				} else {
					snprintf(wired_path, sizeof(wired_path), "%s%s%s",
						cur->fts_path + 1, /* skip '.' */
						cur->fts_path[strlen(cur->fts_path) - 1] == '/'
							? "" /* skip extra '/' */
							: "/",
						cur->fts_name);
				}

#ifdef HAVE_CORESERVICES_CORESERVICES_H
				/* check if the mac alias points to a directory */
				if(alias && S_ISDIR(sb.st_mode))
					wd_index_files_path(real_path, false, fp, wired_path);
#endif
	
				/* get the file type */
				type = wd_get_type(real_path, &sb);
				
				switch(type) {
					case WD_FILE_TYPE_DROPBOX:
						size = 0;
						break;

					case WD_FILE_TYPE_DIR:
					case WD_FILE_TYPE_UPLOADS:
						size = wd_count_path(real_path);
						break;
					
					case WD_FILE_TYPE_FILE:
					default:
						size = sb.st_size;
						break;
				}

				/* format time strings */
				wd_time_to_iso8601(sb.st_mtime, file_time, sizeof(file_time));

				/* write record to cache */
				fprintf(fp, "%s%c%u%c%llu%c%s%c%s\n",
						 wired_path,
						 WD_FIELD_SEPARATOR,
						 type,
						 WD_FIELD_SEPARATOR,
						 size,
						 WD_FIELD_SEPARATOR,
						 file_time,
						 WD_FIELD_SEPARATOR,
						 file_time);

				/* increment for files */
				if(cur->fts_info == FTS_F) {
					wd_files_count++;
					wd_files_size += sb.st_size;
				}

				/* don't enter drop boxes */
				if(type == WD_FILE_TYPE_DROPBOX)
					fts_set(fts, cur, FTS_SKIP);
			}
		}
	}

end:
	/* clean up */
	if(fts)
		fts_close(fts);

	if(root) {
		if(fp)
			fclose(fp);
		
		/* atomically move the new index into place */
		pthread_mutex_lock(&wd_index_mutex);
		rename(index, wd_settings.index);
		pthread_mutex_unlock(&wd_index_mutex);
	}
}



#pragma mark -

void * wd_move_thread(void *arg) {
	wd_move_record_t	*move = (wd_move_record_t *) arg;
	FTS					*fts = NULL;
	FTSENT				*p;
	struct stat			sb;
	int					offset;
	char				*paths[2], to[MAXPATHLEN];
	
	/* stat the file we should copy */
	if(stat(move->from, &sb) < 0)
		goto end;
	
	if(S_ISDIR(sb.st_mode)) {
		/* create argument vector */
		paths[0] = move->from;
		paths[1] = NULL;
		
		/* follow symbolic links | don't change directory | don't stat */
		fts = fts_open(paths, FTS_LOGICAL | FTS_NOCHDIR | FTS_NOSTAT, NULL);
		
		if(!fts)
			goto end;
		
		/* get offset */
		offset = strlen(move->from);
	
		/* now traverse the directory */
		while((p = fts_read(fts)) != NULL) {
			snprintf(to, sizeof(to), "%s%s", move->to, p->fts_path + offset);

			switch(p->fts_info) {
				/* pre-order directory */
				case FTS_D:
					if(mkdir(to, 0755) < 0)
						goto end;
					break;

				/* post-order directories */
				case FTS_DP:
				case FTS_DNR:
					rmdir(p->fts_path);
					break;
					
				/* catch-all */
				default:
					wd_move_file(p->fts_path, to);
					break;
			}
		}
	} else {
		wd_move_file(move->from, move->to);
	}
	
end:
	/* clean up */
	if(fts)
		fts_close(fts);
	
	if(move)
		free(move);
	
	return NULL;
}



void wd_move_file(char *from, char *to) {
	int			source = -1, destination = -1;
	ssize_t		bytes;
	char		buffer[BUFSIZ];
	
	/* open files */
	if((source = open(from, O_RDONLY, 0)) < 0)
		goto end;

	if((destination = open(to, O_CREAT | O_TRUNC | O_WRONLY, 0644)) < 0)
		goto end;

	/* do copy */
	while((bytes = read(source, buffer, sizeof(buffer))) > 0)
		write(destination, buffer, bytes);
	
	/* unlink source */
	unlink(from);

end:
	/* clean up */
	if(source > 0)
		close(source);
	
	if(destination > 0)
		close(destination);
}



#pragma mark -

void * wd_download_thread(void *arg) {
	wd_list_node_t		*node = arg;
	wd_transfer_t		*transfer;
	struct timeval		tv;
	FILE				*fp;
	char				buffer[8192];
	double				now, now_speed, last_speed, last_status;
	size_t				bytes, speed_bytes, stats_bytes;
	unsigned int		limit_me, limit_all;
	int					running = 1;
	
	/* get transfer */
	transfer = WD_LIST_DATA(node);
	
	/* update state */
	transfer->state = WD_TRANSFER_STATE_RUNNING;

	/* log */
	wd_log_l(LOG_INFO, "Sending \"%s\" to %s/%s/%s",
			 transfer->path,
			 transfer->nick, transfer->login, transfer->ip);

	/* open the file */
	fp = fopen(transfer->real_path, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			transfer->real_path, strerror(errno));
		
		goto end;
	}
	
	/* get limits */
	limit_me = wd_get_priv_int(transfer->login, WD_PRIV_DOWNLOAD_SPEED);
	
	/* get current time */
	gettimeofday(&tv, NULL);
	now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
		
	/* set initial values */
	last_speed = last_status = now;
	speed_bytes = stats_bytes = 0;
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_downloads++;
	wd_total_downloads++;
	wd_write_status();
	pthread_mutex_unlock(&wd_status_mutex);
	
	/* seek to requested position */
	fseeko(fp, transfer->offset, SEEK_SET);
	transfer->transferred = transfer->offset;
	
	while(running) {
		/* read data */
		bytes = fread(buffer, 1, sizeof(buffer), fp);
	
		if(bytes <= 0) {
			running = 0;
		
			continue;
		}
		
		/* write data */
		if(SSL_write(transfer->ssl, buffer, bytes) <= 0) {
			running = 0;
			
			continue;
		}

		/* get current time */
		gettimeofday(&tv, NULL);
		now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
		
		/* update status */
		transfer->transferred += bytes;
		speed_bytes += bytes;
		stats_bytes += bytes;
		
		/* update speed */
		transfer->speed = speed_bytes / (now - last_speed);
		
		/* limit speed? */
		if(limit_me > 0 || wd_settings.totaldownloadspeed > 0) {
			now_speed = now;
			limit_all = (double) wd_settings.totaldownloadspeed / wd_current_downloads;
			
			while((limit_me > 0 && transfer->speed > limit_me) ||
			      (limit_all > 0 && transfer->speed > limit_all)) {
				usleep(10000);
				now_speed += 0.01;

				transfer->speed = speed_bytes / (now_speed - last_speed);
			}
		}

		/* update speed */
		if(now - last_speed > 30.0) {
			/* reset */
			speed_bytes = 0;
			last_speed = now;
		}
		
		/* update status */
		if(now - last_status > 5.0) {
			/* write status */
			pthread_mutex_lock(&wd_status_mutex);
			wd_downloads_traffic += stats_bytes;
			wd_write_status();
			pthread_mutex_unlock(&wd_status_mutex);

			/* reset */
			stats_bytes = 0;
			last_status = now;
		}
	}
	
	/* update status */
	if(stats_bytes > 0) {
		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_downloads_traffic += stats_bytes;
		wd_write_status();
		pthread_mutex_unlock(&wd_status_mutex);
	}
	
	/* log */
	wd_log_l(LOG_INFO, "Sent %llu/%llu bytes of \"%s\" to %s/%s/%s",	
			 transfer->transferred - transfer->offset,
			 transfer->size,
			 transfer->path,
			 transfer->nick, transfer->login, transfer->ip);

end:
	/* clean up */
	if(SSL_shutdown(transfer->ssl) == 0)
		SSL_shutdown(transfer->ssl);
	
	SSL_free(transfer->ssl);

	close(transfer->sd);
	
	if(fp)
		fclose(fp);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_downloads--;
	wd_write_status();
	pthread_mutex_unlock(&wd_status_mutex);

	/* delete transfer */
	WD_LIST_LOCK(wd_transfers);
	wd_list_delete(&wd_transfers, node);
	WD_LIST_UNLOCK(wd_transfers);
	wd_update_queue();
	
	return NULL;
}



void * wd_upload_thread(void *arg) {
	wd_list_node_t		*node = arg;
	wd_transfer_t		*transfer;
	struct timeval		tv;
	FILE				*fp;
	char				buffer[8192], *path;
	double				now, now_speed, last_speed, last_status;
	size_t				bytes, speed_bytes, stats_bytes;
	unsigned int		limit_me, limit_all;
	int					running = 1;

	/* get transfer */
	transfer = WD_LIST_DATA(node);
	
	/* update state */
	transfer->state = WD_TRANSFER_STATE_RUNNING;

	/* log */
	wd_log_l(LOG_INFO, "Receiving \"%s\" from %s/%s/%s",
			 transfer->path,
			 transfer->nick, transfer->login, transfer->ip);

	/* open the file */
	fp = fopen(transfer->real_path, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			transfer->real_path, strerror(errno));
		
		goto end;
	}
	
	/* get limit */
	limit_me = wd_get_priv_int(transfer->login, WD_PRIV_UPLOAD_SPEED);
	
	/* get current time */
	gettimeofday(&tv, NULL);
	now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
		
	/* set initial values */
	last_speed = last_status = now;
	speed_bytes = stats_bytes = 0;
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_uploads++;
	wd_total_uploads++;
	wd_write_status();
	pthread_mutex_unlock(&wd_status_mutex);
	
	while(running) {
		/* read data */
		bytes = SSL_read(transfer->ssl, buffer, sizeof(buffer));
	
		if(bytes <= 0) {
			running = 0;
		
			continue;
		}
		
		/* write data */
		if(fwrite(buffer, 1, bytes, fp) <= 0) {
			running = 0;
			
			continue;
		}

		/* get current time */
		gettimeofday(&tv, NULL);
		now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
		
		/* update status */
		transfer->transferred += bytes;
		speed_bytes += bytes;
		stats_bytes += bytes;
		
		/* update speed */
		transfer->speed = speed_bytes / (now - last_speed);
		
		/* limit speed? */
		if(limit_me > 0 || wd_settings.totaluploadspeed > 0) {
			now_speed = now;
			limit_all = (double) wd_settings.totaluploadspeed / wd_current_uploads;
			
			while((limit_me > 0 && transfer->speed > limit_me) ||
			      (limit_all > 0 && transfer->speed > limit_all)) {
				usleep(10000);
				now_speed += 0.01;

				transfer->speed = speed_bytes / (now_speed - last_speed);
			}
		}

		/* update speed */
		if(now - last_speed > 30.0) {
			/* reset */
			speed_bytes = 0;
			last_speed = now;
		}
		
		/* update status */
		if(now - last_status > 5.0 * wd_current_uploads) {
			/* write status */
			pthread_mutex_lock(&wd_status_mutex);
			wd_uploads_traffic += stats_bytes;
			wd_write_status();
			pthread_mutex_unlock(&wd_status_mutex);

			/* reset */
			stats_bytes = 0;
			last_status = now;
		}
	}
	
	/* update status */
	if(stats_bytes > 0) {
		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_uploads_traffic += stats_bytes;
		wd_write_status();
		pthread_mutex_unlock(&wd_status_mutex);
	}
	
	/* log */
	wd_log_l(LOG_INFO, "Received %llu/%llu bytes of \"%s\" from %s/%s/%s",
			 transfer->transferred - transfer->offset,
			 transfer->size,
			 transfer->path,
			 transfer->nick, transfer->login, transfer->ip);
	
	/* move file */
	if(transfer->transferred == transfer->size) {
		path = strdup(transfer->real_path);
		path[strlen(path) - 14] = '\0';
		
		rename(transfer->real_path, path);
		
		free(path);
	}

end:
	/* clean up */
	if(SSL_shutdown(transfer->ssl) == 0)
		SSL_shutdown(transfer->ssl);
	
	SSL_free(transfer->ssl);

	close(transfer->sd);
	
	if(fp)
		fclose(fp);
	
	/* update status */
	pthread_mutex_lock(&wd_status_mutex);
	wd_current_uploads--;
	wd_write_status();
	pthread_mutex_unlock(&wd_status_mutex);

	/* delete transfer */
	WD_LIST_LOCK(wd_transfers);
	wd_list_delete(&wd_transfers, node);
	WD_LIST_UNLOCK(wd_transfers);
	wd_update_queue();
	
	return NULL;
}



void wd_update_queue(void) {
	wd_list_node_t		*client_node, *transfer_node;
	wd_transfer_t		*transfer;
	wd_client_t			*client;
	wd_chat_t			*chat;
	unsigned int		position_downloads, position_uploads;
	unsigned int		client_downloads, client_uploads;
	unsigned int		all_downloads, all_uploads;
	unsigned int		position;

	/* get public chat */
	chat = wd_get_chat(WD_PUBLIC_CHAT);
	
	/* lock lists */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_LOCK(wd_transfers);

	/* count total number of running transfers */
	all_downloads = all_uploads = 0;
	
	WD_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
		if(transfer->state != WD_TRANSFER_STATE_QUEUED) {
			/* total number of running transfers */
			if(transfer->type == WD_TRANSFER_DOWNLOAD)
				all_downloads++;
			else
				all_uploads++;
		}
	}

	/* loop over all clients */
	WD_LIST_FOREACH(chat->clients, client_node, client) {
		/* reset */
		position_downloads = position_uploads = 0;
		client_downloads = client_uploads = 0;

		/* count number of running transfers for this client */
		WD_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
			if(transfer->state != WD_TRANSFER_STATE_QUEUED && transfer->client == client) {
				if(transfer->type == WD_TRANSFER_DOWNLOAD)
					client_downloads++;
				else
					client_uploads++;
			}
		}

		/* traverse the queue */
		WD_LIST_FOREACH(wd_transfers, transfer_node, transfer) {
			/* reset */
			position = 0;
			
			/* this is the position in the queue */
			if(transfer->type == WD_TRANSFER_DOWNLOAD)
				position_downloads++;
			else
				position_uploads++;

			/* these are queued transfers belonging to this client */
			if(transfer->state == WD_TRANSFER_STATE_QUEUED && transfer->client == client) {
				/* calculate number in queue */
				if(transfer->type == WD_TRANSFER_DOWNLOAD) {
					if(all_downloads >= wd_settings.totaldownloads)
						position = position_downloads - all_downloads;
					else if(client_downloads >= wd_settings.clientdownloads)
						position = position_downloads - client_downloads;
				} else {
					if(all_uploads >= wd_settings.totaluploads)
						position = position_uploads - all_uploads;
					else if(client_uploads >= wd_settings.clientuploads)
						position = position_uploads - client_uploads;
				}
	
				if(position > 0) {
					if(transfer->queue != position) {
						/* update number in line */
						transfer->queue = position;
		
						pthread_mutex_lock(&(client->ssl_mutex));
						wd_sreply(client->ssl, 401, "%s%c%u",
								  transfer->path,
								  WD_FIELD_SEPARATOR,
								  transfer->queue);
						pthread_mutex_unlock(&(client->ssl_mutex));
					}
				} else {
					/* client's number just came up */
					transfer->queue = 0;
					transfer->state = WD_TRANSFER_STATE_WAITING;
					transfer->queue_time = time(NULL);
	
					pthread_mutex_lock(&(client->ssl_mutex));
					wd_sreply(client->ssl, 400, "%s%c%llu%c%s",
							  transfer->path,
							  WD_FIELD_SEPARATOR,
							  transfer->offset,
							  WD_FIELD_SEPARATOR,
							  transfer->hash);
					pthread_mutex_unlock(&(client->ssl_mutex));
					
					/* increase number of running transfers */
					if(transfer->type == WD_TRANSFER_DOWNLOAD) {
						all_downloads++;
						client_downloads++;
					} else {
						all_uploads++;
						client_uploads++;
					}
				}
			}
		}
	}
	
	/* unlock lists */
	WD_LIST_UNLOCK(wd_transfers);
	WD_LIST_UNLOCK(wd_chats);
}



void wd_update_transfers(void) {
	wd_list_node_t		*node, *node_next;
	wd_transfer_t		*transfer;
	time_t				now;
	bool				update = false;

	/* get time */
	now = time(NULL);

	/* loop over transfers and remove transfers waiting for more than 10 secs */
	WD_LIST_LOCK(wd_transfers);
	for(node = WD_LIST_FIRST(wd_transfers); node != NULL; node = node_next) {
		node_next = WD_LIST_NEXT(node);
		transfer = WD_LIST_DATA(node);
		
		if(transfer->state == WD_TRANSFER_STATE_WAITING && transfer->queue_time + 10 < now) {
			wd_list_delete(&wd_transfers, node);
			
			update = true;
		}
	}
	WD_LIST_UNLOCK(wd_transfers);
	
	/* update queue */
	if(update)
		wd_update_queue();
}



unsigned int wd_count_transfers(wd_transfer_type_t type) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_list_node_t	*node;
	wd_transfer_t	*transfer;
	unsigned int	count = 0;
	
	WD_LIST_LOCK(wd_transfers);
	WD_LIST_FOREACH(wd_transfers, node, transfer) {
		if(transfer->client == client && transfer->type == type)
			count++;
	}
	WD_LIST_UNLOCK(wd_transfers);
	
	return count;
}



void wd_queue_download(char *path, unsigned long long offset) {
	wd_client_t				*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_transfer_t			*transfer;
	struct stat				sb;
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			buffer[BUFSIZ], sha[SHA_DIGEST_LENGTH];
	char					real_path[MAXPATHLEN];
	int						i;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", path);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(real_path, real_path, sizeof(real_path));
#endif

	/* stat the actual file */
	if(stat(real_path, &sb) < 0) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			real_path, strerror(errno));
		wd_file_error();
		
		return;
	}
	
	/* create a transfer */
	transfer = (wd_transfer_t *) malloc(sizeof(wd_transfer_t));
	memset(transfer, 0, sizeof(wd_transfer_t));
	
	/* set values */
	transfer->client		= client;
	transfer->type			= WD_TRANSFER_DOWNLOAD;
	transfer->state			= WD_TRANSFER_STATE_QUEUED;
	transfer->size			= sb.st_size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	/* copy strings */
	strlcpy(transfer->nick, client->nick, sizeof(transfer->nick));
	strlcpy(transfer->login, client->login, sizeof(transfer->login));
	strlcpy(transfer->ip, client->ip, sizeof(transfer->ip));
	strlcpy(transfer->path, path, sizeof(transfer->path));
	strlcpy(transfer->real_path, real_path, sizeof(transfer->real_path));
	
	/* compute random hash for transfer */
	RAND_bytes(buffer, sizeof(buffer));
	SHA1_Init(&c);
	SHA1_Update(&c, buffer, sizeof(buffer));
	SHA1_Final(sha, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		transfer->hash[i+i]		= hex[sha[i] >> 4];
		transfer->hash[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	transfer->hash[i+i] = '\0';
	
	/* add to list */
	WD_LIST_LOCK(wd_transfers);
	wd_list_add(&wd_transfers, transfer);
	WD_LIST_UNLOCK(wd_transfers);
	
	/* update the queue */
	wd_update_queue();
}



void wd_queue_upload(char *path, unsigned long long size, char *checksum) {
	wd_client_t				*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_transfer_t			*transfer;
	struct stat				sb;
	FILE					*fp;
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			buffer[BUFSIZ], sha[SHA_DIGEST_LENGTH], output[SHA_DIGEST_LENGTH * 2 + 1];
	char					real_path[MAXPATHLEN], dir[MAXPATHLEN], base[MAXPATHLEN];
	size_t					bytes;
	unsigned long long		offset = 0;
	int						i, total = 0;
	
	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s.WiredTransfer", path);

	/* get the parent directory */
	strlcpy(dir, wd_dirname(real_path), sizeof(dir));
	strlcpy(base, wd_basename(real_path), sizeof(base));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* resolve mac alias */
	wd_apple_resolve_alias_path(dir, dir, sizeof(dir));
#endif
	
	/* create new real path */
	snprintf(real_path, sizeof(real_path), "%s/%s",
		dir,
		base);
	
	/* check for existing file to resume */
	if(stat(real_path, &sb) == 0) {
		fp = fopen(real_path, "r");
		
		if(!fp) {
			wd_log(LOG_WARNING, "Could not open %s: %s",
				real_path, strerror(errno));
			wd_reply(500, "Command Failed");
			
			return;
		}
		
		/* checksum the existing file */
		SHA1_Init(&c);
	
		if(sb.st_size >= WD_CHECKSUM_SIZE) {
			/* don't read the entire file for checksum, as that will
			   take quite some time */
			while((bytes = fread(buffer, 1, sizeof(buffer), fp))) {
				SHA1_Update(&c, buffer, bytes);
				total += bytes;
				
				if(total >= WD_CHECKSUM_SIZE)
					break;
			}
		}
		
		SHA1_Final(sha, &c);

		fclose(fp);
	
		if(total > 0) {
			/* map into hex characters */
			for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
				output[i+i]		= hex[sha[i] >> 4];
				output[i+i+1]	= hex[sha[i] & 0x0F];
			}
			
			output[i+i] = '\0';

			/* make sure they match */
			if(strcmp(checksum, output) != 0) {
				wd_reply(522, "Checksum mismatch");
				
				return;
			}
		}
			
		/* set new offset */
		offset = sb.st_size;
	}
	
	/* create a transfer */
	transfer = (wd_transfer_t *) malloc(sizeof(wd_transfer_t));
	memset(transfer, 0, sizeof(*transfer));
	
	/* set values */
	transfer->client		= client;
	transfer->type			= WD_TRANSFER_UPLOAD;
	transfer->state			= WD_TRANSFER_STATE_QUEUED;
	transfer->size			= size;
	transfer->offset		= offset;
	transfer->transferred	= offset;
	
	/* copy strings */
	strlcpy(transfer->nick, client->nick, sizeof(transfer->nick));
	strlcpy(transfer->login, client->login, sizeof(transfer->login));
	strlcpy(transfer->ip, client->ip, sizeof(transfer->ip));
	strlcpy(transfer->path, path, sizeof(transfer->path));
	strlcpy(transfer->real_path, real_path, sizeof(transfer->real_path));
	
	/* compute random hash for transfer */
	RAND_bytes(buffer, sizeof(buffer));
	SHA1_Init(&c);
	SHA1_Update(&c, buffer, sizeof(buffer));
	SHA1_Final(sha, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		transfer->hash[i+i]		= hex[sha[i] >> 4];
		transfer->hash[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	transfer->hash[i+i] = '\0';
	
	/* add to list */
	WD_LIST_LOCK(wd_transfers);
	wd_list_add(&wd_transfers, transfer);
	WD_LIST_UNLOCK(wd_transfers);
	
	/* update the queue */
	wd_update_queue();
}



#pragma mark -

wd_file_type_t wd_get_type(char *real_path, struct stat *sp) {
	FILE			*fp = NULL;
	struct stat		sb;
	char			type_path[MAXPATHLEN];
	wd_file_type_t	type = WD_FILE_TYPE_FILE;

	/* stat the file if we don't have a stat record already*/
	if(!sp) {
		if(stat(real_path, &sb) < 0)
			goto end;
		
		sp = &sb;
	}

	/* determine folder type */
	if(S_ISDIR(sp->st_mode)) {
		/* default to folder */
		type = WD_FILE_TYPE_DIR;

		/* open type file */
		snprintf(type_path, sizeof(type_path), "%s/.wired/type", real_path);
		fp = fopen(type_path, "r");
		
		if(!fp)
			goto end;
		
		/* get type */
		type = fgetc(fp) - '0';
		
		if(type < WD_FILE_TYPE_DIR || type > WD_FILE_TYPE_DROPBOX)
			type = WD_FILE_TYPE_DIR;
	}

end:
	/* clean up */
	if(fp)
		fclose(fp);
		
	return type;
}



void wd_set_type(char *path, wd_file_type_t type) {
	FILE		*fp = NULL;
	char		real_path[MAXPATHLEN], wired_path[MAXPATHLEN], type_path[MAXPATHLEN];
	
	/* test type */
	if(type < WD_FILE_TYPE_DIR || type > WD_FILE_TYPE_DROPBOX) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* get paths */
	snprintf(real_path, sizeof(real_path), ".%s", path);
	snprintf(wired_path, sizeof(wired_path), "%s/.wired", real_path);
	snprintf(type_path, sizeof(type_path), "%s/.wired/type", real_path);
	
	/* create .wired directory */
	if(mkdir(wired_path, 0755) < 0 && errno != EEXIST) {
		wd_log(LOG_ERR, "Could not create %s: %s",
			wired_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* open type */
	fp = fopen(type_path, "w");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			type_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}
	
	/* write type */
	fprintf(fp, "%u\n", type);

end:
	if(fp)
		fclose(fp);
}



#pragma mark -

void wd_get_comment(char *real_path, char *comment, size_t length) {
	FILE		*fp;
	char		dir[MAXPATHLEN], base[MAXPATHLEN], comment_path[MAXPATHLEN];
	char		each_file[255], each_comment[WD_COMMENT_SIZE];
	
	/* get paths */
	strlcpy(dir, wd_dirname(real_path), sizeof(dir));
	strlcpy(base, wd_basename(real_path), sizeof(base));
	snprintf(comment_path, sizeof(comment_path), "%s/.wired/comments", dir);
	
	/* default to empty */
	memset(comment, 0, sizeof(comment));
	
	/* open comments */
	fp = fopen(comment_path, "r");
	
	if(!fp)
		goto end;
	
	/* read each record */
	while((wd_fget_comment(fp, each_file, each_comment, sizeof(each_comment))) > 0) {
		if(strcmp(each_file, base) == 0) {
			strlcpy(comment, each_comment, length);
			
			break;
		}
	}

end:
	/* clean up */
	if(fp)
		fclose(fp);
}



void wd_set_comment(char *path, char *comment) {
	FILE		*fp = NULL, *tmp = NULL;
	char		dir[MAXPATHLEN], base[MAXPATHLEN], real_path[MAXPATHLEN], wired_path[MAXPATHLEN], comment_path[MAXPATHLEN];
	char		buffer[BUFSIZ], each_file[255], each_comment[WD_COMMENT_SIZE];
	size_t		bytes;
	
	/* get paths */
	snprintf(real_path, sizeof(real_path), ".%s", path);
	strlcpy(dir, wd_dirname(real_path), sizeof(dir));
	strlcpy(base, wd_basename(real_path), sizeof(base));
	snprintf(wired_path, sizeof(wired_path), "%s/.wired", dir);
	snprintf(comment_path, sizeof(comment_path), "%s/.wired/comments", dir);
	
	/* create .wired directory */
	if(mkdir(wired_path, 0755) < 0 && errno != EEXIST) {
		wd_log(LOG_ERR, "Could not create %s: %s",
			wired_path, strerror(errno));
		wd_file_error();
		
		goto end;
	}

	/* open comments */
	fp = fopen(comment_path, "r");
	
	/* open temp file */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_ERR, "Could not create temporary file: %s",
			strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* read each record */
	if(fp) {
		while((wd_fget_comment(fp, each_file, each_comment, sizeof(each_comment))) > 0) {
			if(strcmp(each_file, base) != 0) {
				fprintf(tmp, "%s%c%s%c",
					each_file,
					WD_FIELD_SEPARATOR,
					each_comment,
					WD_GROUP_SEPARATOR);
			}
		}
	}
	
	/* write modified record */
	fprintf(tmp, "%s%c%s%c",
			base,
			WD_FIELD_SEPARATOR,
			comment,
			WD_GROUP_SEPARATOR);
	
	/* re-open comments, clearing it */
	if(fp)
		fclose(fp);
		
	fp = fopen(comment_path, "w");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			comment_path, strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* now copy the entire temporary file to the comments file */
	while((bytes = fread(buffer, 1, sizeof(buffer), tmp)))
		fwrite(buffer, 1, bytes, fp);

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(tmp)
		fclose(tmp);
}



void wd_clear_comment(char *real_path) {
	FILE		*fp, *tmp = NULL;
	char		dir[MAXPATHLEN], base[MAXPATHLEN], comment_path[MAXPATHLEN];
	char		buffer[BUFSIZ], each_file[255], each_comment[WD_COMMENT_SIZE];
	size_t		bytes;
	
	/* get paths */
	strlcpy(dir, wd_dirname(real_path), sizeof(dir));
	strlcpy(base, wd_basename(real_path), sizeof(base));
	snprintf(comment_path, sizeof(comment_path), "%s/.wired/comments", dir);
	
	/* open comments */
	fp = fopen(comment_path, "r");
	
	if(!fp)
		goto end;
	
	/* open temp file */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_ERR, "Could not create temporary file: %s",
			strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* read each record, except the one to be cleared */
	while((wd_fget_comment(fp, each_file, each_comment, sizeof(each_comment))) > 0) {
		if(strcmp(each_file, base) != 0) {
			fprintf(tmp, "%s%c%s%c",
				each_file,
				WD_FIELD_SEPARATOR,
				each_comment,
				WD_GROUP_SEPARATOR);
		}
	}
	
	/* re-open comments, clearing it */
	fp = freopen(comment_path, "w", fp);
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			comment_path, strerror(errno));
		wd_file_error();

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* now copy the entire temporary file to the comments file */
	while((bytes = fread(buffer, 1, sizeof(buffer), tmp)))
		fwrite(buffer, 1, bytes, fp);

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(tmp)
		fclose(tmp);
}



void wd_move_comment(char *real_from, char *real_to) {
	char		from_comment_path[MAXPATHLEN];
	char		to_comment_path[MAXPATHLEN];
	char		comment[WD_COMMENT_SIZE];

	/* get paths */
	snprintf(from_comment_path, sizeof(from_comment_path), "%s/.wired/comments",
		wd_dirname(real_from));
	snprintf(to_comment_path, sizeof(to_comment_path), "%s/.wired/comments",
		wd_dirname(real_to));

	/* get comment from source */
	wd_get_comment(real_from, comment, sizeof(comment));
	
	/* clear comment from source */
	wd_clear_comment(real_from);

	/* set comment in destination */
	if(strlen(comment) > 0)
		wd_set_comment(real_to, comment);
}



int wd_fget_comment(FILE *fp, char *file, char *comment, size_t length) {
	size_t	i;
	int		ch;
	
	for(i = 0; i < 255 && (ch = fgetc(fp)) != EOF && ch != 28; i++)
		file[i] = ch;
	
	file[i] = '\0';

	for(i = 0; i < length && (ch = fgetc(fp)) != EOF && ch != 29; i++)
		comment[i] = ch;
	
	comment[i] = '\0';
	
	return i;
}



#pragma mark -

bool wd_path_is_valid(char *path) {
	if(path[0] == '.')
		return -1;
	
    if(strstr(path, "../") != NULL)
        return -1;

    if(strstr(path, "/..") != NULL)
        return -1;
    
    if(strcmp(path, "..") == 0)
        return -1;
	
	return 1;
}



bool wd_path_is_dropbox(char *path) {
	char			dir[MAXPATHLEN], real_path[MAXPATHLEN];
	char			*p, *ap;
	wd_file_type_t	type;
	
	/* get paths */
	strlcpy(dir, wd_dirname(path), sizeof(dir));
	strlcpy(real_path, ".", sizeof(real_path));
	
	/* loop over path components */
	p = dir + 1;
	
	while((ap = strsep(&p, "/"))) {
		/* extend real path */
		snprintf(real_path, sizeof(real_path), "%s/%s", real_path, ap);
		
		/* get file type */
		type = wd_get_type(real_path, NULL);
		
		if(type == WD_FILE_TYPE_DROPBOX)
			return true;
	}
	
	return false;
}



char * wd_basename(char *path) {
	char	real_path[MAXPATHLEN];
	
	strlcpy(real_path, path, sizeof(real_path));
	
	return basename(real_path);
}



char * wd_dirname(char *path) {
	char	real_path[MAXPATHLEN];
	
	strlcpy(real_path, path, sizeof(real_path));
	
	return dirname(real_path);
}



int wd_fts_namecmp(const FTSENT **a, const FTSENT **b) {
	return (strcasecmp((*a)->fts_name, (*b)->fts_name));
}



void wd_file_error(void) {
	switch(errno) {
		case ENOENT:
			wd_reply(520, "File or Directory Not Found");
			break;
		
		case EEXIST:
			wd_reply(521, "File or Directory Exists");
			break;
		
		default:
			wd_reply(500, "Command Failed");
			break;
	}
}
