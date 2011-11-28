/* $Id$ */

/*
 *  Copyright (c) 2004-2007 Axel Andersson
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
#include "windows.h"

struct _wr_user {
	wi_runtime_base_t				base;
	
	wr_uid_t						uid;
	wi_boolean_t					idle;
	wi_boolean_t					admin;
	
	wi_string_t						*nick;
	wi_string_t						*login;
	wi_string_t						*status;
	wi_string_t						*ip;
};


static void							wr_user_dealloc(wi_runtime_instance_t *);
static wi_boolean_t					wr_user_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *				wr_user_description(wi_runtime_instance_t *);
static wi_hash_code_t				wr_user_hash(wi_runtime_instance_t *);


wr_uid_t							wr_reply_uid;

static wi_runtime_id_t				wr_user_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_user_runtime_class = {
	"wr_user_t",
	wr_user_dealloc,
	NULL,
	wr_user_is_equal,
	wr_user_description,
	wr_user_hash
};


void wr_users_init(void) {
	wr_user_runtime_id = wi_runtime_register_class(&wr_user_runtime_class);
}



void wr_users_clear(void) {
	wr_reply_uid = 0;
}



#pragma mark -

char * wr_readline_nickname_generator(const char *text, int state) {
	static wi_uinteger_t	index;
	wi_array_t				*users;
	wi_string_t				*name;
	char					*cname;
	wr_user_t				*user;
	wi_uinteger_t			count;
	
	if(!wr_window_is_chat(wr_current_window))
		return NULL;
	
	users = wr_chat_users(wr_console_window->chat);
	
	if(state == 0)
		index = 0;

	cname = ((*rl_filename_dequoting_function) ((char *) text, 0));
	name = wi_string_with_cstring(cname);
	free(cname);
	
	count = wi_array_count(users);
	
	while(index < count) {
		user = WI_ARRAY(users, index++);
		
		if(wi_string_index_of_string(user->nick, name, WI_STRING_SMART_CASE_INSENSITIVE) == 0)
			return strdup(wi_string_cstring(user->nick));
	}
	
	return NULL;
}



#pragma mark -

wr_user_t * wr_user_alloc(void) {
	return wi_runtime_create_instance(wr_user_runtime_id, sizeof(wr_user_t));
}



wr_user_t * wr_user_init_with_arguments(wr_user_t *user, wi_array_t *arguments) {
	user->uid		= wi_string_uint32(WI_ARRAY(arguments, 1));
	user->idle		= wi_string_bool(WI_ARRAY(arguments, 2));
	user->admin		= wi_string_bool(WI_ARRAY(arguments, 3));
	user->nick		= wi_retain(WI_ARRAY(arguments, 5));
	user->login		= wi_retain(WI_ARRAY(arguments, 6));
	user->ip		= wi_retain(WI_ARRAY(arguments, 7));
	user->status	= wi_retain(WI_ARRAY(arguments, 9));

	return user;
}



static void wr_user_dealloc(wi_runtime_instance_t *instance) {
	wr_user_t		*user = instance;
	
	wi_release(user->nick);
	wi_release(user->login);
	wi_release(user->ip);
	wi_release(user->status);
}



static wi_boolean_t wr_user_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wr_user_t		*user1 = instance1;
	wr_user_t		*user2 = instance2;
	
	return (user1->uid == user2->uid);
}



static wi_string_t * wr_user_description(wi_runtime_instance_t *instance) {
	wr_user_t		*user = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{uid = %u, nick = %@}"),
		wi_runtime_class_name(user),
		user,
		user->uid,
		user->nick);
}



static wi_hash_code_t wr_user_hash(wi_runtime_instance_t *instance) {
	wr_user_t		*user = instance;
	
	return user->uid;
}



#pragma mark -

void wr_user_set_idle(wr_user_t *user, wi_boolean_t idle) {
	user->idle = idle;
}



void wr_user_set_admin(wr_user_t *user, wi_boolean_t admin) {
	user->admin = admin;
}



void wr_user_set_nick(wr_user_t *user, wi_string_t *nick) {
	wi_retain(nick);
	wi_release(user->nick);
	
	user->nick = nick;
}



void wr_user_set_status(wr_user_t *user, wi_string_t *status) {
	wi_retain(status);
	wi_release(user->status);
	
	user->status = status;
}



#pragma mark -

wr_uid_t wr_user_id(wr_user_t *user) {
	return user->uid;
}



wi_boolean_t wr_user_is_idle(wr_user_t *user) {
	return user->idle;
}



wi_boolean_t wr_user_is_admin(wr_user_t *user) {
	return user->admin;
}



wi_string_t * wr_user_nick(wr_user_t *user) {
	return user->nick;
}



wi_string_t * wr_user_status(wr_user_t *user) {
	return user->status;
}
