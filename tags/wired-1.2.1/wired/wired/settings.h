/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#ifndef WD_SETTINGS_H
#define WD_SETTINGS_H 1

#include <sys/types.h>
#include <stdbool.h>
#include <grp.h>
#include <pwd.h>
#include <time.h>

#include "utility.h"


#define WD_CONFIG_FILE			"etc/wired.conf"

#define WD_STRING_SIZE			256


struct wd_settings {
	char						name[WD_STRING_SIZE];
	char						description[WD_STRING_SIZE];
	char						banner[MAXPATHLEN];
	char						address[WD_STRING_SIZE];
	unsigned int				port;

	struct passwd				*user;
	struct group				*group;

	unsigned int				idletime;
	unsigned int				bantime;
	unsigned int				newslimit;
	
	char						files[MAXPATHLEN];
	char						index[MAXPATHLEN];
	unsigned int				indextime;
	char						searchmethod[WD_STRING_SIZE];
	bool						showdotfiles;
	bool						showinvisiblefiles;
	wd_regexp_t					ignoreexpression;
	
	bool						zeroconf;
	
	bool						_register;
	char						tracker[WD_STRING_SIZE];
	char						category[WD_STRING_SIZE];
	char						url[WD_STRING_SIZE];
	unsigned int				bandwidth;
	
	unsigned int				totaldownloads;
	unsigned int				totaluploads;
	unsigned int				clientdownloads;
	unsigned int				clientuploads;
	unsigned int				totaldownloadspeed;
	unsigned int				totaluploadspeed;
	
	char						controlcipher[WD_STRING_SIZE];
	char						transfercipher[WD_STRING_SIZE];

	char						pid[MAXPATHLEN];
	char						users[MAXPATHLEN];
	char						groups[MAXPATHLEN];
	char						news[MAXPATHLEN];
	char						status[MAXPATHLEN];
	char						banlist[MAXPATHLEN];
	char						certificate[MAXPATHLEN];
};
typedef struct wd_settings		wd_settings_t;


struct wd_options {
	char						*name;
	bool						restartrequired;
	void						*setting;
	void						*previoussetting;
	int							(*setfunc) (char *, char *, void *);
	int							(*comparefunc) (void *, void *);
};
typedef struct wd_options		wd_options_t;


int								wd_read_config(void);
void							wd_apply_config(void);
void							wd_reset_config(void);
int								wd_parse_config(char *, char **, char **);
int								wd_config_index(char *);
int								wd_set_config(char *, char *);

int								wd_set_config_number(char *, char *, void *);
int								wd_set_config_string(char *, char *, void *);
int								wd_set_config_path(char *, char *, void *);
int								wd_set_config_user(char *, char *, void *);
int								wd_set_config_group(char *, char *, void *);
int								wd_set_config_boolean(char *, char *, void *);
int								wd_set_config_regex(char *, char *, void *);

int								wd_compare_config_number(void *, void *);
int								wd_compare_config_string(void *, void *);
int								wd_compare_config_user(void *, void *);
int								wd_compare_config_group(void *, void *);
int								wd_compare_config_boolean(void *, void *);


extern wd_settings_t			wd_settings, wd_frozen_settings, wd_previous_settings;
extern wd_options_t				wd_options[];

#endif /* WD_SETTINGS_H */
