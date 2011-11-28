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


int wd_check_login(char *login, char *password) {
	char	*real_login = NULL, *real_password = NULL;
	int		result = -1;

	/* get fields */
	real_login = wd_getuserfield(login, WD_USER_NAME);
	
	if(!real_login)
		goto end;
	
	real_password = wd_getuserfield(login, WD_USER_PASSWORD);
	
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

char * wd_getuser(char *name) {
	FILE	*fp;
	char	buffer[BUFSIZ], *user = NULL, *p, *ap;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));
			
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



char * wd_getuserfield(char *name, int number) {
	char	*user, *field = NULL, *arg, *ap;
	int		i = 0;
	
	/* get the account */
	user = wd_getuser(name);
	
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



char * wd_getgroup(char *name) {
	FILE	*fp;
	char	buffer[BUFSIZ], *group = NULL, *p, *ap;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));
			
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



char * wd_getgroupfield(char *name, int number) {
	char	*group, *field = NULL, *arg, *ap;
	int		i = 0;
	
	/* get the account */
	group = wd_getgroup(name);
	
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



int wd_getpriv(char *name, int priv) {
	char	*group, *value;
	int		result = 1;
	
	/* is the user in a group? */
	group = wd_getuserfield(name, WD_USER_GROUP);
	
	if(group && strlen(group) > 0)
		value = wd_getgroupfield(group, priv + 1);
	else
		value = wd_getuserfield(name, priv + 3);
	
	if(!value)
		goto end;
	
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

int wd_create_user(char *fields[]) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	FILE			*fp;
	char			*user = NULL;
	int				i, ok = 1, result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* do some sanity checks */
	if(strlen(fields[WD_USER_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	/* make sure account doesn't already exist */
	user = wd_getuser(fields[WD_USER_NAME]);
	
	if(user) {
		wd_reply(514, "Account exists");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_getpriv(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = WD_USER_GET_USER_INFO; i < WD_USER_DOWNLOAD_SPEED; i++) {
			if(strtol(fields[i], NULL, 10) == 1) {
				if(wd_getpriv(client->login, i - 3) != 1)
					ok = -1;
			}
		}
		
		if(ok < 0) {
			wd_reply(516, "Permission denied");
	
			goto end;
		}
	}

	/* write out fields */
	for(i = 0; i < WD_USER_LAST; i++) {
		fprintf(fp, "%s%s",
			fields[i],
			i + 1 == WD_USER_LAST ? "" : ":");
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



int wd_edit_user(char *fields[]) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	FILE			*fp = NULL, *temp = NULL;
	size_t			bytes;
	char			buffer[BUFSIZ], *user = NULL, *p, *ap;
	int				i, ok = 1, result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	temp = tmpfile();
	
	if(!temp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s", strerror(errno));

		goto end;
	}
	
	/* make sure account already exists */
	user = wd_getuser(fields[WD_USER_NAME]);
	
	if(!user) {
		wd_reply(513, "Account not found");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_getpriv(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = WD_USER_GET_USER_INFO; i < WD_USER_DOWNLOAD_SPEED; i++) {
			if(strtol(fields[i], NULL, 10) != wd_getpriv(fields[WD_USER_NAME], i - 3)) {
				if(wd_getpriv(client->login, i - 3) != 1)
					ok = -1;
			}
		}
		
		if(ok < 0) {
			wd_reply(516, "Permission denied");
	
			goto end;
		}
	}
	
	/* copy each line from the users file, skipping this login */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(temp, buffer);
			
			continue;
		}

		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
			
		if(strcmp(ap, fields[WD_USER_NAME]) != 0) {
			/* write our old record */
			fprintf(temp, buffer);
		} else {
			/* write our new record to the file instead of the old one */
			for(i = 0; i < WD_USER_LAST; i++) {
				fprintf(temp, "%s%s",
					fields[i],
					i + 1 == WD_USER_LAST ? "" : ":");
			}
			
			/* finish with a newline */
			fprintf(temp, "\n");
		}
		
		/* free the copy */
		free(ap);
	}
	
	/* reopen the users file, clearing it */
	freopen(wd_settings.users, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(temp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer), temp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(temp)
		fclose(temp);
		
	if(user)
		free(user);

	/* unlock */
    pthread_mutex_unlock(&wd_users_mutex);
    
    return result;
}



int wd_delete_user(char *name) {
	FILE		*fp = NULL, *temp = NULL;
	size_t		bytes;
	char		buffer[BUFSIZ], *user = NULL, *p, *ap;
	int			result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_users_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	temp = tmpfile();
	
	if(!temp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s", strerror(errno));

		goto end;
	}
	
	/* make sure receiver exists */
	user = wd_getuser(name);
	
	if(!user) {
		wd_reply(513, "Account not found");
		
		goto end;
	}
	
	/* copy each line from the users file, skipping this one */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(temp, buffer);
			
			continue;
		}

		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
		
		/* copy all records but this one */
		if(strcmp(ap, name) != 0)
			fprintf(temp, buffer);
		
		/* free the copy */
		free(ap);
	}
	
	/* reopen the users file, clearing it */
	freopen(wd_settings.users, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));
		
		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(temp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer) , temp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
	
	if(temp)
		fclose(temp);
		
	if(user)
		free(user);

	/* unlock */
    pthread_mutex_unlock(&wd_users_mutex);
    
    return result;
}



int wd_create_group(char *fields[]) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	FILE			*fp;
	char			*group = NULL;
	int				i, ok = 1, result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "a");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* do some sanity checks */
	if(strlen(fields[WD_GROUP_NAME]) == 0) {
		wd_reply(503, "Syntax error");
		
		goto end;
	}
	
	/* make sure account doesn't already exist */
	group = wd_getgroup(fields[WD_GROUP_NAME]);
	
	if(group) {
		wd_reply(514, "Account exists");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_getpriv(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = WD_GROUP_GET_USER_INFO; i < WD_GROUP_DOWNLOAD_SPEED; i++) {
			if(strtol(fields[i], NULL, 10) == 1) {
				if(wd_getpriv(client->login, i - 1) != 1)
					ok = -1;
			}
		}
		
		if(ok < 0) {
			wd_reply(516, "Permission denied");
	
			goto end;
		}
	}

	/* write out fields */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		fprintf(fp, "%s%s",
			fields[i],
			i + 1 == WD_GROUP_LAST
				? ""
				: ":");
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



int wd_edit_group(char *fields[]) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	FILE				*fp = NULL, *temp = NULL;
	size_t				bytes;
	char				buffer[BUFSIZ], *group = NULL, *p, *ap;
	int					i, ok = 1, result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	temp = tmpfile();
	
	if(!temp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s", strerror(errno));

		goto end;
	}
	
	/* make sure account already exists */
	group = wd_getgroup(fields[WD_GROUP_NAME]);
	
	if(!group) {
		wd_reply(513, "Account not found");

		goto end;
	}
	
	/* make sure the creator has all fields */
	if(!wd_getpriv(client->login, WD_PRIV_ELEVATE_PRIVILEGES)) {
		for(i = WD_GROUP_GET_USER_INFO; i < WD_GROUP_DOWNLOAD_SPEED; i++) {
			if(strcmp(fields[i], wd_getgroupfield(fields[WD_GROUP_NAME], i)) != 0) {
				if(wd_getpriv(client->login, i - 1) != 1)
					ok = -1;
			}
		}
		
		if(ok < 0) {
			wd_reply(516, "Permission denied");
	
			goto end;
		}
	}
	
	/* copy each line from the groups file, skipping this login */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(temp, buffer);
			
			continue;
		}

		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
			
		if(strcmp(ap, fields[WD_GROUP_NAME]) != 0) {
			/* write our old record */
			fprintf(temp, buffer);
		} else {
			/* write our new record to the file instead of the old one */
			for(i = 0; i < WD_GROUP_LAST; i++) {
				fprintf(temp, "%s%s",
					fields[i],
					i + 1 == WD_GROUP_LAST ? "" : ":");
			}
			
			/* finish with a newline */
			fprintf(temp, "\n");
		}
		
		/* free the copy */
		free(ap);
	}
	
	/* reopen the groups file, clearing it */
	freopen(wd_settings.groups, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(temp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer), temp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(temp)
		fclose(temp);
		
	if(group)
		free(group);

	/* unlock */
    pthread_mutex_unlock(&wd_groups_mutex);
    
    return result;
}



int wd_delete_group(char *name) {
	FILE		*fp = NULL, *temp = NULL;
	size_t		bytes;
	char		buffer[BUFSIZ], *group = NULL, *p, *ap;
	int			result = -1;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the groups file */
	fp = fopen(wd_settings.groups, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	temp = tmpfile();
	
	if(!temp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s", strerror(errno));

		goto end;
	}
	
	/* make sure receiver exists */
	group = wd_getgroup(name);
	
	if(!group) {
		wd_reply(513, "Account not found");
		
		goto end;
	}
	
	/* copy each line from the groups file, skipping this one */
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(temp, buffer);
			
			continue;
		}

		/* copy the buffer */
		ap = strdup(buffer);
		
		/* cut after first field */
		if((p = strchr(ap, ':')) != NULL)
			*p = '\0';
		
		/* copy all records but this one */
		if(strcmp(ap, name) != 0)
			fprintf(temp, buffer);
		
		/* free the copy */
		free(ap);
	}
	
	/* reopen the groups file, clearing it */
	freopen(wd_settings.groups, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(temp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer) , temp)))
		fwrite(buffer, 1, bytes, fp);
	
	/* success */
	result = 1;
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
	
	if(temp)
		fclose(temp);
		
	if(group)
		free(group);
    
	/* unlock */
    pthread_mutex_unlock(&wd_groups_mutex);
	
	/* remove references to this group */
	if(result > 0)
		wd_clear_group(name);

    return result;
}



void wd_clear_group(char *group) {
	FILE		*fp = NULL, *temp = NULL;
	size_t		bytes;
	char		buffer[BUFSIZ], *line, *this_group, *p, *pre;
	
	/* lock */
    pthread_mutex_lock(&wd_groups_mutex);

	/* open the users file */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* open a temp file for writing */
	temp = tmpfile();
	
	if(!temp) {
		wd_log(LOG_WARNING, "Could not create temporary file: %s", strerror(errno));

		goto end;
	}
	
	while(fgets(buffer, sizeof(buffer), fp) != NULL) {
		/* copy comments and blank lines */
		if(buffer[0] == '#' || buffer[0] == '\n') {
			fprintf(temp, buffer);
			
			continue;
		}

		/* copy the buffer */
		this_group = line = strdup(buffer);
		pre = strdup(buffer);
		
		/* cut after first two fields */
		if((p = strchr(pre, ':'))) {
			if((p = strchr(++p, ':'))) {
				*(p + 1) = '\0';
				p++;
			}
		}

		/* begin group after the first two fields */
		this_group += strlen(pre);
		
		/* cut group after first field */
		if((p = strchr(this_group, ':')))
			*p = '\0';
		
		/* check if it's the group we've deleted */
		if(strcmp(this_group, group) == 0) {
			/* get rest of original string */
			this_group += strlen(this_group) + 1;
			
			/* write spliced record */
			fprintf(temp, "%s:%s", pre, this_group);
		} else {
			/* write original record */
			fprintf(temp, buffer);
		}
		
		/* free the copies */
		free(line);
		free(pre);
	}
	
	/* reopen the users file, clearing it */
	freopen(wd_settings.users, "w", fp);
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));

		goto end;
	}
	
	/* start over at the beginning of the temporary file */
	rewind(temp);
	
	/* complete copy back */
	while((bytes = fread(buffer, 1, sizeof(buffer), temp)))
		fwrite(buffer, 1, bytes, fp);

end:
	/* clean up */
	if(fp)
		fclose(fp);

	if(temp)
		fclose(temp);


	/* lock */
    pthread_mutex_unlock(&wd_groups_mutex);
}



#pragma mark -

void wd_list_users(void) {
	FILE	*fp;
	char	buffer[BUFSIZ], *p;
	
	/* open the users file for reading */
	fp = fopen(wd_settings.users, "r");
	
	if(!fp) {
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.users, strerror(errno));
			
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
		wd_log(LOG_WARNING, "Could not open %s: %s", wd_settings.groups, strerror(errno));
			
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



void wd_list_privileges(struct wd_client *client) {
	char			value[1024], out[1024];
	unsigned int	priv;
	int				i, length;
	
	memset(out, 0, sizeof(out));
	
	/* get all privileges for the account */
	for(i = 0; i < WD_PRIV_LAST; i++) {
		priv = wd_getpriv(client->login, i);
		
		/* append this value to the out string */
		snprintf(value, sizeof(value), "%u%s", priv, WD_FIELD_SEPARATOR);
		strncat(out, value, strlen(value));
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	length = strlen(out);

	if(length > 0)
		out[length - 1] = '\0';
	
	/* send the account info */
	pthread_mutex_lock(&(client->ssl_mutex));
	wd_sreply(client->ssl, 602, out);
	pthread_mutex_unlock(&(client->ssl_mutex));
}
