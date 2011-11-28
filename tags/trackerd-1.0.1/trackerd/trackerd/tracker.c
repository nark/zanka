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

#include <stdarg.h>
#include <string.h>
#include <wired/wired.h>

#include "clients.h"
#include "commands.h"
#include "main.h"
#include "tracker.h"
#include "servers.h"
#include "settings.h"

static void							wt_listen_thread(wi_runtime_instance_t *);
static void							wt_receive_thread(wi_runtime_instance_t *);


static wi_array_t					*wt_tcp_sockets;
static wi_array_t					*wt_udp_sockets;

static wi_socket_context_t			*wt_socket_context;


void wt_tracker_init(void) {
	wi_enumerator_t			*enumerator;
	wi_array_t				*array, *addresses;
	wi_address_t			*address;
	wi_socket_t				*tcp_socket, *udp_socket;
	wi_string_t				*ip, *string;
	wi_address_family_t		family;

	wt_tcp_sockets	= wi_array_init(wi_array_alloc());
	wt_udp_sockets	= wi_array_init(wi_array_alloc());
	addresses		= wi_array_init(wi_array_alloc());

	if(wi_array_count(wt_settings.address) > 0) {
		/* listen on configured addresses */
		wi_array_rdlock(wt_settings.address);
		
		enumerator = wi_array_data_enumerator(wt_settings.address);
		
		while((string = wi_enumerator_next_data(enumerator))) {
			array = wi_host_addresses(wi_host_with_string(string));

			if(array)
				wi_array_add_data_from_array(addresses, array);
			else
				wi_log_err(WI_STR("Could not resolve \"%@\": %m"), string);
		}
		
		wi_array_unlock(wt_settings.address);
	} else {
		/* add wildcard addresses */
		wi_array_add_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV4));
		wi_array_add_data(addresses, wi_address_wildcard_for_family(WI_ADDRESS_IPV6));
	}
	
	enumerator = wi_array_data_enumerator(addresses);
	
	while((address = wi_enumerator_next_data(enumerator))) {
		ip			= wi_address_string(address);
		family		= wi_address_family(address);
		
		/* force address family? */
		if(wt_address_family != WI_ADDRESS_NULL && family != wt_address_family)
			continue;
		
		/* create sockets */
		wi_address_set_port(address, wt_settings.port);

		tcp_socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP));
		udp_socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_UDP));
		
		if(!tcp_socket || !udp_socket) {
			wi_log_warn(WI_STR("Could not create socket for %@: %m"), ip);
			
			continue;
		}
		
		wi_socket_set_interactive(tcp_socket, true);
		
		/* listen on sockets */
		if(!wi_socket_listen(tcp_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(tcp_socket)));

			continue;
		}
		
		if(!wi_socket_listen(udp_socket, 5)) {
			wi_log_warn(WI_STR("Could not listen on %@ port %u: %m"),
				ip, wi_address_port(wi_socket_address(udp_socket)));

			continue;
		}
		
		/* add to list of sockets */
		wi_array_add_data(wt_tcp_sockets, tcp_socket);
		wi_array_add_data(wt_udp_sockets, udp_socket);
		
		wi_log_info(WI_STR("Listening on %@ port %d"),
			ip, wt_settings.port);
	}

	if(wi_array_count(wt_tcp_sockets) == 0 || wi_array_count(wt_udp_sockets) == 0)
		wi_log_err(WI_STR("No addresses available for listening"));
	
	wi_release(addresses);
}



void wt_tracker_create_threads(void) {
	/* spawn the tracker threads */
	if(!wi_thread_create_thread(wt_listen_thread, NULL) ||
	   !wi_thread_create_thread(wt_receive_thread, NULL))
		wi_log_err(WI_STR("Could not create a thread: %m"));
}



void wt_tracker_apply_settings(void) {
	/* set SSL cipher list */
	if(wt_settings.cipher) {
		if(!wi_socket_context_set_ssl_ciphers(wt_socket_context, wt_settings.cipher)) {
			wi_log_err(WI_STR("Could not set SSL cipher list \"%@\""),
				wt_settings.cipher);
		}
	}

	/* load SSL certificate */
	if(wt_settings.certificate) {
		if(!wi_socket_context_set_ssl_certificate(wt_socket_context, wt_settings.certificate)) {
			wi_log_err(WI_STR("Could not load certificate %@: %m"),
				wt_settings.certificate);
		}

		if(!wi_socket_context_set_ssl_privkey(wt_socket_context, wt_settings.certificate)) {
			wi_log_err(WI_STR("Could not load private key %@: %m"),
				wt_settings.certificate);
		}
	}
}



#pragma mark -

void wt_ssl_init(void) {
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

	wt_socket_context = wi_socket_context_init(wi_socket_context_alloc());
	
	if(!wi_socket_context_set_ssl_type(wt_socket_context, WI_SOCKET_SSL_SERVER))
		wi_log_err(WI_STR("Could not set SSL context: %m"));
	
	if(!wi_socket_context_set_ssl_dh(wt_socket_context, dh1024_p, sizeof(dh1024_p), dh1024_g, sizeof(dh1024_g)))
		wi_log_err(WI_STR("Could not set anonymous DH key: %m"));
}



#pragma mark -

static void wt_listen_thread(wi_runtime_instance_t *arg) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_address_t		*address;
	wi_string_t			*ip;
	wt_client_t			*client;
	wi_uinteger_t		i = 0;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wt_running) {
		ip = NULL;

		/* accept new client */
		socket = wi_socket_accept_multiple(wt_tcp_sockets, wt_socket_context, 30.0, &address);
		
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
		client = wi_autorelease(wt_client_init_with_socket(wt_client_alloc(), socket));

		if(!wi_thread_create_thread(wt_control_thread, client))
			wi_log_err(WI_STR("Could not create a thread for %@: %m"), ip);

next:
		if(++i % 100 == 0)
			wi_pool_drain(pool);
	}
	
	wi_release(pool);
}



static void wt_receive_thread(wi_runtime_instance_t *arg) {
	wi_pool_t			*pool;
	wi_array_t			*arguments;
	wi_address_t		*address;
	wi_string_t			*ip, *command;
	wi_time_interval_t	interval;
	wt_server_t			*server;
	char				buffer[WI_SOCKET_BUFFER_SIZE];
	wi_uinteger_t		i = 0;
	wi_integer_t		bytes;

	pool = wi_pool_init(wi_pool_alloc());

	while(wt_running) {
		command		= NULL;
		arguments	= NULL;
		ip			= NULL;
		
		/* read data */
		bytes = wi_socket_recvfrom_multiple(wt_udp_sockets, wt_socket_context, buffer, sizeof(buffer), &address);
		
		if(!address) {
			wi_log_err(WI_STR("Could not receive data: %m"));

			goto next;
		}
		
		ip = wi_address_string(address);

		if(bytes < 0) {
			wi_log_err(WI_STR("Could not receive data from %@: %m"), ip);

			goto next;
		}
		
		/* parse command */
		wi_parse_wired_command(wi_string_with_cstring(buffer), &command, &arguments);

		if(wi_is_equal(command, WI_STR("UPDATE")) && wi_array_count(arguments) >= 6) {
			server = wt_servers_server_with_key(WI_ARRAY(arguments, 0));

			if(!server)
				goto next;

			if(!wi_is_equal(server->ip, ip))
				goto next;

			/* check update time */
			interval = wi_time_interval();
		
			if(server->update_time > 0.0 && wt_settings.maxupdatetime > 0.0) {
				if(interval - server->update_time < wt_settings.maxupdatetime) {
					wi_log_warn(WI_STR("Deleting \"%@\" with URL %@: Last update %.0f seconds ago considered too quick"),
						server->name, server->url, interval - server->update_time);

					wt_servers_remove_stats_for_server(server);
					wt_servers_remove_server(server);
					wt_servers_write_file();

					goto next;
				}
			}
			
			/* update server */
			wt_servers_remove_stats_for_server(server);
			server->users		= wi_string_uint32(WI_ARRAY(arguments, 1));
			server->guest		= wi_string_bool(WI_ARRAY(arguments, 2));
			server->download	= wi_string_bool(WI_ARRAY(arguments, 3));
			server->files		= wi_string_uint32(WI_ARRAY(arguments, 4));
			server->size		= wi_string_uint64(WI_ARRAY(arguments, 5));
			server->update_time	= interval;
			wt_servers_add_stats_for_server(server);

			wi_lock_lock(wt_status_lock);
			wt_write_status(false);
			wi_lock_unlock(wt_status_lock);
		}

next:
		if(++i % 100 == 0)
			wi_pool_drain(pool);
	}
	
	wi_release(pool);
}



#pragma mark -

void wt_reply(uint32_t n, wi_string_t *fmt, ...) {
	wt_client_t		*client = wt_client();
	wi_string_t		*string;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	wi_socket_write(client->socket, 0.0, WI_STR("%u %@%c"), n, string, WT_MESSAGE_SEPARATOR);
	
	wi_release(string);
}
