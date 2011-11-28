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
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include <wired/wi-compat.h>
#include <wired/wi-macros.h>
#include <wired/wi-private.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>
#include <wired/wi-url.h>

struct _wi_url {
	wi_runtime_base_t					base;
	
	wi_string_t							*scheme;
	wi_string_t							*host;
	wi_uinteger_t						port;
	wi_string_t							*path;
	
	wi_string_t							*string;
};


static void								_wi_url_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_url_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_url_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *					_wi_url_description(wi_runtime_instance_t *);
static wi_hash_code_t					_wi_url_hash(wi_runtime_instance_t *);

static void								_wi_url_regenerate_string(wi_url_t *);


static wi_runtime_id_t					_wi_url_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_url_runtime_class = {
	"wi_url_t",
	_wi_url_dealloc,
	_wi_url_copy,
	_wi_url_is_equal,
	_wi_url_description,
	_wi_url_hash
};



void wi_url_register(void) {
	_wi_url_runtime_id = wi_runtime_register_class(&_wi_url_runtime_class);
}



void wi_url_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_url_runtime_id(void) {
	return _wi_url_runtime_id;
}



#pragma mark -

wi_url_t * wi_url_alloc(void) {
	return wi_runtime_create_instance(_wi_url_runtime_id, sizeof(wi_url_t));
}



wi_url_t * wi_url_init_with_string(wi_url_t *url, wi_string_t *string) {
	wi_range_t		range;
	
	range = wi_string_range_of_string(string, WI_STR("://"), 0);
	
	if(range.location != WI_NOT_FOUND) {
		url->scheme = wi_retain(wi_string_substring_to_index(string, range.location));
		
		if(range.location + range.length >= wi_string_length(string))
			goto end;
		else
			string = wi_string_substring_from_index(string, range.location + 3);
	}
	
	range = wi_string_range_of_string(string, WI_STR("/"), 0);
	
	if(range.location != WI_NOT_FOUND) {
		url->path	= wi_retain(wi_string_substring_from_index(string, range.location));
		string		= wi_string_substring_to_index(string, range.location);
	}
	
	range = wi_string_range_of_string(string, WI_STR(":"), 0);
	
	if(range.location == WI_NOT_FOUND) {
		url->host = wi_copy(string);
	} else {
		url->host = wi_retain(wi_string_substring_to_index(string, range.location));
		
		if(range.location + range.length < wi_string_length(string)) {
			string		= wi_string_substring_from_index(string, range.location + 1);
			url->port	= wi_string_uint32(string);
		}
	}
	
end:
	_wi_url_regenerate_string(url);
	
	return url;
}



static void _wi_url_dealloc(wi_runtime_instance_t *instance) {
	wi_url_t		*url = instance;
	
	wi_release(url->scheme);
	wi_release(url->host);
	wi_release(url->path);

	wi_release(url->string);
}



static wi_runtime_instance_t * _wi_url_copy(wi_runtime_instance_t *instance) {
	wi_url_t		*url = instance;
	
	return wi_url_init_with_string(wi_url_alloc(), url->string);
}



static wi_boolean_t _wi_url_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_url_t		*url1 = instance1;
	wi_url_t		*url2 = instance2;
	
	return (wi_is_equal(url1->string, url2->string));
}



static wi_string_t * _wi_url_description(wi_runtime_instance_t *instance) {
	wi_url_t		*url = instance;
	
	return wi_url_string(url);
}



static wi_hash_code_t _wi_url_hash(wi_runtime_instance_t *instance) {
	wi_url_t		*url = instance;
	
	return wi_hash(url->string);
}



#pragma mark -

void _wi_url_regenerate_string(wi_url_t *url) {
	wi_release(url->string);
	
	url->string = wi_string_init_with_format(wi_string_alloc(), WI_STR("%#@://%#@"), url->scheme, url->host);
	
	if(url->port > 0)
		wi_string_append_format(url->string, WI_STR(":%lu"), url->port);
	
	if(url->path)
		wi_string_append_string(url->string, url->path);
	else
		wi_string_append_string(url->string, WI_STR("/"));
}



#pragma mark -

void wi_url_set_scheme(wi_url_t *url, wi_string_t *scheme) {
	wi_retain(scheme);
	wi_release(url->scheme);
	
	url->scheme = scheme;
	
	_wi_url_regenerate_string(url);
}



wi_string_t * wi_url_scheme(wi_url_t *url) {
	return url->scheme;
}



void wi_url_set_host(wi_url_t *url, wi_string_t *host) {
	wi_retain(host);
	wi_release(url->host);
	
	url->host = host;
	
	_wi_url_regenerate_string(url);
}



wi_string_t * wi_url_host(wi_url_t *url) {
	return url->host;
}



void wi_url_set_port(wi_url_t *url, wi_uinteger_t port) {
	url->port = port;
}



wi_uinteger_t wi_url_port(wi_url_t *url) {
	return url->port;
}



void wi_url_set_path(wi_url_t *url, wi_string_t *path) {
	wi_retain(path);
	wi_release(url->path);
	
	url->path = path;
	
	_wi_url_regenerate_string(url);
}



wi_string_t * wi_url_path(wi_url_t *url) {
	return url->path;
}



#pragma mark -

wi_boolean_t wi_url_is_valid(wi_url_t *url) {
	return (url->scheme && url->host);
}



wi_string_t * wi_url_string(wi_url_t *url) {
	return url->string;
}
