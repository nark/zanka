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

#include <wired/wired.h>

#include "accounts.h"
#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "trackers.h"
#include "version.h"

#define WD_TRACKERS_REGISTER_INTERVAL	3600.0
#define WD_TRACKERS_UPDATE_INTERVAL		60.0


struct _wd_tracker {
	wi_runtime_base_t					base;
	
	wi_lock_t							*register_lock;

	wi_boolean_t						active;

	wi_socket_context_t					*context;
	wi_socket_t							*socket;
	wi_address_t						*address;

	wi_list_t							*addresses;

	wi_string_t							*host;
	wi_string_t							*category;
	wi_string_t							*key;
};
typedef struct _wd_tracker				wd_tracker_t;


static wd_tracker_t *					wd_tracker_alloc(void);
static wd_tracker_t *					wd_tracker_init(wd_tracker_t *);
static void								wd_tracker_dealloc(wi_runtime_instance_t *);
static wi_string_t *					wd_tracker_description(wi_runtime_instance_t *);

static void								wd_trackers_register_with_timer(wi_timer_t *);
static void								wd_trackers_update_with_timer(wi_timer_t *);
static void								wd_trackers_register_thread(wi_runtime_instance_t *);
static void								wd_trackers_update(void);

static void								wd_tracker_register(wd_tracker_t *);
static void								wd_tracker_update(wd_tracker_t *);

static wi_boolean_t						wd_tracker_read(wd_tracker_t *, unsigned int *, wi_array_t **);
static wi_boolean_t						wd_tracker_write(wd_tracker_t *, wi_string_t *, ...);


static wi_list_t						*wd_trackers;

static wi_timer_t						*wd_trackers_register_timer;
static wi_timer_t						*wd_trackers_update_timer;

static wd_account_t						*wd_trackers_guest_account;

static wi_runtime_id_t					wd_tracker_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wd_tracker_runtime_class = {
	"wd_tracker_t",
	wd_tracker_dealloc,
	NULL,
	NULL,
	wd_tracker_description,
	NULL
};


void wd_init_trackers(void) {
	wd_tracker_runtime_id = wi_runtime_register_class(&wd_tracker_runtime_class);

	wd_trackers = wi_list_init(wi_list_alloc());

	wd_trackers_register_timer =
		wi_timer_init_with_function(wi_timer_alloc(),
									wd_trackers_register_with_timer,
									WD_TRACKERS_REGISTER_INTERVAL,
									true);
	
	wd_trackers_update_timer =
		wi_timer_init_with_function(wi_timer_alloc(),
									wd_trackers_update_with_timer,
									WD_TRACKERS_UPDATE_INTERVAL,
									true);
}



void wd_config_trackers(void) {
	wi_list_node_t		*string_node, *address_node;
	wi_string_t			*string;
	wi_url_t			*url;
	wi_address_t		*address;
	wd_tracker_t		*tracker;
	unsigned int		port;
	
	wi_list_wrlock(wd_trackers);
	wi_list_remove_all_data(wd_trackers);
	
	WI_LIST_FOREACH(wd_settings.tracker, string_node, string) {
		tracker	= wd_tracker_init(wd_tracker_alloc());
		url		= wi_url_init_with_string(wi_url_alloc(), string);
		
		if(!wi_url_is_valid(url)) {
			wi_log_warn(WI_STR("Could not parse tracker URL \"%@\""),
				string);
			
			goto next;
		}
		
		tracker->context = wi_socket_context_init(wi_socket_context_alloc());
		
		if(!wi_socket_context_set_ssl_type(tracker->context, WI_SOCKET_SSL_CLIENT)) {
			wi_log_warn(WI_STR("Could not set SSL context: %m"));
			
			goto next;
		}

		tracker->host		= wi_retain(wi_url_host(url));
		tracker->category	= wi_retain(wi_string_substring_from_index(wi_url_path(url), 1));
		tracker->addresses	= wi_retain(wi_host_addresses(wi_host_with_string(tracker->host)));

		if(!tracker->addresses) {
			wi_log_warn(WI_STR("Could not resolve \"%@\": %m"), tracker->host);
			
			goto next;
		}
		
		port = wi_url_port(url);

		if(port == 0)
			port = WD_TRACKER_PORT;

		WI_LIST_FOREACH(tracker->addresses, address_node, address)
			wi_address_set_port(address, port);
		
		wi_list_append_data(wd_trackers, tracker);

next:
		wi_release(tracker);
		wi_release(url);
	}
	
	wi_list_unlock(wd_trackers);
}



void wd_schedule_trackers(void) {
	if(wd_settings._register) {
		wi_timer_schedule(wd_trackers_register_timer);
		wi_timer_schedule(wd_trackers_update_timer);
	} else {
		wi_timer_invalidate(wd_trackers_register_timer);
		wi_timer_invalidate(wd_trackers_update_timer);
	}
}



void wd_dump_trackers(void) {
	wi_log_debug(WI_STR("Trackers:"));
	wi_log_debug(WI_STR("%@"), wd_trackers);
}



#pragma mark -

static wd_tracker_t * wd_tracker_alloc(void) {
	return wi_runtime_create_instance(wd_tracker_runtime_id, sizeof(wd_tracker_t));
}



static wd_tracker_t * wd_tracker_init(wd_tracker_t *tracker) {
	tracker->register_lock = wi_lock_init(wi_lock_alloc());

	return tracker;
}



static void wd_tracker_dealloc(wi_runtime_instance_t *instance) {
	wd_tracker_t		*tracker = instance;

	wi_release(tracker->context);

	wi_release(tracker->addresses);
	wi_release(tracker->host);
	wi_release(tracker->category);
	wi_release(tracker->key);

	wi_release(tracker->register_lock);
}



static wi_string_t * wd_tracker_description(wi_runtime_instance_t *instance) {
	wd_tracker_t		*tracker = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{host = %@, category = %@, active = %d}"),
		wi_runtime_class_name(tracker),
		tracker,
		tracker->host,
		tracker->category,
		tracker->active);
}



#pragma mark -

static void wd_trackers_register_with_timer(wi_timer_t *timer) {
	wd_trackers_register(false);
}



void wd_trackers_register(wi_boolean_t update) {
	if(wi_list_count(wd_trackers) > 0) {
		wi_release(wd_trackers_guest_account);
		
		wd_trackers_guest_account = wi_retain(wd_accounts_read_user_and_group(WI_STR("guest")));
		
		wi_log_info(WI_STR("Registering with trackers..."));

		if(!wi_thread_create_thread(wd_trackers_register_thread, wi_number_with_bool(update)))
			wi_log_err(WI_STR("Could not create a thread: %m"));
	}
}



static void wd_trackers_register_thread(wi_runtime_instance_t *argument) {
	wi_pool_t			*pool;
	wi_number_t			*number = argument;
	wi_list_node_t		*node;
	wd_tracker_t		*tracker;
	wi_boolean_t		update;
	
	pool = wi_pool_init(wi_pool_alloc());
	update = wi_number_bool(number);
	
	wi_list_rdlock(wd_trackers);
	WI_LIST_FOREACH(wd_trackers, node, tracker) {
		wd_tracker_register(tracker);
		
		if(update && tracker->active)
			wd_tracker_update(tracker);
	}
	wi_list_unlock(wd_trackers);
	
	if(update)
		wi_timer_reschedule(wd_trackers_update_timer, WD_TRACKERS_UPDATE_INTERVAL);
	
	wi_release(pool);
}



static void wd_trackers_update_with_timer(wi_timer_t *timer) {
	wd_trackers_update();
}



static void wd_trackers_update(void) {
	wi_list_node_t		*node;
	wd_tracker_t		*tracker;
	
	wi_list_rdlock(wd_trackers);
	WI_LIST_FOREACH(wd_trackers, node, tracker) {
		if(tracker->active)
			wd_tracker_update(tracker);
	}
	wi_list_unlock(wd_trackers);
}



#pragma mark -

static void wd_tracker_register(wd_tracker_t *tracker) {
	wi_list_node_t		*node;
	wi_address_t		*address;
	wi_array_t			*arguments;
	wi_string_t			*ip, *string;
	void				*key;
	unsigned int		message;
	wi_boolean_t		fatal = false;
	
	if(!wi_lock_trylock(tracker->register_lock))
		return;
	
	WI_LIST_FOREACH(tracker->addresses, node, address) {
		tracker->active		= false;
		tracker->address	= NULL;
		ip					= wi_address_string(address);
		
		wi_log_info(WI_STR("Trying %@ for tracker %@..."),
			ip, tracker->host);
		
		tracker->socket = wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP);

		if(!wi_socket_connect(tracker->socket, tracker->context, 30.0)) {
			wi_log_err(WI_STR("Could not connect to tracker %@: %m"),
				tracker->host);
			
			goto next;
		}
		
		if(!wd_tracker_write(tracker, WI_STR("HELLO")))
			goto next;
		
		if(!wd_tracker_read(tracker, &message, &arguments))
			goto next;
		
		if(message != 200) {
			string = wi_array_components_joined_by_string(arguments, WI_STR(" "));
			wi_log_err(WI_STR("Could not register with tracker %@: Unexpected reply \"%u %@\""),
				tracker->host, message, string);
			
			fatal = true;
			goto next;
		}
		
		if(!wd_tracker_write(tracker, WI_STR("CLIENT %#@"), wd_server_version_string))
			goto next;
		
		if(!wd_tracker_write(tracker, WI_STR("REGISTER %#@%c%#@%c%#@%c%u%c%#@"),
							 tracker->category,			WD_FIELD_SEPARATOR,
							 wd_settings.url,			WD_FIELD_SEPARATOR,
							 wd_settings.name,			WD_FIELD_SEPARATOR,
							 wd_settings.bandwidth,		WD_FIELD_SEPARATOR,
							 wd_settings.description))
			goto next;
		
		
		if(!wd_tracker_read(tracker, &message, &arguments))
			goto next;
		
		if(message != 700 || wi_array_count(arguments) < 1) {
			string = wi_array_components_joined_by_string(arguments, WI_STR(" "));
			wi_log_err(WI_STR("Could not register with tracker %@: Unexpected reply \"%u %@\""),
				tracker->host, message, string);
			
			fatal = true;
			goto next;
		}
		
		wi_release(tracker->key);
		tracker->key = wi_retain(WI_ARRAY(arguments, 0));
		
		key = wi_socket_ssl_pubkey(tracker->socket);

		if(!key) {
			wi_log_err(WI_STR("Could not get public key from the tracker %@: %m"),
				tracker->host);
			
			fatal = true;
			goto next;
		}
		
		wi_socket_context_set_ssl_pubkey(tracker->context, key);
		
		wi_log_info(WI_STR("Registered with the tracker %@"),
			tracker->host);
		
		tracker->active		= true;
		tracker->address	= address;
		
next:
		wi_release(tracker->socket);
		
		if(tracker->active || fatal)
			break;
	}
	
	wi_lock_unlock(tracker->register_lock);
}



static void wd_tracker_update(wd_tracker_t *tracker) {
	wi_socket_t			*socket;
	wi_string_t			*string = NULL;
	unsigned int		guest, download;
	int					bytes;
	
	guest = (wd_trackers_guest_account != NULL);
	download = (guest && wd_trackers_guest_account->download);
	
	socket = wi_socket_init_with_address(wi_socket_alloc(), tracker->address, WI_SOCKET_UDP);
	
	if(!socket) {
		wi_log_err(WI_STR("Could not create a socket for tracker %@: %m"),
			tracker->host);
		
		goto end;
	}
	
	bytes = wi_socket_sendto(socket, tracker->context, WI_STR("UPDATE %#@%c%u%c%u%c%u%c%u%c%llu%c"),
							 tracker->key,		WD_FIELD_SEPARATOR,
							 wd_current_users,	WD_FIELD_SEPARATOR,
							 guest,				WD_FIELD_SEPARATOR,
							 download,			WD_FIELD_SEPARATOR,
							 wd_files_count,	WD_FIELD_SEPARATOR,
							 wd_files_size,		WD_MESSAGE_SEPARATOR);
	
	if(bytes < 0) {
		wi_log_err(WI_STR("Could not send message to tracker %@: %m"),
			tracker->host);
		
		goto end;
	}

end:
	wi_release(string);
	wi_release(socket);
}



#pragma mark -

static wi_boolean_t wd_tracker_read(wd_tracker_t *tracker, unsigned int *message, wi_array_t **arguments) {
	wi_string_t		*string;

	*message	= 0;
	*arguments	= NULL;
	string		= wi_socket_read_to_string(tracker->socket, 30.0, WI_STR(WD_MESSAGE_SEPARATOR_STR));

	if(string && wi_string_length(string) > 0) {
		wi_parse_wired_message(string, message, arguments);
	} else {
		if(!string) {
			wi_log_err(WI_STR("Could not read from tracker %@: %m"),
				tracker->host);
		} else {
			wi_log_err(WI_STR("Could not read from tracker %@: %s"),
				tracker->host, "Connection closed");
		}
	}

	return (string != NULL);
}



static wi_boolean_t wd_tracker_write(wd_tracker_t *tracker, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	int				bytes;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	bytes = wi_socket_write(tracker->socket, 30.0, WI_STR("%@%c"), string, WD_MESSAGE_SEPARATOR);

	if(bytes <= 0) {
		wi_log_err(WI_STR("Could not write to tracker %@: %m"),
			tracker->host);
	}
	
	wi_release(string);

	return (bytes > 0);
}
