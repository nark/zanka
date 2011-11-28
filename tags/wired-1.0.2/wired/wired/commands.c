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

#include <sys/types.h>
#include <sys/time.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <ctype.h>
#include <libgen.h>
#include <pthread.h>
#include <openssl/err.h>

#include "config.h"
#include "accounts.h"
#include "banlist.h"
#include "commands.h"
#include "hotline.h"
#include "main.h"
#include "news.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


struct server_commands	wd_server_commands[] = {
 { "BAN",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_BAN_USERS,				wd_cmd_ban },
 { "BROADCAST",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_BROADCAST,				wd_cmd_broadcast },
 { "CLEARNEWS",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_CLEAR_NEWS,				wd_cmd_clearnews },
 { "CLIENT",
   WD_CLIENT_STATE_SAID_HELLO,		true,		true,
   WD_PRIV_NONE,					wd_cmd_client },
 { "CREATEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_CREATE_ACCOUNTS,			wd_cmd_creategroup },
 { "CREATEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_CREATE_ACCOUNTS,			wd_cmd_createuser },
 { "DECLINE",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_decline },
 { "DELETE",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_DELETE_FILES,			wd_cmd_delete },
 { "DELETEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_DELETE_ACCOUNTS,			wd_cmd_deletegroup },
 { "DELETEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_DELETE_ACCOUNTS,			wd_cmd_deleteuser },
 { "EDITGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_editgroup },
 { "EDITUSER",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_edituser },
 { "FOLDER",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_folder },
 { "GET",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_DOWNLOAD,				wd_cmd_get },
 { "GROUPS",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_groups },
 { "HELLO",
   WD_CLIENT_STATE_CONNECTED,		false,		true,
   WD_PRIV_NONE,					wd_cmd_hello },
 { "ICON",
   WD_CLIENT_STATE_SAID_HELLO,		true,		true,
   WD_PRIV_NONE,					wd_cmd_icon },
 { "INFO",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_GET_USER_INFO,			wd_cmd_info },
 { "INVITE",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_invite },
 { "JOIN",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_join },
 { "KICK",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_KICK_USERS,				wd_cmd_kick },
 { "LEAVE",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_leave },
 { "LIST",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_list },
 { "ME",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_me },
 { "MOVE",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_MOVE_FILES,				wd_cmd_move },
 { "MSG",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_msg },
 { "NEWS",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_NONE,					wd_cmd_news },
 { "NICK",
   WD_CLIENT_STATE_SAID_HELLO,		true,		true,
   WD_PRIV_NONE,					wd_cmd_nick },
 { "PASS",
   WD_CLIENT_STATE_GAVE_USER,		false,		true,
   WD_PRIV_NONE,					wd_cmd_pass },
 { "PING",
   WD_CLIENT_STATE_CONNECTED,		false,		false,
   WD_PRIV_NONE,					wd_cmd_ping },
 { "POST",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_POST_NEWS,				wd_cmd_post },
 { "PRIVCHAT",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_NONE,					wd_cmd_privchat },
 { "PRIVILEGES",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_NONE,					wd_cmd_privileges },
 { "PUT",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_put },
 { "READGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_readgroup },
 { "READUSER",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_readuser },
 { "SAY",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_say },
 { "SEARCH",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_search },
 { "STAT",
   WD_CLIENT_STATE_LOGGED_IN,		true,		true,
   WD_PRIV_NONE,					wd_cmd_stat },
 { "USER",
   WD_CLIENT_STATE_SAID_HELLO,		true,		true,
   WD_PRIV_NONE,					wd_cmd_user },
 { "USERS",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_users },
 { "WHO",
   WD_CLIENT_STATE_LOGGED_IN,		false,		true,
   WD_PRIV_NONE,					wd_cmd_who },
};


void * wd_ctl_thread(void *arg) {
	struct wd_client	*client = (struct wd_client *) arg;
	struct timeval		tv;
	fd_set				rfds;
	char				*buffer, *ap;
	int					bytes, state;

	/* associate the struct with this thread */
	pthread_setspecific(wd_client_key, client);

	/* go client */
	while(client->state <= WD_CLIENT_STATE_LOGGED_IN) {
		do {
			FD_ZERO(&rfds);
			FD_SET(client->sd, &rfds);
			tv.tv_sec = 0;
			tv.tv_usec = 100000;
			state = select(client->sd + 1, &rfds, NULL, NULL, &tv);
		} while(state == 0 && client->state <= WD_CLIENT_STATE_LOGGED_IN);
		
		if(client->state > WD_CLIENT_STATE_LOGGED_IN) {
			/* invalid state */
			break;
		}
		
		if(state < 0) {
			if(errno == EINTR) {
				/* got a signal */
				continue;
			} else {
				/* error in TCP communication */
				wd_log(LOG_WARNING, "Could not read from %s: %s",
					client->ip, strerror(errno));

				break;
			}
		}
		
		/* read from SSL */
		pthread_mutex_lock(&(client->ssl_mutex));
		bytes = SSL_read(client->ssl, client->buffer, sizeof(client->buffer));
		pthread_mutex_unlock(&(client->ssl_mutex));
		
		if(bytes == 0) {
			/* EOF */
			break;
		}
		else if(bytes < 0) {
			/* error in SSL communication */
			wd_log(LOG_WARNING, "Could not read from %s: %s",
				client->ip, ERR_get_error() != 0
					? ERR_reason_error_string(ERR_get_error())
					: strerror(errno));

			break;
		}
		
		/* make sure the incoming buffer is properly terminated */
		buffer = client->buffer;
		buffer[bytes] = '\0';
		
		/* loop over the incoming buffer and split up the commands */
		while((ap = strsep(&buffer, WD_MESSAGE_SEPARATOR)) != NULL) {
			if(strlen(ap) > 0)
				wd_parse_command(ap);
		}
	}
	
	/* announce parting if client disconnected by itself */
	if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
		pthread_mutex_lock(&(wd_chats.mutex));
		wd_broadcast(1, 303, "%u%s%lu", 1, WD_FIELD_SEPARATOR, client->uid);
		pthread_mutex_unlock(&(wd_chats.mutex));
	
		/* hotline subsystem */	
		if(wd_settings.hotline)
			wd_hl_relay_leave(client->uid);
	}
	
	/* update status for clients logged in and above */
	if(client->state >= WD_CLIENT_STATE_LOGGED_IN) {
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users--;
		pthread_mutex_unlock(&wd_status_mutex);
		wd_write_status();
	}
	
	/* log */
	wd_log(LOG_INFO, "Disconnect from %s", client->ip);

	/* now delete client */
	wd_delete_client(client);

	return NULL;
}



#pragma mark -

void wd_parse_command(char *buffer) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*p, *command = NULL, *arg = NULL;
	int					i;
	
	/* loop over the command */
	for(p = buffer; *buffer && !isspace(*buffer); buffer++)
		;
	
	/* get command */
	command = (char *) malloc(buffer - p + 1);
	memcpy(command, p, buffer - p);
	command[buffer - p] = NULL;

	/* verify command */
	i = wd_command_index(command);
	
	if(i < 0) {
		wd_reply(501, "Command Not Recognized");
		
		goto end;
	}
	
	/* loop over argument string */	
	for(p = ++buffer; *buffer; buffer++)
		;
	
	/* get argument */
	arg = (char *) malloc(buffer - p + 1);
	memcpy(arg, p, buffer - p);
	arg[buffer - p] = NULL;
	
	/* verify state */
	if(client->state < wd_server_commands[i].state)
		goto end;
	
	/* verify arg */
	if(wd_server_commands[i].args == true && strlen(arg) == 0) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* verify permission */
	if(wd_server_commands[i].permission != WD_PRIV_NONE) {
		if(wd_getpriv(client->login, wd_server_commands[i].permission) != 1) {
			wd_reply(516, "Permission Denied");
		
			goto end;
		}
	}
	
	/* update the idle time */
	if(wd_server_commands[i].activate) {
		client->idle_time = time(NULL);

		if(client->idle) {
			client->idle = 0;

			/* broadcast a user change */
			pthread_mutex_lock(&(wd_chats.mutex));
			wd_broadcast(1, 304, "%lu%s%u%s%u%s%lu%s%s",
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 client->idle,
						 WD_FIELD_SEPARATOR,
						 client->admin,
						 WD_FIELD_SEPARATOR,
						 client->icon,
						 WD_FIELD_SEPARATOR,
						 client->nick);
			pthread_mutex_unlock(&(wd_chats.mutex));
			
			/* hotline subsystem */
			if(wd_settings.hotline) {
				wd_hl_relay_nick(client->uid, client->nick, client->icon,
								 client->idle, client->admin);
			}
		}
	}


	/* go server command */
	((*wd_server_commands[i].action) (arg));

end:
	/* clean up */
	if(command)
		free(command);
	
	if(arg)
		free(arg);
}



int wd_command_index(char *command) {
	int		min, max, i, cmp;
	
	min = 0;
	max = ARRAY_SIZE(wd_server_commands) - 1;
	
	do {
		i = (min + max) / 2;
		cmp = strcasecmp(command, wd_server_commands[i].name);
		
		if(cmp == 0)
			return i;
		else if(cmp < 0)
			max = i - 1;
		else
			min = i + 1;
	} while(min <= max);
	
	return -1;
}



#pragma mark -

/*
	BAN <uid> <reason>
*/

void wd_cmd_ban(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client		*peer;
	struct wd_tempban		*tempban;
	char					*ap, *uid = NULL, *message = NULL;
	unsigned long			uid_l;
	int						i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			uid = strdup(ap);
		else if(i == 1)
			message = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!uid || !message) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* convert user id */
	uid_l = strtoul(uid, NULL, 0);

	/* get user */
	peer = wd_get_client(uid_l, 1);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		goto end;
	}

	/* check priv */
	if(wd_getpriv(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		goto end;
	}
	
	/* broadcast a 307 */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 307, "%lu%s%d%s%s",
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 client->uid,
				 WD_FIELD_SEPARATOR,
				 message);
	pthread_mutex_unlock(&(wd_chats.mutex));
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s banned %s/%s/%s",
			  client->nick,
			  client->login,
			  client->ip,
			  peer->nick,
			  peer->login,
			  peer->ip);

	/* create a temporary ban */
	tempban = (struct wd_tempban *) malloc(sizeof(struct wd_tempban));
	memset(tempban, 0, sizeof(tempban));
	
	/* set values */
	strlcpy(tempban->ip, peer->ip, sizeof(tempban->ip));
	tempban->time = time(NULL);
	
	/* add to list */
	pthread_mutex_lock(&(wd_tempbans.mutex));
	wd_list_add(&wd_tempbans, (void *) tempban);
	pthread_mutex_unlock(&(wd_tempbans.mutex));

	/* disconnect */
	pthread_mutex_lock(&(peer->state_mutex));
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	pthread_mutex_unlock(&(peer->state_mutex));

end:
	/* clean up */
	if(uid)
		free(uid);
	
	if(message)
		free(message);
}



/*
	BROADCAST <message>
*/

void wd_cmd_broadcast(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* broadcast message */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 309, "%lu%s%s", client->uid, WD_FIELD_SEPARATOR, arg);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



/*
	CLEARNEWS
*/

void wd_cmd_clearnews(char *arg) {
	/* clear the news */
	wd_clear_news();
}



/*
	CLIENT <application-version>
*/

void wd_cmd_client(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* copy version string */
	strlcpy(client->version, arg, sizeof(client->version));
}



/*
	CREATEGROUP <...>
*/

void wd_cmd_creategroup(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*ap, *fields[WD_GROUP_LAST + 1];
	int					i = 0;

	/* init */
	memset(&fields, 0, sizeof(fields));
	
	/* check for the groups file delimiter */
	if(strpbrk(arg, ":") != NULL) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i > WD_GROUP_LAST) {
			wd_reply(503, "Syntax Error");
			
			goto end;
		}
		
		fields[i] = strdup(ap);
		i++;
	}

	/* fill in the blanks */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(!fields[i])
			fields[i] = strdup("");
	}

	/* terminate */
	fields[WD_GROUP_LAST] = NULL;
	
	/* create the group */
	if(wd_create_group(fields) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s created the group \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  fields[WD_GROUP_NAME]);
	}
	
end:
	/* clean up */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(fields[i])
			free(fields[i]);
	}
}



/*
	CREATEUSER <...>
*/

void wd_cmd_createuser(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*ap, *fields[WD_USER_LAST + 1];
	int					i = 0;

	/* init */
	memset(&fields, 0, sizeof(fields));
	
	/* check for the accounts file delimiter */
	if(strpbrk(arg, ":") != NULL) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i > WD_USER_LAST) {
			wd_reply(503, "Syntax Error");
			
			goto end;
		}
		
		fields[i] = strdup(ap);
		i++;
	}
	
	/* fill in the blanks */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(!fields[i])
			fields[i] = strdup("");
	}

	/* terminate */
	fields[WD_USER_LAST] = NULL;
	
	/* create the user */
	if(wd_create_user(fields) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s created the user \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  fields[WD_USER_NAME]);
	}
	
end:
	/* clean up */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(fields[i])
			free(fields[i]);
	}
}



/*
	DECLINE <cid>
*/

void wd_cmd_decline(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	unsigned long		cid;
	
	/* convert argument */
	cid = strtoul(arg, NULL, 0);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid) == NULL)
		return;

	/* send declined message */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(cid, 332, "%lu%s%lu", cid, WD_FIELD_SEPARATOR, client->uid);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



/*
	DELETE <path>
*/

void wd_cmd_delete(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* verify the path */
	if(wd_evaluate_path(arg) < 0) {
		wd_reply(520, "File or Directory Not Found");

		return;
	}

	/* delete tree attached to path */
	if(wd_delete_path(arg) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted \"%s\"",
			      client->nick,
			      client->login,
			      client->ip,
			      arg);
	}
}



/*
	DELETEGROUP <name>
*/

void wd_cmd_deletegroup(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* delete the group */
	if(wd_delete_group(arg) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted the group \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  arg);
	}
}



/*
	DELETEUSER <name>
*/

void wd_cmd_deleteuser(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* delete the user */
	if(wd_delete_user(arg) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted the user \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  arg);
	}
}



/*
	EDITGROUP <...>
*/

void wd_cmd_editgroup(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client		*peer;
	struct wd_list			*clients;
	struct wd_list_node	*node;
	char				*ap, *fields[WD_GROUP_LAST + 1], *group = NULL;
	int					i = 0;
	unsigned int		old_admin;

	/* init */
	memset(&fields, 0, sizeof(fields));

	/* check for the groups file delimiter */
	if(strchr(arg, ':') != NULL) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i > WD_GROUP_LAST) {
			wd_reply(503, "Syntax Error");
			
			goto end;
		}
		
		fields[i] = strdup(ap);
		i++;
	}

	/* fill in the blanks */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(!fields[i])
			fields[i] = strdup("");
	}

	/* terminate */
	fields[WD_GROUP_LAST] = NULL;
	
	/* edit the group */
	if(wd_edit_group(fields) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s modified the group \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  fields[WD_GROUP_NAME]);
	}
	
	/* get public chat */
	clients = &(((struct wd_chat *) ((wd_chats.first)->data))->clients);
	
	/* loop over clients and elevate to admin if changed */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(node = clients->first; node != NULL; node = node->next) {
		peer = node->data;
		
		/* get group field */
		group = wd_getuserfield(peer->login, WD_USER_GROUP);

		if(peer->state == WD_CLIENT_STATE_LOGGED_IN && strcmp(group, fields[0]) == 0) {
			/* send new privileges information */
			wd_list_privileges(peer);

			/* elevate to admin if set */
			old_admin = peer->admin;
	
			pthread_mutex_lock(&(peer->admin_mutex));
			peer->admin = wd_getpriv(peer->login, WD_PRIV_KICK_USERS) |
						  wd_getpriv(peer->login, WD_PRIV_BAN_USERS);
			pthread_mutex_unlock(&(peer->admin_mutex));
			
			if(peer->admin != old_admin) {
				/* broadcast change */
				wd_broadcast(1, 304, "%lu%s%u%s%u%s%lu%s%s",
								peer->uid,
								WD_FIELD_SEPARATOR,
								peer->idle,
								WD_FIELD_SEPARATOR,
								peer->admin,
								WD_FIELD_SEPARATOR,
								peer->icon, 
								WD_FIELD_SEPARATOR,
								peer->nick);
			
				/* hotline subsystem */
				if(wd_settings.hotline) {
					wd_hl_relay_nick(client->uid, client->nick, client->icon,
									 client->idle, client->admin);
				}
			}
		}

		free(group);
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
end:
	/* clean up */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		if(fields[i])
			free(fields[i]);
	}
}



/*
	EDITUSER <...>
*/

void wd_cmd_edituser(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client		*peer;
	struct wd_list			*clients;
	struct wd_list_node		*node;
	char					*ap, *fields[WD_USER_LAST + 1];
	int						i = 0;
	unsigned int			old_admin;
	
	/* init */
	memset(&fields, 0, sizeof(fields));

	/* check for the accounts file delimiter */
	if(strchr(arg, ':') != NULL) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i > WD_USER_LAST) {
			wd_reply(503, "Syntax Error");
			
			goto end;
		}
		
		fields[i] = strdup(ap);
		i++;
	}

	/* fill in the blanks */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(!fields[i])
			fields[i] = strdup("");
	}

	/* terminate */
	fields[WD_USER_LAST] = NULL;
	
	/* edit the user */
	if(wd_edit_user(fields) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s modified the user \"%s\"",
				  client->nick,
				  client->login,
				  client->ip,
				  fields[WD_USER_NAME]);
	}
	
	/* get public chat */
	clients = &(((struct wd_chat *) ((wd_chats.first)->data))->clients);
	
	/* loop over clients and elevate to admin if changed */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(node = clients->first; node != NULL; node = node->next) {
		peer = node->data;

		if(peer->state == WD_CLIENT_STATE_LOGGED_IN && strcmp(peer->login, fields[0]) == 0) {
			/* send new privileges information */
			wd_list_privileges(peer);
			
			/* elevate to admin if set */
			old_admin = peer->admin;
	
			pthread_mutex_lock(&(peer->admin_mutex));
			peer->admin = wd_getpriv(peer->login, WD_PRIV_KICK_USERS) |
						  wd_getpriv(peer->login, WD_PRIV_BAN_USERS);
			pthread_mutex_unlock(&(peer->admin_mutex));
			
			if(peer->admin != old_admin) {
				/* broadcast change */
				wd_broadcast(1, 304, "%lu%s%u%s%u%s%lu%s%s",
								peer->uid,
								WD_FIELD_SEPARATOR,
								peer->idle,
								WD_FIELD_SEPARATOR,
								peer->admin,
								WD_FIELD_SEPARATOR,
								peer->icon, 
								WD_FIELD_SEPARATOR,
								peer->nick);
			
				/* hotline subsystem */
				if(wd_settings.hotline) {
					wd_hl_relay_nick(client->uid, client->nick, client->icon,
									 client->idle, client->admin);
				}
			}
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
end:
	/* clean up */
	for(i = 0; i < WD_USER_LAST; i++) {
		if(fields[i])
			free(fields[i]);
	}
}



/*
	FOLDER <path>
*/

void wd_cmd_folder(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char					*dir, real_path[MAXPATHLEN];
	
	/* verify the path */
	if(wd_evaluate_path(arg) < 0) {
		wd_reply(520, "File or Directory Not Found");
			
		return;
	}

	/* get the directory name */
	dir = dirname(arg);
	
	if(!dir) {
		wd_reply(520, "File or Directory Not Found");
			
		return;
	}
	
	snprintf(real_path, sizeof(real_path), ".%s", dir);
	
	/* verify permissions */
	switch(wd_gettype(real_path, NULL)) {
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
		
		default:
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD_ANYWHERE) != 1 &&
			   wd_getpriv(client->login, WD_PRIV_CREATE_FOLDERS) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
	}

	/* create the directory */
	wd_create_path(arg);
}



/*
	GET <path> <offset>
*/

void wd_cmd_get(char *arg) {
	char		*ap, *path = NULL, *offset = NULL;
	off_t		offset_l;
	int			i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			path = strdup(ap);
		else if(i == 1)
			offset = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!path || !offset) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* verify the path */
	if(wd_evaluate_path(path) < 0) {
		wd_reply(520, "File or Directory Not Found");
		
		goto end;
	}
	
	/* convert offset */
	offset_l = strtoul(offset, NULL, 0);

	/* get the file */
	wd_queue_download(path, offset_l);

end:
	/* clean up */
	if(path)
		free(path);
	
	if(offset)
		free(offset);
}



/*
	GROUPS
*/

void wd_cmd_groups(char *arg) {
	/* list groups */
	wd_list_groups();
}



/*
	HELLO
*/

void wd_cmd_hello(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				start_time[26];
	
	/* check state */
	if(client->state != WD_CLIENT_STATE_CONNECTED)
		return;
	
	/* check ban */
	if(wd_check_ban(client->ip) < 0) {
		wd_reply(511, "Banned");
		wd_log(LOG_INFO, "Connection from %s denied, host is banned", client->ip);
		
		client->state = WD_CLIENT_STATE_DISCONNECTED;

		if(SSL_shutdown(client->ssl) == 0)
			SSL_shutdown(client->ssl);
	
		SSL_free(client->ssl);
		client->ssl = NULL;
	
		close(client->sd);
		client->sd = -1;
		
		return;
	}

	/* format time string */
	wd_time_to_iso8601(localtime(&wd_start_time), start_time, sizeof(start_time));
		
	/* reply a 200 */
	wd_reply(200, "%s%s%s%s%s%s%s%s%s",
			 wd_version_string,
			 WD_FIELD_SEPARATOR,
			 WD_PROTOCOL_VERSION,
			 WD_FIELD_SEPARATOR,
			 wd_settings.name,
			 WD_FIELD_SEPARATOR,
			 wd_settings.description,
			 WD_FIELD_SEPARATOR,
			 start_time);

	/* elevate state */
	client->state = WD_CLIENT_STATE_SAID_HELLO;
}



/*
	ICON <icon>
*/

void wd_cmd_icon(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	unsigned long		icon;
	
	/* convert argument */
	icon = strtoul(arg, NULL, 0);
	
	/* copy icon if changed */
	if(client->icon != icon) {
		client->icon = icon;

		/* broadcast a 304 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			pthread_mutex_lock(&(wd_chats.mutex));
			wd_broadcast(1, 304, "%lu%s%u%s%u%s%lu%s%s",
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 client->idle,
						 WD_FIELD_SEPARATOR,
						 client->admin,
						 WD_FIELD_SEPARATOR,
						 client->icon,
						 WD_FIELD_SEPARATOR,
						 client->nick);
			pthread_mutex_unlock(&(wd_chats.mutex));
			
			/* hotline subsystem */
			if(wd_settings.hotline) {
				wd_hl_relay_nick(client->uid, client->nick, client->icon,
								 client->idle, client->admin);
			}
		}
	}
}



/*
	INFO <uid>
*/

void wd_cmd_info(char *arg) {
	struct wd_client		*peer;
	struct wd_list_node		*node;
	struct wd_transfer		*transfer;
	char					logintime[26], idletime[26];
	char					info[1024], downloads[2048], uploads[2048];
	unsigned long			uid;
	int						length;

	/* convert user id */
	uid = strtoul(arg, NULL, 0);

	/* get the client */
	peer = wd_get_client(uid, 1);
	
	if(!peer) {
		/* hotline subsystem */
		if(wd_settings.hotline)
			wd_hl_info(uid);
		else
			wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* format time strings */
	wd_time_to_iso8601(localtime(&(peer->login_time)), logintime, sizeof(logintime));
	wd_time_to_iso8601(localtime(&(peer->idle_time)), idletime, sizeof(idletime));

	/* format the downloads/uploads strings */
	memset(downloads, 0, sizeof(downloads));
	memset(uploads, 0, sizeof(uploads));

	pthread_mutex_lock(&(wd_transfers.mutex));
	for(node = wd_transfers.first; node != NULL; node = node->next) {
		transfer = node->data;

		if(transfer->client == peer && transfer->state == WD_XFER_STATE_RUNNING) {
			switch(transfer->type) {
				case WD_XFER_DOWNLOAD:
					snprintf(info, sizeof(info), "%s%s%llu%s%llu%s%d%s",
							transfer->path,
							WD_RECORD_SEPARATOR,
							transfer->transferred,
							WD_RECORD_SEPARATOR,
							transfer->size,
							WD_RECORD_SEPARATOR,
							transfer->speed,
							WD_GROUP_SEPARATOR);
					strncat(downloads, info, sizeof(downloads));
					break;
				
				case WD_XFER_UPLOAD:
					snprintf(info, sizeof(info), "%s%s%llu%s%llu%s%d%s",
							transfer->path,
							WD_RECORD_SEPARATOR,
							transfer->transferred,
							WD_RECORD_SEPARATOR,
							transfer->size,
							WD_RECORD_SEPARATOR,
							transfer->speed,
							WD_GROUP_SEPARATOR);
					strncat(uploads, info, sizeof(uploads));
					break;
			}
		}
	}
	pthread_mutex_unlock(&(wd_transfers.mutex));
	
	/* chop off the last WD_GROUP_SEPARATOR */
	length = strlen(downloads);
	
	if(length > 0)
		downloads[length - 1] = '\0';

	length = strlen(uploads);
	
	if(length > 0)
		uploads[length - 1] = '\0';
		
	/* send message */
	wd_reply(308, "%lu%s%u%s%u%s%u%s%s%s%s%s%s%s%s%s%s%s%s%s%u%s%s%s%s%s%s%s%s",
			 peer->uid,
			 WD_FIELD_SEPARATOR,
			 peer->idle,
			 WD_FIELD_SEPARATOR,
			 peer->admin,
			 WD_FIELD_SEPARATOR,
			 peer->icon,
			 WD_FIELD_SEPARATOR,
			 peer->nick,
			 WD_FIELD_SEPARATOR,
			 peer->login,
			 WD_FIELD_SEPARATOR,
			 peer->ip,
			 WD_FIELD_SEPARATOR,
			 peer->host,
			 WD_FIELD_SEPARATOR,
			 peer->version,
			 WD_FIELD_SEPARATOR,
			 SSL_get_cipher_name(peer->ssl),
			 WD_FIELD_SEPARATOR,
			 SSL_get_cipher_bits(peer->ssl, NULL),
			 WD_FIELD_SEPARATOR,
			 logintime,
			 WD_FIELD_SEPARATOR,
			 idletime,
			 WD_FIELD_SEPARATOR,
			 downloads,
			 WD_FIELD_SEPARATOR,
			 uploads);
}



/*
	INVITE <uid> <cid>
*/

void wd_cmd_invite(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client	*peer;
	char				*ap, *uid = NULL, *cid = NULL;
	unsigned long		uid_l, cid_l;
	int					i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			uid = strdup(ap);
		else if(i == 1)
			cid = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!uid || !cid) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	
	/* convert arguments */
	uid_l = strtoul(uid, NULL, 0);
	cid_l = strtoul(cid, NULL, 0);
	
	/* get the client from the public chat */
	peer = wd_get_client(uid_l, 1);
	
	if(!peer) {
		/* hotline subsystem */
		if(wd_settings.hotline && hl_get_client(uid_l) != NULL)
			wd_reply(500, "Command Failed");
		else
			wd_reply(512, "Client Not Found");
		
		goto end;
	}
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid_l) == NULL)
		goto end;

	/* check if peer is not on chat */
	if(wd_get_client(peer->uid, cid_l) != NULL)
		goto end;

	/* now we can send the invite message */
	pthread_mutex_lock(&(peer->ssl_mutex));
	wd_sreply(peer->ssl, 331, "%lu%s%lu", cid_l, WD_FIELD_SEPARATOR, client->uid);
	pthread_mutex_unlock(&(peer->ssl_mutex));
	
end:
	/* clean up */
	if(uid)
		free(uid);
	
	if(cid)
		free(cid);
}



/*
	JOIN <cid>
*/

void wd_cmd_join(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_list_node		*chat_node;
	struct wd_chat			*chat;
	unsigned long			cid;
	int						found = 0;

	/* convert argument */
	cid = strtoul(arg, NULL, 0);

	/* no */
	if(cid == 1)
		return;
		
	/* add a copy of the record to the chat */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		if(chat->cid == cid) {
			wd_list_add(&(chat->clients), client);
			found = 1;
			
			break;
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
	if(!found)
		return;
	
	/* send join message */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(cid, 302, "%lu%s%lu%s%u%s%u%s%u%s%s%s%s%s%s%s%s",
				 cid,
				 WD_FIELD_SEPARATOR,
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
				 client->login,
				 WD_FIELD_SEPARATOR,
				 client->ip,
				 WD_FIELD_SEPARATOR,
				 client->host);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



/*
	KICK <uid> <reason>
*/

void wd_cmd_kick(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client		*peer;
	char					*ap, *uid = NULL, *message = NULL;
	unsigned long			uid_l;
	int						i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			uid = strdup(ap);
		else if(i == 1)
			message = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!uid || !message) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* convert user id */
	uid_l = strtoul(uid, NULL, 0);

	/* get user */
	peer = wd_get_client(uid_l, 1);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		goto end;
	}
	
	/* check priv */
	if(wd_getpriv(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		goto end;
	}
	
	/* broadcast a 306 */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 306, "%lu%s%d%s%s",
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 client->uid,
				 WD_FIELD_SEPARATOR,
				 message);
	pthread_mutex_unlock(&(wd_chats.mutex));
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s kicked %s/%s/%s",
			  client->nick,
			  client->login,
			  client->ip,
			  peer->nick,
			  peer->login,
			  peer->ip);

	/* disconnect */
	pthread_mutex_lock(&(peer->state_mutex));
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	pthread_mutex_unlock(&(peer->state_mutex));

end:
	/* clean up */
	if(uid)
		free(uid);
	
	if(message)
		free(message);
}



/*
	LEAVE <cid>
*/

void wd_cmd_leave(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client		*peer;
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	unsigned long			cid;

	/* convert argument */
	cid = strtoul(arg, NULL, 0);
	
	/* no */
	if(cid == 1)
		return;

	/* remove the client from this chat list */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		if(chat->cid == cid) {
			for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
				peer = client_node->data;
				
				if(peer->sd == client->sd) {
					wd_list_delete(&(chat->clients), client_node);
					
					break;
				}
			}

			break;
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));

	/* send a leave message */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(cid, 303, "%lu%s%lu", cid, WD_FIELD_SEPARATOR, client->uid);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



/*
	LIST <path>
*/

void wd_cmd_list(char *arg) {
	/* verify the path */
	if(wd_evaluate_path(arg) < 0) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}
	
	/* list the directory */
	wd_list_path(arg);
}



/*
	ME <id> <chat>
*/

void wd_cmd_me(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*ap, *cid = NULL, *chat = NULL;
	unsigned long		cid_l;
	int					i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			cid = strdup(ap);
		else if(i == 1)
			chat = strdup(ap);
		
		i++;
	}

	/* make sure we got them all */
	if(!cid || !chat) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* convert chat id */
	cid_l = strtoul(cid, NULL, 0);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid_l) == NULL)
		goto end;
	
	while((ap = strsep(&chat, "\n\r"))) {
		if(strlen(ap) > 0) {
			pthread_mutex_lock(&(wd_chats.mutex));
			wd_broadcast(cid_l, 301, "%lu%s%lu%s%s",
						 cid_l,
						 WD_FIELD_SEPARATOR,
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 ap);
			pthread_mutex_unlock(&(wd_chats.mutex));
			
			/* hotline subsystem */
			if(wd_settings.hotline && cid_l == 1)
				wd_hl_relay_me(client->nick, ap);
		}
	}

end:
	/* clean up */
	if(cid)
		free(cid);
	
	if(chat)
		free(chat);
}



/*
	MOVE <path> <path>
*/

void wd_cmd_move(char *arg) {
	char	*ap, *from = NULL, *to = NULL;
	int		i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			from = strdup(ap);
		else if(i == 1)
			to = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!from || !to) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}

	/* verify the paths */
	if(wd_evaluate_path(from) < 0 || wd_evaluate_path(to) < 0) {
		wd_reply(520, "File or Directory Not Found");

		goto end;
	}
	
	/* move the path */
	wd_move_path(from, to);

end:
	/* clean up */
	if(from)
		free(from);
	
	if(to)
		free(to);
}



/*
	MSG <uid> <message>
*/

void wd_cmd_msg(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_client	*peer;
	char				*ap, *uid = NULL, *msg = NULL;
	unsigned long		uid_l;
	int					i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			uid = strdup(ap);
		else if(i == 1)
			msg = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!uid || !msg) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}

	/* convert user id */
	uid_l = strtoul(uid, NULL, 0);

	/* get the client and send the message */
	peer = wd_get_client(uid_l, 1);
	
	if(peer) {
		pthread_mutex_lock(&(peer->ssl_mutex));
		wd_sreply(peer->ssl, 305, "%lu%s%s", client->uid, WD_FIELD_SEPARATOR, msg);
		pthread_mutex_unlock(&(peer->ssl_mutex));
	} else {
		/* hotline subsystem */
		if(wd_settings.hotline && hl_get_client(uid_l) != NULL)
			wd_reply(500, "Command Failed");
		else
			wd_reply(512, "Client Not Found");
	}

end:
	/* clean up */
	if(uid)
		free(uid);
	
	if(msg)
		free(msg);
}



/*
	NEWS
*/

void wd_cmd_news(char *arg) {
	/* send the news */
	wd_send_news();
}



/*
	NICK <nick>
*/

void wd_cmd_nick(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	
	/* copy nick if changed */
	if(strcmp(client->nick, arg) != 0) {
		strlcpy(client->nick, arg, sizeof(client->nick));

		/* broadcast a 304 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			pthread_mutex_lock(&(wd_chats.mutex));
			wd_broadcast(1, 304, "%lu%s%u%s%u%s%lu%s%s",
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 client->idle,
						 WD_FIELD_SEPARATOR,
						 client->admin,
						 WD_FIELD_SEPARATOR,
						 client->icon,
						 WD_FIELD_SEPARATOR,
						 client->nick);
			pthread_mutex_unlock(&(wd_chats.mutex));
			
			/* hotline subsystem */
			if(wd_settings.hotline) {
				wd_hl_relay_nick(client->uid, client->nick, client->icon,
								 client->idle, client->admin);
			}
		}
	}
}



/*
	PASS <password>
*/

void wd_cmd_pass(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	if(client->state != WD_CLIENT_STATE_GAVE_USER)
		return;

	/* attempt to login user */
	if(wd_check_login(client->login, arg) < 0) {
		/* failed */
		wd_log(LOG_INFO, "Login from %s/%s/%s failed",
			   client->nick,
			   client->login,
			   client->ip);
	
		/* reply failure */
		wd_reply(510, "Login Failed");
	} else {
		/* succeeded */
		wd_log(LOG_INFO, "Login from %s/%s/%s succeeded",
			   client->nick,
			   client->login,
			   client->ip);
		
		/* get admin flag */
		pthread_mutex_lock(&(client->admin_mutex));
		client->admin = wd_getpriv(client->login, WD_PRIV_KICK_USERS) |
						wd_getpriv(client->login, WD_PRIV_BAN_USERS);
		pthread_mutex_unlock(&(client->admin_mutex));
		
		/* announce user join on public chat */
		pthread_mutex_lock(&(wd_chats.mutex));
		wd_broadcast(1, 302, "1%s%lu%s%u%s%u%s%u%s%s%s%s%s%s", 
					 WD_FIELD_SEPARATOR,
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
					 client->login,
					 WD_FIELD_SEPARATOR,
					 client->ip,
					 WD_FIELD_SEPARATOR,
					 client->host);
		pthread_mutex_unlock(&(wd_chats.mutex));
		
		/* hotline subsystem */
		if(wd_settings.hotline) {
			wd_hl_relay_join(client->uid, client->nick, client->icon,
							 client->idle, client->admin);

		}
		
		/* elevate state */
		client->state = WD_CLIENT_STATE_LOGGED_IN;
		
		/* reply success */
		wd_reply(201, "%u", client->uid);

		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users++;
		wd_total_users++;
		pthread_mutex_unlock(&wd_status_mutex);
		wd_write_status();
	}
}



/*
	PING
*/

void wd_cmd_ping(char *arg) {
	/* reply ping */
	wd_reply(202, "Pong");
}



/*
	POST <message>
*/

void wd_cmd_post(char *arg) {
	/* post the news */
	wd_post_news(arg);
}



/*
	PRIVCHAT
*/

void wd_cmd_privchat(char *arg) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct wd_list_node		*chat_node;
	struct wd_chat			*chat;
	unsigned long			cid;
	int						loop = 1, found = 0;
	
	/* locate a new unique chat id */
	while(loop) {
		found = 0;
		cid = (unsigned long) random() % ULONG_MAX;
	
		pthread_mutex_lock(&(wd_chats.mutex));
		for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
			chat = chat_node->data;
			
			if(chat->cid == cid) {
				found = 1;
				
				break;
			}
		}
		pthread_mutex_unlock(&(wd_chats.mutex));
		
		if(!found)
			loop = 0;
	}

	/* create a new chat */
	chat = (struct wd_chat *) malloc(sizeof(struct wd_chat));
	chat->cid = cid;
	wd_list_create(&(chat->clients));
	
	/* add a copy of this client */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_list_add(&wd_chats, chat);
	wd_list_add(&(chat->clients), client);
	pthread_mutex_unlock(&(wd_chats.mutex));
		
	/* chat created notice */
	wd_reply(330, "%lu", cid);
}



/*
	PRIVILEGES
*/



void wd_cmd_privileges(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);

	/* send privileges information */
	wd_list_privileges(client);
}



/*
	PUT <path> <size> <checksum>
*/

void wd_cmd_put(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*ap, *path = NULL, *size = NULL, *checksum = NULL;
	char				*dir, real_path[MAXPATHLEN];
	off_t				size_l;
	int					i = 0;

	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			path = strdup(ap);
		else if(i == 1)
			size = strdup(ap);
		else if(i == 2)
			checksum = strdup(ap);
		
		i++;
	}
	
	/* make sure we got them all */
	if(!path || !size || !checksum) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}

	/* convert size */
	size_l = strtoul(size, NULL, 0);
	
	/* verify destination path */
	if(wd_evaluate_path(dirname(path)) < 0) {
		wd_reply(520, "File or Directory Not Found");
		
		goto end;
	}
	
	/* get the directory name */
	dir = dirname(path);
	
	if(!dir) {
		wd_reply(520, "File or Directory Not Found");
			
		return;
	}
	
	snprintf(real_path, sizeof(real_path), ".%s", dir);
	
	/* verify permissions */
	switch(wd_gettype(real_path, NULL)) {
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD) != 1) {
				wd_reply(516, "Permission Denied");
		
				goto end;
			}
			break;
		
		default:
			if(wd_getpriv(client->login, WD_PRIV_UPLOAD_ANYWHERE) != 1) {
				wd_reply(516, "Permission Denied");
		
				goto end;
			}
			break;
	}
	
	/* enter upload */
	wd_queue_upload(path, size_l, checksum);

end:
	/* clean up */
	if(path)
		free(path);

	if(size)
		free(size);

	if(checksum)
		free(checksum);
}



/*
	READGROUP <name>
*/

void wd_cmd_readgroup(char *arg) {
	char		*field, value[1024], out[1024];
	char		*group = NULL;
	int			i, length;

	/* check for account */
	group = wd_getgroup(arg);
	
	if(!group) {
		wd_reply(513, "Account Not Found");
		
		goto end;
	}
	
	memset(out, 0, sizeof(out));
	
	/* get all the fields of the account */
	for(i = 0; i < WD_GROUP_LAST; i++) {
		field = wd_getgroupfield(arg, i);
		
		/* append this value to the out string */
		snprintf(value, sizeof(value), "%s%s",
			field
				? field
				: "",
			WD_FIELD_SEPARATOR);
		strncat(out, value, strlen(value));
		
		if(field)
			free(field);
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	length = strlen(out);

	if(length > 0)
		out[length - 1] = '\0';
	
	/* send the account info */
	wd_reply(601, out);

end:
	/* clean up */
	if(group)
		free(group);
}



/*
	READUSER <name>
*/

void wd_cmd_readuser(char *arg) {
	char		*field, value[1024], out[1024];
	char		*user = NULL;
	int			i, length;

	/* check for account */
	user = wd_getuser(arg);
	
	if(!user) {
		wd_reply(513, "Account Not Found");
		
		goto end;
	}
	
	memset(out, 0, sizeof(out));
	
	/* get all the fields of the account */
	for(i = 0; i < WD_USER_LAST; i++) {
		field = wd_getuserfield(arg, i);
		
		/* append this value to the out string */
		snprintf(value, sizeof(value), "%s%s",
			field
				? field
				: "",
			WD_FIELD_SEPARATOR);
		strncat(out, value, strlen(value));
		
		if(field)
			free(field);
	}

	/* chop off the last WD_FIELD_SEPARATOR */
	length = strlen(out);

	if(length > 0)
		out[length - 1] = '\0';
	
	/* send the account info */
	wd_reply(600, out);

end:
	/* clean up */
	if(user)
		free(user);
}



/*
	SAY <id> <chat>
*/

void wd_cmd_say(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*ap, *cid = NULL, *chat = NULL;
	unsigned long		cid_l;
	int					i = 0;
	
	/* split the arguments */
	while((ap = strsep(&arg, WD_FIELD_SEPARATOR)) != NULL) {
		if(i == 0)
			cid = strdup(ap);
		else if(i == 1)
			chat = strdup(ap);
		
		i++;
	}

	/* make sure we got them all */
	if(!cid || !chat) {
		wd_reply(503, "Syntax Error");
		
		goto end;
	}
	
	/* convert chat id */
	cid_l = strtoul(cid, NULL, 0);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid_l) == NULL)
		goto end;
	
	/* split by newlines */
	arg = chat;
	
	while((ap = strsep(&arg, "\n\r"))) {
		if(strlen(ap) > 0) {
			pthread_mutex_lock(&(wd_chats.mutex));
			wd_broadcast(cid_l, 300, "%lu%s%lu%s%s",
						 cid_l,
						 WD_FIELD_SEPARATOR,
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 ap);
			pthread_mutex_unlock(&(wd_chats.mutex));
			
			/* hotline subsystem */
			if(wd_settings.hotline && cid_l == 1)
				wd_hl_relay_say(client->nick, ap);
		}
	}

end:
	/* clean up */
	if(cid)
		free(cid);
	
	if(chat)
		free(chat);
}



/*
	SEARCH <query>
*/

void wd_cmd_search(char *arg) {
	/* start search */
	wd_search(".", arg, true);
}



/*
	STAT <path>
*/

void wd_cmd_stat(char *arg) {
	/* verify the path */
	if(wd_evaluate_path(arg) < 0) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}

	/* request file information */
	wd_stat_path(arg);
}



/*
	USER <user>
*/

void wd_cmd_user(char *arg) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	
	if(client->state != WD_CLIENT_STATE_SAID_HELLO)
		return;

	/* copy login */
	strlcpy(client->login, arg, sizeof(client->login));

	/* set the username as nick if none else provided */
	if(strlen(client->nick) == 0)
		strlcpy(client->nick, client->login, sizeof(client->nick));

	/* elevate state */
	client->state = WD_CLIENT_STATE_GAVE_USER;
}



/*
	USERS
*/

void wd_cmd_users(char *arg) {
	/* list users */
	wd_list_users();
}



/*
	WHO
*/

void wd_cmd_who(char *arg) {
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	struct wd_client		*client;
	unsigned long			cid;

	/* convert argument */
	cid = strtoul(arg, NULL, 0);
	
	/* loop over all clients and reply 310 */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		if(chat->cid == cid) {
			for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
				client = client_node->data;
				
				if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
					wd_reply(310, "%lu%s%lu%s%u%s%u%s%u%s%s%s%s%s%s%s%s",
							cid,
							WD_FIELD_SEPARATOR,
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
							client->login,
							WD_FIELD_SEPARATOR,
							client->ip,
							WD_FIELD_SEPARATOR,
							client->host);
				}
			}
			
			break;
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
	/* hotline subsystem */
	if(wd_settings.hotline)
		wd_hl_who(cid);

	/* reply end marker */
	wd_reply(311, "%u", cid);
}
