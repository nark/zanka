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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <readline/readline.h>
#include <wired/wired.h>

#include "users.h"

static void							wr_user_dealloc(wi_runtime_instance_t *);


wi_list_t							*wr_users;

wr_uid_t							wr_reply_uid;

static wi_runtime_id_t				wr_user_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_user_runtime_class = {
	"wr_user_t",
	wr_user_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_init_users(void) {
	wr_user_runtime_id = wi_runtime_register_class(&wr_user_runtime_class);

	wr_users = wi_list_init(wi_list_alloc());
}



void wr_clear_users(void) {
	wi_list_remove_all_data(wr_users);
}



#pragma mark -

char * wr_readline_nickname_generator(const char *text, int state) {
	static wi_list_node_t	*node;
	wi_string_t				*name;
	char					*cname, *match = NULL;
	wr_user_t				*user;
	
	if(state == 0)
		node = wi_list_first_node(wr_users);

	cname = ((*rl_filename_dequoting_function) ((char *) text, 0));
	name = wi_string_with_cstring(cname);

	while(node) {
		user = wi_list_node_data(node);
		node = wi_list_node_next_node(node);
		
		if(wi_string_index_of_string(user->nick, name, WI_STRING_SMART_CASE_INSENSITIVE) == 0) {
			match = strdup(wi_string_cstring(user->nick));
			
			break;
		}
	}

	free(cname);
	
	return match;
}



#pragma mark -

wr_user_t * wr_user_alloc(void) {
	return wi_runtime_create_instance(wr_user_runtime_id, sizeof(wr_user_t));
}



wr_user_t * wr_user_init(wr_user_t *user) {
	return user;
}



static void wr_user_dealloc(wi_runtime_instance_t *instance) {
	wr_user_t		*user = instance;
	
	wi_release(user->nick);
	wi_release(user->login);
	wi_release(user->ip);
	wi_release(user->status);
}



#pragma mark -

wr_user_t * wr_user_with_uid(wr_uid_t uid) {
    wi_list_node_t  *node;
	wr_user_t       *user;

	WI_LIST_FOREACH(wr_users, node, user) {
		if(user->uid == uid)
			return user;
	}

	return NULL;
}



wr_user_t * wr_user_with_nick(wi_string_t *nick) {
    wi_list_node_t  *node;
	wi_string_t		*name;
	wr_user_t       *user, *value = NULL;
	char			*cname;

	cname = ((*rl_filename_dequoting_function) ((char *) wi_string_cstring(nick), 0));
	name = wi_string_with_cstring(cname);
	free(cname);

	WI_LIST_FOREACH(wr_users, node, user) {
		if(wi_is_equal(user->nick, name)) {
			value = user;

			break;
		}
	}

	return value;
}
