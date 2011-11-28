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

#ifndef WD_FILES_H
#define WD_FILES_H 1

#include <sys/types.h>
#include <sys/stat.h>
#include <fts.h>
#include <stdbool.h>
#include <openssl/sha.h>
#include <openssl/ssl.h>

#include "server.h"
#include "utility.h"


enum wd_file_type {
	WD_FILE_TYPE_FILE				= 0,
	WD_FILE_TYPE_DIR,
	WD_FILE_TYPE_UPLOADS,
	WD_FILE_TYPE_DROPBOX
};
typedef enum wd_file_type			wd_file_type_t;


enum wd_transfer_type {
	WD_TRANSFER_DOWNLOAD			= 0,
	WD_TRANSFER_UPLOAD
};
typedef enum wd_transfer_type		wd_transfer_type_t;


enum wd_transfer_state {
	WD_TRANSFER_STATE_QUEUED		= 0,
	WD_TRANSFER_STATE_WAITING,
	WD_TRANSFER_STATE_RUNNING
};
typedef enum wd_transfer_state		wd_transfer_state_t;


#define WD_COMMENT_SIZE				4096
#define WD_CHECKSUM_SIZE			1048576


struct wd_transfer {
	int								sd;
	SSL								*ssl;

	wd_client_t						*client;
	char							nick[WD_NICK_SIZE];
	char							login[WD_LOGIN_SIZE];
	char							ip[16];

	char							path[MAXPATHLEN];
	char							real_path[MAXPATHLEN];
	char							hash[SHA_DIGEST_LENGTH * 2 + 1];
	
	wd_transfer_type_t				type;
	wd_transfer_state_t				state;
	unsigned int					queue;
	time_t							queue_time;

	unsigned long long				offset;
	unsigned long long				size;
	unsigned long long				transferred;
	unsigned int					speed;
};
typedef struct wd_transfer			wd_transfer_t;


struct wd_move_record {
	char							from[MAXPATHLEN];
	char							to[MAXPATHLEN];
};
typedef struct wd_move_record		wd_move_record_t;


void								wd_list_path(char *);
unsigned long long					wd_count_path(char *);
void								wd_stat_path(char *);
void								wd_create_path(char *);
int									wd_delete_path(char *);
int									wd_delete_paths(char *);
void								wd_move_path(char *, char *);

void								wd_search_files(char *);
void								wd_search_files_path(char *, char *, bool, char *);
void								wd_search_files_index(char *);

void								wd_index_files(void);
void *								wd_index_files_thread(void *);
void								wd_index_files_path(char *, bool, FILE *, char *);

void *								wd_move_thread(void *);
void								wd_move_file(char *, char *);

void *								wd_download_thread(void *);
void *								wd_upload_thread(void *);
void								wd_update_queue(void);
void								wd_update_transfers(void);
unsigned int						wd_count_transfers(wd_transfer_type_t);
void								wd_queue_download(char *, unsigned long long);
void								wd_queue_upload(char *, unsigned long long, char *);

wd_file_type_t						wd_get_type(char *, struct stat *);
void								wd_set_type(char *, wd_file_type_t);

void								wd_get_comment(char *, char *, size_t);
void								wd_set_comment(char *, char *);
void								wd_move_comment(char *, char *);
void								wd_clear_comment(char *);
int									wd_fget_comment(FILE *, char *, char *, size_t);

bool								wd_path_is_valid(char *);
bool								wd_path_is_dropbox(char *);
char *								wd_basename(char *);
char *								wd_dirname(char *);
int									wd_fts_namecmp(const FTSENT **, const FTSENT **);
void								wd_file_error(void);


extern wd_list_t					wd_transfers;

extern unsigned int					wd_files_count;
extern unsigned long long			wd_files_size;

#endif /* WD_FILES_H */
