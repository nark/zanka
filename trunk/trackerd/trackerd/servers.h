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

#ifndef WT_SERVERS_H
#define WT_SERVERS_H 1

#include <wired/wired.h>

struct _wt_server {
	wi_runtime_base_t				base;

	wi_string_t						*key;
	wi_time_interval_t				update_time;
	wi_time_interval_t				register_time;

	wi_string_t						*ip;
	wi_uinteger_t					port;

	wi_string_t						*category;
	wi_string_t						*url;
	wi_string_t						*name;
	wi_uinteger_t					users;
	wi_uinteger_t					bandwidth;
	wi_boolean_t					guest;
	wi_boolean_t					download;
	wi_uinteger_t					files;
	wi_file_offset_t				size;
	wi_string_t						*description;
};
typedef struct _wt_server			wt_server_t;


void								wt_servers_init(void);
void								wt_servers_apply_settings(void);
void								wt_servers_schedule(void);
void								wt_servers_read_file(void);
void								wt_servers_write_file(void);

void								wt_servers_add_server(wt_server_t *);
void								wt_servers_remove_server(wt_server_t *);
wt_server_t *						wt_servers_server_with_ip(wi_string_t *);
wt_server_t *						wt_servers_server_with_key(wi_string_t *);
void								wt_servers_add_stats_for_server(wt_server_t *);
void								wt_servers_remove_stats_for_server(wt_server_t *);

void								wt_servers_reply_server_list(void);
wi_boolean_t						wt_servers_category_is_valid(wi_string_t *);

wt_server_t *						wt_server_alloc(void);
wt_server_t *						wt_server_init(wt_server_t *);

#endif /* WT_SERVERS_H */
