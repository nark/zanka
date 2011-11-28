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
#include <stdbool.h>
#include <openssl/sha.h>
#include <openssl/ssl.h>

#include "server.h"


#define WD_FILE_TYPE_FILE			0
#define WD_FILE_TYPE_DIR			1
#define WD_FILE_TYPE_UPLOADS		2
#define WD_FILE_TYPE_DROPBOX		3

#define WD_CHECKSUM_SIZE			1048576

#define WD_XFER_DOWNLOAD			0
#define WD_XFER_UPLOAD				1

#define WD_XFER_STATE_WAITING		0
#define WD_XFER_STATE_QUEUED		1
#define WD_XFER_STATE_RUNNING		2


struct wd_transfer {
	int								sd;
	SSL								*ssl;

	struct wd_client				*client;
	char							nick[WD_NICK_SIZE];
	char							login[WD_LOGIN_SIZE];
	char							ip[16];

	char							path[MAXPATHLEN];
	char							real_path[MAXPATHLEN];
	char							hash[SHA_DIGEST_LENGTH * 2 + 1];
	
	unsigned int					type;
	unsigned int					state;
	unsigned long long				offset;
	unsigned long long				size;
	unsigned long long				transferred;
	unsigned int					speed;
	unsigned int					queue;
	time_t							queue_time;
};


struct wd_move {
	char							from[MAXPATHLEN];
	char							to[MAXPATHLEN];
};


void								wd_list_path(char *);
unsigned long long					wd_count_path(char *);
void								wd_stat_path(char *);
void								wd_create_path(char *);
int									wd_delete_path(char *);
int									wd_delete_paths(char *);
void								wd_move_path(char *, char *);
void								wd_search(char *, char *, bool);
void								wd_update_files(char *, bool);

void *								wd_copy_thread(void *);
void								wd_copy_file(char *, char *);

void *								wd_download_thread(void *);
void *								wd_upload_thread(void *);
void								wd_update_queue(void);
void								wd_update_transfers(void);
void								wd_queue_download(char *, unsigned long long);
void								wd_queue_upload(char *, unsigned long long, char *);

unsigned int						wd_file_type(char *, struct stat *);
int									wd_evaluate_path(char *);
void								wd_file_error(void);


extern struct wd_list				wd_transfers;

extern unsigned int					wd_files_count;
extern unsigned long long			wd_files_size;

#endif /* WD_FILES_H */
