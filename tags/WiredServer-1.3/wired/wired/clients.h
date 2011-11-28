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

#ifndef WD_CLIENTS_H
#define WD_CLIENTS_H 1

#include <wired/wired.h>

#include "accounts.h"

#define WD_CLIENT_BUFFER_INITIAL_SIZE	BUFSIZ
#define WD_CLIENT_BUFFER_MAX_SIZE		131072


enum wd_client_state {
	WD_CLIENT_STATE_CONNECTED			= 0,
	WD_CLIENT_STATE_SAID_HELLO,
	WD_CLIENT_STATE_GAVE_USER,
	WD_CLIENT_STATE_LOGGED_IN,
	WD_CLIENT_STATE_DISCONNECTED
};
typedef enum wd_client_state			wd_client_state_t;


typedef unsigned int					wd_uid_t;
typedef unsigned int					wd_icon_t;


struct _wd_client {
	wi_runtime_base_t					base;
	
	wi_lock_t							*socket_lock;
	wi_socket_t							*socket;
	
	wi_lock_t							*flag_lock;
	wd_uid_t							uid;
	wd_client_state_t					state;
	wd_icon_t							icon;
	wi_boolean_t						idle;
	wi_boolean_t						admin;
	
	wd_account_t						*account;

	wi_string_t							*nick;
	wi_string_t							*login;
	wi_string_t							*ip;
	wi_string_t							*host;
	unsigned int						port;
	wi_string_t							*version;
	wi_string_t							*status;
	
	wi_string_t							*image;
	
	char								*buffer;
	unsigned int						buffer_size;
	unsigned int						buffer_offset;

	wi_time_interval_t					login_time;
	wi_time_interval_t					idle_time;
};
typedef struct _wd_client				wd_client_t;


void									wd_init_clients(void);
void									wd_schedule_clients(void);
void									wd_dump_clients(void);

wd_client_t *							wd_client_alloc(void);
wd_client_t *							wd_client_init_with_socket(wd_client_t *, wi_socket_t *);

void									wd_client_lock_socket(wd_client_t *);
void									wd_client_unlock_socket(wd_client_t *);

void									wd_client_set(wd_client_t *);
wd_client_t *							wd_client(void);

wd_client_t *							wd_client_with_uid(wd_uid_t);

void									wd_client_broadcast_status(wd_client_t *);
void									wd_client_broadcast_leave(wd_client_t *, unsigned int);

void									wd_clients_add_client(wd_client_t *);
void									wd_clients_remove_client(wd_client_t *);
void									wd_clients_remove_all_clients(void);


extern wi_list_t						*wd_clients;

#endif /* WD_CLIENTS_H */
