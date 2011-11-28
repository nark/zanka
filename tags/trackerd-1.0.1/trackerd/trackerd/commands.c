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

#include <string.h>
#include <wired/wired.h>

#include "banlist.h"
#include "clients.h"
#include "commands.h"
#include "main.h"
#include "servers.h"
#include "settings.h"
#include "tracker.h"
#include "version.h"

struct _wt_commands {
	const char					*name;

	/* minimum state required */
	wt_client_state_t			state;

	/* minimum number of arguments required */
	wi_uinteger_t				args;

	void						(*action)(wi_array_t *);
};
typedef struct _wt_commands		wt_commands_t;


static void						wt_parse_command(wi_string_t *);
static wi_uinteger_t			wt_command_index(wi_string_t *);

static void						wt_cmd_categories(wi_array_t *);
static void						wt_cmd_client(wi_array_t *);
static void						wt_cmd_hello(wi_array_t *);
static void						wt_cmd_register(wi_array_t *);
static void						wt_cmd_servers(wi_array_t *);


static wt_commands_t			wt_commands[] = {
	{ "CATEGORIES",
	  WT_CLIENT_STATE_SAID_HELLO,		0,		wt_cmd_categories },
	{ "CLIENT",
	  WT_CLIENT_STATE_SAID_HELLO,		1,		wt_cmd_client },
	{ "HELLO",
	  WT_CLIENT_STATE_CONNECTED,		0,		wt_cmd_hello },
	{ "REGISTER",
	  WT_CLIENT_STATE_SAID_HELLO,		5,		wt_cmd_register },
	{ "SERVERS",
	  WT_CLIENT_STATE_SAID_HELLO,		0,		wt_cmd_servers },
};


void wt_control_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wt_client_t			*client = argument;
	wi_string_t			*string;
	wi_socket_state_t	state;
	wi_uinteger_t		i = 0;
	
	pool = wi_pool_init(wi_pool_alloc());

	wt_client_set(client);

	while(client->state <= WT_CLIENT_STATE_SAID_HELLO) {
		do {
			state = wi_socket_wait(client->socket, 0.1);
		} while(state == WI_SOCKET_TIMEOUT && client->state <= WT_CLIENT_STATE_SAID_HELLO);

		if(client->state > WT_CLIENT_STATE_SAID_HELLO) {
			/* invalid state */
			break;
		}

		if(state == WI_SOCKET_ERROR) {
			if(wi_error_code() == EINTR) {
				/* got a signal */
				continue;
			} else {
				/* error in TCP communication */
				wi_log_err(WI_STR("Could not read from %@: %m"), client->ip);

				break;
			}
		}

		string = wi_socket_read_to_string(client->socket, 0.0, WI_STR(WT_MESSAGE_SEPARATOR_STR));

		if(!string || wi_string_length(string) == 0) {
			if(!string)
				wi_log_info(WI_STR("Could not read from %@: %m"), client->ip);
			
			break;
		}

		wt_parse_command(string);
		
		if(++i % 10 == 0)
			wi_pool_drain(pool);
	}

	wi_log_info(WI_STR("Disconnect from %@ after %.2fs"),
		client->ip,
		wi_time_interval() - client->connect_time);
	
	wi_release(pool);
}



#pragma mark -

static void wt_parse_command(wi_string_t *buffer) {
	wt_client_t		*client = wt_client();
	wi_string_t		*command;
	wi_array_t		*arguments;
	wi_uinteger_t	index;
	
	wi_parse_wired_command(buffer, &command, &arguments);
	
	index = wt_command_index(command);

	if(index == WI_NOT_FOUND) {
		wt_reply(501, WI_STR("Command Not Recognized"));

		return;
	}

	if(client->state < wt_commands[index].state)
		return;
	
	if(wi_array_count(arguments) < wt_commands[index].args) {
		wt_reply(503, WI_STR("Syntax Error"));

		return;
	}

	((*wt_commands[index].action) (arguments));
}



static wi_uinteger_t wt_command_index(wi_string_t *command) {
	const char		*cstring;
	wi_uinteger_t	i, min, max;
	int				cmp;

	cstring = wi_string_cstring(command);
	min = 0;
	max = WI_ARRAY_SIZE(wt_commands) - 1;

	do {
		i = (min + max) / 2;
		cmp = strcasecmp(cstring, wt_commands[i].name);

		if(cmp == 0)
			return i;
		else if(cmp < 0 && i > 0)
			max = i - 1;
		else if(cmp > 0)
			min = i + 1;
		else
			break;
	} while(min <= max);

	return WI_NOT_FOUND;
}



#pragma mark -

/*
	CATEGORIES
*/

static void wt_cmd_categories(wi_array_t *arguments) {
	wi_file_t		*file;
	wi_string_t		*string;

	file = wi_file_for_reading(wt_settings.categories);
	
	if(!file) {
		wt_reply(500, WI_STR("Command Failed"));
		wi_log_err(WI_STR("Could not open %@: %m"), wt_settings.categories);

		return;
	}

	while((string = wi_file_read_config_line(file)))
		wt_reply(710, WI_STR("%@"), string);

	wt_reply(711, WI_STR("Done"));
}



/*
	CLIENT <application-version>
*/

static void wt_cmd_client(wi_array_t *arguments) {
	wt_client_t		*client = wt_client();

	client->version = wi_retain(WI_ARRAY(arguments, 0));
}



/*
	HELLO
*/

void wt_cmd_hello(wi_array_t *arguments) {
	wt_client_t		*client = wt_client();

	if(client->state != WT_CLIENT_STATE_CONNECTED)
		return;

	if(wt_ip_is_banned(client->ip)) {
		wt_reply(511, WI_STR("Banned"));
		wi_log_err(WI_STR("Connection from %@ denied, host is banned"),
			client->ip);

		client->state = WT_CLIENT_STATE_DISCONNECTED;

		return;
	}

	wt_reply(200, WI_STR("%#@%c%#@%c%#@%c%#@%c%#@"),
			 wt_server_version_string,		WT_FIELD_SEPARATOR,
			 wt_protocol_version_string,	WT_FIELD_SEPARATOR,
			 wt_settings.name,				WT_FIELD_SEPARATOR,
			 wt_settings.description,		WT_FIELD_SEPARATOR,
			 wi_date_iso8601_string(wt_start_date));
	
	client->state = WT_CLIENT_STATE_SAID_HELLO;
}



/*
	REGISTER <category> <url> <name> <bandwidth> <description>
*/

static void wt_cmd_register(wi_array_t *arguments) {
	wt_client_t					*client = wt_client();
	wi_enumerator_t				*enumerator;
	wi_array_t					*array;
	wi_address_t				*address, *hostaddress;
	wi_url_t					*url;
	wi_string_t					*hostname;
	wt_server_t					*server;
	wi_boolean_t				failed = false, passed;
	uint32_t					bandwidth;

	url			= wi_autorelease(wi_url_init_with_string(wi_url_alloc(), WI_ARRAY(arguments, 1)));
	hostname	= wi_url_host(url);
	address		= wi_socket_address(client->socket);
	
	if(!wi_url_is_valid(url)) {
		/* invalid URL */
		if(wt_settings.strictlookup) {
			wt_reply(503, WI_STR("Syntax Error"));
			wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ aborted: %s"),
				client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1),
				"Invalid URL");
			
			return;
		}
		
		failed = true;
		goto failed;
	}

	if(wi_ip_version(hostname) > 0) {
		/* hostname is numeric, compare with source address */
		if(!wi_is_equal(hostname, client->ip)) {
			/* IP mismatch */
			if(wt_settings.strictlookup) {
				wt_reply(530, WI_STR("Address Mismatch"));
				wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ denied: %s"),
					client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1),
					"IP mismatch");

				return;
			}

			failed = true;
			goto failed;
		}
	} else {
		/* hostname is symbolic */
		if(wt_settings.lookup) {
			/* look up and compare with source address */
			passed = false;
			array = wi_host_addresses(wi_host_with_string(hostname));
			
			if(array) {
				enumerator = wi_array_data_enumerator(array);
				
				while((hostaddress = wi_enumerator_next_data(enumerator))) {
					if(wi_is_equal(hostaddress, address)) {
						passed = true;
						
						break;
					}
				}
			}
			
			if(!passed) {
				/* lookup failed */
				if(wt_settings.strictlookup) {
					wt_reply(531, WI_STR("Address Mismatch"));
					wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ denied: %s"),
						client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1),
						"Lookup failed");
					
					return;
				}
				
				failed = true;
				goto failed;
			}
		}

		if(wt_settings.reverselookup) {
			/* reverse look up and compare to hostname */
			if(!wi_is_equal(wi_address_hostname(address), hostname)) {
				/* reverse lookup failed */
				if(wt_settings.strictlookup) {
					wt_reply(531, WI_STR("Address Mismatch"));
					wi_log_warn(WI_STR("Register from %@ as \"%@\" URL % denied: %@"),
						client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1),
						"Reverse lookup failed");

					return;
				}

				failed = true;
				goto failed;
			}
		}
	}

failed:
	/* get bandwidth */
	bandwidth = wi_string_uint32(WI_ARRAY(arguments, 3));

	/* bandwidth too low? */
	if(wt_settings.minbandwidth > 0 && bandwidth < wt_settings.minbandwidth) {
		wt_reply(516, WI_STR("Permission Denied"));
		wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ denied: Bandwidth %.0f Kbps considered too low"),
			client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1), bandwidth / 128.0);

		return;
	}

	/* bandwidth too high? */
	if(wt_settings.maxbandwidth > 0 && bandwidth > wt_settings.maxbandwidth) {
		wt_reply(516, WI_STR("Permission Denied"));
		wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ denied: Bandwidth %.0f Kbps considered too high"),
			client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1), bandwidth / 128.0);

		return;
	}

	/* is there an existing server from this host? */
	server = wt_servers_server_with_ip(client->ip);

	if(server) {
		if(server->port == wi_url_port(url)) {
			/* remove existing server in preparation for re-registration */
			wt_servers_remove_stats_for_server(server);
			wt_servers_remove_server(server);
		} else {
			/* multiple servers from the same IP allowed? */
			if(!wt_settings.allowmultiple) {
				wt_reply(530, WI_STR("Address Registered"));
				wi_log_warn(WI_STR("Register from %@ as \"%@\" URL %@ denied: %s"),
					client->ip, WI_ARRAY(arguments, 2), WI_ARRAY(arguments, 1),
					"A server from the same address is already registered");
				
				return;
			}
		}
	}
	
	/* rewrite URL if host verification failed */
	if(failed) {
		wi_url_set_scheme(url, WI_STR("wired"));
		wi_url_set_host(url, client->ip);

		if(wi_string_length(WI_ARRAY(arguments, 1)) == 0)
			wi_log_info(WI_STR("Rewriting URL to %@"), wi_url_string(url));
		else
			wi_log_info(WI_STR("Rewriting URL from %@ to %@"), WI_ARRAY(arguments, 1), wi_url_string(url));
	}

	/* create new server */
	server					= wt_server_init(wt_server_alloc());
	server->key				= wi_retain(wi_string_sha1(wi_autorelease(wi_string_init_random_string_with_length(wi_string_alloc(), 1024))));
	server->port			= wi_url_port(url);
	server->bandwidth		= bandwidth;
	server->register_time	= wi_time_interval();
	server->update_time		= 0.0;
	server->ip				= wi_retain(client->ip);
	server->category		= wt_servers_category_is_valid(WI_ARRAY(arguments, 0))
		? wi_retain(WI_ARRAY(arguments, 0))
		: wi_string_init(wi_string_alloc());
	server->name			= wi_retain(WI_ARRAY(arguments, 2));
	server->description		= wi_retain(WI_ARRAY(arguments, 4));
	server->url				= wi_copy(wi_url_string(url));

	wt_servers_add_server(server);
	wt_servers_add_stats_for_server(server);
	
	/* reply 700 */
	wt_reply(700, WI_STR("%@"), server->key);
	wi_log_info(WI_STR("Registered \"%@\" with URL %@"), server->name, server->url);
	wt_servers_write_file();
	wi_release(server);
}



/*
	SERVERS
*/

static void wt_cmd_servers(wi_array_t *arguments) {
	/* reply all servers */
	wt_servers_reply_server_list();

	/* update status */
	wi_lock_lock(wt_status_lock);
	wt_total_clients++;
	wt_write_status(true);
	wi_lock_unlock(wt_status_lock);
}
