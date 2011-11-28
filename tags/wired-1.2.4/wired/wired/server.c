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
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


int							wd_ctl_socket, wd_xfer_socket;
struct sockaddr_in			wd_ctl_addr, wd_xfer_addr;

SSL_CTX						*wd_ctl_ssl_ctx, *wd_xfer_ssl_ctx;
pthread_mutex_t				*wd_ssl_locks;
bool						wd_ssl_loaded_certificate;
DH							*wd_ssl_tmp_dh;

pthread_key_t				wd_client_key;

wd_uid_t					wd_current_uid;

wd_list_t					wd_chats;

bool						wd_tracker;
int							wd_tracker_socket;
struct sockaddr_in			wd_tracker_addr;
char						wd_tracker_key[WD_STRING_SIZE];
RSA							*wd_tracker_rsa;
pthread_mutex_t				wd_tracker_register_mutex = PTHREAD_MUTEX_INITIALIZER;

#ifdef HAVE_CORESERVICES_CORESERVICES_H
CFNetServiceRef				wd_net_service;
#endif


void wd_init_server(void) {
	wd_chat_t			*chat;
	struct hostent		*host;
	pthread_t			thread;
	int					on = 1, err;

	/* create our linked lists */
	wd_list_create(&wd_tempbans);
	wd_list_create(&wd_chats);
	wd_list_create(&wd_transfers);
	
	/* create the public chat */
	chat = (wd_chat_t *) malloc(sizeof(wd_chat_t));
	memset(chat, 0, sizeof(wd_chat_t));
	
	/* init public chat */
	chat->cid = WD_PUBLIC_CHAT;
	wd_list_create(&(chat->clients));
	wd_list_add(&wd_chats, chat);

	/* create a pthread key to associate all client threads with */
	pthread_key_create(&wd_client_key, NULL);
	
	/* create the sockets */
	wd_ctl_socket		= socket(AF_INET, SOCK_STREAM, 0);
	wd_xfer_socket		= socket(AF_INET, SOCK_STREAM, 0);

	if(wd_ctl_socket < 0 || wd_xfer_socket < 0) {
		wd_log(LOG_ERR, "Could not create a socket: %s",
			strerror(errno));
	}

	/* set socket options */
	if(setsockopt(wd_ctl_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0 ||
	   setsockopt(wd_xfer_socket, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on)) < 0) {
		wd_log(LOG_ERR, "Could not set socket options: %s",
			strerror(errno));
	}

	if(setsockopt(wd_ctl_socket, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on)) < 0) {
		wd_log(LOG_ERR, "Could not set socket options: %s",
			strerror(errno));
	}
	
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
			
			memcpy(&wd_ctl_addr.sin_addr, host->h_addr,
				   sizeof(wd_ctl_addr.sin_addr));
		}
	}

	/* init the transfer address */
	memset(&wd_xfer_addr, 0, sizeof(wd_xfer_addr));
	wd_xfer_addr.sin_family			= AF_INET;
	wd_xfer_addr.sin_port			= htons(wd_frozen_settings.port + 1);
	wd_xfer_addr.sin_addr.s_addr	= wd_ctl_addr.sin_addr.s_addr;
	
	/* bind the sockets */
	if(bind(wd_ctl_socket, (struct sockaddr *) &wd_ctl_addr, sizeof(wd_ctl_addr)) < 0 ||
	   bind(wd_xfer_socket, (struct sockaddr *) &wd_xfer_addr, sizeof(wd_xfer_addr)) < 0) {
		wd_log(LOG_ERR, "Could not bind socket: %s",
			strerror(errno));
	}
	
	/* now listen */
	if(listen(wd_ctl_socket, 5) < 0 || listen(wd_xfer_socket, 5) < 0) {
		wd_log(LOG_ERR, "Could not listen on socket: %s",
			strerror(errno));
	}

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* spawn the Core Foundation run loop thread */
	if(wd_frozen_settings.zeroconf) {
		if((err = pthread_create(&thread, NULL, wd_cf_thread, NULL)) < 0) {
			wd_log(LOG_ERR, "Could not create a thread: %s",
				strerror(err));
		}
	}
#endif

	/* spawn the server threads... */
	if((err = pthread_create(&thread, NULL, wd_ctl_listen_thread, NULL)) < 0 ||
	   (err = pthread_create(&thread, NULL, wd_xfer_listen_thread, NULL)) < 0) {
		wd_log(LOG_ERR, "Could not create a thread: %s",
			strerror(err));
	}
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
		port = WD_TRACKER_PORT;
	
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
			
		memcpy(&wd_tracker_addr.sin_addr, host->h_addr,
			   sizeof(wd_tracker_addr.sin_addr));
	}
	
	/* create a socket */
	wd_tracker_socket = socket(AF_INET, SOCK_DGRAM, 0);
	
	if(wd_tracker_socket < 0) {
		wd_log(LOG_ERR, "Could not create a socket: %s",
			strerror(errno));
	}
}



void wd_tracker_register(void) {
	pthread_t	thread;
	int			err;

	if(pthread_mutex_trylock(&wd_tracker_register_mutex) == 0) {
		if((err = pthread_create(&thread, NULL, wd_tracker_register_thread, NULL)) < 0) {
			wd_log(LOG_ERR, "Could not create a thread: %s",
				strerror(err));
		}

		pthread_mutex_unlock(&wd_tracker_register_mutex);
	}
}



void * wd_tracker_register_thread(void *arg) {
	SSL_CTX		*ssl_ctx = NULL;
	SSL			*ssl = NULL;
	X509		*cert = NULL;
	EVP_PKEY	*pkey = NULL;
	char		buffer[1024];
	int			sd = -1, bytes, message;
	
	/* mark not available until we get a reply */
	wd_tracker = false;

	/* log */
	wd_log(LOG_INFO, "Registering with the tracker...");
	
	/* create TCP socket */
	sd = socket(AF_INET, SOCK_STREAM, 0);
	
	if(sd < 0) {
		wd_log(LOG_WARNING, "Could not create socket for tracker: %s",
			strerror(errno));
		
		goto end;
	}
	
	/* connect TCP socket */
	if(connect(sd, (struct sockaddr *) &wd_tracker_addr, sizeof(wd_tracker_addr)) < 0) {
		wd_log(LOG_WARNING, "Could not connect to tracker: %s",
			strerror(errno));
		
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
	bytes = wd_write(ssl, 5.0, "HELLO");

	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			wd_ssl_strerror());

		goto end;
	}

	/* read 200 message */
	bytes = wd_read(ssl, 5.0, buffer, sizeof(buffer));

	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			wd_ssl_strerror());

		goto end;
	}

	message = wd_get_message(buffer);

	if(message != 200) {
		wd_log(LOG_WARNING, "Could not register with the tracker: Unexpected reply %d",
			message);

		goto end;
	}

	/* send CLIENT command */
	bytes = wd_write(ssl, 5.0, "CLIENT %s", wd_version_string);

	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			wd_ssl_strerror());

		goto end;
	}

	/* send REGISTER command */
	bytes = wd_write(ssl, 5.0, "REGISTER %s%c%s%c%s%c%u%c%s",
		wd_settings.category,
		WD_FIELD_SEPARATOR,
		wd_frozen_settings.url,
		WD_FIELD_SEPARATOR,
		wd_settings.name,
		WD_FIELD_SEPARATOR,
		wd_settings.bandwidth,
		WD_FIELD_SEPARATOR,
		wd_settings.description);

	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			wd_ssl_strerror());

		goto end;
	}

	/* read 700 message */
	bytes = wd_read(ssl, 5.0, buffer, sizeof(buffer));

	if(bytes < 0) {
		wd_log(LOG_WARNING, "Could not read from tracker: %s",
			wd_ssl_strerror());

		goto end;
	}

	message = wd_get_message(buffer);

	if(message != 700) {
		wd_log(LOG_WARNING, "Could not register with the tracker: Unexpected reply %d",
			message);

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

	return NULL;
}



void wd_tracker_update(void) {
	char		*user, buffer[1024], e_buffer[1024];
	int			bytes, guest = 0, download = 0;

	/* check for guest account */
	user = wd_get_user("guest");
	
	if(user != NULL) {
		guest = 1;
		
		if(wd_get_priv_int("guest", WD_PRIV_DOWNLOAD) == 1)
			download = 1;
		
		free(user);
	}
	
	/* create message */
	snprintf(buffer, sizeof(buffer), "UPDATE %s%c%u%c%u%c%u%c%u%c%llu%c",
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
	int		mutexes, i;
	
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
	
	/* set auto retry flag */
	SSL_CTX_set_mode(wd_ctl_ssl_ctx, SSL_MODE_AUTO_RETRY);
	SSL_CTX_set_mode(wd_xfer_ssl_ctx, SSL_MODE_AUTO_RETRY);

	/* create locking mutexes */
	mutexes = CRYPTO_num_locks();
	wd_ssl_locks = (pthread_mutex_t *) malloc(mutexes * sizeof(pthread_mutex_t));
	
	for(i = 0; i < mutexes; i++)
		pthread_mutex_init(&(wd_ssl_locks[i]), NULL);
	
	/* set locking callbacks */
	CRYPTO_set_id_callback(wd_ssl_id_function);
	CRYPTO_set_locking_callback(wd_ssl_locking_function);

	/* init DH */
	wd_init_dh();
}



void wd_init_dh(void) {
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
	wd_ssl_tmp_dh = DH_new();
	
	if(!wd_ssl_tmp_dh) {
		wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
			ERR_reason_error_string(ERR_get_error()));
	}

	wd_ssl_tmp_dh->p = BN_bin2bn(dh1024_p, sizeof(dh1024_p), NULL);
	wd_ssl_tmp_dh->g = BN_bin2bn(dh1024_g, sizeof(dh1024_g), NULL);

	if(!wd_ssl_tmp_dh->p || !wd_ssl_tmp_dh->g) {
		wd_log(LOG_ERR, "Could not generate anonymous DH key: %s",
			ERR_reason_error_string(ERR_get_error()));
	}
}



void wd_apply_config_ssl(void) {
	/* set our desired cipher list */
	if(SSL_CTX_set_cipher_list(wd_ctl_ssl_ctx, wd_settings.controlcipher) != 1 ||
	   SSL_CTX_set_cipher_list(wd_xfer_ssl_ctx, wd_settings.transfercipher) != 1) {
		wd_log(LOG_ERR, "Could not set SSL cipher list '%s'", 
			wd_settings.controlcipher);
	}

	/* load SSL certificate */
	if(strlen(wd_settings.certificate) > 0) {
		wd_ssl_loaded_certificate = true;
		
		if(SSL_CTX_use_certificate_chain_file(wd_ctl_ssl_ctx, wd_settings.certificate) != 1 ||
		   SSL_CTX_use_certificate_chain_file(wd_xfer_ssl_ctx, wd_settings.certificate) != 1) {
			wd_log(LOG_WARNING, "Could not load certificate %s", 
				wd_settings.certificate);

			wd_ssl_loaded_certificate = false;
		}
	
		if(SSL_CTX_use_PrivateKey_file(wd_ctl_ssl_ctx, wd_settings.certificate, SSL_FILETYPE_PEM) != 1 ||
		   SSL_CTX_use_PrivateKey_file(wd_xfer_ssl_ctx, wd_settings.certificate, SSL_FILETYPE_PEM) != 1) {
			wd_log(LOG_WARNING, "Could not load key file %s", 
				wd_settings.certificate);

			wd_ssl_loaded_certificate = false;
		}
	}
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
	time_t			now, last_tracker, last_register, last_index;

	last_tracker = last_register = last_index = 0;
	
	while(wd_running) {
		/* get current time */
		now = time(NULL);
		
		/* check for config reload */
		if(wd_reload) {
			wd_log(LOG_INFO, "Signal HUP received, reloading configuration");
			wd_read_config();
			wd_apply_config();

			wd_reload = 0;
		}
		
		/* check for register reload */
		if(wd_reregister) {
			if(wd_frozen_settings._register && wd_settings._register) {
				wd_log(LOG_INFO, "Signal USR1 received, registering with tracker");
				wd_tracker_register();
			
				last_register = time(NULL);
			}
		
			wd_reregister = 0;
		}

		/* check for index reload */
		if(wd_reindex) {
			if(strlen(wd_settings.index) > 0) {
				wd_log(LOG_INFO, "Signal USR2 received, indexing files");
				wd_index_files();
			
				last_index = time(NULL);
			}
		
			wd_reindex = 0;
		}

		/* check all clients to see if they've gone idle */
		wd_update_clients();
		
		/* check all private chats and see if they're unpopulated */
		wd_update_chats();
		
		/* check all temp bans and see if they've expired */
		wd_update_tempbans();
	
		/* check all transfers and see if they've expired */
		wd_update_transfers();
		
		/* check if we should re-index the files */
		if(strlen(wd_settings.index) > 0) {
			if((wd_settings.indextime == 0 && last_index == 0) ||
			   (wd_settings.indextime != 0 &&
			    (unsigned int) (now - last_index) >= wd_settings.indextime)) {
				wd_index_files();
			
				last_index = time(NULL);
			}
		}

		/* check if we should re-register with the tracker */
		if(wd_frozen_settings._register && wd_settings._register) {
			if(now - last_register >= 3600) {
				wd_tracker_register();
			
				last_register = time(NULL);
			}
		}
		
		/* check if we should update the tracker */
		if(wd_tracker && wd_settings._register) {
			if(now - last_tracker >= 60) {
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
	wd_client_t			*client;
	wd_chat_t			*chat;
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
		
		if(!wd_ssl_loaded_certificate && wd_ssl_tmp_dh) {
			if(SSL_set_tmp_dh(ssl, wd_ssl_tmp_dh)) {
				wd_log(LOG_WARNING, "Falling back to anonymous DH key for %s",
					inet_ntoa(addr.sin_addr));
			} else {
				wd_log(LOG_WARNING, "Could not set DH key for %s: %s",
					inet_ntoa(addr.sin_addr),
					ERR_reason_error_string(ERR_get_error()));
			}
		}				
		
		if(SSL_accept(ssl) != 1) {
			wd_log(LOG_WARNING, "Could not accept an SSL connection from %s: %s",
				inet_ntoa(addr.sin_addr),
				wd_ssl_strerror());
			
			goto close;
		}
		
		/* create a client */
		client = (wd_client_t *) malloc(sizeof(wd_client_t));
		memset(client, 0, sizeof(wd_client_t));

		/* set values */
		client->sd			= sd;
		client->port		= addr.sin_port;
		client->state		= WD_CLIENT_STATE_CONNECTED;
		client->login_time	= time(NULL);
		client->idle_time	= time(NULL);
		client->ssl			= ssl;
		client->buffer_size	= WD_BUFFER_INITIAL_SIZE;
		
		/* allocate buffer */
		client->buffer = (char *) malloc(client->buffer_size);
		memset(client->buffer, 0, client->buffer_size);
	
		/* copy strings */
		strlcpy(client->ip, (char *) inet_ntoa(addr.sin_addr), sizeof(client->ip));

		if((host = gethostbyaddr((char *) &addr.sin_addr, sizeof(addr.sin_addr), AF_INET)))
			strlcpy(client->host, host->h_name, sizeof(client->host));
		
		/* create mutexes */
		pthread_mutex_init(&(client->ssl_mutex), NULL);
		pthread_mutex_init(&(client->flag_mutex), NULL);
		
		/* get public chat */
		chat = wd_get_chat(WD_PUBLIC_CHAT);
		
		/* assign user id */
		client->uid = wd_get_uid();
		
		/* add to public chat */
		WD_LIST_LOCK(wd_chats);
		wd_list_add(&(chat->clients), client);
		WD_LIST_UNLOCK(wd_chats);

		/* log */
		wd_log(LOG_INFO, "Connect from %s", client->ip);
			
		/* spawn a client thread */
		if((err = pthread_create(&(client->thread), NULL, wd_ctl_thread, client)) < 0) {
			wd_log(LOG_WARNING, "Could not create a thread: %s",
				strerror(err));

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
	wd_list_node_t			*node;
	wd_transfer_t			*transfer;
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
		
		if(!wd_ssl_loaded_certificate && wd_ssl_tmp_dh) {
			if(SSL_set_tmp_dh(ssl, wd_ssl_tmp_dh)) {
				wd_log(LOG_WARNING, "Falling back to anonymous DH key for %s",
					inet_ntoa(addr.sin_addr));
			} else {
				wd_log(LOG_WARNING, "Could not set DH key for %s: %s",
					inet_ntoa(addr.sin_addr),
					ERR_reason_error_string(ERR_get_error()));
			}
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
		if((p = strrchr(buffer, WD_MESSAGE_SEPARATOR)))
			*p = '\0';
		
		/* start after space */
		if((p = strchr(buffer, ' ')))
			p++;
		else
			goto close;
		
		/* find transfer */
		WD_LIST_LOCK(wd_transfers);
		WD_LIST_FOREACH(wd_transfers, node, transfer) {
			if(strcmp(p, transfer->hash) == 0) {
				found = 1;
				
				break;
			}
		}
		WD_LIST_UNLOCK(wd_transfers);
		
		/* make sure we got a transfer */
		if(!found)
			goto close;
		
		/* make sure it's from the expected client */
		if(strcmp(transfer->ip, inet_ntoa(addr.sin_addr)) != 0)
			goto close;
		
		/* spawn a transfer thread */
		transfer->ssl = ssl;
		transfer->sd = sd;
		
		if(transfer->type == WD_TRANSFER_DOWNLOAD)
			err = pthread_create(&thread, 0, wd_download_thread, node);
		else
			err = pthread_create(&thread, 0, wd_upload_thread, node);
		
		if(err < 0) {
			wd_log(LOG_WARNING, "Could not create a thread: %s",
				strerror(err));

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

		wd_net_service = CFNetServiceCreate(NULL, CFSTR(""),
											CFSTR(WD_ZEROCONF_NAME),
											name, wd_frozen_settings.port);

		CFNetServiceRegister(wd_net_service, NULL);
		
		CFRelease(wd_net_service);
		CFRelease(name);
	}

	return NULL;
}
#endif



#pragma mark -

wd_uid_t wd_get_uid(void) {
	wd_chat_t	*chat;
	
	chat = wd_get_chat(WD_PUBLIC_CHAT);
	
 	if(WD_LIST_COUNT(chat->clients) == 0)
		wd_current_uid = 0;
	
	return ++wd_current_uid;
}



wd_client_t * wd_get_client(wd_uid_t uid, wd_cid_t cid) {
	wd_list_node_t	*node;
	wd_chat_t		*chat;
	wd_client_t		*client, *result = NULL;
	
	/* get chat */
	chat = wd_get_chat(cid);
	
	if(!chat)
		return result;
	
	/* find uid on chat */
	WD_LIST_LOCK(chat->clients);
	WD_LIST_FOREACH(chat->clients, node, client) {
		if(client->uid == uid) {
			result = client;
			
			break;
		}
	}
	WD_LIST_UNLOCK(chat->clients);

	return result;
}



void wd_delete_client(wd_client_t *client) {
	wd_list_node_t	*chat_node, *client_node, *transfer_node, *transfer_node_next;
	wd_chat_t		*chat;
	wd_client_t		*peer;
	wd_transfer_t	*transfer;
	bool			update = false;
	
	/* remove the client from all chat lists we find it on */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(wd_chats, chat_node, chat) {
		WD_LIST_FOREACH(chat->clients, client_node, peer) {
			if(peer->sd == client->sd) {
				WD_LIST_DATA(client_node) = NULL;
				wd_list_delete(&(chat->clients), client_node);
				
				break;
			}
		}
	}
	WD_LIST_UNLOCK(wd_chats);
	
	/* delete all the client's transfers */
	WD_LIST_LOCK(wd_transfers);
	for(transfer_node = WD_LIST_FIRST(wd_transfers); transfer_node != NULL; transfer_node = transfer_node_next) {
		transfer_node_next = WD_LIST_NEXT(transfer_node);
		transfer = WD_LIST_DATA(transfer_node);

		if(transfer->client == client) {
			if(transfer->state != WD_TRANSFER_STATE_RUNNING) {
				wd_list_delete(&wd_transfers, transfer_node);
			} else {
				pthread_mutex_lock(&(transfer->flag_mutex));
				transfer->state = WD_TRANSFER_STATE_STOPPED;
				pthread_mutex_unlock(&(transfer->flag_mutex));
			}
			
			update = true;
		}
	}
	WD_LIST_UNLOCK(wd_transfers);

	/* update queue */
	if(update)
		wd_update_queue();

	/* close SSL socket */
	if(client->ssl) {
		if(SSL_shutdown(client->ssl) == 0)
			SSL_shutdown(client->ssl);
	
		SSL_free(client->ssl);
	}
	
	/* close TCP/IP socket */
	if(client->sd > 0)
		close(client->sd);

	/* free mutexes */
	pthread_mutex_destroy(&(client->ssl_mutex));
	pthread_mutex_destroy(&(client->flag_mutex));
	
	/* free client */
	free(client->image);
	free(client->buffer);
	free(client);
}



void wd_update_clients(void) {
	wd_list_node_t	*node;
	wd_chat_t		*chat;
	wd_client_t		*client;
	time_t			now;
	
	/* get public chat */
	chat = wd_get_chat(WD_PUBLIC_CHAT);
	now = time(NULL);

	/* loop over all clients */
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(chat->clients, node, client) {
		if(client->state == WD_CLIENT_STATE_LOGGED_IN && !client->idle &&
		   client->idle_time + wd_settings.idletime < (unsigned int) now) {
			client->idle = true;
			
			/* broadcast a user change */
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
	}
	WD_LIST_UNLOCK(wd_chats);
}



#pragma mark -

wd_chat_t * wd_get_chat(wd_cid_t cid) {
	wd_list_node_t	*node;
	wd_chat_t		*chat, *result = NULL;
	
	WD_LIST_LOCK(wd_chats);
	WD_LIST_FOREACH(wd_chats, node, chat) {
		if(chat->cid == cid) {
			result = chat;
			
			break;
		}
	}
	WD_LIST_UNLOCK(wd_chats);
	
	return result;
}



void wd_update_chats(void) {
	wd_list_node_t	*node, *node_next;
	wd_chat_t		*chat;
	
	/* loop over chats (skipping public) and remove the empty ones */
	WD_LIST_LOCK(wd_chats);
	for(node = WD_LIST_FIRST(wd_chats); node != NULL; node = node_next) {
		node_next = WD_LIST_NEXT(node);
		chat = WD_LIST_DATA(node);
		
		if(chat->cid == WD_PUBLIC_CHAT)
			continue;
		
		if(WD_LIST_COUNT(chat->clients) == 0) {
			wd_list_free(&(chat->clients));
			wd_list_delete(&wd_chats, node);
		}
	}
	WD_LIST_UNLOCK(wd_chats);
}



#pragma mark -

void wd_reply(unsigned int n, char *fmt, ...) {
	wd_client_t		*client = (wd_client_t *) pthread_getspecific(wd_client_key);
	char			*inbuffer, *outbuffer;
	size_t			bytes;
	va_list			ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&inbuffer, fmt, ap) < 0 || inbuffer == NULL)
		return;

	/* compose message */
	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%c",
		n, inbuffer, WD_MESSAGE_SEPARATOR);
	
	/* send */
	pthread_mutex_lock(&(client->ssl_mutex));
	SSL_write(client->ssl, outbuffer, bytes);
	pthread_mutex_unlock(&(client->ssl_mutex));
	
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
	
	/* compose message */
	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%c",
		n, inbuffer, WD_MESSAGE_SEPARATOR);

	/* send */
	SSL_write(ssl, outbuffer, bytes);
	
	free(outbuffer);
	free(inbuffer);
	
	va_end(ap);
}



void wd_broadcast(wd_cid_t cid, unsigned int n, char *fmt, ...) {
	wd_list_node_t	*chat_node, *client_node;
	wd_chat_t		*chat;
	wd_client_t		*client;
	char			*inbuffer, *outbuffer;
	size_t			bytes;
	va_list			ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&inbuffer, fmt, ap) < 0 || inbuffer == NULL)
		return;
	
	/* compose message */
	bytes = strlen(inbuffer) + 6;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%u %s%c",
		n, inbuffer, WD_MESSAGE_SEPARATOR);
	
	/* loop over all clients of chat (note, locking must done outside this function) */
	WD_LIST_FOREACH(wd_chats, chat_node, chat) {
		if(chat->cid == cid) {
			WD_LIST_FOREACH(chat->clients, client_node, client) {
				if(client->state == WD_CLIENT_STATE_LOGGED_IN) {
					/* send */
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



#pragma mark -

int wd_write(SSL *ssl, double timeout, char *fmt, ...) {
	struct timeval	tv, timeout_tv, now;
	fd_set			wfds;
	char			*inbuffer, *outbuffer = NULL;
	size_t			bytes;
	int				sd, state, result = -1;
	va_list			ap;

	va_start(ap, fmt);

	if(vasprintf(&inbuffer, fmt, ap) < 0 || inbuffer == NULL)
		goto end;

	/* compose message */
	bytes = strlen(inbuffer) + 2;
	outbuffer = (char *) malloc(bytes);
	bytes = snprintf(outbuffer, bytes, "%s%c",
		inbuffer, WD_MESSAGE_SEPARATOR);

	/* select until data can be sent or the timeout expires */
	if(timeout > 0.0) {
		sd = SSL_get_fd(ssl);
		gettimeofday(&now, NULL);
		timeout_tv = now;

		do {
			FD_ZERO(&wfds);
			FD_SET(sd, &wfds);

			tv.tv_sec = 1;
			tv.tv_usec = 0;
			state = select(sd + 1, NULL, &wfds, NULL, &tv);

			gettimeofday(&now, NULL);
			timeout -= now.tv_sec - timeout_tv.tv_sec;
			timeout -= (now.tv_usec - timeout_tv.tv_usec) / (double) 1000000;

			if(timeout <= 0.0) {
				errno = ETIMEDOUT;

				goto end;
			}
		} while(state == 0);
	}

	/* send */
	result = SSL_write(ssl, outbuffer, bytes);

end:
	/* clean up */
	free(outbuffer);
	free(inbuffer);

	va_end(ap);

	return result;
}



int wd_read(SSL *ssl, double timeout, char *buffer, size_t length) {
	struct timeval	tv, timeout_tv, now;
	fd_set			rfds;
	char			*p;
	int				sd, state, result = -1;

	/* select until data is available or the timeout expires */
	if(timeout > 0.0) {
		sd = SSL_get_fd(ssl);
		gettimeofday(&now, NULL);
		timeout_tv = now;

		do {
			FD_ZERO(&rfds);
			FD_SET(sd, &rfds);

			tv.tv_sec = 1;
			tv.tv_usec = 0;
			state = select(sd + 1, &rfds, NULL, NULL, &tv);

			gettimeofday(&now, NULL);
			timeout -= now.tv_sec - timeout_tv.tv_sec;
			timeout -= (now.tv_usec - timeout_tv.tv_usec) / (double) 1000000;

			if(timeout <= 0.0) {
				errno = ETIMEDOUT;

				goto end;
			}
		} while(state == 0);
	}

	/* read */
	result = SSL_read(ssl, buffer, length);
	buffer[result] = '\0';

	if((p = strrchr(buffer, WD_MESSAGE_SEPARATOR)))
		*p = '\0';

end:
	/* clean up */
	return result;
}



int wd_get_message(char *buffer) {
	char	message[4];

	strlcpy(message, buffer, sizeof(message));

	return strtol(message, NULL, 10);
}
