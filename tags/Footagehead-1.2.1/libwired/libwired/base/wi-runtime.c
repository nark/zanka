/* $Id$ */

/*
 *  Copyright (c) 2005-2006 Axel Andersson
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
#include <unistd.h>
#include <string.h>

#include <wired/wi-assert.h>
#include <wired/wi-hash.h>
#include <wired/wi-lock.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include "wi-private.h"

#define _WI_RUNTIME_MAGIC				0xAC1DFEED
#define _WI_RUNTIME_OFFSET				0xDEADC0DE
#define _WI_RUNTIME_CLASS_TABLE_SIZE	256
#define _WI_RUNTIME_ZOMBIE_BIT			(1 << 31)

#define _WI_RUNTIME_BASE(instance) \
	((wi_runtime_base_t *) instance)

#define _WI_RUNTIME_IS_ZOMBIE(instance) \
	(_WI_RUNTIME_BASE((instance))->id & _WI_RUNTIME_ZOMBIE_BIT)

#define _WI_RUNTIME_ASSERT_MAGIC(instance) \
	WI_ASSERT((_WI_RUNTIME_BASE((instance))->magic == _WI_RUNTIME_MAGIC), "%p is not a valid instance", (instance))

#define _WI_RUNTIME_ASSERT_ZOMBIE(instance)			\
	WI_STMT_START									\
		if(_WI_RUNTIME_IS_ZOMBIE((instance)))		\
			_wi_runtime_zombie_abort((instance));	\
	WI_STMT_END


static void								_wi_runtime_null_abort(wi_runtime_instance_t *);
static void								_wi_runtime_zombie_abort(wi_runtime_instance_t *);


wi_boolean_t							wi_zombie_enabled = false;

static wi_runtime_class_t				*_wi_runtime_class_table[_WI_RUNTIME_CLASS_TABLE_SIZE] = {NULL};
static uint32_t							_wi_runtime_class_table_count = 0;

static wi_recursive_lock_t				*_wi_runtime_retain_count_lock;

static wi_runtime_id_t					_wi_runtime_null_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_runtime_null_class = {
	"wi_runtime_null_class",
	(void *) _wi_runtime_null_abort,
	(void *) _wi_runtime_null_abort,
	(void *) _wi_runtime_null_abort,
	(void *) _wi_runtime_null_abort,
	(void *) _wi_runtime_null_abort
};



void wi_runtime_register(void) {
	_wi_runtime_null_id = wi_runtime_register_class(&_wi_runtime_null_class);
}



void wi_runtime_initialize(void) {
	char		*env;
	
	_wi_runtime_retain_count_lock = wi_recursive_lock_init(wi_recursive_lock_alloc());
	
	env = getenv("wi_zombie_enabled");
	
	if(env)
		wi_zombie_enabled = (strcmp(env, "0") != 0);
}



#pragma mark -

wi_runtime_id_t wi_runtime_register_class(wi_runtime_class_t *class) {
	_wi_runtime_class_table[_wi_runtime_class_table_count++] = class;
	
	return _wi_runtime_class_table_count - 1;
}



wi_runtime_instance_t * wi_runtime_create_instance(wi_runtime_id_t id, size_t size) {
	wi_runtime_instance_t	*instance;
	
	instance = wi_malloc(size);
	
	_WI_RUNTIME_BASE(instance)->magic = _WI_RUNTIME_MAGIC;
	_WI_RUNTIME_BASE(instance)->id = id;
	_WI_RUNTIME_BASE(instance)->retain_count = 1;
	
	return instance;
}



#pragma mark -

wi_runtime_class_t * wi_runtime_class_with_name(wi_string_t *name) {
	wi_runtime_class_t	*class;
	const char			*cname;
	uint32_t			i;
	
	cname = wi_string_cstring(name);
	
	for(i = 0; i < _wi_runtime_class_table_count; i++) {
		class = _wi_runtime_class_table[i];
		
		if(strcmp(class->name, cname) == 0)
			return class;
	}
	
	return NULL;
}



wi_runtime_class_t * wi_runtime_class_with_id(wi_runtime_id_t id) {
	if(id < _wi_runtime_class_table_count)
		return _wi_runtime_class_table[id];
	
	return NULL;
}



#pragma mark -

wi_runtime_class_t * wi_runtime_class(wi_runtime_instance_t *instance) {
	if(_WI_RUNTIME_BASE(instance)->magic == _WI_RUNTIME_MAGIC)
		return _wi_runtime_class_table[_WI_RUNTIME_BASE(instance)->id];
	
	return NULL;
}



const char * wi_runtime_class_name(wi_runtime_instance_t *instance) {
	wi_runtime_class_t		*class;
	
	class = wi_runtime_class(instance);
	
	if(class)
		return class->name;
	
	return NULL;
}



wi_runtime_id_t wi_runtime_id(wi_runtime_instance_t *instance) {
	if(_WI_RUNTIME_BASE(instance)->magic == _WI_RUNTIME_MAGIC)
		return _WI_RUNTIME_BASE(instance)->id;
	
	return WI_RUNTIME_ID_NULL;
}



#pragma mark -

static void _wi_runtime_null_abort(wi_runtime_instance_t *instance) {
	WI_ASSERT(0, "%p has no associated class", instance);
}



static void _wi_runtime_zombie_abort(wi_runtime_instance_t *instance) {
	wi_pool_t		*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	WI_ASSERT(0, "%p %@ is a deallocated instance", instance, instance);
	wi_release(pool);
}



#pragma mark -

wi_runtime_instance_t * wi_retain(wi_runtime_instance_t *instance) {
	if(!instance)
		return NULL;

	_WI_RUNTIME_ASSERT_MAGIC(instance);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance);

	wi_recursive_lock_lock(_wi_runtime_retain_count_lock);
	
	_WI_RUNTIME_BASE(instance)->retain_count++;
	
	wi_recursive_lock_unlock(_wi_runtime_retain_count_lock);
	
	return instance;
}



uint32_t wi_retain_count(wi_runtime_instance_t *instance) {
	if(!instance)
		return 0;

	_WI_RUNTIME_ASSERT_MAGIC(instance);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance);
	
	return _WI_RUNTIME_BASE(instance)->retain_count;
}



void wi_release(wi_runtime_instance_t *instance) {
	wi_runtime_class_t		*class;
	
	if(!instance)
		return;
	
	_WI_RUNTIME_ASSERT_MAGIC(instance);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance);
	
	wi_recursive_lock_lock(_wi_runtime_retain_count_lock);

	if(--_WI_RUNTIME_BASE(instance)->retain_count == 0) {
		if(wi_zombie_enabled && _WI_RUNTIME_BASE(instance)->id != wi_pool_runtime_id()) {
			_WI_RUNTIME_BASE(instance)->id |= _WI_RUNTIME_ZOMBIE_BIT;
			_WI_RUNTIME_BASE(instance)->retain_count++;

			wi_recursive_lock_unlock(_wi_runtime_retain_count_lock);
		} else {
			wi_recursive_lock_unlock(_wi_runtime_retain_count_lock);

			class = _wi_runtime_class_table[_WI_RUNTIME_BASE(instance)->id];
			
			if(class->dealloc)
				class->dealloc(instance);

			wi_free(instance);
		}
	} else {
		wi_recursive_lock_unlock(_wi_runtime_retain_count_lock);
	}
}



#pragma mark -

wi_runtime_instance_t * wi_copy(wi_runtime_instance_t *instance) {
	wi_runtime_class_t		*class;
	
	if(!instance)
		return NULL;
	
	_WI_RUNTIME_ASSERT_MAGIC(instance);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance);
	
	class = _wi_runtime_class_table[_WI_RUNTIME_BASE(instance)->id];
	
	if(class->copy)
		return class->copy(instance);
	
	return NULL;
}



wi_boolean_t wi_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_runtime_class_t		*class1, *class2;

	if(instance1 == instance2)
		return true;
	
	if(!instance1 || !instance2)
		return false;

	_WI_RUNTIME_ASSERT_MAGIC(instance1);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance1);
	_WI_RUNTIME_ASSERT_MAGIC(instance2);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance2);
	
	class1 = _wi_runtime_class_table[_WI_RUNTIME_BASE(instance1)->id];
	class2 = _wi_runtime_class_table[_WI_RUNTIME_BASE(instance2)->id];

	if(class1 != class2)
		return false;

	if(class1->is_equal)
		return class1->is_equal(instance1, instance2);
	
	return false;
}



wi_string_t * wi_description(wi_runtime_instance_t *instance) {
	wi_runtime_class_t		*class;
	wi_runtime_id_t			id;
	
	if(!instance)
		return NULL;
	
	_WI_RUNTIME_ASSERT_MAGIC(instance);
	
	id = _WI_RUNTIME_BASE(instance)->id;
	
	if(_WI_RUNTIME_IS_ZOMBIE(instance))
		id &= ~_WI_RUNTIME_ZOMBIE_BIT;
	   
	class = _wi_runtime_class_table[id];

	if(class->description)
		return class->description(instance);

	return wi_string_with_format(WI_STR("<%s %p>"), class->name, instance);
}



wi_hash_code_t wi_hash(wi_runtime_instance_t *instance) {
	wi_runtime_class_t		*class;
	
	if(!instance)
		return 0;
	
	_WI_RUNTIME_ASSERT_MAGIC(instance);
	_WI_RUNTIME_ASSERT_ZOMBIE(instance);
	   
	class = _wi_runtime_class_table[_WI_RUNTIME_BASE(instance)->id];
	
	if(class->hash)
		return class->hash(instance);
	
	return wi_hash_pointer(instance);
}



#pragma mark -

void wi_show(wi_runtime_instance_t *instance) {
	wi_log_info(WI_STR("%@"), instance);
}
