/* $Id$ */

/*
 *  Copyright (c) 2011 Axel Andersson
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

#include "client.h"
#include "commands.h"
#include "ignores.h"
#include "messages.h"
#include "spec.h"
#include "windows.h"

typedef void									wr_message_func_t(wi_p7_message_t *);


enum _wr_messages_error {
	WR_MESSAGES_INTERNAL_ERROR					= 0,
	WR_MESSAGES_INVALID_MESSAGE					= 1,
	WR_MESSAGES_UNRECOGNIZED_MESSAGE			= 2,
	WR_MESSAGES_MESSAGE_OUT_OF_SEQUENCE			= 3,
	WR_MESSAGES_LOGIN_FAILED					= 4,
	WR_MESSAGES_PERMISSION_DENIED				= 5,
	WR_MESSAGES_NOT_SUBSCRIBED					= 6,
	WR_MESSAGES_ALREADY_SUBSCRIBED				= 7,
	WR_MESSAGES_CHAT_NOT_FOUND					= 8,
	WR_MESSAGES_ALREADY_ON_CHAT					= 9,
	WR_MESSAGES_NOT_ON_CHAT						= 10,
	WR_MESSAGES_NOT_INVITED_TO_CHAT				= 11,
	WR_MESSAGES_USER_NOT_FOUND					= 12,
	WR_MESSAGES_USER_CANNOT_BE_DISCONNECTED		= 13,
	WR_MESSAGES_FILE_NOT_FOUND					= 14,
	WR_MESSAGES_FILE_EXISTS						= 15,
	WR_MESSAGES_ACCOUNT_NOT_FOUND				= 16,
	WR_MESSAGES_ACCOUNT_EXISTS					= 17,
	WR_MESSAGES_ACCOUNT_IN_USE					= 18,
	WR_MESSAGES_TRACKER_NOT_ENABLED				= 19,
	WR_MESSAGES_NOT_REGISTERED					= 20,
	WR_MESSAGES_BAN_NOT_FOUND					= 21,
	WR_MESSAGES_BAN_EXISTS						= 22,
	WR_MESSAGES_BOARD_NOT_FOUND					= 23,
	WR_MESSAGES_BOARD_EXISTS					= 24,
	WR_MESSAGES_THREAD_NOT_FOUND				= 25,
	WR_MESSAGES_POST_NOT_FOUND					= 26,
	WR_MESSAGES_RSRC_NOT_SUPPORTED				= 27
};
typedef enum _wr_messages_error					wr_messages_error_t;


static void										wr_message_okay(wi_p7_message_t *);
static void										wr_message_error(wi_p7_message_t *);
static void										wr_message_server_info(wi_p7_message_t *);
static void										wr_message_send_ping(wi_p7_message_t *);
static void										wr_message_ping(wi_p7_message_t *);
static void										wr_message_user_info(wi_p7_message_t *);
static void										wr_message_chat_user_list(wi_p7_message_t *);
static void										wr_message_chat_user_list_done(wi_p7_message_t *);
static void										wr_message_chat_topic(wi_p7_message_t *);
static void										wr_message_chat_say(wi_p7_message_t *);
static void										wr_message_chat_me(wi_p7_message_t *);
static void										wr_message_chat_user_status(wi_p7_message_t *);
static void										wr_message_chat_user_join(wi_p7_message_t *);
static void										wr_message_chat_user_leave(wi_p7_message_t *);
static void										wr_message_chat_chat_created(wi_p7_message_t *);
static void										wr_message_chat_invitation(wi_p7_message_t *);
static void										wr_message_chat_user_decline_invitation(wi_p7_message_t *);
static void										wr_message_message_message(wi_p7_message_t *);
static void										wr_message_message_broadcast(wi_p7_message_t *);


static wi_mutable_dictionary_t					*wr_message_handlers;



#define WR_MESSAGE_HANDLER(message, handler) \
	wi_mutable_dictionary_set_data_for_key(wr_message_handlers, (handler), (message))
	
void wr_messages_init(void) {
	wr_message_handlers = wi_dictionary_init_with_capacity_and_callbacks(wi_mutable_dictionary_alloc(),
		0, wi_dictionary_default_key_callbacks, wi_dictionary_null_value_callbacks);
	
	WR_MESSAGE_HANDLER(WI_STR("wired.okay"), wr_message_okay);
	WR_MESSAGE_HANDLER(WI_STR("wired.error"), wr_message_error);
	WR_MESSAGE_HANDLER(WI_STR("wired.server_info"), wr_message_server_info);
	WR_MESSAGE_HANDLER(WI_STR("wired.send_ping"), wr_message_send_ping);
	WR_MESSAGE_HANDLER(WI_STR("wired.ping"), wr_message_ping);
	WR_MESSAGE_HANDLER(WI_STR("wired.user.info"), wr_message_user_info);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_list"), wr_message_chat_user_list);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_list.done"), wr_message_chat_user_list_done);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.topic"), wr_message_chat_topic);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.say"), wr_message_chat_say);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.me"), wr_message_chat_me);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_status"), wr_message_chat_user_status);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_join"), wr_message_chat_user_join);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_leave"), wr_message_chat_user_leave);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.chat_created"), wr_message_chat_chat_created);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.invitation"), wr_message_chat_invitation);
	WR_MESSAGE_HANDLER(WI_STR("wired.chat.user_decline_invitation"), wr_message_chat_user_decline_invitation);
	WR_MESSAGE_HANDLER(WI_STR("wired.message.message"), wr_message_message_message);
	WR_MESSAGE_HANDLER(WI_STR("wired.message.broadcast"), wr_message_message_broadcast);
}



void wr_messages_handle_message(wi_p7_message_t *message) {
	wr_message_func_t		*handler;
	wi_string_t				*name;
	
	name		= wi_p7_message_name(message);
	handler		= wi_dictionary_data_for_key(wr_message_handlers, name);
	
	if(!handler) {
		wr_printf_prefix(WI_STR("No handler for message \"%@\""), name);
		
		return;
	}
	
	(*handler)(message);
}



#pragma mark -

static void wr_message_okay(wi_p7_message_t *message) {
}



static void wr_message_error(wi_p7_message_t *message) {
	wi_string_t				*command;
	wi_string_t				*string;
	wr_messages_error_t		error;
	
	wi_p7_message_get_enum_for_name(message, &error, WI_STR("wired.error"));
	
	switch(error) {
		case WR_MESSAGES_INTERNAL_ERROR:
			string = wi_string_with_format(WI_STR("Internal server error: %@"),
				wi_p7_message_string_for_name(message, WI_STR("wired.error.string")));
			break;

		case WR_MESSAGES_INVALID_MESSAGE:
			string = WI_STR("Invalid message");
			break;
		
		case WR_MESSAGES_UNRECOGNIZED_MESSAGE:
			string = WI_STR("Unrecognized message");
			break;
		
		case WR_MESSAGES_MESSAGE_OUT_OF_SEQUENCE:
			string = WI_STR("Message out of sequence");
			break;
		
		case WR_MESSAGES_LOGIN_FAILED:
			string = WI_STR("Login failed");
			break;
		
		case WR_MESSAGES_PERMISSION_DENIED:
			string = WI_STR("Permission denied");
			break;
		
		case WR_MESSAGES_NOT_SUBSCRIBED:
			string = WI_STR("Not subscribed");
			break;
		
		case WR_MESSAGES_ALREADY_SUBSCRIBED:
			string = WI_STR("Already subscribed");
			break;
		
		case WR_MESSAGES_CHAT_NOT_FOUND:
			string = WI_STR("Chat not found");
			break;
		
		case WR_MESSAGES_ALREADY_ON_CHAT:
			string = WI_STR("Already on chat");
			break;
		
		case WR_MESSAGES_NOT_ON_CHAT:
			string = WI_STR("Not on chat");
			break;
		
		case WR_MESSAGES_NOT_INVITED_TO_CHAT:
			string = WI_STR("Not invited to chat");
			break;
		
		case WR_MESSAGES_USER_NOT_FOUND:
			string = WI_STR("User not found");
			break;
		
		case WR_MESSAGES_USER_CANNOT_BE_DISCONNECTED:
			string = WI_STR("Cannot be disconnected");
			break;
		
		case WR_MESSAGES_FILE_NOT_FOUND:
			string = WI_STR("File or folder not found");
			break;
		
		case WR_MESSAGES_FILE_EXISTS:
			string = WI_STR("File or folder exists");
			break;
		
		case WR_MESSAGES_ACCOUNT_NOT_FOUND:
			string = WI_STR("Account not found");
			break;
		
		case WR_MESSAGES_ACCOUNT_EXISTS:
			string = WI_STR("Account exists");
			break;
		
		case WR_MESSAGES_ACCOUNT_IN_USE:
			string = WI_STR("Account in use");
			break;
		
		case WR_MESSAGES_TRACKER_NOT_ENABLED:
			string = WI_STR("Tracker not enabled");
			break;
		
		case WR_MESSAGES_NOT_REGISTERED:
			string = WI_STR("Not registered");
			break;
		
		case WR_MESSAGES_BAN_NOT_FOUND:
			string = WI_STR("Ban not found");
			break;
		
		case WR_MESSAGES_BAN_EXISTS:
			string = WI_STR("Ban exists");
			break;
		
		case WR_MESSAGES_BOARD_NOT_FOUND:
			string = WI_STR("Board not found");
			break;
		
		case WR_MESSAGES_BOARD_EXISTS:
			string = WI_STR("Board exists");
			break;
		
		case WR_MESSAGES_THREAD_NOT_FOUND:
			string = WI_STR("Thread not found");
			break;
		
		case WR_MESSAGES_POST_NOT_FOUND:
			string = WI_STR("Post not found");
			break;
		
		case WR_MESSAGES_RSRC_NOT_SUPPORTED:
			string = WI_STR("Resource fork not supported");
			break;
		
		default:
			string = WI_STR("Unknown error");
			break;
	}
	
	command = wr_commands_command_for_message(message);
	
	if(command)
		wr_printf_prefix(WI_STR("%@: %@"), command, string);
	else
		wr_printf_prefix(WI_STR("%@"), string);
}



static void wr_message_send_ping(wi_p7_message_t *message) {
	wi_p7_message_t		*reply;
	
	reply = wi_p7_message_with_name(WI_STR("wired.ping"), wr_p7_spec);
	
	wr_client_reply_message(reply, message);
}



static void wr_message_ping(wi_p7_message_t *message) {
}



static void wr_message_server_info(wi_p7_message_t *message) {
	wi_release(wr_server);
	
	wr_server = wr_server_init_with_message(wr_server_alloc(), message);
}



static void wr_message_user_info(wi_p7_message_t *message) {
	wi_date_t			*date;
	wi_string_t			*string, *interval;
	wi_p7_uint32_t		uid, build, bits;

	wr_printf_prefix(WI_STR("User info:"));

	wr_printf_block(WI_STR("Nick:        %@"),
		wi_p7_message_string_for_name(message, WI_STR("wired.user.nick")));
	wr_printf_block(WI_STR("Status:      %@"),
		wi_p7_message_string_for_name(message, WI_STR("wired.user.status")));
	wr_printf_block(WI_STR("Login:       %@"),
		wi_p7_message_string_for_name(message, WI_STR("wired.user.login")));

	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	
	wr_printf_block(WI_STR("ID:          %u"), uid);
	wr_printf_block(WI_STR("Address:     %@"),
		wi_p7_message_string_for_name(message, WI_STR("wired.user.ip")));
	wr_printf_block(WI_STR("Host:        %@"),
		wi_p7_message_string_for_name(message, WI_STR("wired.user.host")));
	
	wi_p7_message_get_uint32_for_name(message, &build, WI_STR("wired.info.application.build"));
	
	wr_printf_block(WI_STR("Client:      %@ %@ (%u) on %@ %@ (%@)"),
		wi_p7_message_string_for_name(message, WI_STR("wired.info.application.name")),
		wi_p7_message_string_for_name(message, WI_STR("wired.info.application.version")),
		build,
		wi_p7_message_string_for_name(message, WI_STR("wired.info.os.name")),
		wi_p7_message_string_for_name(message, WI_STR("wired.info.os.version")),
		wi_p7_message_string_for_name(message, WI_STR("wired.info.arch")));
	
	if(wi_p7_message_get_uint32_for_name(message, &bits, WI_STR("wired.user.cipher.bits"))) {
		wr_printf_block(WI_STR("Cipher:      %@/%u bits"),
			wi_p7_message_string_for_name(message, WI_STR("wired.user.cipher.name")),
			bits);
	} else {
		wr_printf_block(WI_STR("Cipher:      None"));
	}
	
	date		= wi_p7_message_date_for_name(message, WI_STR("wired.user.login_time"));
	interval	= wi_time_interval_string(wi_date_time_interval_since_now(date));
	string		= wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));

	wr_printf_block(WI_STR("Login Time:  %@, since %@"), interval, string);

	date		= wi_p7_message_date_for_name(message, WI_STR("wired.user.idle_time"));
	interval	= wi_time_interval_string(wi_date_time_interval_since_now(date));
	string		= wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));

	wr_printf_block(WI_STR("Idle Time:   %@, since %@"), interval, string);
}



static void wr_message_chat_user_list(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wi_p7_uint32_t		cid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));

	chat = wr_chats_chat_with_cid(cid);

	wr_chat_add_user(chat, wr_user_with_message(message));
}



static void wr_message_chat_user_list_done(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wi_p7_uint32_t		cid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));

	chat = wr_chats_chat_with_cid(cid);

	wr_draw_divider();
	wr_print_users(wr_windows_window_with_chat(chat));
}



static void wr_message_chat_topic(wi_p7_message_t *message) {
	wr_chat_t		*chat;
	wr_window_t		*window;
	wr_topic_t		*topic;
	wi_p7_uint32_t	cid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));

	chat = wr_chats_chat_with_cid(cid);
	
	if(chat) {
		window = wr_windows_window_with_chat(chat);

		if(window && wr_window_is_chat(window)) {
			topic = wr_topic_with_message(message);
			
			wr_window_set_topic(window, topic);
			
			wr_draw_header();
			wr_print_topic();
		}
	}
}



static void wr_message_chat_say(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wr_user_t			*user;
	wi_p7_uint32_t		cid;
	wi_p7_uint32_t		uid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	
	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);
	
	if(user && !wr_is_ignored(wr_user_nick(user))) {
		wr_wprint_say(wr_windows_window_with_chat(chat),
			wr_user_nick(user),
			wi_p7_message_string_for_name(message, WI_STR("wired.chat.say")));
	}
}



static void wr_message_chat_me(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wr_user_t			*user;
	wi_p7_uint32_t		cid;
	wi_p7_uint32_t		uid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	
	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);
	
	if(user && !wr_is_ignored(wr_user_nick(user))) {
		wr_wprint_me(wr_windows_window_with_chat(chat),
			wr_user_nick(user),
			wi_p7_message_string_for_name(message, WI_STR("wired.chat.me")));
	}
}



static void wr_message_chat_user_status(wi_p7_message_t *message) {
	wi_string_t			*nick, *status;
	wr_user_t			*user;
	wi_p7_uint32_t		uid;
	wi_p7_boolean_t		idle, admin;

	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	
	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user) {
		wi_p7_message_get_bool_for_name(message, &idle, WI_STR("wired.user.idle"));
		wi_p7_message_get_bool_for_name(message, &admin, WI_STR("wired.user.admin"));
		
		nick		= wi_p7_message_string_for_name(message, WI_STR("wired.user.nick"));
		status		= wi_p7_message_string_for_name(message, WI_STR("wired.user.status"));
		
		if(!wi_is_equal(wr_user_nick(user), nick)) {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ is now known as %@"),
				wr_user_nick(user), nick);

			wr_user_set_nick(user, nick);
		}

		wr_user_set_idle(user, idle);
		wr_user_set_admin(user, admin);
		wr_user_set_status(user, status);
	}
}



static void wr_message_chat_user_join(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wr_user_t			*user;
	wi_p7_uint32_t		cid;

	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	
	chat = wr_chats_chat_with_cid(cid);
	user = wr_user_with_message(message);

	wr_chat_add_user(chat, user);
	
	wr_draw_divider();
	wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has joined"),
		wr_user_nick(user));
}



static void wr_message_chat_user_leave(wi_p7_message_t *message) {
	wr_chat_t			*chat;
	wr_user_t			*user;
	wi_p7_uint32_t		uid, cid;

	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	
	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);

	if(user) {
		wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has left"),
			wr_user_nick(user));
		
		wr_chat_remove_user(chat, user);
		wr_draw_divider();
	}
}



static void wr_message_chat_chat_created(wi_p7_message_t *message) {
	wi_p7_message_t		*reply;
	wr_chat_t			*chat;
	wr_window_t			*window;
	wi_p7_uint32_t		cid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));

	chat = wr_chat_init_private_chat(wr_chat_alloc(), cid);
	wr_chats_add_chat(chat);

	window = wr_window_init_with_chat(wr_window_alloc(), chat);
	wr_windows_add_window(window);
	wr_windows_show_window(window);

	wi_release(window);
	wi_release(chat);
	
	reply = wi_p7_message_with_name(WI_STR("wired.chat.join_chat"), wr_p7_spec);
	wi_p7_message_set_uint32_for_name(reply, cid, WI_STR("wired.chat.id"));
	wr_client_send_message(reply);
	
	if(wr_private_chat_invite_uid != 0) {
		reply = wi_p7_message_with_name(WI_STR("wired.chat.invite_user"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(reply, cid, WI_STR("wired.chat.id"));
		wi_p7_message_set_uint32_for_name(reply, wr_private_chat_invite_uid, WI_STR("wired.user.id"));
		wr_client_send_message(reply);
		
		wr_private_chat_invite_uid = 0;
	}
}



static void wr_message_chat_invitation(wi_p7_message_t *message) {
	wi_p7_message_t		*reply;
	wr_user_t			*user;
	wr_chat_t			*chat;
	wr_window_t			*window;
	wi_p7_uint32_t		cid, uid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));

	user = wr_chat_user_with_uid(wr_public_chat, uid);
	
	if(user && !wr_is_ignored(wr_user_nick(user))) {
		chat = wr_chat_init_private_chat(wr_chat_alloc(), cid);
		wr_chats_add_chat(chat);
		
		window = wr_window_init_with_chat(wr_window_alloc(), chat);
		wr_windows_add_window(window);
		wr_windows_show_window(window);

		reply = wi_p7_message_with_name(WI_STR("wired.chat.join_chat"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(reply, cid, WI_STR("wired.chat.id"));
		wr_client_send_message(reply);

		wi_release(window);
		wi_release(chat);
	}
}



static void wr_message_chat_user_decline_invitation(wi_p7_message_t *message) {
	wr_user_t			*user;
	wr_chat_t			*chat;
	wi_p7_uint32_t		cid, uid;
	
	wi_p7_message_get_uint32_for_name(message, &cid, WI_STR("wired.chat.id"));
	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));

	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(wr_public_chat, uid);
	
	if(chat && user) {
		wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has declined invitation"),
			wr_user_nick(user));
	}
}



static void wr_message_message_message(wi_p7_message_t *message) {
	wr_user_t			*user;
	wr_window_t			*window;
	wi_p7_uint32_t		uid;

	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));

	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user && !wr_is_ignored(wr_user_nick(user))) {
		window = wr_windows_window_with_user(user);
		
		if(!window) {
			window = wr_window_init_with_user(wr_window_alloc(), user);
			wr_windows_add_window(window);
			wi_release(window);
		}
		
		wr_wprint_msg(window, wr_user_nick(user), wi_p7_message_string_for_name(message, WI_STR("wired.message.message")));
	}
}



static void wr_message_message_broadcast(wi_p7_message_t *message) {
	wr_user_t			*user;
	wi_p7_uint32_t		uid;

	wi_p7_message_get_uint32_for_name(message, &uid, WI_STR("wired.user.id"));

	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user && !wr_is_ignored(wr_user_nick(user))) {
		wr_wprintf_prefix(wr_console_window, WI_STR("Broadcast message from %@:"),
			wr_user_nick(user));
		wr_wprintf_block(wr_console_window, WI_STR("%@"),
			wi_p7_message_string_for_name(message, WI_STR("wired.message.broadcast")));
	}
}
