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

#include <sys/param.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <pthread.h>

#include "config.h"
#include "accounts.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


pthread_mutex_t					wd_users_mutex	= PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t					wd_groups_mutex	= PTHREAD_MUTEX_INITIALIZER;

struct wd_user_fields			wd_user_fields[] = {
	{ WD_USER_NAME,					WD_PRIV_NONE,
	  WD_PRIV_TYPE_STRING },
	{ WD_USER_PASSWORD,				WD_PRIV_NONE,
	  WD_PRIV_TYPE_STRING },
	{ WD_USER_GROUP,				WD_PRIV_NONE,
	  WD_PRIV_TYPE_STRING },
	{ WD_USER_GET_USER_INFO,		WD_PRIV_GET_USER_INFO,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_BROADCAST,			WD_PRIV_BROADCAST,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_POST_NEWS,			WD_PRIV_POST_NEWS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_CLEAR_NEWS,			WD_PRIV_CLEAR_NEWS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_DOWNLOAD,				WD_PRIV_DOWNLOAD,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_UPLOAD,				WD_PRIV_UPLOAD,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_UPLOAD_ANYWHERE,		WD_PRIV_UPLOAD_ANYWHERE,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_CREATE_FOLDERS,		WD_PRIV_CREATE_FOLDERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_ALTER_FILES,			WD_PRIV_ALTER_FILES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_DELETE_FILES,			WD_PRIV_DELETE_FILES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_VIEW_DROPBOXES,		WD_PRIV_VIEW_DROPBOXES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_CREATE_ACCOUNTS,		WD_PRIV_CREATE_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_EDIT_ACCOUNTS,		WD_PRIV_EDIT_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_DELETE_ACCOUNTS,		WD_PRIV_DELETE_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_ELEVATE_PRIVILEGES,	WD_PRIV_ELEVATE_PRIVILEGES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_KICK_USERS,			WD_PRIV_KICK_USERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_BAN_USERS,			WD_PRIV_BAN_USERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_CANNOT_BE_KICKED,		WD_PRIV_CANNOT_BE_KICKED,
	  WD_PRIV_TYPE_BOOL },
	{ WD_USER_DOWNLOAD_SPEED,		WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_USER_UPLOAD_SPEED,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_USER_DOWNLOAD_LIMIT,		WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_USER_UPLOAD_LIMIT,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_USER_TOPIC,				WD_PRIV_TOPIC,
	  WD_PRIV_TYPE_NUMBER },
};


struct wd_group_fields			wd_group_fields[] = {
	{ WD_GROUP_NAME,					WD_PRIV_NONE,
	  WD_PRIV_TYPE_STRING },
	{ WD_GROUP_GET_USER_INFO,			WD_PRIV_GET_USER_INFO,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_BROADCAST,				WD_PRIV_BROADCAST,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_POST_NEWS,				WD_PRIV_POST_NEWS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_CLEAR_NEWS,				WD_PRIV_CLEAR_NEWS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_DOWNLOAD,				WD_PRIV_DOWNLOAD,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_UPLOAD,					WD_PRIV_UPLOAD,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_UPLOAD_ANYWHERE,			WD_PRIV_UPLOAD_ANYWHERE,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_CREATE_FOLDERS,			WD_PRIV_CREATE_FOLDERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_ALTER_FILES,				WD_PRIV_ALTER_FILES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_DELETE_FILES,			WD_PRIV_DELETE_FILES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_VIEW_DROPBOXES,			WD_PRIV_VIEW_DROPBOXES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_CREATE_ACCOUNTS,			WD_PRIV_CREATE_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_EDIT_ACCOUNTS,			WD_PRIV_EDIT_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_DELETE_ACCOUNTS,			WD_PRIV_DELETE_ACCOUNTS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_ELEVATE_PRIVILEGES,		WD_PRIV_ELEVATE_PRIVILEGES,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_KICK_USERS,				WD_PRIV_KICK_USERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_BAN_USERS,				WD_PRIV_BAN_USERS,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_CANNOT_BE_KICKED,		WD_PRIV_CANNOT_BE_KICKED,
	  WD_PRIV_TYPE_BOOL },
	{ WD_GROUP_DOWNLOAD_SPEED,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_GROUP_UPLOAD_SPEED,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_GROUP_DOWNLOAD_LIMIT,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_GROUP_UPLOAD_LIMIT,			WD_PRIV_NONE,
	  WD_PRIV_TYPE_NUMBER },
	{ WD_GROUP_TOPIC,					WD_PRIV_TOPIC,
	  WD_PRIV_TYPE_NUMBER },
};


int wd_check_login(char *login, char *password) {
	char	*real_login = NULL, *real_password = NULL;
	int		result = -1;

	/* get fields */
	real_login = wd_get_user_field(login, WD_USER_NAME);
	
	if(!real_login)
		goto end;
	
	real_password = wd_get_user_field(login, WD_USER_PASSWORD);
	
	if(!real_password)
		goto end;
	
	/* attempt a match */
	if(strcmp(real_login, login) == 0) {
		if(strlen(real_password) == 0 || strcmp(real_password, password) == 0)
			result = 1;
	}
	
end:
	/* clean up */	
	if(real_login)
		free(real_login);
	
	if(real_password)
		free(real_password);

	return result;
}



#pragma mark -

char * wd_get_user(char *name) {
	FILE	*fp;
	char	buffer[BUFSIZ], *user = NULL, *p, *ap;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));
			
		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* ignore comments */
		if(buffer[0] == '#' || buffer[0] == '\0')
			continue;
		
		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
		
		/* check for match */
		if(strcmp(name, ap) == 0)
			user = strdup(buffer);
		
		/* free copy */
		free(ap);
		
		if(user)
			break;
	}

end:
	/* clean up */
	if(fp)
		fclose(fp);

	return user;
}



char * wd_get_user_field(char *name, int number) {
	char	*user, *field = NULL, *arg, *ap;
	int		i = 0;
	
	/* get the account */
	user = wd_get_user(name);
	
	if(!user)
		goto end;

	/* loop and separate the fields */
	arg = user;
	
	while((ap = strsep(&arg, ":")) != NULL) {
		if(i == number) {
			field = strdup(ap);

			break;
		}
		
		i++;
	}

end:
	/* clean up */
	if(user)
		free(user);
	
	return field;
}



char * wd_get_group(char *name) {
	FILE	*fp;
	char	buffer[BUFSIZ], *group = NULL, *p, *ap;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));
			
		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* ignore comments */
		if(buffer[0] == '#' || buffer[0] == '\0')
			continue;
		
		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
		
		/* check for match */
		if(strcmp(name, ap) == 0)
			group = strdup(buffer);
		
		/* free copy */
		free(ap);
		
		if(group)
			break;
	}
		
end:
	/* clean up */
	if(fp)
		fclose(fp);

	return group;
}



char * wd_get_group_field(char *name, int number) {
	char	*group, *field = NULL, *arg, *ap;
	int		i = 0;
	
	/* get the account */
	group = wd_get_group(name);
	
	if(!group)
		goto end;

	/* loop and separate the fields */
	arg = group;
	
	while((ap = strsep(&arg, ":")) != NULL) {
		if(i == number) {
			field = strdup(ap);

			break;
		}
		
		i++;
	}
	
end:
	/* clean up */
	if(group)
		free(group);
	
	return field;
}



int wd_get_priv_int(char *name, int priv) {
	char	*group = NULL, *value = NULL;
	int		result = 0;
	
	/* always authorize */
	if(priv == WD_PRIV_NONE) {
		result = 1;
		
		goto end;
	}
	
	/* is the user in a group? */
	group = wd_get_user_field(name, WD_USER_GROUP);
	
	if(group && strlen(group) > 0)
		value = wd_get_group_field(group, priv + WD_GROUP_PRIV_FIRST);
	else
		value = wd_get_user_field(name, priv + WD_USER_PRIV_FIRST);
	
	if(!value) {
		result = 0;
		
		goto end;
	}
	
	result = strtol(value, NULL, 10);
	
end:
	/* clean up */
	if(group)
		free(group);
	
	if(value)
		free(value);
	
	return result;
}



#pragma mark -

int wd_create_user(int argc, char *argv[]) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	FILE			*fp = NULL;
	char			*user = NULL;
	int				i, result = -1;
	
	/* do some sanity checks */
	if(strlen(argv[WD_USER_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	for(i = 0; i < argc; i++) {
		if(wd_check_priv_value(argv[i], wd_user_fields[i].type) < 0) {
			wd_reply(503, "Syntax Error");
					
			goto end;
		}
	}
	
	/* make sure account doesn't already exist */
	user = wd_get_user(argv[WD_USER_NAME]);
	
	if(user) {
		wd_reply(514, "Account exists");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(wd_get_priv_int(client->login, WD_PRIV_ELEVATE_PRIVILEGES) != 1) {
		for(i = 0; i < argc; i++) {
			if(strtoul(argv[i], NULL, 10) == 1) {
				if(wd_get_priv_int(client->login, wd_user_fields[i].privilege) != 1) {
					wd_reply(516, "Permission denied");
			
					goto end;
				}
			}
		}
	}
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* write out fields */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(i < argc) {
			/* insert given value */
			fprintf(fp, "%s", argv[i]);
		} else {
			/* insert default value */
			switch(wd_user_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					fprintf(fp, "%u", 0);
					break;
				
				default:
					break;
			}
		}
		
		/* insert delimiter */
		if(i < WD_USER_LAST - 1)
			fprintf(fp, ":");
	}
	
	/* finish with a newline */
	fprintf(fp, "\n");
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);
		
	if(user)
		free(user);

	/* unlock */
    pthread_mutex_unlock(&wd_users_mutex);
    
    return result;
}



int wd_edit_user(int argc, char *argv[]) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	FILE			*fp = NULL;
	char			*user = NULL;
	int				i, result = -1;
	
	/* do some sanity checks */
	if(strlen(argv[WD_USER_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	for(i = 0; i < argc; i++) {
		if(wd_check_priv_value(argv[i], wd_user_fields[i].type) < 0) {
			wd_reply(503, "Syntax Error");
					
			goto end;
		}
	}
	
	/* make sure account already exist */
	user = wd_get_user(argv[WD_USER_NAME]);
	
	if(!user) {
		wd_reply(513, "Account not found");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(wd_get_priv_int(client->login, WD_PRIV_ELEVATE_PRIVILEGES) != 1) {
		for(i = 0; i < argc; i++) {
			if(strtoul(argv[i], NULL, 10) == 1) {
				if(wd_get_priv_int(client->login, wd_user_fields[i].privilege) != 1) {
					wd_reply(516, "Permission denied");
			
					goto end;
				}
			}
		}
	}
	
	/* delete previous account */
	result = wd_delete_user(argv[WD_USER_NAME]);
	
	if(result < 0)
		goto end;
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* write out fields */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(i < argc) {
			/* insert given value */
			fprintf(fp, "%s", argv[i]);
		} else {
			/* insert default value */
			switch(wd_user_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					fprintf(fp, "%u", 0);
					break;
				
				default:
					break;
			}
		}
		
		/* insert delimiter */
		if(i < WD_USER_LAST - 1)
			fprintf(fp, ":");
	}
	
	/* finish with a newline */
	fprintf(fp, "\n");
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);
		
	if(user)
		free(user);

	/* unlock */
    pthread_mutex_unlock(&wd_users_mutex);
    
    return result;
}



int wd_delete_user(char *name) {
	FILE		*fp = NULL, *tmp = NULL;
	size_t		bytes;
	char		buffer[BUFSIZ], record[BUFSIZ], *user = NULL, *p;
	int			result = -1;
	
	/* make sure receiver exists */
	user = wd_get_user(name);
	
	if(!user) {
		wd_reply(513, "Account not found");
		
		goto end;
	}
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* open a tmp file for writing */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s",
			strerror(errno));

		goto end;
	}
	
	/* copy each line from the users file, skipping this one */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(tmp, buffer);
			
			continue;
		}
		
		/* copy buffer */
		strlcpy(record, buffer, sizeof(record));
		
		/* cut after first field */
		if((p = strchr(buffer, ':')))
			*p = '\0';

		/* copy all records but this one */
		if(strcmp(name, buffer) != 0)
			fprintf(tmp, record);
	}
	
	/* reopen the users file, clearing it */
	freopen(wd_settings.users, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));
		
		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer) , tmp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
	
	if(tmp)
		fclose(tmp);
		
	if(user)
		free(user);

	/* unlock */
    pthread_mutex_unlock(&wd_users_mutex);
    
    return result;
}



int wd_create_group(int argc, char *argv[]) {
	wd_client_t	*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	FILE		*fp = NULL;
	char		*group = NULL;
	int			i, result = -1;
	
	/* do some sanity checks */
	if(strlen(argv[WD_GROUP_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	for(i = 0; i < argc; i++) {
		if(wd_check_priv_value(argv[i], wd_group_fields[i].type) < 0) {
			wd_reply(503, "Syntax Error");
					
			goto end;
		}
	}
	
	/* make sure account doesn't already exist */
	group = wd_get_group(argv[WD_GROUP_NAME]);
	
	if(group) {
		wd_reply(514, "Account exists");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_get_priv_int(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = 0; i < argc; i++) {
			if(strtoul(argv[i], NULL, 10) == 1) {
				if(wd_get_priv_int(client->login, wd_group_fields[i].privilege) != 1) {
					wd_reply(516, "Permission denied");
			
					goto end;
				}
			}
		}
	}

	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* write out fields */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(i < argc) {
			/* insert given value */
			fprintf(fp, "%s", argv[i]);
		} else {
			/* insert default value */
			switch(wd_group_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					fprintf(fp, "%u", 0);
					break;
				
				default:
					break;
			}
		}
		
		/* insert delimiter */
		if(i < WD_GROUP_LAST - 1)
			fprintf(fp, ":");
	}

	/* finish with a newline */
	fprintf(fp, "\n");
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);
		
	if(group)
		free(group);

	/* unlock */
    pthread_mutex_unlock(&wd_groups_mutex);
    
    return result;
}



int wd_edit_group(int argc, char *argv[]) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	FILE			*fp = NULL;
	char			*group = NULL;
	int				i, result = -1;
	
	/* do some sanity checks */
	if(strlen(argv[WD_GROUP_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	for(i = 0; i < argc; i++) {
		if(wd_check_priv_value(argv[i], wd_group_fields[i].type) < 0) {
			wd_reply(503, "Syntax Error");
					
			goto end;
		}
	}
	
	/* make sure account doesn't already exist */
	group = wd_get_group(argv[WD_GROUP_NAME]);
	
	if(!group) {
		wd_reply(513, "Account not found");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_get_priv_int(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = 0; i < argc; i++) {
			if(strtoul(argv[i], NULL, 10) == 1) {
				if(wd_get_priv_int(client->login, wd_group_fields[i].privilege) != 1) {
					wd_reply(516, "Permission denied");
			
					goto end;
				}
			}
		}
	}

	/* delete previous account */
	result = wd_delete_group(argv[WD_GROUP_NAME]);
	
	if(result < 0)
		goto end;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* write out fields */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(i < argc) {
			/* insert given value */
			fprintf(fp, "%s", argv[i]);
		} else {
			/* insert default value */
			switch(wd_group_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					fprintf(fp, "%u", 0);
					break;
				
				default:
					break;
			}
		}
		
		/* insert delimiter */
		if(i < WD_GROUP_LAST - 1)
			fprintf(fp, ":");
	}

	/* finish with a newline */
	fprintf(fp, "\n");
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);
		
	if(group)
		free(group);

	/* unlock */
    pthread_mutex_unlock(&wd_groups_mutex);
    
    return result;
}



int wd_delete_group(char *name) {
	FILE		*fp = NULL, *tmp = NULL;
	char		buffer[BUFSIZ], record[BUFSIZ], *group = NULL, *p;
	size_t		bytes;
	int			result = -1;
	
	/* make sure receiver exists */
	group = wd_get_group(name);
	
	if(!group) {
		wd_reply(513, "Account not found");
		
		goto end;
	}
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s",
			strerror(errno));

		goto end;
	}
	
	/* copy each line from the groups file, skipping this one */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(tmp, buffer);
			
			continue;
		}

		/* copy buffer */
		strlcpy(record, buffer, sizeof(record));
		
		/* cut after first field */
		if((p = strchr(buffer, ':')))
			*p = '\0';

		/* copy all records but this one */
		if(strcmp(name, buffer) != 0)
			fprintf(tmp, record);
	}
	
	/* reopen the groups file, clearing it */
	freopen(wd_settings.groups, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer) , tmp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
	
	if(tmp)
		fclose(tmp);
		
	if(group)
		free(group);
    
	/* unlock */
    pthread_mutex_unlock(&wd_groups_mutex);
	
    return result;
}



void wd_clear_group(char *name) {
	FILE		*fp = NULL, *tmp = NULL;
	size_t		bytes;
	char		buffer[BUFSIZ], *line, *group, *p, *pre;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	tmp = tmpfile();
	
	if(!tmp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s",
			strerror(errno));

		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(tmp, buffer);
			
			continue;
		}

		/* copy the buffer */
		group = line = strdup(buffer);
		pre = strdup(buffer);
		
		/* cut after first two fields */
		if((p = strchr(pre, ':'))) {
			if((p = strchr(++p, ':'))) {
				*(p + 1) = '\0';
				p++;
			}
		}

		/* begin group after the first two fields */
		group += strlen(pre);
		
		/* cut group after first field */
		if((p = strchr(group, ':')))
			*p = '\0';
		
		/* check if it's the group we've deleted */
		if(strcmp(group, name) == 0) {
			/* get rest of original string */
			group += strlen(group) + 1;
			
			/* write spliced record */
			fprintf(tmp, "%s:%s", pre, group);
		} else {
			/* write original record */
			fprintf(tmp, buffer);
		}
		
		/* free the copies */
		free(line);
		free(pre);
	}
	
	/* reopen the users file, clearing it */
	freopen(wd_settings.users, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(tmp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer), tmp)))
		fwrite(buffer, 1, bytes, fp);

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(tmp)
		fclose(tmp);


	/* lock */
    pthread_mutex_unlock(&wd_groups_mutex);
}



#pragma mark -

void wd_read_user(char *name) {
	char		*p, *field, value[1024], out[1024];
	char		*user = NULL;
	int			i;

	/* check for account */
	user = wd_get_user(name);
	
	if(!user) {
		wd_reply(513, "Account Not Found");
		
		goto end;
	}
	
	memset(out, 0, sizeof(out));
	
	/* get all the fields of the account */
	for(i = 0; i < WD_USER_LAST; i++) {
		/* get field */
		field = wd_get_user_field(name, i);
		
		if(field) {
			/* insert given value */
			snprintf(value, sizeof(value), "%s%c",
					 field,
					 WD_FIELD_SEPARATOR);
		} else {
			/* insert default value */
			switch(wd_user_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					snprintf(value, sizeof(value), "%u%c",
							 0,
							 WD_FIELD_SEPARATOR);
					break;
				
				default:
					snprintf(value, sizeof(value), "%c",
							 WD_FIELD_SEPARATOR);
					break;
			}
		}
		
		/* append to string */
		strncat(out, value, strlen(value));
		
		if(field)
			free(field);
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	if((p = strrchr(out, WD_FIELD_SEPARATOR)))
		*p = '\0';

	/* send the account info */
	wd_reply(600, "%s", out);

end:
	/* clean up */
	if(user)
		free(user);
}



void wd_read_group(char *name) {
	char		*p, *field, value[1024], out[1024];
	char		*group = NULL;
	int			i;

	/* check for account */
	group = wd_get_group(name);
	
	if(!group) {
		wd_reply(513, "Account Not Found");
		
		goto end;
	}
	
	memset(out, 0, sizeof(out));
	
	/* get all the fields of the account */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		/* get field */
		field = wd_get_group_field(name, i);
		
		if(field) {
			/* insert given value */
			snprintf(value, sizeof(value), "%s%c",
					 field,
					 WD_FIELD_SEPARATOR);
		} else {
			/* insert default value */
			switch(wd_group_fields[i].type) {
				case WD_PRIV_TYPE_NUMBER:
				case WD_PRIV_TYPE_BOOL:
					snprintf(value, sizeof(value), "%u%c",
							 0,
							 WD_FIELD_SEPARATOR);
					break;
				
				default:
					snprintf(value, sizeof(value), "%c",
							 WD_FIELD_SEPARATOR);
					break;
			}
		}
		
		/* append to string */
		strncat(out, value, strlen(value));
		
		if(field)
			free(field);
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	if((p = strrchr(out, WD_FIELD_SEPARATOR)))
		*p = '\0';

	/* send the account info */
	wd_reply(601, "%s", out);

end:
	/* clean up */
	if(group)
		free(group);
}



void wd_list_users(void) {
	FILE	*fp;
	char	buffer[BUFSIZ], *p;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.users, strerror(errno));
			
		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* ignore comments */
		if(buffer[0] == '#' || buffer[0] == '\0')
			continue;
		
		/* cut after first field */
		if((p = strchr(buffer, ':')) != NULL)
			*p = '\0';
		
		/* send */
		wd_reply(610, "%s", buffer);
	}
	
	wd_reply(611, "Done");

end:
	/* clean up */
	if(fp)
		fclose(fp);
}



void wd_list_groups(void) {
	FILE	*fp;
	char	buffer[BUFSIZ], *p;
	
	/* open the groups file for reading */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s",
			wd_settings.groups, strerror(errno));
			
		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* remove the linebreak */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* ignore comments */
		if(buffer[0] == '#' || buffer[0] == '\0')
			continue;
		
		/* cut after first field */
		if((p = strchr(buffer, ':')) != NULL)
			*p = '\0';
		
		/* send */
		wd_reply(620, "%s", buffer);
	}
	
	wd_reply(621, "Done");

end:
	/* clean up */
	if(fp)
		fclose(fp);
}



void wd_reload_privileges(char *user, char *group) {
	wd_client_t		*client;
	wd_list_node_t	*node;
	wd_chat_t		*chat;
	char			*this_user, *this_group;
	bool			admin;
	
	/* get public chat */
	chat = wd_get_chat(WD_PUBLIC_CHAT);
	
	/* loop over clients and elevate to admin if changed */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(chat->clients, node, client) {
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* get fields */
			this_user = client->login;
			this_group = wd_get_user_field(client->login, WD_USER_GROUP);

			if((user && strcmp(this_user, user) == 0) ||
			   (group && strcmp(this_group, group) == 0)) {
				/* send new privileges information */
				wd_send_privileges(client);
			}
			
			/* elevate to admin if set */
			admin = client->admin;
	
			pthread_mutex_lock(&(client->flag_mutex));
			client->admin = wd_get_priv_int(client->login, WD_PRIV_KICK_USERS) |
							wd_get_priv_int(client->login, WD_PRIV_BAN_USERS);
			pthread_mutex_unlock(&(client->flag_mutex));
			
			if(client->admin != admin) {
				/* broadcast change */
				wd_broadcast(WD_PUBLIC_CHAT, 304, "%u%c%u%c%u%c%u%c%s%c%s",
							 client->uid,
							 WD_FIELD_SEPARATOR,
							 client->idle,
							 WD_FIELD_SEPARATOR,
							 client->admin,
							 WD_FIELD_SEPARATOR,
							 client->icon, 
							 WD_FIELD_SEPARATOR,
							 client->nick,
							 WD_FIELD_SEPARATOR,
							 client->status);
			}

			/* clean up */
			if(this_group)
				free(this_group);
		}
	}
	WD_LIST_UNLOCK(wd_chats);
}



void wd_send_privileges(wd_client_t *client) {
	char			*p, value[1024], out[1024];
	unsigned int	priv;
	int				i;
	
	memset(out, 0, sizeof(out));
	
	/* get all privileges for the account */
	for(i = 0; i < WD_PRIV_LAST; i++) {
		priv = wd_get_priv_int(client->login, i);
		
		/* append this value to the out string */
		snprintf(value, sizeof(value), "%u%c",
				 priv,
				 WD_FIELD_SEPARATOR);
		strncat(out, value, strlen(value));
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	if((p = strrchr(out, WD_FIELD_SEPARATOR)))
		*p = '\0';
	
	/* send the account info */
	pthread_mutex_lock(&(client->ssl_mutex));
	wd_sreply(client->ssl, 602, out);
	pthread_mutex_unlock(&(client->ssl_mutex));
}



#pragma mark -

int wd_check_priv_value(char *value, int type) {
	int			test;
	
	if(strlen(value) == 0)
		return 1;
	
	switch(type) {
		case WD_PRIV_TYPE_STRING:
			if(strchr(value, ':') != NULL)
				return -1;
			break;
		
		case WD_PRIV_TYPE_NUMBER:
			test = strtol(value, NULL, 10);
			
			if(errno == EINVAL)
				return -1;
			break;
		
		case WD_PRIV_TYPE_BOOL:
			test = strtoul(value, NULL, 10);
			
			if(errno == EINVAL || test > 1)
				return -1;
			break;
		
		default:
			break;
	}
	
	return 1;
}
