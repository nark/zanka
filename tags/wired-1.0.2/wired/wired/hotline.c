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

#include <sys/types.h>
#include <sys/time.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <pthread.h>
#include <iconv.h>

#include "accounts.h"
#include "banlist.h"
#include "commands.h"
#include "hotline.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


int								hl_ctl_socket;
struct sockaddr_in				hl_ctl_addr;

unsigned short					hl_id;

pthread_key_t					hl_client_key;

struct wd_list					hl_chats;

iconv_t							hl_conv_from, hl_conv_to;


#define hl_get_short(src) \
	((unsigned short) (((unsigned char *) src)[0]) << 8) | \
	((unsigned short) (((unsigned char *) src)[1]))

#define hl_set_short(dst, val) \
	(((unsigned char *) dst)[0] = (unsigned char) ((((unsigned short) val) >> 8) & 0xFF)) ^ \
	(((unsigned char *) dst)[1] = (unsigned char) ((((unsigned short) val))      & 0xFF))

#define hl_get_long(src) \
	((unsigned short) (((unsigned char *) src)[0]) << 24) | \
	((unsigned short) (((unsigned char *) src)[1]) << 16) | \
	((unsigned short) (((unsigned char *) src)[2]) <<  8) | \
	((unsigned short) (((unsigned char *) src)[3]))

#define hl_set_long(dst, val) \
	(((unsigned char *) dst)[0] = (unsigned char) ((((unsigned short) val) >> 24) & 0xFF)) ^ \
	(((unsigned char *) dst)[1] = (unsigned char) ((((unsigned short) val) >> 16) & 0xFF)) ^ \
	(((unsigned char *) dst)[2] = (unsigned char) ((((unsigned short) val) >>  8) & 0xFF)) ^ \
	(((unsigned char *) dst)[3] = (unsigned char) ((((unsigned short) val))       & 0xFF))


void hl_init_server(void) {
	struct wd_chat		*public;
	struct hostent		*host;
	pthread_t			thread;
	int					on = 1, err;
	
	/* create our linked lists */
	wd_list_create(&hl_chats);

	/* create the public chat (safe to skip locking of the linked list mutex here) */
	public = (struct wd_chat *) malloc(sizeof(struct wd_chat));
	public->cid = 1;
	wd_list_create(&(public->clients));
	wd_list_add(&hl_chats, public);
	
	/* create a pthread key to associate all client threads with */
	pthread_key_create(&hl_client_key, NULL);

	/* init iconv */
	hl_conv_from = iconv_open("MacRoman", "UTF-8");
	hl_conv_to = iconv_open("UTF-8", "MacRoman");
	
	if(hl_conv_from == (iconv_t) -1 || hl_conv_to == (iconv_t) -1) {
		wd_log(LOG_ERR, "Could not open libiconv for MacRoman to UTF-8 conversion: %s",
			strerror(errno));
	}
	
	/* create the socket */
	hl_ctl_socket = socket(AF_INET, SOCK_STREAM, 0);
	
	if(hl_ctl_socket < 0)
		wd_log(LOG_ERR, "Could not create socket for Hotline: %s", strerror(errno));
	
	/* set socket options */
	if(setsockopt(hl_ctl_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0)
		wd_log(LOG_ERR, "Could not set socket options for Hotline: %s", strerror(errno));

	if(setsockopt(hl_ctl_socket, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on)) < 0)
		wd_log(LOG_ERR, "Could not set socket options for Hotline: %s", strerror(errno));

	/* init the control address */
	memset(&hl_ctl_addr, 0, sizeof(hl_ctl_addr));
	hl_ctl_addr.sin_family		= AF_INET;
	hl_ctl_addr.sin_port		= htons(wd_settings.hotline_port);

	/* bind to all available addresses if none found in config */
	if(strlen(wd_settings.address) == 0) {
		hl_ctl_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	} else {
		if(!inet_aton(wd_settings.address, &hl_ctl_addr.sin_addr)) {
			host = gethostbyname(wd_settings.address);

			if(!host) {
				wd_log(LOG_ERR, "Could not resolve hostname %s: %s",
					wd_settings.address, hstrerror(h_errno));
			}
			
			memcpy(&hl_ctl_addr.sin_addr, host->h_addr, sizeof(hl_ctl_addr.sin_addr));
		}
	}

	/* bind the socket */
	if(bind(hl_ctl_socket, (struct sockaddr *) &hl_ctl_addr, sizeof(hl_ctl_addr)) < 0)
		wd_log(LOG_ERR, "Could not bind socket for Hotline: %s", strerror(errno));
	
	/* now listen */
	if(listen(hl_ctl_socket, 5) < 0)
		wd_log(LOG_ERR, "Could not listen on socket for Hotline: %s", strerror(errno));
	
	/* spawn the server threads... */
	if((err = pthread_create(&thread, NULL, hl_ctl_listen_thread, NULL)) < 0)
		wd_log(LOG_ERR, "Could not create a thread for Hotline: %s", strerror(err));
}



#pragma mark -

void * hl_ctl_listen_thread(void *arg) {
	struct hl_client	*client;
	struct wd_chat		*chat;
	struct sockaddr_in	addr;
	struct hostent		*host;
	sigset_t			sigs;
	int					sd, length, err;

	/* block all signals */
	sigfillset(&sigs);
	pthread_sigmask(SIG_BLOCK, &sigs, NULL);

	while(wd_running) {
		length = sizeof(addr);
		sd = -1;
		client = NULL;
		
		/* get socket */
		sd = accept(hl_ctl_socket, (struct sockaddr *) &addr, &length);
		
		if(sd < 0) {
			if(errno != EINTR) {
				wd_log(LOG_WARNING, "Could not accept a connection for %s: %s",
					inet_ntoa(addr.sin_addr), strerror(errno));
			}
			
			goto close;
		}
		
		/* create a client */
		client = (struct hl_client *) malloc(sizeof(struct hl_client));
		memset(client, 0, sizeof(struct hl_client));
		
		/* set values */
		client->sd			= sd;
		client->port		= addr.sin_port;
		client->state		= WD_CLIENT_STATE_CONNECTED;
		client->login_time	= time(NULL);
		client->idle_time	= time(NULL);
		
		/* copy strings */
		strlcpy(client->ip, (char *) inet_ntoa(addr.sin_addr), sizeof(client->ip));
		
		if((host = gethostbyaddr((char *) &addr.sin_addr, sizeof(addr.sin_addr), AF_INET)))
			strlcpy(client->host, host->h_name, sizeof(client->host));

		wd_log(LOG_INFO, "Connect from %s", client->ip);
		
		/* get public chat */
		pthread_mutex_lock(&(hl_chats.mutex));
		chat = ((hl_chats.first)->data);
		
		/* assign user id */
		client->uid = (chat->clients).last
			? 1 + ((struct hl_client *) (((chat->clients).last)->data))->uid
			: 32768;
		
		/* add to public chat */
		wd_list_add(&(chat->clients), client);
		pthread_mutex_unlock(&(hl_chats.mutex));

		/* check to see if client is banned by IP */
		if(wd_check_ban(client->ip) < 0) {
			wd_log(LOG_INFO, "Connect from %s denied", client->ip);
			
			goto close;
		}

		/* spawn a client thread */
		if((err = pthread_create(&(client->thread), NULL, hl_ctl_thread, client)) < 0) {
			wd_log(LOG_WARNING, "Could not create a thread: %s", strerror(err));
			
			goto close;
		}
		
		/* all done */
		continue;
		
close:
		if(sd > 0)
			close(sd);
		
		/* delete client */
		if(client) {
			wd_log(LOG_INFO, "Disconnect from %s", client->ip);
			
			client->state = WD_CLIENT_STATE_DISCONNECTED;
			hl_delete_client(client);
		}
	}

	return 0;
}



void * hl_ctl_thread(void *arg) {
	struct hl_client		*client = (struct hl_client *) arg;
	struct hl_transaction	transaction;
	sigset_t				sigs;
	size_t					bytes;

	/* associate the struct with this thread */
	pthread_setspecific(hl_client_key, client);

	/* unblock our thread specific signals from clients */
	sigemptyset(&sigs);
	sigaddset(&sigs, SIGUSR1);
	sigaddset(&sigs, SIGUSR2);
	pthread_sigmask(SIG_UNBLOCK, &sigs, NULL);

	/* initial handshake */
	if((bytes = read(client->sd, client->buffer, 12)) != 12)
		goto close;
	
	if((bytes = write(client->sd, "TRTP\0\0\0\0", 8)) != 8)
		goto close;
	
	while((hl_read_transaction(&transaction)) > 0) {
		/* update the idle time */
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
			pthread_mutex_lock(&(hl_chats.mutex));
			wd_hl_relay_nick(client->uid, client->nick, client->icon,
							 client->idle, client->admin);
			pthread_mutex_unlock(&(hl_chats.mutex));
		}

		/* set transaction id */
		hl_id = transaction.id;

		switch(transaction.type) {
			case 101:
				if(hl_cmd_news() < 0)
					goto close;
				break;
				
			case 105:
				if(hl_cmd_chat() < 0)
					goto close;
				break;
				
			case 107:
				if(hl_cmd_login() < 0)
					goto close;
				break;
			
			case 300:
				if(hl_cmd_who() < 0)
					goto close;
				break;
			
			case 303:
				if(hl_cmd_info() < 0)
					goto close;
				break;

			case 304:
				if(hl_cmd_nick() < 0)
					goto close;
				break;

			default:
				if(hl_cmd_error() < 0)
					goto close;
				break;
		}
	}

close:
	/* announce parting (hotline clients don't get kick messages,
	   so always announce them here) */
	if(client->state >= WD_CLIENT_STATE_LOGGED_IN) {
		hl_wd_relay_leave(client);

		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users--;
		pthread_mutex_unlock(&wd_status_mutex);
		wd_write_status();
	}
	
	/* log */
	wd_log(LOG_INFO, "Disconnect from %s", client->ip);
	
	/* now delete client */
	hl_delete_client(client);
	
	return NULL;
}



#pragma mark -

void hl_update_clients(void) {
	struct wd_list			*clients;
	struct wd_list_node		*node;
	struct hl_client		*client;

	/* get public chat */
	pthread_mutex_lock(&(hl_chats.mutex));
	clients = &(((struct wd_chat *) ((hl_chats.first)->data))->clients);
	
	for(node = clients->first; node != NULL; node = node->next) {
		client = node->data;
		if(!client->idle && client->idle_time + wd_settings.idletime < (unsigned int) time(NULL)) {
			client->idle = 1;
			
			/* broadcast a user change */
			wd_broadcast(1, 304, "%u%s%u%s%u%s%u%s%s",
						 client->uid,
						 WD_FIELD_SEPARATOR,
						 client->idle,
						 WD_FIELD_SEPARATOR,
						 client->admin,
						 WD_FIELD_SEPARATOR,
						 client->icon,
						 WD_FIELD_SEPARATOR,
						 client->nick);
				
			/* hotline subsystem */
			wd_hl_relay_nick(client->uid, client->nick, client->icon,
							 client->idle, client->admin);
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}



#pragma mark -

int hl_cmd_chat(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;
	struct hl_field			field;
	int						i;
	unsigned char			chat[8192];
	unsigned short			options = 0;

	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	for(i = 0; i < parameters.count; i++) {
		if(hl_read_field(&field) < 0)
			return -1;
		
		if(hl_read_buffer(client->buffer, field.size) < 0)
			return -1;
		
		switch(field.id) {
			case 101:
				strlcpy(chat, client->buffer, sizeof(chat));
				break;
			
			case 109:
				options = hl_get_short(client->buffer);
				break;
		}
	}

	if(options == 0)
		hl_wd_relay_say(client, chat);
	else if(options == 1)
		hl_wd_relay_me(client, chat);

	return 1;
}


int hl_cmd_error(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;
	struct hl_field			field;
	char					data[2];
	int						i;

	/* read parameter count */
	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	/* read parameters */
	for(i = 0; i < parameters.count; i++) {
		if(hl_read_field(&field) < 0)
			return -1;
		
		if(hl_read_buffer(client->buffer, field.size) < 0)
			return -1;
	}
	
	/* send error as a server message */
	hl_send_transaction(client->sd, 0, 104, 1, 0, 34);
	hl_send_parameters(client->sd, 2);
	
	hl_send_field(client->sd, 109, 2);
	hl_set_short(data, 1);
	hl_send_buffer(client->sd, data, sizeof(data));
	
	hl_send_field(client->sd, 101, 22);
	hl_send_buffer(client->sd, "Command not supported.", 22);

	return 1;
}



int hl_cmd_info(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;
	struct hl_field			field;
	int						i;
	
	/* read parameter count */
	if(hl_read_parameters(&parameters) < 0)
		return -1;

	/* read parameters */
	for(i = 0; i < parameters.count; i++) {
		if(hl_read_field(&field) < 0)
			return -1;
		
		if(hl_read_buffer(client->buffer, field.size) < 0)
			return -1;
	}
	
	/* send info result header */
	hl_send_transaction(client->sd, 1, 0, hl_id, 0, 44);
	hl_send_parameters(client->sd, 2);
	
	/* send name */
	hl_send_field(client->sd, 102, 7);
	hl_send_buffer(client->sd, "Unknown", 7);

	/* send info */
	hl_send_field(client->sd, 101, 27);
	hl_send_buffer(client->sd, "User info is not supported.", 27);
	
	return 1;
}



int hl_cmd_login(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;
	struct hl_field			field;
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], sha_password[SHA_DIGEST_LENGTH * 2 + 1];
	char					password[256];
	unsigned char			data[2];
	bool					login = false;
	int						i, j;

	/* read parameter count */
	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	/* read parameters */
	for(i = 0; i < parameters.count; i++) {
		if(hl_read_field(&field) < 0)
			return -1;
		
		if(hl_read_buffer(client->buffer, field.size) < 0)
			return -1;

		switch(field.id) {
			case 102:
				strlcpy(client->nick, client->buffer, sizeof(client->nick));
				
				login = true;
				break;

			case 104:
				if(field.size == 4)
					client->icon = hl_get_long(client->buffer);
				else if(field.size == 2)
					client->icon = hl_get_short(client->buffer);
				break;
				
			case 105:
				strlcpy(client->login, client->buffer, sizeof(client->login));
				
				/* "decrypt" */
				for(j = 0; j < field.size; j++)
					client->login[j] = 255 - client->login[j];
				
				login = true;
				break;
			
			case 106:
				strlcpy(password, client->buffer, sizeof(password));

				/* "decrypt" */
				for(j = 0; j < field.size; j++)
					password[j] = 255 - password[j];

				/* calculate password checksum */
				SHA1_Init(&c);
				SHA1_Update(&c, password, field.size);
				SHA1_Final(sha, &c);
				
				/* map into hexademical characters */
				for(j = 0; j < SHA_DIGEST_LENGTH; j++) {
					sha_password[j+j]	= hex[sha[j] >> 4];
					sha_password[j+j+1]	= hex[sha[j] & 0x0F];
				}
				
				sha_password[j+j] = '\0';
				break;
			
			case 160:
				client->version = hl_get_short(client->buffer);
				break;
		}
	}

	/* "guest" by default */
	if(strlen(client->login) == 0)
		strlcpy(client->login, "guest", sizeof(client->login));
		
	/* nick = login by default */
	if(strlen(client->nick) == 0)
		strlcpy(client->nick, client->login, sizeof(client->nick));

	/* test login */
	if(wd_check_login(client->login, sha_password) > 0) {
		/* succeeded */
		wd_log(LOG_INFO, "Login from %s/%s/%s succeeded",
			   client->nick,
			   client->login,
			   client->ip);
	} else {
		/* failed */
		wd_log(LOG_INFO, "Login from %s/%s/%s failed",
			   client->nick,
			   client->login,
			   client->ip);
		
		return -1;
	}

	/* get admin flag */
	client->admin = wd_getpriv(client->login, WD_PRIV_KICK_USERS) |
					wd_getpriv(client->login, WD_PRIV_BAN_USERS);

	/* newer clients want to send a 304 before we show them */
	if(login) {
		/* relay to wired */
		hl_wd_relay_join(client);

		/* elevate state */
		client->state = WD_CLIENT_STATE_LOGGED_IN;

		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users++;
		wd_total_users++;
		pthread_mutex_unlock(&wd_status_mutex);
		wd_write_status();
	}

	/* send login result header */
	hl_send_transaction(client->sd, 1, 0, hl_id, 0, 8);
	hl_send_parameters(client->sd, 1);
	
	/* send uid */
	hl_send_field(client->sd, 103, 2);
	hl_set_short(data, client->uid);
	hl_send_buffer(client->sd, data, sizeof(data));

	/* send empty agreement header */
	hl_send_transaction(client->sd, 0, 109, 1, 0, 8);
	hl_send_parameters(client->sd, 1);
	
	/* send agreement */
	hl_send_field(client->sd, 154, 2);
	hl_set_short(data, 1);
	hl_send_buffer(client->sd, data, sizeof(data));
	
	return 1;
}



int hl_cmd_news(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;

	/* read parameter count */
	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	/* send login result header */
	hl_send_transaction(client->sd, 1, 0, hl_id, 0, 28);
	hl_send_parameters(client->sd, 1);
	
	/* send version */
	hl_send_field(client->sd, 101, 22);
	hl_send_buffer(client->sd, "News is not supported.", 22);

	return 1;
}



int hl_cmd_nick(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct hl_parameters	parameters;
	struct hl_field			field;
	char					nick[WD_NICK_SIZE];
	unsigned int			icon = 0;
	int						i;
	
	/* read parameter count */
	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	/* read parameters */
	for(i = 0; i < parameters.count; i++) {
		if(hl_read_field(&field) < 0)
			return -1;
		
		if(hl_read_buffer(client->buffer, field.size) < 0)
			return -1;
		
		switch(field.id) {
			case 102:
				strlcpy(nick, client->buffer, sizeof(nick));
				break;

			case 104:
				icon = hl_get_short(client->buffer);
				break;
		}
	}
	
	if(client->state == WD_CLIENT_STATE_CONNECTED) {
		/* update client */
		strlcpy(client->nick, nick, sizeof(client->nick));
		client->icon = icon;

		/* relay to wired */
		hl_wd_relay_join(client);

		/* update status */
		pthread_mutex_lock(&wd_status_mutex);
		wd_current_users++;
		wd_total_users++;
		pthread_mutex_unlock(&wd_status_mutex);
		wd_write_status();

		/* elevate state */
		client->state = WD_CLIENT_STATE_LOGGED_IN;
	}
	else if(strcmp(client->nick, nick) != 0 || icon != client->icon) {
		/* update client */
		strlcpy(client->nick, nick, sizeof(client->nick));
		client->icon = icon;

		/* relay to wired */
		hl_wd_relay_nick(client);
	}

	return 1;
}



int hl_cmd_who(void) {
	struct hl_client		*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	struct wd_list_node		*client_node;
	struct wd_chat			*hl_chat, *wd_chat;
	struct hl_client		*hl_peer;
	struct wd_client		*wd_peer;
	struct hl_parameters	parameters;
	unsigned char			data[2], nick[WD_NICK_SIZE];
	unsigned short			flags;
	unsigned int			count = 0, size = 0, length;
	
	/* get number of parameters */
	if(hl_read_parameters(&parameters) < 0)
		return -1;
	
	/* get public chats */
	hl_chat = ((hl_chats.first)->data);
	wd_chat = ((wd_chats.first)->data);
	
	/* run through once to get number of clients and their sizes */
	/* first, wired chat */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(client_node = (wd_chat->clients).first; client_node != NULL; client_node = client_node->next) {
		wd_peer = client_node->data;
		
		if(wd_peer->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* convert nick */
			strlcpy(nick, wd_peer->nick, sizeof(nick));
			hl_convert_buffer(hl_conv_from, nick, strlen(wd_peer->nick));
			length = strlen(nick);

			count++;
			size += 8 + length;
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));

	/* then, hotline chat */
	pthread_mutex_lock(&(hl_chats.mutex));
	for(client_node = (hl_chat->clients).first; client_node != NULL; client_node = client_node->next) {
		hl_peer = client_node->data;
		
		if(hl_peer->state == WD_CLIENT_STATE_LOGGED_IN) {
			count++;
			size += 8 + strlen(hl_peer->nick);
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
	
	/* send result header */
	hl_send_transaction(client->sd, 1, 0, hl_id, 0, 2 + (count * 4) + size);
	hl_send_parameters(client->sd, count);
	
	/* now run through again and send */
	/* first, wired chat */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(client_node = (wd_chat->clients).first; client_node != NULL; client_node = client_node->next) {
		wd_peer = client_node->data;
		
		if(wd_peer->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* convert nick */
			strlcpy(nick, wd_peer->nick, sizeof(nick));
			hl_convert_buffer(hl_conv_from, nick, strlen(wd_peer->nick));
			length = strlen(nick);
			
			/* send field header */
			hl_send_field(client->sd, 300, 8 + length);
						  
			/* send uid */
			hl_set_short(data, wd_peer->uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon id */
			hl_set_short(data, wd_peer->icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			flags = 0;

			if(wd_peer->idle)
				flags |= 1;
			if(wd_peer->admin)
				flags |= 2;
			
			hl_set_short(data, flags);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send nick size */
			hl_set_short(data, length);
			hl_send_buffer(client->sd, data, sizeof(data));
			
			/* send nick*/
			hl_send_buffer(client->sd, nick, length);
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));

	/* then, hotline chat */
	pthread_mutex_lock(&(hl_chats.mutex));
	for(client_node = (hl_chat->clients).first; client_node != NULL; client_node = client_node->next) {
		hl_peer = client_node->data;
		
		if(hl_peer->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send field header */
			hl_send_field(client->sd, 300, 8 + strlen(hl_peer->nick));
						  
			/* send uid */
			hl_set_short(data, hl_peer->uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon id */
			hl_set_short(data, hl_peer->icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			flags = 0;

			if(hl_peer->idle)
				flags |= 1;
			if(hl_peer->admin)
				flags |= 2;
			
			hl_set_short(data, flags);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send nick size */
			hl_set_short(data, strlen(hl_peer->nick));
			hl_send_buffer(client->sd, data, sizeof(data));
			
			/* send nick*/
			hl_send_buffer(client->sd, hl_peer->nick, strlen(hl_peer->nick));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
	
	return 1;
}



#pragma mark -

void wd_hl_ban(unsigned long uid) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct hl_client		*peer;
	struct wd_tempban		*tempban;
	
	/* get user */
	peer = hl_get_client(uid);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* check priv */
	if(wd_getpriv(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		return;
	}
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s kicked %s/%s/%s",
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
	pthread_kill(peer->thread, SIGUSR1);
}



void wd_hl_info(unsigned long uid) {
	struct hl_client		*peer;
	char					logintime[26], idletime[26];
	
	/* get user */
	peer = hl_get_client(uid);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* format time strings */
	wd_time_to_iso8601(localtime(&(peer->login_time)), logintime, sizeof(logintime));
	wd_time_to_iso8601(localtime(&(peer->idle_time)), idletime, sizeof(idletime));

	/* reply info via wired */
	wd_reply(308, "%lu%s%u%s%u%s%u%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
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
			 "Hotline Subsystem/1.0 (unknown; unknown; unknown)",
			 WD_FIELD_SEPARATOR,
			 "",
			 WD_FIELD_SEPARATOR,
			 "",
			 WD_FIELD_SEPARATOR,
		 	 logintime,
			 WD_FIELD_SEPARATOR,
			 idletime,
			 WD_FIELD_SEPARATOR,
			 "",
			 WD_FIELD_SEPARATOR,
		 	 "");

}



void wd_hl_kick(unsigned long uid) {
	struct wd_client		*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	struct hl_client		*peer;
	
	/* get user */
	peer = hl_get_client(uid);
	
	if(!peer) {
		wd_reply(512, "Client Not Found");
		
		return;
	}
	
	/* check priv */
	if(wd_getpriv(peer->login, WD_PRIV_CANNOT_BE_KICKED) == 1) {
		wd_reply(515, "Cannot Be Disconnected");
		
		return;
	}
	
	/* log */
	wd_log_ll(LOG_INFO, "%s/%s/%s kicked %s/%s/%s",
			  client->nick,
			  client->login,
			  client->ip,
			  peer->nick,
			  peer->login,
			  peer->ip);

	/* disconnect */
	pthread_kill(peer->thread, SIGUSR1);
}



void wd_hl_who(unsigned long cid) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	char					nick[WD_NICK_SIZE], login[WD_LOGIN_SIZE];
		
	/* only for public chat */
	if(cid != 1)
		return;

	/* get public chat */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	/* loop over all clients and reply 310 */
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* convert nick and login */
			strlcpy(nick, client->nick, sizeof(nick));
			hl_convert_buffer(hl_conv_to, nick, strlen(nick));
			strlcpy(login, client->login, sizeof(login));
			hl_convert_buffer(hl_conv_to, login, strlen(nick));
			
			/* send */
			wd_reply(310, "%lu%s%u%s%u%s%u%s%u%s%s%s%s%s%s%s%s",
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
					 nick,
					 WD_FIELD_SEPARATOR,
					 login,
					 WD_FIELD_SEPARATOR,
					 client->ip,
					 WD_FIELD_SEPARATOR,
					 client->host);
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}



#pragma mark -



void hl_wd_relay_join(struct hl_client *peer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2], nick[WD_NICK_SIZE], login[WD_NICK_SIZE];

	/* broadcast user join via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user join header */
			hl_send_transaction(client->sd, 0, 301, 1, 0, 24 + strlen(peer->nick));
			hl_send_parameters(client->sd, 4);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, peer->uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon */
			hl_send_field(client->sd, 104, 2);
			hl_set_short(data, peer->icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			hl_send_field(client->sd, 112, 2);
			hl_set_short(data, 0);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send name */
			hl_send_field(client->sd, 102, strlen(peer->nick));
			hl_send_buffer(client->sd, peer->nick, strlen(peer->nick));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));

	/* convert nick and login */
	strlcpy(nick, peer->nick, sizeof(nick));
	hl_convert_buffer(hl_conv_to, nick, strlen(nick));
	strlcpy(login, peer->login, sizeof(login));
	hl_convert_buffer(hl_conv_to, login, strlen(nick));
	
	/* broadcast user join via wired */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 302, "%lu%s%u%s%u%s%u%s%u%s%s%s%s%s%s",
				 1,
				 WD_FIELD_SEPARATOR,
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 peer->idle,
				 WD_FIELD_SEPARATOR,
				 peer->admin,
				 WD_FIELD_SEPARATOR,
				 peer->icon,
				 WD_FIELD_SEPARATOR,
				 nick,
				 WD_FIELD_SEPARATOR,
				 login,
				 WD_FIELD_SEPARATOR,
				 peer->ip,
				 WD_FIELD_SEPARATOR,
				 peer->host);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_hl_relay_join(unsigned long uid, char *nick, unsigned long icon, bool idle, bool admin) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2], conv_nick[WD_NICK_SIZE];
	unsigned int			length;
	unsigned short			flags;
	
	/* convert nick */
	strlcpy(conv_nick, nick, sizeof(conv_nick));
	hl_convert_buffer(hl_conv_from, conv_nick, strlen(nick));
	length = strlen(conv_nick);
	
	/* get flags */
	flags = 0;

	if(idle)
		flags |= 1;
	if(admin)
		flags |= 2;

	/* broadcast user join via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user join header */
			hl_send_transaction(client->sd, 0, 301, 1, 0, 24 + length);
			hl_send_parameters(client->sd, 4);

			/* send name */
			hl_send_field(client->sd, 102, length);
			hl_send_buffer(client->sd, conv_nick, length);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon */
			hl_send_field(client->sd, 104, 2);
			hl_set_short(data, icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			hl_send_field(client->sd, 112, 2);
			hl_set_short(data, flags);
			hl_send_buffer(client->sd, data, sizeof(data));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}




void hl_wd_relay_leave(struct hl_client *peer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2];

	/* broadcast user leave via wired */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user change header */
			hl_send_transaction(client->sd, 0, 302, 1, 0, 8);
			hl_send_parameters(client->sd, 1);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, peer->uid);
			hl_send_buffer(client->sd, data, sizeof(data));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));

	/* broadcast user leave via wired */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 303, "1%s%u", WD_FIELD_SEPARATOR, peer->uid);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_hl_relay_leave(unsigned long uid) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2];

	/* broadcast user leave via wired */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user change header */
			hl_send_transaction(client->sd, 0, 302, 1, 0, 8);
			hl_send_parameters(client->sd, 1);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, uid);
			hl_send_buffer(client->sd, data, sizeof(data));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}



void hl_wd_relay_me(struct hl_client *peer, char *buffer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned int			length;
	
	/* get nick length */
	length = strlen(peer->nick);
	
	/* broadcast chat via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			hl_send_transaction(client->sd, 0, 106, 1, 0, 7 + strlen(buffer) + 6 + length);
			hl_send_parameters(client->sd, 1);
			hl_send_field(client->sd, 101, strlen(buffer) + 7 + length);
			hl_send_buffer(client->sd, "\r *** ", 6);
			hl_send_buffer(client->sd, peer->nick, length);
			hl_send_buffer(client->sd, " ", 1);
			hl_send_buffer(client->sd, buffer, strlen(buffer));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));

	/* convert chat */
	hl_convert_buffer(hl_conv_to, buffer, strlen(buffer));

	/* broadcast chat via wired */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 301, "%lu%s%u%s%s",
				 1,
				 WD_FIELD_SEPARATOR,
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 buffer);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_hl_relay_me(char *nick, char *buffer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	char					conv_nick[WD_NICK_SIZE];
	unsigned int			length;
	
	/* get nick length */
	length = strlen(nick);
	
	/* convert nick */
	strlcpy(conv_nick, nick, sizeof(conv_nick));
	hl_convert_buffer(hl_conv_from, conv_nick, strlen(nick));
	length = strlen(conv_nick);

	/* convert chat */
	hl_convert_buffer(hl_conv_from, buffer, strlen(buffer));

	/* broadcast chat via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;

		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			hl_send_transaction(client->sd, 0, 106, 1, 0, 7 + strlen(buffer) + 6 + length);
			hl_send_parameters(client->sd, 1);
			hl_send_field(client->sd, 101, strlen(buffer) + 7 + length);
			hl_send_buffer(client->sd, "\r *** ", 6);
			hl_send_buffer(client->sd, conv_nick, length);
			hl_send_buffer(client->sd, " ", 1);
			hl_send_buffer(client->sd, buffer, strlen(buffer));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}



void hl_wd_relay_nick(struct hl_client *peer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2], nick[WD_NICK_SIZE];
	unsigned int			length;
	unsigned short			flags;
	
	/* get nick length */
	length = strlen(peer->nick);

	/* get flags */
	flags = 0;

	if(peer->idle)
		flags |= 1;
	if(peer->admin)
		flags |= 2;

	/* broadcast user change via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user change header */
			hl_send_transaction(client->sd, 0, 301, 1, 0, 24 + length);
			hl_send_parameters(client->sd, 4);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, peer->uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon */
			hl_send_field(client->sd, 104, 2);
			hl_set_short(data, peer->icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			hl_send_field(client->sd, 112, 2);
			hl_set_short(data, flags);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send name */
			hl_send_field(client->sd, 102, length);
			hl_send_buffer(client->sd, peer->nick, length);
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
	
	/* convert nick */
	strlcpy(nick, peer->nick, sizeof(nick));
	hl_convert_buffer(hl_conv_to, nick, strlen(nick));
	
	/* broadcast user change via wired */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 304, "%u%s%u%s%u%s%u%s%s",
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 peer->idle,
				 WD_FIELD_SEPARATOR,
				 peer->admin,
				 WD_FIELD_SEPARATOR,
				 peer->icon,
				 WD_FIELD_SEPARATOR,
				 nick);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_hl_relay_nick(unsigned long uid, char *nick, unsigned long icon, unsigned int idle, unsigned int admin) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	unsigned char			data[2], conv_nick[WD_NICK_SIZE];
	unsigned int			length;
	unsigned short			flags;
	
	/* convert nick */
	strlcpy(conv_nick, nick, sizeof(conv_nick));
	hl_convert_buffer(hl_conv_from, conv_nick, strlen(nick));
	length = strlen(conv_nick);
	
	/* get flags */
	flags = 0;

	if(idle)
		flags |= 1;
	if(admin)
		flags |= 2;

	/* broadcast user change via hotline */
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			/* send user change header */
			hl_send_transaction(client->sd, 0, 301, 1, 0, 24 + length);
			hl_send_parameters(client->sd, 4);

			/* send uid */
			hl_send_field(client->sd, 103, 2);
			hl_set_short(data, uid);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send icon */
			hl_send_field(client->sd, 104, 2);
			hl_set_short(data, icon);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send flags */
			hl_send_field(client->sd, 112, 2);
			hl_set_short(data, flags);
			hl_send_buffer(client->sd, data, sizeof(data));

			/* send name */
			hl_send_field(client->sd, 102, length);
			hl_send_buffer(client->sd, conv_nick, length);
		}
	}
}



void hl_wd_relay_say(struct hl_client *peer, char *buffer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	char					prefix[16];
	unsigned int			length;
	
	/* get nick length */
	length = strlen(peer->nick);
	
	/* broadcast chat via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			hl_send_transaction(client->sd, 0, 106, 1, 0, 7 + strlen(buffer) + sizeof(prefix));
			hl_send_parameters(client->sd, 1);
			hl_send_field(client->sd, 101, 1 + strlen(buffer) + sizeof(prefix));
			hl_send_buffer(client->sd, "\r", 1);

			memset(prefix, ' ', sizeof(prefix));
			
			if(length > sizeof(prefix))
				memcpy(prefix, peer->nick, 13);
			else
				memcpy(prefix + (13 - length), peer->nick, length);

			memcpy(prefix + 13, ":  ", 3);

			hl_send_buffer(client->sd, prefix, sizeof(prefix));
			hl_send_buffer(client->sd, buffer, strlen(buffer));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));

	/* convert chat */
	hl_convert_buffer(hl_conv_to, buffer, strlen(buffer));

	/* broadcast chat via wired */
	pthread_mutex_lock(&(wd_chats.mutex));
	wd_broadcast(1, 300, "%lu%s%u%s%s",
				 1,
				 WD_FIELD_SEPARATOR,
				 peer->uid,
				 WD_FIELD_SEPARATOR,
				 buffer);
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_hl_relay_say(char *nick, char *buffer) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client;
	char					prefix[16], conv_nick[WD_NICK_SIZE];
	unsigned int			length;
	
	/* convert nick */
	strlcpy(conv_nick, nick, sizeof(conv_nick));
	hl_convert_buffer(hl_conv_from, conv_nick, strlen(nick));
	length = strlen(conv_nick);

	/* convert chat */
	hl_convert_buffer(hl_conv_from, buffer, strlen(buffer));
	
	/* broadcast chat via hotline */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
		
		if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
			hl_send_transaction(client->sd, 0, 106, 1, 0, 7 + strlen(buffer) + sizeof(prefix));
			hl_send_parameters(client->sd, 1);
			hl_send_field(client->sd, 101, 1 + strlen(buffer) + sizeof(prefix));
			hl_send_buffer(client->sd, "\r", 1);

			memset(prefix, ' ', sizeof(prefix));
			
			if(length > sizeof(prefix))
				memcpy(prefix, conv_nick, 13);
			else
				memcpy(prefix + (13 - length), conv_nick, length);

			memcpy(prefix + 13, ":  ", 3);

			hl_send_buffer(client->sd, prefix, sizeof(prefix));
			hl_send_buffer(client->sd, buffer, strlen(buffer));
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
}



#pragma mark -

void hl_convert_buffer(iconv_t direction, char *inbuffer, size_t inbytes) {
	char					outbuffer[8192], *i, *o;
	size_t					outbytes;
	
	/* get sizes */
	outbytes = sizeof(outbuffer);
	memset(outbuffer, 0, outbytes);

	/* use temporary variables for conversion */
	i = inbuffer;
	o = outbuffer;

	/* convert */
	iconv(direction, (const char **) &i, &inbytes, &o, &outbytes);
	
	/* copy back */
	memcpy(inbuffer, outbuffer, sizeof(outbuffer) - outbytes);
	inbuffer[sizeof(outbuffer) - outbytes] = '\0';
}




#pragma mark -

struct hl_client * hl_get_client(unsigned short uid) {
	struct wd_list_node		*client_node;
	struct wd_chat			*chat;
	struct hl_client		*client, *value = NULL;

	/* get public chat */
	pthread_mutex_lock(&(hl_chats.mutex));
	chat = ((hl_chats.first)->data);
	
	/* find uid on chat */
	for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
		client = client_node->data;
				
		if(client->uid == uid) {
			value = client;
					
			break;
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));

	return value;
}



void hl_delete_client(struct hl_client *client) {
	struct wd_list_node	*chat_node, *client_node;
	struct wd_chat		*chat;
	struct hl_client	*peer;
	
	/* remove the client from all chat lists we find it on */
	pthread_mutex_lock(&(hl_chats.mutex));
	for(chat_node = hl_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
			peer = client_node->data;
			
			if(peer->sd == client->sd)
				wd_list_delete(&(chat->clients), client_node);
		}
	}
	pthread_mutex_unlock(&(hl_chats.mutex));
	
	/* close down client */
	if(client->state <= WD_CLIENT_STATE_LOGGED_IN)
		close(client->sd);

	/* free client */
	free(client);
}



#pragma mark -

void hl_send_transaction(int sd, int is_reply, int type, int id, int error, int size) {
	struct hl_transaction   transaction;

	/* create transaction */
	memset(&transaction, 0, sizeof(transaction));
	transaction.flags		= (char) htons(0);
	transaction.is_reply	= (char) htons(is_reply);
	transaction.type		= htons(type);
	transaction.id			= htonl(id);
	transaction.error		= htonl(error);
	transaction.total_size	= htonl(size);
	transaction.data_size	= htonl(size);
	
	/* send to client */
	write(sd, &transaction, sizeof(transaction));
}



void hl_send_parameters(int sd, int count) {
	struct hl_parameters	parameters;
	
	/* create hl_parameters */
	memset(&parameters, 0, sizeof(parameters));
	parameters.count		= htons(count);
	
	/* send to client */
	write(sd, &parameters, sizeof(parameters));
}



void hl_send_field(int sd, int id, int size) {
	struct hl_field			field;
	
	/* create field */
	memset(&field, 0, sizeof(field));
	field.id				= htons(id);
	field.size				= htons(size);
	
	/* send to client */
	write(sd, &field, sizeof(field));
}



void hl_send_buffer(int sd, char *inbuffer, size_t inbytes) {
	/* send to client */
	write(sd, inbuffer, inbytes);
}



int hl_read_transaction(struct hl_transaction *transaction) {
	struct hl_client	*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	size_t				bytes;
	
	memset(transaction, 0, sizeof(struct hl_transaction));
	
	/* read from client */
	bytes = read(client->sd, transaction, sizeof(struct hl_transaction));

	if(bytes != sizeof(struct hl_transaction))
		return -1;
	
	/* convert from network order */
	transaction->flags		= (unsigned char) ntohs(transaction->flags);
	transaction->is_reply   = (unsigned char) ntohs(transaction->is_reply);
	transaction->type		= ntohs(transaction->type);
	transaction->id			= ntohl(transaction->id);
	transaction->error		= ntohl(transaction->error);
	transaction->total_size	= ntohl(transaction->total_size);
	transaction->data_size	= ntohl(transaction->data_size);
	
	return 1;
}



int hl_read_parameters(struct hl_parameters *parameters) {
	struct hl_client	*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	size_t				bytes;
	
	memset(parameters, 0, sizeof(struct hl_parameters));

	/* read from client */
	bytes = read(client->sd, parameters, sizeof(struct hl_parameters));
	
	if(bytes != sizeof(struct hl_parameters))
		return -1;
	
	/* convert from network order */
	parameters->count = ntohs(parameters->count);
	
	return 1;
}



int hl_read_field(struct hl_field *field) {
	struct hl_client	*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	size_t				bytes;
	
	memset(field, 0, sizeof(struct hl_field));

	/* read from client */
	bytes = read(client->sd, field, sizeof(struct hl_field));
	
	if(bytes != sizeof(struct hl_field))
		return -1;
	
	/* convert from network order */
	field->id	= ntohs(field->id);
	field->size	= ntohs(field->size);
	
	return 1;
}



int hl_read_buffer(char *inbuffer, size_t inbytes) {
	struct hl_client	*client = (struct hl_client *) pthread_getspecific(hl_client_key);
	size_t				bytes;
	
	memset(inbuffer, 0, inbytes);

	/* read from client */
	if((bytes = read(client->sd, inbuffer, inbytes)) != inbytes)
		return -1;
	
	inbuffer[inbytes] = '\0';

	return 1;
}
