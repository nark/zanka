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

#ifdef HAVE_CORESERVICES_CORESERVICES_H
#include <CoreServices/CoreServices.h>
#endif

#include <stdarg.h>
#include <wired/wired.h>

#include "accounts.h"
#include "banlist.h"
#include "commands.h"
#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "trackers.h"
#include "transfers.h"
#include "version.h"

static void							wd_control_listen_thread(wi_runtime_instance_t *);
static void							wd_transfer_listen_thread(wi_runtime_instance_t *);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
static void							wd_cf_thread(wi_runtime_instance_t *);
#endif


static wi_list_t					*wd_control_sockets;
static wi_list_t					*wd_transfer_sockets;

static wi_socket_context_t			*wd_control_socket_context;
static wi_socket_context_t			*wd_transfer_socket_context;

wi_string_t							*wd_banner;


void wd_init_server(void) {
	wi_list_t				*list, *addresses;
	wi_list_node_t			*node, *next_node;
	wi_address_t			*address;
	wi_socket_t				*control_socket, *transfer_socket;
	wi_string_t				*ip, *string;
	wi_address_family_t		family;

	wd_control_sockets	= wi_list_init(wi_list_alloc());
	wd_transfer_sockets	= wi_list_init(wi_list_alloc());
	addresses			= wi_list_init(wi_list_alloc());

	if(wi_list_count(wd_settings.address) > 0) {
		/* listen on configured addresses */
		wi_list_rdlock(wd_settings.address);
		WI_LIST_FOREACH(wd_settings.address, node, string) {
			list = wi_host_addresses(wi_host_with_string(string));

			if(list)
				wi_list_append_data_from_list(addresses, list);
			else
				wi_log_err(WI_STR("Could not resolve \"%@\": %m"), string);
		}
		wi_list_unlock(wd_settings.address);
	} else {
		/* add wildcard addresses */
		wi_list_append_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV4));
		wi_list_append_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV6));
	}

	for(node = wi_list_first_node(addresses); node; node = next_node) {
		next_node		= wi_list_node_next_node(node);
		address			= wi_list_node_data(node);
		ip				= wi_address_string(address);
		family			= wi_address_family(address);
		control_socket	= NULL;
		transfer_socket	= NULL;

		/* force address family? */
		if(wd_address_family != WI_ADDRESS_NULL && family != wd_address_family)
			goto next;
		
		/* create sockets */
		wi_address_set_port(address, wd_settings.port);
		control_socket	= wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP);

		wi_address_set_port(address, wd_settings.port + 1);
		transfer_socket	= wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP);
	
		if(!control_socket || !transfer_socket) {
			wi_log_warn(WI_STR("Could not create socket for %@: %m"), ip);
			
			goto next;
		}

		/* listen on sockets */
		if(!wi_socket_listen(control_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(control_socket)));
			
			goto next;
		}

		if(!wi_socket_listen(transfer_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(transfer_socket)));
			
			goto next;
		}
		
		wi_socket_set_interactive(control_socket, true);
		wi_socket_set_interactive(transfer_socket, false);

		/* add to list of sockets */
		wi_list_append_data(wd_control_sockets, control_socket);
		wi_list_append_data(wd_transfer_sockets, transfer_socket);

		wi_log_info(WI_STR("Listening on %@ ports %d-%d"),
			ip, wd_settings.port, wd_settings.port + 1);

next:
		wi_release(control_socket);
		wi_release(transfer_socket);
	}

	if(wi_list_count(wd_control_sockets) == 0 || wi_list_count(wd_transfer_sockets) == 0)
		wi_log_err(WI_STR("No addresses available for listening"));
	
	wi_release(addresses);
}



void wd_fork_server(void) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* spawn the Core Foundation run loop thread */
	if(wd_settings.zeroconf) {
		if(!wi_thread_create_thread(wd_cf_thread, NULL))
			wi_log_err(WI_STR("Could not create a thread: %m"));
	}
#endif

	/* spawn the server threads */
	if(!wi_thread_create_thread(wd_control_listen_thread, NULL) ||
	   !wi_thread_create_thread(wd_transfer_listen_thread, NULL))
		wi_log_err(WI_STR("Could not create a thread: %m"));
}



void wd_config_server(void) {
	wi_string_t		*string;

	/* reload banner */
	if(wd_settings.banner) {
		if(wd_settings.banner_changed) {
			string = wi_string_init_with_contents_of_file(wi_string_alloc(), wd_settings.banner);
			
			if(string) {
				wd_banner = wi_retain(wi_string_base64(string));
				wi_release(string);
			} else {
				wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.banner);
			}
		}
	} else {
		wi_release(wd_banner);
		wd_banner = NULL;
	}

	/* reload server name/description */
	if(wd_settings.name_changed || wd_settings.description_changed) {
		string = wi_date_iso8601_string(wd_start_date);
		
		wd_broadcast_lock();
		wd_broadcast(WD_PUBLIC_CID, 200, WI_STR("%#@%c%#@%c%#@%c%#@%c%#@%c%u%c%llu"),
					 wd_server_version_string,		WD_FIELD_SEPARATOR,
					 wd_protocol_version_string,	WD_FIELD_SEPARATOR,
					 wd_settings.name,				WD_FIELD_SEPARATOR,
					 wd_settings.description,		WD_FIELD_SEPARATOR,
					 string,						WD_FIELD_SEPARATOR,
					 wd_files_unique_count,			WD_FIELD_SEPARATOR,
					 wd_files_unique_size);
		wd_broadcast_unlock();
	}

	/* set SSL cipher list */
	if(wd_settings.controlcipher) {
		if(!wi_socket_context_set_ssl_ciphers(wd_control_socket_context, wd_settings.controlcipher)) {
			wi_log_err(WI_STR("Could not set SSL cipher list \"%@\": %m"),
				wd_settings.controlcipher);
		}
	}

	if(wd_settings.transfercipher) {
		if(!wi_socket_context_set_ssl_ciphers(wd_transfer_socket_context, wd_settings.transfercipher)) {
			wi_log_err(WI_STR("Could not set SSL cipher list \"%@\": %m"),
				wd_settings.transfercipher);
	   }
	}

	/* load SSL certificate */
	if(wd_settings.certificate) {
		if(!wi_socket_context_set_ssl_certificate(wd_control_socket_context, wd_settings.certificate) ||
		   !wi_socket_context_set_ssl_certificate(wd_transfer_socket_context, wd_settings.certificate)) {
			wi_log_err(WI_STR("Could not load certificate %@: %m"),
				wd_settings.certificate);
		}
	}
}



#pragma mark -

void wd_init_ssl(void) {
	unsigned char	dh1024_p[] = {
		0xBC,0xBB,0x2B,0x4F,0x58,0x58,0x9C,0x4D,0x46,0x0D,0xBB,0x9E,
		0x4D,0x85,0x69,0x56,0x43,0x5E,0xFB,0xC8,0xF6,0xC0,0xAC,0x8E,
		0xCB,0xF6,0x0B,0x38,0x8F,0x25,0xD6,0x7A,0xA1,0x26,0xC4,0x74,
		0x74,0x98,0x96,0x3F,0x96,0x90,0x3B,0x00,0x6E,0xE3,0x0A,0x61,
		0xA9,0xA2,0x62,0x49,0xDA,0x7D,0xE0,0x6B,0x8F,0xA7,0x89,0x7F,
		0x41,0x09,0x09,0xA3,0xA2,0x5F,0x2C,0xD3,0x77,0x26,0x8D,0x81,
		0x33,0x04,0xEF,0x40,0x75,0xB2,0xCF,0xBA,0xEF,0xD5,0x08,0xF4,
		0x9E,0x30,0xD2,0x57,0x12,0xD6,0xEA,0x86,0xCA,0x10,0x7B,0x4B,
		0x93,0x42,0x7E,0x79,0x42,0x36,0x5D,0x2B,0x23,0xDB,0x7E,0xAB,
		0xDB,0xFD,0x1B,0xDA,0x86,0x49,0x15,0x92,0x41,0x56,0xDD,0x68,
		0x2C,0x7F,0xAA,0x34,0x56,0x80,0xA5,0x8B };
	unsigned char	dh1024_g[] = { 0x02 };

	wd_control_socket_context	= wi_socket_context_init(wi_socket_context_alloc());
	wd_transfer_socket_context	= wi_socket_context_init(wi_socket_context_alloc());
	
	if(!wi_socket_context_set_ssl_type(wd_control_socket_context, WI_SOCKET_SSL_SERVER) ||
	   !wi_socket_context_set_ssl_type(wd_transfer_socket_context, WI_SOCKET_SSL_SERVER))
		wi_log_err(WI_STR("Could not set SSL context: %m"));
	
	if(!wi_socket_context_set_ssl_dh(wd_control_socket_context, dh1024_p, sizeof(dh1024_p), dh1024_g, sizeof(dh1024_g)) ||
	   !wi_socket_context_set_ssl_dh(wd_transfer_socket_context, dh1024_p, sizeof(dh1024_p), dh1024_g, sizeof(dh1024_g)))
		wi_log_err(WI_STR("Could not set anonymous DH key: %m"));
}



#pragma mark -

static void wd_control_listen_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_address_t		*address;
	wi_string_t			*ip;
	wd_client_t			*client;
	unsigned int		i = 0;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wd_running) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		/* accept new client */
		socket = wi_socket_accept_multiple(wd_control_sockets, wd_control_socket_context, 30.0, &address);

		if(!address) {
			wi_log_err(WI_STR("Could not accept a connection: %m"));
			
			goto next;
		}
		
		ip = wi_address_string(address);
		
		if(!socket) {
			wi_log_err(WI_STR("Could not accept a connection for %@: %m"), ip);
			
			goto next;
		}
		
		wi_socket_set_direction(socket, WI_SOCKET_READ);
		
		wi_log_info(WI_STR("Connect from %@"), ip);
		
		/* spawn a client thread */
		client = wi_autorelease(wd_client_init_with_socket(wd_client_alloc(), socket));

		if(!wi_thread_create_thread(wd_control_thread, client))
			wi_log_err(WI_STR("Could not create a thread for %@: %m"), ip);

next:
		if(++i % 10 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}
	
	wi_release(pool);
}



static void wd_transfer_listen_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_address_t		*address;
	wi_array_t			*arguments;
	wi_string_t			*ip, *string, *command;
	wd_transfer_t		*transfer;
	unsigned int		i = 0;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wd_running) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
		
		/* accept new connection */
		socket = wi_socket_accept_multiple(wd_transfer_sockets, wd_transfer_socket_context, 30.0, &address);
		
		if(!address) {
			wi_log_err(WI_STR("Could not accept a connection: %m"));
			
			goto next;
		}
		
		ip = wi_address_string(address);
		
		if(!socket) {
			wi_log_err(WI_STR("Could not accept a connection for %@: %m"), ip);
			
			goto next;
		}

		string = wi_socket_read_to_string(socket, 5.0, WI_STR(WD_MESSAGE_SEPARATOR_STR));
		
		if(!string || wi_string_length(string) == 0) {
			if(!string)
				wi_log_warn(WI_STR("Could not read from %@: %m"), ip);

			goto next;
		}
		
		/* parse command */
		wi_parse_wired_command(string, &command, &arguments);
		
		if(wi_is_equal(command, WI_STR("TRANSFER")) && wi_array_count(arguments) >= 1) {
			/* get transfer by identifier */
			transfer = wd_transfer_with_hash(WI_ARRAY(arguments, 0));
			
			if(!transfer)
				goto next;
			
			if(!wi_is_equal(ip, transfer->client->ip))
				goto next;
			
			transfer->socket = wi_retain(socket);
			
			/* spawn a transfer thread */
			if(!wi_thread_create_thread(wd_transfer_thread, transfer))
				wi_log_err(WI_STR("Could not create a thread for %@: %m"), ip);
		}

next:
		if(++i % 10 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}
	
	wi_release(pool);
}



#ifdef HAVE_CORESERVICES_CORESERVICES_H

static void wd_cf_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	CFNetServiceRef		service;
	CFStringRef			name;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wd_running) {
		name = CFStringCreateWithCString(NULL, wi_string_cstring(wd_settings.name),
										 kCFStringEncodingUTF8);

		service = CFNetServiceCreate(NULL, CFSTR(""),
									 CFSTR(WD_ZEROCONF_NAME),
									 name, wd_settings.port);

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4
		CFNetServiceRegisterWithOptions(service, 0, NULL);
#else
		CFNetServiceRegister(service, NULL);
#endif

		CFRelease(service);
		CFRelease(name);
	}
	
	wi_release(pool);
}

#endif



#pragma mark -

void wd_reply(unsigned int n, wi_string_t *fmt, ...) {
	wd_client_t		*client = wd_client();
	wi_string_t		*string;
	va_list			ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wd_client_lock_socket(client);
	wi_socket_write(client->socket, 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
	wd_client_unlock_socket(client);
	
	wi_release(string);
}



void wd_reply_error(void) {
	switch(wi_error_code()) {
		case ENOENT:
			wd_reply(520, WI_STR("File or Directory Not Found"));
			break;

		case EEXIST:
			wd_reply(521, WI_STR("File or Directory Exists"));
			break;

		default:
			wd_reply(500, WI_STR("Command Failed"));
			break;
	}
}



void wd_sreply(wi_socket_t *socket, unsigned int n, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wi_socket_write(socket, 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
	
	wi_release(string);	
}



#pragma mark -

void wd_broadcast(wd_cid_t cid, unsigned int n, wi_string_t *fmt, ...) {
	wi_list_node_t	*chat_node, *client_node;
	wd_chat_t		*chat;
	wd_client_t		*client;
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	WI_LIST_FOREACH(wd_chats, chat_node, chat) {
		if(chat->cid == cid) {
			WI_LIST_FOREACH(chat->clients, client_node, client) {
				if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
					wd_client_lock_socket(client);
					wi_socket_write(client->socket, 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
					wd_client_unlock_socket(client);
				}
			}

			break;
		}
	}

	wi_release(string);
}



void wd_broadcast_lock(void) {
	wi_list_rdlock(wd_chats);
}



void wd_broadcast_unlock(void) {
	wi_list_unlock(wd_chats);
}
