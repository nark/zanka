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

#include "config.h"

#include <sys/types.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/in.h>
#include <wired/wired.h>

#include "clients.h"
#include "chats.h"
#include "server.h"
#include "settings.h"
#include "transfers.h"

#define WD_CLIENTS_THREAD_KEY			"wd_client_t"

#define WD_CLIENTS_TIMER_INTERVAL		60.0


static void								wd_update_clients(wi_timer_t *);

static void								wd_client_dealloc(wi_runtime_instance_t *);
static wi_string_t *					wd_client_description(wi_runtime_instance_t *);

static wd_uid_t							wd_client_uid(void);


static wi_timer_t						*wd_clients_timer;

wi_list_t								*wd_clients;

static wi_runtime_id_t					wd_client_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wd_client_runtime_class = {
	"wd_client_t",
	wd_client_dealloc,
	NULL,
	NULL,
	wd_client_description,
	NULL
};


void wd_init_clients(void) {
	wd_client_runtime_id = wi_runtime_register_class(&wd_client_runtime_class);

	wd_clients = wi_list_init(wi_list_alloc());

	wd_clients_timer = wi_timer_init_with_function(wi_timer_alloc(),
												   wd_update_clients,
												   WD_CLIENTS_TIMER_INTERVAL,
												   true);
}



void wd_schedule_clients(void) {
	wi_timer_schedule(wd_clients_timer);
}



static void wd_update_clients(wi_timer_t *timer) {
	wi_list_node_t		*node;
	wd_client_t			*client;
	wi_time_interval_t	interval;

	if(wi_list_count(wd_clients) > 0) {
		interval = wi_time_interval();

		wd_broadcast_lock();
		wi_list_rdlock(wd_clients);
		WI_LIST_FOREACH(wd_clients, node, client) {
			if(client->idle || client->state != WD_CLIENT_STATE_LOGGED_IN)
				continue;

			if(client->idle_time + wd_settings.idletime < interval) {
				client->idle = true;

				wd_client_broadcast_status(client);
			}
		}
		wi_list_unlock(wd_clients);
		wd_broadcast_unlock();
	}
}



void wd_dump_clients(void) {
	wi_log_debug(WI_STR("Clients:"));
	wi_log_debug(WI_STR("%@"), wd_clients);
}



#pragma mark -

wd_client_t * wd_client_alloc(void) {
	wd_client_t     *client;

	client = wi_runtime_create_instance(wd_client_runtime_id, sizeof(wd_client_t));

	client->buffer_size = WD_CLIENT_BUFFER_INITIAL_SIZE;
	client->buffer = wi_malloc(client->buffer_size);

	return client;
}



wd_client_t * wd_client_init_with_socket(wd_client_t *client, wi_socket_t *socket) {
	wi_address_t		*address;

	client->uid			= wd_client_uid();
	client->socket		= wi_retain(socket);
	client->state		= WD_CLIENT_STATE_CONNECTED;
	client->login_time	= wi_time_interval();
	client->idle_time	= client->idle_time;
	
	address				= wi_socket_address(socket);
	client->ip			= wi_retain(wi_address_string(address));
	client->host		= wi_retain(wi_address_hostname(address));
	
	client->socket_lock	= wi_lock_init(wi_lock_alloc());
	client->flag_lock	= wi_lock_init(wi_lock_alloc());

	return client;
}



static void wd_client_dealloc(wi_runtime_instance_t *instance) {
	wd_client_t			*client = instance;
	
	wi_release(client->socket);
	
	wi_release(client->account);
	
	wi_release(client->nick);
	wi_release(client->login);
	wi_release(client->ip);
	wi_release(client->host);
	wi_release(client->version);
	wi_release(client->status);
	wi_release(client->image);

	wi_release(client->socket_lock);
	wi_release(client->flag_lock);

	wi_free(client->buffer);
}



static wi_string_t * wd_client_description(wi_runtime_instance_t *instance) {
	wd_client_t			*client = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{nick = %@, login = %@, ip = %@}"),
		wi_runtime_class_name(client),
		client,
		client->nick,
		client->login,
		client->ip);
}



#pragma mark -

static wd_uid_t wd_client_uid(void) {
	static wd_uid_t		uid;

	if(wi_list_count(wd_clients) == 0)
		uid = 0;

	return ++uid;
}



#pragma mark -

void wd_client_lock_socket(wd_client_t *client) {
	wi_lock_lock(client->socket_lock);
}



void wd_client_unlock_socket(wd_client_t *client) {
	wi_lock_unlock(client->socket_lock);
}



#pragma mark -

void wd_client_set(wd_client_t *client) {
	wi_hash_set_data_for_key(wi_thread_hash(), client, WI_STR(WD_CLIENTS_THREAD_KEY));
}



wd_client_t * wd_client(void) {
	return wi_hash_data_for_key(wi_thread_hash(), WI_STR(WD_CLIENTS_THREAD_KEY));
}



#pragma mark -

wd_client_t * wd_client_with_uid(wd_uid_t uid) {
	wi_list_node_t  *node;
	wd_client_t     *client, *value = NULL;

	wi_list_rdlock(wd_clients);
	WI_LIST_FOREACH(wd_clients, node, client) {
		if(client->uid == uid) {
			value = client;

			break;
		}
	}
	wi_list_unlock(wd_clients);

	return value;
}



#pragma mark -

void wd_client_broadcast_status(wd_client_t *client) {
	wd_broadcast(WD_PUBLIC_CID, 304, WI_STR("%u%c%u%c%u%c%u%c%#@%c%#@"),
				 client->uid,		WD_FIELD_SEPARATOR,
				 client->idle,		WD_FIELD_SEPARATOR,
				 client->admin,		WD_FIELD_SEPARATOR,
				 client->icon,		WD_FIELD_SEPARATOR,
				 client->nick,		WD_FIELD_SEPARATOR,
				 client->status);
}



void wd_client_broadcast_leave(wd_client_t *client, wd_cid_t cid) {
	wd_broadcast(cid, 303, WI_STR("%u%c%u"),
				 cid,		WD_FIELD_SEPARATOR,
				 client->uid);
}



#pragma mark -

void wd_clients_add_client(wd_client_t *client) {
	wi_list_wrlock(wd_clients);
	wi_list_append_data(wd_clients, client);
	wi_list_unlock(wd_clients);
}



void wd_clients_remove_client(wd_client_t *client) {
	wd_chats_remove_client(client);
	wd_transfers_remove_client(client);
	
	wi_list_wrlock(wd_clients);
	wi_list_remove_data(wd_clients, client);
	wi_list_unlock(wd_clients);
}



void wd_clients_remove_all_clients(void) {
	wi_list_node_t  *node;
	wd_client_t     *client;

	wi_list_wrlock(wd_clients);
	WI_LIST_FOREACH(wd_clients, node, client) {
		wd_chats_remove_client(client);
		wd_transfers_remove_client(client);
	}

	wi_list_remove_all_data(wd_clients);
	wi_list_unlock(wd_clients);
}
