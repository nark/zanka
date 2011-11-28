
/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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
#include <wired/wi-enumerator.h>
#include <wired/wi-list.h>
#include <wired/wi-lock.h>
#include <wired/wi-macros.h>
#include <wired/wi-runtime.h>
#include <wired/wi-system.h>
#include <wired/wi-string.h>

#include "wi-private.h"

#define _WI_LIST_RETAIN(list, key)							\
	((list)->callbacks.retain								\
		? (*(list)->callbacks.retain)((key))				\
		: (key))

#define _WI_LIST_RELEASE(list, key)							\
	WI_STMT_START											\
		if((list)->callbacks.release)						\
			(*(list)->callbacks.release)((key));			\
	WI_STMT_END

#define _WI_LIST_IS_EQUAL(list, data1, data2)				\
	(((list)->callbacks.is_equal &&							\
	  (*(list)->callbacks.is_equal)((data1), (data2))) ||	\
	 (!(list)->callbacks.is_equal &&						\
	  (data1) == (data2)))

#define _WI_LIST_INDEX_ASSERT(list, index)					\
	WI_ASSERT((index) < (list)->count,						\
		"index %d out of range (count %d) in %@",			\
		(index), (list)->count, (list))


struct _wi_list_node {
	void								*data;

	struct _wi_list_node				*next, *previous, *link;
};


struct _wi_list {
	wi_runtime_base_t					base;
	
	wi_list_callbacks_t					callbacks;
	
	wi_list_node_t						*first, *last;
	uint32_t							count;
	
	wi_rwlock_t							*lock;
	
	wi_list_node_t						**node_chunks;
	uint32_t							node_chunks_count;
	uint32_t							node_chunks_offset;

	wi_list_node_t						*node_free_list;
};


static void								_wi_list_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_list_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_list_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *					_wi_list_description(wi_runtime_instance_t *);

static wi_list_node_t *					_wi_list_node_create(wi_list_t *);
static void								_wi_list_node_remove(wi_list_t *, wi_list_node_t *);

static void								_wi_list_prepend_node(wi_list_t *, wi_list_node_t *);
static void								_wi_list_append_node(wi_list_t *, wi_list_node_t *);
static void								_wi_list_insert_node_before_node(wi_list_t *, wi_list_node_t *, wi_list_node_t *);
static void								_wi_list_insert_node_sorted(wi_list_t *, wi_list_node_t *, wi_compare_func_t *);


const wi_list_callbacks_t				wi_list_default_callbacks = {
	wi_retain,
	wi_release,
	wi_is_equal,
	wi_description
};

static uint32_t							_wi_list_nodes_per_page;

static wi_runtime_id_t					_wi_list_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_list_runtime_class = {
	"wi_list_t",
	_wi_list_dealloc,
	_wi_list_copy,
	_wi_list_is_equal,
	_wi_list_description,
	NULL
};


void wi_list_register(void) {
	_wi_list_runtime_id = wi_runtime_register_class(&_wi_list_runtime_class);
}



void wi_list_initialize(void) {
	_wi_list_nodes_per_page = wi_page_size() / sizeof(wi_list_node_t);
}



#pragma mark -

wi_runtime_id_t wi_list_runtime_id(void) {
	return _wi_list_runtime_id;
}



#pragma mark -

wi_list_t * wi_list_alloc(void) {
	return wi_runtime_create_instance(_wi_list_runtime_id, sizeof(wi_list_t));
}



wi_list_t * wi_list_init(wi_list_t *list) {
	return wi_list_init_with_callbacks(list, wi_list_default_callbacks);
}



wi_list_t * wi_list_init_with_callbacks(wi_list_t *list, wi_list_callbacks_t callbacks) {
	list->callbacks				= callbacks;
	list->node_chunks_offset	= _wi_list_nodes_per_page;
	list->lock					= wi_rwlock_init(wi_rwlock_alloc());
	
	return list;
}



wi_list_t * wi_list_init_with_data(wi_list_t *list, ...) {
	void		*data;
	va_list		ap;

	list = wi_list_init(list);

	va_start(ap, list);
	while((data = va_arg(ap, void *)))
		wi_list_append_data(list, data);
	va_end(ap);

	return list;
}



wi_list_t * wi_list_init_with_array(wi_list_t *list, wi_array_t *array) {
	uint32_t		i, count;
	
	list = wi_list_init(list);
	count = wi_array_count(array);
	
	for(i = 0; i < count; i++)
		wi_list_append_data(list, wi_array_data_at_index(array, i));
	
	return list;
}



static void _wi_list_dealloc(wi_runtime_instance_t *instance) {
	wi_list_t		*list = instance;
	uint32_t		i;

	wi_list_remove_all_data(list);

	if(list->node_chunks) {
		for(i = 0; i < list->node_chunks_count; i++)
			wi_free(list->node_chunks[i]);

		wi_free(list->node_chunks);
	}

	wi_release(list->lock);
}



static wi_runtime_instance_t * _wi_list_copy(wi_runtime_instance_t *instance) {
	wi_list_t				*list = instance, *list_copy;
	wi_list_node_t			*node;
	wi_runtime_instance_t	*data;
	
	list_copy = wi_list_init_with_callbacks(wi_list_alloc(), list->callbacks);
	
	WI_LIST_FOREACH(list, node, data)
		wi_list_append_data(list_copy, data);
	
	return list_copy;
}



static wi_boolean_t _wi_list_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_list_t			*list1 = instance1;
	wi_list_t			*list2 = instance2;
	wi_list_node_t		*node1, *node2;
	
	if(list1->count != list2->count)
		return false;
	
	if(list1->callbacks.is_equal != list2->callbacks.is_equal)
		return false;
	
	node1 = list1->first;
	node2 = list2->first;

	while(node1 && node2) {
		if(!_WI_LIST_IS_EQUAL(list1, node1->data, node2->data))
			return false;
		
		node1 = node1->next;
		node2 = node2->next;
	}

	return true;
}



static wi_string_t * _wi_list_description(wi_runtime_instance_t *instance) {
	wi_list_t			*list = instance;
	wi_list_node_t		*node;
	wi_string_t			*string, *description;
	void				*data;
	
	string = wi_string_with_format(WI_STR("<%s %p>{count = %d, values = (\n"),
		wi_runtime_class_name(list),
		list,
		list->count);
	
	WI_LIST_FOREACH(list, node, data) {
		if(list->callbacks.description)
			description = (*list->callbacks.description)(data);
		else
			description = wi_string_with_format(WI_STR("%p"), data);
		
		wi_string_append_format(string, WI_STR("    %@\n"), description);
	}
	
	wi_string_append_string(string, WI_STR(")}"));
	
	return string;
}



#pragma mark -

void wi_list_wrlock(wi_list_t *list) {
	wi_rwlock_wrlock(list->lock);
}




void wi_list_rdlock(wi_list_t *list) {
	wi_rwlock_rdlock(list->lock);
}



void wi_list_unlock(wi_list_t *list) {
	wi_rwlock_unlock(list->lock);
}



#pragma mark -

uint32_t wi_list_count(wi_list_t *list) {
	return list->count;
}



wi_list_node_t * wi_list_first_node(wi_list_t *list) {
	return list->first;
}



void * wi_list_first_data(wi_list_t *list) {
	return list->first ? list->first->data : NULL;
}



wi_list_node_t * wi_list_last_node(wi_list_t *list) {
	return list->last;
}



void * wi_list_last_data(wi_list_t *list) {
	return list->last ? list->last->data : NULL;
}



wi_list_node_t * wi_list_node_with_data(wi_list_t *list, void *data) {
	wi_list_node_t	*node;

	for(node = list->first; node; node = node->next) {
		if(node->data == data)
			return node;
	}

	return NULL;
}



wi_list_node_t * wi_list_node_at_index(wi_list_t *list, uint32_t index) {
	wi_list_node_t	*node;
	uint32_t		i;
	
	if(index == 0)
		return list->first;
	else if(index == list->count - 1)
		return list->last;

	for(i = 0, node = list->first; node; node = node->next, i++) {
		if(i == index)
			return node;
	}
	
	return NULL;
}



void * wi_list_data_at_index(wi_list_t *list, uint32_t index) {
	wi_list_node_t	*node;
	uint32_t		i;
	
	if(index == 0)
		return list->first->data;
	else if(index == list->count - 1)
		return list->last->data;

	for(i = 0, node = list->first; node; node = node->next, i++) {
		if(i == index)
			return node->data;
	}
	
	return NULL;
}



wi_boolean_t wi_list_contains_data(wi_list_t *list, void *data) {
	wi_list_node_t	*node;

	for(node = list->first; node; node = node->next) {
		if(_WI_LIST_IS_EQUAL(list, node->data, data))
			return true;
	}

	return false;
}



uint32_t wi_list_index_of_data(wi_list_t *list, void *data) {
	wi_list_node_t	*node;
	uint32_t		i;

	for(i = 0, node = list->first; node; node = node->next) {
		if(_WI_LIST_IS_EQUAL(list, node->data, data))
			return i;
	}

	return WI_NOT_FOUND;
}



#pragma mark -

void * wi_list_node_data(wi_list_node_t *node) {
	return node->data;
}



wi_list_node_t * wi_list_node_next_node(wi_list_node_t *node) {
	return node->next;
}



void * wi_list_node_next_data(wi_list_node_t *node) {
	return node->next ? node->next->data : NULL;
}



wi_list_node_t * wi_list_node_previous_node(wi_list_node_t *node) {
	return node->previous;
}



void * wi_list_node_previous_data(wi_list_node_t *node) {
	return node->previous ? node->previous->data : NULL;
}



#pragma mark -

static wi_list_node_t * _wi_list_node_create(wi_list_t *list) {
	wi_list_node_t		*node, *node_block;
	size_t				size;

	if(!list->node_free_list) {
		if(list->node_chunks_offset == _wi_list_nodes_per_page) {
			list->node_chunks_count++;

			size = list->node_chunks_count * sizeof(wi_list_node_t *);
			list->node_chunks = wi_realloc(list->node_chunks, size);

			size = _wi_list_nodes_per_page * sizeof(wi_list_node_t);
			list->node_chunks[list->node_chunks_count - 1] = wi_malloc(size);

			list->node_chunks_offset = 0;
		}
		
		node_block = list->node_chunks[list->node_chunks_count - 1];
		list->node_free_list = &node_block[list->node_chunks_offset++];
		list->node_free_list->link = NULL;
	}
	
	node = list->node_free_list;
	list->node_free_list = node->link;

	return node;
}



static void _wi_list_node_remove(wi_list_t *list, wi_list_node_t *node) {
	if(node->previous)
		node->previous->next = node->next;

	if(node->next)
		node->next->previous = node->previous;

	if(node == list->first)
		list->first = node->next;

	if(node == list->last)
		list->last = node->previous;
	
	_WI_LIST_RELEASE(list, node->data);
	node->data = NULL;

	node->link = list->node_free_list;
	list->node_free_list = node;

	list->count--;
}



static void _wi_list_prepend_node(wi_list_t *list, wi_list_node_t *node) {
	node->previous = NULL;
	node->next = list->first;
	
	if(list->first)
		list->first->previous = node;
	
	list->first = node;
	
	if(!list->last)
		list->last = node;
	
	list->count++;
}



static void _wi_list_append_node(wi_list_t *list, wi_list_node_t *node) {
	if(!list->first)
		list->first = node;

	if(list->last)
		list->last->next = node;

	node->previous = list->last;
	node->next = NULL;

	list->last = node;
	list->count++;
}



static void _wi_list_insert_node_before_node(wi_list_t *list, wi_list_node_t *node, wi_list_node_t *before_node) {
	if(list->first == before_node)
		list->first = node;

	node->previous = before_node->previous;
	node->next = before_node;
	
	if(before_node->previous)
		before_node->previous->next = node;
	
	before_node->previous = node;

	list->count++;
}



static void _wi_list_insert_node_sorted(wi_list_t *list, wi_list_node_t *node, wi_compare_func_t *compare) {
	wi_list_node_t	*each_node;
	
	if(list->count == 0) {
		_wi_list_append_node(list, node);
	} else {
		for(each_node = list->first; each_node; each_node = each_node->next) {
			if((*compare)(node->data, each_node->data) < 0) {
				_wi_list_insert_node_before_node(list, node, each_node);
				
				return;
			}
		}
			
		_wi_list_append_node(list, node);
	}
}



#pragma mark -

wi_enumerator_t * wi_list_data_enumerator(wi_list_t *list) {
	return wi_autorelease(wi_enumerator_init_with_list(wi_enumerator_alloc(), list, wi_enumerator_list_data_enumerator));
}



void * wi_enumerator_list_data_enumerator(wi_runtime_instance_t *instance, void *context) {
	wi_list_t		*list = instance;
	wi_list_node_t	**node = context;
	
	if(!list->first)
		return NULL;
	
	if(*node) {
		*node = (*node)->next;
		
		if(*node)
			return (*node)->data;
	} else {
		*node = list->first;
		
		return (*node)->data;
	}

	return NULL;
}



#pragma mark -

void wi_list_sort(wi_list_t *list, wi_compare_func_t *compare) {
	wi_list_node_t	*first, *last, *n, *p, *q;
	int				i, merges, lsize, psize, qsize;

	first = list->first;
	lsize = 1;
	
	while(true) {
		p = first;
		first = last = NULL;
		merges = 0;
		
		while(p) {
			merges++;
			q = p;
			psize = 0;
			
			for(i = psize = 0; i < lsize; i++) {
				psize++;
				q = q->next;
				
				if(!q)
					break;
			}
			
			qsize = lsize;
			
			while(psize > 0 || (qsize > 0 && q)) {
				if(psize == 0) {
					n = q;
					q = q->next;
					qsize--;
				} else if(qsize == 0 || !q) {
					n = p;
					p = p->next;
					psize--;
				} else if((*compare)(p->data, q->data) <= 0) {
					n = p;
					p = p->next;
					psize--;
				} else {
					n = q;
					q = q->next;
					qsize--;
				}
				
				if(last)
					last->next = n;
				else
					first = n;
				
				n->previous = last;
				last = n;
			}
			
			p = q;
		}

		last->next = NULL;
		
		if(merges <= 1)
			break;
		else
			lsize *= 2;
	}
	
	list->first = first;
	list->last = last;
}



void wi_list_reverse(wi_list_t *list) {
	wi_list_node_t	*node, *swap_node;
	
	node = list->first;
	list->first = list->last;
	list->last = node;
	
	while(node) {
		swap_node = node->next;
		node->next = node->previous;
		node->previous = swap_node;
		
		node = swap_node;
	}
}



#pragma mark -

void wi_list_prepend_data(wi_list_t *list, void *data) {
	wi_list_node_t		*node;

	node = _wi_list_node_create(list);
	node->data = _WI_LIST_RETAIN(list, data);

	_wi_list_prepend_node(list, node);
}



void wi_list_append_data(wi_list_t *list, void *data) {
	wi_list_node_t		*node;

	node = _wi_list_node_create(list);
	node->data = _WI_LIST_RETAIN(list, data);

	_wi_list_append_node(list, node);
}



void wi_list_append_data_from_list(wi_list_t *list, wi_list_t *otherlist) {
	wi_list_node_t		*node;
	void				*data;
	
	WI_LIST_FOREACH(otherlist, node, data)
		wi_list_append_data(list, data);
}



void wi_list_insert_data(wi_list_t *list, void *data, uint32_t index) {
	wi_list_node_t		*node;

	_WI_LIST_INDEX_ASSERT(list, index);

	node = _wi_list_node_create(list);
	node->data = _WI_LIST_RETAIN(list, data);

	_wi_list_insert_node_before_node(list, node, wi_list_node_at_index(list, index));
}



void wi_list_insert_data_sorted(wi_list_t *list, void *data, wi_compare_func_t *compare) {
	wi_list_node_t		*node;

	node = _wi_list_node_create(list);
	node->data = _WI_LIST_RETAIN(list, data);

	_wi_list_insert_node_sorted(list, node, compare);
}



#pragma mark -

void wi_list_remove_data(wi_list_t *list, void *data) {
	wi_list_node_t	*node, *next_node;

	for(node = list->first; node; node = next_node) {
		next_node = node->next;

		if(node->data == data)
			_wi_list_node_remove(list, node);
	}
}



void wi_list_remove_node(wi_list_t *list, wi_list_node_t *node) {
	_wi_list_node_remove(list, node);
}



void wi_list_remove_all_data(wi_list_t *list) {
	wi_list_node_t		*node, *next_node;

	for(node = list->first; node; node = next_node) {
		next_node = node->next;
		
		_wi_list_node_remove(list, node);
	}
}
