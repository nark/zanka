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

#ifndef WT_SETTINGS_H
#define WT_SETTINGS_H 1

#include <grp.h>
#include <pwd.h>
#include <wired/wired.h>

#define WT_CONFIG_PATH				"etc/trackerd.conf"


struct _wt_settings {
	wi_string_t						*name;
	wi_string_t						*description;
	wi_array_t						*address;
	wi_uinteger_t					port;

	uid_t							user;
	gid_t							group;

	wi_string_t						*cipher;

	wi_time_interval_t				minupdatetime;
	wi_time_interval_t				maxupdatetime;
	wi_uinteger_t					minbandwidth;
	wi_uinteger_t					maxbandwidth;
	wi_boolean_t					lookup;
	wi_boolean_t					reverselookup;
	wi_boolean_t					strictlookup;
	wi_boolean_t					allowmultiple;

	wi_string_t						*categories;
	wi_string_t						*servers;
	wi_string_t						*pid;
	wi_string_t						*status;
	wi_string_t						*banlist;
	wi_string_t						*certificate;
};
typedef struct _wt_settings			wt_settings_t;


void								wt_settings_init(void);
wi_boolean_t						wt_settings_read_config(void);
void								wt_settings_apply_settings(void);


extern wt_settings_t				wt_settings;
extern wi_boolean_t					wt_settings_chroot;

#endif /* WT_SETTINGS_H */
