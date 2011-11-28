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
	
	wi_thread_t							*thread;
};
typedef struct _wi_pool_stack			_wi_pool_stack_t;


struct _wi_pool {
	wi_runtime_base_t					base;
	
	_wi_pool_array_t					*array;
};


static void								_wi_pool_dealloc(wi_runtime_instance_t *);

static void								_wi_pool_add_pool(wi_pool_t *);
static void								_wi_pool_add_poolstack(_wi_pool_stack_t *);
static void								_wi_pool_add_pool_to_poolstack(wi_pool_t *, _wi_pool_stack_t *);
static wi_pool_t *						_wi_pool_pool(void);
static _wi_pool_stack_t *				_wi_pool_poolstack(uint32_t *);
static void								_wi_pool_remove_pool(wi_pool_t *);
static void								_wi_pool_remove_poolstack(_wi_pool_stack_t *, uint32_t);
static void								_wi_pool_pop_pool(wi_pool_t *);


static _wi_pool_stack_t					**_wi_pool_stacks[_WI_POOL_STACKS_BUCKETS];
static uint32_t							_wi_pool_stacks_capacities[_WI_POOL_STACKS_BUCKETS];
static uint32_t							_wi_pool_stacks_lengths[_WI_POOL_STACKS_BUCKETS];
static wi_lock_t						*_wi_pool_stacks_lock;

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
	_wi_pool_stacks_lock = wi_lock_init(wi_lock_alloc());
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
	_wi_pool_stack_t		*stack;
	
	stack = _wi_pool_poolstack(NULL);
	
	if(!stack) {
		stack = wi_malloc(sizeof(_wi_pool_stack_t));
		stack->thread = wi_thread_current_thread();
		
		_wi_pool_add_poolstack(stack);
	}
	
	_wi_pool_add_pool_to_poolstack(pool, stack);
}



static void _wi_pool_add_poolstack(_wi_pool_stack_t *stack) {
	uint32_t		index, capacity, length;
	
	index = wi_hash_pointer(stack->thread) % _WI_POOL_STACKS_BUCKETS;
	
	wi_lock_lock(_wi_pool_stacks_lock);
	
	capacity	= _wi_pool_stacks_capacities[index];
	length		= _wi_pool_stacks_lengths[index];
	
	if(length >= capacity) {
		capacity += capacity;
		
		if(capacity < _WI_POOL_STACKS_INITIAL_SIZE)
			capacity = _WI_POOL_STACKS_INITIAL_SIZE;
		
		_wi_pool_stacks[index] = wi_realloc(_wi_pool_stacks[index], capacity * sizeof(_wi_pool_stack_t));
		_wi_pool_stacks_capacities[index] = capacity;
	}
	
	_wi_pool_stacks[index][length] = stack;
	_wi_pool_stacks_lengths[index] = ++length;
	
	wi_lock_unlock(_wi_pool_stacks_lock);
}



static void _wi_pool_add_pool_to_poolstack(wi_pool_t *pool, _wi_pool_stack_t *stack) {
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
	
	stack = _wi_pool_poolstack(NULL);
	
	if(!stack)
		return NULL;
	
	return stack->pools[stack->length - 1];
}



static _wi_pool_stack_t * _wi_pool_poolstack(uint32_t *stack_index) {
	wi_thread_t				*thread;
	_wi_pool_stack_t		**stacks, *stack;
	uint32_t				i, index, length;
	
	thread = wi_thread_current_thread();
	index = wi_hash_pointer(thread) % _WI_POOL_STACKS_BUCKETS;
	stacks = _wi_pool_stacks[index];
	length = _wi_pool_stacks_lengths[index];
	
	for(i = 0; i < length; i++) {
		stack = *stacks++;
		
		if(stack->thread == thread) {
			if(stack_index)
				*stack_index = i;
			
			return stack;
		}
	}
	
	return NULL;
}



static void _wi_pool_remove_pool(wi_pool_t *pool) {
	_wi_pool_stack_t		*stack;
	wi_pool_t				*p;
	uint32_t				break_index, stack_index;
	int32_t					i;
	
	stack = _wi_pool_poolstack(&stack_index);
	
	if(!stack) {
		wi_log_warn(WI_STR("Orphaned pool in thread %@"), wi_thread_current_thread());
		
		return;
	}
	
	break_index = 0;
	
	for(i = stack->length - 1; i >= 0; --i) {
		p = stack->pools[i];
		
		if(p == pool) {
			stack->length	= i;
			break_index		= i;
		
			break;
		}
		
		wi_release(p);
	}
	
	if(break_index == 0)
		_wi_pool_remove_poolstack(stack, stack_index);
}



static void _wi_pool_remove_poolstack(_wi_pool_stack_t *stack, uint32_t stack_index) {
	_wi_pool_stack_t		**stacks;
	uint32_t				index, length;
	
	index = wi_hash_pointer(wi_thread_current_thread()) % _WI_POOL_STACKS_BUCKETS;

	wi_lock_lock(_wi_pool_stacks_lock);
	
	length = _wi_pool_stacks_lengths[index] - 1;
	stacks = _wi_pool_stacks[index];
	
	stacks[stack_index] = NULL;
	_wi_pool_stacks_lengths[index] = length;
	
	if(stack_index < length) {
		memmove(&stacks[stack_index],
				&stacks[stack_index + 1],
				sizeof(_wi_pool_stack_t **) * length);
	}
	
	if(stack->pools)
		wi_free(stack->pools);
	
	wi_free(stack);
	
	wi_lock_unlock(_wi_pool_stacks_lock);
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
	
	return instance;
}
