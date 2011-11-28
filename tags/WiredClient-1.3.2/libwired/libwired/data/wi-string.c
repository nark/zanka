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

#ifdef HAVE_CORESERVICES_CORESERVICES_H
#include <Carbon/Carbon.h>
#endif

#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <float.h>
#include <time.h>
#include <pwd.h>
#include <ctype.h>
#include <errno.h>

#ifdef HAVE_INTTYPES_H
#include <inttypes.h>
#endif

#ifdef WI_ICONV
#include <iconv.h>
#endif

#ifdef WI_CRYPTO
#include <openssl/rand.h>
#endif

#include <wired/wi-array.h>
#include <wired/wi-assert.h>
#include <wired/wi-compat.h>
#include <wired/wi-data.h>
#include <wired/wi-file.h>
#include <wired/wi-hash.h>
#include <wired/wi-lock.h>
#include <wired/wi-macros.h>
#include <wired/wi-private.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#define _WI_STRING_MIN_SIZE				128
#define _WI_STRING_FORMAT_BUFSIZ		64

#define _WI_STRING_GROW(string, n)										\
	WI_STMT_START														\
		if((string)->length + (n) >= (string)->capacity)				\
			_wi_string_grow((string), (string)->length + (n));			\
	WI_STMT_END

#define _WI_STRING_INDEX_ASSERT(string, index)							\
	WI_ASSERT((index) <= (string)->length,								\
		"index %d out of range (length %d) in \"%@\"",					\
		(index), (string)->length, (string))


struct _wi_string {
	wi_runtime_base_t					base;
	
	char								*string;
	wi_uinteger_t						length;
	wi_uinteger_t						capacity;
	wi_boolean_t						free;
};


static void								_wi_string_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_string_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_string_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *					_wi_string_description(wi_runtime_instance_t *);
static wi_hash_code_t					_wi_string_hash(wi_runtime_instance_t *);

static void								_wi_string_grow(wi_string_t *, wi_uinteger_t);
static void								_wi_string_append_arguments(wi_string_t *, const char *, va_list);

static wi_boolean_t						_wi_string_char_is_whitespace(char);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
static void								_wi_string_resolve_mac_alias_in_path(char *);
#endif


static wi_lock_t						*_wi_string_constant_string_lock;
static wi_hash_t						*_wi_string_constant_string_table;

static wi_runtime_id_t					_wi_string_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_string_runtime_class = {
	"wi_string_t",
	_wi_string_dealloc,
	_wi_string_copy,
	_wi_string_is_equal,
	_wi_string_description,
	_wi_string_hash
};



#ifdef WI_ICONV

struct _wi_string_encoding {
	wi_runtime_base_t					base;
	
	wi_string_t							*charset;
	wi_string_t							*encoding;

	wi_uinteger_t						options;
};


static void								_wi_string_encoding_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_string_encoding_copy(wi_runtime_instance_t *);
static wi_string_t *					_wi_string_encoding_description(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_string_encoding_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_string_encoding_runtime_class = {
	"wi_string_encoding_t",
	_wi_string_encoding_dealloc,
	_wi_string_encoding_copy,
	NULL,
	_wi_string_encoding_description,
	NULL
};

#endif



void wi_string_register(void) {
	_wi_string_runtime_id = wi_runtime_register_class(&_wi_string_runtime_class);
	
#ifdef WI_ICONV
	_wi_string_encoding_runtime_id = wi_runtime_register_class(&_wi_string_encoding_runtime_class);
#endif
}



void wi_string_initialize(void) {
	_wi_string_constant_string_lock = wi_lock_init(wi_lock_alloc());
	_wi_string_constant_string_table = wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
		2000, wi_hash_null_key_callbacks, wi_hash_default_value_callbacks);
}



#pragma mark -

wi_runtime_id_t wi_string_runtime_id(void) {
	return _wi_string_runtime_id;
}



#pragma mark -

wi_string_t * wi_string(void) {
	return wi_autorelease(wi_string_init(wi_string_alloc()));
}



wi_string_t * wi_string_with_cstring(const char *cstring) {
	return wi_autorelease(wi_string_init_with_cstring(wi_string_alloc(), cstring));
}



wi_string_t * wi_string_with_cstring_no_copy(char *cstring, wi_boolean_t free) {
	return wi_autorelease(wi_string_init_with_cstring_no_copy(wi_string_alloc(), cstring, free));
}



wi_string_t * wi_string_with_format(wi_string_t *fmt, ...) {
	wi_string_t		*string;
	va_list			ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	va_end(ap);
	
	return wi_autorelease(string);
}



wi_string_t * wi_string_with_data(wi_data_t *data) {
	return wi_autorelease(wi_string_init_with_data(wi_string_alloc(), data));
}



wi_string_t * wi_string_with_bytes(const void *buffer, wi_uinteger_t size) {
	return wi_autorelease(wi_string_init_with_bytes(wi_string_alloc(), buffer, size));
}



wi_string_t * wi_string_with_bytes_no_copy(void *buffer, wi_uinteger_t size, wi_boolean_t free) {
	return wi_autorelease(wi_string_init_with_bytes_no_copy(wi_string_alloc(), buffer, size, free));
}



wi_string_t * wi_string_with_base64(wi_string_t *base64) {
	return wi_autorelease(wi_string_init_with_base64(wi_string_alloc(), base64));
}



#pragma mark -

wi_string_t * wi_string_alloc(void) {
	return wi_runtime_create_instance(_wi_string_runtime_id, sizeof(wi_string_t));
}



wi_string_t * wi_string_init(wi_string_t *string) {
	return wi_string_init_with_capacity(string, 0);
}



wi_string_t * wi_string_init_with_capacity(wi_string_t *string, wi_uinteger_t capacity) {
	string->capacity	= WI_MAX(wi_exp2m1(wi_log2(capacity) + 1), _WI_STRING_MIN_SIZE);
	string->string		= wi_malloc(string->capacity);
	string->length		= 0;
	string->free		= true;
	
	return string;
}



wi_string_t * wi_string_init_with_cstring_no_copy(wi_string_t *string, char *cstring, wi_boolean_t free) {
	string->length		= strlen(cstring);
	string->capacity	= string->capacity;
	string->string		= cstring;
	string->free		= free;
	
	return string;
}



wi_string_t * wi_string_init_with_cstring(wi_string_t *string, const char *cstring) {
	string = wi_string_init_with_capacity(string, strlen(cstring));
	
	wi_string_append_cstring(string, cstring);

	return string;
}



wi_string_t * wi_string_init_with_data(wi_string_t *string, wi_data_t *data) {
	return wi_string_init_with_bytes(string, wi_data_bytes(data), wi_data_length(data));
}



wi_string_t * wi_string_init_with_bytes(wi_string_t *string, const void *buffer, wi_uinteger_t size) {
	string = wi_string_init_with_capacity(string, size);
	
	wi_string_append_bytes(string, buffer, size);

	return string;
}



wi_string_t * wi_string_init_with_bytes_no_copy(wi_string_t *string, void *buffer, wi_uinteger_t size, wi_boolean_t free) {
	string->length		= size;
	string->capacity	= string->capacity;
	string->string		= buffer;
	string->free		= free;
	
	return string;
}



#ifdef WI_SSL
wi_string_t * wi_string_init_random_string_with_length(wi_string_t *string, wi_uinteger_t length) {
	unsigned char		*buffer;
	
	buffer = wi_malloc(length);
	
	RAND_bytes(buffer, length);
	
	string = wi_string_init_with_bytes(string, (char *) buffer, length);
	
	wi_free(buffer);
	
	return string;
}
#endif



wi_string_t * wi_string_init_with_format(wi_string_t *string, wi_string_t *fmt, ...) {
	va_list		ap;
	
	va_start(ap, fmt);
	string = wi_string_init_with_format_and_arguments(string, fmt, ap);
	va_end(ap);
	
	return string;
}



wi_string_t * wi_string_init_with_format_and_arguments(wi_string_t *string, wi_string_t *fmt, va_list ap) {
	string = wi_string_init(string);
	
	_wi_string_append_arguments(string, wi_string_cstring(fmt), ap);
	
	return string;
}



wi_string_t * wi_string_init_with_base64(wi_string_t *string, wi_string_t *base64) {
	wi_data_t		*data;
	
	data = wi_data_init_with_base64(wi_data_alloc(), base64);
	string = wi_string_init_with_data(string, data);
	wi_release(data);
	
	return string;
}



wi_string_t * wi_string_init_with_contents_of_file(wi_string_t *string, wi_string_t *path) {
	wi_file_t       *file;
	
	wi_release(string);
		
	file = wi_file_for_reading(path);
	
	if(!file)
		return NULL;
	
	return wi_retain(wi_file_read_to_end_of_file(file));
}



static void _wi_string_dealloc(wi_runtime_instance_t *instance) {
	wi_string_t		*string = instance;
	
	if(string->string && string->free)
		wi_free(string->string);
}



static wi_runtime_instance_t * _wi_string_copy(wi_runtime_instance_t *instance) {
	wi_string_t		*string = instance;
	
	return wi_string_init_with_cstring(wi_string_alloc(), string->string);
}



static wi_boolean_t _wi_string_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	return (wi_string_compare(instance1, instance2) == 0);
}



static wi_string_t * _wi_string_description(wi_runtime_instance_t *instance) {
	wi_string_t		*string = instance;
	
	return wi_string_with_cstring(string->string);
}



static wi_hash_code_t _wi_string_hash(wi_runtime_instance_t *instance) {
	wi_string_t		*string = instance;
	
	return wi_hash_cstring(string->string, string->length);
}



#pragma mark -


wi_integer_t wi_string_compare(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_string_t		*string1 = instance1;
	wi_string_t		*string2 = instance2;

	return strcmp(string1->string, string2->string);
}



wi_integer_t wi_string_case_insensitive_compare(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_string_t		*string1 = instance1;
	wi_string_t		*string2 = instance2;

	return strcasecmp(string1->string, string2->string);
}



#pragma mark -

wi_uinteger_t wi_string_length(wi_string_t *string) {
	return string ? string->length : 0;
}



const char * wi_string_cstring(wi_string_t *string) {
	return string->string;
}



char wi_string_character_at_index(wi_string_t *string, wi_uinteger_t index) {
	_WI_STRING_INDEX_ASSERT(string, index);

	return string->string[index];
}



#pragma mark -

wi_string_t * _wi_string_constant_string(const char *cstring) {
	wi_string_t			*string, *newstring;
	wi_uinteger_t		count;
	
	wi_lock_lock(_wi_string_constant_string_lock);
	string = wi_hash_data_for_key(_wi_string_constant_string_table, (void *) cstring);
	wi_lock_unlock(_wi_string_constant_string_lock);
	
	if(!string) {
		newstring = string = wi_string_init_with_cstring(wi_string_alloc(), cstring);
		
		wi_lock_lock(_wi_string_constant_string_lock);
		
		count = wi_hash_count(_wi_string_constant_string_table);

		wi_hash_set_data_for_key(_wi_string_constant_string_table, string, (void *) cstring);
		
		if(wi_hash_count(_wi_string_constant_string_table) == count)
			string = wi_hash_data_for_key(_wi_string_constant_string_table, (void *) cstring);
		
		wi_lock_unlock(_wi_string_constant_string_lock);
		
		wi_release(newstring);
	}
	
	return string;
}



#pragma mark -

static void _wi_string_grow(wi_string_t *string, wi_uinteger_t capacity) {
	capacity = WI_MAX(wi_exp2m1(wi_log2(capacity) + 1), _WI_STRING_MIN_SIZE);

	string->string = wi_realloc(string->string, capacity);
	string->capacity = capacity;
}



static void _wi_string_append_arguments(wi_string_t *string, const char *fmt, va_list ap) {
	wi_string_t			*description;
	const char			*p, *pfmt;
	char				*s, *vbuffer, cfmt[_WI_STRING_FORMAT_BUFSIZ], buffer[_WI_STRING_FORMAT_BUFSIZ];
	wi_uinteger_t		i, size, totalsize;
	int					ch, length;
	wi_boolean_t		alt, star, h, hh, j, t, l, ll, L, z;
	
	pfmt = fmt;
	
	while(true) {
		memset(cfmt, 0, sizeof(cfmt));
		
		i = totalsize = length = 0;
		p = pfmt;
		
		while(*pfmt && *pfmt != '%')
			pfmt++;

		size = pfmt - p;
		
		if(size > 0)
			wi_string_append_bytes(string, p, size);
		
		if(!*pfmt)
			return;
		
		alt = star = h = hh = j = t = l = ll = L = z = false;
		
		ch			= *pfmt++;
		cfmt[i++]	= ch;

nextflag:
		ch			= *pfmt++;
		cfmt[i++]	= ch;

		switch(ch) {
			case '#':
				alt = true;
				
				goto nextflag;
				break;
				
			case '@':
				description = wi_description(va_arg(ap, wi_runtime_instance_t *));
				
				if(description) {
					wi_string_append_cstring(string, description->string);
					totalsize += description->length;
				}
				else if(!alt) {
					wi_string_append_cstring(string, "(null)");
					totalsize += 6;
				}
				break;
			
			case ' ':
			case '-':
			case '+':
			case '.':
			case '\'':
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
				goto nextflag;
				break;
			
			case '*':
				star = true;
				length = va_arg(ap, int);
				
				goto nextflag;
				break;
				
			case 'h':
				if(h)
					hh = true;
				else
					h = true;

				goto nextflag;
				break;
				
			case 'j':
				j = true;
				
				goto nextflag;
				break;
			
			case 't':
				t = true;
				
				goto nextflag;
				break;
			
			case 'l':
				if(l)
					ll = true;
				else
					l = true;

				goto nextflag;
				break;

			case 'L':
				L = true;
				
				goto nextflag;
				break;
			
			case 'a':
			case 'A':
			case 'e':
			case 'E':
			case 'f':
			case 'g':
			case 'G':
				if(L)
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, long double));
				else
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, double));
				
				wi_string_append_bytes(string, buffer, size);
				totalsize += size;
				break;
				
				
				wi_string_append_bytes(string, buffer, size);
				totalsize += size;
				break;
				
			case 'c':
			case 'D':
			case 'd':
			case 'i':
			case 'O':
			case 'o':
			case 'p':
			case 'U':
			case 'u':
			case 'X':
			case 'x':
				if(ll)
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, long long));
				else if(l || ch == 'D' || ch == 'O' || ch == 'U')
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, long));
				else if(ch == 'p')
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, void *));
#ifdef HAVE_INTMAX_T
				else if(j)
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, intmax_t));
#endif
#ifdef HAVE_PTRDIFF_T
				else if(t)
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, ptrdiff_t));
#endif
				else if(z)
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, size_t));
				else
					size = snprintf(buffer, sizeof(buffer), cfmt, va_arg(ap, int));
				
				wi_string_append_bytes(string, buffer, size);
				totalsize += size;
				break;
			
			case 'm':
				description = wi_error_string();
				wi_string_append_cstring(string, description->string);
				totalsize += description->length;
				break;
			
			case 'n':
				if(hh)
					*(va_arg(ap, signed char *)) = totalsize;
				else if(h)
					*(va_arg(ap, short *)) = totalsize;
				if(ll)
					*(va_arg(ap, long long *)) = totalsize;
				else if(l)
					*(va_arg(ap, long *)) = totalsize;
#ifdef HAVE_INTMAX_T
				else if(j)
					*(va_arg(ap, intmax_t *)) = totalsize;
#endif
#ifdef HAVE_PTRDIFF_T
				else if(t)
					*(va_arg(ap, ptrdiff_t *)) = totalsize;
#endif
				else if(z)
					*(va_arg(ap, size_t *)) = totalsize;
				break;
			
			case 's':
				s = va_arg(ap, char *);
				
				if(s) {
					if(star)
						size = wi_asprintf(&vbuffer, cfmt, length, s);
					else
						size = wi_asprintf(&vbuffer, cfmt, s);
					
					if(size > 0 && vbuffer) {
						wi_string_append_bytes(string, vbuffer, size);
						totalsize += size;
						free(vbuffer);
					}
				}
				else if(!alt) {
					wi_string_append_cstring(string, "(null)");
					totalsize += 6;
				}
				break;
			
			case 'z':
				z = true;
				
				goto nextflag;
				break;
				
			default:
				if(ch == '\0')
					return;
				
				buffer[0] = ch;

				wi_string_append_bytes(string, buffer, 1);
				totalsize += 1;
				break;
		}
	}
}



#pragma mark -

void wi_string_set_string(wi_string_t *string, wi_string_t *otherstring) {
	if(string->string != otherstring->string) {
		string->string[0]	= '\0';
		string->length		= 0;

		wi_string_append_cstring(string, otherstring->string);
	}
}



void wi_string_set_format(wi_string_t *string, wi_string_t *fmt, ...) {
	va_list		ap;
	
	va_start(ap, fmt);
	wi_string_set_format_and_arguments(string, fmt, ap);
	va_end(ap);
	
}



void wi_string_set_format_and_arguments(wi_string_t *string, wi_string_t *fmt, va_list ap) {
	wi_string_t		*newstring;
	
	newstring = wi_string_init_with_format_and_arguments(wi_string_alloc(), fmt, ap);
	wi_string_set_string(string, newstring);
	wi_release(newstring);
}



#pragma mark -

void wi_string_append_cstring(wi_string_t *string, const char *cstring) {
	wi_string_append_bytes(string, cstring, strlen(cstring));
}



wi_string_t * wi_string_by_appending_cstring(wi_string_t *string, const char *cstring) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_by_appending_cstring(newstring, cstring);
	
	return wi_autorelease(newstring);
}



void wi_string_append_bytes(wi_string_t *string, const void *buffer, wi_uinteger_t length) {
	_WI_STRING_GROW(string, length);
	
	memmove(string->string + string->length, buffer, length);
	
	string->length += length;
	string->string[string->length] = '\0';
}



wi_string_t * wi_string_by_appending_bytes(wi_string_t *string, const void *buffer, wi_uinteger_t length) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_append_bytes(newstring, buffer, length);
	
	return wi_autorelease(newstring);
}



void wi_string_append_string(wi_string_t *string, wi_string_t *otherstring) {
	wi_string_append_cstring(string, otherstring->string);
}



wi_string_t * wi_string_by_appending_string(wi_string_t *string, wi_string_t *otherstring) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_append_cstring(newstring, otherstring->string);
	
	return wi_autorelease(newstring);
}



void wi_string_append_format(wi_string_t *string, wi_string_t *fmt, ...) {
	va_list			ap;
	
	va_start(ap, fmt);
	_wi_string_append_arguments(string, wi_string_cstring(fmt), ap);
	va_end(ap);
}



wi_string_t * wi_string_by_appending_format(wi_string_t *string, wi_string_t *fmt, ...) {
	wi_string_t		*newstring;
	va_list			ap;
	
	va_start(ap, fmt);
	newstring = wi_copy(string);
	_wi_string_append_arguments(newstring, wi_string_cstring(fmt), ap);
	va_end(ap);
	
	return wi_autorelease(newstring);
}



void wi_string_append_format_and_arguments(wi_string_t *string, wi_string_t *fmt, va_list ap) {
	_wi_string_append_arguments(string, wi_string_cstring(fmt), ap);
}



wi_string_t * wi_string_by_appending_format_and_arguments(wi_string_t *string, wi_string_t *fmt, va_list ap) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	_wi_string_append_arguments(newstring, wi_string_cstring(fmt), ap);
	
	return wi_autorelease(newstring);
}



#pragma mark -

void wi_string_insert_string_at_index(wi_string_t *string, wi_string_t *otherstring, wi_uinteger_t index) {
	_WI_STRING_INDEX_ASSERT(string, index);
	
	_WI_STRING_GROW(string, otherstring->length);
	
	memmove(string->string + index + otherstring->length,
			string->string + index,
			string->length);
	
	memmove(string->string + index, otherstring->string, otherstring->length);

	string->length += otherstring->length;
	string->string[string->length] = '\0';
}



#pragma mark -

void wi_string_delete_characters_in_range(wi_string_t *string, wi_range_t range) {
	_WI_STRING_INDEX_ASSERT(string, range.location + range.length);

	if(range.location + range.length < string->length) {
		memmove(string->string + range.location,
				string->string + range.location + range.length,
				string->length - range.location - range.length);
	}
	
	string->length -= range.length;
	string->string[string->length] = '\0';
}



wi_string_t * wi_string_by_deleting_characters_in_range(wi_string_t *string, wi_range_t range) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_delete_characters_in_range(newstring, range);
	
	return wi_autorelease(newstring);
}



void wi_string_delete_characters_from_index(wi_string_t *string, wi_uinteger_t index) {
	wi_string_delete_characters_in_range(string, wi_make_range(index, string->length - index));
}



wi_string_t * wi_string_by_deleting_characters_from_index(wi_string_t *string, wi_uinteger_t index) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_delete_characters_from_index(newstring, index);
	
	return wi_autorelease(newstring);
}



void wi_string_delete_characters_to_index(wi_string_t *string, wi_uinteger_t index) {
	wi_string_delete_characters_in_range(string, wi_make_range(0, index));
}



wi_string_t * wi_string_by_deleting_characters_to_index(wi_string_t *string, wi_uinteger_t index) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_delete_characters_to_index(newstring, index);
	
	return wi_autorelease(newstring);
}



static wi_boolean_t _wi_string_char_is_whitespace(char ch) {
	return (ch == ' ' || ch == '\t' || ch == '\n');
}



void wi_string_delete_surrounding_whitespace(wi_string_t *string) {
	while(string->length > 0 && _wi_string_char_is_whitespace(string->string[0]))
		wi_string_delete_characters_in_range(string, wi_make_range(0, 1));

	while(string->length > 0 && _wi_string_char_is_whitespace(string->string[string->length - 1]))
		wi_string_delete_characters_in_range(string, wi_make_range(string->length - 1, 1));
}



wi_string_t * wi_string_by_deleting_surrounding_whitespace(wi_string_t *string) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_delete_surrounding_whitespace(newstring);
	
	return wi_autorelease(newstring);
}



#pragma mark -

wi_string_t * wi_string_substring_with_range(wi_string_t *string, wi_range_t range) {
	_WI_STRING_INDEX_ASSERT(string, range.location + range.length);

	return wi_autorelease(wi_string_init_with_bytes(wi_string_alloc(), string->string + range.location, range.length));
}



wi_string_t * wi_string_substring_from_index(wi_string_t *string, wi_uinteger_t index) {
	return wi_string_substring_with_range(string, wi_make_range(index, string->length - index));
}



wi_string_t * wi_string_substring_to_index(wi_string_t *string, wi_uinteger_t index) {
	return wi_string_substring_with_range(string, wi_make_range(0, index));
}



wi_array_t * wi_string_components_separated_by_string(wi_string_t *string, wi_string_t *separator) {
	wi_string_t		*component;
	wi_array_t		*array;
	const char		*cstring;
	char			*s, *ss, *ap;
	
	array	= wi_array_init(wi_array_alloc());
	cstring	= wi_string_cstring(separator);
	
	s = ss = strdup(string->string);
	
	while((ap = wi_strsep(&s, cstring))) {
		component = wi_string_init_with_cstring(wi_string_alloc(), ap);
		wi_array_add_data(array, component);
		wi_release(component);
	}
	
	free(ss);
	
	return wi_autorelease(array);
}



#pragma mark -

wi_range_t wi_string_range_of_string(wi_string_t *string, wi_string_t *otherstring, wi_string_options_t options) {
	return wi_string_range_of_string_in_range(string, otherstring, options, wi_make_range(0, string->length));
}



wi_range_t wi_string_range_of_string_in_range(wi_string_t *string, wi_string_t *otherstring, wi_string_options_t options, wi_range_t inrange) {
	wi_range_t		range;
	
	range.location = wi_string_index_of_string_in_range(string, otherstring, options, inrange);
	
	if(range.location == WI_NOT_FOUND)
		range.length = 0;
	else
		range.length = otherstring->length;
	
	return range;
}



wi_uinteger_t wi_string_index_of_string(wi_string_t *string, wi_string_t *otherstring, wi_string_options_t options) {
	return wi_string_index_of_string_in_range(string, otherstring, options, wi_make_range(0, string->length));
}



wi_uinteger_t wi_string_index_of_string_in_range(wi_string_t *string, wi_string_t *otherstring, wi_string_options_t options, wi_range_t range) {
	char			*p;
	wi_uinteger_t	i, index;
	wi_boolean_t	insensitive = false;
	
	if(options & WI_STRING_CASE_INSENSITIVE) {
		insensitive = true;
	}
	else if(options & WI_STRING_SMART_CASE_INSENSITIVE) {
		insensitive = true;
		
		for(i = 0; i < otherstring->length; i++) {
			if(isupper(otherstring->string[i])) {
				insensitive = false;
				
				break;
			}
		}
	}
	
	p = insensitive
		? wi_strncasestr(string->string + range.location, otherstring->string, range.length)
		: wi_strnstr(string->string + range.location, otherstring->string, range.length);
	
	if(!p)
		return WI_NOT_FOUND;
	
	index = p - string->string;
	
	if(index > range.location + range.length)
		return WI_NOT_FOUND;
	
	return index;
}



wi_uinteger_t wi_string_index_of_char(wi_string_t *string, int ch, wi_string_options_t options) {
	wi_uinteger_t	i, index = WI_NOT_FOUND;
	char			*p;
	int				c;
	wi_boolean_t	insensitive = false;

	if((options & WI_STRING_CASE_INSENSITIVE) ||
	   (options & WI_STRING_SMART_CASE_INSENSITIVE && isupper(ch))) {
		insensitive = true;
		ch = tolower((unsigned int) ch);
	}

	p = string->string;
	
	for(i = 0; *p; p++, i++) {
		c = insensitive ? tolower((unsigned int) *p) : *p;
		
		if(c == ch) {
			index = i;

			if(!(options & WI_STRING_BACKWARDS))
				break;
		}
	}
	
	return index;
}

 

wi_boolean_t wi_string_contains_string(wi_string_t *string, wi_string_t *otherstring, wi_string_options_t options) {
	return (wi_string_index_of_string(string, otherstring, options) != WI_NOT_FOUND);
}



wi_boolean_t wi_string_has_prefix(wi_string_t *string, wi_string_t *prefix) {
	return (strncmp(string->string, prefix->string, prefix->length) == 0);
}



wi_boolean_t wi_string_has_suffix(wi_string_t *string, wi_string_t *suffix) {
	wi_integer_t	offset;

	offset = string->length - suffix->length;

	if(offset < 0)
		return false;

	return (strcmp(string->string + offset, suffix->string) == 0);
}



#pragma mark -

wi_string_t * wi_string_lowercase_string(wi_string_t *string) {
	wi_string_t		*newstring;
	wi_uinteger_t	i;
	
	newstring = wi_copy(string);
	
	for(i = 0; i < newstring->length; i++)
		newstring->string[i] = tolower((unsigned int) newstring->string[i]);
	
	return wi_autorelease(newstring);
}



wi_string_t * wi_string_uppercase_string(wi_string_t *string) {
	wi_string_t		*newstring;
	wi_uinteger_t	i;
	
	newstring = wi_copy(string);
	
	for(i = 0; i < newstring->length; i++)
		newstring->string[i] = toupper((unsigned int) newstring->string[i]);
	
	return wi_autorelease(newstring);
}



#pragma mark -

wi_array_t * wi_string_path_components(wi_string_t *path) {
	wi_array_t		*array, *components;
	wi_string_t		*component;
	wi_uinteger_t	i, count;
	
	components	= wi_string_components_separated_by_string(path, WI_STR("/"));
	count		= wi_array_count(components);
	array		= wi_array_init_with_capacity(wi_array_alloc(), count);

	for(i = 0; i < count; i++) {
		component = WI_ARRAY(components, i);

		if(wi_string_length(component) > 0)
			wi_array_add_data(array, component);
		else if(i == 0)
			wi_array_add_data(array, WI_STR("/"));
	}

	return wi_autorelease(array);
}



void wi_string_normalize_path(wi_string_t *path) {
	wi_array_t		*array;
	wi_string_t		*component, *string;
	wi_boolean_t	absolute;
	wi_uinteger_t	i, count;
	
	if(wi_string_length(path) == 0 || wi_is_equal(path, WI_STR("/")))
	   return;

	wi_string_expand_tilde_in_path(path);

	absolute	= wi_string_has_prefix(path, WI_STR("/"));
	array		= wi_string_path_components(path);
	count		= wi_array_count(array);
	
	for(i = 0; i < count; i++) {
		component = WI_ARRAY(array, i);

		if(wi_string_length(component) == 0 || wi_is_equal(component, WI_STR("/"))) {
			wi_array_remove_data_at_index(array, i);

			i--;
			count--;
		}
		else if(wi_is_equal(component, WI_STR("."))) {
			wi_array_remove_data_at_index(array, i);
			
			i--;
			count--;
		}
		else if(absolute && wi_is_equal(component, WI_STR("..")) && i > 0) {
			wi_array_remove_data_at_index(array, i - 1);
			wi_array_remove_data_at_index(array, i - 1);
			
			i -= 2;
			count -= 2;
		}
	}
	
	string = wi_array_components_joined_by_string(array, WI_STR("/"));
	
	if(wi_string_has_prefix(path, WI_STR("/")))
		wi_string_insert_string_at_index(string, WI_STR("/"), 0);
		
	wi_string_set_string(path, string);
}



wi_string_t * wi_string_by_normalizing_path(wi_string_t *path) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_normalize_path(string);
	
	return wi_autorelease(string);
}



#ifdef HAVE_CORESERVICES_CORESERVICES_H

static void _wi_string_resolve_mac_alias_in_path(char *path) {
	FSRef		fsRef;
	Boolean		isDir, isAlias;

	if(FSPathMakeRef((UInt8 *) path, &fsRef, NULL) != noErr)
		return;
	
	if(FSIsAliasFile(&fsRef, &isAlias, &isDir) != noErr)
		return;
	
	if(!isAlias)
		return;

	if(FSResolveAliasFile(&fsRef, true, &isDir, &isAlias) != noErr)
		return;

	if(FSRefMakePath(&fsRef, (UInt8 *) path, WI_PATH_SIZE) != noErr)
		return;
}

#endif



void wi_string_resolve_aliases_in_path(wi_string_t *path) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	wi_string_t		*string;
	char			fullpath[WI_PATH_SIZE] = "";
	char			*p, *pp, *ap;
	
	p = pp = strdup(path->string);
	
	while((ap = wi_strsep(&pp, "/"))) {
		if(ap[0]) {
			wi_strlcat(fullpath, "/", sizeof(fullpath));
			wi_strlcat(fullpath, ap, sizeof(fullpath));
			
			_wi_string_resolve_mac_alias_in_path(fullpath);
		}
	}
	
	free(p);
	
	if(strlen(fullpath) > 0 && strcmp(path->string, fullpath) != 0) {
		string = wi_string_init_with_cstring(wi_string_alloc(), fullpath);
		wi_string_set_string(path, string);
		wi_release(string);
	}
#endif
}



wi_string_t * wi_string_by_resolving_aliases_in_path(wi_string_t *path) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_resolve_aliases_in_path(string);
	
	return wi_autorelease(string);
}



void wi_string_expand_tilde_in_path(wi_string_t *path) {
	wi_array_t		*array;
	wi_string_t		*component, *string;
	struct passwd	*user;
	wi_uinteger_t	length;
	
	if(!wi_string_has_prefix(path, WI_STR("~")))
		return;

	array		= wi_string_path_components(path);
	component	= WI_ARRAY(array, 0);
	length		= wi_string_length(component);
	
	if(length == 1) {
		user = getpwuid(getuid());
	} else {
		wi_string_delete_characters_to_index(component, 1);
		
		user = getpwnam(wi_string_cstring(component));
	}
	
	if(user) {
		wi_string_delete_characters_to_index(path, length);
		
		string = wi_string_init_with_cstring(wi_string_alloc(), user->pw_dir);
		wi_string_insert_string_at_index(path, string, 0);
		wi_release(string);
	}
}



wi_string_t * wi_string_by_expanding_tilde_in_path(wi_string_t *path) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_expand_tilde_in_path(string);
	
	return wi_autorelease(string);
}



void wi_string_append_path_component(wi_string_t *path, wi_string_t *component) {
	if(wi_string_length(path) == 0) {
		wi_string_append_string(path, component);
	}
	else if(wi_string_has_suffix(path, WI_STR("/"))) {
		if(wi_string_has_prefix(component, WI_STR("/")))
		   wi_string_delete_characters_from_index(path, path->length - 1);

		wi_string_append_string(path, component);
	}
	else if(!wi_is_equal(component, WI_STR("/"))) {
	   wi_string_append_format(path, WI_STR("/%@"), component);
	}
}



wi_string_t * wi_string_by_appending_path_component(wi_string_t *path, wi_string_t *component) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_append_path_component(string, component);
	
	return wi_autorelease(string);
}



wi_string_t * wi_string_last_path_component(wi_string_t *path) {
	return wi_array_last_data(wi_string_path_components(path));
}



void wi_string_delete_last_path_component(wi_string_t *path) {
	wi_array_t		*array;
	wi_string_t		*string;
	wi_uinteger_t	count;
	
	if(wi_is_equal(path, WI_STR("/")))
		return;
	
	array = wi_string_path_components(path);
	count = wi_array_count(array);
	
	if(count > 0) {
		wi_array_remove_data_at_index(array, count - 1);
		
		string = wi_array_components_joined_by_string(array, WI_STR("/"));
		wi_string_normalize_path(string);
		wi_string_set_string(path, string);
	}
}



wi_string_t * wi_string_by_deleting_last_path_component(wi_string_t *path) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_delete_last_path_component(string);
	
	return wi_autorelease(string);
}



wi_string_t * wi_string_path_extension(wi_string_t *path) {
	wi_uinteger_t	index;
	
	index = wi_string_index_of_char(path, '.', WI_STRING_BACKWARDS);

	if(index != WI_NOT_FOUND && index + 1 < path->length)
		return wi_string_by_deleting_characters_to_index(path, index + 1);
	
	return WI_STR("");
}



void wi_string_delete_path_extension(wi_string_t *path) {
	wi_uinteger_t	index;
	
	index = wi_string_index_of_char(path, '.', WI_STRING_BACKWARDS);

	if(index != WI_NOT_FOUND)
		wi_string_delete_characters_from_index(path, index);
}



wi_string_t * wi_string_by_deleting_path_extension(wi_string_t *path) {
	wi_string_t		*string;
	
	string = wi_copy(path);
	wi_string_delete_path_extension(string);
	
	return wi_autorelease(string);
}



#pragma mark -

wi_boolean_t wi_string_bool(wi_string_t *string) {
	if(strcasecmp(string->string, "yes") == 0)
		return true;
	
	return (wi_string_int32(string) > 0);
}



int32_t wi_string_int32(wi_string_t *string) {
	long		l;
	char		*ep;
	
	errno = 0;
	l = strtol(string->string, &ep, 0);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0;
	
	if(l > INT32_MAX || l < INT32_MIN)
		return 0;
	
	return (int32_t) l;
}



uint32_t wi_string_uint32(wi_string_t *string) {
	unsigned long	ul;
	char			*ep;
	
	errno = 0;
	ul = strtoul(string->string, &ep, 0);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0;
	
	if(ul > UINT32_MAX)
		return 0;
	
	return (uint32_t) ul;
}



int64_t wi_string_int64(wi_string_t *string) {
	long long	ll;
	char		*ep;
	
	errno = 0;
	ll = strtoll(string->string, &ep, 0);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0;
	
	return (int64_t) ll;
}



uint64_t wi_string_uint64(wi_string_t *string) {
	unsigned long long	ull;
	char				*ep;
	
	errno = 0;
	ull = strtoull(string->string, &ep, 0);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0ULL;
	
	return (uint64_t) ull;
}



wi_integer_t wi_string_integer(wi_string_t *string) {
#if WI_32
	return (wi_integer_t) wi_string_int32(string);
#else
	return (wi_integer_t) wi_string_int64(string);
#endif
}



wi_uinteger_t wi_string_uinteger(wi_string_t *string) {
#if WI_32
	return (wi_uinteger_t) wi_string_uint32(string);
#else
	return (wi_uinteger_t) wi_string_uint64(string);
#endif
}



float wi_string_float(wi_string_t *string) {
	double		d;
	char		*ep;
	
	errno = 0;
	d = strtod(string->string, &ep);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0.0;
	
	if(d > FLT_MAX || d < FLT_MIN)
		return 0.0;
	
	return (float) d;
}



double wi_string_double(wi_string_t *string) {
	double		d;
	char		*ep;
	
	errno = 0;
	d = strtod(string->string, &ep);
	
	if(string->string == ep || *ep != '\0' || errno == ERANGE)
		return 0.0;
	
	return d;
}



#pragma mark -

wi_data_t * wi_string_data(wi_string_t *string) {
	return wi_autorelease(wi_data_init_with_bytes(wi_data_alloc(), string->string, string->length));
}



wi_string_t * wi_string_md5(wi_string_t *string) {
	return wi_data_md5(wi_string_data(string));
}



wi_string_t * wi_string_sha1(wi_string_t *string) {
	return wi_data_sha1(wi_string_data(string));
}



wi_string_t * wi_string_base64(wi_string_t *string) {
	static char			base64_table[] =
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	wi_string_t			*base64_string;
	unsigned char		inbuffer[3], outbuffer[4];
	wi_uinteger_t		i, count, position, offset, remaining, size;

	position = offset = 0;
	size = string->length * (4.0f / 3.0f) + 4;
	base64_string = wi_string_init_with_capacity(wi_string_alloc(), size);

	while(position < string->length) {
		for(i = 0; i < 3; i++) {
			if(position + i < string->length)
				inbuffer[i] = string->string[position + i];
			else
				inbuffer[i] = '\0';
		}

		outbuffer[0] =  (inbuffer[0] & 0xFC) >> 2;
		outbuffer[1] = ((inbuffer[0] & 0x03) << 4) | ((inbuffer[1] & 0xF0) >> 4);
		outbuffer[2] = ((inbuffer[1] & 0x0F) << 2) | ((inbuffer[2] & 0xC0) >> 6);
		outbuffer[3] =   inbuffer[2] & 0x3F;

		remaining = string->length - position;
		
		if(remaining == 1)
			count = 2;
		else if(remaining == 2)
			count = 3;
		else
			count = 4;

		for(i = 0; i < count; i++)
			base64_string->string[offset++] = base64_table[outbuffer[i]];

		for(i = count; i < 4; i++)
			base64_string->string[offset++] = '=';

		position += 3;
	}

	base64_string->string[offset] = '\0';
	
	return wi_autorelease(base64_string);
}



#pragma mark -

#ifdef WI_ICONV

void wi_string_convert_encoding(wi_string_t *string, wi_string_encoding_t *from, wi_string_encoding_t *to) {
	char		*in, *out, *buffer;
	size_t		bytes, inbytes, outbytes, inbytesleft, outbytesleft;
	iconv_t		conv;
	
	conv = iconv_open(wi_string_cstring(to->encoding), wi_string_cstring(from->encoding));
	
	if(conv == (iconv_t) -1)
		return;
	
	inbytes = inbytesleft = string->length;
	outbytes = outbytesleft = string->length * 4;
	
	buffer = wi_malloc(outbytes);
	
	in = string->string;
	out = buffer;

#ifdef _LIBICONV_VERSION
	bytes = iconv(conv, (const char **) &in, &inbytesleft, &out, &outbytesleft);
#else
	bytes = iconv(conv, &in, &inbytesleft, &out, &outbytesleft);
#endif
	
	if(bytes == (size_t) -1) {
		wi_error_set_errno(errno);
	} else {
		string->string[0]	= '\0';
		string->length		= 0;

		wi_string_append_bytes(string, buffer, outbytes - outbytesleft);
	}
	
	wi_free(buffer);
	
	iconv_close(conv);
}



wi_string_t * wi_string_by_converting_encoding(wi_string_t *string, wi_string_encoding_t *from, wi_string_encoding_t *to) {
	wi_string_t		*newstring;
	
	newstring = wi_copy(string);
	wi_string_convert_encoding(newstring, from, to);
	
	return wi_autorelease(newstring);
}

#endif



#pragma mark -

wi_boolean_t wi_string_write_to_file(wi_string_t *string, wi_string_t *path) {
	FILE	*fp;
	char	fullpath[WI_PATH_SIZE];
	
	snprintf(fullpath, sizeof(fullpath), "%s~", path->string);

	fp = fopen(fullpath, "w");

	if(!fp) {
		wi_error_set_errno(errno);

		return false;
	}
	
	fprintf(fp, "%s", string->string);
	fclose(fp);
	
	if(rename(fullpath, path->string) < 0) {
		wi_error_set_errno(errno);

		(void) unlink(fullpath);
		
		return false;
	}
	
	return true;
}



#pragma mark -

#ifdef WI_ICONV

wi_runtime_id_t wi_string_encoding_runtime_id(void) {
	return _wi_string_encoding_runtime_id;
}



#pragma mark -

wi_string_encoding_t * wi_string_encoding_with_charset(wi_string_t *charset, wi_string_encoding_options_t options) {
	return wi_autorelease(wi_string_encoding_init_with_charset(wi_string_encoding_alloc(), charset, options));
}



#pragma mark -

wi_string_encoding_t * wi_string_encoding_alloc(void) {
	return wi_runtime_create_instance(_wi_string_encoding_runtime_id, sizeof(wi_string_encoding_t));
}



wi_string_encoding_t * wi_string_encoding_init_with_charset(wi_string_encoding_t *encoding, wi_string_t *charset, wi_string_encoding_options_t options) {
	iconv_t			iconv;
	
	encoding->charset = wi_copy(charset);
	encoding->encoding = wi_copy(charset);
	encoding->options = options;
	
	if(options & WI_STRING_ENCODING_IGNORE)
		wi_string_append_string(encoding->encoding, WI_STR("//IGNORE"));
		
	if(options & WI_STRING_ENCODING_TRANSLITERATE)
		wi_string_append_string(encoding->encoding, WI_STR("//TRANSLIT"));
	
	iconv = iconv_open(wi_string_cstring(encoding->encoding), wi_string_cstring(encoding->encoding));
	
	if(iconv == (iconv_t) -1) {
		wi_error_set_errno(errno);

		wi_release(encoding);
		
		return NULL;
	}
	
	iconv_close(iconv);
	
	return encoding;
}



static void _wi_string_encoding_dealloc(wi_runtime_instance_t *instance) {
	wi_string_encoding_t		*encoding = instance;
	
	wi_release(encoding->charset);
	wi_release(encoding->encoding);
}



static wi_runtime_instance_t * _wi_string_encoding_copy(wi_runtime_instance_t *instance) {
	wi_string_encoding_t		*encoding = instance;
	
	return wi_string_encoding_init_with_charset(wi_string_encoding_alloc(), encoding->charset, encoding->options);
}



static wi_string_t * _wi_string_encoding_description(wi_runtime_instance_t *instance) {
	wi_string_encoding_t		*encoding = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{encoding = %@}"),
	  wi_runtime_class_name(encoding),
	  encoding,
	  encoding->encoding);
}



#pragma mark -

wi_string_t * wi_string_encoding_charset(wi_string_encoding_t *encoding) {
	return encoding->charset;
}

#endif /* WI_ICONV */
