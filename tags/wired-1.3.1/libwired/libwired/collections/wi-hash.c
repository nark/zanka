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
#include <stdarg.h>
#include <unistd.h>
#include <string.h>

#include <wired/wi-array.h>
#include <wired/wi-assert.h>
#include <wired/wi-hash.h>
#include <wired/wi-lock.h>
#include <wired/wi-macros.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include "wi-private.h"

#define _WI_HASH_MIN_COUNT				11
#define _WI_HASH_MAX_COUNT				16777213

#define _WI_HASH_CHECK_RESIZE(hash)									\
	WI_STMT_START													\
		if((hash->buckets_count >= 3 * hash->key_count &&			\
		    hash->buckets_count >  hash->min_count) ||				\
		   (hash->key_count     >= 3 * hash->buckets_count &&		\
			hash->buckets_count <  _WI_HASH_MAX_COUNT))				\
			_wi_hash_resize(hash);									\
	WI_STMT_END

#define _WI_HASH_KEY_RETAIN(hash, key)								\
	((hash)->key_callbacks.retain									\
		? (*(hash)->key_callbacks.retain)((key))					\
		: (key))

#define _WI_HASH_KEY_RELEASE(hash, key)								\
	WI_STMT_START													\
		if((hash)->key_callbacks.release)							\
			(*(hash)->key_callbacks.release)((key));				\
	WI_STMT_END

#define _WI_HASH_KEY_HASH(hash, key)								\
	((hash)->key_callbacks.hash										\
		? (*(hash)->key_callbacks.hash)((key))						\
		: wi_hash_pointer((key)))

#define _WI_HASH_KEY_IS_EQUAL(hash, key1, key2)						\
	(((hash)->key_callbacks.is_equal &&								\
	  (*(hash)->key_callbacks.is_equal)((key1), (key2))) ||			\
	 (!(hash)->key_callbacks.is_equal &&							\
	  (key1) == (key2)))

#define _WI_HASH_VALUE_RETAIN(hash, value)							\
	((hash)->value_callbacks.retain									\
		? (*(hash)->value_callbacks.retain)((value))				\
		: (value))

#define _WI_HASH_VALUE_RELEASE(hash, value)							\
	WI_STMT_START													\
		if((hash)->value_callbacks.release)							\
			(*(hash)->value_callbacks.release)((value));			\
	WI_STMT_END

#define _WI_HASH_VALUE_IS_EQUAL(hash, value1, value2)				\
	(((hash)->value_callbacks.is_equal &&							\
	  (*(hash)->value_callbacks.is_equal)((value1), (value2))) ||	\
	 (!(hash)->value_callbacks.is_equal &&							\
	  (value1) == (value2)))


struct _wi_hash_bucket {
	void								*key;
	void								*data;

	struct _wi_hash_bucket				*next, *link;
};
typedef struct _wi_hash_bucket			_wi_hash_bucket_t;


struct _wi_hash {
	wi_runtime_base_t					base;
	
	wi_hash_key_callbacks_t				key_callbacks;
	wi_hash_value_callbacks_t			value_callbacks;

	_wi_hash_bucket_t					**buckets;
	uint32_t							buckets_count;
	uint32_t							min_count;
	uint32_t							key_count;
	
	wi_rwlock_t							*lock;
	
	_wi_hash_bucket_t					**bucket_chunks;
	uint32_t							bucket_chunks_count;
	uint32_t							bucket_chunks_offset;

	_wi_hash_bucket_t					*bucket_free_list;
};


struct _wi_hash_cursor {
	uint32_t							index;
	_wi_hash_bucket_t					*bucket;
};
typedef struct _wi_hash_cursor			_wi_hash_cursor_t;


static void								_wi_hash_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_hash_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_hash_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *					_wi_hash_description(wi_runtime_instance_t *);

static _wi_hash_bucket_t *				_wi_enumerator_hash_enumerator(wi_runtime_instance_t *, void *);

static void								_wi_hash_resize(wi_hash_t *);

static _wi_hash_bucket_t *				_wi_hash_bucket_create(wi_hash_t *);
static _wi_hash_bucket_t *				_wi_hash_bucket_for_key(wi_hash_t *, void *, uint32_t);
static void								_wi_hash_bucket_remove(wi_hash_t *, _wi_hash_bucket_t *);
#ifdef HAVE_QSORT_R
static int								_wi_hash_compare_buckets(void *, const void *, const void *);
#else
static int								_wi_hash_compare_buckets(const void *, const void *);
#endif


const wi_hash_key_callbacks_t			wi_hash_default_key_callbacks = {
	wi_copy,
	wi_release,
	wi_is_equal,
	wi_description,
	wi_hash
};

const wi_hash_value_callbacks_t			wi_hash_default_value_callbacks = {
	wi_retain,
	wi_release,
	wi_is_equal,
	wi_description
};

static uint32_t							_wi_hash_buckets_per_page;

#ifndef HAVE_QSORT_R
static wi_lock_t						*_wi_hash_sort_lock;
static wi_compare_func_t				*_wi_hash_sort_function;
#endif

static wi_runtime_id_t					_wi_hash_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_hash_runtime_class = {
	"wi_hash_t",
	_wi_hash_dealloc,
	_wi_hash_copy,
	_wi_hash_is_equal,
	_wi_hash_description,
	NULL
};


void wi_hash_register(void) {
	_wi_hash_runtime_id = wi_runtime_register_class(&_wi_hash_runtime_class);
}



void wi_hash_initialize(void) {
	_wi_hash_buckets_per_page = wi_page_size() / sizeof(_wi_hash_bucket_t);

#ifndef HAVE_QSORT_R
	_wi_hash_sort_lock = wi_lock_init(wi_lock_alloc());
#endif
}



#pragma mark -

wi_runtime_id_t wi_hash_runtime_id(void) {
	return _wi_hash_runtime_id;
}



#pragma mark -

wi_hash_t * wi_hash_alloc(void) {
	return wi_runtime_create_instance(_wi_hash_runtime_id, sizeof(wi_hash_t));
}



wi_hash_t * wi_hash_init(wi_hash_t *hash) {
	return wi_hash_init_with_capacity(hash, 0);
}



wi_hash_t * wi_hash_init_with_capacity(wi_hash_t *hash, uint32_t capacity) {
	return wi_hash_init_with_capacity_and_callbacks(hash, capacity, wi_hash_default_key_callbacks, wi_hash_default_value_callbacks);
}



wi_hash_t * wi_hash_init_with_capacity_and_callbacks(wi_hash_t *hash, uint32_t capacity, wi_hash_key_callbacks_t key_callbacks, wi_hash_value_callbacks_t value_callbacks) {
	hash->key_callbacks			= key_callbacks;
	hash->value_callbacks		= value_callbacks;
	hash->bucket_chunks_offset	= _wi_hash_buckets_per_page;
	hash->min_count				= WI_MAX(wi_exp2m1(wi_log2(capacity) + 1), _WI_HASH_MIN_COUNT);
	hash->buckets_count			= hash->min_count;
	hash->buckets				= wi_malloc(hash->buckets_count * sizeof(_wi_hash_bucket_t *));
	hash->lock					= wi_rwlock_init(wi_rwlock_alloc());
	
	return hash;
}



wi_hash_t * wi_hash_init_with_data_and_keys(wi_hash_t *hash, ...) {
	void			*data, *key;
	va_list			ap;

	hash = wi_hash_init_with_capacity(hash, 0);

	va_start(ap, hash);
	while((data = va_arg(ap, void *))) {
		key = va_arg(ap, void *);
		
		wi_hash_set_data_for_key(hash, data, key);   
	}
	va_end(ap);
	
	return hash;
}



static wi_runtime_instance_t * _wi_hash_copy(wi_runtime_instance_t *instance) {
	wi_hash_t			*hash = instance, *hash_copy;
	_wi_hash_bucket_t	*bucket;
	uint32_t			i;
	
	hash_copy = wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(), hash->key_count, hash->key_callbacks, hash->value_callbacks);
	
	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next)
			wi_hash_set_data_for_key(hash_copy, bucket->data, bucket->key);
	}
	
	return hash_copy;
}



static void _wi_hash_dealloc(wi_runtime_instance_t *instance) {
	wi_hash_t		*hash = instance;
	uint32_t		i;

	wi_hash_remove_all_data(hash);

	if(hash->bucket_chunks) {
		for(i = 0; i < hash->bucket_chunks_count; i++)
			wi_free(hash->bucket_chunks[i]);

		wi_free(hash->bucket_chunks);
	}
	
	wi_free(hash->buckets);

	wi_release(hash->lock);
}



static wi_boolean_t _wi_hash_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_hash_t			*hash1 = instance1;
	wi_hash_t			*hash2 = instance2;
	_wi_hash_bucket_t	*bucket;
	uint32_t			i;

	if(hash1->key_count != hash2->key_count)
		return false;
	
	if(hash1->value_callbacks.is_equal != hash2->value_callbacks.is_equal)
		return false;
	
	for(i = 0; i < hash1->buckets_count; i++) {
		for(bucket = hash1->buckets[i]; bucket; bucket = bucket->next) {
			if(!_WI_HASH_VALUE_IS_EQUAL(hash1, bucket->data, wi_hash_data_for_key(hash2, bucket->key)))
				return false;
		}
	}
	
	return true;
}



static wi_string_t * _wi_hash_description(wi_runtime_instance_t *instance) {
	wi_hash_t			*hash = instance;
	_wi_hash_bucket_t	*bucket;
	wi_string_t			*string, *key_description, *value_description;
	uint32_t			i;

	string = wi_string_with_format(WI_STR("<%s %p>{count = %d, values = (\n"),
		wi_runtime_class_name(hash),
		hash,
		hash->key_count);

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next) {
			if(hash->key_callbacks.description)
				key_description = (*hash->key_callbacks.description)(bucket->key);
			else
				key_description = wi_string_with_format(WI_STR("%p"), bucket->key);

			if(hash->value_callbacks.description)
				value_description = (*hash->value_callbacks.description)(bucket->data);
			else
				value_description = wi_string_with_format(WI_STR("%p"), bucket->data);
			
			wi_string_append_format(string, WI_STR("    %@: %@\n"), key_description, value_description);
		}
	}
	
	wi_string_append_string(string, WI_STR(")}"));

	return string;
}



#pragma mark -

void wi_hash_wrlock(wi_hash_t *hash) {
	wi_rwlock_wrlock(hash->lock);
}



void wi_hash_rdlock(wi_hash_t *hash) {
	wi_rwlock_rdlock(hash->lock);
}



void wi_hash_unlock(wi_hash_t *hash) {
	wi_rwlock_unlock(hash->lock);
}



#pragma mark -

uint32_t wi_hash_count(wi_hash_t *hash) {
	return hash->key_count;
}



wi_array_t * wi_hash_all_keys(wi_hash_t *hash) {
	wi_array_t				*array;
	_wi_hash_bucket_t		*bucket;
	wi_array_callbacks_t	callbacks;
	uint32_t				i;
	
	callbacks.retain		= hash->key_callbacks.retain;
	callbacks.release		= hash->key_callbacks.release;
	callbacks.is_equal		= hash->key_callbacks.is_equal;
	callbacks.description	= hash->key_callbacks.description;
	array					= wi_array_init_with_capacity_and_callbacks(wi_array_alloc(), hash->key_count, callbacks);

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next)
			wi_array_add_data(array, bucket->key);
	}
	
	return wi_autorelease(array);
}



wi_array_t * wi_hash_all_values(wi_hash_t *hash) {
	wi_array_t				*array;
	_wi_hash_bucket_t		*bucket;
	wi_array_callbacks_t	callbacks;
	uint32_t				i;
	
	callbacks.retain		= hash->value_callbacks.retain;
	callbacks.release		= hash->value_callbacks.release;
	callbacks.is_equal		= hash->value_callbacks.is_equal;
	callbacks.description	= hash->value_callbacks.description;
	array					= wi_array_init_with_capacity_and_callbacks(wi_array_alloc(), hash->key_count, callbacks);

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next)
			wi_array_add_data(array, bucket->data);
	}
	
	return wi_autorelease(array);
}



wi_array_t * wi_hash_keys_sorted_by_value(wi_hash_t *hash, wi_compare_func_t *compare) {
	wi_array_t				*array, *buckets;
	_wi_hash_bucket_t		*bucket;
	wi_array_callbacks_t	callbacks;
	void					**data;
	uint32_t				i;
	
	if(hash->key_count == 0)
		return wi_autorelease(wi_array_init(wi_array_alloc()));
	
	callbacks.retain		= NULL;
	callbacks.release		= NULL;
	callbacks.is_equal		= NULL;
	callbacks.description	= NULL;
	buckets					= wi_array_init_with_capacity_and_callbacks(wi_array_alloc(), hash->key_count, callbacks);

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next)
			wi_array_add_data(buckets, bucket);
	}
	
	data = wi_malloc(sizeof(void *) * hash->key_count);
	wi_array_get_data(buckets, data);
	
#ifdef HAVE_QSORT_R
	qsort_r(data, hash->key_count, sizeof(void *), compare, _wi_hash_compare_buckets);
#else
	wi_lock_lock(_wi_hash_sort_lock);
	_wi_hash_sort_function = compare;
	qsort(data, hash->key_count, sizeof(void *), _wi_hash_compare_buckets);
	wi_lock_unlock(_wi_hash_sort_lock);
#endif

	wi_release(buckets);
	
	callbacks.retain		= hash->key_callbacks.retain;
	callbacks.release		= hash->key_callbacks.release;
	callbacks.is_equal		= hash->key_callbacks.is_equal;
	callbacks.description	= hash->key_callbacks.description;
	array					= wi_array_init_with_capacity_and_callbacks(wi_array_alloc(), hash->key_count, callbacks);

	for(i = 0; i < hash->key_count; i++)
		wi_array_add_data(array, ((_wi_hash_bucket_t *) data[i])->key);
	
	wi_free(data);

	return wi_autorelease(array);
}



#pragma mark -

wi_enumerator_t * wi_hash_key_enumerator(wi_hash_t *hash) {
	return wi_autorelease(wi_enumerator_init_with_hash(wi_enumerator_alloc(), hash, wi_enumerator_hash_key_enumerator));
}



wi_enumerator_t * wi_hash_data_enumerator(wi_hash_t *hash) {
	return wi_autorelease(wi_enumerator_init_with_hash(wi_enumerator_alloc(), hash, wi_enumerator_hash_data_enumerator));
}



static _wi_hash_bucket_t * _wi_enumerator_hash_enumerator(wi_runtime_instance_t *instance, void *context) {
	wi_hash_t				*hash = instance;
	_wi_hash_cursor_t		*cursor = context;
	_wi_hash_bucket_t		*bucket;
	
	while(cursor->index < hash->buckets_count) {
		bucket = cursor->bucket;
		
		if(bucket) {
			if(bucket->next) {
				bucket = bucket->next;
				cursor->bucket = bucket;
				
				return bucket;
			} else {
				cursor->index++;
			}
		}
		
		bucket = hash->buckets[cursor->index];
		
		if(bucket) {
			cursor->bucket = bucket;
			
			return bucket;
		} else {
			cursor->index++;
		}
	}
	
	return NULL;
}



void * wi_enumerator_hash_key_enumerator(wi_runtime_instance_t *instance, void *context) {
	_wi_hash_bucket_t		*bucket;
	
	bucket = _wi_enumerator_hash_enumerator(instance, context);
	
	if(bucket)
		return bucket->key;
	
	return NULL;
}



void * wi_enumerator_hash_data_enumerator(wi_runtime_instance_t *instance, void *context) {
	_wi_hash_bucket_t		*bucket;
	
	bucket = _wi_enumerator_hash_enumerator(instance, context);
	
	if(bucket)
		return bucket->data;
	
	return NULL;
}



#pragma mark -

static void _wi_hash_resize(wi_hash_t *hash) {
	_wi_hash_bucket_t	**buckets, *bucket, *next_bucket;
	uint32_t			i, index, capacity, buckets_count;

	capacity		= wi_exp2m1(wi_log2(hash->key_count) + 1);
	buckets_count	= WI_CLAMP(capacity, hash->min_count, _WI_HASH_MAX_COUNT);
	buckets			= wi_malloc(buckets_count * sizeof(_wi_hash_bucket_t *));

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = next_bucket) {
			next_bucket		= bucket->next;
			index			= _WI_HASH_KEY_HASH(hash, bucket->key) % buckets_count;
			bucket->next	= buckets[index];
			buckets[index]	= bucket;
		}
	}

	wi_free(hash->buckets);

	hash->buckets		= buckets;
	hash->buckets_count	= buckets_count;
}



#pragma mark -

static _wi_hash_bucket_t * _wi_hash_bucket_create(wi_hash_t *hash) {
	_wi_hash_bucket_t	*bucket, *bucket_block;
	size_t				size;

	if(!hash->bucket_free_list) {
		if(hash->bucket_chunks_offset == _wi_hash_buckets_per_page) {
			hash->bucket_chunks_count++;

			size = hash->bucket_chunks_count * sizeof(_wi_hash_bucket_t *);
			hash->bucket_chunks = wi_realloc(hash->bucket_chunks, size);

			size = _wi_hash_buckets_per_page * sizeof(_wi_hash_bucket_t);
			hash->bucket_chunks[hash->bucket_chunks_count - 1] = wi_malloc(size);

			hash->bucket_chunks_offset = 0;
		}

		bucket_block = hash->bucket_chunks[hash->bucket_chunks_count - 1];
		hash->bucket_free_list = &bucket_block[hash->bucket_chunks_offset++];
		hash->bucket_free_list->link = NULL;
	}

	bucket = hash->bucket_free_list;
	hash->bucket_free_list = bucket->link;

	return bucket;
}



static _wi_hash_bucket_t * _wi_hash_bucket_for_key(wi_hash_t *hash, void *key, uint32_t index) {
	_wi_hash_bucket_t	*bucket;
	
	bucket = hash->buckets[index];

	if(!bucket)
		return NULL;

	for(; bucket; bucket = bucket->next) {
		if(_WI_HASH_KEY_IS_EQUAL(hash, bucket->key, key))
			return bucket;
	}
		
	return NULL;
}



static void _wi_hash_bucket_remove(wi_hash_t *hash, _wi_hash_bucket_t *bucket) {
	_WI_HASH_KEY_RELEASE(hash, bucket->key);
	_WI_HASH_KEY_RELEASE(hash, bucket->data);
	
	bucket->link = hash->bucket_free_list;
	hash->bucket_free_list = bucket;

	hash->key_count--;
}



#ifdef HAVE_QSORT_R

static int _wi_hash_compare_buckets(void *context, const void *p1, const void *p2) {
	return (*(wi_compare_func_t *) context)((*(_wi_hash_bucket_t **) p1)->data, (*(_wi_hash_bucket_t **) p2)->data);
}

#else

static int _wi_hash_compare_buckets(const void *p1, const void *p2) {
	return (*_wi_hash_sort_function)((*(_wi_hash_bucket_t **) p1)->data, (*(_wi_hash_bucket_t **) p2)->data);
}

#endif



#pragma mark -

void wi_hash_set_data_for_key(wi_hash_t *hash, void *data, void *key) {
	_wi_hash_bucket_t	*bucket;
	uint32_t			index;
	
	index = _WI_HASH_KEY_HASH(hash, key) % hash->buckets_count;
	bucket = _wi_hash_bucket_for_key(hash, key, index);

	if(bucket) {
		_WI_HASH_VALUE_RETAIN(hash, data);
		_WI_HASH_VALUE_RELEASE(hash, bucket->data);
			
		bucket->data		= data;
	} else {
		bucket				= _wi_hash_bucket_create(hash);
		bucket->next		= hash->buckets[index];
		bucket->key			= _WI_HASH_KEY_RETAIN(hash, key);
		bucket->data		= _WI_HASH_VALUE_RETAIN(hash, data);

		hash->key_count++;
		hash->buckets[index] = bucket;
	}

	_WI_HASH_CHECK_RESIZE(hash);
}



void wi_hash_add_entries_from_hash(wi_hash_t *hash, wi_hash_t *otherhash) {
	_wi_hash_bucket_t	*bucket;
	uint32_t			i;

	for(i = 0; i < otherhash->buckets_count; i++) {
		for(bucket = otherhash->buckets[i]; bucket; bucket = bucket->next)
			wi_hash_set_data_for_key(hash, bucket->data, bucket->key);
	}
}



void * wi_hash_data_for_key(wi_hash_t *hash, void *key) {
	_wi_hash_bucket_t	*bucket;
	uint32_t			index;

	index = _WI_HASH_KEY_HASH(hash, key) % hash->buckets_count;
	bucket = _wi_hash_bucket_for_key(hash, key, index);
	
	if(bucket)
		return bucket->data;
	
	return NULL;
}



void wi_hash_set_hash(wi_hash_t *hash, wi_hash_t *otherhash) {
	wi_hash_remove_all_data(hash);
	wi_hash_add_entries_from_hash(hash, otherhash);
}



#pragma mark -

void wi_hash_remove_data_for_key(wi_hash_t *hash, void *key) {
	_wi_hash_bucket_t	*bucket, *previous_bucket;
	uint32_t			index;

	index = _WI_HASH_KEY_HASH(hash, key) % hash->buckets_count;
	bucket = hash->buckets[index];

	if(bucket) {
		previous_bucket = NULL;
		
		for(; bucket; bucket = bucket->next) {
			if(_WI_HASH_KEY_IS_EQUAL(hash, bucket->key, key)) {
				if(bucket == hash->buckets[index])
					hash->buckets[index] = bucket->next;
				
				if(previous_bucket)
					previous_bucket->next = bucket->next;
				
				_wi_hash_bucket_remove(hash, bucket);
				break;
			}
			
			previous_bucket = bucket;
		}
	}
	
	_WI_HASH_CHECK_RESIZE(hash);
}



void wi_hash_remove_all_data(wi_hash_t *hash) {
	_wi_hash_bucket_t	*bucket;
	uint32_t			i;

	for(i = 0; i < hash->buckets_count; i++) {
		for(bucket = hash->buckets[i]; bucket; bucket = bucket->next)
			_wi_hash_bucket_remove(hash, bucket);

		hash->buckets[i] = NULL;
	}

	_WI_HASH_CHECK_RESIZE(hash);
}
