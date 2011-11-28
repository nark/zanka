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

#include "config.h"

#include <sys/param.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <ctype.h>
#include <grp.h>
#include <pwd.h>

#include "main.h"
#include "settings.h"
#include "utility.h"


struct settings			wd_settings;

struct options			wd_options[] = {
	{ "address",				wd_settings.address,				wd_config_string },
	{ "ban time",				&wd_settings.bantime,				wd_config_number },
	{ "banlist",				&wd_settings.banlist,				wd_config_path },
	{ "certificate",			&wd_settings.certificate,			wd_config_path },
	{ "client downloads",		&wd_settings.clientdownloads,		wd_config_number },
	{ "client uploads",			&wd_settings.clientuploads,			wd_config_number },
	{ "control cipher",			&wd_settings.controlcipher,			wd_config_string },
	{ "description",			&wd_settings.description,			wd_config_string },
	{ "files",					&wd_settings.files,					wd_config_path },
	{ "group",					&wd_settings.group,					wd_config_group },
	{ "groups",					&wd_settings.groups,				wd_config_path },
	{ "hotline",				&wd_settings.hotline,				wd_config_boolean },
	{ "hotline port",			&wd_settings.hotline_port,			wd_config_number },
	{ "idle time",				&wd_settings.idletime,				wd_config_number },
	{ "name",					&wd_settings.name,					wd_config_string },
	{ "news",					&wd_settings.news,					wd_config_path },
	{ "pid",					&wd_settings.pid,					wd_config_path },
	{ "port",					&wd_settings.port,					wd_config_number },
	{ "status",					&wd_settings.status,				wd_config_path },
	{ "total download speed",	&wd_settings.totaldownloadspeed,	wd_config_number },
	{ "total downloads",		&wd_settings.totaldownloads,		wd_config_number },
	{ "total upload speed",		&wd_settings.totaluploadspeed,		wd_config_number },
	{ "total uploads",			&wd_settings.totaluploads,			wd_config_number },
	{ "transfer cipher",		&wd_settings.transfercipher,		wd_config_string },
	{ "user",					&wd_settings.user,					wd_config_user },
	{ "users",					&wd_settings.users,					wd_config_path },
	{ "zeroconf",				&wd_settings.zeroconf,				wd_config_boolean },
};

const char				*wd_signals[] = {
	"",			"HUP",		"INT",		"QUIT",		"ILL",		"TRAP",
	"ABRT",		"EMT",		"FPE",		"KILL",		"BUS",		"SEGV",
	"SYS",		"PIPE",		"ALRM",		"TERM",		"URG",		"STOP",
	"TSTP",		"CONT",		"CHLD",		"TTIN",		"TTOU",		"IO",
	"XCPU",		"XFSZ",		"VTALRM",	"PROF",		"WINCH",	"INFO",
	"USR1",		"USR2"
};



int wd_read_config(void) {
	FILE		*fp;
	char		buffer[BUFSIZ];
	char		*p, *name = NULL, *value = NULL;
	
	/* open the config file */
	fp = fopen(wd_config, "r");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s", wd_config, strerror(errno));
 
		return -1;
	}
	
	/* found a config file, reset config */
	wd_reset_config();
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak if any */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';

		/* parse the line */
		if(wd_parse_config(buffer, &name, &value) > 0) {
			/* set value */
			if(wd_setconfig(name, value) < 0)
				goto error;
			
			/* free strings */
			free(name);
			name = NULL;
			
			free(value);
			value = NULL;
		}
	}
	
	fclose(fp);
	
	/* success */
	return 1;

error:
	if(name)
		free(name);
	
	if(value)
		free(value);
	
	return -1;
}



void wd_reset_config(void) {
	/* zero out struct */
	memset(&wd_settings, 0, sizeof(struct settings));
}



int wd_parse_config(char *buffer, char **name, char **value) {
	char	*ap;
	int		i = 0;
	
	/* ignore comments and empty lines */
	if(*buffer == '#' || !*buffer)
		return -1;

	/* divide into name=value pairs */
	while((ap = strsep(&buffer, "=")) != NULL) {
		/* skip leading spaces */
		while(*ap == ' ')
			ap++;
		
		/* remove trailing spaces */
		while(ap[strlen(ap) - 1] == ' ')
			ap[strlen(ap) - 1] = '\0';

		/* get name/value */
		switch(i++) {
			case 0:
				*name = strdup(ap);
				break;

			case 1:
				*value = strdup(ap);
				break;
		}
	}

	/* make sure we got both */
	if(!*name || !*value) {
		if(*name)
			free(*name);
		
		if(*value)
			free(*value);
		
		return -1;
	}
	
	/* success */
	return 1;
}



int wd_config_index(char *name) {
	int		min = 0;
	int		max = ARRAY_SIZE(wd_options) - 1;
	
	do {
		int i	= (min + max) / 2;
		int cmp	= strcasecmp(name, wd_options[i].name);
		
		if(cmp == 0)
			return i;
		else if(cmp < 0)
			max = i - 1;
		else
			min = i + 1;
	} while(min <= max);
	
	return -1;
}



int wd_setconfig(char *name, char *value) {
	int		i;
	
	i = wd_config_index(name);
	
	if(i < 0) {
		wd_log(LOG_ERR, "Invalid config, no such option '%s'", name);

		return -1;
	}
	
	return ((*wd_options[i].action) (name, value, wd_options[i].affects));
}



#pragma mark -

int wd_config_number(char *name, char *value, void *affects) {
	int		number = strtol(value, NULL, 10);

	*(int *) affects = number;

	return 1;
}



int wd_config_string(char *name, char *value, void *affects) {
	strlcpy((char *) affects, value, WD_STRING_SIZE);
	
	return 1;
}



int wd_config_path(char *name, char *value, void *affects) {
	wd_expand_path((char *) affects, value, MAXPATHLEN);
	
	return 1;
}



int wd_config_user(char *name, char *value, void *affects) {
	struct passwd	**user = (struct passwd **) affects;
	
	*user = getpwnam(value);
	
	if(!*user) {
		wd_log(LOG_ERR, "Invalid config, no such user '%s'", value);

		return -1;
	}
	
	return 1;
}



int wd_config_group(char *name, char *value, void *affects) {
	struct group	**group = (struct group **) affects;
	
	*group = getgrnam(value);
	
	if(!group) {
		wd_log(LOG_ERR, "Invalid config, no such group '%s'", value);
		
		return -1;
	}

	return 1;
}



int wd_config_boolean(char *name, char *value, void *affects) {
	bool	boolean;

	if(strcasecmp(value, "yes") == 0 || strtol(value, NULL, 10) == 1) {
		boolean = true;
	}
	else if(strcasecmp(value, "no") == 0 || strtol(value, NULL, 10) == 0) {
		boolean = false;
	} else {
		wd_log(LOG_ERR, "Invalid config, '%s' not a boolean value", value);
		
		return -1;
	}

	*(bool *) affects = boolean;

	return 1;
}



int wd_config_list(char *name, char *value, void *affects) {
	char	**list = (char **) affects;
	char	*ap;
	int		i = 0;

	while((ap = strsep(&value, ", ")) && i < WD_LIST_SIZE) {
		if(strlen(ap) > 0) {
			list[i] = strdup(ap);
			
			i++;
		}
	}
	
	list[i] = NULL;

	return 1;
}
