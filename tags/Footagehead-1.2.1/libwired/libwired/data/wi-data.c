/* $Id$ */

/*
 *  Copyright (c) 2006 Axel Andersson
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

#include <string.h>

#ifdef WI_SSL
#include <openssl/md5.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#endif

#include <wired/wi-data.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include "wi-private.h"

struct _wi_data {
	wi_runtime_base_t					base;
	
	void								*bytes;
	uint32_t							length;
	uint32_t							capacity;
};


static void								_wi_data_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_data_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_data_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_hash_code_t					_wi_data_hash(wi_runtime_instance_t *);
static wi_string_t *					_wi_data_description(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_data_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_data_runtime_class = {
	"wi_data_t",
	_wi_data_dealloc,
	_wi_data_copy,
	_wi_data_is_equal,
	_wi_data_description,
	_wi_data_hash
};



void wi_data_register(void) {
	_wi_data_runtime_id = wi_runtime_register_class(&_wi_data_runtime_class);
}



void wi_data_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_data_runtime_id(void) {
	return _wi_data_runtime_id;
}



#pragma mark -

wi_data_t * wi_data_with_random_bytes(uint32_t length) {
	return wi_autorelease(wi_data_init_with_random_bytes(wi_data_alloc(), length));
}



wi_data_t * wi_data_with_base64(wi_string_t *base64) {
	return wi_autorelease(wi_data_init_with_base64(wi_data_alloc(), base64));
}



#pragma mark -

wi_data_t * wi_data_alloc(void) {
	return wi_runtime_create_instance(_wi_data_runtime_id, sizeof(wi_data_t));
}



wi_data_t * wi_data_init_with_capacity(wi_data_t *data, uint32_t capacity) {
	data->capacity	= capacity;
	data->bytes		= wi_malloc(data->capacity);
	
	return data;
}



wi_data_t * wi_data_init_with_bytes(wi_data_t *data, const void *bytes, uint32_t length) {
	data = wi_data_init_with_capacity(data, length);

	memcpy(data->bytes, bytes, length);
	data->length = length;
	
	return data;
}



#ifdef WI_SSL
wi_data_t * wi_data_init_with_random_bytes(wi_data_t *data, uint32_t length) {
	data = wi_data_init_with_capacity(data, length);
	
	RAND_bytes(data->bytes, length);
	
	data->length = length;
	
	return data;
}
#endif



wi_data_t * wi_data_init_with_base64(wi_data_t *data, wi_string_t *base64) {
	const char		*buffer;
	char			ch, inbuffer[4], outbuffer[3];
	uint32_t		length, count, i, position, offset;
	wi_boolean_t	ignore, stop, end;
	
	length		= wi_string_length(base64);
	buffer		= wi_string_cstring(base64);
	position	= 0;
	offset		= 0;
	data		= wi_data_init_with_capacity(data, length);
	
	while(position < length) {
		ignore = end = false;
		ch = buffer[position++];
		
		if(ch >= 'A' && ch <= 'Z')
			ch = ch - 'A';
		else if(ch >= 'a' && ch <= 'z')
			ch = ch - 'a' + 26;
		else if(ch >= '0' && ch <= '9')
			ch = ch - '0' + 52;
		else if(ch == '+')
			ch = 62;
		else if(ch == '=')
			end = true;
		else if(ch == '/')
			ch = 63;
		else
			ignore = true;
		
		if(!ignore) {
			count = 3;
			stop = false;
			
			if(end) {
				if(offset == 0)
					break;
				else if(offset == 1 || offset == 2)
					count = 1;
				else
					count = 2;
				
				offset = 3;
				stop = true;
			}
			
			inbuffer[offset++] = ch;
			
			if(offset == 4) {
				outbuffer[0] =  (inbuffer[0]         << 2) | ((inbuffer[1] & 0x30) >> 4);
				outbuffer[1] = ((inbuffer[1] & 0x0F) << 4) | ((inbuffer[2] & 0x3C) >> 2);
				outbuffer[2] = ((inbuffer[2] & 0x03) << 6) |  (inbuffer[3] & 0x3F);
				
				for(i = 0; i < count; i++)
					wi_data_append_bytes(data, &outbuffer[i], 1);

				offset = 0;
			}
			
			if(stop)
				break;
		}
	}
	
	return data;
}



static void _wi_data_dealloc(wi_runtime_instance_t *instance) {
	wi_data_t		*data = instance;
	
	wi_free(data->bytes);
}



static wi_runtime_instance_t * _wi_data_copy(wi_runtime_instance_t *instance) {
	wi_data_t		*data = instance;
	
	return wi_data_init_with_bytes(wi_data_alloc(), data->bytes, data->length);
}



static wi_boolean_t _wi_data_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_data_t		*data1 = instance1;
	wi_data_t		*data2 = instance2;
	
	if(data1->length != data2->length)
		return false;
	
	return (memcmp(data1->bytes, data2->bytes, data1->length) == 0);
}



static wi_hash_code_t _wi_data_hash(wi_runtime_instance_t *instance) {
	wi_data_t		*data = instance;
	
	return wi_hash_pointer(data);
}



static wi_string_t * _wi_data_description(wi_runtime_instance_t *instance) {
	wi_data_t			*data = instance;
	wi_string_t			*description;
	const unsigned char	*bytes;
	uint32_t			i;
	
	description = wi_string();
	bytes = data->bytes;
	
	for(i = 0; i < data->length; i++) {
		if(i > 0 && i % 4 == 0)
			wi_string_append_string(description, WI_STR(" "));

		wi_string_append_format(description, WI_STR("%02X"), bytes[i]);
	}
	
	return description;
}



#pragma mark -

const void * wi_data_bytes(wi_data_t *data) {
	return data->bytes;
}



uint32_t wi_data_length(wi_data_t *data) {
	return data->length;
}



#pragma mark -

void wi_data_append_data(wi_data_t *data, wi_data_t *append_data) {
	wi_data_append_bytes(data, append_data->bytes, append_data->length);
}



void wi_data_append_bytes(wi_data_t *data, const void *bytes, uint32_t length) {
	if(data->length + length > data->capacity) {
		data->capacity	= data->length + length;
		data->bytes		= wi_realloc(data->bytes, data->capacity);
	}
	
	memcpy(data->bytes + data->length, bytes, length);

	data->length += length;
}



#pragma mark -

#ifdef WI_SSL

wi_string_t * wi_data_md5(wi_data_t *data) {
	static unsigned char	hex[] = "0123456789abcdef";
	MD5_CTX					c;
	unsigned char			md5[MD5_DIGEST_LENGTH];
	char					md5_hex[sizeof(md5) * 2 + 1];
	unsigned int			i;

	MD5_Init(&c);
	MD5_Update(&c, data->bytes, data->length);
	MD5_Final(md5, &c);
	
	for(i = 0; i < MD5_DIGEST_LENGTH; i++) {
		md5_hex[i+i]	= hex[md5[i] >> 4];
		md5_hex[i+i+1]	= hex[md5[i] & 0x0F];
	}

	md5_hex[i+i] = '\0';

	return wi_string_with_cstring(md5_hex);
}



wi_string_t * wi_data_sha1(wi_data_t *data) {
	static unsigned char	hex[] = "0123456789abcdef";
	SHA_CTX					c;
	unsigned char			sha1[SHA_DIGEST_LENGTH];
	char					sha1_hex[sizeof(sha1) * 2 + 1];
	unsigned int			i;

	SHA1_Init(&c);
	SHA1_Update(&c, data->bytes, data->length);
	SHA1_Final(sha1, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		sha1_hex[i+i]	= hex[sha1[i] >> 4];
		sha1_hex[i+i+1]	= hex[sha1[i] & 0x0F];
	}

	sha1_hex[i+i] = '\0';

	return wi_string_with_cstring(sha1_hex);
}

#endif



wi_string_t * wi_data_base64(wi_data_t *data) {
	static char			base64_table[] =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	wi_string_t			*base64;
	unsigned char		*bytes, inbuffer[3], outbuffer[4];
	unsigned int		i, length, count, position, offset, remaining;
	size_t				size;

	position	= 0;
	offset		= 0;
	length		= data->length;
	size		= (length * (4.0 / 3.0)) + 3;
	bytes		= data->bytes;
	base64		= wi_string_init_with_capacity(wi_string_alloc(), size);
	
	while(position < length) {
		for(i = 0; i < 3; i++) {
			if(position + i < length)
				inbuffer[i] = bytes[position + i];
			else
				inbuffer[i] = '\0';
		}

		outbuffer[0] =  (inbuffer[0] & 0xFC) >> 2;
		outbuffer[1] = ((inbuffer[0] & 0x03) << 4) | ((inbuffer[1] & 0xF0) >> 4);
		outbuffer[2] = ((inbuffer[1] & 0x0F) << 2) | ((inbuffer[2] & 0xC0) >> 6);
		outbuffer[3] =   inbuffer[2] & 0x3F;

		remaining = length - position;
		
		if(remaining == 1)
			count = 2;
		else if(remaining == 2)
			count = 3;
		else
			count = 4;

		for(i = 0; i < count; i++)
			wi_string_append_bytes(base64, &base64_table[outbuffer[i]], 1);

		for(i = count; i < 4; i++)
			wi_string_append_bytes(base64, "=", 1);

		position += 3;
	}
	
	return wi_autorelease(base64);
}
