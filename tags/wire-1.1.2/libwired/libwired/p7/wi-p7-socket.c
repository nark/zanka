/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#ifdef WI_P7

#include <wired/wi-byteorder.h>
#include <wired/wi-crypto.h>
#include <wired/wi-error.h>
#include <wired/wi-log.h>
#include <wired/wi-p7-message.h>
#include <wired/wi-p7-socket.h>
#include <wired/wi-p7-spec.h>
#include <wired/wi-p7-private.h>
#include <wired/wi-private.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include <openssl/sha.h>

#include <zlib.h>

#define _WI_P7_SOCKET_XML_MAGIC								0x3C3F786D
#define _WI_P7_SOCKET_BINARY_MAGIC_SIZE						66
#define _WI_P7_SOCKET_LENGTH_SIZE							4

#define _WI_P7_SOCKET_CHECKSUM_LENGTH						SHA_DIGEST_LENGTH

#define _WI_P7_COMPRESSION_DEFLATE							0

#define _WI_P7_ENCRYPTION_RSA_AES128_SHA1					0	
#define _WI_P7_ENCRYPTION_RSA_AES192_SHA1					1
#define _WI_P7_ENCRYPTION_RSA_AES256_SHA1					2
#define _WI_P7_ENCRYPTION_RSA_BF128_SHA1					3
#define _WI_P7_ENCRYPTION_RSA_3DES192_SHA1					4

#define _WI_P7_CHECKSUM_SHA1								0

#define _WI_P7_COMPRESSION_ENABLED(options)					\
	(((options) & WI_P7_COMPRESSION_DEFLATE))

#define _WI_P7_ENCRYPTION_ENABLED(options)					\
	(((options) & WI_P7_ENCRYPTION_RSA_AES128_SHA1) ||		\
	 ((options) & WI_P7_ENCRYPTION_RSA_AES192_SHA1) ||		\
	 ((options) & WI_P7_ENCRYPTION_RSA_AES256_SHA1) ||		\
	 ((options) & WI_P7_ENCRYPTION_RSA_BF128_SHA1) ||		\
	 ((options) & WI_P7_ENCRYPTION_RSA_3DES192_SHA1))

#define _WI_P7_CHECKSUM_ENABLED(options)					\
	(((options) & WI_P7_CHECKSUM_SHA1))

#define _WI_P7_COMPRESSION_ENUM_TO_OPTIONS(flag)			\
	((flag) == _WI_P7_COMPRESSION_DEFLATE ?					\
		WI_P7_COMPRESSION_DEFLATE : -1)

#define _WI_P7_ENCRYPTION_ENUM_TO_OPTIONS(flag)				\
	((flag) == _WI_P7_ENCRYPTION_RSA_AES128_SHA1 ?			\
		WI_P7_ENCRYPTION_RSA_AES128_SHA1 :					\
	 (flag) == _WI_P7_ENCRYPTION_RSA_AES192_SHA1 ?			\
		WI_P7_ENCRYPTION_RSA_AES192_SHA1 :					\
	 (flag) == _WI_P7_ENCRYPTION_RSA_AES256_SHA1 ?			\
		WI_P7_ENCRYPTION_RSA_AES256_SHA1 :					\
	 (flag) == _WI_P7_ENCRYPTION_RSA_BF128_SHA1 ?			\
		WI_P7_ENCRYPTION_RSA_BF128_SHA1 :					\
	 (flag) == _WI_P7_ENCRYPTION_RSA_3DES192_SHA1 ?			\
		WI_P7_ENCRYPTION_RSA_3DES192_SHA1 : -1)

#define _WI_P7_CHECKSUM_ENUM_TO_OPTIONS(flag)				\
	((flag) == _WI_P7_CHECKSUM_SHA1 ?						\
		WI_P7_CHECKSUM_SHA1 : -1)

#define _WI_P7_COMPRESSION_OPTIONS_TO_ENUM(options)			\
	((options) & WI_P7_COMPRESSION_DEFLATE ?				\
		_WI_P7_COMPRESSION_DEFLATE : -1)

#define _WI_P7_ENCRYPTION_OPTIONS_TO_ENUM(options)			\
	((options) & WI_P7_ENCRYPTION_RSA_AES128_SHA1 ?			\
		_WI_P7_ENCRYPTION_RSA_AES128_SHA1 :					\
	 (options) & WI_P7_ENCRYPTION_RSA_AES192_SHA1 ?			\
		_WI_P7_ENCRYPTION_RSA_AES192_SHA1 :					\
	 (options) & WI_P7_ENCRYPTION_RSA_AES256_SHA1 ?			\
		_WI_P7_ENCRYPTION_RSA_AES256_SHA1 :					\
	 (options) & WI_P7_ENCRYPTION_RSA_BF128_SHA1 ?			\
		_WI_P7_ENCRYPTION_RSA_BF128_SHA1 :					\
	 (options) & WI_P7_ENCRYPTION_RSA_3DES192_SHA1 ?		\
		_WI_P7_ENCRYPTION_RSA_3DES192_SHA1 : -1)

#define _WI_P7_CHECKSUM_OPTIONS_TO_ENUM(options)			\
	((options) & WI_P7_CHECKSUM_SHA1 ?						\
		_WI_P7_CHECKSUM_SHA1 : -1)

#define _WI_P7_ENCRYPTION_OPTIONS_TO_CIPHER(options)		\
	((options) & WI_P7_ENCRYPTION_RSA_AES128_SHA1 ?			\
		WI_CIPHER_AES128 :									\
	 (options) & WI_P7_ENCRYPTION_RSA_AES192_SHA1 ?			\
		WI_CIPHER_AES192 :									\
	 (options) & WI_P7_ENCRYPTION_RSA_AES256_SHA1 ?			\
		WI_CIPHER_AES256 :									\
	 (options) & WI_P7_ENCRYPTION_RSA_BF128_SHA1 ?			\
		WI_CIPHER_BF128 :									\
	 (options) & WI_P7_ENCRYPTION_RSA_3DES192_SHA1 ?		\
		WI_CIPHER_3DES192 : -1)


struct _wi_p7_socket {
	wi_runtime_base_t						base;
	
	wi_socket_t								*socket;
	
	wi_p7_spec_t							*spec;
	wi_string_t								*name;
	double									version;
	
	wi_p7_serialization_t					serialization;
	wi_p7_options_t							options;
	
	wi_boolean_t							encryption_enabled;
	wi_rsa_t								*rsa;
	wi_cipher_t								*cipher;
	
	wi_boolean_t							compression_enabled;
	z_stream								compression_stream;
	z_stream								decompression_stream;
	
	wi_boolean_t							checksum_enabled;
	wi_uinteger_t							checksum_length;
	
	wi_p7_boolean_t							local_compatibility_check;
	wi_p7_boolean_t							remote_compatibility_check;
	
	uint64_t								read_raw_bytes, read_processed_bytes;
	uint64_t								sent_raw_bytes, sent_processed_bytes;
};


enum _wi_p7_socket_compression {
	_WI_P7_SOCKET_COMPRESS,
	_WI_P7_SOCKET_DECOMPRESS,
};
typedef enum _wi_p7_socket_compression		_wi_p7_socket_compression_t;


static void									_wi_p7_socket_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_socket_description(wi_runtime_instance_t *);

static wi_boolean_t							_wi_p7_socket_connect_handshake(wi_p7_socket_t *, wi_time_interval_t, wi_p7_options_t);
static wi_boolean_t							_wi_p7_socket_accept_handshake(wi_p7_socket_t *, wi_time_interval_t, wi_p7_options_t);
static wi_boolean_t							_wi_p7_socket_connect_key_exchange(wi_p7_socket_t *, wi_time_interval_t, wi_string_t *, wi_string_t *);
static wi_boolean_t							_wi_p7_socket_accept_key_exchange(wi_p7_socket_t *, wi_time_interval_t);
static wi_boolean_t							_wi_p7_socket_send_compatibility_check(wi_p7_socket_t *, wi_time_interval_t);
static wi_boolean_t							_wi_p7_socket_receive_compatibility_check(wi_p7_socket_t *, wi_time_interval_t);

static wi_boolean_t							_wi_p7_socket_write_binary_message(wi_p7_socket_t *, wi_time_interval_t, wi_p7_message_t *);
static wi_boolean_t							_wi_p7_socket_write_xml_message(wi_p7_socket_t *, wi_time_interval_t, wi_p7_message_t *);
static wi_p7_message_t *					_wi_p7_socket_read_binary_message(wi_p7_socket_t *, wi_time_interval_t, uint32_t);
static wi_p7_message_t *					_wi_p7_socket_read_xml_message(wi_p7_socket_t *, wi_time_interval_t, wi_string_t *);

static wi_boolean_t							_wi_p7_socket_configure_compression_streams(wi_p7_socket_t *);
static wi_boolean_t							_wi_p7_socket_xcompress_buffer(wi_p7_socket_t *, _wi_p7_socket_compression_t, const void *, uint32_t, void **, uint32_t *);
static int									_wi_p7_socket_xflate_buffer(z_stream *, _wi_p7_socket_compression_t, const void *, uint32_t, uint32_t *, void *, uint32_t *);

static void									_wi_p7_socket_configure_checksum(wi_p7_socket_t *);
static void									_wi_p7_socket_checksum_binary_message(wi_p7_socket_t *, wi_p7_message_t *, void *);


wi_p7_socket_password_provider_func_t		*wi_p7_socket_password_provider = NULL;

static wi_runtime_id_t						_wi_p7_socket_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_socket_runtime_class = {
    "wi_p7_socket_t",
    _wi_p7_socket_dealloc,
    NULL,
    NULL,
    _wi_p7_socket_description,
    NULL
};



void wi_p7_socket_register(void) {
    _wi_p7_socket_runtime_id = wi_runtime_register_class(&_wi_p7_socket_runtime_class);
}



void wi_p7_socket_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_p7_socket_runtime_id(void) {
    return _wi_p7_socket_runtime_id;
}



#pragma mark -

wi_p7_socket_t * wi_p7_socket_alloc(void) {
    return wi_runtime_create_instance(_wi_p7_socket_runtime_id, sizeof(wi_p7_socket_t));
}



wi_p7_socket_t * wi_p7_socket_init_with_descriptor(wi_p7_socket_t *p7_socket, int sd, wi_p7_spec_t *p7_spec) {
	p7_socket->socket	= wi_socket_init_with_descriptor(wi_socket_alloc(), sd);
	p7_socket->spec		= wi_retain(p7_spec);

	return p7_socket;
}



wi_p7_socket_t * wi_p7_socket_init_with_socket(wi_p7_socket_t *p7_socket, wi_socket_t *socket, wi_p7_spec_t *p7_spec) {
	p7_socket->socket	= wi_retain(socket);
	p7_socket->spec		= wi_retain(p7_spec);
	
	return p7_socket;
}



static void _wi_p7_socket_dealloc(wi_runtime_instance_t *instance) {
	wi_p7_socket_t		*p7_socket = instance;
	
	wi_release(p7_socket->socket);
	wi_release(p7_socket->spec);
	wi_release(p7_socket->name);
	wi_release(p7_socket->rsa);
	wi_release(p7_socket->cipher);
}



static wi_string_t * _wi_p7_socket_description(wi_runtime_instance_t *instance) {
	wi_p7_socket_t		*p7_socket = instance;

	return wi_string_with_format(WI_STR("<%@ %p>{options = 0x%X, socket = %@}"),
		wi_runtime_class_name(p7_socket),
		p7_socket,
		p7_socket->options,
		p7_socket->socket);
}



#pragma mark -

void wi_p7_socket_set_private_rsa(wi_p7_socket_t *p7_socket, wi_rsa_t *rsa) {
	wi_retain(rsa);
	wi_release(p7_socket->rsa);
	
	p7_socket->rsa = rsa;
}



wi_rsa_t * wi_p7_socket_private_rsa(wi_p7_socket_t *p7_socket) {
	return p7_socket->rsa;
}



#pragma mark -

wi_socket_t * wi_p7_socket_socket(wi_p7_socket_t *p7_socket) {
	return p7_socket->socket;
}



wi_p7_spec_t * wi_p7_socket_spec(wi_p7_socket_t *p7_socket) {
	return p7_socket->spec;
}



wi_cipher_t * wi_p7_socket_cipher(wi_p7_socket_t *p7_socket) {
	return p7_socket->cipher;
}



wi_p7_options_t wi_p7_socket_options(wi_p7_socket_t *p7_socket) {
	return p7_socket->options;
}



wi_p7_serialization_t wi_p7_socket_serialization(wi_p7_socket_t *p7_socket) {
	return p7_socket->serialization;
}



#pragma mark -

static wi_boolean_t _wi_p7_socket_connect_handshake(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_options_t options) {
	wi_p7_message_t		*p7_message;
	wi_p7_double_t		version;
	wi_p7_enum_t		flag;
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.handshake"), p7_socket);
	
	if(!p7_message)
		return false;

	if(!wi_p7_message_set_double_for_name(p7_message, wi_p7_spec_version(wi_p7_spec_builtin_spec()), WI_STR("p7.handshake.version")))
		return false;
	
	if(!wi_p7_message_set_string_for_name(p7_message, wi_p7_spec_name(p7_socket->spec), WI_STR("p7.handshake.protocol_name")))
		return false;
	
	if(!wi_p7_message_set_double_for_name(p7_message, wi_p7_spec_version(p7_socket->spec), WI_STR("p7.handshake.protocol_version")))
		return false;
	
	if(p7_socket->serialization == WI_P7_BINARY) {
		if(_WI_P7_COMPRESSION_ENABLED(options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_COMPRESSION_OPTIONS_TO_ENUM(options),
												WI_STR("p7.handshake.compression"))) {
				return false;
			}
		}
		
		if(_WI_P7_ENCRYPTION_ENABLED(options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_ENCRYPTION_OPTIONS_TO_ENUM(options),
												WI_STR("p7.handshake.encryption"))) {
				return false;
			}
		}
		
		if(_WI_P7_CHECKSUM_ENABLED(options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_CHECKSUM_OPTIONS_TO_ENUM(options),
												WI_STR("p7.handshake.checksum"))) {
				return false;
			}
		}
	}
	
	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;
	
	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;

	if(!wi_is_equal(p7_message->name, WI_STR("p7.handshake.reply"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.handshake.reply\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
	if(!wi_p7_message_get_double_for_name(p7_message, &version, WI_STR("p7.handshake.version"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.version\" field"));
		
		return false;
	}

	if(version != wi_p7_spec_version(wi_p7_spec_builtin_spec())) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Remote P7 protocol %.1f is not compatible"),
			version);
		
		return false;
	}
	
	p7_socket->name = wi_retain(wi_p7_message_string_for_name(p7_message, WI_STR("p7.handshake.protocol_name")));
	
	if(!p7_socket->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.protocol_name\" field"));
		
		return false;
	}
	
	if(!wi_p7_message_get_double_for_name(p7_message, &p7_socket->version, WI_STR("p7.handshake.protocol_version"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.protocol_version\" field"));
		
		return false;
	}
	
	p7_socket->local_compatibility_check = !wi_p7_spec_is_compatible_with_protocol(p7_socket->spec, p7_socket->name, p7_socket->version);

	if(p7_socket->serialization == WI_P7_BINARY) {
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.compression")))
			p7_socket->options |= _WI_P7_COMPRESSION_ENUM_TO_OPTIONS(flag);
	
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.encryption")))
			p7_socket->options |= _WI_P7_ENCRYPTION_ENUM_TO_OPTIONS(flag);
	
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.checksum")))
			p7_socket->options |= _WI_P7_CHECKSUM_ENUM_TO_OPTIONS(flag);
	}
	
	if(!wi_p7_message_get_bool_for_name(p7_message, &p7_socket->remote_compatibility_check, WI_STR("p7.handshake.compatibility_check")))
		p7_socket->remote_compatibility_check = false;
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.handshake.acknowledge"), p7_socket);
	
	if(!p7_message)
		return false;
	
	if(p7_socket->local_compatibility_check) {
		if(!wi_p7_message_set_bool_for_name(p7_message, true, WI_STR("p7.handshake.compatibility_check")))
			return false;
	}

	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;
	
	return true;
}



static wi_boolean_t _wi_p7_socket_accept_handshake(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_options_t options) {
	wi_p7_message_t		*p7_message;
	wi_p7_double_t		version;
	wi_p7_enum_t		flag;
	wi_p7_options_t		client_options;
	
	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;

	if(!wi_is_equal(p7_message->name, WI_STR("p7.handshake"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.handshake\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
 	if(!wi_p7_message_get_double_for_name(p7_message, &version, WI_STR("p7.handshake.version"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.version\" field"));
		
		return false;
	}
	
	if(version != wi_p7_spec_version(wi_p7_spec_builtin_spec())) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Remote P7 protocol %.1f is not compatible"),
			version);

		return false;
	}
	
	p7_socket->name = wi_retain(wi_p7_message_string_for_name(p7_message, WI_STR("p7.handshake.protocol_name")));
	
	if(!p7_socket->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.protocol_name\" field"));
		
		return false;
	}
	
 	if(!wi_p7_message_get_double_for_name(p7_message, &p7_socket->version, WI_STR("p7.handshake.protocol_version"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.handshake.protocol_version\" field"));
		
		return false;
	}

	p7_socket->local_compatibility_check = !wi_p7_spec_is_compatible_with_protocol(p7_socket->spec, p7_socket->name, p7_socket->version);

	if(p7_socket->serialization == WI_P7_BINARY) {
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.compression"))) {
			client_options = _WI_P7_COMPRESSION_ENUM_TO_OPTIONS(flag);
			
			if(options & client_options)
				p7_socket->options |= client_options;
		}
		
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.encryption"))) {
			client_options = _WI_P7_ENCRYPTION_ENUM_TO_OPTIONS(flag);

			if(options & client_options)
				p7_socket->options |= client_options;
		}
		
		if(wi_p7_message_get_enum_for_name(p7_message, &flag, WI_STR("p7.handshake.checksum"))) {
			client_options = _WI_P7_CHECKSUM_ENUM_TO_OPTIONS(flag);

			if(options & client_options)
				p7_socket->options |= client_options;
		}
	}
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.handshake.reply"), p7_socket);

	if(!p7_message)
		return false;
	
	if(!wi_p7_message_set_double_for_name(p7_message, wi_p7_spec_version(wi_p7_spec_builtin_spec()), WI_STR("p7.handshake.version")))
		return false;
	
	if(!wi_p7_message_set_string_for_name(p7_message, wi_p7_spec_name(p7_socket->spec), WI_STR("p7.handshake.protocol_name")))
		return false;
	
	if(!wi_p7_message_set_double_for_name(p7_message, wi_p7_spec_version(p7_socket->spec), WI_STR("p7.handshake.protocol_version")))
		return false;
	
	if(p7_socket->serialization == WI_P7_BINARY) {
		if(_WI_P7_COMPRESSION_ENABLED(p7_socket->options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_COMPRESSION_OPTIONS_TO_ENUM(p7_socket->options),
												WI_STR("p7.handshake.compression"))) {
				return false;
			}
		}

		if(_WI_P7_ENCRYPTION_ENABLED(p7_socket->options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_ENCRYPTION_OPTIONS_TO_ENUM(p7_socket->options),
												WI_STR("p7.handshake.encryption"))) {
				return false;
			}
		}

		if(_WI_P7_CHECKSUM_ENABLED(p7_socket->options)) {
			if(!wi_p7_message_set_enum_for_name(p7_message,
												_WI_P7_CHECKSUM_OPTIONS_TO_ENUM(p7_socket->options),
												WI_STR("p7.handshake.checksum"))) {
				return false;
			}
		}
	}
	
	if(p7_socket->local_compatibility_check) {
		if(!wi_p7_message_set_bool_for_name(p7_message, true, WI_STR("p7.handshake.compatibility_check")))
			return false;
	}

	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;

	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;

	if(!wi_is_equal(p7_message->name, WI_STR("p7.handshake.acknowledge"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.handshake.acknowledge\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
	if(!wi_p7_message_get_bool_for_name(p7_message, &p7_socket->remote_compatibility_check, WI_STR("p7.handshake.compatibility_check")))
		p7_socket->remote_compatibility_check = false;
	
	return true;
}



static wi_boolean_t _wi_p7_socket_connect_key_exchange(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_string_t *username, wi_string_t *password) {
	wi_p7_message_t		*p7_message;
	wi_data_t			*data, *rsa;
	wi_string_t			*client_password1, *client_password2, *server_password;

	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;
	
	if(!wi_is_equal(p7_message->name, WI_STR("p7.encryption"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.encryption\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
	rsa = wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.public_key"));
	
	if(!rsa) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.encryption.public_key\" field"));
		
		return false;
	}
	
	p7_socket->rsa = wi_rsa_init_with_public_key(wi_rsa_alloc(), rsa);
	
	if(!p7_socket->rsa)
		return false;
	
	p7_socket->cipher = wi_cipher_init_with_random_key(wi_cipher_alloc(), _WI_P7_ENCRYPTION_OPTIONS_TO_CIPHER(p7_socket->options));
	
	if(!p7_socket->cipher)
		return false;
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.encryption.reply"), p7_socket);

	if(!p7_message)
		return false;
	
	data = wi_rsa_encrypt(p7_socket->rsa, wi_cipher_key(p7_socket->cipher));
	
	if(!wi_p7_message_set_data_for_name(p7_message, data, WI_STR("p7.encryption.cipher_key")))
		return false;

	data = wi_cipher_iv(p7_socket->cipher);
	
	if(data) {
		data = wi_rsa_encrypt(p7_socket->rsa, data);
		
		if(!wi_p7_message_set_data_for_name(p7_message, data, WI_STR("p7.encryption.cipher_iv")))
			return false;
	}
	
	data = wi_rsa_encrypt(p7_socket->rsa, wi_string_data(username));
	
	if(!data)
		return false;
	
	if(!wi_p7_message_set_data_for_name(p7_message, data, WI_STR("p7.encryption.username")))
		return false;
	
	if(!password)
		password = WI_STR("");

	client_password1 = wi_data_sha1(wi_data_by_appending_data(wi_string_data(wi_string_sha1(password)), rsa));
	client_password2 = wi_data_sha1(wi_data_by_appending_data(rsa, wi_string_data(wi_string_sha1(password))));
	
	data = wi_rsa_encrypt(p7_socket->rsa, wi_string_data(client_password1));
	
	if(!data)
		return false;

	if(!wi_p7_message_set_data_for_name(p7_message, data, WI_STR("p7.encryption.client_password")))
		return false;
	
	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;

	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;
	
	if(!wi_is_equal(p7_message->name, WI_STR("p7.encryption.acknowledge"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.encryption.acknowledge\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
	data = wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.server_password"));
	
	if(!data) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.encryption.server_password\" field"));
		
		return false;
	}
	
	data = wi_cipher_decrypt(p7_socket->cipher, data);
	
	if(!data)
		return false;
	
	server_password = wi_string_with_data(data);

	if(!wi_is_equal(server_password, client_password2)) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Password mismatch during key exchange"));
		
		return false;
	}

	p7_socket->encryption_enabled = true;
	
	return true;
}



static wi_boolean_t _wi_p7_socket_accept_key_exchange(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout) {
	wi_p7_message_t		*p7_message;
	wi_data_t			*data, *rsa, *key, *iv;
	wi_string_t			*string, *username, *client_password, *server_password1, *server_password2;
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.encryption"), p7_socket);

	if(!p7_message)
		return false;
	
	rsa = wi_rsa_public_key(p7_socket->rsa);
	
	if(!wi_p7_message_set_data_for_name(p7_message, rsa, WI_STR("p7.encryption.public_key")))
		return false;
	
	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;
	
	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;
	
	if(!wi_is_equal(p7_message->name, WI_STR("p7.encryption.reply"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.encryption.reply\", not \"%@\""),
			p7_message->name);
		
		return false;
	}

	key		= wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.cipher_key"));
	iv		= wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.cipher_iv"));
	
	if(!key) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.encryption.cipher_key\" field"));
		
		return false;
	}
	
	key = wi_rsa_decrypt(p7_socket->rsa, key);
	
	if(iv)
		iv = wi_rsa_decrypt(p7_socket->rsa, iv);
	
	p7_socket->cipher = wi_cipher_init_with_key(wi_cipher_alloc(), _WI_P7_ENCRYPTION_OPTIONS_TO_CIPHER(p7_socket->options), key, iv);

	if(!p7_socket->cipher)
		return false;
	
	data = wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.username"));

	if(!data) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.encryption.username\" field"));
		
		return false;
	}
	
	data = wi_rsa_decrypt(p7_socket->rsa, data);
	
	if(!data)
		return false;
	
	username = wi_string_with_data(data);
	
	data = wi_p7_message_data_for_name(p7_message, WI_STR("p7.encryption.client_password"));

	if(!data) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.encryption.client_password\" field"));
		
		return false;
	}
	
	data = wi_rsa_decrypt(p7_socket->rsa, data);
	
	if(!data)
		return false;

	client_password = wi_string_with_data(data);
	
	if(wi_p7_socket_password_provider) {
		string = (*wi_p7_socket_password_provider)(username);
		
		if(!string) {
			wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
				WI_STR("Unknown user \"%@\" during key exchange"),
				username);
			
			return false;
		}
	} else {
		string = wi_string_sha1(WI_STR(""));
	}
	
	server_password1 = wi_data_sha1(wi_data_by_appending_data(wi_string_data(string), rsa));
	server_password2 = wi_data_sha1(wi_data_by_appending_data(rsa, wi_string_data(string)));
	
	if(!wi_is_equal(client_password, server_password1)) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Password mismatch for \"%@\" during key exchange"),
			username);
		
		return false;
	}
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.encryption.acknowledge"), p7_socket);
	
	if(!p7_message)
		return false;
	
	data = wi_cipher_encrypt(p7_socket->cipher, wi_string_data(server_password2));
	
	if(!data)
		return false;

	if(!wi_p7_message_set_data_for_name(p7_message, data, WI_STR("p7.encryption.server_password")))
		return false;

	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;

	p7_socket->encryption_enabled = true;
	
	return true;
}



static wi_boolean_t _wi_p7_socket_send_compatibility_check(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout) {
	wi_p7_message_t		*p7_message;
	wi_p7_boolean_t		status;
	
	p7_message = wi_p7_message_with_name(WI_STR("p7.compatibility_check.specification"), p7_socket);
	
	if(!p7_message)
		return false;
	
	if(!wi_p7_message_set_string_for_name(p7_message, wi_p7_spec_xml(p7_socket->spec), WI_STR("p7.compatibility_check.specification")))
		return false;

	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;

	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;
	
	if(!wi_is_equal(p7_message->name, WI_STR("p7.compatibility_check.status"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.compatibility_check.status\", not \"%@\""),
			p7_message->name);
		
		return false;
	}
	
	if(!wi_p7_message_get_bool_for_name(p7_message, &status, WI_STR("p7.compatibility_check.status"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.compatibility_check.status\" field"));
		
		return false;
	}

	if(!status) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Remote protocol %@ %.1f is not compatible"),
			p7_socket->name,
			p7_socket->version);
		
		return false;
	}

	return true;
}



static wi_boolean_t _wi_p7_socket_receive_compatibility_check(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout) {
	wi_string_t			*string;
	wi_p7_message_t		*p7_message;
	wi_p7_spec_t		*p7_spec;
	wi_boolean_t		compatible;
	
	p7_message = wi_p7_socket_read_message(p7_socket, timeout);
	
	if(!p7_message)
		return false;
	
	if(!wi_is_equal(p7_message->name, WI_STR("p7.compatibility_check.specification"))) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message should be \"p7.compatibility_check.specification\", not \"%@\""),
			p7_message->name);
		
		return false;
	}

	string = wi_p7_message_string_for_name(p7_message, WI_STR("p7.compatibility_check.specification"));
	
	if(!string) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Message has no \"p7.compatibility_check.specification\" field"));
		
		return false;
	}
	
	p7_spec = wi_p7_spec_init_with_string(wi_p7_spec_alloc(), string);
	
	if(!p7_spec)
		return false;
	
	compatible = wi_p7_spec_is_compatible_with_spec(p7_socket->spec, p7_spec);

	wi_release(p7_spec);

	p7_message = wi_p7_message_with_name(WI_STR("p7.compatibility_check.status"), p7_socket);
	
	if(!p7_message)
		return false;
	
	if(!wi_p7_message_set_bool_for_name(p7_message, compatible, WI_STR("p7.compatibility_check.status")))
		return false;

	if(!wi_p7_socket_write_message(p7_socket, timeout, p7_message))
		return false;

	return true;
}



#pragma mark -

static wi_boolean_t _wi_p7_socket_write_binary_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_message_t *p7_message) {
	const void			*send_buffer;
	void				*compressed_buffer = NULL, *encrypted_buffer = NULL;
	char				length_buffer[_WI_P7_SOCKET_LENGTH_SIZE];
	unsigned char		checksum_buffer[_WI_P7_SOCKET_CHECKSUM_LENGTH];
	uint32_t			send_size, compressed_size, encrypted_size;
	wi_boolean_t		result = false;
	
	send_size	= p7_message->binary_size;
	send_buffer	= p7_message->binary_buffer;
	
	p7_socket->sent_raw_bytes += send_size;
	
	if(p7_socket->compression_enabled) {
		if(!_wi_p7_socket_xcompress_buffer(p7_socket,
										   _WI_P7_SOCKET_COMPRESS,
										   send_buffer,
										   send_size,
										   &compressed_buffer,
										   &compressed_size)) {
			goto end;
		}
		
		send_size	= compressed_size;
		send_buffer	= compressed_buffer;
	}
	
	if(p7_socket->encryption_enabled) {
		if(!wi_cipher_encrypt_bytes(p7_socket->cipher,
									send_buffer,
									send_size,
									&encrypted_buffer,
									&encrypted_size)) {
			goto end;
		}
		
		send_size	= encrypted_size;
		send_buffer	= encrypted_buffer;
	}

	p7_socket->sent_processed_bytes += send_size;

	wi_write_swap_host_to_big_int32(length_buffer, 0, send_size);
	
	if(wi_socket_write_buffer(p7_socket->socket, timeout, length_buffer, sizeof(length_buffer)) < 0)
		goto end;

	if(wi_socket_write_buffer(p7_socket->socket, timeout, send_buffer, send_size) < 0)
		goto end;
	
	if(p7_socket->checksum_enabled) {
		_wi_p7_socket_checksum_binary_message(p7_socket, p7_message, checksum_buffer);

		if(wi_socket_write_buffer(p7_socket->socket, timeout, checksum_buffer, p7_socket->checksum_length) < 0)
			goto end;
	}
	
	result = true;

end:
	wi_free(compressed_buffer);
	wi_free(encrypted_buffer);
	
	return result;
}



static wi_boolean_t _wi_p7_socket_write_xml_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_message_t *p7_message) {
	if(wi_socket_write_buffer(p7_socket->socket, timeout, p7_message->xml_buffer, p7_message->xml_length) < 0)
		return false;
	
	return true;
}



static wi_p7_message_t * _wi_p7_socket_read_binary_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, uint32_t message_size) {
	wi_p7_message_t		*p7_message;
	void				*decompressed_buffer, *decrypted_buffer;
	unsigned char		local_checksum_buffer[_WI_P7_SOCKET_CHECKSUM_LENGTH];
	unsigned char		remote_checksum_buffer[_WI_P7_SOCKET_CHECKSUM_LENGTH];
	uint32_t			decompressed_size, decrypted_size;
	int32_t				length;
	
	p7_message = wi_autorelease(wi_p7_message_init(wi_p7_message_alloc(), p7_socket));

	if(!p7_message->binary_buffer) {
		p7_message->binary_capacity	= message_size;
		p7_message->binary_buffer	= wi_malloc(p7_message->binary_capacity);
	}
	else if(message_size > p7_message->binary_capacity) {
		p7_message->binary_capacity	= message_size;
		p7_message->binary_buffer	= wi_realloc(p7_message->binary_buffer, message_size);
	}
	
	length = wi_socket_read_buffer(p7_socket->socket, timeout, p7_message->binary_buffer, message_size);
	
	if(length <= 0)
		return NULL;
	
	p7_message->binary_size = length;
	p7_socket->read_raw_bytes += p7_message->binary_size;

	if(p7_socket->encryption_enabled) {
		if(!wi_cipher_decrypt_bytes(p7_socket->cipher,
									p7_message->binary_buffer,
									p7_message->binary_size,
									&decrypted_buffer,
									&decrypted_size)) {
			return NULL;
		}
		
		wi_free(p7_message->binary_buffer);
		
		p7_message->binary_size		= decrypted_size;
		p7_message->binary_capacity	= decrypted_size;
		p7_message->binary_buffer	= decrypted_buffer;
	}
	
	if(p7_socket->compression_enabled) {
		if(!_wi_p7_socket_xcompress_buffer(p7_socket,
										   _WI_P7_SOCKET_DECOMPRESS,
										   p7_message->binary_buffer,
										   p7_message->binary_size,
										   &decompressed_buffer,
										   &decompressed_size)) {
			return NULL;
		}
		
		wi_free(p7_message->binary_buffer);

		p7_message->binary_size		= decompressed_size;
		p7_message->binary_capacity	= decompressed_size; 
		p7_message->binary_buffer	= decompressed_buffer;
	}
	
	p7_socket->read_processed_bytes += p7_message->binary_size;
	
	if(p7_socket->checksum_enabled) {
		length = wi_socket_read_buffer(p7_socket->socket, timeout, remote_checksum_buffer, p7_socket->checksum_length);
		
		if(length <= 0)
			return NULL;
		
		_wi_p7_socket_checksum_binary_message(p7_socket, p7_message, local_checksum_buffer);
		
		if(memcmp(remote_checksum_buffer, local_checksum_buffer, p7_socket->checksum_length) != 0) {
			wi_error_set_libwired_p7_error(WI_ERROR_P7_CHECKSUMMISMATCH, WI_STR(""));
			
			return NULL;
		}
	}

	return p7_message;
}



static wi_p7_message_t * _wi_p7_socket_read_xml_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_string_t *prefix) {
	wi_string_t			*string;
	wi_p7_message_t		*p7_message;
	
	p7_message = wi_autorelease(wi_p7_message_init(wi_p7_message_alloc(), p7_socket));
	
	while(true) {
		string = wi_socket_read_to_string(p7_socket->socket, timeout, WI_STR(">"));
		
		if(!string || wi_string_length(string) == 0)
			return NULL;
		
		wi_string_delete_surrounding_whitespace(string);
		
		if(!p7_message->xml_string)
			p7_message->xml_string = wi_copy(string);
		else
			wi_string_append_string(p7_message->xml_string, string);
		
		if(wi_string_has_suffix(string, WI_STR("</p7:message>")) ||
		   (wi_string_has_suffix(string, WI_STR("/>")) &&
			wi_string_has_prefix(string, WI_STR("<p7:message")))) {
			break;
		}
	}
	
	wi_retain(p7_message->xml_string);
	
	if(prefix)
		wi_string_insert_string_at_index(p7_message->xml_string, prefix, 0);

	wi_string_delete_surrounding_whitespace(p7_message->xml_string);
	
	return p7_message;
}



#pragma mark -

static wi_boolean_t _wi_p7_socket_configure_compression_streams(wi_p7_socket_t *p7_socket) {
	int			err;

	err = deflateInit(&p7_socket->compression_stream, Z_DEFAULT_COMPRESSION);
	
	if(err != Z_OK) {
		wi_error_set_zlib_error(err);
		
		return false;
	}
	
	err = inflateInit(&p7_socket->decompression_stream);
	
	if(err != Z_OK) {
		wi_error_set_zlib_error(err);
		
		return false;
	}
	
	p7_socket->compression_enabled = true;
	
	return true;
}



static wi_boolean_t _wi_p7_socket_xcompress_buffer(wi_p7_socket_t *p7_socket, _wi_p7_socket_compression_t compression, const void *in_buffer, uint32_t in_size, void **out_buffer, uint32_t *out_size) {
	const void		*input;
	void			*output, *working_buffer;
	z_stream		*stream;
	uint32_t		offset, input_size, input_processed, output_size, working_size, total_working_size;
	int				err;
	
	stream					= (compression == _WI_P7_SOCKET_COMPRESS) ? &p7_socket->compression_stream : &p7_socket->decompression_stream;
	working_size			= (compression == _WI_P7_SOCKET_COMPRESS) ? in_size : 4 * in_size;
	working_buffer			= wi_malloc(working_size);
	input					= in_buffer;
	input_size				= in_size;
	output					= working_buffer;
	output_size				= working_size;
	total_working_size		= 0;
	
	while(true) {
		err = _wi_p7_socket_xflate_buffer(stream, compression, input, input_size, &input_processed, output, &output_size);
		
		if(err != Z_OK) {
			wi_error_set_zlib_error(err);
			
			wi_free(working_buffer);
			
			return false;
		}
		
		total_working_size += output_size;
		
		if(stream->avail_out > 0)
			break;
		
		offset				= (output - working_buffer) + output_size;
		working_size		*= 4;
		working_buffer		= wi_realloc(working_buffer, working_size);
		output				= working_buffer + offset;
		output_size			= working_size - offset;
		input				+= input_processed;
		input_size			-= input_processed;
	}
	
	*out_buffer	= working_buffer;
	*out_size	= total_working_size;
	
	return true;
}



static int _wi_p7_socket_xflate_buffer(z_stream *stream, _wi_p7_socket_compression_t compression, const void *input, uint32_t input_size, uint32_t *input_processed, void *output, uint32_t *output_size) {
	int		err;
	
    stream->next_in		= (Bytef *) input;
    stream->avail_in	= input_size;
    stream->total_in	= 0;

    stream->next_out	= output;
    stream->avail_out	= *output_size;
    stream->total_out	= 0;

	if(compression == _WI_P7_SOCKET_COMPRESS)
		err = deflate(stream, Z_SYNC_FLUSH);
	else
		err = inflate(stream, Z_SYNC_FLUSH);
    
    *input_processed	= stream->total_in;
    *output_size		= stream->total_out;
    
	return err;
}



#pragma mark -

static void _wi_p7_socket_configure_checksum(wi_p7_socket_t *p7_socket) {
	if(p7_socket->options & WI_P7_CHECKSUM_SHA1)
		p7_socket->checksum_length = SHA_DIGEST_LENGTH;
	
	p7_socket->checksum_enabled = true;
}



static void _wi_p7_socket_checksum_binary_message(wi_p7_socket_t *p7_socket, wi_p7_message_t *p7_message, void *buffer) {
	SHA_CTX		c;

	if(p7_socket->options & WI_P7_CHECKSUM_SHA1) {
		SHA1_Init(&c);
		SHA1_Update(&c, p7_message->binary_buffer, p7_message->binary_size);
		SHA1_Final(buffer, &c);
	}
}



#pragma mark -

wi_boolean_t wi_p7_socket_connect(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_options_t options, wi_p7_serialization_t serialization, wi_string_t *username, wi_string_t *password) {
	p7_socket->serialization = serialization;
	
	if(!_wi_p7_socket_connect_handshake(p7_socket, timeout, options))
		return false;
	
	if(_WI_P7_COMPRESSION_ENABLED(p7_socket->options)) {
		if(!_wi_p7_socket_configure_compression_streams(p7_socket))
			return false;
	}
	
	if(_WI_P7_CHECKSUM_ENABLED(p7_socket->options))
		_wi_p7_socket_configure_checksum(p7_socket);
	
	if(_WI_P7_ENCRYPTION_ENABLED(p7_socket->options)) {
		if(!_wi_p7_socket_connect_key_exchange(p7_socket, timeout, username, password))
			return false;
	}

	if(p7_socket->remote_compatibility_check) {
		if(!_wi_p7_socket_send_compatibility_check(p7_socket, timeout))
			return false;
	}
	
	if(p7_socket->local_compatibility_check) {
		if(!_wi_p7_socket_receive_compatibility_check(p7_socket, timeout))
			return false;
	}

	return true;
}



wi_boolean_t wi_p7_socket_accept(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_options_t options) {
	if(!_wi_p7_socket_accept_handshake(p7_socket, timeout, options))
		return false;
	
	if(_WI_P7_COMPRESSION_ENABLED(p7_socket->options)) {
		if(!_wi_p7_socket_configure_compression_streams(p7_socket))
			return false;
	}
	
	if(_WI_P7_CHECKSUM_ENABLED(p7_socket->options))
		_wi_p7_socket_configure_checksum(p7_socket);
	
	if(_WI_P7_ENCRYPTION_ENABLED(p7_socket->options)) {
		if(!_wi_p7_socket_accept_key_exchange(p7_socket, timeout))
			return false;
	}
	
	if(p7_socket->local_compatibility_check) {
		if(!_wi_p7_socket_receive_compatibility_check(p7_socket, timeout))
			return false;
	}

	if(p7_socket->remote_compatibility_check) {
		if(!_wi_p7_socket_send_compatibility_check(p7_socket, timeout))
			return false;
	}
	
	return true;
}



wi_boolean_t wi_p7_socket_write_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, wi_p7_message_t *p7_message) {
	wi_boolean_t	result;
	
	wi_p7_message_serialize(p7_message);
	
	wi_log_info(WI_STR("Sending %@"), p7_message);
	
	if(p7_socket->serialization == WI_P7_BINARY)
		result = _wi_p7_socket_write_binary_message(p7_socket, timeout, p7_message);
	else
		result = _wi_p7_socket_write_xml_message(p7_socket, timeout, p7_message);
	
	if(!result)
		return false;
	
	wi_log_info(WI_STR("Sent %llu raw bytes, %llu processed bytes, compressed to %.2f%%"),
		p7_socket->sent_raw_bytes,
		p7_socket->sent_processed_bytes,
		((double) p7_socket->sent_raw_bytes / (double) p7_socket->sent_processed_bytes) * 100.0);
	
	return true;
}



wi_p7_message_t * wi_p7_socket_read_message(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout) {
	wi_p7_message_t		*p7_message;
	wi_string_t			*prefix = NULL;
	char				length_buffer[_WI_P7_SOCKET_LENGTH_SIZE];
	uint32_t			length;
	
	if(p7_socket->serialization == WI_P7_UNKNOWN || p7_socket->serialization == WI_P7_BINARY) {
		if(wi_socket_read_buffer(p7_socket->socket, timeout, length_buffer, sizeof(length_buffer)) <= 0)
			return NULL;
		
		length = wi_read_swap_big_to_host_int32(length_buffer, 0);
		
		if(p7_socket->serialization == WI_P7_UNKNOWN) {
			if(length == _WI_P7_SOCKET_XML_MAGIC) {
				p7_socket->serialization = WI_P7_XML;
				prefix = WI_STR("<?xm");
			}
			else if(length <= _WI_P7_SOCKET_BINARY_MAGIC_SIZE) {
				p7_socket->serialization = WI_P7_BINARY;
			}
		}
	}
	
	if(p7_socket->serialization == WI_P7_BINARY)
		p7_message = _wi_p7_socket_read_binary_message(p7_socket, timeout, length);
	else if(p7_socket->serialization == WI_P7_XML)
		p7_message = _wi_p7_socket_read_xml_message(p7_socket, timeout, prefix);
	else {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_HANDSHAKEFAILED,
			WI_STR("Invalid data from remote host"));
		
		return NULL;
	}
	
	if(!p7_message)
		return NULL;

	if(p7_message->binary_size == 0) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDMESSAGE,
			WI_STR("Invalid data from remote host"));
		
		return NULL;
	}
	
	wi_p7_message_deserialize(p7_message);
	
	wi_log_info(WI_STR("Received %@"), p7_message);

	wi_log_info(WI_STR("Received %llu raw bytes, %llu processed bytes, compressed to %.2f%%"),
		p7_socket->read_raw_bytes,
		p7_socket->read_processed_bytes,
		((double) p7_socket->read_raw_bytes / (double) p7_socket->read_processed_bytes) * 100.0);

	return p7_message;
}



int32_t wi_p7_socket_write_oobdata(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, const void *buffer, uint32_t size) {
	const void			*send_buffer;
	void				*compressed_buffer = NULL, *encrypted_buffer = NULL;
	char				length_buffer[_WI_P7_SOCKET_LENGTH_SIZE];
	uint32_t			send_size, compressed_size, encrypted_size;
	int32_t				result = -1;
	
	send_size	= size;
	send_buffer	= buffer;
	
	if(p7_socket->compression_enabled) {
		if(!_wi_p7_socket_xcompress_buffer(p7_socket,
										   _WI_P7_SOCKET_COMPRESS,
										   send_buffer,
										   send_size,
										   &compressed_buffer,
										   &compressed_size)) {
			goto end;
		}
		
		send_size	= compressed_size;
		send_buffer	= compressed_buffer;
	}
	
	if(p7_socket->encryption_enabled) {
		if(!wi_cipher_encrypt_bytes(p7_socket->cipher,
									send_buffer,
									send_size,
									&encrypted_buffer,
									&encrypted_size)) {
			goto end;
		}
		
		send_size	= encrypted_size;
		send_buffer = encrypted_buffer;
	}

	wi_write_swap_host_to_big_int32(length_buffer, 0, send_size);

	if(wi_socket_write_buffer(p7_socket->socket, timeout, length_buffer, sizeof(length_buffer)) < 0)
		goto end;

	result = wi_socket_write_buffer(p7_socket->socket, timeout, send_buffer, send_size);

end:
	wi_free(compressed_buffer);
	wi_free(encrypted_buffer);
	
	return result;
}



int32_t wi_p7_socket_read_oobdata(wi_p7_socket_t *p7_socket, wi_time_interval_t timeout, void *out_buffer, uint32_t out_size) {
	void				*receive_buffer = NULL, *decrypted_buffer, *decompressed_buffer;
	char				length_buffer[_WI_P7_SOCKET_LENGTH_SIZE];
	uint32_t			receive_size, decompressed_size, decrypted_size;
	int32_t				result = -1;
	
	if(wi_socket_read_buffer(p7_socket->socket, timeout, length_buffer, sizeof(length_buffer)) <= 0)
		goto end;
	
	receive_size	= wi_read_swap_big_to_host_int32(length_buffer, 0);
	receive_buffer	= wi_malloc(receive_size);
	
	result = wi_socket_read_buffer(p7_socket->socket, timeout, receive_buffer, receive_size);
	
	if(result <= 0)
		goto end;
	
	if(p7_socket->encryption_enabled) {
		if(!wi_cipher_decrypt_bytes(p7_socket->cipher,
									receive_buffer,
									receive_size,
									&decrypted_buffer,
									&decrypted_size)) {
			goto end;
		}
		
		wi_free(receive_buffer);

		receive_size	= decrypted_size;
		receive_buffer	= decrypted_buffer;
	}
	
	if(p7_socket->compression_enabled) {
		if(!_wi_p7_socket_xcompress_buffer(p7_socket,
										   _WI_P7_SOCKET_DECOMPRESS,
										   receive_buffer,
										   receive_size,
										   &decompressed_buffer,
										   &decompressed_size)) {
			goto end;
		}
		
		wi_free(receive_buffer);

		receive_size	= decompressed_size;
		receive_buffer	= decompressed_buffer;
	}
	
	memcpy(out_buffer, receive_buffer, receive_size);
	
	result = receive_size;
	
end:
	wi_free(receive_buffer);
	
	return result;
}

#endif
