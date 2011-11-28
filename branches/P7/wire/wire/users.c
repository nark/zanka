/* $Id$ */

/*
 *  Copyright (c) 2004-2011 Axel Andersson
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
	
	wr_user_color_t					color;
};


static void							wr_user_dealloc(wi_runtime_instance_t *);
static wi_boolean_t					wr_user_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *				wr_user_description(wi_runtime_instance_t *);
static wi_hash_code_t				wr_user_hash(wi_runtime_instance_t *);


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
	
	users = wr_chat_users(wr_window_chat(wr_console_window));
	
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

wr_user_t * wr_user_with_message(wi_p7_message_t *message) {
	return wi_autorelease(wr_user_init_with_message(wr_user_alloc(), message));
}



#pragma mark -

wr_user_t * wr_user_alloc(void) {
	return wi_runtime_create_instance(wr_user_runtime_id, sizeof(wr_user_t));
}



wr_user_t * wr_user_init_with_message(wr_user_t *user, wi_p7_message_t *message) {
	wi_p7_uint32_t		uid;
	wi_p7_boolean_t		idle, admin;
	wi_p7_enum_t		color;
	
	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	wi_p7_message_get_bool_for_name(message, &idle, WI_STR("wired.user.idle"));
	wi_p7_message_get_bool_for_name(message, &admin, WI_STR("wired.user.admin"));
	wi_p7_message_get_enum_for_name(message, &color, WI_STR("wired.account.color"));
	
	user->nick		= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.user.nick")));
	user->status	= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.user.status")));
	user->uid		= uid;
	user->idle		= idle;
	user->admin		= admin;
	user->color		= color;

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

wr_uid_t wr_user_id(wr_user_t *user) {
	return user->uid;
}



#pragma mark -

void wr_user_set_idle(wr_user_t *user, wi_boolean_t idle) {
	user->idle = idle;
}



wi_boolean_t wr_user_is_idle(wr_user_t *user) {
	return user->idle;
}



void wr_user_set_admin(wr_user_t *user, wi_boolean_t admin) {
	user->admin = admin;
}



wi_boolean_t wr_user_is_admin(wr_user_t *user) {
	return user->admin;
}



void wr_user_set_nick(wr_user_t *user, wi_string_t *nick) {
	wi_retain(nick);
	wi_release(user->nick);
	
	user->nick = nick;
}



wi_string_t * wr_user_nick(wr_user_t *user) {
	return user->nick;
}



void wr_user_set_status(wr_user_t *user, wi_string_t *status) {
	wi_retain(status);
	wi_release(user->status);
	
	user->status = status;
}



wi_string_t * wr_user_status(wr_user_t *user) {
	return user->status;
}



wr_user_color_t wr_user_color(wr_user_t *user) {
	return user->color;
}
