/* $Id$ */

/*
 *  Copyright (c) 2004-2007 Axel Andersson
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

#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>

#ifndef __GLIBC__
#include <dirent.h>
#include <glob.h>
#endif

#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "files.h"
#include "main.h"

#include "windows.h"

struct _wr_file {
	wi_runtime_base_t				base;
	
	wr_file_type_t					type;
	wi_file_offset_t				size;
	
	wi_string_t						*name;
	wi_string_t						*path;
};

#ifndef __GLIBC__
struct _wr_files_glob_dir {
	wi_string_t						*path;
	struct dirent					**entries;
	wi_uinteger_t					count, offset;
};
typedef struct _wr_files_glob_dir	wr_files_glob_dir_t;
#endif


static wi_array_t *					wr_files_glob(wi_string_t *);
#ifndef __GLIBC__
static void *						wr_files_glob_opendir(const char *);
static struct dirent *				wr_files_glob_readdir(void *);
static void							wr_files_glob_closedir(void *);
static int							wr_files_glob_stat(const char *, struct stat *);
#endif

static void							wr_file_dealloc(wi_runtime_instance_t *);
static wi_string_t *				wr_file_description(wi_runtime_instance_t *);

wi_string_t *						wr_files_cwd;
wi_string_t *						wr_files_ld;
wi_array_t							*wr_files;

wr_ls_state_t						wr_ls_state;
wr_stat_state_t						wr_stat_state;

static wi_runtime_id_t				wr_file_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_file_runtime_class = {
	"wr_file_t",
	wr_file_dealloc,
	NULL,
	NULL,
	wr_file_description,
	NULL
};


void wr_files_init(void) {
	wr_file_runtime_id = wi_runtime_register_class(&wr_file_runtime_class);

	wr_files = wi_array_init(wi_array_alloc());
	
	wr_files_cwd = wi_string_init_with_cstring(wi_string_alloc(), "/");
}



void wr_files_clear(void) {
	wi_array_remove_all_data(wr_files);
	
	wi_release(wr_files_ld);
	wr_files_ld = NULL;
}



#pragma mark -

char * wr_readline_filename_generator(const char *text, int state) {
	static wi_string_t		*directory_path;
	static wi_uinteger_t	index;
	wi_string_t				*path, *full_path, *name;
	wr_file_t				*file;
	char					*cname;
	wi_boolean_t			root;
	wi_uinteger_t			count;
	
	cname = ((*rl_filename_dequoting_function) ((char *) text, 0));
	path = wi_string_with_cstring(cname);
	free(cname);
	
	if(state == 0) {
		wi_release(directory_path);
		
		directory_path	= wi_retain(wi_string_by_deleting_last_path_component(path));
		full_path		= wr_files_full_path(directory_path);
		index			= 0;

		wr_files_clear();
		wr_send_command(WI_STR("LIST %@"), full_path);
		wr_runloop_run_for_socket(wr_socket, 3.0, 411);
	}

	name = wi_string_last_path_component(path);
	root = wi_is_equal(name, WI_STR("/"));
	count = wi_array_count(wr_files);

	while(index < count) {
		file = WI_ARRAY(wr_files, index++);

		if(file->type == WR_FILE_FILE && wr_ls_state == WR_LS_COMPLETING_DIRECTORY)
			continue;

		if(root || wi_string_index_of_string(file->name, name, WI_STRING_SMART_CASE_INSENSITIVE) == 0) {
			rl_completion_append_character = (file->type != WR_FILE_FILE) ? '/' : ' ';

			full_path = wi_string_by_appending_path_component(directory_path, file->name);

			return strdup(wi_string_cstring(full_path));
		}
	}
	
	return NULL;
}



#pragma mark -

wi_string_t * wr_files_full_path(wi_string_t *path) {
	wi_string_t		*fullpath;
	
	if(wi_string_has_prefix(path, WI_STR("/")))
		fullpath = wi_autorelease(wi_copy(path));
	else
		fullpath = wi_string_by_appending_path_component(wr_files_cwd, path);

	wi_string_normalize_path(fullpath);
	
	return fullpath;
}



wi_array_t * wr_files_full_paths(wi_array_t *paths) {
	wi_enumerator_t	*enumerator, *glob_enumerator;
	wi_array_t		*array, *globpaths;
	wi_string_t		*path, *globpath;
	
	array = wi_array_init_with_capacity(wi_array_alloc(), wi_array_count(paths));
	enumerator = wi_array_data_enumerator(paths);
	
	while((path = wi_enumerator_next_data(enumerator))) {
		globpaths = wr_files_glob(path);
		
		if(globpaths) {
			glob_enumerator = wi_array_data_enumerator(wr_files_glob(path));
			
			while((globpath = wi_enumerator_next_data(glob_enumerator)))
				wi_array_add_data(array, wr_files_full_path(globpath));
		}
	}
	
	return wi_autorelease(array);
}



wi_string_t * wr_files_string_for_size(wi_file_offset_t size) {
	double      kb, mb, gb, tb, pb;

	if(size < 1024) {
		return wi_string_with_format(WI_STR("%llu %@"),
			size,
			size == 1
				? WI_STR("byte")
				: WI_STR("bytes"));
	}

	kb = size / 1024.0;

	if(kb < 1000.0)
		return wi_string_with_format(WI_STR("%.1f KB"), kb);

	mb = kb / 1024;

	if(mb < 1000.0)
		return wi_string_with_format(WI_STR("%.1f MB"), mb);

	gb = mb / 1024;

    if(gb < 1000.0)
		return wi_string_with_format(WI_STR("%.1f GB"), gb);

	tb = gb / 1024;

	if(tb < 1000.0)
		return wi_string_with_format(WI_STR("%.1f TB"), tb);

	pb = tb / 1024;

	if(pb < 1000.0)
		return wi_string_with_format(WI_STR("%.1f PB"), pb);

	return wi_string_with_cstring("");
}



wi_string_t * wr_files_string_for_count(wi_uinteger_t count) {
	return wi_string_with_format(WI_STR("%u %@"),
		count,
		count == 1
			? WI_STR("item")
			: WI_STR("items"));
}



#pragma mark -

static wi_array_t * wr_files_glob(wi_string_t *pattern) {
#ifdef __GLIBC__
	return wi_autorelease(wi_array_init_with_data(wi_array_alloc(), pattern, NULL));
#else
	wi_array_t		*array;
	glob_t			gl;
	wi_uinteger_t	i;
	int				status;
	
	gl.gl_opendir	= wr_files_glob_opendir;
	gl.gl_readdir	= wr_files_glob_readdir;
	gl.gl_closedir	= wr_files_glob_closedir;
	gl.gl_lstat		= wr_files_glob_stat;
	gl.gl_stat		= wr_files_glob_stat;
	
	status = glob(wi_string_cstring(pattern), GLOB_NOCHECK | GLOB_ALTDIRFUNC, NULL, &gl);
	
	if(status != 0) {
		wr_printf_prefix(WI_STR("glob: %s"), strerror(errno));
		
		return NULL;
	}
	
	array = wi_array_init_with_capacity(wi_array_alloc(), gl.gl_pathc);
	
	for(i = 0; i < (wi_uinteger_t) gl.gl_pathc; i++)
		wi_array_add_data(array, wi_string_with_cstring(gl.gl_pathv[i]));
	
	globfree(&gl);
	
	return wi_autorelease(array);
#endif
}



#ifndef __GLIBC__

static void * wr_files_glob_opendir(const char *path) {
	wr_files_glob_dir_t		*dir;
	wr_file_t				*file;
	wi_uinteger_t			i;
	
	dir = wi_malloc(sizeof(wr_files_glob_dir_t));
	dir->path = wi_retain(wr_files_full_path(wi_string_with_cstring(path)));
	
	wr_ls_state = WR_LS_GLOBBING;
	wr_files_clear();
	wr_send_command(WI_STR("LIST %@"), dir->path);
	wr_runloop_run_for_socket(wr_socket, 3.0, 411);
	
	dir->count = wi_array_count(wr_files);
	dir->entries = wi_malloc(sizeof(struct dirent) * (dir->count + 1));
	
	for(i = 0; i < dir->count; i++) {
		file = WI_ARRAY(wr_files, i);

		dir->entries[i] = wi_malloc(sizeof(struct dirent));
		dir->entries[i]->d_ino = 0;
		dir->entries[i]->d_reclen = 0;
		dir->entries[i]->d_type = (file->type == WR_FILE_FILE) ? DT_REG : DT_DIR;
		dir->entries[i]->d_namlen = wi_string_length(file->name);
		
		strlcpy(dir->entries[i]->d_name, wi_string_cstring(file->name), sizeof(dir->entries[i]->d_name));
	}

	return dir;
}



static struct dirent * wr_files_glob_readdir(void *p) {
	wr_files_glob_dir_t		*dir = p;

	return dir->entries[dir->offset++];
}



static void wr_files_glob_closedir(void *p) {
	wr_files_glob_dir_t		*dir = p;
	wi_uinteger_t			i;
	
	wi_release(dir->path);
	
	for(i = 0; i < dir->count; i++)
		wi_free(dir->entries[i]);
	
	wi_free(dir->entries);
	wi_free(dir);
}



static int wr_files_glob_stat(const char *path, struct stat *sp) {
	memset(sp, 0, sizeof(struct stat));
	
	return 0;
}

#endif



#pragma mark -

wr_file_t * wr_file_alloc(void) {
	return wi_runtime_create_instance(wr_file_runtime_id, sizeof(wr_file_t));
}



wr_file_t * wr_file_init_with_arguments(wr_file_t *file, wi_array_t *arguments) {
	file->type = wi_string_uint32(WI_ARRAY(arguments, 1));
	file->size = wi_string_uint32(WI_ARRAY(arguments, 2));
	file->path = wi_retain(WI_ARRAY(arguments, 0));
	file->name = wi_retain(wi_string_last_path_component(file->path));

	return file;
}



static void wr_file_dealloc(wi_runtime_instance_t *instance) {
	wr_file_t		*file = instance;
	
	wi_release(file->name);
	wi_release(file->path);
}



static wi_string_t * wr_file_description(wi_runtime_instance_t *instance) {
	wr_file_t		*file = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@}"),
		wi_runtime_class_name(file),
		file,
		file->name);
}



#pragma mark -

wr_file_type_t wr_file_type(wr_file_t *file) {
	return file->type;
}



wi_file_offset_t wr_file_size(wr_file_t *file) {
	return file->size;
}



wi_string_t * wr_file_name(wr_file_t *file) {
	return file->name;
}



wi_string_t * wr_file_path(wr_file_t *file) {
	return file->path;
}
