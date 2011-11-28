/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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
#include <sys/time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netdb.h>
#include <net/if.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#ifdef WI_SSL
#include <openssl/err.h>
#include <openssl/ssl.h>
#endif

#ifdef HAVE_IFADDRS_H
#include <ifaddrs.h>
#endif

#include <wired/wi-array.h>
#include <wired/wi-assert.h>
#include <wired/wi-address.h>
#include <wired/wi-date.h>
#include <wired/wi-macros.h>
#include <wired/wi-lock.h>
#include <wired/wi-private.h>
#include <wired/wi-socket.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>
#include <wired/wi-thread.h>

#define _WI_SOCKET_BUFFER_MAX_SIZE		131072


struct _wi_socket_context {
	wi_runtime_base_t					base;
	
#ifdef WI_SSL
	SSL_CTX								*ssl_ctx;
	DH									*dh;
	
	RSA									*pub_rsa;
	RSA									*priv_rsa;
	
	wi_boolean_t						certificate;
#endif
};


struct _wi_socket {
	wi_runtime_base_t					base;
	
	wi_address_t						*address;
	wi_socket_type_t					type;
	wi_uinteger_t						direction;
	int									sd;

#ifdef WI_SSL
	SSL									*ssl;
#endif
	
	void								*data;
	
	wi_string_t							*buffer;
	
	wi_boolean_t						interactive;
	wi_boolean_t						close;
	wi_boolean_t						broken;
};


#if defined(WI_SSL) && defined(WI_PTHREADS)
static unsigned long					_wi_socket_ssl_id_function(void);
static void								_wi_socket_ssl_locking_function(int, int, const char *, int);
#endif

static void								_wi_socket_context_dealloc(wi_runtime_instance_t *);

static void								_wi_socket_dealloc(wi_runtime_instance_t *);
static wi_string_t *					_wi_socket_description(wi_runtime_instance_t *);

static wi_boolean_t						_wi_socket_set_option(wi_socket_t *, int, int, int);
static wi_boolean_t						_wi_socket_get_option(wi_socket_t *, int, int, int *);


#if defined(WI_SSL) && defined(WI_PTHREADS)
static wi_array_t						*_wi_socket_ssl_locks;
#endif

static wi_runtime_id_t					_wi_socket_context_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_socket_context_runtime_class = {
	"wi_socket_context_t",
	_wi_socket_context_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};

static wi_runtime_id_t					_wi_socket_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_socket_runtime_class = {
	"wi_socket_t",
	_wi_socket_dealloc,
	NULL,
	NULL,
	_wi_socket_description,
	NULL
};



void wi_socket_register(void) {
	_wi_socket_context_runtime_id = wi_runtime_register_class(&_wi_socket_context_runtime_class);
	_wi_socket_runtime_id = wi_runtime_register_class(&_wi_socket_runtime_class);
}



void wi_socket_initialize(void) {
#ifdef WI_SSL
#ifdef WI_PTHREADS
	wi_lock_t		*lock;
	wi_uinteger_t	i, count;
#endif

	SSL_library_init();

#ifdef WI_PTHREADS
	count = CRYPTO_num_locks();
	_wi_socket_ssl_locks = wi_array_init_with_capacity(wi_array_alloc(), count);
	
	for(i = 0; i < count; i++) {
		lock = wi_lock_init(wi_lock_alloc());
		wi_array_add_data(_wi_socket_ssl_locks, lock);
		wi_release(lock);
	}

	CRYPTO_set_id_callback(_wi_socket_ssl_id_function);
	CRYPTO_set_locking_callback(_wi_socket_ssl_locking_function);
#endif
#endif
}



#pragma mark -

#if defined(WI_SSL) && defined(WI_PTHREADS)

static unsigned long _wi_socket_ssl_id_function(void) {
	return ((unsigned long) wi_thread_current_thread());
}



static void _wi_socket_ssl_locking_function(int mode, int n, const char *file, int line) {
	wi_lock_t		*lock;
	
	lock = WI_ARRAY(_wi_socket_ssl_locks, n);
	
	if(mode & CRYPTO_LOCK)
		wi_lock_lock(lock);
	else
		wi_lock_unlock(lock);
}

#endif



#pragma mark -

void wi_socket_exit_thread(void) {
#ifdef WI_SSL
	ERR_remove_state(0);
#endif
}



#pragma mark -

wi_runtime_id_t wi_socket_context_runtime_id(void) {
	return _wi_socket_context_runtime_id;
}



#pragma mark -

wi_socket_context_t * wi_socket_context_alloc(void) {
	return wi_runtime_create_instance(_wi_socket_context_runtime_id, sizeof(wi_socket_context_t));
}



wi_socket_context_t * wi_socket_context_init(wi_socket_context_t *context) {
	return context;
}



static void _wi_socket_context_dealloc(wi_runtime_instance_t *instance) {
#ifdef WI_SSL
	wi_socket_context_t		*context = instance;
	
	if(context->ssl_ctx)
		SSL_CTX_free(context->ssl_ctx);
	
	if(context->dh)
		DH_free(context->dh);
#endif
}



#pragma mark -

wi_boolean_t wi_socket_context_set_ssl_type(wi_socket_context_t *context, wi_socket_ssl_type_t type) {
#ifdef WI_SSL
	SSL_METHOD		*method = NULL;
	
	switch(type) {
		case WI_SOCKET_SSL_CLIENT:
			method = TLSv1_client_method();
			break;

		case WI_SOCKET_SSL_SERVER:
			method = TLSv1_server_method();
			break;
	}
	
	context->ssl_ctx = SSL_CTX_new(method);
	
	if(!context->ssl_ctx) {
		wi_error_set_openssl_error();
		
		return false;
	}
	
	SSL_CTX_set_mode(context->ssl_ctx, SSL_MODE_AUTO_RETRY);
	SSL_CTX_set_quiet_shutdown(context->ssl_ctx, 1);
	
	return true;
#else
	wi_error_set_libwired_error(WI_ERROR_SOCKET_NOSSL);
	
	return false;
#endif
}



wi_boolean_t wi_socket_context_set_ssl_certificate(wi_socket_context_t *context, wi_string_t *path) {
#ifdef WI_SSL
	const char		*certificate;
	
	context->certificate = false;
	
	certificate = wi_string_cstring(path);
	
	if(SSL_CTX_use_certificate_chain_file(context->ssl_ctx, certificate) != 1) {
		wi_error_set_openssl_error();

		return false;
	}
	
	if(SSL_CTX_use_PrivateKey_file(context->ssl_ctx, certificate, SSL_FILETYPE_PEM) != 1) {
		wi_error_set_openssl_error();

		return false;
	}
	
	context->certificate = true;
	
	return true;
#else
	wi_error_set_libwired_error(WI_ERROR_SOCKET_NOSSL);
	
	return false;
#endif
}



wi_boolean_t wi_socket_context_set_ssl_privkey(wi_socket_context_t *context, wi_string_t *path) {
#ifdef WI_SSL
	FILE		*fp;
	
	fp = fopen(wi_string_cstring(path), "r");
	
	if(!fp) {
		wi_error_set_errno(errno);
		
		return false;
	}
		
	context->priv_rsa = PEM_read_RSAPrivateKey(fp, NULL, 0, NULL);
	
	if(!context->priv_rsa)
		wi_error_set_openssl_error();
	
	fclose(fp);
	
	return (context->priv_rsa != NULL);
#else
	wi_error_set_libwired_error(WI_ERROR_SOCKET_NOSSL);
	
	return false;
#endif
}



void wi_socket_context_set_ssl_pubkey(wi_socket_context_t *context, void *rsa) {
#ifdef WI_SSL
	if(context->pub_rsa != rsa) {
		if(context->pub_rsa)
			RSA_free(context->pub_rsa);
		
		context->pub_rsa = rsa;
	}
#endif
}



wi_boolean_t wi_socket_context_set_ssl_ciphers(wi_socket_context_t *context, wi_string_t *ciphers) {
#ifdef WI_SSL
	if(SSL_CTX_set_cipher_list(context->ssl_ctx, wi_string_cstring(ciphers)) != 1) {
		wi_error_set_libwired_error(WI_ERROR_SOCKET_NOVALIDCIPHER);

		return false;
	}
	
	return true;
#else
	wi_error_set_libwired_error(WI_ERROR_SOCKET_NOSSL);
	
	return false;
#endif
}



wi_boolean_t wi_socket_context_set_ssl_dh(wi_socket_context_t *context, const unsigned char *p, size_t p_size, const unsigned char *g, size_t g_size) {
#ifdef WI_SSL
	context->dh = DH_new();
	
	if(!context->dh) {
		wi_error_set_openssl_error();

		return false;
	}

	context->dh->p = BN_bin2bn(p, p_size, NULL);
	context->dh->g = BN_bin2bn(g, g_size, NULL);

	if(!context->dh->p || !context->dh->g) {
		wi_error_set_openssl_error();

		DH_free(context->dh);
		context->dh = NULL;
		
		return false;
	}
	
	return true;
#else
	wi_error_set_libwired_error(WI_ERROR_SOCKET_NOSSL);
	
	return false;
#endif
}



#pragma mark -

wi_runtime_id_t wi_socket_runtime_id(void) {
	return _wi_socket_runtime_id;
}



#pragma mark -

wi_socket_t * wi_socket_alloc(void) {
	return wi_runtime_create_instance(_wi_socket_runtime_id, sizeof(wi_socket_t));
}



wi_socket_t * wi_socket_init_with_address(wi_socket_t *_socket, wi_address_t *address, wi_socket_type_t type) {
	_socket->address	= wi_copy(address);
	_socket->close		= true;
	_socket->buffer		= wi_string_init_with_capacity(wi_string_alloc(), WI_SOCKET_BUFFER_SIZE);
	_socket->type		= type;

	_socket->sd			= socket(wi_address_family(_socket->address), _socket->type, 0);
	
	if(_socket->sd < 0) {
		wi_error_set_errno(errno);
		
		wi_release(_socket);
		
		return NULL;
	}
	
	if(!_wi_socket_set_option(_socket, SOL_SOCKET, SO_REUSEADDR, 1)) {
		wi_release(_socket);
		
		return NULL;
	}

	return _socket;
}



wi_socket_t * wi_socket_init_with_descriptor(wi_socket_t *socket, int sd) {
	socket->sd			= sd;
	socket->buffer		= wi_string_init_with_capacity(wi_string_alloc(), WI_SOCKET_BUFFER_SIZE);
	
	return socket;
}



static void _wi_socket_dealloc(wi_runtime_instance_t *instance) {
	wi_socket_t		*socket = instance;
	
	wi_socket_close(socket);
	
	wi_release(socket->address);
	wi_release(socket->buffer);
}



static wi_string_t * _wi_socket_description(wi_runtime_instance_t *instance) {
	wi_socket_t		*socket = instance;

	return wi_string_with_format(WI_STR("<%@ %p>{sd = %d, address = %@}"),
		wi_runtime_class_name(socket),
		socket,
		socket->sd,
		socket->address);
}



#pragma mark -

static wi_boolean_t _wi_socket_set_option(wi_socket_t *socket, int level, int name, int option) {
	if(setsockopt(socket->sd, level, name, &option, sizeof(option)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



static wi_boolean_t _wi_socket_get_option(wi_socket_t *socket, int level, int name, int *option) {
	socklen_t		length;
	
	length = sizeof(*option);
	
	if(getsockopt(socket->sd, level, name, option, &length) < 0) {
		wi_error_set_errno(errno);
		
		*option = 0;
		
		return false;
	}
	
	return true;
}



#pragma mark -

wi_address_t * wi_socket_address(wi_socket_t *socket) {
	return socket->address;
}



int wi_socket_descriptor(wi_socket_t *socket) {
	return socket->sd;
}



void * wi_socket_ssl(wi_socket_t *socket) {
#ifdef WI_SSL
	return socket->ssl;
#else
	return NULL;
#endif
}



void * wi_socket_ssl_pubkey(wi_socket_t *socket) {
#ifdef WI_SSL
	RSA			*rsa = NULL;
	X509		*x509 = NULL;
	EVP_PKEY	*pkey = NULL;

	x509 = SSL_get_peer_certificate(socket->ssl);

	if(!x509) {
		wi_error_set_openssl_error();
		
		goto end;
	}
	
	pkey = X509_get_pubkey(x509);
	
	if(!pkey) {
		wi_error_set_openssl_error();

		goto end;
	}
	
	rsa = EVP_PKEY_get1_RSA(pkey);
	
	if(!rsa)
		wi_error_set_openssl_error();

end:
	if(x509)
		X509_free(x509);
	
	if(pkey)
		EVP_PKEY_free(pkey);
	
	return rsa;
#else
	return NULL;
#endif
}



wi_string_t * wi_socket_cipher_version(wi_socket_t *socket) {
#ifdef WI_SSL
	return wi_string_with_cstring(SSL_get_cipher_version(socket->ssl));
#else
	return NULL;
#endif
}



wi_string_t * wi_socket_cipher_name(wi_socket_t *socket) {
#ifdef WI_SSL
	return wi_string_with_cstring(SSL_get_cipher_name(socket->ssl));
#else
	return NULL;
#endif
}



wi_uinteger_t wi_socket_cipher_bits(wi_socket_t *socket) {
#ifdef WI_SSL
	return SSL_get_cipher_bits(socket->ssl, NULL);
#else
	return 0;
#endif
}



wi_string_t * wi_socket_certificate_name(wi_socket_t *socket) {
#ifdef WI_SSL
	X509			*x509 = NULL;
	EVP_PKEY		*pkey = NULL;
	wi_string_t		*string = NULL;

	x509 = SSL_get_peer_certificate(socket->ssl);

	if(!x509)
		goto end;

	pkey = X509_get_pubkey(x509);

	if(!pkey)
		goto end;
	
	switch(EVP_PKEY_type(pkey->type)) {
		case EVP_PKEY_RSA:
			string = wi_string_init_with_cstring(wi_string_alloc(), "RSA");
			break;

		case EVP_PKEY_DSA:
			string = wi_string_init_with_cstring(wi_string_alloc(), "DSA");
			break;

		case EVP_PKEY_DH:
			string = wi_string_init_with_cstring(wi_string_alloc(), "DH");
			break;

		default:
			break;
	}
	
end:
	if(x509)
		X509_free(x509);

	if(pkey)
		EVP_PKEY_free(pkey);

	return wi_autorelease(string);
#else
	return NULL;
#endif
}



wi_uinteger_t wi_socket_certificate_bits(wi_socket_t *socket) {
#ifdef WI_SSL
	X509			*x509 = NULL;
	EVP_PKEY		*pkey = NULL;
	wi_uinteger_t	bits = 0;

	x509 = SSL_get_peer_certificate(socket->ssl);

	if(!x509)
		goto end;

	pkey = X509_get_pubkey(x509);

	if(!pkey)
		goto end;
	
	bits = 8 * EVP_PKEY_size(pkey);
	
end:
	if(x509)
		X509_free(x509);

	if(pkey)
		EVP_PKEY_free(pkey);

	return bits;
#else
	return 0;
#endif
}



wi_string_t * wi_socket_certificate_hostname(wi_socket_t *socket) {
#ifdef WI_SSL
	X509			*x509;
	wi_string_t		*string;
	char			hostname[MAXHOSTNAMELEN];

	x509 = SSL_get_peer_certificate(socket->ssl);

	if(!x509)
		return NULL;

	X509_NAME_get_text_by_NID(X509_get_subject_name(x509),
							  NID_commonName,
							  hostname,
							  sizeof(hostname));
	
	string = wi_string_init_with_cstring(wi_string_alloc(), hostname);
	
	X509_free(x509);
	
	return wi_autorelease(string);
#else
	return NULL;
#endif
}



#pragma mark -

void wi_socket_set_port(wi_socket_t *socket, wi_uinteger_t port) {
	wi_address_set_port(socket->address, port);
}



wi_uinteger_t wi_socket_port(wi_socket_t *socket) {
	return wi_address_port(socket->address);
}



void wi_socket_set_direction(wi_socket_t *socket, wi_uinteger_t direction) {
	socket->direction = direction;
}



wi_uinteger_t wi_socket_direction(wi_socket_t *socket) {
	return socket->direction;
}



void wi_socket_set_data(wi_socket_t *socket, void *data) {
	socket->data = data;
}



void * wi_socket_data(wi_socket_t *socket) {
	return socket->data;
}




void wi_socket_set_blocking(wi_socket_t *socket, wi_boolean_t blocking) {
	int		flags;

	flags = fcntl(socket->sd, F_GETFL);

	if(flags < 0) {
		wi_error_set_errno(errno);

		return;
	}

	if(blocking)
		flags &= ~O_NONBLOCK;
	else
		flags |= O_NONBLOCK;

	if(fcntl(socket->sd, F_SETFL, flags) < 0) {
		wi_error_set_errno(errno);

		return;
	}
}



wi_boolean_t wi_socket_blocking(wi_socket_t *socket) {
	int		flags;
	
	flags = fcntl(socket->sd, F_GETFL);
		
	if(flags < 0) {
		wi_error_set_errno(errno);

		return false;
	}
	
	return !(flags & O_NONBLOCK);
}



void wi_socket_set_interactive(wi_socket_t *socket, wi_boolean_t interactive) {
	if(socket->type == WI_SOCKET_TCP && interactive)
		_wi_socket_set_option(socket, IPPROTO_TCP, TCP_NODELAY, 1);
	
	if(wi_address_family(socket->address) == WI_ADDRESS_IPV4)
		_wi_socket_set_option(socket, IPPROTO_IP, IP_TOS, interactive ? IPTOS_LOWDELAY : IPTOS_THROUGHPUT);
	
	socket->interactive = interactive;
}



wi_boolean_t wi_socket_interactive(wi_socket_t *socket) {
	return socket->interactive;
}



int wi_socket_error(wi_socket_t *socket) {
	int		error;
	
	WI_ASSERT(socket->type == WI_SOCKET_TCP, "%@ is not a TCP socket", socket);
	
	if(!_wi_socket_get_option(socket, SOL_SOCKET, SO_ERROR, &error))
		return errno;
	
	return error;
}



#pragma mark -

wi_socket_t * wi_socket_wait_multiple(wi_array_t *array, wi_time_interval_t timeout) {
	wi_enumerator_t		*enumerator;
	wi_socket_t			*socket, *accept_socket = NULL;
	struct timeval		tv;
	fd_set				rfds, wfds;
	int					state, max_sd;

	tv = wi_dtotv(timeout);
	max_sd = -1;

	FD_ZERO(&rfds);
	FD_ZERO(&wfds);

	wi_array_rdlock(array);
	
	enumerator = wi_array_data_enumerator(array);
	
	while((socket = wi_enumerator_next_data(enumerator))) {
		if(wi_string_length(socket->buffer) > 0) {
			accept_socket = socket;
			
			break;
		}
		
		if(socket->direction & WI_SOCKET_READ)
			FD_SET(socket->sd, &rfds);

		if(socket->direction & WI_SOCKET_WRITE)
			FD_SET(socket->sd, &wfds);

		if(socket->sd > max_sd)
			max_sd = socket->sd;
	}

	wi_array_unlock(array);
	
	if(accept_socket)
		return accept_socket;
	
	state = select(max_sd + 1, &rfds, &wfds, NULL, (timeout > 0.0) ? &tv : NULL);
	
	if(state < 0) {
		wi_error_set_errno(errno);

		return NULL;
	}
	
	wi_array_rdlock(array);

	enumerator = wi_array_data_enumerator(array);
	
	while((socket = wi_enumerator_next_data(enumerator))) {
		if(FD_ISSET(socket->sd, &rfds) || FD_ISSET(socket->sd, &wfds)) {
			accept_socket = socket;

			break;
		}
	}
	
	wi_array_unlock(array);
	
	return accept_socket;
}



wi_socket_state_t wi_socket_wait(wi_socket_t *socket, wi_time_interval_t timeout) {
	if(wi_string_length(socket->buffer) > 0)
		return WI_SOCKET_READY;

	return wi_socket_wait_descriptor(socket->sd,
									 timeout,
									 (socket->direction & WI_SOCKET_READ),
									 (socket->direction & WI_SOCKET_WRITE));
}



wi_socket_state_t wi_socket_wait_descriptor(int sd, wi_time_interval_t timeout, wi_boolean_t read, wi_boolean_t write) {
	struct timeval	tv;
	fd_set			rfds, wfds;
	int				state;
	
	tv = wi_dtotv(timeout);
	
	FD_ZERO(&rfds);
	FD_ZERO(&wfds);
	
	if(read)
		FD_SET(sd, &rfds);
	
	if(write)
		FD_SET(sd, &wfds);
	
	state = select(sd + 1, &rfds, &wfds, NULL, (timeout > 0.0) ? &tv : NULL);
	
	if(state < 0) {
		wi_error_set_errno(errno);
		
		return WI_SOCKET_ERROR;
	}
	else if(state == 0) {
		wi_error_set_errno(ETIMEDOUT);
		
		return WI_SOCKET_TIMEOUT;
	}
	
	return WI_SOCKET_READY;
}



#pragma mark -

wi_boolean_t wi_socket_listen(wi_socket_t *_socket, wi_uinteger_t backlog) {
	struct sockaddr		*sa;
	wi_uinteger_t		length;
	
	sa		= wi_address_sa(_socket->address);
	length	= wi_address_sa_length(_socket->address);
	
	if(bind(_socket->sd, sa, length) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}

	if(_socket->type == WI_SOCKET_TCP) {
		if(listen(_socket->sd, backlog) < 0) {
			wi_error_set_errno(errno);

			return false;
		}
	}
	
	_socket->direction = WI_SOCKET_READ;
	
	return true;
}



wi_boolean_t wi_socket_connect(wi_socket_t *socket, wi_socket_context_t *context, wi_time_interval_t timeout) {
	struct sockaddr		*sa;
	wi_socket_state_t	state;
	wi_uinteger_t		length;
	int					err;
#ifdef WI_SSL
	int					ret;
#endif
	wi_boolean_t		blocking;
	
	blocking = wi_socket_blocking(socket);

	if(blocking)
		wi_socket_set_blocking(socket, false);
	
	sa		= wi_address_sa(socket->address);
	length	= wi_address_sa_length(socket->address);

	err		= connect(socket->sd, sa, length);
	
	if(err < 0) {
		if(errno != EINPROGRESS) {
			wi_error_set_errno(errno);
			
			return false;
		}
		
		do {
			state = wi_socket_wait_descriptor(socket->sd, 1.0, true, true);
			timeout -= 1.0;
		} while(state == WI_SOCKET_TIMEOUT && timeout >= 0.0);
		
		if(state == WI_SOCKET_ERROR)
			return false;
		
		if(timeout <= 0.0) {
			wi_error_set_errno(ETIMEDOUT);
			
			return false;
		}
		
		err = wi_socket_error(socket);
		
		if(err != 0) {
			wi_error_set_errno(err);
			
			return false;
		}
	}

#ifdef WI_SSL
	if(context && context->ssl_ctx) {
		socket->ssl = SSL_new(context->ssl_ctx);
		
		if(!socket->ssl) {
			wi_error_set_openssl_error();
			
			return false;
		}
		
		if(SSL_set_fd(socket->ssl, socket->sd) != 1) {
			wi_error_set_openssl_error();

			return false;
		}
		
		ret = SSL_connect(socket->ssl);
		
		if(ret != 1) {
			do {
				err = SSL_get_error(socket->ssl, ret);

				if(err != SSL_ERROR_WANT_READ && err != SSL_ERROR_WANT_WRITE) {
					wi_error_set_openssl_error();
					
					return false;
				}
				
				state = wi_socket_wait_descriptor(socket->sd, 1.0, (err == SSL_ERROR_WANT_READ), (err == SSL_ERROR_WANT_WRITE));
				
				if(state == WI_SOCKET_ERROR)
					break;
				else if(state == WI_SOCKET_READY) {
					ret = SSL_connect(socket->ssl);
					
					if(ret == 1)
						break;
				}
				
				timeout -= 1.0;
			} while(timeout >= 0.0);
			
			if(state == WI_SOCKET_ERROR)
				return false;
			
			if(timeout <= 0.0) {
				wi_error_set_errno(ETIMEDOUT);
				
				return false;
			}
		}
	}
#endif

	if(blocking)
		wi_socket_set_blocking(socket, true);

	socket->direction = WI_SOCKET_READ;
	
	return true;
}



wi_socket_t * wi_socket_accept_multiple(wi_array_t *array, wi_socket_context_t *context, wi_time_interval_t timeout, wi_address_t **address) {
	wi_socket_t		*socket;
	
	*address = NULL;
	socket = wi_socket_wait_multiple(array, 0.0);
	
	if(!socket)
		return NULL;
	
	return wi_socket_accept(socket, context, timeout, address);
}



wi_socket_t * wi_socket_accept(wi_socket_t *accept_socket, wi_socket_context_t *context, wi_time_interval_t timeout, wi_address_t **address) {
	wi_socket_t					*socket;
#ifdef WI_SSL
	SSL							*ssl = NULL;
#endif
	struct sockaddr_storage		ss;
	socklen_t					length;
	int							sd;
	
	length = sizeof(ss);
	sd = accept(accept_socket->sd, (struct sockaddr *) &ss, &length);
	
	*address = (length > 0) ? wi_autorelease(wi_address_init_with_sa(wi_address_alloc(), (struct sockaddr *) &ss)) : NULL;

	if(sd < 0) {
		wi_error_set_errno(errno);
		
		goto err;
	}
	
#ifdef WI_SSL
	if(context && context->ssl_ctx) {
		ssl = SSL_new(context->ssl_ctx);

		if(!ssl) {
			wi_error_set_openssl_error();
			
			goto err;
		}

		if(SSL_set_fd(ssl, sd) != 1) {
			wi_error_set_openssl_error();
			
			goto err;
		}

		if(!context->certificate && context->dh) {
			if(SSL_set_tmp_dh(ssl, context->dh) != 1) {
				wi_error_set_openssl_error();
				
				goto err;
			}
		}
		
		if(timeout > 0.0) {
			if(wi_socket_wait_descriptor(sd, timeout, true, false) != WI_SOCKET_READY)
				goto err;
		}

		if(SSL_accept(ssl) != 1) {
			wi_error_set_openssl_error();
			
			goto err;
		}
	}
#endif

	socket = wi_socket_init_with_descriptor(wi_socket_alloc(), sd);

	socket->close		= true;
	socket->address		= wi_retain(*address);
	socket->type		= accept_socket->type;
	socket->direction	= WI_SOCKET_READ;
	socket->interactive	= accept_socket->interactive;

#ifdef WI_SSL
	socket->ssl			= ssl;
#endif
	
	return wi_autorelease(socket);
	
err:
#ifdef WI_SSL
	if(ssl)
		SSL_free(ssl);
#endif

	if(sd >= 0)
		close(sd);

	return NULL;
}



void wi_socket_close(wi_socket_t *socket) {
#ifdef WI_SSL
	if(socket->ssl) {
		if(!socket->broken) {
			if(SSL_shutdown(socket->ssl) == 0)
				SSL_shutdown(socket->ssl);
		}

		SSL_free(socket->ssl);
		
		socket->ssl = NULL;
	}
#endif

	if(socket->close && socket->sd >= 0) {
		close(socket->sd);
		
		socket->sd = -1;
	}
}



#pragma mark -

wi_integer_t wi_socket_sendto(wi_socket_t *socket, wi_socket_context_t *context, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	int				bytes;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);

	bytes = wi_socket_sendto_buffer(socket, context, wi_string_cstring(string), wi_string_length(string));
	
	wi_release(string);

	return bytes;
}



wi_integer_t wi_socket_sendto_buffer(wi_socket_t *socket, wi_socket_context_t *context, const char *buffer, size_t length) {
	wi_address_t	*address;
	char			*outbuffer = NULL;
	wi_integer_t	bytes;
	
	address = wi_socket_address(socket);

#ifdef WI_SSL
	if(context && context->pub_rsa) {
		outbuffer = wi_malloc(RSA_size(context->pub_rsa));
		bytes = RSA_public_encrypt(length, (unsigned char *) buffer, (unsigned char *) outbuffer,
			context->pub_rsa, RSA_PKCS1_OAEP_PADDING);
		
		if(bytes < 0) {
			wi_error_set_openssl_error();
			
			goto end;
		}
		
		bytes = sendto(socket->sd, outbuffer, bytes, 0,
			wi_address_sa(address), wi_address_sa_length(address));
	} else {
#endif
		bytes = sendto(socket->sd, buffer, length, 0,
			wi_address_sa(address), wi_address_sa_length(address));
#ifdef WI_SSL
	}
#endif
	
	if(bytes < 0) {
		wi_error_set_errno(errno);
		
		goto end;
	}

end:
	if(outbuffer)
		wi_free(outbuffer);
	
	return bytes;
}



wi_integer_t wi_socket_recvfrom_multiple(wi_array_t *array, wi_socket_context_t *context, char *buffer, size_t length, wi_address_t **address) {
	wi_socket_t		*socket;
	
	*address = NULL;
	socket = wi_socket_wait_multiple(array, 0.0);
	
	if(!socket)
		return -1;
	
	return wi_socket_recvfrom(socket, context, buffer, length, address);
}



wi_integer_t wi_socket_recvfrom(wi_socket_t *socket, wi_socket_context_t *context, char *buffer, size_t length, wi_address_t **address) {
	struct sockaddr_storage		ss;
	char						*inbuffer = NULL;
	socklen_t					sslength;
	wi_integer_t				bytes;
	
	sslength = sizeof(ss);
	
#ifdef WI_SSL
	if(context && context->priv_rsa) {
		inbuffer = wi_malloc(length);
		bytes = recvfrom(socket->sd, inbuffer, length, 0, (struct sockaddr *) &ss, &sslength);
		
		if(bytes < 0) {
			wi_error_set_errno(errno);
			
			goto end;
		}
		
		bytes = RSA_private_decrypt(bytes, (unsigned char *) inbuffer, (unsigned char *) buffer,
			context->priv_rsa, RSA_PKCS1_OAEP_PADDING);
		
		if(bytes < 0) {
			wi_error_set_openssl_error();

			goto end;
		}
	} else {
#endif
		bytes = recvfrom(socket->sd, buffer, length, 0, (struct sockaddr *) &ss, &sslength);

		if(bytes < 0) {
			wi_error_set_errno(errno);
			
			goto end;
		}
#ifdef WI_SSL
	}
#endif

end:
	*address = (sslength > 0) ? wi_autorelease(wi_address_init_with_sa(wi_address_alloc(), (struct sockaddr *) &ss)) : NULL;

	if(inbuffer)
		wi_free(inbuffer);

	return bytes;
}



#pragma mark -

wi_integer_t wi_socket_write(wi_socket_t *socket, wi_time_interval_t timeout, wi_string_t *fmt, ...) {
	wi_string_t		*string;
	wi_integer_t	bytes;
	va_list			ap;

	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	bytes = wi_socket_write_buffer(socket, timeout, wi_string_cstring(string), wi_string_length(string));
	
	wi_release(string);

	return bytes;
}



wi_integer_t wi_socket_write_buffer(wi_socket_t *socket, wi_time_interval_t timeout, const void *buffer, size_t length) {
	wi_integer_t	bytes;
	
	if(timeout > 0.0) {
		if(wi_socket_wait_descriptor(socket->sd, timeout, false, true) != WI_SOCKET_READY)
			return -1;
	}

#ifdef WI_SSL
	if(socket->ssl) {
		bytes = SSL_write(socket->ssl, buffer, length);

		if(bytes < 0) {
			wi_error_set_openssl_error();

			socket->broken = true;
		}
	} else {
#endif
		bytes = write(socket->sd, buffer, length);
		
		if(bytes < 0)
			wi_error_set_errno(errno);
#ifdef WI_SSL
	}
#endif
	
	return bytes;
}



wi_string_t * wi_socket_read(wi_socket_t *socket, wi_time_interval_t timeout, size_t length) {
	wi_string_t		*string;
	char			buffer[WI_SOCKET_BUFFER_SIZE];
	int				bytes = -1;
	
	string = wi_string_init_with_capacity(wi_string_alloc(), length);
	
	while(length > sizeof(buffer)) {
		bytes = wi_socket_read_buffer(socket, timeout, buffer, sizeof(buffer));
		
		if(bytes <= 0)
			goto end;
		
		wi_string_append_bytes(string, buffer, bytes);
		
		length -= bytes;
	}

	if(length > 0) {
		bytes = wi_socket_read_buffer(socket, timeout, buffer, length);
		
		if(bytes <= 0)
			goto end;
		
		wi_string_append_bytes(string, buffer, bytes);
	}

end:
	if(wi_string_length(string) == 0) {
		if(bytes < 0) {
			wi_release(string);
			
			string = NULL;
		}
	}

	return wi_autorelease(string);
}



wi_string_t * wi_socket_read_to_string(wi_socket_t *socket, wi_time_interval_t timeout, wi_string_t *separator) {
	wi_string_t		*string, *substring;
	wi_uinteger_t	index;
	
	index = wi_string_index_of_string(socket->buffer, separator, 0);
	
	if(index != WI_NOT_FOUND) {
		substring = wi_string_substring_to_index(socket->buffer, index + wi_string_length(separator));
		
		wi_string_delete_characters_in_range(socket->buffer, wi_make_range(0, wi_string_length(substring)));

		return substring;
	}
	
	while((string = wi_socket_read(socket, timeout, WI_SOCKET_BUFFER_SIZE))) {
		if(wi_string_length(string) == 0)
			return string;

		wi_string_append_string(socket->buffer, string);

		index = wi_string_index_of_string(socket->buffer, separator, 0);
		
		if(index == WI_NOT_FOUND) {
			if(wi_string_length(socket->buffer) > _WI_SOCKET_BUFFER_MAX_SIZE) {
				substring = wi_string_substring_to_index(socket->buffer, _WI_SOCKET_BUFFER_MAX_SIZE);

				wi_string_delete_characters_in_range(socket->buffer, wi_make_range(0, wi_string_length(substring)));
				
				return substring;
			}
		} else {
			substring = wi_string_substring_to_index(socket->buffer, index + wi_string_length(separator));
			
			wi_string_delete_characters_in_range(socket->buffer, wi_make_range(0, wi_string_length(substring)));
			
			return substring;
		}
	}
	
	return NULL;
}



wi_integer_t wi_socket_read_buffer(wi_socket_t *socket, wi_time_interval_t timeout, void *buffer, size_t length) {
	wi_integer_t	bytes;
	
	if(timeout > 0.0) {
#ifdef WI_SSL
		if(socket->ssl && SSL_pending(socket->ssl) == 0) {
#endif
			if(wi_socket_wait_descriptor(socket->sd, timeout, true, false) != WI_SOCKET_READY)
				return -1;
#ifdef WI_SSL
		}
#endif
	}

#ifdef WI_SSL
	if(socket->ssl) {
		bytes = SSL_read(socket->ssl, buffer, length);
		
		if(bytes <= 0) {
			wi_error_set_openssl_error();

			socket->broken = true;
		}
	} else {
#endif
		bytes = read(socket->sd, buffer, length);
		
		if(bytes < 0)
			wi_error_set_errno(errno);
		else if(bytes == 0)
			wi_error_set_libwired_error(WI_ERROR_SOCKET_EOF);
#ifdef WI_SSL
	}
#endif

	return bytes;
}
