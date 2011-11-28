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

#ifndef WD_SERVER_H
#define WD_SERVER_H 1

#include "config.h"

#include <sys/param.h>
#include <sys/types.h>
#include <netdb.h>
#include <openssl/ssl.h>
#include <pthread.h>

#include "utility.h"


enum {
	WD_CLIENT_STATE_CONNECTED			= 0,
	WD_CLIENT_STATE_SAID_HELLO,
	WD_CLIENT_STATE_GAVE_USER,
	WD_CLIENT_STATE_LOGGED_IN,
	WD_CLIENT_STATE_DISCONNECTED
};


#define WD_NICK_SIZE					256
#define WD_LOGIN_SIZE					WD_NICK_SIZE
#define WD_PASSWD_SIZE					256
#define WD_VERSION_SIZE					128
#define WD_BUFFER_SIZE					1024

#define WD_MESSAGE_SEPARATOR			"\4"
#define WD_FIELD_SEPARATOR				"\34"
#define WD_GROUP_SEPARATOR				"\35"
#define WD_RECORD_SEPARATOR				"\36"


struct wd_client {
	int									sd;
	pthread_t							thread;

	SSL									*ssl;
	pthread_mutex_t						ssl_mutex;
	
	unsigned long						uid;
	unsigned int						state;
	pthread_mutex_t						state_mutex;
	
	char								nick[WD_NICK_SIZE];
	char								login[WD_LOGIN_SIZE];
	char								ip[16];
	char								host[MAXHOSTNAMELEN];
	char								version[WD_VERSION_SIZE];
	int									port;

	char								*buffer;
	unsigned int						buffer_size;
	unsigned int						buffer_offset;

	unsigned long						icon;
	unsigned int						idle;
	unsigned int						admin;
	pthread_mutex_t						admin_mutex;
	
	time_t								login_time;
	time_t								idle_time;
};

struct wd_chat {
	unsigned long						cid;
	
	struct wd_list						clients;
};


void									wd_init_server(void);

void									wd_init_tracker(void);
void									wd_tracker_register(void);
void									wd_tracker_update(void);

void									wd_init_ssl(void);
void									wd_init_dh(void);
unsigned long							wd_ssl_id_function(void);
void									wd_ssl_locking_function(int, int, const char *, int);

void *									wd_utility_thread(void *);
void *									wd_ctl_listen_thread(void *);
void *									wd_xfer_listen_thread(void *);
#ifdef HAVE_CORESERVICES_CORESERVICES_H
void *									wd_cf_thread(void *);
#endif

struct wd_client *						wd_get_client(unsigned long, unsigned long);
void									wd_delete_client(struct wd_client *);

void									wd_update_clients(void);
void									wd_update_chats(void);

void									wd_reply(unsigned int, char *, ...);
void									wd_sreply(SSL *, unsigned int, char *, ...);
void									wd_swrite(SSL *, char *, ...);
void									wd_broadcast(unsigned long, unsigned int, char *, ...);


extern int								wd_ctl_socket, wd_xfer_socket;
extern struct sockaddr_in				wd_ctl_addr, wd_xfer_addr;

extern SSL_CTX							*wd_ctl_ssl_ctx, *wd_xfer_ssl_ctx;
extern pthread_mutex_t					*wd_ssl_locks;

extern pthread_key_t					wd_client_key;

extern struct wd_list					wd_chats;

#endif /* WD_SERVER_H */
