/* $Id$ */

/*
 *  Copyright (c) 2004-2006 Axel Andersson
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

#include <stdio.h>
#include <stdlib.h>
#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "files.h"
#include "main.h"

static void							wr_file_dealloc(wi_runtime_instance_t *);
static wi_string_t *				wr_file_description(wi_runtime_instance_t *);

wi_string_t *						wr_files_cwd;
wi_string_t *						wr_files_ld;
wi_list_t							*wr_files;

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


void wr_init_files(void) {
	wr_file_runtime_id = wi_runtime_register_class(&wr_file_runtime_class);

	wr_files = wi_list_init(wi_list_alloc());
	
	wr_files_cwd = wi_string_init_with_cstring(wi_string_alloc(), "/");
}



void wr_clear_files(void) {
	wi_list_remove_all_data(wr_files);
	
	wi_release(wr_files_ld);
	wr_files_ld = NULL;
}



#pragma mark -

char * wr_readline_filename_generator(const char *text, int state) {
	static wi_list_node_t	*node;
	static wi_string_t		*directory_path;
	wi_string_t				*path, *full_path, *name;
	wr_file_t				*file;
	char					*cname;
	wi_boolean_t			root;
	
	cname = ((*rl_filename_dequoting_function) ((char *) text, 0));
	path = wi_string_with_cstring(cname);
	free(cname);
	
	if(state == 0) {
		wi_release(directory_path);
		
		directory_path	= wi_retain(wi_string_by_deleting_last_path_component(path));
		full_path		= wr_files_full_path(directory_path);

		wr_clear_files();
		wr_send_command(WI_STR("LIST %@"), full_path);
		wr_runloop_run_for_socket(wr_socket, 3.0, 411);

		node = wi_list_first_node(wr_files);
	}

	name = wi_string_last_path_component(path);
	root = wi_is_equal(name, WI_STR("/"));

	while(node) {
		file = wi_list_node_data(node);
		node = wi_list_node_next_node(node);

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



wi_string_t * wr_files_string_for_count(unsigned int count) {
	return wi_string_with_format(WI_STR("%u %@"),
		count,
		count == 1
			? WI_STR("item")
			: WI_STR("items"));
}



#pragma mark -

wr_file_t * wr_file_alloc(void) {
	return wi_runtime_create_instance(wr_file_runtime_id, sizeof(wr_file_t));
}



wr_file_t * wr_file_init(wr_file_t *file) {
	return file;
}



static void wr_file_dealloc(wi_runtime_instance_t *instance) {
	wr_file_t		*file = instance;
	
	wi_release(file->name);
	wi_release(file->path);
}



static wi_string_t * wr_file_description(wi_runtime_instance_t *instance) {
	wr_file_t		*file = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{name = %@}"),
		wi_runtime_class_name(file),
		file,
		file->name);
}
