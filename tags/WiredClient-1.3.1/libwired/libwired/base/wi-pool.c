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

#include <wired/wi-lock.h>
#include <wired/wi-log.h>
#include <wired/wi-pool.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>
#include <wired/wi-thread.h>

#include "wi-private.h"

#define _WI_POOL_ARRAY_SIZE \
	((4096 - sizeof(uint32_t) - sizeof(void *)) / sizeof(void *))

#define _WI_POOL_STACK_INITIAL_SIZE		4
#define _WI_POOL_STACKS_INITIAL_SIZE	4
#define _WI_POOL_STACKS_BUCKETS			64


struct _wi_pool_array {
	wi_runtime_instance_t				*instances[_WI_POOL_ARRAY_SIZE];
	uint32_t							length;
	
	struct _wi_pool_array				*next;
};
typedef struct _wi_pool_array			_wi_pool_array_t;


struct _wi_pool_stack {
	wi_pool_t							**pools;
	uint32_t							capacity;
	uint32_t							length;
};
typedef struct _wi_pool_stack			_wi_pool_stack_t;


struct _wi_pool {
	wi_runtime_base_t					base;
	
	uint32_t							count;
	_wi_pool_array_t					*array;
};


static void								_wi_pool_dealloc(wi_runtime_instance_t *);

static void								_wi_pool_add_pool(wi_pool_t *);
static wi_pool_t *						_wi_pool_pool(void);
static void								_wi_pool_remove_pool(wi_pool_t *);
static void								_wi_pool_pop_pool(wi_pool_t *);


static wi_runtime_id_t					_wi_pool_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_pool_runtime_class = {
	"wi_pool_t",
	_wi_pool_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



void wi_pool_register(void) {
	_wi_pool_runtime_id = wi_runtime_register_class(&_wi_pool_runtime_class);
}



void wi_pool_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_pool_runtime_id(void) {
	return _wi_pool_runtime_id;
}



#pragma mark -

wi_pool_t * wi_pool_alloc(void) {
	return wi_runtime_create_instance(_wi_pool_runtime_id, sizeof(wi_pool_t));
}



wi_pool_t * wi_pool_init(wi_pool_t *pool) {
	_wi_pool_add_pool(pool);
	
	pool->array = wi_malloc(sizeof(_wi_pool_array_t));
	
	return pool;
}



static void _wi_pool_dealloc(wi_runtime_instance_t *instance) {
	wi_pool_t			*pool = instance;
	_wi_pool_array_t	*array, *next_array;
	
	_wi_pool_remove_pool(pool);
	_wi_pool_pop_pool(pool);
	
	for(array = pool->array; array; array = next_array) {
		next_array = array->next;
		wi_free(array);
	}
}



#pragma mark -

static void _wi_pool_add_pool(wi_pool_t *pool) {
	wi_thread_t				*thread;
	_wi_pool_stack_t		*stack;
	
	thread	= wi_thread_current_thread();
	stack	= wi_thread_poolstack(thread);
	
	if(!stack) {
		stack = wi_malloc(sizeof(_wi_pool_stack_t));
		wi_thread_set_poolstack(thread, stack);
	}
	
	if(stack->length >= stack->capacity) {
		stack->capacity += stack->capacity;
		
		if(stack->capacity < _WI_POOL_STACK_INITIAL_SIZE)
			stack->capacity = _WI_POOL_STACK_INITIAL_SIZE;
		
		stack->pools = wi_realloc(stack->pools, stack->capacity * sizeof(wi_pool_t *));
	}
	
	stack->pools[stack->length] = pool;
	stack->length++;
}



static wi_pool_t * _wi_pool_pool(void) {
	_wi_pool_stack_t		*stack;
	
	stack = wi_thread_poolstack(wi_thread_current_thread());
	
	if(!stack)
		return NULL;
	
	return stack->pools[stack->length - 1];
}



static void _wi_pool_remove_pool(wi_pool_t *pool) {
	wi_thread_t				*thread;
	_wi_pool_stack_t		*stack;
	
	thread	= wi_thread_current_thread();
	stack	= wi_thread_poolstack(thread);
	
	if(!stack) {
		wi_log_warn(WI_STR("Orphaned pool in thread %@"), wi_thread_current_thread());
		
		return;
	}
	
	if(pool != stack->pools[stack->length - 1]) {
		wi_log_warn(WI_STR("Removing pool that is not on top of stack in thread %@"), thread);
		
		return;
	}
	
	stack->pools[stack->length - 1] = NULL;
	stack->length--;
	
	if(stack->length == 0) {
		if(stack->pools)
			wi_free(stack->pools);
		
		wi_free(stack);
		
		wi_thread_set_poolstack(thread, NULL);
	}
}



static void _wi_pool_pop_pool(wi_pool_t *pool) {
	wi_runtime_instance_t		**instances;
	_wi_pool_array_t			*array;
	uint32_t					i, length;
	
	for(array = pool->array; array; array = array->next) {
		length		= array->length;
		instances	= array->instances;
		
		for(i = 0; i < length; i++)
			wi_release(*instances++);
	}
}



#pragma mark -

uint32_t wi_pool_count(wi_pool_t *pool) {
	return pool->count;
}



#pragma mark -

wi_runtime_instance_t * wi_autorelease(wi_runtime_instance_t *instance) {
	wi_pool_t			*pool;
	_wi_pool_array_t	*array, *new_array;
	
	if(!instance)
		return NULL;
	
	pool = _wi_pool_pool();

	if(!pool) {
		pool = wi_pool_init(wi_pool_alloc());
		wi_log_warn(WI_STR("Instance %p %@ autoreleased with no pool in place - just leaking"), instance, instance);
		wi_release(pool);

		return instance;
	}
	
	array = pool->array;
	
	if(array->length >= _WI_POOL_ARRAY_SIZE) {
		new_array = wi_malloc(sizeof(_wi_pool_array_t));
		new_array->next = array;
		
		array = new_array;
		pool->array = array;
	}
	
	array->instances[array->length] = instance;
	array->length++;
	pool->count++;
	
	return instance;
}
