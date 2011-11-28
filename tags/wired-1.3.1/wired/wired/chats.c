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

#include <stdlib.h>
#include <wired/wired.h>

#include "chats.h"
#include "server.h"

static void							wd_chat_dealloc(wi_runtime_instance_t *);
static wi_string_t *				wd_chat_description(wi_runtime_instance_t *);

static wd_cid_t						wd_chat_cid(void);


wi_list_t							*wd_chats;

static wi_runtime_id_t				wd_chat_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wd_chat_runtime_class = {
	"wd_chat_t",
	wd_chat_dealloc,
	NULL,
	NULL,
	wd_chat_description,
	NULL
};


void wd_init_chats(void) {
	wd_chat_t		*chat;

	wd_chat_runtime_id = wi_runtime_register_class(&wd_chat_runtime_class);

	chat = wd_chat_init_public(wd_chat_alloc());
	wd_chats = wi_list_init_with_data(wi_list_alloc(), chat, (void *) NULL);
	wi_release(chat);
}



void wd_dump_chats(void) {
	wi_log_debug(WI_STR("Chats:"));
	wi_log_debug(WI_STR("%@"), wd_chats);
}



#pragma mark -

wd_chat_t * wd_chat_alloc(void) {
	return wi_runtime_create_instance(wd_chat_runtime_id, sizeof(wd_chat_t));
}



wd_chat_t * wd_chat_init(wd_chat_t *chat) {
	chat->clients = wi_list_init(wi_list_alloc());
	
	return chat;
}



wd_chat_t * wd_chat_init_public(wd_chat_t *chat) {
	chat = wd_chat_init(chat);
	
	chat->cid = WD_PUBLIC_CID;
	
	return chat;
}



wd_chat_t * wd_chat_init_private(wd_chat_t *chat) {
	chat = wd_chat_init(chat);
	
	chat->cid = wd_chat_cid();
	
	return chat;
}



static void wd_chat_dealloc(wi_runtime_instance_t *instance) {
	wd_chat_t		*chat = instance;

	wi_release(chat->topic.topic);
	wi_release(chat->topic.date);
	wi_release(chat->topic.nick);
	wi_release(chat->topic.login);
	wi_release(chat->topic.ip);
	
	wi_release(chat->clients);
}



static wi_string_t * wd_chat_description(wi_runtime_instance_t *instance) {
	wd_chat_t		*chat = instance;

	return wi_string_with_format(WI_STR("<%s %p>{cid = %u, clients = %@}"),
		wi_runtime_class_name(chat),
		chat,
		chat->cid,
		chat->clients);
}



#pragma mark -

static wd_cid_t wd_chat_cid(void) {
	wd_cid_t	cid;

	do {
		cid = ((wd_cid_t) random() % UINT_MAX) + 1;
	} while(wd_chat_with_cid(cid));
	
	return cid;
}



#pragma mark -

wd_chat_t * wd_chat_with_cid(wd_cid_t cid) {
	wi_list_node_t	*node;
	wd_chat_t		*chat, *value = NULL;

	wi_list_rdlock(wd_chats);
	WI_LIST_FOREACH(wd_chats, node, chat) {
		if(chat->cid == cid) {
			value = chat;

			break;          
		}
	}
	wi_list_unlock(wd_chats);

	return value;
}



#pragma mark -

wi_boolean_t wd_chat_contains_client(wd_chat_t *chat, wd_client_t *client) {
	wi_list_node_t	*node;
	wd_client_t		*each;
	wi_boolean_t	value = false;

	if(chat) {
		wi_list_rdlock(wd_chats);
		WI_LIST_FOREACH(chat->clients, node, each) {
			if(each == client) {
				value = true;

				break;
			}
		}
		wi_list_unlock(wd_chats);
	}

	return value;
}



void wd_chat_add_client(wd_chat_t *chat, wd_client_t *client) {
	wd_broadcast_lock();
	wd_broadcast(chat->cid, 302, WI_STR("%u%c%u%c%u%c%u%c%u%c%#@%c%#@%c%#@%c%#@%c%#@%c%#@"),
				 chat->cid,			WD_FIELD_SEPARATOR,
				 client->uid,		WD_FIELD_SEPARATOR,
				 client->idle,		WD_FIELD_SEPARATOR,
				 client->admin,		WD_FIELD_SEPARATOR,
				 client->icon,		WD_FIELD_SEPARATOR,
				 client->nick,		WD_FIELD_SEPARATOR,
				 client->login,		WD_FIELD_SEPARATOR,
				 client->ip,		WD_FIELD_SEPARATOR,
				 client->host,		WD_FIELD_SEPARATOR,
				 client->status,	WD_FIELD_SEPARATOR,
				 client->image);
	wd_broadcast_unlock();
	
	wi_list_wrlock(wd_chats);
	wi_list_append_data(chat->clients, client);
	wi_list_unlock(wd_chats);

	if(chat->topic.topic)
		wd_chat_reply_topic(chat);
}



void wd_chat_remove_client(wd_chat_t *chat, wd_client_t *client) {
	wi_list_wrlock(wd_chats);
	wi_list_remove_data(chat->clients, client);

	if(chat->cid != WD_PUBLIC_CID && wi_list_count(chat->clients) == 0)
		wi_list_remove_data(wd_chats, chat);

	wi_list_unlock(wd_chats);
}



void wd_chat_reply_client_list(wd_chat_t *chat) {
	wi_list_node_t	*node;
	wd_client_t		*client;
	
	wi_list_rdlock(wd_chats);
	WI_LIST_FOREACH(chat->clients, node, client) {
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_reply(310, WI_STR("%u%c%u%c%u%c%u%c%u%c%#@%c%#@%c%#@%c%#@%c%#@%c%#@"),
					 chat->cid,			WD_FIELD_SEPARATOR,
					 client->uid,		WD_FIELD_SEPARATOR,
					 client->idle,		WD_FIELD_SEPARATOR,
					 client->admin,		WD_FIELD_SEPARATOR,
					 client->icon,		WD_FIELD_SEPARATOR,
					 client->nick,		WD_FIELD_SEPARATOR,
					 client->login,		WD_FIELD_SEPARATOR,
					 client->ip,		WD_FIELD_SEPARATOR,
					 client->host,		WD_FIELD_SEPARATOR,
					 client->status,	WD_FIELD_SEPARATOR,
					 client->image);
		}
	}
	wi_list_unlock(wd_chats);

	wd_reply(311, WI_STR("%u"), chat->cid);
}



#pragma mark -

void wd_chat_set_topic(wd_chat_t *chat, wi_string_t *topic) {
	wd_client_t		*client = wd_client();
	
	wi_release(chat->topic.topic);
	chat->topic.topic = wi_copy(topic);
	
	wi_release(chat->topic.date);
	chat->topic.date = wi_date_init(wi_date_alloc());

	wi_release(chat->topic.nick);
	chat->topic.nick = wi_copy(client->nick);

	wi_release(chat->topic.login);
	chat->topic.login = wi_copy(client->login);

	wi_release(chat->topic.ip);
	chat->topic.ip = wi_copy(client->ip);
}



void wd_chat_reply_topic(wd_chat_t *chat) {
	wi_string_t		*string;
	
	string = wi_date_iso8601_string(chat->topic.date);
	
	wd_reply(341, WI_STR("%u%c%#@%c%#@%c%#@%c%#@%c%#@"),
			 chat->cid,				WD_FIELD_SEPARATOR,
			 chat->topic.nick,		WD_FIELD_SEPARATOR,
			 chat->topic.login,		WD_FIELD_SEPARATOR,
			 chat->topic.ip,		WD_FIELD_SEPARATOR,
			 string,				WD_FIELD_SEPARATOR,
			 chat->topic.topic);
}



void wd_chat_broadcast_topic(wd_chat_t *chat) {
	wi_string_t		*string;
	
	string = wi_date_iso8601_string(chat->topic.date);
	
	wd_broadcast(chat->cid, 341, WI_STR("%u%c%#@%c%#@%c%#@%c%#@%c%#@"),
				 chat->cid,				WD_FIELD_SEPARATOR,
				 chat->topic.nick,		WD_FIELD_SEPARATOR,
				 chat->topic.login,		WD_FIELD_SEPARATOR,
				 chat->topic.ip,		WD_FIELD_SEPARATOR,
				 string,				WD_FIELD_SEPARATOR,
				 chat->topic.topic);
}



#pragma mark -

void wd_chats_remove_client(wd_client_t *client) {
	wi_list_node_t	*node, *next_node;
	wd_chat_t		*chat;

	wi_list_wrlock(wd_chats);
	for(node = wi_list_first_node(wd_chats); node; node = next_node) {
		next_node	= wi_list_node_next_node(node);
		chat		= wi_list_node_data(node);

		wi_list_remove_data(chat->clients, client);

		if(chat->cid != WD_PUBLIC_CID && wi_list_count(chat->clients) == 0)
			wi_list_remove_node(wd_chats, node);
	}
	wi_list_unlock(wd_chats);
}
