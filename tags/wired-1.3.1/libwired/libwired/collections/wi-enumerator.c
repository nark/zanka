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

#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <string.h>

#include <wired/wi-array.h>
#include <wired/wi-enumerator.h>
#include <wired/wi-hash.h>
#include <wired/wi-list.h>
#include <wired/wi-runtime.h>
#include <wired/wi-set.h>
#include <wired/wi-string.h>

#include "wi-private.h"

enum _wi_enumerator_type {
	_WI_ENUMERATOR_ARRAY,
	_WI_ENUMERATOR_HASH,
	_WI_ENUMERATOR_LIST,
	_WI_ENUMERATOR_SET
};
typedef enum _wi_enumerator_type		_wi_enumerator_type_t;


union _wi_enumerator_context {
	uint32_t							array;
	void								*hash;
	void								*list;
	void								*set;
};
typedef union _wi_enumerator_context	_wi_enumerator_context_t;


struct _wi_enumerator {
	wi_runtime_base_t					base;
	
	_wi_enumerator_type_t				type;
	
	wi_runtime_instance_t				*collection;
	wi_enumerator_func_t				*func;
	
	_wi_enumerator_context_t			context;
};

static void								_wi_enumerator_dealloc(wi_runtime_instance_t *);
static wi_string_t *					_wi_enumerator_description(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_enumerator_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_enumerator_runtime_class = {
	"wi_enumerator_t",
	_wi_enumerator_dealloc,
	NULL,
	NULL,
	_wi_enumerator_description,
	NULL
};


void wi_enumerator_register(void) {
	_wi_enumerator_runtime_id = wi_runtime_register_class(&_wi_enumerator_runtime_class);
}



void wi_enumerator_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_enumerator_runtime_id(void) {
	return _wi_enumerator_runtime_id;
}



#pragma mark -

wi_enumerator_t * wi_enumerator_alloc(void) {
	return wi_runtime_create_instance(_wi_enumerator_runtime_id, sizeof(wi_enumerator_t));
}



static wi_enumerator_t * _wi_enumerator_init_with_collection(wi_enumerator_t *enumerator, wi_runtime_instance_t *collection, void *func) {
	enumerator->collection	= wi_retain(collection);
	enumerator->func		= func;
	
	return enumerator;
}



wi_enumerator_t * wi_enumerator_init_with_array(wi_enumerator_t *enumerator, wi_array_t *array, wi_enumerator_func_t *func) {
	enumerator			= _wi_enumerator_init_with_collection(enumerator, array, func);
	enumerator->type	= _WI_ENUMERATOR_ARRAY;
	
	return enumerator;
}



wi_enumerator_t * wi_enumerator_init_with_hash(wi_enumerator_t *enumerator, wi_hash_t *hash, wi_enumerator_func_t *func) {
	enumerator			= _wi_enumerator_init_with_collection(enumerator, hash, func);
	enumerator->type	= _WI_ENUMERATOR_HASH;
	
	return enumerator;
}



wi_enumerator_t * wi_enumerator_init_with_list(wi_enumerator_t *enumerator, wi_list_t *list, wi_enumerator_func_t *func) {
	enumerator			= _wi_enumerator_init_with_collection(enumerator, list, func);
	enumerator->type	= _WI_ENUMERATOR_LIST;
	
	return enumerator;
}



wi_enumerator_t * wi_enumerator_init_with_set(wi_enumerator_t *enumerator, wi_set_t *set, wi_enumerator_func_t *func) {
	enumerator			= _wi_enumerator_init_with_collection(enumerator, set, func);
	enumerator->type	= _WI_ENUMERATOR_SET;
	
	return enumerator;
}



static void _wi_enumerator_dealloc(wi_runtime_instance_t *instance) {
	wi_enumerator_t		*enumerator = instance;
	
	wi_release(enumerator->collection);
}



static wi_string_t * _wi_enumerator_description(wi_runtime_instance_t *instance) {
	wi_enumerator_t			*enumerator = instance;

	return wi_string_with_format(WI_STR("<%s %p>{collection = %@}"),
		wi_runtime_class_name(enumerator),
		enumerator,
		enumerator->collection);
}



#pragma mark -

void * wi_enumerator_next_data(wi_enumerator_t *enumerator) {
	void		*context;
	
	switch(enumerator->type) {
		case _WI_ENUMERATOR_ARRAY:
			context = &enumerator->context.array;
			break;
			
		case _WI_ENUMERATOR_HASH:
			context = &enumerator->context.hash;
			break;
			
		case _WI_ENUMERATOR_LIST:
			context = &enumerator->context.list;
			break;
			
		case _WI_ENUMERATOR_SET:
			context = &enumerator->context.set;
			break;
		
		default:
			return NULL;
			break;
	}
	
	return (*enumerator->func)(enumerator->collection, context);
}
