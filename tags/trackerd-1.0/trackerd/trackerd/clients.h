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

#ifndef WT_CLIENTS
#define WT_CLIENTS 1

#include <wired/wired.h>

#define WT_CLIENT_BUFFER_INITIAL_SIZE	BUFSIZ
#define WT_CLIENT_BUFFER_MAX_SIZE		131072


enum _wt_client_state {
	WT_CLIENT_STATE_CONNECTED			= 0,
	WT_CLIENT_STATE_SAID_HELLO,
	WT_CLIENT_STATE_DISCONNECTED
};
typedef enum _wt_client_state			wt_client_state_t;


struct _wt_client {
	wi_runtime_base_t					base;
	
	wi_socket_t							*socket;

	wt_client_state_t					state;
	wi_string_t							*ip;
	wi_string_t							*version;

	char								*buffer;
	unsigned int						buffer_size;
	unsigned int						buffer_offset;

	double								connect_time;
};
typedef struct _wt_client				wt_client_t;


void									wt_init_clients(void);

wt_client_t *							wt_client_alloc(void);
wt_client_t *							wt_client_init_with_socket(wt_client_t *, wi_socket_t *);

void									wt_client_set(wt_client_t *);
wt_client_t *							wt_client(void);

#endif /* WT_CLIENTS */
