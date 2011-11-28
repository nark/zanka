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

#include "banlist.h"
#include "settings.h"

#define WD_TEMPBANS_TIMER_INTERVAL		60.0


struct _wd_tempban {
	wi_runtime_base_t					base;
	
	wi_string_t							*ip;
	wi_time_interval_t					interval;
};
typedef struct _wd_tempban				wd_tempban_t;


static void								wd_update_tempbans(wi_timer_t *);

static wd_tempban_t *					wd_tempban_alloc(void);
static wd_tempban_t *					wd_tempban_init_with_ip(wd_tempban_t *, wi_string_t *);
static void								wd_tempban_dealloc(wi_runtime_instance_t *);
static wi_string_t *					wd_tempban_description(wi_runtime_instance_t *);


static wi_list_t						*wd_tempbans;
static wi_timer_t						*wd_tempbans_timer;

static wi_runtime_id_t					wd_tempban_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				wd_tempban_runtime_class = {
	"wd_tempban_t",
	wd_tempban_dealloc,
	NULL,
	NULL,
	wd_tempban_description,
	NULL
};


void wd_init_tempbans(void) {
	wd_tempban_runtime_id = wi_runtime_register_class(&wd_tempban_runtime_class);

	wd_tempbans = wi_list_init(wi_list_alloc());

	wd_tempbans_timer = wi_timer_init_with_function(wi_timer_alloc(),
													wd_update_tempbans,
													WD_TEMPBANS_TIMER_INTERVAL,
													true);
}



void wd_schedule_tempbans(void) {
	wi_timer_schedule(wd_tempbans_timer);
}



static void wd_update_tempbans(wi_timer_t *timer) {
	wi_list_node_t		*node, *next_node;
	wd_tempban_t		*tempban;
	wi_time_interval_t	interval;
	
	if(wi_list_count(wd_tempbans) > 0) {
		interval = wi_time_interval();

		wi_list_wrlock(wd_tempbans);
		for(node = wi_list_first_node(wd_tempbans); node; node = next_node) {
			next_node	= wi_list_node_next_node(node);
			tempban		= wi_list_node_data(node);

			if(tempban->interval + wd_settings.bantime < interval)
				wi_list_remove_node(wd_tempbans, node);
		}
		wi_list_unlock(wd_tempbans);
	}
}



void wd_dump_tempbans(void) {
	wi_log_debug(WI_STR("Tempbans:"));
	wi_log_debug(WI_STR("%@"), wd_tempbans);
}



#pragma mark -

static wd_tempban_t * wd_tempban_alloc(void) {
	return wi_runtime_create_instance(wd_tempban_runtime_id, sizeof(wd_tempban_t));
}



static wd_tempban_t * wd_tempban_init_with_ip(wd_tempban_t *tempban, wi_string_t *ip) {
	tempban->ip			= wi_retain(ip);
	tempban->interval	= wi_time_interval();
	
	return tempban;
}



static void wd_tempban_dealloc(wi_runtime_instance_t *instance) {
	wd_tempban_t		*tempban = instance;

	wi_release(tempban->ip);
}



static wi_string_t * wd_tempban_description(wi_runtime_instance_t *instance) {
	wd_tempban_t		*tempban = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{ip = %@, time_remaining = %.0f}"),
		wi_runtime_class_name(tempban),
		tempban,
		tempban->ip,
		wi_time_interval() - tempban->interval);
}



#pragma mark -

wi_boolean_t wd_ip_is_banned(wi_string_t *ip) {
	wi_file_t			*file;
	wi_string_t			*string;
	wi_list_node_t		*node;
	wd_tempban_t		*tempban;
	wi_boolean_t		banned = false;

	wi_list_rdlock(wd_tempbans);
	WI_LIST_FOREACH(wd_tempbans, node, tempban) {
		if(wi_is_equal(ip, tempban->ip)) {
			banned = true;

			break;
		}
	}
	wi_list_unlock(wd_tempbans);
	
	if(banned)
		return banned;

	if(wd_settings.banlist) {
		file = wi_file_for_reading(wd_settings.banlist);
		
		if(!file) {
			wi_log_err(WI_STR("Could not open %@: %m"), wd_settings.banlist);
		} else {
			while((string = wi_file_read_config_line(file))) {
				if(wi_ip_match(ip, string)) {
					banned = true;
					
					break;
				}
			}
		}
	}
	
	return banned;
}



void wd_tempban(wi_string_t *ip) {
	wd_tempban_t	*tempban;
	
	tempban = wd_tempban_init_with_ip(wd_tempban_alloc(), ip);
	wi_list_wrlock(wd_tempbans);
	wi_list_append_data(wd_tempbans, tempban);
	wi_list_unlock(wd_tempbans);
	wi_release(tempban);
}
