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

#ifdef HAVE_CORESERVICES_CORESERVICES_H
#include <CoreServices/CoreServices.h>
#endif

#include <sys/types.h>
#include <sys/time.h>
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
#include <openssl/ssl.h>
#include <openssl/err.h>

#include "banlist.h"
#include "commands.h"
#include "hotline.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


int							wd_ctl_socket, wd_xfer_socket;
struct sockaddr_in			wd_ctl_addr, wd_xfer_addr;

SSL_CTX						*wd_ctl_ssl_ctx, *wd_xfer_ssl_ctx;
pthread_mutex_t				*wd_ssl_locks;

pthread_key_t				wd_client_key;

struct wd_list				wd_chats;

#ifdef HAVE_CORESERVICES_CORESERVICES_H
CFNetServiceRef				wd_net_service;
#endif


void wd_init_server(void) {
	struct wd_chat			*public;
	struct hostent			*host;
	pthread_t				thread;
	int						on = 1, err;

	/* create our linked lists */
	wd_list_create(&wd_tempbans);
	wd_list_create(&wd_chats);
	wd_list_create(&wd_transfers);
	
	/* create the public chat (safe to skip locking of the linked list mutex here) */
	public = (struct wd_chat *) malloc(sizeof(struct wd_chat));
	public->cid = 1;
	wd_list_create(&(public->clients));
	wd_list_add(&wd_chats, public);

	/* create a pthread key to associate all client threads with */
	pthread_key_create(&wd_client_key, NULL);
	
	
	/* create the sockets */
	wd_ctl_socket		= socket(AF_INET, SOCK_STREAM, 0);
	wd_xfer_socket		= socket(AF_INET, SOCK_STREAM, 0);

	if(wd_ctl_socket < 0 || wd_xfer_socket < 0)
		wd_log(LOG_ERR, "Could not create socket for Wired: %s", strerror(errno));

	/* set socket options */
	if(setsockopt(wd_ctl_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0 ||
	   setsockopt(wd_xfer_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0)
		wd_log(LOG_ERR, "Could not set socket options for Wired: %s", strerror(errno));

	if(setsockopt(wd_ctl_socket, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on)) < 0)
		wd_log(LOG_ERR, "Could not set socket options for Wired: %s", strerror(errno));
	
	/* init the control address */
	memset(&wd_ctl_addr, 0, sizeof(wd_ctl_addr));
	wd_ctl_addr.sin_family			= AF_INET;
	wd_ctl_addr.sin_port			= htons(wd_settings.port);

	/* bind to all available addresses if none found in config */
	if(strlen(wd_settings.address) == 0) {
		wd_ctl_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	} else {
		if(!inet_aton(wd_settings.address, &wd_ctl_addr.sin_addr)) {
			host = gethostbyname(wd_settings.address);

			if(!host) {
				wd_log(LOG_ERR, "Could not resolve hostname %s: %s",
					wd_settings.address, hstrerror(h_errno));
			}
			
			memcpy(&wd_ctl_addr.sin_addr, host->h_addr, sizeof(wd_ctl_addr.sin_addr));
		}
	}

	/* init the transfer address */
	memset(&wd_xfer_addr, 0, sizeof(wd_xfer_addr));
	wd_xfer_addr.sin_family			= AF_INET;
	wd_xfer_addr.sin_port			= htons(wd_settings.port + 1);
	wd_xfer_addr.sin_addr.s_addr	= wd_ctl_addr.sin_addr.s_addr;
	
	/* bind the sockets */
	if(bind(wd_ctl_socket, (struct sockaddr *) &wd_ctl_addr, sizeof(wd_ctl_addr)) < 0 ||
	   bind(wd_xfer_socket, (struct sockaddr *) &wd_xfer_addr, sizeof(wd_xfer_addr)) < 0)
		wd_log(LOG_ERR, "Could not bind socket for Wired: %s", strerror(errno));
	
	/* now listen */
	if(listen(wd_ctl_socket, 5) < 0 ||
	   listen(wd_xfer_socket, 5) < 0)
		wd_log(LOG_ERR, "Could not listen on socket for Wired: %s", strerror(errno));

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* spawn the Core Foundation run loop thread */
	if(wd_settings.zeroconf) {
		if((err = pthread_create(&thread, NULL, wd_cf_thread, NULL)) < 0)
			wd_log(LOG_ERR, "Could not create a thread: %s", strerror(err));
	}
#endif

	/* spawn the server threads... */
	if((err = pthread_create(&thread, NULL, wd_ctl_listen_thread, NULL)) < 0 ||
	   (err = pthread_create(&thread, NULL, wd_xfer_listen_thread, NULL)) < 0)
		wd_log(LOG_ERR, "Could not create a thread for Wired: %s", strerror(err));
}



#pragma mark -

void wd_init_ssl(void) {
	DH				*dh;
	int				mutexes, i;
	unsigned char	dh2048_p[] = {
		0xF6,0x42,0x57,0xB7,0x08,0x7F,0x08,0x17,0x72,0xA2,0xBA,0xD6,
		0xA9,0x42,0xF3,0x05,0xE8,0xF9,0x53,0x11,0x39,0x4F,0xB6,0xF1,
		0x6E,0xB9,0x4B,0x38,0x20,0xDA,0x01,0xA7,0x56,0xA3,0x14,0xE9,
		0x8F,0x40,0x55,0xF3,0xD0,0x07,0xC6,0xCB,0x43,0xA9,0x94,0xAD,
		0xF7,0x4C,0x64,0x86,0x49,0xF8,0x0C,0x83,0xBD,0x65,0xE9,0x17,
		0xD4,0xA1,0xD3,0x50,0xF8,0xF5,0x59,0x5F,0xDC,0x76,0x52,0x4F,
		0x3D,0x3D,0x8D,0xDB,0xCE,0x99,0xE1,0x57,0x92,0x59,0xCD,0xFD,
		0xB8,0xAE,0x74,0x4F,0xC5,0xFC,0x76,0xBC,0x83,0xC5,0x47,0x30,
		0x61,0xCE,0x7C,0xC9,0x66,0xFF,0x15,0xF9,0xBB,0xFD,0x91,0x5E,
		0xC7,0x01,0xAA,0xD3,0x5B,0x9E,0x8D,0xA0,0xA5,0x72,0x3A,0xD4,
		0x1A,0xF0,0xBF,0x46,0x00,0x58,0x2B,0xE5,0xF4,0x88,0xFD,0x58,
		0x4E,0x49,0xDB,0xCD,0x20,0xB4,0x9D,0xE4,0x91,0x07,0x36,0x6B,
		0x33,0x6C,0x38,0x0D,0x45,0x1D,0x0F,0x7C,0x88,0xB3,0x1C,0x7C,
		0x5B,0x2D,0x8E,0xF6,0xF3,0xC9,0x23,0xC0,0x43,0xF0,0xA5,0x5B,
		0x18,0x8D,0x8E,0xBB,0x55,0x8C,0xB8,0x5D,0x38,0xD3,0x34,0xFD,
		0x7C,0x17,0x57,0x43,0xA3,0x1D,0x18,0x6C,0xDE,0x33,0x21,0x2C,
		0xB5,0x2A,0xFF,0x3C,0xE1,0xB1,0x29,0x40,0x18,0x11,0x8D,0x7C,
		0x84,0xA7,0x0A,0x72,0xD6,0x86,0xC4,0x03,0x19,0xC8,0x07,0x29,
		0x7A,0xCA,0x95,0x0C,0xD9,0x96,0x9F,0xAB,0xD0,0x0A,0x50,0x9B,
		0x02,0x46,0xD3,0x08,0x3D,0x66,0xA4,0x5D,0x41,0x9F,0x9C,0x7C,
		0xBD,0x89,0x4B,0x22,0x19,0x26,0xBA,0xAB,0xA2,0x5E,0xC3,0x55,
		0xE9,0x32,0x0B,0x3B };
	unsigned char	dh2048_g[] = { 0x02 };

	/* initiate SSL */
	SSL_load_error_strings();
	SSL_library_init();

	/* create SSL contexts */
	wd_ctl_ssl_ctx		= SSL_CTX_new(TLSv1_server_method());
	wd_xfer_ssl_ctx		= SSL_CTX_new(TLSv1_server_method());
	
	if(!wd_ctl_ssl_ctx || !wd_xfer_ssl_ctx) {
		wd_log(LOG_ERR, "Could not create an SSL context: %s",
			ERR_reason_error_string(ERR_get_error()));
	}

	if(strlen(wd_settings.certificate) > 0) {
		/* load SSL certificate */
		if(SSL_CTX_use_certificate_chain_file(wd_ctl_ssl_ctx, wd_settings.certificate) != 1 ||
		   SSL_CTX_use_certificate_chain_file(wd_xfer_ssl_ctx, wd_settings.certificate) != 1)
			wd_log(LOG_ERR, "Could not load certificate %s", wd_settings.certificate);
	
		if(SSL_CTX_use_PrivateKey_file(wd_ctl_ssl_ctx, wd_settings.certificate, SSL_FILETYPE_PEM) != 1 ||
		   SSL_CTX_use_PrivateKey_file(wd_xfer_ssl_ctx, wd_settings.certificate, SSL_FILETYPE_PEM) != 1)
			wd_log(LOG_ERR, "Could not load key file %s", wd_settings.certificate);
	} else {
		/* create DH key */
		dh = DH_new();
		
		if(!dh) {
			wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
				ERR_reason_error_string(ERR_get_error()));
		}

		dh->p = BN_bin2bn(dh2048_p, sizeof(dh2048_p), NULL);
		dh->g = BN_bin2bn(dh2048_g, sizeof(dh2048_g), NULL);

		if(!dh->p || !dh->g) {
			wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
				ERR_reason_error_string(ERR_get_error()));
		}

		SSL_CTX_set_tmp_dh(wd_ctl_ssl_ctx, dh);
		SSL_CTX_set_tmp_dh(wd_xfer_ssl_ctx, dh);

		DH_free(dh);
	}
	
	/* set our desired cipher list */
	if(SSL_CTX_set_cipher_list(wd_ctl_ssl_ctx, wd_settings.controlcipher) != 1 ||
	   SSL_CTX_set_cipher_list(wd_xfer_ssl_ctx, wd_settings.transfercipher) != 1)
		wd_log(LOG_ERR, "Could not set SSL cipher list '%s'", wd_settings.controlcipher);

	/* create locking mutexes */
	mutexes = CRYPTO_num_locks();
	wd_ssl_locks = (pthread_mutex_t *) malloc(mutexes * sizeof(pthread_mutex_t));
	
	for(i = 0; i < mutexes; i++)
		pthread_mutex_init(&(wd_ssl_locks[i]), NULL);
	
	/* set locking callbacks */
	CRYPTO_set_id_callback(wd_ssl_id_function);
	CRYPTO_set_locking_callback(wd_ssl_locking_function);
}



unsigned long wd_ssl_id_function(void) {
	return ((unsigned long) pthread_self());
}



void wd_ssl_locking_function(int mode, int n, const char * file, int line) {
	if(mode & CRYPTO_LOCK)
		pthread_mutex_lock(&(wd_ssl_locks[n]));
	else
		pthread_mutex_unlock(&(wd_ssl_locks[n]));
}



#pragma mark -

void * wd_utility_thread(void *arg) {
	while(wd_running) {
		/* check for config reload */
		if(wd_reload) {
			wd_log(LOG_INFO, "Signal HUP received, reloading configuration");
			wd_read_config();
			wd_reload = 0;
		}

		/* check all clients to see if they've gone idle */
		wd_update_clients();
		
		/* hotline subsystem */
		if(wd_settings.hotline)
			hl_update_clients();

		/* check all private chats and see if they're unpopulated */
		wd_update_chats();
		
		/* check all temp bans and see if they've expired */
		wd_update_tempbans();
	
		/* check all transfers and see if they've expired */
		wd_update_transfers();
		
		/* sleep and do it again */
		sleep(30);
	}

	return NULL;
}



void * wd_ctl_listen_thread(void *arg) {
	struct wd_client	*client;
	struct wd_chat		*chat;
	struct sockaddr_in	addr;
	struct hostent		*host;
	SSL					*ssl;
	int					sd, err, length;
	
	while(wd_running) {
		/* reset */
		length = sizeof(addr);
		sd = -1;
		ssl = NULL;
		client = NULL;
				
		/* get socket */
		sd = accept(wd_ctl_socket, (struct sockaddr *) &addr, &length);

		if(sd < 0) {
			if(errno != EINTR) {
				wd_log(LOG_WARNING, "Could not accept a connection for %s: %s",
					inet_ntoa(addr.sin_addr),
					strerror(errno));
			}

			goto close;
		}
		
		/* TCP connection ready, do SSL handshake */
		ssl = SSL_new(wd_ctl_ssl_ctx);
		
		if(!ssl) {
			wd_log(LOG_WARNING, "Could not create an SSL object for %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}

		if(SSL_set_fd(ssl, sd) != 1) {
			wd_log(LOG_WARNING, "Could not set the SSL file descriptor for %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}
		
		if(SSL_accept(ssl) != 1) {
			wd_log(LOG_WARNING, "Could not accept an SSL connection from %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}
		
		/* create a client */
		client = (struct wd_client *) malloc(sizeof(struct wd_client));
		memset(client, 0, sizeof(struct wd_client));

		/* set values */
		client->sd			= sd;
		client->port		= addr.sin_port;
		client->state		= WD_CLIENT_STATE_CONNECTED;
		client->login_time	= time(NULL);
		client->idle_time	= time(NULL);
		client->ssl			= ssl;
	
		/* copy strings */
		strlcpy(client->ip, (char *) inet_ntoa(addr.sin_addr), sizeof(client->ip));

		if((host = gethostbyaddr((char *) &addr.sin_addr, sizeof(addr.sin_addr), AF_INET)))
			strlcpy(client->host, host->h_name, sizeof(client->host));
		
		/* create mutexes */
		pthread_mutex_init(&(client->ssl_mutex), NULL);
		pthread_mutex_init(&(client->state_mutex), NULL);
		pthread_mutex_init(&(client->admin_mutex), NULL);
		pthread_mutex_init(&(client->transfers_mutex), NULL);
		
		/* get public chat */
		pthread_mutex_lock(&(wd_chats.mutex));
		chat = (wd_chats.first)->data;
		
		/* assign user id */
		client->uid = (chat->clients).last
			? 1 + ((struct wd_client *) (((chat->clients).last)->data))->uid
			: 1;
		
		/* add to public chat */
		wd_list_add(&(chat->clients), client);
		pthread_mutex_unlock(&(wd_chats.mutex));
		
		/* check to see if client is banned by IP */
		if(wd_check_ban(client->ip) < 0) {
			wd_sreply(client->ssl, 511, "Banned");

			wd_log(LOG_INFO, "Connect from %s denied", client->ip);

			goto close;
		}

		wd_log(LOG_INFO, "Connect from %s", client->ip);
			
		/* spawn a client thread */
		if((err = pthread_create(&(client->thread), NULL, wd_ctl_thread, client)) < 0) {
			wd_log(LOG_WARNING, "Could not create a thread: %s", strerror(err));

			goto close;
		}
		
		/* all done */
		continue;

close:
		/* close down client */
		if(ssl) {
			if(SSL_shutdown(ssl) == 0)
				SSL_shutdown(ssl);
			
			SSL_free(ssl);
		}
			
		if(sd > 0)
			close(sd);
		
		/* delete client */
		if(client) {
			client->ssl = NULL;
			client->sd = -1;
			client->state = WD_CLIENT_STATE_DISCONNECTED;

			wd_log(LOG_INFO, "Disconnect from %s", client->ip);
			wd_delete_client(client);
		}
	}
	
	return NULL;
}



void * wd_xfer_listen_thread(void *arg) {
	struct wd_list_node		*node;
	struct wd_transfer		*transfer;
	pthread_t				thread;
	SSL						*ssl;
	struct sockaddr_in		addr;
	char					buffer[BUFSIZ], *p;
	size_t					bytes;
	int						sd, length, err, found;

	while(wd_running) {
		/* reset */
		length = sizeof(addr);
		sd = -1;
		ssl = NULL;
		transfer = NULL;
		found = 0;
		
		/* get socket */
		sd = accept(wd_xfer_socket, (struct sockaddr *) &addr, &length);
		
		if(sd < 0) {
			if(errno != EINTR)
				wd_log(LOG_WARNING, "Could not accept a connection for %s: %s",
					inet_ntoa(addr.sin_addr),
					strerror(errno));
			
			goto close;
		}
		
		/* TCP connection ready, do SSL handshake */
		ssl = SSL_new(wd_xfer_ssl_ctx);
		
		if(!ssl) {
			wd_log(LOG_WARNING, "Could not create an SSL object for %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}

		if(SSL_set_fd(ssl, sd) != 1) {
			wd_log(LOG_WARNING, "Could not set the SSL file descriptor for %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}
		
		if(SSL_accept(ssl) != 1) {
			wd_log(LOG_WARNING, "Could not accept an SSL connection from %s: %s",
				inet_ntoa(addr.sin_addr),
				ERR_reason_error_string(ERR_get_error()));
			
			goto close;
		}
		
		/* read from client */
		bytes = SSL_read(ssl, buffer, sizeof(buffer));
		buffer[bytes] = '\0';
		
		/* strip separator */
		if((p = strstr(buffer, WD_MESSAGE_SEPARATOR)))
			*p = '\0';
		
		/* start after space */
		if((p = strchr(buffer, ' ')))
			p++;
		else
			goto close;
		
		/* find transfer */
		pthread_mutex_lock(&(wd_transfers.mutex));
		for(node = wd_transfers.first; node != NULL; node = node->next) {
			transfer = node->data;
			
			if(strcmp(p, transfer->hash) == 0) {
				found = 1;
				
				break;
			}
		}
		pthread_mutex_unlock(&(wd_transfers.mutex));
		
		/* make sure we got a transfer */
		if(!found)
			goto close;
		
		/* make sure it's from the expected client */
		if(strcmp(transfer->client->ip, inet_ntoa(addr.sin_addr)) != 0)
			goto close;
		
		/* spawn a transfer thread */
		transfer->ssl = ssl;
		transfer->sd = sd;
		
		if(transfer->type == WD_XFER_DOWNLOAD)
			err = pthread_create(&thread, 0, wd_download_thread, node);
		else
			err = pthread_create(&thread, 0, wd_upload_thread, node);
		
		if(err < 0) {
			wd_log(LOG_WARNING, "Could not create a thread: %s", strerror(err));

			goto close;
		}

		/* all done */
		continue;

close:
		if(ssl) {
			if(SSL_shutdown(ssl) == 0)
				SSL_shutdown(ssl);
			
			SSL_free(ssl);
		}
			
		if(sd > 0)
			close(sd);
	}
	
	return NULL;
}



#ifdef HAVE_CORESERVICES_CORESERVICES_H
void * wd_cf_thread(void *arg) {
	CFStringRef		name, description, service_name;

	while(wd_running) {
		name = CFStringCreateWithCString(NULL, wd_settings.name,
										 kCFStringEncodingUTF8);
		description = CFStringCreateWithCString(NULL, wd_settings.description, 
												kCFStringEncodingUTF8);

		service_name = CFStringCreateWithFormat(NULL, NULL,
			CFSTR("%@%s%@"),
			name,
			WD_FIELD_SEPARATOR,
			description);

		wd_net_service	= CFNetServiceCreate(NULL, CFSTR(""), CFSTR("_wired._tcp"),
											 service_name, wd_settings.port);

		CFNetServiceRegister(wd_net_service, NULL);
		
		CFRelease(wd_net_service);
		CFRelease(service_name);
		CFRelease(description);
		CFRelease(name);
	}

	return NULL;
}
#endif



#pragma mark -

struct wd_client * wd_get_client(unsigned long uid, unsigned long cid) {
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	struct wd_client		*client, *value = NULL;

	/* find uid on chat */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		if(chat->cid == cid) {
			for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
				client = client_node->data;
				
				if(client->uid == uid) {
					value = client;
					
					break;
				}
			}
			
			break;
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));

	return value;
}



void wd_delete_client(struct wd_client *client) {
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	struct wd_client		*peer;
	
	/* remove the client from all chat lists we find it on */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
			peer = client_node->data;
			
			if(peer->sd == client->sd)
				wd_list_delete(&(chat->clients), client_node);
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
	/* free mutexes */
	pthread_mutex_destroy(&(client->ssl_mutex));
	pthread_mutex_destroy(&(client->state_mutex));
	pthread_mutex_destroy(&(client->admin_mutex));
	pthread_mutex_destroy(&(client->transfers_mutex));
	
	/* close SSL socket */
	if(client->ssl) {
		if(client->sd > 0) {
			if(SSL_shutdown(client->ssl) == 0)
				SSL_shutdown(client->ssl);
		}
	
		SSL_free(client->ssl);
	}
	
	/* close TCP/IP socket */
	if(client->sd > 0)
		close(client->sd);

	/* free client */
	free(client);
}



#pragma mark -

void wd_update_clients(void) {
	struct wd_list			*clients;
	struct wd_list_node		*node;
	struct wd_client		*client;

	/* get public chat */
	pthread_mutex_lock(&(wd_chats.mutex));
	clients = &(((struct wd_chat *) ((wd_chats.first)->data))->clients);

	/* loop over public chat */
	for(node = clients->first; node != NULL; node = node->next) {
		client = node->data;
		
		if(!client->idle && client->idle_time + wd_settings.idletime < (unsigned int) time(NULL)) {
			client->idle = 1;
			
			/* broadcast a user change */
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
				
			/* hotline subsystem */
			if(wd_settings.hotline) {
				wd_hl_relay_nick(client->uid, client->nick, client->icon,
								 client->idle, client->admin);
			}
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
}



void wd_update_chats(void) {
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	int						count;

	/* loop over chats (skipping public) and remove the empty ones */
	pthread_mutex_lock(&(wd_chats.mutex));
	for(chat_node = (wd_chats.first)->next; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		count = 0;
		
		for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next)
			count++;
		
		if(count == 0) {
			wd_list_free(&(chat->clients));
			wd_list_delete(&wd_chats, chat_node);
			
			free(chat);
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
}



#pragma mark -

void wd_reply(unsigned int n, char *fmt, ...) {
	struct wd_client	*client = (struct wd_client *) pthread_getspecific(wd_client_key);
	char				*inbuffer, *outbuffer;
	size_t				bytes;
	va_list				ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&inbuffer, fmt, ap) < 0 || inbuffer == NULL)
		return;

	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%s", n, inbuffer, WD_MESSAGE_SEPARATOR);
	
	SSL_write(client->ssl, outbuffer, bytes);
	
	free(outbuffer);
	free(inbuffer);
	
	va_end(ap);
}



void wd_sreply(SSL *ssl, unsigned int n, char *fmt, ...) {
	char			*inbuffer, *outbuffer;
	size_t			bytes;
	va_list			ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&inbuffer, fmt, ap) == -1 || inbuffer == NULL)
		return;
	
	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%s", n, inbuffer, WD_MESSAGE_SEPARATOR);

	SSL_write(ssl, outbuffer, bytes);
	
	free(outbuffer);
	free(inbuffer);
	
	va_end(ap);
}



void wd_broadcast(unsigned long cid, unsigned int n, char *fmt, ...) {
	struct wd_list_node		*chat_node, *client_node;
	struct wd_chat			*chat;
	struct wd_client		*client;
	char					*inbuffer, *outbuffer;
	size_t					bytes;
	va_list					ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&inbuffer, fmt, ap) < 0 || inbuffer == NULL)
		return;
	
	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%s", n, inbuffer, WD_MESSAGE_SEPARATOR);
	
	for(chat_node = wd_chats.first; chat_node != NULL; chat_node = chat_node->next) {
		chat = chat_node->data;
		
		if(chat->cid == cid) {
			for(client_node = (chat->clients).first; client_node != NULL; client_node = client_node->next) {
				client = client_node->data;
				
				if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
					pthread_mutex_lock(&(client->ssl_mutex));
					SSL_write(client->ssl, outbuffer, bytes);
					pthread_mutex_unlock(&(client->ssl_mutex));
				}
			}
			break;
		}
	}

	free(outbuffer);
	free(inbuffer);

	va_end(ap);
}
