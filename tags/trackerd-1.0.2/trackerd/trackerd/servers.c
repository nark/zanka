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

#include <stdlib.h>
#include <string.h>
#include <wired/wired.h>

#include "main.h"
#include "servers.h"
#include "settings.h"
#include "tracker.h"

#define WT_SERVER_MAGIC					"WTSV"
#define WT_SERVER_VERSION				1

#define WT_SERVER_KEY_SIZE				41
#define WT_SERVER_IP_SIZE				41
#define WT_SERVER_CATEGORY_SIZE			256
#define WT_SERVER_NAME_SIZE				256
#define WT_SERVER_URL_SIZE				256
#define WT_SERVER_DESCRIPTION_SIZE		256

#define WT_SERVERS_UPDATE_INTERVAL		60.0


struct _wt_server_packed {
	char								key[WT_SERVER_KEY_SIZE];
	wi_time_interval_t					update_time;
	wi_time_interval_t					register_time;

	char								ip[WT_SERVER_IP_SIZE];
	uint32_t							port;

	char								category[WT_SERVER_CATEGORY_SIZE];
	char								url[WT_SERVER_URL_SIZE];
	char								name[WT_SERVER_NAME_SIZE];
	uint32_t							users;
	uint32_t							bandwidth;
	wi_boolean_t						guest;
	wi_boolean_t						download;
	uint32_t							files;
	wi_file_offset_t					size;
	char								description[WT_SERVER_DESCRIPTION_SIZE];
};
typedef struct _wt_server_packed		wt_server_packed_t;


static void								wt_server_dealloc(wi_runtime_instance_t *);

static void								wt_update_servers(wi_timer_t *);

static wt_server_t *					wt_server_init_with_packed(wt_server_t *, wt_server_packed_t);
static wt_server_packed_t				wt_server_packed(wt_server_t *);


static wi_lock_t						*wt_servers_lock;
static wi_timer_t						*wt_servers_timer;

static wi_dictionary_t					*wt_servers;

static wi_boolean_t						wt_servers_have_read_file;

static wi_runtime_id_t					wt_server_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wt_server_runtime_class = {
	"wt_server_t",
	wt_server_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wt_servers_init(void) {
	wt_server_runtime_id = wi_runtime_register_class(&wt_server_runtime_class);

	wt_servers = wi_dictionary_init(wi_dictionary_alloc());
	
	wt_servers_lock = wi_lock_init(wi_lock_alloc());

	wt_servers_timer = wi_timer_init_with_function(wi_timer_alloc(),
												   wt_update_servers,
												   WT_SERVERS_UPDATE_INTERVAL,
												   true);
}



void wt_servers_apply_settings(void) {
	if(wt_settings.servers && !wt_servers_have_read_file) {
		wt_servers_read_file();
		
		wt_servers_have_read_file = true;
	}
}



void wt_servers_schedule(void) {
	wi_timer_schedule(wt_servers_timer);
}



void wt_servers_read_file(void) {
	FILE				*fp;
	wt_server_packed_t	server_packed;
	wt_server_t			*server;
	char				magic[5];
	wi_time_interval_t	interval, update;
	wi_uinteger_t		count = 0;
	wi_boolean_t		loaded = false;
	uint32_t			version;

	wi_lock_lock(wt_servers_lock);
	
	fp = fopen(wi_string_cstring(wt_settings.servers), "r");

	if(!fp) {
		if(errno != ENOENT) {
			wi_log_err(WI_STR("Could not open %@: %s"),
				wt_settings.servers, strerror(errno));
		}

		goto end;
	}

	if(fread(&magic, 4, 1, fp) != 1 || strncmp(magic, WT_SERVER_MAGIC, 4) != 0) {
		wi_log_warn(WI_STR("Could not read %@: %s"), wt_settings.servers, "Not a server file");

		goto end;
	}

	if(fread(&version, 4, 1, fp) != 1 || version != WT_SERVER_VERSION) {
		wi_log_warn(WI_STR("Could not read %@: %s"), wt_settings.servers, "Wrong version");

		goto end;
	}

	wi_log_info(WI_STR("Reading %@"), wt_settings.servers);

	interval = wi_time_interval();

	while((fread(&server_packed, sizeof(wt_server_packed_t), 1, fp)) > 0) {
		update = server_packed.update_time > 0 ? server_packed.update_time : server_packed.register_time;

		if(interval - update < wt_settings.minupdatetime) {
			server = wt_server_init_with_packed(wt_server_alloc(), server_packed);
			wt_servers_add_server(server);
			wt_servers_add_stats_for_server(server);
			wi_release(server);

			loaded = true;
			count++;
		}
	}

	if(loaded) {
		wi_lock_lock(wt_status_lock);
		wt_write_status(true);
		wi_lock_unlock(wt_status_lock);

		wi_log_info(WI_STR("Loaded %u %s from %@"),
			count,
			count == 1
				? "server"
				: "servers",
			wt_settings.servers);
	}

end:
	wi_lock_unlock(wt_servers_lock);
}



void wt_servers_write_file(void) {
	static char				magic[] = WT_SERVER_MAGIC;
	static uint32_t			version = WT_SERVER_VERSION;
	FILE					*fp;
	wi_enumerator_t			*enumerator;
	wt_server_t				*server;
	wt_server_packed_t		server_packed;

	wi_lock_lock(wt_servers_lock);
	fp = fopen(wi_string_cstring(wt_settings.servers), "w");

	if(!fp) {
		wi_log_warn(WI_STR("Could not open %@: %s"),
			wt_settings.servers, strerror(errno));

		goto end;
	}

	fwrite(magic, 4, 1, fp);
	fwrite(&version, 4, 1, fp);

	wi_dictionary_rdlock(wt_servers);
	
	enumerator = wi_dictionary_data_enumerator(wt_servers);
	
	while((server = wi_enumerator_next_data(enumerator))) {
		server_packed = wt_server_packed(server);
		fwrite(&server_packed, sizeof(wt_server_packed_t), 1, fp);
	}

	wi_dictionary_unlock(wt_servers);

	fclose(fp);

end:
	wi_lock_unlock(wt_servers_lock);
}



static void wt_update_servers(wi_timer_t *timer) {
	wi_enumerator_t		*enumerator;
	wt_server_t			*server;
	void				*key;
	wi_time_interval_t	interval, update;
	wi_boolean_t		changed = false;

	wi_dictionary_wrlock(wt_servers);
		
	if(wi_dictionary_count(wt_servers) > 0) {
		interval = wi_time_interval();

		enumerator = wi_array_data_enumerator(wi_dictionary_all_keys(wt_servers));
		
		while((key = wi_enumerator_next_data(enumerator))) {
			server = wi_dictionary_data_for_key(wt_servers, key);
			update = server->update_time > 0.0 ? server->update_time : server->register_time;
			
			if(interval - update > wt_settings.minupdatetime) {
				wi_log_warn(WI_STR("Deleting \"%@\" with URL %@: Last update %.0f seconds ago considered too slow"),
							server->name, server->url, interval - update);

				wt_servers_remove_stats_for_server(server);
				wi_dictionary_remove_data_for_key(wt_servers, key);
				
				changed = true;
			}
		}
	}

	wi_dictionary_unlock(wt_servers);

	if(changed) {
		wi_lock_lock(wt_status_lock);
		wt_write_status(true);
		wi_lock_unlock(wt_status_lock);

		wt_servers_write_file();
	}
}



#pragma mark -

void wt_servers_add_server(wt_server_t *server) {
	wi_dictionary_wrlock(wt_servers);
	wi_dictionary_set_data_for_key(wt_servers, server, server->key);
	wi_dictionary_unlock(wt_servers);
}



void wt_servers_remove_server(wt_server_t *server) {
	wi_dictionary_wrlock(wt_servers);
	wi_dictionary_remove_data_for_key(wt_servers, server->key);
	wi_dictionary_unlock(wt_servers);
}



wt_server_t * wt_servers_server_with_ip(wi_string_t *ip) {
	wi_enumerator_t	*enumerator;
	wt_server_t		*server, *value = NULL;

	wi_dictionary_rdlock(wt_servers);
	
	enumerator = wi_dictionary_data_enumerator(wt_servers);
	
	while((server = wi_enumerator_next_data(enumerator))) {
		if(wi_is_equal(server->ip, ip)) {
			value = wi_autorelease(wi_retain(server));

			break;
		}
	}

	wi_dictionary_unlock(wt_servers);

	return value;
}



wt_server_t * wt_servers_server_with_key(wi_string_t *key) {
	wt_server_t		*server;
	
	wi_dictionary_rdlock(wt_servers);
	server = wi_autorelease(wi_retain(wi_dictionary_data_for_key(wt_servers, key)));
	wi_dictionary_unlock(wt_servers);
	
	return server;
}



void wt_servers_add_stats_for_server(wt_server_t *server) {
	wi_lock_lock(wt_status_lock);
	wt_current_servers++;
	wt_current_users += server->users;
	wt_current_files += server->files;
	wt_current_size += server->size;
	wi_lock_unlock(wt_status_lock);
}



void wt_servers_remove_stats_for_server(wt_server_t *server) {
	wi_lock_lock(wt_status_lock);
	wt_current_servers--;
	wt_current_users -= server->users;
	wt_current_files -= server->files;
	wt_current_size -= server->size;
	wi_lock_unlock(wt_status_lock);
}



#pragma mark -

void wt_servers_reply_server_list(void) {
	wi_enumerator_t		*enumerator;
	wt_server_t			*server;
	
	wi_dictionary_rdlock(wt_servers);
	
	enumerator = wi_dictionary_data_enumerator(wt_servers);
	
	while((server = wi_enumerator_next_data(enumerator))) {
		wt_reply(720, WI_STR("%@%c%@%c%@%c%u%c%u%c%u%c%u%c%u%c%llu%c%@"),
				 server->category,		WT_FIELD_SEPARATOR,
				 server->url,			WT_FIELD_SEPARATOR,
				 server->name,			WT_FIELD_SEPARATOR,
				 server->users,			WT_FIELD_SEPARATOR,
				 server->bandwidth,		WT_FIELD_SEPARATOR,
				 server->guest,			WT_FIELD_SEPARATOR,
				 server->download,		WT_FIELD_SEPARATOR,
				 server->files,			WT_FIELD_SEPARATOR,
				 server->size,			WT_FIELD_SEPARATOR,
				 server->description);
	}
	
	wi_dictionary_unlock(wt_servers);

	wt_reply(721, WI_STR("Done"));
}



wi_boolean_t wt_servers_category_is_valid(wi_string_t *category) {
	wi_file_t		*file;
	wi_string_t		*string;
	wi_boolean_t	result = false;

	if(wi_string_length(category) == 0)
		return true;

	file = wi_file_for_reading(wt_settings.categories);
	
	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %m"), wt_settings.categories);
		
		return true;
	}
	
	while((string = wi_file_read_config_line(file))) {
		if(wi_is_equal(category, string)) {
			result = true;
			
			break;
		}
	}

	return result;
}



#pragma mark -

wt_server_t * wt_server_alloc(void) {
	return wi_runtime_create_instance(wt_server_runtime_id, sizeof(wt_server_t));
}



wt_server_t * wt_server_init(wt_server_t *server) {
	return server;
}



static wt_server_t * wt_server_init_with_packed(wt_server_t *server, wt_server_packed_t server_packed) {
	server->key				= wi_string_init_with_cstring(wi_string_alloc(), server_packed.key);
	server->update_time		= server_packed.update_time;
	server->register_time	= server_packed.register_time;

	server->ip				= wi_string_init_with_cstring(wi_string_alloc(), server_packed.ip);
	server->port			= server_packed.port;

	server->category		= wi_string_init_with_cstring(wi_string_alloc(), server_packed.category);
	server->url				= wi_string_init_with_cstring(wi_string_alloc(), server_packed.url);
	server->name			= wi_string_init_with_cstring(wi_string_alloc(), server_packed.name);
	server->users			= server_packed.users;
	server->bandwidth		= server_packed.bandwidth;
	server->guest			= server_packed.guest;
	server->download		= server_packed.download;
	server->files			= server_packed.files;
	server->size			= server_packed.size;
	server->description		= wi_string_init_with_cstring(wi_string_alloc(), server_packed.description);
	
	return server;
}



static void wt_server_dealloc(wi_runtime_instance_t *instance) {
	wt_server_t		*server = instance;
	
	wi_release(server->key);
	wi_release(server->ip);
	wi_release(server->category);
	wi_release(server->url);
	wi_release(server->name);
	wi_release(server->description);
}



#pragma mark -

static wt_server_packed_t wt_server_packed(wt_server_t *server) {
	wt_server_packed_t	server_packed;

	memset(&server_packed, 0, sizeof(server_packed));

	wi_strlcpy(server_packed.key, wi_string_cstring(server->key), sizeof(server_packed.key));
	server_packed.update_time	= server->update_time;
	server_packed.register_time	= server->register_time;

	wi_strlcpy(server_packed.ip, wi_string_cstring(server->ip), sizeof(server_packed.ip));
	server_packed.port			= server->port;

	wi_strlcpy(server_packed.category, wi_string_cstring(server->category), sizeof(server_packed.category));
	wi_strlcpy(server_packed.url, wi_string_cstring(server->url), sizeof(server_packed.url));
	wi_strlcpy(server_packed.name, wi_string_cstring(server->name), sizeof(server_packed.name));
	server_packed.users			= server->users;
	server_packed.bandwidth		= server->bandwidth;
	server_packed.guest			= server->guest;
	server_packed.download		= server->download;
	server_packed.files			= server->files;
	server_packed.size			= server->size;
	wi_strlcpy(server_packed.description, wi_string_cstring(server->description), sizeof(server_packed.description));

	return server_packed;
}
