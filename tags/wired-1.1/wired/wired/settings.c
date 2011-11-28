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
#include <regex.h>

#include "main.h"
#include "settings.h"
#include "utility.h"


struct wd_settings		wd_settings, wd_frozen_settings;

int						wd_config_line;

struct wd_options		wd_options[] = {
	{ "address",				&wd_settings.address,				wd_config_string },
	{ "ban time",				&wd_settings.bantime,				wd_config_number },
	{ "bandwidth",				&wd_settings.bandwidth,				wd_config_number },
	{ "banlist",				&wd_settings.banlist,				wd_config_path },
	{ "category",				&wd_settings.category,				wd_config_string },
	{ "certificate",			&wd_settings.certificate,			wd_config_path },
	{ "client downloads",		&wd_settings.clientdownloads,		wd_config_number },
	{ "client uploads",			&wd_settings.clientuploads,			wd_config_number },
	{ "control cipher",			&wd_settings.controlcipher,			wd_config_string },
	{ "description",			&wd_settings.description,			wd_config_string },
	{ "files",					&wd_settings.files,					wd_config_path },
	{ "group",					&wd_settings.group,					wd_config_group },
	{ "groups",					&wd_settings.groups,				wd_config_path },
	{ "hotline",				&wd_settings.hotline,				wd_config_boolean },
	{ "hotline port",			&wd_settings.hotlineport,			wd_config_number },
	{ "idle time",				&wd_settings.idletime,				wd_config_number },
	{ "ignore dot",				&wd_settings.ignoredot,				wd_config_boolean },
	{ "ignore expression",		&wd_settings.ignoreexpression,		wd_config_regex },
	{ "ignore invisible",		&wd_settings.ignoreinvisible,		wd_config_boolean },
	{ "name",					&wd_settings.name,					wd_config_string },
	{ "news",					&wd_settings.news,					wd_config_path },
	{ "pid",					&wd_settings.pid,					wd_config_path },
	{ "port",					&wd_settings.port,					wd_config_number },
	{ "register",				&wd_settings._register,				wd_config_boolean },
	{ "status",					&wd_settings.status,				wd_config_path },
	{ "total download speed",	&wd_settings.totaldownloadspeed,	wd_config_number },
	{ "total downloads",		&wd_settings.totaldownloads,		wd_config_number },
	{ "total upload speed",		&wd_settings.totaluploadspeed,		wd_config_number },
	{ "total uploads",			&wd_settings.totaluploads,			wd_config_number },
	{ "tracker",				&wd_settings.tracker,				wd_config_string },
	{ "transfer cipher",		&wd_settings.transfercipher,		wd_config_string },
	{ "url",					&wd_settings.url,					wd_config_string },
	{ "user",					&wd_settings.user,					wd_config_user },
	{ "users",					&wd_settings.users,					wd_config_path },
	{ "zeroconf",				&wd_settings.zeroconf,				wd_config_boolean },
};



int wd_read_config(bool first) {
	struct wd_settings	settings;
	FILE				*fp;
	char				path[MAXPATHLEN], buffer[BUFSIZ];
	char				*p, *name = NULL, *value = NULL;
	
	/* open the config file */
	wd_expand_path(path, wd_config, sizeof(path));
	fp = fopen(path, "r");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s", path, strerror(errno));
 
		return -1;
	}
	
	/* found a config file, save previous and reset */
	settings = wd_settings;
	wd_reset_config();
	wd_config_line = 1;
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak if any */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* parse the line */
		if(wd_parse_config(buffer, &name, &value) > 0) {
			/* bump line number */
			wd_config_line++;

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
	
	/* check what changed */
	if(!first) {
		if(!wd_chroot && strcmp(settings.files, wd_settings.files) != 0) {
			/* change root for new files directory */
			if(chdir(wd_settings.files) < 0) {
				wd_log(LOG_WARNING, "Could not change directory to %s: %s", 
					wd_settings.files, strerror(errno));
				
				goto error;
			}
		}
	}
	
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
	/* free regular expressions */
	regfree(&wd_settings.ignoreexpression);

	/* zero out struct */
	memset(&wd_settings, 0, sizeof(struct wd_settings));
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
		wd_log(LOG_WARNING, "Could not interpret the option \"%s\" at %s line %d",
			name, wd_config, wd_config_line);

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
		wd_log(LOG_WARNING, "Could not locate the user \"%s\" at %s line %d",
			value, wd_config, wd_config_line);
		
		return -1;
	}
	
	return 1;
}



int wd_config_group(char *name, char *value, void *affects) {
	struct group	**group = (struct group **) affects;
	
	*group = getgrnam(value);
	
	if(!group) {
		wd_log(LOG_WARNING, "Could not locate the group \"%s\" at %s line %d",
			value, wd_config, wd_config_line);
		
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
		wd_log(LOG_WARNING, "Could not intepret \"%s\" as a boolean value at %s line %d",
			value, wd_config, wd_config_line);
		
		return -1;
	}

	*(bool *) affects = boolean;

	return 1;
}



int wd_config_regex(char *name, char *value, void *affects) {
	regex_t		regex;
	char		*p, *ovalue = NULL, error[WD_STRING_SIZE];
	int			options, result;
	
	ovalue = strdup(value);
	options = REG_EXTENDED;
	
	/* skip leading / */
	if(value[0] == '/') {
		value++;
	} else {
		wd_log(LOG_WARNING, "Could not compile regular expression \"%s\": missing \"/\" at %s line %d",
			ovalue, wd_config, wd_config_line);
		
		goto error;
	}
	
	/* skip last / and extract options */
	if((p = strrchr(value, '/')) != NULL) {
		*p = '\0';
		
		while(*(++p) != '\0') {
			switch(*p) {
				case 'i':
					options |= REG_ICASE;
					break;
				
				case 'm':
					options |= REG_NEWLINE;
					break;
				
				default:
					wd_log(LOG_WARNING, "Could not compile regular expression \"%s\": invalid option \"%c\" at %s line %d",
						ovalue, *p, wd_config, wd_config_line);
					
					goto error;
					break;
			}
		}
	} else {
		wd_log(LOG_WARNING, "Could not compile regular expression \"%s\": missing \"/\" at %s line %d",
			ovalue, wd_config, wd_config_line);
		
		return -1;
	}

	/* compile expression */
	if((result = regcomp(&regex, value, options)) != 0) {
		regerror(result, &regex, error, sizeof(error));
		
		wd_log(LOG_WARNING, "Could not compile regular expression \"%s\": %s at %s line %d",
			ovalue, error, wd_config, wd_config_line);
		
		goto error;
	}

	*(regex_t *) affects = regex;
	
	return 1;

error:
	if(ovalue)
		free(ovalue);
	
	return -1;
}
