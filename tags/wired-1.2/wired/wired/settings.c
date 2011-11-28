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

#include "files.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


int						wd_config_line;

wd_settings_t			wd_settings, wd_frozen_settings, wd_previous_settings;

wd_options_t			wd_options[] = {
	{ "address",							true,
	  &wd_settings.address,					&wd_previous_settings.address,
	  wd_set_config_string,					wd_compare_config_string },
	{ "ban time",							false,
	  &wd_settings.bantime,					&wd_previous_settings.bantime,
	  wd_set_config_number,					NULL },
	{ "bandwidth",							false,
	  &wd_settings.bandwidth,				&wd_previous_settings.bandwidth,
	  wd_set_config_number,					NULL },
	{ "banlist",							false,
	  &wd_settings.banlist,					&wd_previous_settings.banlist,
	  wd_set_config_path,					NULL },
	{ "banner",								false,
	  &wd_settings.banner,					&wd_previous_settings.banner,
	  wd_set_config_path,					NULL },
	{ "category",							true,
	  &wd_settings.category,				&wd_previous_settings.category,
	  wd_set_config_string,					wd_compare_config_string },
	{ "certificate",						false,
	  &wd_settings.certificate,				&wd_previous_settings.certificate,
	  wd_set_config_path,					NULL },
	{ "client downloads",					false,
	  &wd_settings.clientdownloads,			&wd_previous_settings.clientdownloads,
	  wd_set_config_number,					NULL },
	{ "client uploads",						false,
	  &wd_settings.clientuploads,			&wd_previous_settings.clientuploads,
	  wd_set_config_number,					NULL },
	{ "control cipher",						false,
	  &wd_settings.controlcipher,			&wd_previous_settings.controlcipher,
	  wd_set_config_string,					NULL },
	{ "description",						false,
	  &wd_settings.description,				&wd_previous_settings.description,
	  wd_set_config_string,					NULL },
	{ "files",								false,
	  &wd_settings.files,					&wd_previous_settings.files,
	  wd_set_config_path,					NULL },
	{ "group",								true,
	  &wd_settings.group,					&wd_previous_settings.group,
	  wd_set_config_group,					wd_compare_config_group },
	{ "groups",								false,
	  &wd_settings.groups,					&wd_previous_settings.groups,
	  wd_set_config_path,					NULL },
	{ "idle time",							false,
	  &wd_settings.idletime,				&wd_previous_settings.idletime,
	  wd_set_config_number,					NULL },
	{ "ignore expression",					false,
	  &wd_settings.ignoreexpression,		&wd_previous_settings.ignoreexpression,
	  wd_set_config_regex,					NULL },
	{ "index",								false,
	  &wd_settings.index,					&wd_previous_settings.index,
	  wd_set_config_path,					NULL },
	{ "index time",							false,
	  &wd_settings.indextime,				&wd_previous_settings.indextime,
	  wd_set_config_number,					NULL },
	{ "name",								false,
	  &wd_settings.name,					&wd_previous_settings.name,
	  wd_set_config_string,					NULL },
	{ "news",								false,
	  &wd_settings.news,					&wd_previous_settings.news,
	  wd_set_config_path,					NULL },
	{ "news limit",							false,
	  &wd_settings.newslimit,				&wd_previous_settings.newslimit,
	  wd_set_config_number,					NULL },
	{ "pid",								true,
	  &wd_settings.pid,						&wd_previous_settings.pid,
	  wd_set_config_path,					wd_compare_config_string },
	{ "port",								true,
	  &wd_settings.port,					&wd_previous_settings.port,
	  wd_set_config_number,					wd_compare_config_number },
	{ "register",							true,
	  &wd_settings._register,				&wd_previous_settings._register,
	  wd_set_config_boolean,				wd_compare_config_boolean },
	{ "search method",						false,
	  &wd_settings.searchmethod,			&wd_previous_settings.searchmethod,
	  wd_set_config_string,					NULL },
	{ "show dot files",						false,
	  &wd_settings.showdotfiles,			&wd_previous_settings.showdotfiles,
	  wd_set_config_boolean,				NULL },
	{ "show invisible files",				false,
	  &wd_settings.showinvisiblefiles,		&wd_previous_settings.showinvisiblefiles,
	  wd_set_config_boolean,				NULL },
	{ "status",								true,
	  &wd_settings.status,					&wd_previous_settings.status,
	  wd_set_config_path,					wd_compare_config_string },
	{ "total download speed",				false,
	  &wd_settings.totaldownloadspeed,		&wd_previous_settings.totaldownloadspeed,
	  wd_set_config_number,					NULL },
	{ "total downloads",					false,
	  &wd_settings.totaldownloads,			&wd_previous_settings.totaldownloads,
	  wd_set_config_number,					NULL },
	{ "total upload speed",					false,
	  &wd_settings.totaluploadspeed,		&wd_previous_settings.totaluploadspeed,
	  wd_set_config_number,					NULL },
	{ "total uploads",						false,
	  &wd_settings.totaluploads,			&wd_previous_settings.totaluploads,
	  wd_set_config_number,					NULL },
	{ "tracker",							true,
	  &wd_settings.tracker,					&wd_previous_settings.tracker,
	  wd_set_config_string,					wd_compare_config_string },
	{ "transfer cipher",					false,
	  &wd_settings.transfercipher,			&wd_previous_settings.transfercipher,
	  wd_set_config_string,					NULL },
	{ "url",								true,
	  &wd_settings.url,						&wd_previous_settings.url,
	  wd_set_config_string,					wd_compare_config_string },
	{ "user",								true,
	  &wd_settings.user,					&wd_previous_settings.user,
	  wd_set_config_user,					wd_compare_config_user },
	{ "users",								false,
	  &wd_settings.users,					&wd_previous_settings.users,
	  wd_set_config_path,					NULL },
	{ "zeroconf",							true,
	  &wd_settings.zeroconf,				&wd_previous_settings.zeroconf,
	  wd_set_config_boolean,				wd_compare_config_boolean },
};




int wd_read_config(void) {
	FILE		*fp;
	char		path[MAXPATHLEN], buffer[BUFSIZ];
	char		*p, *name = NULL, *value = NULL;
	
	/* open the config file */
	wd_expand_path(path, wd_config, sizeof(path));
	fp = fopen(path, "r");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			path, strerror(errno));
 
		return -1;
	}
	
	/* found a config file, save previous and reset */
	wd_previous_settings = wd_settings;
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
			if(wd_set_config(name, value) < 0)
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



void wd_apply_config(void) {
	char	start_time[WD_DATETIME_SIZE];

	/* change directory to the files path */
	if(strcmp(wd_settings.files, wd_previous_settings.files) != 0) {
		if(chdir(wd_settings.files) < 0) {
			wd_log(LOG_ERR, "Could not change directory to %s: %s", 
				wd_settings.files, strerror(errno));
		}
	}
	
	/* load banner */
	if(strlen(wd_settings.banner) > 0)
		wd_base64_encode(wd_settings.banner, wd_banner, sizeof(wd_banner));

	/* reload server information */
	if(strcmp(wd_settings.name, wd_previous_settings.name) != 0 ||
	   strcmp(wd_settings.description, wd_previous_settings.description) != 0) {
		/* format time string */
		wd_time_to_iso8601(wd_start_time, start_time, sizeof(start_time));
			
		/* reply a 200 */
		wd_broadcast(WD_PUBLIC_CHAT, 200, "%s%c%s%c%s%c%s%c%s%c%u%c%llu",
			 wd_version_string,
			 WD_FIELD_SEPARATOR,
			 WD_PROTOCOL_VERSION,
			 WD_FIELD_SEPARATOR,
			 wd_settings.name,
			 WD_FIELD_SEPARATOR,
			 wd_settings.description,
			 WD_FIELD_SEPARATOR,
			 start_time,
			 WD_FIELD_SEPARATOR,
			 wd_files_count,
			 WD_FIELD_SEPARATOR,
			 wd_files_size);
	}
	   
	/* apply SSL config */
	wd_apply_config_ssl();
}



void wd_reset_config(void) {
	/* free regular expressions */
	if(WD_REGEXP_INITED(wd_settings.ignoreexpression))
		regfree(&WD_REGEXP_REGEX(wd_settings.ignoreexpression));

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



int wd_config_index(char *command) {
	int		min, max, index, cmp;
	
	min = 0;
	max = ARRAY_SIZE(wd_options) - 1;
	
	do {
		index = (min + max) / 2;
		cmp = strcasecmp(command, wd_options[index].name);
		
		if(cmp == 0)
			return index;
		else if(cmp < 0)
			max = index - 1;
		else
			min = index + 1;
	} while(min <= max);
	
	return -1;
}



int wd_set_config(char *name, char *value) {
	int		index, result;
	
	index = wd_config_index(name);
	
	if(index < 0) {
		wd_log(LOG_ERR, "Could not interpret the option \"%s\" at %s line %d",
			name, wd_config, wd_config_line);

		return -1;
	}
	
	result = ((*wd_options[index].setfunc) (name, value, wd_options[index].setting));
	
	if(!wd_startup && wd_options[index].restartrequired) {
		if(((*wd_options[index].comparefunc) (wd_options[index].setting, wd_options[index].previoussetting)) != 0) {
			wd_log(LOG_ERR, "Could not change the option \"%s\" at %s line %d: %s",
				name, wd_config, wd_config_line, "Restart required");
		}
	}
	
	return result;
}



#pragma mark -

int wd_set_config_number(char *name, char *value, void *affects) {
	int		number = strtol(value, NULL, 10);

	*(int *) affects = number;

	return 1;
}



int wd_set_config_string(char *name, char *value, void *affects) {
	strlcpy((char *) affects, value, WD_STRING_SIZE);
	
	return 1;
}



int wd_set_config_path(char *name, char *value, void *affects) {
	wd_expand_path((char *) affects, value, MAXPATHLEN);
	
	return 1;
}



int wd_set_config_user(char *name, char *value, void *affects) {
	struct passwd	**user = (struct passwd **) affects;
	unsigned int	uid;
	
	uid = strtoul(value, NULL, 10);
	
	if(uid == 0 && errno == EINVAL)
		*user = getpwnam(value);
	else
		*user = getpwuid(uid);
	
	if(!*user) {
		wd_log(LOG_WARNING, "Could not locate the user \"%s\" at %s line %d",
			value, wd_config, wd_config_line);
		
		return -1;
	}
	
	return 1;
}



int wd_set_config_group(char *name, char *value, void *affects) {
	struct group	**group = (struct group **) affects;
	unsigned int	gid;
	
	gid = strtoul(value, NULL, 10);
	
	if(gid == 0 && errno == EINVAL)
		*group = getgrnam(value);
	else
		*group = getgrgid(gid);
	
	if(!*group) {
		wd_log(LOG_WARNING, "Could not locate the group \"%s\" at %s line %d",
			value, wd_config, wd_config_line);
		
		return -1;
	}

	return 1;
}



int wd_set_config_boolean(char *name, char *value, void *affects) {
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



int wd_set_config_regex(char *name, char *value, void *affects) {
	regex_t		regex;
	char		*p, *ovalue = NULL, error[WD_STRING_SIZE];
	int			options, result = -1, regresult;
	
	ovalue = strdup(value);
	options = REG_EXTENDED;
	
	/* skip leading / */
	if(value[0] == '/') {
		value++;
	} else {
		wd_log(LOG_ERR, "Could not compile regular expression \"%s\" at %s line %d: %s",
			ovalue, wd_config, wd_config_line, "Missing \"/\"");
		
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
					wd_log(LOG_ERR, "Could not compile regular expression \"%s\" at %s line %d: Invalid option \"%c\"",
						ovalue, wd_config, wd_config_line, *p);
					
					goto error;
					break;
			}
		}
	} else {
		wd_log(LOG_WARNING, "Could not compile regular expression \"%s\" at %s line %d: %s",
			ovalue, wd_config, wd_config_line, "Missing \"/\"");
		
		goto error;
	}

	/* compile expression */
	if((regresult = regcomp(&regex, value, options)) != 0) {
		regerror(regresult, &regex, error, sizeof(error));
		
		wd_log(LOG_ERR, "Could not compile regular expression \"%s\" at %s line %d: %s",
			ovalue, error, wd_config, wd_config_line, error);
		
		goto error;
	}

	WD_REGEXP_REGEX(*(wd_regexp_t *) affects) = regex;
	WD_REGEXP_INITED(*(wd_regexp_t *) affects) = true;
	
	result = 1;

error:
	if(ovalue)
		free(ovalue);
	
	return result;
}



#pragma mark -

int wd_compare_config_number(void *s1, void *s2) {
	return (*(int *) s1 != *(int *) s2);
}



int wd_compare_config_string(void *s1, void *s2) {
	return strcmp((char *) s1, (char *) s2);
}



int wd_compare_config_user(void *s1, void *s2) {
	return ((*(struct passwd **) s1)->pw_uid != (*(struct passwd **) s2)->pw_uid);
}



int wd_compare_config_group(void *s1, void *s2) {
	return ((*(struct group **) s1)->gr_gid != (*(struct group **) s2)->gr_gid);
}



int wd_compare_config_boolean(void *s1, void *s2) {
	return (*(bool *) s1 != *(bool *) s2);
}
