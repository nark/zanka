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

#include <wired/wired.h>

#include "clients.h"

#define WT_CLIENTS_THREAD_KEY			"wt_client_t"


static void								wt_client_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					wt_client_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wt_client_runtime_class = {
	"wt_client_t",
	wt_client_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wt_init_clients(void) {
	wt_client_runtime_id = wi_runtime_register_class(&wt_client_runtime_class);
}



#pragma mark -

wt_client_t * wt_client_alloc(void) {
	wt_client_t		*client;

	client = wi_runtime_create_instance(wt_client_runtime_id, sizeof(wt_client_t));

	client->buffer_size = WT_CLIENT_BUFFER_INITIAL_SIZE;
	client->buffer = wi_malloc(client->buffer_size);
	
	return client;
}



wt_client_t * wt_client_init_with_socket(wt_client_t *client, wi_socket_t *socket) {
	client->socket			= wi_retain(socket);
	client->state			= WT_CLIENT_STATE_CONNECTED;
	client->ip				= wi_retain(wi_address_string(wi_socket_address(socket)));
	client->connect_time	= wi_time_interval();
	
	return client;
}



static void wt_client_dealloc(wi_runtime_instance_t *instance) {
	wt_client_t		*client = (wt_client_t *) instance;
	
	wi_release(client->socket);
	wi_release(client->ip);
	wi_release(client->version);
	
	wi_free(client->buffer);
}



#pragma mark -

void wt_client_set(wt_client_t *client) {
	wi_hash_set_data_for_key(wi_thread_hash(), client, WI_STR(WT_CLIENTS_THREAD_KEY));
}



wt_client_t * wt_client(void) {
	return wi_hash_data_for_key(wi_thread_hash(), WI_STR(WT_CLIENTS_THREAD_KEY));
}
