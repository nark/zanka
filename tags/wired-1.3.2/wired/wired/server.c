/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#ifdef HAVE_DNS_SD_H
#include <dns_sd.h>
#endif

#include <sys/types.h>
#include <netinet/in.h>
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

#ifdef HAVE_DNS_SD_H

static void							wd_server_register_dnssd(void);
static void							wd_server_register_dnssd_reply(DNSServiceRef, DNSServiceFlags, DNSServiceErrorType, const char *, const char *, const char *, void *);
#endif

static void							wd_control_listen_thread(wi_runtime_instance_t *);
static void							wd_transfer_listen_thread(wi_runtime_instance_t *);


static wi_array_t					*wd_control_sockets;
static wi_array_t					*wd_transfer_sockets;

static wi_socket_context_t			*wd_control_socket_context;
static wi_socket_context_t			*wd_transfer_socket_context;

wi_string_t							*wd_banner;


void wd_server_init(void) {
	wi_enumerator_t			*enumerator;
	wi_array_t				*array, *addresses;
	wi_address_t			*address;
	wi_socket_t				*control_socket, *transfer_socket;
	wi_string_t				*ip, *string;
	wi_address_family_t		family;
	
	wd_control_sockets	= wi_array_init(wi_array_alloc());
	wd_transfer_sockets	= wi_array_init(wi_array_alloc());
	addresses			= wi_array_init(wi_array_alloc());

	if(wi_array_count(wd_settings.address) > 0) {
		/* listen on configured addresses */
		wi_array_rdlock(wd_settings.address);
		
		enumerator = wi_array_data_enumerator(wd_settings.address);
		
		while((string = wi_enumerator_next_data(enumerator))) {
			array = wi_host_addresses(wi_host_with_string(string));

			if(array)
				wi_array_add_data_from_array(addresses, array);
			else
				wi_log_err(WI_STR("Could not resolve \"%@\": %m"), string);
		}
		
		wi_array_unlock(wd_settings.address);
	} else {
		/* add wildcard addresses */
		wi_array_add_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV4));
		wi_array_add_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV6));
	}
	
	enumerator = wi_array_data_enumerator(addresses);
	
	while((address = wi_enumerator_next_data(enumerator))) {
		ip		= wi_address_string(address);
		family	= wi_address_family(address);

		/* force address family? */
		if(wd_address_family != WI_ADDRESS_NULL && family != wd_address_family)
			continue;
		
		/* create sockets */
		wi_address_set_port(address, wd_settings.port);
		control_socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP));

		wi_address_set_port(address, wd_settings.port + 1);
		transfer_socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP));
	
		if(!control_socket || !transfer_socket) {
			wi_log_warn(WI_STR("Could not create socket for %@: %m"), ip);
			
			continue;
		}

		/* listen on sockets */
		if(!wi_socket_listen(control_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(control_socket)));
			
			continue;
		}

		if(!wi_socket_listen(transfer_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(transfer_socket)));
			
			continue;
		}
		
		wi_socket_set_interactive(control_socket, true);
		wi_socket_set_interactive(transfer_socket, false);

		/* add to list of sockets */
		wi_array_add_data(wd_control_sockets, control_socket);
		wi_array_add_data(wd_transfer_sockets, transfer_socket);

		wi_log_info(WI_STR("Listening on %@ ports %d-%d"),
			ip, wd_settings.port, wd_settings.port + 1);
	}

	if(wi_array_count(wd_control_sockets) == 0 || wi_array_count(wd_transfer_sockets) == 0)
		wi_log_err(WI_STR("No addresses available for listening"));
	
	wi_release(addresses);
	
#ifdef HAVE_DNS_SD_H
	wd_server_register_dnssd();
#endif
}



void wd_server_create_threads(void) {
	if(!wi_thread_create_thread(wd_control_listen_thread, NULL) ||
	   !wi_thread_create_thread(wd_transfer_listen_thread, NULL))
		wi_log_err(WI_STR("Could not create a thread: %m"));
}



void wd_server_apply_settings(void) {
	wi_string_t		*string;
	wi_data_t		*data;

	/* reload banner */
	if(wd_settings.banner) {
		if(wd_settings.banner_changed) {
			data = wi_data_init_with_contents_of_file(wi_data_alloc(), wd_settings.banner);
			
			if(data) {
				wi_release(wd_banner);
				wd_banner = wi_retain(wi_data_base64(data));
			} else {
				wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.banner);
			}

			wi_release(data);
		}
	} else {
		wi_release(wd_banner);
		wd_banner = NULL;
	}

	/* reload server name/description */
	if(wd_settings.name_changed || wd_settings.description_changed) {
		string = wi_date_iso8601_string(wd_start_date);
		
		wd_broadcast(wd_public_chat, 200, WI_STR("%#@%c%#@%c%#@%c%#@%c%#@%c%u%c%llu"),
					 wd_server_version_string,		WD_FIELD_SEPARATOR,
					 wd_protocol_version_string,	WD_FIELD_SEPARATOR,
					 wd_settings.name,				WD_FIELD_SEPARATOR,
					 wd_settings.description,		WD_FIELD_SEPARATOR,
					 string,						WD_FIELD_SEPARATOR,
					 wd_files_unique_count,			WD_FIELD_SEPARATOR,
					 wd_files_unique_size);
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

void wd_ssl_init(void) {
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

#ifdef HAVE_DNS_SD_H

static void wd_server_register_dnssd(void) {
	DNSServiceRef			service;
	DNSServiceErrorType		err;

	err = DNSServiceRegister(&service,
							 0,
							 kDNSServiceInterfaceIndexAny,
							 wi_string_cstring(wd_settings.name),
							 WD_DNSSD_NAME,
							 NULL,
							 NULL,
							 htons(wd_settings.port),
							 0,
							 NULL,
							 wd_server_register_dnssd_reply,
							 NULL);
	
	if(err != kDNSServiceErr_NoError)
		wi_log_warn(WI_STR("Could not register for DNS service discovery: %d"), err);
}



static void wd_server_register_dnssd_reply(DNSServiceRef client, DNSServiceFlags flags, DNSServiceErrorType error, const char *name, const char *regtype, const char *domain, void *context) {
	wi_log_info(WI_STR("DNS service discovery reply for %s.%s%s: %d"), name, regtype, domain, error);
}

#endif



#pragma mark -

static void wd_control_listen_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_address_t		*address;
	wi_string_t			*ip;
	wd_user_t			*user;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wd_running) {
		wi_pool_drain(pool);

		/* accept new user */
		socket = wi_socket_accept_multiple(wd_control_sockets, wd_control_socket_context, 30.0, &address);

		if(!address) {
			wi_log_err(WI_STR("Could not accept a connection: %m"));
			
			continue;
		}
		
		ip = wi_address_string(address);
		
		if(!socket) {
			wi_log_err(WI_STR("Could not accept a connection for %@: %m"), ip);
			
			continue;
		}
		
		wi_socket_set_direction(socket, WI_SOCKET_READ);
		
		wi_log_info(WI_STR("Connect from %@"), ip);
		
		/* spawn a user thread */
		user = wd_user_with_socket(socket);

		if(!wi_thread_create_thread(wd_control_thread, user))
			wi_log_err(WI_STR("Could not create a thread for %@: %m"), ip);
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
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wd_running) {
		wi_pool_drain(pool);

		/* accept new connection */
		socket = wi_socket_accept_multiple(wd_transfer_sockets, wd_transfer_socket_context, 30.0, &address);
		
		if(!address) {
			wi_log_err(WI_STR("Could not accept a connection: %m"));
			
			continue;
		}
		
		ip = wi_address_string(address);
		
		if(!socket) {
			wi_log_err(WI_STR("Could not accept a connection for %@: %m"), ip);
			
			continue;
		}

		string = wi_socket_read_to_string(socket, 5.0, WI_STR(WD_MESSAGE_SEPARATOR_STR));
		
		if(!string || wi_string_length(string) == 0) {
			if(!string)
				wi_log_warn(WI_STR("Could not read from %@: %m"), ip);

			continue;
		}
		
		/* parse command */
		wi_parse_wired_command(string, &command, &arguments);
		
		if(wi_is_equal(command, WI_STR("TRANSFER")) && wi_array_count(arguments) >= 1) {
			/* get transfer by identifier */
			transfer = wd_transfers_transfer_with_hash(WI_ARRAY(arguments, 0));
			
			if(!transfer)
				continue;
			
			if(!wi_is_equal(ip, wd_user_ip(transfer->user)))
				continue;
			
			transfer->socket = wi_retain(socket);
			
			/* spawn a transfer thread */
			if(!wi_thread_create_thread(wd_transfer_thread, transfer))
				wi_log_err(WI_STR("Could not create a thread for %@: %m"), ip);
		}
	}
	
	wi_release(pool);
}



#pragma mark -

void wd_reply(uint32_t n, wi_string_t *fmt, ...) {
	wd_user_t		*user = wd_users_user_for_thread();
	wi_string_t		*string;
	va_list			ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wd_user_lock_socket(user);
	wi_socket_write(wd_user_socket(user), 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
	wd_user_unlock_socket(user);
	
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



void wd_sreply(wi_socket_t *socket, uint32_t n, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wi_socket_write(socket, 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
	
	wi_release(string);	
}



void wd_broadcast(wd_chat_t *chat, uint32_t n, wi_string_t *fmt, ...) {
	wi_enumerator_t	*enumerator;
	wi_string_t		*string;
	wi_array_t		*users;
	wd_user_t		*user;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	users = wd_chat_users(chat);
	
	wi_array_rdlock(users);

	enumerator = wi_array_data_enumerator(users);
	
	while((user = wi_enumerator_next_data(enumerator))) {
		if(wd_user_state(user) == WD_USER_LOGGED_IN) {
			wd_user_lock_socket(user);
			wi_socket_write(wd_user_socket(user), 0.0, WI_STR("%u %@%c"), n, string, WD_MESSAGE_SEPARATOR);
			wd_user_unlock_socket(user);
		}
	}
	
	wi_array_unlock(users);

	wi_release(string);
}
