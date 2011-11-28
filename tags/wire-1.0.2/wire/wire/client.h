/* $Id$ */

/*
 *  Copyright (c) 2004 Axel Andersson
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

#ifndef WR_CLIENT_H
#define WR_CLIENT_H 1

#include <sys/param.h>
#include <stdbool.h>
#include <netinet/in.h>
#include <netdb.h>
#include <regex.h>
#include <openssl/sha.h>
#include <openssl/ssl.h>

#include "utility.h"


enum wr_file_type {
	WR_FILE_FILE					= 0,
	WR_FILE_DIRECTORY,
	WR_FILE_UPLOADS,
	WR_FILE_DROPBOX
};
typedef enum wr_file_type			wr_file_type_t;


enum wr_ls_state {
	WR_LS_NOTHING					= 0,
	WR_LS_LISTING,
	WR_LS_COMPLETING,
	WR_LS_COMPLETING_DIRECTORY
};
typedef enum wr_ls_state			wr_ls_state_t;


enum wr_stat_state {
	WR_STAT_NOTHING					= 0,
	WR_STAT_FILE,
	WR_STAT_TRANSFER
};
typedef enum wr_stat_state			wr_stat_state_t;


enum wr_transfer_type {
	WR_TRANSFER_DOWNLOAD			= 0,
	WR_TRANSFER_UPLOAD
};
typedef enum wr_transfer_type		wr_transfer_type_t;


enum wr_transfer_state {
	WR_TRANSFER_WAITING				= 0,
	WR_TRANSFER_QUEUED,
	WR_TRANSFER_RUNNING
};
typedef enum wr_transfer_state		wr_transfer_state_t;


#define WR_MESSAGE_SEPARATOR		"\4"
#define WR_FIELD_SEPARATOR			"\34"
#define WR_GROUP_SEPARATOR			"\35"
#define WR_RECORD_SEPARATOR			"\36"

#define WR_PROTOCOL					1.0

#define WR_BUFFER_SIZE				1024
#define WR_SERVER_SIZE				256
#define WR_NICK_SIZE				256
#define WR_LOGIN_SIZE				256
#define WR_PASSWORD_SIZE			256
#define WR_TOPIC_SIZE				256
#define WR_CHECKSUM_SIZE			1048576

#define WR_REGEXP_SIZE				128


typedef unsigned int				wr_uid_t;
typedef unsigned int				wr_icon_t;

struct wr_user {
	wr_uid_t						uid;
	bool							idle;
	bool							admin;
	wr_icon_t						icon;
	char							nick[WR_NICK_SIZE];
	char							login[WR_LOGIN_SIZE];
	char							ip[15];
};
typedef struct wr_user				wr_user_t;


struct wr_file {
	wr_file_type_t					type;
	unsigned long long				size;
	char							path[MAXPATHLEN];
	char							name[MAXPATHLEN];
};
typedef struct wr_file				wr_file_t;


typedef unsigned int				wr_tid_t;

struct wr_transfer {
	wr_tid_t						tid;
	wr_transfer_state_t				state;
	wr_transfer_type_t				type;
	
	int								sd;
	SSL								*ssl;
	FILE							*fp;
	
	char							path[MAXPATHLEN];
	char							local_path[MAXPATHLEN];
	char							local_path_partial[MAXPATHLEN];

	char							hash[SHA_DIGEST_LENGTH * 2 + 1];
	char							checksum[SHA_DIGEST_LENGTH * 2 + 1];
	
	unsigned int					queue;
	time_t							start_time;
	
	unsigned long long				offset;
	unsigned long long				size;
	unsigned long long				transferred;
	unsigned int					speed;
};
typedef struct wr_transfer			wr_transfer_t;


typedef unsigned int				wr_iid_t;

struct wr_ignore {
	wr_iid_t						iid;
	char							string[WR_REGEXP_SIZE];
	regex_t							regex;
};
typedef struct wr_ignore			wr_ignore_t;


void								wr_init_ssl(void);

wr_user_t *							wr_get_user(wr_uid_t);
wr_user_t *							wr_get_user_with_nick(char *);
wr_transfer_t *						wr_get_transfer(char *);
wr_transfer_t *						wr_get_transfer_with_sd(int);
wr_transfer_t *						wr_get_transfer_with_tid(wr_tid_t);

char *								wr_rl_nickname_generator(const char *, int);
char *								wr_rl_filename_generator(const char *, int);
char *								wr_rl_ignore_generator(const char *, int);

void								wr_connect(char *, int, char *, char *);
void								wr_close(void);
void								wr_close_transfer(wr_transfer_t *);

int									wr_parse_message(char *);
void								wr_send_command(char *, ...);
void								wr_send_command_on_ssl(SSL *, char *, ...);

void								wr_msg_200(int, char **);
void								wr_msg_201(int, char **);
void								wr_msg_300(int, char **);
void								wr_msg_301(int, char **);
void								wr_msg_302(int, char **);
void								wr_msg_303(int, char **);
void								wr_msg_304(int, char **);
void								wr_msg_305(int, char **);
void								wr_msg_306(int, char **);
void								wr_msg_307(int, char **);
void								wr_msg_308(int, char **);
void								wr_msg_309(int, char **);
void								wr_msg_310(int, char **);
void								wr_msg_311(int, char **);
void								wr_msg_320(int, char **);
void								wr_msg_321(int, char **);
void								wr_msg_322(int, char **);
void								wr_msg_341(int, char **);
void								wr_msg_400(int, char **);
void								wr_msg_401(int, char **);
void								wr_msg_402(int, char **);
void								wr_msg_410(int, char **);
void								wr_msg_411(int, char **);


extern char							wr_host[MAXHOSTNAMELEN];
extern int							wr_port;
extern char							wr_server[WR_SERVER_SIZE];
extern float						wr_protocol;
extern char							wr_nick[WR_NICK_SIZE];
extern unsigned int					wr_icon;
extern char							wr_login[WR_LOGIN_SIZE];
extern char							wr_password[WR_PASSWORD_SIZE];
extern char							wr_password_sha[SHA_DIGEST_LENGTH * 2 + 1];
extern char							wr_topic[WR_TOPIC_SIZE];

extern unsigned long long			wr_received_bytes;
extern unsigned long long			wr_transferred_bytes;

extern int							wr_news_count;
extern int							wr_news_limit;

extern wr_ls_state_t				wr_ls_state;
extern wr_stat_state_t				wr_stat_state;

extern char							wr_files_cwd[MAXPATHLEN];
extern char							wr_files_ld[MAXPATHLEN];
extern wr_list_t					wr_files;

extern wr_list_t					wr_users;

extern wr_list_t					wr_transfers;

extern wr_list_t					wr_ignores;

extern int							wr_socket;
extern struct sockaddr_in			wr_addr;

extern bool							wr_connected;

extern wr_uid_t						wr_reply_uid;

extern SSL_CTX						*wr_ssl_ctx;
extern SSL							*wr_ssl;

#endif /* WR_CLIENT_H */
