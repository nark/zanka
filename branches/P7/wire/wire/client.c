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

#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "ignores.h"
#include "main.h"
#include "messages.h"
#include "server.h"
#include "spec.h"
#include "users.h"
#include "windows.h"

static wr_server_t *				wr_client_login(wi_p7_socket_t *, wi_string_t *, wi_string_t *);
static wi_p7_message_t *			wr_client_info_message(void);
static wi_p7_message_t *			wr_client_read_message(wi_p7_socket_t *);
static wi_boolean_t					wr_client_write_message(wi_p7_socket_t *, wi_p7_message_t *);

static wi_boolean_t					wr_runloop_server_callback(wi_socket_t *);


static const char					wr_default_icon[] =
	"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"
	"Vy/xW31D+jfvNtPdS+ASBQAAAABJRU5ErkJggg==";

wi_string_encoding_t				*wr_client_string_encoding;
wi_string_encoding_t				*wr_server_string_encoding;

wi_string_t							*wr_nick;
wi_string_t							*wr_status;
wi_data_t							*wr_icon;
wi_string_t							*wr_icon_path;
wi_string_t							*wr_timestamp_format;

wr_server_t							*wr_server;

wi_socket_t							*wr_socket;
wi_p7_socket_t						*wr_p7_socket;

wi_string_t							*wr_password;

wi_boolean_t						wr_connected;


void wr_client_init(void) {
	wr_server_string_encoding = wi_string_encoding_init_with_charset(
		wi_string_encoding_alloc(),
		WI_STR("UTF-8"),
		WI_STRING_ENCODING_IGNORE | WI_STRING_ENCODING_TRANSLITERATE);
	
	wr_client_set_charset(WI_STR("UTF-8"));
	
	wr_nick = wi_retain(wi_user_name());
	wr_icon = wi_data_init_with_base64(wi_data_alloc(), wi_string_with_cstring(wr_default_icon));
}



#pragma mark -

wi_boolean_t wr_client_set_charset(wi_string_t *charset) {
	wi_string_encoding_t	*encoding;
	wi_integer_t			options;
	
	if(wr_client_string_encoding && wi_is_equal(charset, wi_string_encoding_charset(wr_client_string_encoding)))
		return true;
	
	options = WI_STRING_ENCODING_IGNORE | WI_STRING_ENCODING_TRANSLITERATE;
	encoding = wi_string_encoding_init_with_charset(wi_string_encoding_alloc(),
													charset,
													options);
	
	if(!encoding)
		return false;

	wi_release(wr_client_string_encoding);
	wr_client_string_encoding = encoding;
	
	wr_printf_prefix(WI_STR("Using character set %@"), charset);
	
	return true;
}



#pragma mark -

void wr_client_connect(wi_string_t *hostname, wi_uinteger_t port, wi_string_t *login, wi_string_t *password) {
	wi_enumerator_t		*enumerator;
	wi_array_t			*addresses;
	wi_address_t		*address;
	wi_p7_socket_t		*p7_socket;
	wi_p7_message_t		*message;
	wi_socket_t			*socket;
	wi_string_t			*ip;
	wr_server_t			*server;
	
	if(wr_connected)
		wr_client_disconnect();
	
	wr_printf_prefix(WI_STR("Connecting to %@..."), hostname);
	
	if(port == 0)
		port = WR_PORT;
	
	if(!login)
		login = WI_STR("guest");
	
	if(!password)
		password = WI_STR("");
	
	addresses = wi_host_addresses(wi_host_with_string(hostname));
	
	if(!addresses) {
		wr_printf_prefix(WI_STR("Could not resolve \"%@\": %m"),
			hostname);
		
		return;
	}
	
	enumerator = wi_array_data_enumerator(addresses);
	
	while((address = wi_enumerator_next_data(enumerator))) {
		ip = wi_address_string(address);

		wr_printf_prefix(WI_STR("Trying %@ at port %u..."), ip, port);
		
		wi_address_set_port(address, port);
		
		socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP));
		
		if(!socket) {
			wr_printf_prefix(WI_STR("Could not open a socket to %@: %m"), ip);
			
			continue;
		}
		
		wi_socket_set_interactive(socket, true);
		
		if(!wi_socket_connect(socket, 10.0)) {
			wr_printf_prefix(WI_STR("Could not connect to %@: %m"), ip);

			continue;
		}
		
		p7_socket = wi_autorelease(wi_p7_socket_init_with_socket(wi_p7_socket_alloc(), socket, wr_p7_spec));
		
		if(!wi_p7_socket_connect(p7_socket,
								 10.0,
								 WI_P7_COMPRESSION_DEFLATE | WI_P7_ENCRYPTION_RSA_AES256_SHA1 | WI_P7_CHECKSUM_SHA1,
								 WI_P7_BINARY,
								 login,
								 wi_string_sha1(password))) {
			wr_printf_prefix(WI_STR("Could not connect to %@: %m"), ip);
			
			continue;
		}
		
		wr_printf_prefix(WI_STR("Connected using %@/%u bits, logging in..."),
			wi_cipher_name(wi_p7_socket_cipher(p7_socket)),
			wi_cipher_bits(wi_p7_socket_cipher(p7_socket)));
		
		server = wr_client_login(p7_socket, login, password);
		
		if(!server)
			break;

		wr_printf_prefix(WI_STR("Logged in, welcome to %@"), wr_server_name(server));
		
		message = wi_p7_message_with_name(WI_STR("wired.chat.join_chat"), wr_p7_spec);
		wi_p7_message_set_uint32_for_name(message, wr_chat_id(wr_public_chat), WI_STR("wired.chat.id"));
		wr_client_write_message(p7_socket, message);
		
		wr_connected	= true;
		wr_socket		= wi_retain(socket);
		wr_p7_socket	= wi_retain(p7_socket);
		wr_server		= wi_retain(server);
		wr_password		= wi_retain(password);
		
		wi_socket_set_direction(wr_socket, WI_SOCKET_READ);
		wr_runloop_add_socket(wr_socket, &wr_runloop_server_callback);

		break;
	}
		
	wr_draw_divider();
}



void wr_client_disconnect(void) {
	if(wr_connected) {
		wr_wprintf_prefix(wr_console_window, WI_STR("Connection to %@ closed"),
			wi_address_string(wi_socket_address(wr_socket)));

		wr_connected = false;
	}
	
	wr_runloop_remove_socket(wr_socket);
	wi_socket_close(wr_socket);
	wi_release(wr_p7_socket);
	wi_release(wr_socket);

	wi_release(wr_server);
	
	wi_release(wr_password);

	wr_windows_clear();
	wr_chats_clear();
	wr_users_clear();

	wr_draw_header();
	wr_draw_divider();
}



#pragma mark -

void wr_client_send_message(wi_p7_message_t *message) {
	wr_client_write_message(wr_p7_socket, message);
}



void wr_client_reply_message(wi_p7_message_t *reply, wi_p7_message_t *message) {
	wi_p7_uint32_t	transaction;
	
	if(reply != message) {
		if(wi_p7_message_get_uint32_for_name(message, &transaction, WI_STR("wired.transaction")))
			wi_p7_message_set_uint32_for_name(reply, transaction, WI_STR("wired.transaction"));
	}
	
	wr_client_write_message(wr_p7_socket, reply);
}



#pragma mark -

static wr_server_t * wr_client_login(wi_p7_socket_t *p7_socket, wi_string_t *login, wi_string_t *password) {
	wi_p7_message_t		*message;
	wi_string_t			*error;
	wr_server_t			*server;
	
	if(!wr_client_write_message(p7_socket, wr_client_info_message()))
		return NULL;
	
	message = wr_client_read_message(p7_socket);
	
	if(!message)
		return NULL;
	
	if(!wi_is_equal(wi_p7_message_name(message), WI_STR("wired.server_info"))) {
		wr_printf_prefix(WI_STR("Could not login: Received unexpected message \"%@\" (expected wired.server_info)"),
			wi_p7_message_name(message));
		
		return NULL;
	}
	
	server = wr_server_with_message(message);

	message = wi_p7_message_with_name(WI_STR("wired.user.set_nick"), wr_p7_spec);
	wi_p7_message_set_string_for_name(message, wr_nick, WI_STR("wired.user.nick"));
	
	if(!wr_client_write_message(p7_socket, message))
		return NULL;
	
	message = wr_client_read_message(p7_socket);
	
	if(!message)
		return NULL;
	
	if(wr_status) {
		message = wi_p7_message_with_name(WI_STR("wired.user.set_status"), wr_p7_spec);
		wi_p7_message_set_string_for_name(message, wr_status, WI_STR("wired.user.status"));
		
		if(!wr_client_write_message(p7_socket, message))
			return NULL;
		
		message = wr_client_read_message(p7_socket);
		
		if(!message)
			return NULL;
	}
	
	message = wi_p7_message_with_name(WI_STR("wired.user.set_icon"), wr_p7_spec);
	wi_p7_message_set_data_for_name(message, wr_icon, WI_STR("wired.user.icon"));
	
	if(!wr_client_write_message(p7_socket, message))
		return NULL;
	
	message = wr_client_read_message(p7_socket);
	
	if(!message)
		return NULL;
	
	message = wi_p7_message_with_name(WI_STR("wired.send_login"), wr_p7_spec);
	wi_p7_message_set_string_for_name(message, login, WI_STR("wired.user.login"));
	wi_p7_message_set_string_for_name(message, wi_string_sha1(password), WI_STR("wired.user.password"));
	
	if(!wr_client_write_message(p7_socket, message))
		return NULL;
	
	message = wr_client_read_message(p7_socket);
	
	if(!message)
		return NULL;
	
	if(wi_is_equal(wi_p7_message_name(message), WI_STR("wired.error"))) {
		error = wi_p7_message_enum_name_for_name(message, WI_STR("wired.error"));
		
		wr_printf_prefix(WI_STR("Could not login: Received error \"%@\""),
			error);
		
		return NULL;
	}
	else if(!wi_is_equal(wi_p7_message_name(message), WI_STR("wired.login"))) {
		wr_printf_prefix(WI_STR("Could not login: Received unexpected message \"%@\" (expected wired.login)"),
			wi_p7_message_name(message));
		
		return NULL;
	}
	
	message = wr_client_read_message(p7_socket);
	
	if(!message)
		return NULL;
	
	if(wi_is_equal(wi_p7_message_name(message), WI_STR("wired.error"))) {
		error = wi_p7_message_enum_name_for_name(message, WI_STR("wired.error"));
		
		wr_printf_prefix(WI_STR("Could not login: Received error \"%@\""),
			error);
		
		return NULL;
	}
	else if(!wi_is_equal(wi_p7_message_name(message), WI_STR("wired.account.privileges"))) {
		wr_printf_prefix(WI_STR("Could not login: Received unexpected message \"%@\" (expected wired.account.privileges)"),
			wi_p7_message_name(message));
		
		return NULL;
	}
	
	return server;
}



static wi_p7_message_t * wr_client_info_message(void) {
	wi_p7_message_t		*message;
	
	message = wi_p7_message_with_name(WI_STR("wired.client_info"), wr_p7_spec);
	wi_p7_message_set_string_for_name(message, WI_STR("Wire"), WI_STR("wired.info.application.name"));
	wi_p7_message_set_string_for_name(message, wi_string_with_cstring(WR_VERSION), WI_STR("wired.info.application.version"));
	wi_p7_message_set_uint32_for_name(message, WI_REVISION, WI_STR("wired.info.application.build"));
	wi_p7_message_set_string_for_name(message, wi_process_os_name(wi_process()), WI_STR("wired.info.os.name"));
	wi_p7_message_set_string_for_name(message, wi_process_os_release(wi_process()), WI_STR("wired.info.os.version"));
	wi_p7_message_set_string_for_name(message, wi_process_os_arch(wi_process()), WI_STR("wired.info.arch"));
	wi_p7_message_set_bool_for_name(message, false, WI_STR("wired.info.supports_rsrc"));

	return message;
}



static wi_p7_message_t * wr_client_read_message(wi_p7_socket_t *p7_socket) {
	wi_p7_message_t		*message;
	
	message = wi_p7_socket_read_message(p7_socket, 30.0);
	
	if(!message) {
		wr_printf_prefix(WI_STR("Could not read message from server: %m"));
		
		return NULL;
	}
	
	if(!wi_p7_spec_verify_message(wr_p7_spec, message)) {
		wr_printf_prefix(WI_STR("Could not verify message from server: %m"));
		
		return NULL;
	}
	
	return message;
}



static wi_boolean_t wr_client_write_message(wi_p7_socket_t *p7_socket, wi_p7_message_t *message) {
	if(!wi_p7_socket_write_message(p7_socket, 30.0, message)) {
		wr_printf_prefix(WI_STR("Could not write message to server: %m"));
		
		return false;
	}
	
	return true;
}



#pragma mark -

static wi_boolean_t wr_runloop_server_callback(wi_socket_t *socket) {
	wi_p7_message_t		*message;
	
	message = wr_client_read_message(wr_p7_socket);
	
	if(message) {
		wr_messages_handle_message(message);
		
		return true;
	} else {
		wr_client_disconnect();

		return false;
	}
}
