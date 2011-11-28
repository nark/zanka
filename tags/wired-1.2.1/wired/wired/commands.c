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
#include "files.h"
#include "main.h"
#include "news.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


wd_commands_t		wd_commands[] = {
 { "BAN",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_BAN_USERS,				wd_cmd_ban },
 { "BANNER",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_NONE,					wd_cmd_banner },
 { "BROADCAST",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_BROADCAST,				wd_cmd_broadcast },
 { "CLEARNEWS",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_CLEAR_NEWS,				wd_cmd_clearnews },
 { "CLIENT",
   WD_CLIENT_STATE_SAID_HELLO,		0,					true,
   WD_PRIV_NONE,					wd_cmd_client },
 { "COMMENT",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_ALTER_FILES,				wd_cmd_comment },
 { "CREATEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		WD_GROUP_MIN,		true,
   WD_PRIV_CREATE_ACCOUNTS,			wd_cmd_creategroup },
 { "CREATEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		WD_USER_MIN,		true,
   WD_PRIV_CREATE_ACCOUNTS,			wd_cmd_createuser },
 { "DECLINE",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_decline },
 { "DELETE",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_DELETE_FILES,			wd_cmd_delete },
 { "DELETEGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_DELETE_ACCOUNTS,			wd_cmd_deletegroup },
 { "DELETEUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_DELETE_ACCOUNTS,			wd_cmd_deleteuser },
 { "EDITGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		WD_GROUP_MIN,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_editgroup },
 { "EDITUSER",
   WD_CLIENT_STATE_LOGGED_IN,		WD_USER_MIN,		true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_edituser },
 { "FOLDER",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_folder },
 { "GET",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_DOWNLOAD,				wd_cmd_get },
 { "GROUPS",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_groups },
 { "HELLO",
   WD_CLIENT_STATE_CONNECTED,		0,					true,
   WD_PRIV_NONE,					wd_cmd_hello },
 { "ICON",
   WD_CLIENT_STATE_SAID_HELLO,		1,					true,
   WD_PRIV_NONE,					wd_cmd_icon },
 { "INFO",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_GET_USER_INFO,			wd_cmd_info },
 { "INVITE",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_NONE,					wd_cmd_invite },
 { "JOIN",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_join },
 { "KICK",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_KICK_USERS,				wd_cmd_kick },
 { "LEAVE",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_leave },
 { "LIST",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_list },
 { "ME",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_me },
 { "MOVE",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_ALTER_FILES,				wd_cmd_move },
 { "MSG",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_NONE,					wd_cmd_msg },
 { "NEWS",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_NONE,					wd_cmd_news },
 { "NICK",
   WD_CLIENT_STATE_SAID_HELLO,		1,					true,
   WD_PRIV_NONE,					wd_cmd_nick },
 { "PASS",
   WD_CLIENT_STATE_GAVE_USER,		1,					true,
   WD_PRIV_NONE,					wd_cmd_pass },
 { "PING",
   WD_CLIENT_STATE_CONNECTED,		0,					false,
   WD_PRIV_NONE,					wd_cmd_ping },
 { "POST",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_POST_NEWS,				wd_cmd_post },
 { "PRIVCHAT",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_NONE,					wd_cmd_privchat },
 { "PRIVILEGES",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_NONE,					wd_cmd_privileges },
 { "PUT",
   WD_CLIENT_STATE_LOGGED_IN,		3,					true,
   WD_PRIV_NONE,					wd_cmd_put },
 { "READGROUP",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_readgroup },
 { "READUSER",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_readuser },
 { "SAY",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_say },
 { "SEARCH",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_search },
 { "STAT",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_stat },
 { "STATUS",
   WD_CLIENT_STATE_SAID_HELLO,		1,					true,
   WD_PRIV_NONE,					wd_cmd_status },
 { "TOPIC",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_topic },
 { "TYPE",
   WD_CLIENT_STATE_LOGGED_IN,		2,					true,
   WD_PRIV_ALTER_FILES,				wd_cmd_type },
 { "USER",
   WD_CLIENT_STATE_SAID_HELLO,		1,					true,
   WD_PRIV_NONE,					wd_cmd_user },
 { "USERS",
   WD_CLIENT_STATE_LOGGED_IN,		0,					true,
   WD_PRIV_EDIT_ACCOUNTS,			wd_cmd_users },
 { "WHO",
   WD_CLIENT_STATE_LOGGED_IN,		1,					true,
   WD_PRIV_NONE,					wd_cmd_who },
};


void * wd_ctl_thread(void *arg) {
	wd_client_t			*client = (wd_client_t *) arg;
	struct timeval		tv;
	fd_set				rfds;
	int					bytes = 0, pending, state;

	/* associate the struct with this thread */
	pthread_setspecific(wd_client_key, client);

	/* go client */
	while(client->state <= WD_CLIENT_STATE_LOGGED_IN) {
		if(client->buffer_offset == 0) {
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
		}
		
		/* read from SSL */
		pthread_mutex_lock(&(client->ssl_mutex));
		bytes = SSL_read(client->ssl,
						 client->buffer + client->buffer_offset,
						 client->buffer_size - client->buffer_offset);
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
		
		if(client->buffer[client->buffer_offset + bytes - 1] != WD_MESSAGE_SEPARATOR) {
			/* increase buffer by SSL_pending() bytes or, if we've reached 
			   the 16k limit in SSL/TLS, by initial buffer size */
			pending = SSL_pending(client->ssl);
			
			if(pending == 0)
				pending = WD_BUFFER_SIZE;
			
			/* increase buffer size and set new offset */
			client->buffer_size += pending;
			client->buffer = realloc(client->buffer, client->buffer_size);
			client->buffer_offset += bytes;
		} else {
			/* chomp separator */
			client->buffer[client->buffer_offset + bytes - 1] = '\0';
			
			/* parse buffer */
			wd_parse_command(client->buffer);
			
			/* reset offset */
			client->buffer_offset = 0;
		}
	}
	
	/* announce parting if client disconnected by itself */
	if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
		WD_LIST_LOCK(wd_chats);
		wd_broadcast(WD_PUBLIC_CHAT, 303, "%u%c%u",
					 WD_PUBLIC_CHAT,
					 WD_FIELD_SEPARATOR,
					 client->uid);
		WD_LIST_UNLOCK(wd_chats);
	}
	
	/* update status for clients logged in and above */
	if(client->state >= WD_CLIENT_STATE_LOGGED_IN) {
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users--;
		wd_write_status();
		pthread_mutex_unlock(&wd_status_mutex);
	}
	
	/* log */
	wd_log(LOG_INFO, "Disconnect from %s", client->ip);

	/* now delete client */
	wd_delete_client(client);

	return NULL;
}



#pragma mark -

void wd_parse_command(char *buffer) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			*start, *command = NULL, *arg = NULL;
	char			**argv = NULL;
	int				index, argc = 0;
	
	/* loop over the command */
	start = buffer;

	while(*buffer && !isspace(*buffer))
		buffer++;
	
	/* get command */
	command = (char *) malloc(buffer - start + 1);
	memcpy(command, start, buffer - start);
	command[buffer - start] = '\0';

	/* verify command */
	index = wd_command_index(command);
	
	if(index < 0) {
		wd_reply(501, "Command Not Recognized");
		
		goto end;
	}
	
	/* loop over argument string */
	start = buffer;
	
	while(*buffer)
		buffer++;

	if(isspace(*start)) {
		/* get argument */
		arg = (char *) malloc(buffer - start + 2);
		memcpy(arg, start + 1, buffer - start);
		arg[buffer - start + 1] = '\0';
	
		/* get argument vector */
		wd_argv_create_wired(arg, &argc, &argv);
	}

	/* verify state */
	if(client->state < wd_commands[index].state)
		goto end;

	/* verify arg */
	if(argc < wd_commands[index].args) {
		wd_reply(503, "Syntax Error");
	
		goto end;
	}
	
	/* verify permission */
	if(wd_get_priv_int(client->login, wd_commands[index].permission) != 1) {
		wd_reply(516, "Permission Denied");
	
		goto end;
	}
	
	/* update the idle time */
	if(wd_commands[index].activate) {
		client->idle_time = time(NULL);

		if(client->idle) {
			client->idle = 0;

			/* broadcast a user change */
			WD_LIST_LOCK(wd_chats);
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
			WD_LIST_UNLOCK(wd_chats);
		}
	}
	
	/* go server command */
	((*wd_commands[index].action) (argc, argv));

end:
	/* clean up */
	if(command)
		free(command);
	
	if(arg)
		free(arg);
	
	if(argc > 0)
		wd_argv_free(argc, argv);
}



int wd_command_index(char *command) {
	int		min, max, index, cmp;
	
	min = 0;
	max = ARRAY_SIZE(wd_commands) - 1;
	
	do {
		index = (min + max) / 2;
		cmp = strcasecmp(command, wd_commands[index].name);
		
		if(cmp == 0)
			return index;
		else if(cmp < 0)
			max = index - 1;
		else
			min = index + 1;
	} while(min <= max);
	
	return -1;
}



#pragma mark -

/*
	BAN <uid> <reason>
*/

void wd_cmd_ban(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_client_t		*peer;
	wd_tempban_t	*tempban;

	/* get user */
	peer = wd_get_client(strtoul(argv[0], NULL, 10), WD_PUBLIC_CHAT);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}

	/* check priv */
	if(wd_get_priv_int(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		return;
	}
	
	/* broadcast a 307 */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(WD_PUBLIC_CHAT, 307, "%u%c%u%c%s",
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 client->uid,
				 WD_FIELD_SEPARATOR,
				 argv[1]);
	WD_LIST_UNLOCK(wd_chats);
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s banned %s/%s/%s",
			  client->nick, client->login, client->ip,
			  peer->nick, peer->login, peer->ip);

	/* create a temporary ban */
	tempban = (wd_tempban_t *) malloc(sizeof(wd_tempban_t));
	memset(tempban, 0, sizeof(tempban));
	
	/* set values */
	strlcpy(tempban->ip, peer->ip, sizeof(tempban->ip));
	tempban->time = time(NULL);
	
	/* add to list */
	WD_LIST_LOCK(wd_tempbans);
	wd_list_add(&wd_tempbans, (void *) tempban);
	WD_LIST_UNLOCK(wd_tempbans);

	/* disconnect */
	pthread_mutex_lock(&(peer->flag_mutex));
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	pthread_mutex_unlock(&(peer->flag_mutex));
}



/*
	BANNER
*/

void wd_cmd_banner(int argc, char **argv) {
	/* return the banner */
	wd_reply(203, "%s", wd_banner);
}




/*
	BROADCAST <message>
*/

void wd_cmd_broadcast(int argc, char **argv) {
	wd_client_t	*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* broadcast message */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(WD_PUBLIC_CHAT, 309, "%u%c%s",
				 client->uid,
				 WD_FIELD_SEPARATOR,
				 argv[0]);
	WD_LIST_UNLOCK(wd_chats);
}



/*
	CLEARNEWS
*/

void wd_cmd_clearnews(int argc, char **argv) {
	/* clear the news */
	wd_clear_news();
}



/*
	CLIENT <application-version>
*/

void wd_cmd_client(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* copy version string */
	strlcpy(client->version, argv[0], sizeof(client->version));
}



/*
	COMMENT <path> <comment>
*/

void wd_cmd_comment(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	
	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");

		return;
	}
	
	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}

	/* comment the path */
	wd_set_comment(argv[0], argv[1]);
}



/*
	CREATEGROUP <...>
*/

void wd_cmd_creategroup(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* create the group */
	if(wd_create_group(argc, argv) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s created the group \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[WD_GROUP_NAME]);
	}
}



/*
	CREATEUSER <...>
*/

void wd_cmd_createuser(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* create the user */
	if(wd_create_user(argc, argv) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s created the user \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[WD_USER_NAME]);
	}
}



/*
	DECLINE <cid>
*/

void wd_cmd_decline(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_cid_t		cid;
	
	/* convert argument */
	cid = strtoul(argv[0], NULL, 10);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid) != NULL)
		return;

	/* send declined message */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(cid, 332, "%u%c%u",
				 cid,
				 WD_FIELD_SEPARATOR,
				 client->uid);
	WD_LIST_UNLOCK(wd_chats);
}



/*
	DELETE <path>
*/

void wd_cmd_delete(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");

		return;
	}
	
	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}

	/* delete tree attached to path */
	if(wd_delete_path(argv[0]) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted \"%s\"",
			      client->nick, client->login, client->ip,
			      argv[0]);
	}
}



/*
	DELETEGROUP <name>
*/

void wd_cmd_deletegroup(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* delete the group */
	if(wd_delete_group(argv[0]) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted the group \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[0]);
	}
}



/*
	DELETEUSER <name>
*/

void wd_cmd_deleteuser(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* delete the user */
	if(wd_delete_user(argv[0]) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s deleted the user \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[0]);
	}
}



/*
	EDITGROUP <...>
*/

void wd_cmd_editgroup(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* edit the group */
	if(wd_edit_group(argc, argv) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s modified the group \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[WD_GROUP_NAME]);
		
		/* reload clients */
		wd_reload_privileges(NULL, argv[WD_GROUP_NAME]);
	}
}



/*
	EDITUSER <...>
*/

void wd_cmd_edituser(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	
	/* edit the user */
	if(wd_edit_user(argc, argv) > 0) {
		/* log */
		wd_log_ll(LOG_INFO, "%s/%s/%s modified the user \"%s\"",
				  client->nick, client->login, client->ip,
				  argv[WD_USER_NAME]);
		
		/* reload clients */
		wd_reload_privileges(argv[WD_USER_NAME], NULL);
	}
}



/*
	FOLDER <path>
*/

void wd_cmd_folder(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			real_path[MAXPATHLEN];
	
	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");
			
		return;
	}

	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}

	/* get real path */
	snprintf(real_path, sizeof(real_path), ".%s", wd_dirname(argv[0]));
	
	/* verify permissions */
	switch(wd_get_type(real_path, NULL)) {
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
		
		default:
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD_ANYWHERE) != 1 &&
			   wd_get_priv_int(client->login, WD_PRIV_CREATE_FOLDERS) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
	}

	/* create the directory */
	wd_create_path(argv[0]);
}



/*
	GET <path> <offset>
*/

void wd_cmd_get(int argc, char **argv) {
	wd_client_t			*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	unsigned long long	offset;

	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}

	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}
	
	/* verify queue limit */
	if(wd_count_transfers(WD_TRANSFER_DOWNLOAD) >= wd_settings.clientdownloads) {
		wd_reply(523, "Queue Limit Exceeded");
		
		return;
	}
	
	/* convert offset */
	offset = strtoull(argv[1], NULL, 10);
	
	/* get the file */
	wd_queue_download(argv[0], offset);
}



/*
	GROUPS
*/

void wd_cmd_groups(int argc, char **argv) {
	/* list groups */
	wd_list_groups();
}



/*
	HELLO
*/

void wd_cmd_hello(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			start_time[WD_DATETIME_SIZE];
	
	/* check state */
	if(client->state != WD_CLIENT_STATE_CONNECTED)
		return;
	
	/* check ban */
	if(wd_ip_is_banned(client->ip)) {
		wd_reply(511, "Banned");
		wd_log(LOG_INFO, "Connection from %s denied, host is banned", client->ip);
		
		client->state = WD_CLIENT_STATE_DISCONNECTED;
		
		return;
	}

	/* format time string */
	wd_time_to_iso8601(wd_start_time, start_time, sizeof(start_time));
		
	/* reply a 200 */
	wd_reply(200, "%s%c%s%c%s%c%s%c%s%c%u%c%llu",
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

	/* elevate state */
	client->state = WD_CLIENT_STATE_SAID_HELLO;
}



/*
	ICON <icon> <image>
*/

void wd_cmd_icon(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_icon_t		icon;

	/* convert argument */
	icon = strtoul(argv[0], NULL, 10);
	
	/* copy icon if changed */
	if(client->icon != icon) {
		client->icon = icon;
		
		/* broadcast a 304 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			WD_LIST_LOCK(wd_chats);
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
			WD_LIST_UNLOCK(wd_chats);
		}
	}
	
	/* copy custom icon if changed */
	if(argc > 1 && strcmp(argv[1], client->image) != 0) {
		strlcpy(client->image, argv[1], sizeof(client->image));

		/* broadcast a 340 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			WD_LIST_LOCK(wd_chats);
			wd_broadcast(WD_PUBLIC_CHAT, 340, "%u%c%s",
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 client->image);
			WD_LIST_UNLOCK(wd_chats);
		}
	}
}



/*
	INFO <uid>
*/

void wd_cmd_info(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_client_t		*peer;
	wd_list_node_t	*node;
	wd_transfer_t	*transfer;
	char			*p, logintime[WD_DATETIME_SIZE], idletime[WD_DATETIME_SIZE];
	char			info[1024], downloads[2048], uploads[2048];
	bool			dropbox;
	wd_uid_t		uid;

	/* convert user id */
	uid = strtoul(argv[0], NULL, 10);

	/* get the client */
	peer = wd_get_client(uid, WD_PUBLIC_CHAT);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}

	/* get drop box privs */
	dropbox = wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES);
	
	/* format time strings */
	wd_time_to_iso8601(peer->login_time, logintime, sizeof(logintime));
	wd_time_to_iso8601(peer->idle_time, idletime, sizeof(idletime));

	/* format the downloads/uploads strings */
	memset(downloads, 0, sizeof(downloads));
	memset(uploads, 0, sizeof(uploads));

	WD_LIST_LOCK(wd_transfers);
	WD_LIST_FOREACH(wd_transfers, node, transfer) {
		if(transfer->client == peer && transfer->state == WD_TRANSFER_STATE_RUNNING) {
			/* hide transfers from inside drop boxes */
			if(!dropbox) {
				if(wd_path_is_dropbox(transfer->path))
					continue;
			}
			
			/* create info record */
			snprintf(info, sizeof(info), "%s%c%llu%c%llu%c%u%c",
					 transfer->path,
					 WD_RECORD_SEPARATOR,
					 transfer->transferred,
					 WD_RECORD_SEPARATOR,
					 transfer->size,
					 WD_RECORD_SEPARATOR,
					 transfer->speed,
					 WD_GROUP_SEPARATOR);
			
			/* append */
			if(transfer->type == WD_TRANSFER_DOWNLOAD)
				strncat(downloads, info, sizeof(downloads));
			else
				strncat(uploads, info, sizeof(uploads));
		}
	}
	WD_LIST_UNLOCK(wd_transfers);
	
	/* chop off the last WD_GROUP_SEPARATOR */
	if((p = strrchr(downloads, WD_GROUP_SEPARATOR)))
		*p = '\0';

	if((p = strrchr(uploads, WD_GROUP_SEPARATOR)))
		*p = '\0';
	
	/* send message */
	wd_reply(308, "%u%c%u%c%u%c%u%c%s%c%s%c%s%c%s%c%s%c%s%c%u%c%s%c%s%c%s%c%s%c%s%c%s",
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
			 uploads,
			 WD_FIELD_SEPARATOR,
			 peer->status,
			 WD_FIELD_SEPARATOR,
			 peer->image);
}



/*
	INVITE <uid> <cid>
*/

void wd_cmd_invite(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_client_t		*peer;
	wd_uid_t		uid;
	wd_cid_t		cid;

	/* convert arguments */
	uid = strtoul(argv[0], NULL, 10);
	cid = strtoul(argv[1], NULL, 10);
	
	/* get the client from the public chat */
	peer = wd_get_client(uid, WD_PUBLIC_CHAT);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* check if client is on the chat */
	if(wd_get_client(client->uid, cid) == NULL)
		return;

	/* check if peer is not on the chat */
	if(wd_get_client(peer->uid, cid) != NULL)
		return;

	/* now we can send the invite message */
	pthread_mutex_lock(&(peer->ssl_mutex));
	wd_sreply(peer->ssl, 331, "%u%c%u", cid, WD_FIELD_SEPARATOR, client->uid);
	pthread_mutex_unlock(&(peer->ssl_mutex));
}



/*
	JOIN <cid>
*/

void wd_cmd_join(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_chat_t		*chat;
	wd_cid_t		cid;

	/* convert argument */
	cid = strtoul(argv[0], NULL, 10);

	/* check if client is on the chat already */
	if(wd_get_client(client->uid, cid) != NULL)
		return;
	
	/* check if the chat exists */
	chat = wd_get_chat(cid);

	if(!chat)
		return;
	
	/* send join message */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(cid, 302, "%u%c%u%c%u%c%u%c%u%c%s%c%s%c%s%c%s%c%s%c%s",
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
				 client->host,
				 WD_FIELD_SEPARATOR,
				 client->status,
				 WD_FIELD_SEPARATOR,
				 client->image);
	WD_LIST_UNLOCK(wd_chats);

	/* add the client to the chat */
	WD_LIST_LOCK(wd_chats);
	wd_list_add(&(chat->clients), client);
	WD_LIST_UNLOCK(wd_chats);

	/* reply topic */
	if(strlen(chat->topic.topic) > 0) {
		wd_reply(341, "%u%c%s%c%s%c%s%c%s%c%s",
				 WD_PUBLIC_CHAT,
				 WD_FIELD_SEPARATOR,
				 chat->topic.nick,
				 WD_FIELD_SEPARATOR,
				 chat->topic.login,
				 WD_FIELD_SEPARATOR,
				 chat->topic.ip,
				 WD_FIELD_SEPARATOR,
				 chat->topic.time,
				 WD_FIELD_SEPARATOR,
				 chat->topic.topic);
	}
}



/*
	KICK <uid> <reason>
*/

void wd_cmd_kick(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_client_t		*peer;
	wd_uid_t		uid;

	/* convert user id */
	uid = strtoul(argv[0], NULL, 10);

	/* get user */
	peer = wd_get_client(uid, WD_PUBLIC_CHAT);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* check priv */
	if(wd_get_priv_int(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		return;
	}
	
	/* broadcast a 306 */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(WD_PUBLIC_CHAT, 306, "%u%c%u%c%s",
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 client->uid,
				 WD_FIELD_SEPARATOR,
				 argv[1]);
	WD_LIST_UNLOCK(wd_chats);
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s kicked %s/%s/%s",
			  client->nick, client->login, client->ip,
			  peer->nick, peer->login, peer->ip);

	/* disconnect */
	pthread_mutex_lock(&(peer->flag_mutex));
	peer->state = WD_CLIENT_STATE_DISCONNECTED;
	pthread_mutex_unlock(&(peer->flag_mutex));
}



/*
	LEAVE <cid>
*/

void wd_cmd_leave(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_list_node_t	*node;
	wd_client_t		*peer;
	wd_chat_t		*chat;
	wd_cid_t		cid;

	/* convert argument */
	cid = strtoul(argv[0], NULL, 10);
	
	/* no */
	if(cid == WD_PUBLIC_CHAT)
		return;
	
	/* get chat */
	chat = wd_get_chat(cid);
	
	if(!chat)
		return;
		
	/* loop over all clients and remove this one */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(chat->clients, node, peer) {
		if(peer->sd == client->sd) {
			WD_LIST_DATA(node) = NULL;
			wd_list_delete(&(chat->clients), node);
			
			break;
		}
	}
	WD_LIST_UNLOCK(wd_chats);

	/* send a leave message */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(cid, 303, "%u%c%u",
				 cid,
				 WD_FIELD_SEPARATOR,
				 client->uid);
	WD_LIST_UNLOCK(wd_chats);
}



/*
	LIST <path>
*/

void wd_cmd_list(int argc, char **argv) {
	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}
	
	/* list the directory */
	wd_list_path(argv[0]);
}



/*
	ME <cid> <chat>
*/

void wd_cmd_me(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			*ap, *chat;
	wd_cid_t		cid;

	/* convert chat id */
	cid = strtoul(argv[0], NULL, 10);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid) == NULL)
		return;
	
	/* split over newlines */
	chat = argv[1];
	
	while((ap = strsep(&chat, "\n\r"))) {
		if(strlen(ap) > 0) {
			WD_LIST_LOCK(wd_chats);
			wd_broadcast(cid, 301, "%u%c%u%c%s",
						 cid,
						 WD_FIELD_SEPARATOR,
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 ap);
			WD_LIST_UNLOCK(wd_chats);
		}
	}
}



/*
	MOVE <path> <path>
*/

void wd_cmd_move(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* verify the paths */
	if(!wd_path_is_valid(argv[0]) || !wd_path_is_valid(argv[1])) {
		wd_reply(520, "File or Directory Not Found");

		return;
	}

	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}
	
	/* move the path */
	wd_move_path(argv[0], argv[1]);
}



/*
	MSG <uid> <message>
*/

void wd_cmd_msg(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_client_t		*peer;
	wd_uid_t		uid;

	/* convert user id */
	uid = strtoul(argv[0], NULL, 10);

	/* get client */
	peer = wd_get_client(uid, WD_PUBLIC_CHAT);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* send message */
	pthread_mutex_lock(&(peer->ssl_mutex));
	wd_sreply(peer->ssl, 305, "%u%c%s", client->uid, WD_FIELD_SEPARATOR, argv[1]);
	pthread_mutex_unlock(&(peer->ssl_mutex));
}



/*
	NEWS
*/

void wd_cmd_news(int argc, char **argv) {
	/* send the news */
	wd_send_news();
}



/*
	NICK <nick>
*/

void wd_cmd_nick(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	
	if(client->state < WD_CLIENT_STATE_SAID_HELLO)
		return;

	/* copy nick if changed */
	if(strcmp(client->nick, argv[0]) != 0) {
		strlcpy(client->nick, argv[0], sizeof(client->nick));

		/* broadcast a 304 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			WD_LIST_LOCK(wd_chats);
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
			WD_LIST_UNLOCK(wd_chats);
		}
	}
}



/*
	PASS <password>
*/

void wd_cmd_pass(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_chat_t		*chat;

	if(client->state != WD_CLIENT_STATE_GAVE_USER)
		return;

	/* attempt to login user */
	if(wd_check_login(client->login, argv[0]) < 0) {
		/* failed */
		wd_log(LOG_INFO, "Login from %s/%s/%s failed",
			   client->nick, client->login, client->ip);
	
		/* reply failure */
		wd_reply(510, "Login Failed");
	} else {
		/* succeeded */
		wd_log(LOG_INFO, "Login from %s/%s/%s succeeded",
			   client->nick, client->login, client->ip);
		
		/* get admin flag */
		pthread_mutex_lock(&(client->flag_mutex));
		client->admin = wd_get_priv_int(client->login, WD_PRIV_KICK_USERS) |
						wd_get_priv_int(client->login, WD_PRIV_BAN_USERS);
		pthread_mutex_unlock(&(client->flag_mutex));
		
		/* announce user join on public chat */
		WD_LIST_LOCK(wd_chats);
		wd_broadcast(WD_PUBLIC_CHAT, 302, "%u%c%u%c%u%c%u%c%u%c%s%c%s%c%s%c%s%c%s%c%s",
					 WD_PUBLIC_CHAT,
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
					 client->host,
					 WD_FIELD_SEPARATOR,
					 client->status,
					 WD_FIELD_SEPARATOR,
					 client->image);
		WD_LIST_UNLOCK(wd_chats);
		
		/* elevate state */
		client->state = WD_CLIENT_STATE_LOGGED_IN;
		
		/* reply success */
		wd_reply(201, "%u", client->uid);
		
		/* get chat */
		chat = wd_get_chat(WD_PUBLIC_CHAT);
		
		/* reply topic */
		if(strlen(chat->topic.topic) > 0) {
			wd_reply(341, "%u%c%s%c%s%c%s%c%s%c%s",
					 WD_PUBLIC_CHAT,
					 WD_FIELD_SEPARATOR,
					 chat->topic.nick,
					 WD_FIELD_SEPARATOR,
					 chat->topic.login,
					 WD_FIELD_SEPARATOR,
					 chat->topic.ip,
					 WD_FIELD_SEPARATOR,
					 chat->topic.time,
					 WD_FIELD_SEPARATOR,
					 chat->topic.topic);
		}

		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users++;
		wd_total_users++;
		wd_write_status();
		pthread_mutex_unlock(&wd_status_mutex);
	}
}



/*
	PING
*/

void wd_cmd_ping(int argc, char **argv) {
	/* reply ping */
	wd_reply(202, "Pong");
}



/*
	POST <message>
*/

void wd_cmd_post(int argc, char **argv) {
	/* post the news */
	wd_post_news(argv[0]);
}



/*
	PRIVCHAT
*/

void wd_cmd_privchat(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_list_node_t	*node;
	wd_chat_t		*chat;
	wd_cid_t		cid;
	bool			found;
	
	/* loop over chats and locate a new unique chat id */
	WD_LIST_LOCK(wd_chats);
	do {
		cid = (wd_cid_t) random() % ULONG_MAX;
		found = true;
		
		WD_LIST_FOREACH(wd_chats, node, chat) {
			if(chat->cid == cid) {
				found = false;
				
				break;
			}
		}
	} while(!found);
	WD_LIST_UNLOCK(wd_chats);

	/* create a new chat */
	chat = (wd_chat_t *) malloc(sizeof(wd_chat_t));
	memset(chat, 0, sizeof(wd_chat_t));
	
	/* init chat */
	chat->cid = cid;
	wd_list_create(&(chat->clients));
	
	/* add a copy of this client */
	WD_LIST_LOCK(wd_chats);
	wd_list_add(&wd_chats, chat);
	wd_list_add(&(chat->clients), client);
	WD_LIST_UNLOCK(wd_chats);
		
	/* chat created notice */
	wd_reply(330, "%u", cid);
}



/*
	PRIVILEGES
*/



void wd_cmd_privileges(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* send privileges information */
	wd_send_privileges(client);
}



/*
	PUT <path> <size> <checksum>
*/

void wd_cmd_put(int argc, char **argv) {
	wd_client_t			*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	struct stat			sb;
	char				dir[MAXPATHLEN], real_path[MAXPATHLEN];
	unsigned long long	size;

	/* get the directory name */
	strlcpy(dir, wd_dirname(argv[0]), sizeof(dir));
	
	/* convert size */
	size = strtoull(argv[1], NULL, 10);
	
	/* verify destination path */
	if(!wd_path_is_valid(dir)) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}

	/* verify file doesn't already exist */
	snprintf(real_path, sizeof(real_path), ".%s", argv[0]);

	if(stat(real_path, &sb) == 0) {
		wd_reply(521, "File or Directory Exists");

		return;
	}
	
	/* verify permissions on directory */
	snprintf(real_path, sizeof(real_path), ".%s", dir);
	
	switch(wd_get_type(real_path, NULL)) {
		case WD_FILE_TYPE_UPLOADS:
		case WD_FILE_TYPE_DROPBOX:
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
		
		default:
			if(wd_get_priv_int(client->login, WD_PRIV_UPLOAD_ANYWHERE) != 1) {
				wd_reply(516, "Permission Denied");
		
				return;
			}
			break;
	}
	
	/* verify queue limit */
	if(wd_count_transfers(WD_TRANSFER_UPLOAD) >= wd_settings.clientuploads) {
		wd_reply(523, "Queue Limit Exceeded");
		
		return;
	}
	
	/* enter upload */
	wd_queue_upload(argv[0], size, argv[2]);
}



/*
	READGROUP <name>
*/

void wd_cmd_readgroup(int argc, char **argv) {
	/* read group */
	wd_read_group(argv[0]);
}



/*
	READUSER <name>
*/

void wd_cmd_readuser(int argc, char **argv) {
	/* read user */
	wd_read_user(argv[0]);
}



/*
	SAY <id> <chat>
*/

void wd_cmd_say(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			*ap, *chat;
	wd_cid_t		cid;
	
	/* convert chat id */
	cid = strtoul(argv[0], NULL, 10);
	
	/* check if client is on chat */
	if(wd_get_client(client->uid, cid) == NULL)
		return;
	
	/* split by newlines */
	chat = argv[1];
	
	while((ap = strsep(&chat, "\n\r"))) {
		if(strlen(ap) > 0) {
			WD_LIST_LOCK(wd_chats);
			wd_broadcast(cid, 300, "%u%c%u%c%s",
						 cid,
						 WD_FIELD_SEPARATOR,
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 ap);
			WD_LIST_UNLOCK(wd_chats);
		}
	}
}



/*
	SEARCH <query>
*/

void wd_cmd_search(int argc, char **argv) {
	/* start search */
	wd_search_files(argv[0]);
}



/*
	STAT <path>
*/

void wd_cmd_stat(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");
		
		return;
	}

	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}

	/* request file information */
	wd_stat_path(argv[0]);
}



/*
	STATUS <status>
*/

void wd_cmd_status(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	
	if(client->state < WD_CLIENT_STATE_SAID_HELLO)
		return;

	/* copy status if changed */
	if(strcmp(client->status, argv[0]) != 0) {
		strlcpy(client->status, argv[0], sizeof(client->status));

		/* broadcast a 304 if the client is logged in */
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			WD_LIST_LOCK(wd_chats);
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
			WD_LIST_UNLOCK(wd_chats);
		}
	}
}



/*
	TOPIC <cid> <topic>
*/

void wd_cmd_topic(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	wd_chat_t		*chat;
	wd_cid_t		cid;
	time_t			now;

	/* convert argument */
	cid = strtoul(argv[0], NULL, 10);
	
	if(cid == WD_PUBLIC_CHAT) {
		if(wd_get_priv_int(client->login, WD_PRIV_TOPIC) != 1) {
			wd_reply(516, "Permission Denied");
			
			return;
		}
	} else {
		if(wd_get_client(client->uid, cid) == NULL)
			return;
	}
	
	/* get chat */
	chat = wd_get_chat(cid);
	
	if(!chat)
		return;
	
	/* get time */
	now = time(NULL);
	
	/* set new values */
	strlcpy(chat->topic.topic, argv[1], sizeof(chat->topic.topic));
	wd_time_to_iso8601(now, chat->topic.time, sizeof(chat->topic.time));
	strlcpy(chat->topic.nick, client->nick, sizeof(chat->topic.nick));
	strlcpy(chat->topic.login, client->login, sizeof(chat->topic.login));
	strlcpy(chat->topic.ip, client->ip, sizeof(chat->topic.ip));
	
	/* broadcast new topic */
	WD_LIST_LOCK(wd_chats);
	wd_broadcast(cid, 341, "%u%c%s%c%s%c%s%c%s%c%s",
				 cid,
				 WD_FIELD_SEPARATOR,
				 chat->topic.nick,
				 WD_FIELD_SEPARATOR,
				 chat->topic.login,
				 WD_FIELD_SEPARATOR,
				 chat->topic.ip,
				 WD_FIELD_SEPARATOR,
				 chat->topic.time,
				 WD_FIELD_SEPARATOR,
				 chat->topic.topic);
	WD_LIST_UNLOCK(wd_chats);
}



/*
	TYPE <path> <type>
*/

void wd_cmd_type(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);

	/* verify the path */
	if(!wd_path_is_valid(argv[0])) {
		wd_reply(520, "File or Directory Not Found");

		return;
	}
	
	/* verify drop box */
	if(wd_get_priv_int(client->login, WD_PRIV_VIEW_DROPBOXES) != 1) {
		if(wd_path_is_dropbox(argv[0])) {
			wd_reply(520, "File or Directory Not Found");
	
			return;
		}
	}

	/* comment the path */
	wd_set_type(argv[0], strtoul(argv[1], NULL, 10));
}



/*
	USER <user>
*/

void wd_cmd_user(int argc, char **argv) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	
	if(client->state != WD_CLIENT_STATE_SAID_HELLO)
		return;

	/* copy login */
	strlcpy(client->login, argv[0], sizeof(client->login));

	/* set the username as nick if none else provided */
	if(strlen(client->nick) == 0)
		strlcpy(client->nick, client->login, sizeof(client->nick));

	/* elevate state */
	client->state = WD_CLIENT_STATE_GAVE_USER;
}



/*
	USERS
*/

void wd_cmd_users(int argc, char **argv) {
	/* list users */
	wd_list_users();
}



/*
	WHO <cid>
*/

void wd_cmd_who(int argc, char **argv) {
	wd_list_node_t	*node;
	wd_chat_t		*chat;
	wd_client_t		*client;
	wd_cid_t		cid;

	/* convert argument */
	cid = strtoul(argv[0], NULL, 10);
	
	/* get chat */
	chat = wd_get_chat(cid);
	
	if(!chat)
		return;
	
	/* loop over all clients and reply 310 */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(chat->clients, node, client) {
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			wd_reply(310, "%u%c%u%c%u%c%u%c%u%c%s%c%s%c%s%c%s%c%s%c%s",
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
					client->host,
					WD_FIELD_SEPARATOR,
					client->status,
					WD_FIELD_SEPARATOR,
					client->image);
		}
	}
	WD_LIST_UNLOCK(wd_chats);
	
	/* reply end marker */
	wd_reply(311, "%u", cid);
}
