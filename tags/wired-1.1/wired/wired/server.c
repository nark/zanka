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

#include "accounts.h"
#include "banlist.h"
#include "commands.h"
#include "files.h"
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

bool						wd_tracker;
int							wd_tracker_socket;
struct sockaddr_in			wd_tracker_addr;
char						wd_tracker_key[WD_STRING_SIZE];
RSA							*wd_tracker_rsa;

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
	wd_ctl_addr.sin_port			= htons(wd_frozen_settings.port);

	/* bind to all available addresses if none found in config */
	if(strlen(wd_frozen_settings.address) == 0) {
		wd_ctl_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	} else {
		if(!inet_aton(wd_frozen_settings.address, &wd_ctl_addr.sin_addr)) {
			host = gethostbyname(wd_frozen_settings.address);

			if(!host) {
				wd_log(LOG_ERR, "Could not resolve hostname %s: %s",
					wd_frozen_settings.address, hstrerror(h_errno));
			}
			
			memcpy(&wd_ctl_addr.sin_addr, host->h_addr, sizeof(wd_ctl_addr.sin_addr));
		}
	}

	/* init the transfer address */
	memset(&wd_xfer_addr, 0, sizeof(wd_xfer_addr));
	wd_xfer_addr.sin_family			= AF_INET;
	wd_xfer_addr.sin_port			= htons(wd_frozen_settings.port + 1);
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
	if(wd_frozen_settings.zeroconf) {
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

void wd_init_tracker(void) {
	struct hostent	*host;
	char			*p, tracker[WD_STRING_SIZE];
	int				port = 0;
	
	/* copy the tracker setting */
	strlcpy(tracker, wd_frozen_settings.tracker, sizeof(tracker));
	
	if((p = strchr(tracker, ':'))) {
		if(strlen(p) == 1) {
			wd_log(LOG_WARNING, "Could not register with the tracker: %s", 
				wd_frozen_settings.tracker);

			return;
		}
		
		port = strtoul(p + 1, NULL, 10);
		*p = '\0';
	}
	
	if(!port)
		port = 2002;
	
	/* init the tracker address */
	memset(&wd_tracker_addr, 0, sizeof(wd_tracker_addr));
	wd_tracker_addr.sin_family		= AF_INET;
	wd_tracker_addr.sin_port		= htons(port);

	/* look up tracker host */
	if(!inet_aton(tracker, &wd_tracker_addr.sin_addr)) {
		host = gethostbyname(tracker);

		if(!host) {
			wd_log(LOG_ERR, "Could not resolve hostname %s: %s",
				tracker, hstrerror(h_errno));
		}
			
		memcpy(&wd_tracker_addr.sin_addr, host->h_addr, sizeof(wd_tracker_addr.sin_addr));
	}
	
	/* create a socket */
	wd_tracker_socket = socket(AF_INET, SOCK_DGRAM, 0);
	
	if(wd_tracker_socket < 0)
		wd_log(LOG_ERR, "Could not create socket for tracker: %s", strerror(errno));
}



void wd_tracker_register(void) {
	SSL_CTX		*ssl_ctx = NULL;
	SSL			*ssl = NULL;
	X509		*cert = NULL;
	EVP_PKEY	*pkey = NULL;
	char		*p, buffer[1024];
	int			sd = -1, bytes;
	
	/* update files */
	wd_update_files(".", true);
	
	/* not yet */
	wd_tracker = false;
	
	/* create TCP socket */
	sd = socket(AF_INET, SOCK_STREAM, 0);
	
	if(sd < 0) {
		wd_log(LOG_WARNING, "Could not create socket for tracker: %s", strerror(errno));
		
		goto end;
	}
	
	/* connect TCP socket */
	if(connect(sd, (struct sockaddr *) &wd_tracker_addr, sizeof(wd_tracker_addr)) < 0) {
		wd_log(LOG_WARNING, "Could not connect to tracker: %s", strerror(errno));
		
		goto end;
	}

	/* create SSL context */
	ssl_ctx = SSL_CTX_new(TLSv1_client_method());
	
	if(!ssl_ctx) {
		wd_log(LOG_WARNING, "Could not create an SSL context for tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}

	if(SSL_CTX_set_cipher_list(ssl_ctx, "ALL") != 1) {
		wd_log(LOG_ERR, "Could not set SSL cipher list: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}

	/* create SSL socket */
	ssl = SSL_new(ssl_ctx);
	
	if(!ssl) {
		wd_log(LOG_WARNING, "Could not create an SSL object for tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
			
		goto end;
	}

	if(SSL_set_fd(ssl, sd) != 1) {
		wd_log(LOG_WARNING, "Could not set the SSL file descriptor for tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}
		
	if(SSL_connect(ssl) != 1) {
		wd_log(LOG_WARNING, "Could not connect to tracker via SSL: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}
	
	/* send HELLO command */
	snprintf(buffer, sizeof(buffer), "HELLO%s",
		WD_MESSAGE_SEPARATOR);
	SSL_write(ssl, buffer, strlen(buffer));
	
	/* read 200 message */
	bytes = SSL_read(ssl, buffer, sizeof(buffer));
	
	if(bytes < 4) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			ERR_get_error() != 0
				? ERR_reason_error_string(ERR_get_error())
				: strerror(errno));
		
		goto end;
	}
	
	buffer[bytes] = '\0';
	
	if((p = strstr(buffer, WD_MESSAGE_SEPARATOR)))
		*p = '\0';

	if(strncmp(buffer, "200", 3) != 0) {
		wd_log(LOG_WARNING, "Could not register with the tracker: Unexpected reply \"%s\"",
			buffer);
		
		goto end;
	}
	
	/* send CLIENT command */
	snprintf(buffer, sizeof(buffer), "CLIENT %s%s",
		wd_version_string,
		WD_MESSAGE_SEPARATOR);
	SSL_write(ssl, buffer, strlen(buffer));

	/* send REGISTER command */
	snprintf(buffer, sizeof(buffer), "REGISTER %s%s%s%s%s%s%u%s%s%s",
		wd_settings.category,
		WD_FIELD_SEPARATOR,
		wd_frozen_settings.url,
		WD_FIELD_SEPARATOR,
		wd_settings.name,
		WD_FIELD_SEPARATOR,
		wd_settings.bandwidth,
		WD_FIELD_SEPARATOR,
		wd_settings.description,
		WD_MESSAGE_SEPARATOR);
	SSL_write(ssl, buffer, strlen(buffer));

	/* read 700 message */
	bytes = SSL_read(ssl, buffer, sizeof(buffer));
	
	if(bytes < 4) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			ERR_get_error() != 0
				? ERR_reason_error_string(ERR_get_error())
				: strerror(errno));
		
		goto end;
	}
	
	buffer[bytes] = '\0';
	
	if((p = strstr(buffer, WD_MESSAGE_SEPARATOR)))
		*p = '\0';
	
	if(strncmp(buffer, "700", 3) != 0) {
		wd_log(LOG_WARNING, "Could not register with the tracker: Unexpected reply \"%s\"",
			buffer);
		
		goto end;
	}
	
	/* copy the plaintext key */
	strlcpy(wd_tracker_key, buffer + 4, sizeof(wd_tracker_key));
	
	/* get the certificate */
	cert = SSL_get_peer_certificate(ssl);
	
	if(!cert) {
		wd_log(LOG_INFO, "Could not get certificate from the tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}

	/* get the public key */
	pkey = X509_get_pubkey(cert);

	if(!pkey) {
		wd_log(LOG_INFO, "Could not get public key from the tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}

	/* get the RSA key */
	if(wd_tracker_rsa) {
		RSA_free(wd_tracker_rsa);
		wd_tracker_rsa = NULL;
	}
	
	wd_tracker_rsa = EVP_PKEY_get1_RSA(pkey);

	if(!wd_tracker_rsa) {
		wd_log(LOG_INFO, "Could not get public key from the tracker: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		goto end;
	}
	
	/* all done */
	wd_tracker = true;
	wd_log(LOG_INFO, "Registered with the tracker %s",
		wd_frozen_settings.tracker);
	
end:
	/* clean up */
	if(ssl) {
		if(SSL_shutdown(ssl) == 0)
			SSL_shutdown(ssl);
		
		SSL_free(ssl);
	}
	
	if(ssl_ctx)
		SSL_CTX_free(ssl_ctx);
	
	if(cert)
		X509_free(cert);
	
	if(pkey)
		EVP_PKEY_free(pkey);
	
	if(sd > 0)
		close(sd);
}



void wd_tracker_update(void) {
	char		*user, buffer[1024], e_buffer[1024];
	int			bytes, guest = 0, download = 0;

	/* check for guest account */
	user = wd_getuser("guest");
	
	if(user != NULL) {
		guest = 1;
		
		if(wd_getpriv("guest", WD_PRIV_DOWNLOAD) == 1)
			download = 1;
		
		free(user);
	}
	
	/* create message */
	snprintf(buffer, sizeof(buffer), "UPDATE %s%s%u%s%u%s%u%s%u%s%llu%s",
		wd_tracker_key,
		WD_FIELD_SEPARATOR,
		wd_current_users,
		WD_FIELD_SEPARATOR,
		guest,
		WD_FIELD_SEPARATOR,
		download,
		WD_FIELD_SEPARATOR,
		wd_files_count,
		WD_FIELD_SEPARATOR,
		wd_files_size,
		WD_MESSAGE_SEPARATOR);
	
	memset(e_buffer, 0, sizeof(e_buffer));
		
	/* encrypt with tracker's public key */
	bytes = RSA_public_encrypt(strlen(buffer), buffer, e_buffer,
		wd_tracker_rsa, RSA_PKCS1_OAEP_PADDING);
	
	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not encrypt tracker message: %s",
			ERR_reason_error_string(ERR_get_error()));
		
		return;
	}
	
	/* send message */
	sendto(wd_tracker_socket, e_buffer, bytes, 0,
		(struct sockaddr *) &wd_tracker_addr, sizeof(wd_tracker_addr));
}



#pragma mark -

void wd_init_ssl(void) {
	int			mutexes, i;
	bool		use_dh = false;
	
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

	if(strlen(wd_frozen_settings.certificate) == 0) {
		/* no certificate configured, use DH */
		use_dh = true;
	} else {
		/* load SSL certificate */
		if(SSL_CTX_use_certificate_chain_file(wd_ctl_ssl_ctx, wd_frozen_settings.certificate) != 1 ||
		   SSL_CTX_use_certificate_chain_file(wd_xfer_ssl_ctx, wd_frozen_settings.certificate) != 1) {
			wd_log(LOG_WARNING, "Could not load certificate %s", 
				wd_frozen_settings.certificate);
			
			use_dh = true;
		}
	
		if(SSL_CTX_use_PrivateKey_file(wd_ctl_ssl_ctx, wd_frozen_settings.certificate, SSL_FILETYPE_PEM) != 1 ||
		   SSL_CTX_use_PrivateKey_file(wd_xfer_ssl_ctx, wd_frozen_settings.certificate, SSL_FILETYPE_PEM) != 1) {
			wd_log(LOG_WARNING, "Could not load key file %s", 
				wd_frozen_settings.certificate);
			
			use_dh = true;
		}
	}
	
	/* init DH */
	if(use_dh) {
		wd_log(LOG_WARNING, "Falling back to anonymous ciphers");
		wd_init_dh();
	}

	/* set our desired cipher list */
	if(SSL_CTX_set_cipher_list(wd_ctl_ssl_ctx, wd_frozen_settings.controlcipher) != 1 ||
	   SSL_CTX_set_cipher_list(wd_xfer_ssl_ctx, wd_frozen_settings.transfercipher) != 1) {
		wd_log(LOG_ERR, "Could not set SSL cipher list '%s'", 
			wd_frozen_settings.controlcipher);
	}

	/* create locking mutexes */
	mutexes = CRYPTO_num_locks();
	wd_ssl_locks = (pthread_mutex_t *) malloc(mutexes * sizeof(pthread_mutex_t));
	
	for(i = 0; i < mutexes; i++)
		pthread_mutex_init(&(wd_ssl_locks[i]), NULL);
	
	/* set locking callbacks */
	CRYPTO_set_id_callback(wd_ssl_id_function);
	CRYPTO_set_locking_callback(wd_ssl_locking_function);
}



void wd_init_dh(void) {
	DH				*dh;
	unsigned char	dh1024_p[] = {
		0xBC,0xBB,0x2B,0x4F,0x58,0x58,0x9C,0x4D,0x46,0x0D,0xBB,0x9E,
		0x4D,0x85,0x69,0x56,0x43,0x5E,0xFB,0xC8,0xF6,0xC0,0xAC,0x8E,
		0xCB,0xF6,0x0B,0x38,0x8F,0x25,0xD6,0x7A,0xA1,0x26,0xC4,0x74,
		0x74,0x98,0x96,0x3F,0x96,0x90,0x3B,0x00,0x6E,0xE3,0x0A,0x61,
		0xA9,0xA2,0x62,0x49,0xDA,0x7D,0xE0,0x6B,0x8F,0xA7,0x89,0x7F,
		0x41,0x09,0x09,0xA3,0xA2,0x5F,0x2C,0xD3,0x77,0x26,0x8D,0x81,
		0x33,0x04,0xEF,0x40,0x75,0xB2,0xCF,0xBA,0xEF,0xD5,0x08,0xF4,
		0x9E,0x30,0xD2,0x57,0x12,0xD6,0xEA,0x86,0xCA,0x10,0x7B,0x4B,
		0x93,0x42,0x7E,0x79,0x42,0x36,0x5D,0x2B,0x23,0xDB,0x7E,0xAB,
		0xDB,0xFD,0x1B,0xDA,0x86,0x49,0x15,0x92,0x41,0x56,0xDD,0x68,
		0x2C,0x7F,0xAA,0x34,0x56,0x80,0xA5,0x8B };
	unsigned char	dh1024_g[] = { 0x02 };

	/* create DH key */
	dh = DH_new();
	
	if(!dh) {
		wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
			ERR_reason_error_string(ERR_get_error()));
	}

	dh->p = BN_bin2bn(dh1024_p, sizeof(dh1024_p), NULL);
	dh->g = BN_bin2bn(dh1024_g, sizeof(dh1024_g), NULL);

	if(!dh->p || !dh->g) {
		wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
			ERR_reason_error_string(ERR_get_error()));
	}

	/* assign DH key */
	SSL_CTX_set_tmp_dh(wd_ctl_ssl_ctx, dh);
	SSL_CTX_set_tmp_dh(wd_xfer_ssl_ctx, dh);

	DH_free(dh);
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
	time_t			now, last_tracker = 0, last_register = 0;
	
	while(wd_running) {
		/* get current time */
		now = time(NULL);
		
		/* check for config reload */
		if(wd_reload) {
			wd_log(LOG_INFO, "Signal HUP received, reloading configuration");
			wd_read_config(false);
			
			if(wd_tracker)
				wd_tracker_register();

			wd_reload = 0;
		}

		/* check all clients to see if they've gone idle */
		wd_update_clients();
		
		/* hotline subsystem */
		if(wd_frozen_settings.hotline)
			hl_update_clients();

		/* check all private chats and see if they're unpopulated */
		wd_update_chats();
		
		/* check all temp bans and see if they've expired */
		wd_update_tempbans();
	
		/* check all transfers and see if they've expired */
		wd_update_transfers();
		
		/* check if we should re-register with the tracker */
		if(wd_frozen_settings._register) {
			if(now - last_register > 3600) {
				wd_tracker_register();
			
				last_register = time(NULL);
			}
		}
		
		/* check if we should update the tracker */
		if(wd_tracker) {
			if(now - last_tracker > 60) {
				wd_tracker_update();
			
				last_tracker = time(NULL);
			}
		}
		
		/* sleep and do it again */
		sleep(10);
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
		client->buffer		= (char *) malloc(WD_BUFFER_SIZE);
		client->buffer_size	= WD_BUFFER_SIZE;
	
		/* copy strings */
		strlcpy(client->ip, (char *) inet_ntoa(addr.sin_addr), sizeof(client->ip));

		if((host = gethostbyaddr((char *) &addr.sin_addr, sizeof(addr.sin_addr), AF_INET)))
			strlcpy(client->host, host->h_name, sizeof(client->host));
		
		/* create mutexes */
		pthread_mutex_init(&(client->ssl_mutex), NULL);
		pthread_mutex_init(&(client->state_mutex), NULL);
		pthread_mutex_init(&(client->admin_mutex), NULL);
		
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
		if(strcmp(transfer->ip, inet_ntoa(addr.sin_addr)) != 0)
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
	CFStringRef		name;

	while(wd_running) {
		name = CFStringCreateWithCString(NULL, wd_frozen_settings.name,
										 kCFStringEncodingUTF8);

		wd_net_service = CFNetServiceCreate(NULL, CFSTR(""), CFSTR("_wired._tcp"),
											name, wd_frozen_settings.port);

		CFNetServiceRegister(wd_net_service, NULL);
		
		CFRelease(wd_net_service);
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
			
			if(peer->sd == client->sd) {
				wd_list_delete(&(chat->clients), client_node);
				
				break;
			}
		}
	}
	pthread_mutex_unlock(&(wd_chats.mutex));
	
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

	/* free mutexes */
	pthread_mutex_destroy(&(client->ssl_mutex));
	pthread_mutex_destroy(&(client->state_mutex));
	pthread_mutex_destroy(&(client->admin_mutex));
//	pthread_mutex_destroy(&(client->transfers_mutex));
	
	/* free client */
	free(client->buffer);
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
			if(wd_frozen_settings.hotline) {
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
