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

#ifndef WD_HOTLINE_H
#define WD_HOTLINE_H 1

#include <sys/param.h>
#include <sys/types.h>
#include <iconv.h>

#include "server.h"


struct hl_transaction {
	unsigned char					flags;
	unsigned char					is_reply;
	unsigned short					type;
	unsigned long					id;
	unsigned long					error;
	unsigned long					total_size;
	unsigned long					data_size;
};


struct hl_parameters {
	unsigned short					count;
};


struct hl_field {
	unsigned short					id;
	unsigned short					size;
};


struct hl_client {
	int								sd;
	pthread_t						thread;
	
	unsigned short					version;
	unsigned short					uid;
	unsigned int					state;
	
	unsigned char					nick[WD_NICK_SIZE];
	unsigned char					login[WD_LOGIN_SIZE];
	unsigned char					ip[16];
	unsigned char					host[MAXHOSTNAMELEN];
	int								port;
	unsigned char					buffer[WD_BUFFER_SIZE];
	
	unsigned short					icon;
	unsigned int					idle;
	unsigned int					admin;
	
	time_t							login_time;
	time_t							idle_time;
};


void								hl_init_server(void);

void *								hl_ctl_listen_thread(void *);
void *								hl_ctl_thread(void *);

void								hl_update_clients(void);

int								 	hl_cmd_chat(void);
int									hl_cmd_error(void);
int									hl_cmd_info(void);
int									hl_cmd_login(void);
int									hl_cmd_msg(void);
int									hl_cmd_news(void);
int									hl_cmd_nick(void);
int									hl_cmd_who(void);

void								wd_hl_ban(unsigned long uid);
void								wd_hl_info(unsigned long uid);
void								wd_hl_kick(unsigned long uid);
void								wd_hl_who(unsigned long);

void								hl_wd_relay_join(struct hl_client *);
void								wd_hl_relay_join(unsigned long, char *, unsigned long, bool, bool);
void								hl_wd_relay_leave(struct hl_client *);
void								wd_hl_relay_leave(unsigned long);
void								hl_wd_relay_me(struct hl_client *, char *);
void								wd_hl_relay_me(char *, char *);
void								hl_wd_relay_msg(struct hl_client *, unsigned int , char *);
void								wd_hl_relay_msg(unsigned int, unsigned, char *, char *);
void								hl_wd_relay_nick(struct hl_client *);
void								wd_hl_relay_nick(unsigned long, char *, unsigned long, unsigned int, unsigned int);
void								hl_wd_relay_say(struct hl_client *, char *);
void								wd_hl_relay_say(char *, char *);

void								hl_convert_buffer(iconv_t, char *, size_t);

struct hl_client *					hl_get_client(unsigned short);
void								hl_delete_client(struct hl_client *);

void								hl_send_transaction(int, int, int, int, int, int);
void								hl_send_parameters(int, int);
void								hl_send_field(int, int, int);
void								hl_send_buffer(int, char *, size_t);
int									hl_read_transaction(struct hl_transaction *);
int									hl_read_parameters(struct hl_parameters *);
int									hl_read_field(struct hl_field *);
int									hl_read_buffer(char *, size_t);


extern int							hl_ctl_socket;
extern struct sockaddr_in			hl_ctl_addr;

extern pthread_key_t				hl_client_key;

extern struct wd_list				hl_chats;

extern iconv_t						hl_conv_from, hl_conv_to;

#endif
