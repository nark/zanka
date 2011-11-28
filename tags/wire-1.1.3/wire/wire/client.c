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

#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "files.h"
#include "ignores.h"
#include "main.h"
#include "server.h"
#include "transfers.h"
#include "users.h"
#include "version.h"
#include "windows.h"

static wi_integer_t					wr_runloop_server_callback(wi_socket_t *);

static uint32_t						wr_parse_message(wi_string_t *);

static void							wr_msg_200(wi_array_t *);
static void							wr_msg_201(wi_array_t *);
static void							wr_msg_202(wi_array_t *);
static void							wr_msg_300(wi_array_t *);
static void							wr_msg_301(wi_array_t *);
static void							wr_msg_302(wi_array_t *);
static void							wr_msg_303(wi_array_t *);
static void							wr_msg_304(wi_array_t *);
static void							wr_msg_305(wi_array_t *);
static void							wr_msg_306(wi_array_t *);
static void							wr_msg_307(wi_array_t *);
static void							wr_msg_308(wi_array_t *);
static void							wr_msg_309(wi_array_t *);
static void							wr_msg_310(wi_array_t *);
static void							wr_msg_311(wi_array_t *);
static void							wr_msg_320(wi_array_t *);
static void							wr_msg_321(wi_array_t *);
static void							wr_msg_322(wi_array_t *);
static void							wr_msg_330(wi_array_t *);
static void							wr_msg_331(wi_array_t *);
static void							wr_msg_332(wi_array_t *);
static void							wr_msg_341(wi_array_t *);
static void							wr_msg_400(wi_array_t *);
static void							wr_msg_401(wi_array_t *);
static void							wr_msg_402(wi_array_t *);
static void							wr_msg_410(wi_array_t *);
static void							wr_msg_411(wi_array_t *);
static void							wr_msg_420(wi_array_t *);
static void							wr_msg_421(wi_array_t *);


wi_string_encoding_t				*wr_client_string_encoding;
wi_string_encoding_t				*wr_server_string_encoding;

wi_string_t							*wr_host;
wi_uinteger_t						wr_port;

wr_server_t							*wr_server;

wi_string_t							*wr_nick;
wi_string_t							*wr_status;
wi_string_t							*wr_icon;
wi_string_t							*wr_login;
wi_string_t							*wr_password;

wi_string_t							*wr_icon_path;
wi_string_t							*wr_timestamp_format;

static const char					wr_default_icon[] =
	"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"
	"Vy/xW31D+jfvNtPdS+ASBQAAAABJRU5ErkJggg==";

wi_socket_tls_t						*wr_socket_tls;
wi_socket_t							*wr_socket;
wi_address_t						*wr_address;

uint64_t							wr_received_bytes;
uint64_t							wr_transferred_bytes;

wi_integer_t						wr_news_count;
wi_integer_t						wr_news_limit;

wi_time_interval_t					wr_ping_time;

wi_boolean_t						wr_connected;
wi_boolean_t						wr_logged_in;


void wr_client_init(void) {
	wr_socket_tls = wi_socket_tls_init_with_type(wi_socket_tls_alloc(), WI_SOCKET_TLS_CLIENT);
	
	if(!wr_socket_tls)
		wi_log_err(WI_STR("Could not create TLS context: %m"));
	
	if(!wi_socket_tls_set_ciphers(wr_socket_tls, WI_STR("ALL:NULL:!MD5:@STRENGTH")))
		wi_log_err(WI_STR("Could not set TLS ciphers: %m"));
	
	wr_server_string_encoding = wi_string_encoding_init_with_charset(
		wi_string_encoding_alloc(),
		WI_STR("UTF-8"),
		WI_STRING_ENCODING_IGNORE | WI_STRING_ENCODING_TRANSLITERATE);
	
	wr_set_charset(WI_STR("ISO-8859-1"));
	
	wr_nick = wi_retain(wi_user_name());
	wr_icon = wi_string_init_with_cstring(wi_string_alloc(), wr_default_icon);
}



#pragma mark -

wi_boolean_t wr_set_charset(wi_string_t *charset) {
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

void wr_connect(wi_string_t *hostname, wi_uinteger_t port, wi_string_t *login, wi_string_t *password) {
	wi_enumerator_t		*enumerator;
	wi_array_t			*addresses;
	wi_address_t		*address;
	wi_socket_t			*socket;
	wi_string_t			*ip;
	
	if(wr_connected)
		wr_disconnect();
	
	wr_printf_prefix(WI_STR("Connecting to %@..."), hostname);
	
	if(port == 0)
		port = WR_CONTROL_PORT;
	
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

		if(!wi_socket_connect_tls(socket, wr_socket_tls, 10.0)) {
			wr_printf_prefix(WI_STR("Could not connect to %@: %m"), ip);

			continue;
		}

		wr_printf_prefix(WI_STR("Connected using %@/%@/%u bits, logging in..."),
			wi_socket_cipher_version(socket),
			wi_socket_cipher_name(socket),
			wi_socket_cipher_bits(socket));

		wr_connected	= true;
		wr_host			= wi_retain(hostname);
		wr_port			= port;
		wr_login		= wi_retain(login);
		wr_password		= wi_retain(password);
		wr_socket		= wi_retain(socket);
		wr_address		= wi_retain(address);
		
		wr_runloop_add_socket(wr_socket, &wr_runloop_server_callback);
		wr_send_command(WI_STR("HELLO"));

		break;
	}

	if(wr_socket)
		wi_socket_set_direction(wr_socket, WI_SOCKET_READ);
}



void wr_disconnect(void) {
	wr_runloop_remove_socket(wr_socket);
	wi_socket_close(wr_socket);
	wi_release(wr_socket);

	if(wr_connected) {
		wr_wprintf_prefix(wr_console_window, WI_STR("Connection to %@ closed"),
			wr_host);
	}

	wi_release(wr_server);

	wi_release(wr_host);
	wi_release(wr_login);
	wi_release(wr_password);
	wi_release(wr_address);

	wr_windows_clear();
	wr_chats_clear();
	wr_files_clear();
	wr_transfers_clear();
	wr_users_clear();

	wr_connected = false;
	wr_logged_in = false;
	
	wr_draw_header();
	wr_draw_divider();
}



#pragma mark -

static wi_integer_t wr_runloop_server_callback(wi_socket_t *socket) {
	wi_string_t		*string;
	uint32_t		message = 0;
	
	string = wi_socket_read_to_string(wr_socket, 0.0, WI_STR(WR_MESSAGE_SEPARATOR_STR));
	
	if(string && wi_string_length(string) > 0) {
		message = wr_parse_message(string);
	} else {
		if(!string)
			wr_printf_prefix(WI_STR("Could not read from server: %m"));

		wr_disconnect();
	}
	
	return message;
}



#pragma mark -

static uint32_t wr_parse_message(wi_string_t *buffer) {
	wi_array_t		*arguments;
	wi_string_t		*string;
	uint32_t		message;
	
	string = wi_string_by_converting_encoding(buffer, wr_server_string_encoding, wr_client_string_encoding);

	wi_parse_wired_message(string, &message, &arguments);

	switch(message) {
		case 200:		wr_msg_200(arguments);		break;
		case 201:		wr_msg_201(arguments);		break;
		case 202:		wr_msg_202(arguments);		break;
		case 300:		wr_msg_300(arguments);		break;
		case 301:		wr_msg_301(arguments);		break;
		case 302:		wr_msg_302(arguments);		break;
		case 303:		wr_msg_303(arguments);		break;
		case 304:		wr_msg_304(arguments);		break;
		case 305:		wr_msg_305(arguments);		break;
		case 306:		wr_msg_306(arguments);		break;
		case 307:		wr_msg_307(arguments);		break;
		case 308:		wr_msg_308(arguments);		break;
		case 309:		wr_msg_309(arguments);		break;
		case 310:		wr_msg_310(arguments);		break;
		case 311:		wr_msg_311(arguments);		break;
		case 320:		wr_msg_320(arguments);		break;
		case 321:		wr_msg_321(arguments);		break;
		case 322:		wr_msg_322(arguments);		break;
		case 330:		wr_msg_330(arguments);		break;
		case 331:		wr_msg_331(arguments);		break;
		case 332:		wr_msg_332(arguments);		break;
		case 340:									break;
		case 341:		wr_msg_341(arguments);		break;
		case 400:		wr_msg_400(arguments);		break;
		case 401:		wr_msg_401(arguments);		break;
		case 402:		wr_msg_402(arguments);		break;
		case 410:		wr_msg_410(arguments);		break;
		case 411:		wr_msg_411(arguments);		break;
		case 420:		wr_msg_420(arguments);		break;
		case 421:		wr_msg_421(arguments);		break;
			
		case 500:
		case 501:
		case 502:
		case 503:
			wr_printf_prefix(WI_STR("%@: Command failed (%d)"),
				wr_last_command, message);
			break;

		case 510:
			wr_printf_prefix(WI_STR("%@: Login failed, wrong login or password"),
				wr_last_command);
			
			wr_disconnect();
			break;

		case 511:
			wr_printf_prefix(WI_STR("%@: Login failed, host is banned"),
				wr_last_command);

			wr_disconnect();
			break;

		case 512:
			wr_printf_prefix(WI_STR("%@: Client not found"),
				wr_last_command);
			break;

		case 513:
			wr_printf_prefix(WI_STR("%@: Account not found"),
				wr_last_command);
			break;

		case 514:
			wr_printf_prefix(WI_STR("%@: Account already exists"),
				wr_last_command);
			break;

		case 515:
			wr_printf_prefix(WI_STR("%@: User cannot be disconnected"),
				wr_last_command);
			break;

		case 516:
			wr_printf_prefix(WI_STR("%@: Permission denied"),
				wr_last_command);
			break;

		case 520:
			wr_printf_prefix(WI_STR("%@: File or directory not found"),
				wr_last_command);
			break;

		case 521:
			if(!wr_transfers_recursive_upload) {
				wr_printf_prefix(WI_STR("%@: File or directory already exists"),
					wr_last_command);
			}
			break;

		case 522:
			wr_printf_prefix(WI_STR("%@: Checksum mismatch"),
				wr_last_command);
			break;

		case 523:
			wr_printf_prefix(WI_STR("%@: Queue limit exceeded"),
				wr_last_command);
			break;
		
		case 602:									break;

		default:
			string = wi_array_components_joined_by_string(arguments, WI_STR(" "));
			
			wr_printf_prefix(WI_STR("%@: Unknown message: %d %@"),
				wr_last_command, message, string);
			break;
	}

	wr_received_bytes += wi_string_length(buffer);
	
	return message;
}



wi_boolean_t wr_send_command(wi_string_t *fmt, ...) {
	wi_string_t		*string;
	wi_integer_t	result;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	result = wr_send_command_on_socket(wr_socket, WI_STR("%@"), string);

	if(result > 0)
		wr_transferred_bytes += wi_string_length(string);
	
	wi_release(string);

	return (result > 0);
}



wi_boolean_t wr_send_command_on_socket(wi_socket_t *socket, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	wi_integer_t	result;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wi_string_convert_encoding(string, wr_client_string_encoding, wr_server_string_encoding);

	result = wi_socket_write_format(socket, 15.0, WI_STR("%@%c"), string, WR_MESSAGE_SEPARATOR);

	if(result <= 0)
		wr_printf_prefix(WI_STR("Could not write to server: %m"));
	
	wi_release(string);

	return (result > 0);
}



#pragma mark -

static void wr_msg_200(wi_array_t *arguments) {
	wi_string_t		*password;
	double			protocol;
	
	protocol = wi_string_double(wr_protocol_version_string);
	
	wr_server = wr_server_init(wr_server_alloc());
	wr_server->version = wi_retain(WI_ARRAY(arguments, 0));
	wr_server->protocol = wi_string_double(WI_ARRAY(arguments, 1));
	wr_server->name = wi_retain(WI_ARRAY(arguments, 2));
	wr_server->description = wi_retain(WI_ARRAY(arguments, 3));
	wr_server->startdate = wi_date_init_with_rfc3339_string(wi_date_alloc(), WI_ARRAY(arguments, 4));
	wr_server->files = wi_string_uint32(WI_ARRAY(arguments, 5));
	wr_server->size = wi_string_uint64(WI_ARRAY(arguments, 6));

	wr_draw_divider();
	
	if(!wr_logged_in) {
		if(wr_server->protocol > protocol) {
			wr_wprintf_prefix(wr_console_window, WI_STR("Server protocol version %.1f may not be fully compatible with client protocol version %.1f"),
				wr_server->protocol, protocol);
		}

		wr_send_command(WI_STR("CLIENT %#@"), wr_client_version_string);
		wr_send_command(WI_STR("NICK %#@"), wr_nick);
		wr_send_command(WI_STR("STATUS %#@"), wr_status);
		wr_send_command(WI_STR("ICON %u%c%#@"), 0, WR_FIELD_SEPARATOR, wr_icon);
		wr_send_command(WI_STR("USER %#@"), wr_login ? wr_login : WI_STR("guest"));
		
		if(wr_password && wi_string_length(wr_password) > 0)
			password = wi_string_sha1(wr_password);
		else
			password = NULL;

		wr_send_command(WI_STR("PASS %#@"), password);
		
		wr_send_command(WI_STR("WHO %u"), 1);

		wr_logged_in = true;
	}
}



static void wr_msg_201(wi_array_t *arguments) {
	wr_wprintf_prefix(wr_console_window, WI_STR("Logged in, welcome to %@"), wr_server->name);
}



static void wr_msg_202(wi_array_t *arguments) {
	wi_time_interval_t	interval;

	if(wr_ping_time > 0.0) {
		interval = wi_time_interval() - wr_ping_time;
		
		wr_wprintf_prefix(wr_console_window, WI_STR("Ping reply after %.2fms"), interval * 1000.0);
		
		wr_ping_time = 0.0;
	}
}



static void wr_msg_300(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	wr_uid_t	uid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	uid = wi_string_uint32(WI_ARRAY(arguments, 1));

	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);
	
	if(user && !wr_is_ignored(wr_user_nick(user)))
		wr_wprint_say(wr_windows_window_with_chat(chat), wr_user_nick(user), WI_ARRAY(arguments, 2));
}



static void wr_msg_301(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	wr_uid_t	uid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	uid = wi_string_uint32(WI_ARRAY(arguments, 1));

	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);
	
	if(user && !wr_is_ignored(wr_user_nick(user)))
		wr_wprint_me(wr_windows_window_with_chat(chat), wr_user_nick(user), WI_ARRAY(arguments, 2));
}



static void wr_msg_302(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	
	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wr_chats_chat_with_cid(cid);

	user = wr_user_init_with_arguments(wr_user_alloc(), arguments);
	wr_chat_add_user(chat, user);
	wi_release(user);

	wr_draw_divider();
	wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has joined"),
		wr_user_nick(user));
}



static void wr_msg_303(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	wr_uid_t	uid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	uid = wi_string_uint32(WI_ARRAY(arguments, 1));

	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(chat, uid);

	if(user) {
		wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has left"),
			wr_user_nick(user));
		
		wr_chat_remove_user(chat, user);
		wr_draw_divider();
	}
}



static void wr_msg_304(wi_array_t *arguments) {
	wi_string_t		*nick;
	wr_user_t		*user;
	wr_uid_t		uid;

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user) {
		nick = WI_ARRAY(arguments, 4);
		
		if(!wi_is_equal(wr_user_nick(user), nick)) {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ is now known as %@"),
				wr_user_nick(user), nick);

			wr_user_set_nick(user, nick);
		}

		wr_user_set_idle(user, wi_string_bool(WI_ARRAY(arguments, 1)));
		wr_user_set_admin(user, wi_string_bool(WI_ARRAY(arguments, 2)));
		wr_user_set_status(user, WI_ARRAY(arguments, 5));
	}
}



static void wr_msg_305(wi_array_t *arguments) {
	wr_user_t		*user;
	wr_window_t		*window;
	wr_uid_t		uid;

	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user && !wr_is_ignored(wr_user_nick(user))) {
		window = wr_windows_window_with_user(user);
		
		if(!window) {
			window = wr_window_init_with_user(wr_window_alloc(), user);
			wr_windows_add_window(window);
			wi_release(window);
		}
		
		wr_wprint_msg(window, wr_user_nick(user), WI_ARRAY(arguments, 1));
		wr_reply_uid = wr_user_id(user);
	}
}



static void wr_msg_306(wi_array_t *arguments) {
	wi_string_t		*message;
	wr_user_t		*killer, *victim;
	wr_uid_t		killer_uid, victim_uid;

	victim_uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	killer_uid = wi_string_uint32(WI_ARRAY(arguments, 1));
	message = WI_ARRAY(arguments, 2);

	victim = wr_chat_user_with_uid(wr_public_chat, victim_uid);
	killer = wr_chat_user_with_uid(wr_public_chat, killer_uid);

	if(killer && victim) {
		if(wi_string_length(message) > 0) {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ was kicked by %@: %@"),
				wr_user_nick(victim), wr_user_nick(killer), message);
		} else {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ was kicked by %@"),
				wr_user_nick(victim), wr_user_nick(killer));
		}
	}

	if(victim) {
		wr_chat_remove_user(wr_public_chat, victim);
		wr_draw_divider();
	}
}



static void wr_msg_307(wi_array_t *arguments) {
	wi_string_t		*message;
	wr_user_t		*killer, *victim;
	wr_uid_t		killer_uid, victim_uid;

	victim_uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	killer_uid = wi_string_uint32(WI_ARRAY(arguments, 1));
	message = WI_ARRAY(arguments, 2);

	victim = wr_chat_user_with_uid(wr_public_chat, victim_uid);
	killer = wr_chat_user_with_uid(wr_public_chat, killer_uid);

	if(killer && victim) {
		if(wi_string_length(message) > 0) {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ was banned by %@: %@"),
				wr_user_nick(victim), wr_user_nick(killer), message);
		} else {
			wr_wprintf_prefix(wr_console_window, WI_STR("%@ was banned by %@"),
				wr_user_nick(victim), wr_user_nick(killer));
		}
	}

	if(victim) {
		wr_chat_remove_user(wr_public_chat, victim);
		wr_draw_divider();
	}
}



static void wr_msg_308(wi_array_t *arguments) {
	wi_enumerator_t		*enumerator;
	wi_date_t			*date;
	wi_array_t			*array, *transfers;
	wi_string_t			*string, *interval, *name, *transferred, *size, *speed;
	wi_uinteger_t		n;
	wi_boolean_t		first;
	
	wr_printf_prefix(WI_STR("User info:"),
		WI_ARRAY(arguments, 4));

	wr_printf_block(WI_STR("Nick:        %@"), WI_ARRAY(arguments, 4));

	if(wr_server->protocol >= 1.1)
		wr_printf_block(WI_STR("Status:      %@"), WI_ARRAY(arguments, 15));

	wr_printf_block(WI_STR("Login:       %@"), WI_ARRAY(arguments, 5));
	wr_printf_block(WI_STR("ID:          %@"), WI_ARRAY(arguments, 0));
	wr_printf_block(WI_STR("Address:     %@"), WI_ARRAY(arguments, 6));
	wr_printf_block(WI_STR("Host:        %@"), WI_ARRAY(arguments, 7));
	wr_printf_block(WI_STR("Client:      %@"), WI_ARRAY(arguments, 8));
	wr_printf_block(WI_STR("Cipher:      %@/%@ bits"), WI_ARRAY(arguments, 9), WI_ARRAY(arguments, 10));

	date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 11));
	interval = wi_time_interval_string(wi_date_time_interval_since_now(date));
    string = wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));
	wr_printf_block(WI_STR("Login Time:  %@, since %@"), interval, string);

	date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 12));
	interval = wi_time_interval_string(wi_date_time_interval_since_now(date));
    string = wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));
	wr_printf_block(WI_STR("Idle Time:   %@, since %@"), interval, string);
	
	for(n = WR_TRANSFER_DOWNLOAD; n <= WR_TRANSFER_UPLOAD; n++) {
		string		= WI_ARRAY(arguments, (n == WR_TRANSFER_DOWNLOAD) ? 13 : 14);
		transfers	= wi_string_components_separated_by_string(string, WI_STR(WR_GROUP_SEPARATOR_STR));
		enumerator	= wi_array_data_enumerator(transfers);
		first		= true;
		
		while((string = wi_enumerator_next_data(enumerator))) {
			array	= wi_string_components_separated_by_string(string, WI_STR(WR_RECORD_SEPARATOR_STR));
			
			if(wi_array_count(array) == 4) {
				name		= wi_string_last_path_component(WI_ARRAY(array, 0));
				transferred	= wr_files_string_for_size(wi_string_uint64(WI_ARRAY(array, 1)));
				size		= wr_files_string_for_size(wi_string_uint64(WI_ARRAY(array, 2)));
				speed		= wr_files_string_for_size(wi_string_uint32(WI_ARRAY(array, 3)));
				
				if(first) {
					if(n == WR_TRANSFER_DOWNLOAD) {
						wr_printf_block(WI_STR("Downloads:   %@, %@ of %@, %@/s"),
							name, transferred, size, speed);
					} else {
						wr_printf_block(WI_STR("Uploads:     %@, %@ of %@, %@/s"),
							name, transferred, size, speed);
					}
				} else {
					wr_printf_block(WI_STR("             %@, %@ of %@, %@/s"),
						name, transferred, size, speed);
				}
			}
			
			first = false;
		}
	}
}



static void wr_msg_309(wi_array_t *arguments) {
	wr_user_t	*user;
	wr_uid_t	uid;
	
	uid = wi_string_uint32(WI_ARRAY(arguments, 0));
	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user && !wr_is_ignored(wr_user_nick(user))) {
		wr_wprintf_prefix(wr_console_window, WI_STR("Broadcast message from %@:"),
			wr_user_nick(user));
		wr_wprintf_block(wr_console_window, WI_STR("%@"),
			WI_ARRAY(arguments, 1));
	}
}



static void wr_msg_310(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wr_chats_chat_with_cid(cid);

	user = wr_user_init_with_arguments(wr_user_alloc(), arguments);
	wr_chat_add_user(chat, user);
	wi_release(user);
}



static void wr_msg_311(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_cid_t	cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wr_chats_chat_with_cid(cid);

	wr_draw_divider();
	wr_print_users(wr_windows_window_with_chat(chat));
}



static void wr_msg_320(wi_array_t *arguments) {
	wi_date_t		*date;
	wi_string_t		*string;
	
	if(wr_news_count >= 0) {
		wr_news_count++;

		if(wr_news_count > wr_news_limit) {
			wr_printf_prefix(WI_STR("news: Displayed %u %@, use /news -ALL to see more"),
				wr_news_limit,
				wr_news_limit == 1
					? WI_STR("post")
					: WI_STR("posts"));

			wr_news_count = -1;
		} else {
			date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 1));
			string = wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));

			wr_printf_prefix(WI_STR("From %@ (%@):"), WI_ARRAY(arguments, 0), string);
			wr_printf_block(WI_STR("%@"), WI_ARRAY(arguments, 2));
		}
	}
}



static void wr_msg_321(wi_array_t *arguments) {
	wr_news_count = 0;
}



static void wr_msg_322(wi_array_t *arguments) {
	wr_wprintf_prefix(wr_console_window, WI_STR("News from %@:"), WI_ARRAY(arguments, 0));
	wr_wprintf_block(wr_console_window, WI_STR("%@"), WI_ARRAY(arguments, 2));
}



static void wr_msg_330(wi_array_t *arguments) {
	wr_cid_t		cid;
	
	if(wr_private_chat) {
		cid = wi_string_int32(WI_ARRAY(arguments, 0));
		
		wr_chat_set_id(wr_private_chat, cid);
		wr_chats_add_chat(wr_private_chat);

		wr_send_command(WI_STR("WHO %u"), cid);
		
		if(wr_private_chat_invite_uid > 0) {
			wr_send_command(WI_STR("INVITE %u%c%u"),
				wr_private_chat_invite_uid,		WR_FIELD_SEPARATOR,
				cid);
		}
		
		wi_release(wr_private_chat);
		wr_private_chat = NULL;
		
		wr_private_chat_invite_uid = 0;
	}
}



static void wr_msg_331(wi_array_t *arguments) {
	wr_window_t	*window;
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	wr_uid_t	uid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	uid = wi_string_uint32(WI_ARRAY(arguments, 1));

	user = wr_chat_user_with_uid(wr_public_chat, uid);

	if(user) {
		wr_send_command(WI_STR("JOIN %u"), cid);
		wr_send_command(WI_STR("WHO %u"), cid);
	
		chat = wr_chat_init_private_chat(wr_chat_alloc());
		wr_chat_set_id(chat, cid);
		wr_chats_add_chat(chat);
		wi_release(chat);

		window = wr_window_init_with_chat(wr_window_alloc(), chat);
		wr_windows_add_window(window);
		wr_windows_show_window(window);
		wi_release(window);
	}
}



static void wr_msg_332(wi_array_t *arguments) {
	wr_chat_t	*chat;
	wr_user_t	*user;
	wr_cid_t	cid;
	wr_uid_t	uid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	uid = wi_string_uint32(WI_ARRAY(arguments, 1));

	chat = wr_chats_chat_with_cid(cid);
	user = wr_chat_user_with_uid(wr_public_chat, uid);
	
	if(user && chat) {
		wr_wprintf_prefix(wr_windows_window_with_chat(chat), WI_STR("%@ has declined invitation"),
			wr_user_nick(user));
	}
}



static void wr_msg_341(wi_array_t *arguments) {
	wi_date_t		*date;
	wr_chat_t		*chat;
	wr_window_t		*window;
	wr_cid_t		cid;

	cid = wi_string_uint32(WI_ARRAY(arguments, 0));
	chat = wr_chats_chat_with_cid(cid);
	
	if(chat) {
		window = wr_windows_window_with_chat(chat);

		if(window && wr_window_is_chat(window)) {
			wi_release(window->topic.nick);
			window->topic.nick = wi_retain(WI_ARRAY(arguments, 1));
			
			wi_release(window->topic.date);
			date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 4));
			window->topic.date = wi_retain(wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y")));

			wi_release(window->topic.topic);
			window->topic.topic = wi_retain(WI_ARRAY(arguments, 5));
			
			wr_draw_header();
			wr_print_topic();
		}
	}
}



static void wr_msg_400(wi_array_t *arguments) {
	wr_transfer_t		*transfer;

	transfer = wr_transfers_transfer_with_remote_path(WI_ARRAY(arguments, 0));

	if(!transfer)
		return;
	
	wr_transfer_open(transfer, wi_string_uint64(WI_ARRAY(arguments, 1)), WI_ARRAY(arguments, 2));
}



static void wr_msg_401(wi_array_t *arguments) {
	wr_transfer_t	*transfer;

	transfer = wr_transfers_transfer_with_remote_path(WI_ARRAY(arguments, 0));

	if(transfer) {
		transfer->state = WR_TRANSFER_QUEUED;
		transfer->queue = wi_string_uint32(WI_ARRAY(arguments, 1));
	}
}



static void wr_msg_402(wi_array_t *arguments) {
	wi_date_t			*date;
	wi_string_t			*path, *kind, *string;
	wr_file_t			*file;
	wr_transfer_t		*transfer;
	wi_file_offset_t	size;
	wr_file_type_t		type;

	path = WI_ARRAY(arguments, 0);
	type = wi_string_uint32(WI_ARRAY(arguments, 1));
	size = wi_string_uint64(WI_ARRAY(arguments, 2));

	if(wr_stat_state == WR_STAT_FILE) {
		wr_printf_prefix(WI_STR("File info for %@:"), wi_string_last_path_component(path));
		
		wr_printf_block(WI_STR("Path:      %@"), path);

		switch(type) {
			case WR_FILE_FILE:
				kind = WI_STR("File");
				break;

			case WR_FILE_DIRECTORY:
				kind = WI_STR("Folder");
				break;

			case WR_FILE_UPLOADS:
				kind = WI_STR("Uploads Folder");
				break;

			case WR_FILE_DROPBOX:
				kind = WI_STR("Drop Box Folder");
				break;
			
			default:
				kind = NULL;
				break;
		}

		wr_printf_block(WI_STR("Kind:      %@"), kind);
		
		if(type == WR_FILE_FILE)
			string = wr_files_string_for_size(size);
		else
			string = wr_files_string_for_count(size);
		
		wr_printf_block(WI_STR("Size:      %@"), string);

		date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 3));
		string = wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));
		wr_printf_block(WI_STR("Created:   %@"), string);

		date = wi_date_with_rfc3339_string(WI_ARRAY(arguments, 4));
		string = wi_date_string_with_format(date, WI_STR("%a %b %e %T %Y"));
		wr_printf_block(WI_STR("Modified:  %@"), string);

		if(type == WR_FILE_FILE)
			wr_printf_block(WI_STR("Checksum:  %@"), WI_ARRAY(arguments, 5));

		if(wr_server->protocol >= 1.1)
			wr_printf_block(WI_STR("Comment:   %@"), WI_ARRAY(arguments, 6));
	}
	else if(wr_stat_state == WR_STAT_TRANSFER) {
		transfer = wr_transfers_transfer_with_remote_path(WI_ARRAY(arguments, 0));
		
		if(transfer) {
			if(type == WR_FILE_FILE) {
				if(transfer->checksum && !wi_is_equal(transfer->checksum, WI_ARRAY(arguments, 5))) {
					wr_printf_prefix(WI_STR("get: Checksum mismatch for \"%@\""),
						transfer->name);
					
					wr_transfer_stop(transfer);
					
					return;
				}
				
				if(!transfer->recursive) {
					file = wr_file_init_with_arguments(wr_file_alloc(), arguments);
					wr_transfer_download_add_file(transfer, file, false);
					wi_release(file);
				}
				
				wr_transfer_request(transfer);
			} else {
				wr_ls_state = WR_LS_TRANSFER;
				transfer->recursive = true;
				
				wr_files_clear();
				wr_send_command(WI_STR("LISTRECURSIVE %#@"), path);
			}
		}
	}
}



static void wr_msg_410(wi_array_t *arguments) {
	wr_file_t		*file;
	
	file = wr_file_init_with_arguments(wr_file_alloc(), arguments);
	wi_array_add_data(wr_files, file);
	wi_release(file);
}



static void wr_msg_411(wi_array_t *arguments) {
	wr_transfer_t		*transfer;
	wi_file_offset_t	free;

	if(wr_ls_state == WR_LS_LISTING) {
		free = wi_string_uint64(WI_ARRAY(arguments, 1));

		wr_printf_prefix(WI_STR("Listing of %@ (%@ available):"), wr_files_ld, wr_files_string_for_size(free));

		if(wi_array_count(wr_files) == 0)
			wr_printf_block(WI_STR("(empty)"));
		else
			wr_print_files();
	}
	else if(wr_ls_state == WR_LS_TRANSFER) {
		transfer = wr_transfers_transfer_with_remote_path(WI_ARRAY(arguments, 0));
		
		if(transfer) {
			if(transfer->type == WR_TRANSFER_DOWNLOAD)
				wr_transfer_download_add_files(transfer, wr_files);
			else
				wr_transfer_upload_remove_files(transfer, wr_files);
				
			transfer->state = WR_TRANSFER_WAITING;
			transfer->listed = true;
			
			wr_transfer_request(transfer);
		}
	}
}



static void wr_msg_420(wi_array_t *arguments) {
	wr_file_t		*file;

	file = wr_file_init_with_arguments(wr_file_alloc(), arguments);
	wi_array_add_data(wr_files, file);
	wi_release(file);
}



static void wr_msg_421(wi_array_t *arguments) {
	wr_printf_prefix(WI_STR("Search results:"));

	if(wi_array_count(wr_files) == 0)
		wr_printf_block(WI_STR("(none)"));
	else
		wr_print_files();
}
