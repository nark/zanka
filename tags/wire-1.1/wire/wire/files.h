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

#ifndef WR_FILES_H
#define WR_FILES_H 1

enum _wr_file_type {
	WR_FILE_FILE					= 0,
	WR_FILE_DIRECTORY,
	WR_FILE_UPLOADS,
	WR_FILE_DROPBOX
};
typedef enum _wr_file_type			wr_file_type_t;


struct _wr_file {
	wi_runtime_base_t				base;
	
	wr_file_type_t					type;
	wi_file_offset_t				size;
	
	wi_string_t						*name;
	wi_string_t						*path;
};
typedef struct _wr_file				wr_file_t;


enum _wr_ls_state {
	WR_LS_NOTHING					= 0,
	WR_LS_LISTING,
	WR_LS_COMPLETING,
	WR_LS_COMPLETING_DIRECTORY
};
typedef enum _wr_ls_state			wr_ls_state_t;


enum _wr_stat_state {
	WR_STAT_NOTHING					= 0,
	WR_STAT_FILE,
	WR_STAT_TRANSFER
};
typedef enum _wr_stat_state			wr_stat_state_t;


void								wr_init_files(void);
void								wr_clear_files(void);

char *								wr_readline_filename_generator(const char *, int);

wi_string_t *						wr_files_full_path(wi_string_t *);
wi_string_t *						wr_files_string_for_size(wi_file_offset_t);
wi_string_t *						wr_files_string_for_count(unsigned int);

wr_file_t *							wr_file_alloc(void);
wr_file_t *							wr_file_init(wr_file_t *);


extern wi_string_t					*wr_files_cwd;
extern wi_string_t					*wr_files_ld;
extern wi_list_t					*wr_files;

extern wr_ls_state_t				wr_ls_state;
extern wr_stat_state_t				wr_stat_state;

#endif /* WR_FILES_H */
