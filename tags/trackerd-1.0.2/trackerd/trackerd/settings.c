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

#include "main.h"
#include "servers.h"
#include "settings.h"
#include "tracker.h"

wt_settings_t					wt_settings;

static wi_settings_t			*wt_wi_settings;

static wi_settings_spec_t		wt_wi_settings_spec[] = {
	{ "address",			WI_SETTINGS_STRING_ARRAY,	&wt_settings.address },
	{ "allow multiple",		WI_SETTINGS_BOOL,			&wt_settings.allowmultiple },
	{ "banlist",			WI_SETTINGS_PATH,			&wt_settings.banlist },
	{ "categories",			WI_SETTINGS_PATH,			&wt_settings.categories },
	{ "certificate",		WI_SETTINGS_PATH,			&wt_settings.certificate },
	{ "cipher",				WI_SETTINGS_STRING,			&wt_settings.cipher },
	{ "description",		WI_SETTINGS_STRING,			&wt_settings.description },
	{ "group",				WI_SETTINGS_GROUP,			&wt_settings.group },
	{ "lookup",				WI_SETTINGS_BOOL,			&wt_settings.lookup },
	{ "max bandwidth",		WI_SETTINGS_NUMBER,			&wt_settings.maxbandwidth },
	{ "max update time",	WI_SETTINGS_TIME_INTERVAL,	&wt_settings.maxupdatetime },
	{ "min bandwidth",		WI_SETTINGS_NUMBER,			&wt_settings.minbandwidth },
	{ "min update time",	WI_SETTINGS_TIME_INTERVAL,	&wt_settings.minupdatetime },
	{ "name",				WI_SETTINGS_STRING,			&wt_settings.name },
	{ "pid",				WI_SETTINGS_PATH,			&wt_settings.pid },
	{ "port",				WI_SETTINGS_PORT,			&wt_settings.port },
	{ "reverse lookup",		WI_SETTINGS_BOOL,			&wt_settings.reverselookup },
	{ "servers",			WI_SETTINGS_PATH,			&wt_settings.servers },
	{ "status",				WI_SETTINGS_PATH,			&wt_settings.status },
	{ "strict lookup",		WI_SETTINGS_BOOL,			&wt_settings.strictlookup },
	{ "user",				WI_SETTINGS_USER,			&wt_settings.user },
};


void wt_settings_init(void) {
	wt_wi_settings = wi_settings_init_with_spec(wi_settings_alloc(),
												wt_wi_settings_spec,
												WI_ARRAY_SIZE(wt_wi_settings_spec));
}



wi_boolean_t wt_settings_read_config(void) {
	return wi_settings_read_file(wt_wi_settings);
}



void wt_settings_apply_settings(void) {
	wt_tracker_apply_settings();
	wt_servers_apply_settings();
}
