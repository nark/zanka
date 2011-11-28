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

#ifndef WI_P7_SOCKET_H
#define WI_P7_SOCKET_H 1

#include <wired/wi-base.h>
#include <wired/wi-crypto.h>
#include <wired/wi-runtime.h>
#include <wired/wi-socket.h>

enum _wi_p7_options {
	WI_P7_COMPRESSION_DEFLATE						= (1 << 0),
	WI_P7_ENCRYPTION_RSA_AES128_SHA1				= (1 << 1),
	WI_P7_ENCRYPTION_RSA_AES192_SHA1				= (1 << 2),
	WI_P7_ENCRYPTION_RSA_AES256_SHA1				= (1 << 3),
	WI_P7_ENCRYPTION_RSA_BF128_SHA1					= (1 << 4),
	WI_P7_ENCRYPTION_RSA_3DES192_SHA1				= (1 << 5),
	WI_P7_CHECKSUM_SHA1								= (1 << 6),
	WI_P7_ALL										= (WI_P7_COMPRESSION_DEFLATE |
													   WI_P7_ENCRYPTION_RSA_AES128_SHA1 |
													   WI_P7_ENCRYPTION_RSA_AES192_SHA1 |
													   WI_P7_ENCRYPTION_RSA_AES256_SHA1 |
													   WI_P7_ENCRYPTION_RSA_BF128_SHA1 |
													   WI_P7_ENCRYPTION_RSA_3DES192_SHA1 |
													   WI_P7_CHECKSUM_SHA1)
};
typedef enum _wi_p7_options							wi_p7_options_t;


typedef wi_string_t *								wi_p7_socket_password_provider_func_t(wi_string_t *);


WI_EXPORT wi_runtime_id_t							wi_p7_socket_runtime_id(void);

WI_EXPORT wi_p7_socket_t *							wi_p7_socket_alloc(void);
WI_EXPORT wi_p7_socket_t *							wi_p7_socket_init_with_descriptor(wi_p7_socket_t *, int, wi_p7_spec_t *);
WI_EXPORT wi_p7_socket_t *							wi_p7_socket_init_with_socket(wi_p7_socket_t *, wi_socket_t *, wi_p7_spec_t *);

WI_EXPORT void										wi_p7_socket_set_private_rsa(wi_p7_socket_t *, wi_rsa_t *);
WI_EXPORT wi_rsa_t *								wi_p7_socket_private_rsa(wi_p7_socket_t *);

WI_EXPORT wi_socket_t *								wi_p7_socket_socket(wi_p7_socket_t *);
WI_EXPORT wi_p7_spec_t *							wi_p7_socket_spec(wi_p7_socket_t *);
WI_EXPORT wi_cipher_t *								wi_p7_socket_cipher(wi_p7_socket_t *);
WI_EXPORT wi_p7_options_t							wi_p7_socket_options(wi_p7_socket_t *);
WI_EXPORT wi_p7_serialization_t						wi_p7_socket_serialization(wi_p7_socket_t *);

WI_EXPORT wi_boolean_t								wi_p7_socket_connect(wi_p7_socket_t *, wi_time_interval_t, wi_p7_options_t, wi_p7_serialization_t, wi_string_t *, wi_string_t *);
WI_EXPORT wi_boolean_t								wi_p7_socket_accept(wi_p7_socket_t *, wi_time_interval_t, wi_p7_options_t);
WI_EXPORT wi_boolean_t								wi_p7_socket_write_message(wi_p7_socket_t *, wi_time_interval_t, wi_p7_message_t *);
WI_EXPORT wi_p7_message_t *							wi_p7_socket_read_message(wi_p7_socket_t *, wi_time_interval_t);
WI_EXPORT int32_t									wi_p7_socket_write_oobdata(wi_p7_socket_t *, wi_time_interval_t, const void *, uint32_t);
WI_EXPORT int32_t									wi_p7_socket_read_oobdata(wi_p7_socket_t *, wi_time_interval_t, void *, uint32_t);


WI_EXPORT wi_p7_socket_password_provider_func_t		*wi_p7_socket_password_provider;

#endif /* WI_P7_SOCKET_H */
