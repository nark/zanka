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

#ifndef WI_LIST_H
#define WI_LIST_H 1

#include <wired/wi-base.h>
#include <wired/wi-enumerator.h>
#include <wired/wi-runtime.h>

#define WI_LIST_FOREACH(list, node, var) \
	for((node) = wi_list_first_node(list); \
		(node) && ((var) = wi_list_node_data(node)); \
		(node) = wi_list_node_next_node(node))


struct _wi_list_callbacks {
	wi_retain_func_t					*retain;
	wi_release_func_t					*release;
	wi_is_equal_func_t					*is_equal;
	wi_description_func_t				*description;
};
typedef struct _wi_list_callbacks		wi_list_callbacks_t;


WI_EXPORT wi_runtime_id_t				wi_list_runtime_id(void);

WI_EXPORT wi_list_t *					wi_list_alloc(void);
WI_EXPORT wi_list_t *					wi_list_init(wi_list_t *);
WI_EXPORT wi_list_t *					wi_list_init_with_callbacks(wi_list_t *, wi_list_callbacks_t);
WI_EXPORT wi_list_t *					wi_list_init_with_data(wi_list_t *, ...) WI_SENTINEL;
WI_EXPORT wi_list_t *					wi_list_init_with_array(wi_list_t *, wi_array_t *);

WI_EXPORT void							wi_list_wrlock(wi_list_t *);
WI_EXPORT void							wi_list_rdlock(wi_list_t *);
WI_EXPORT void							wi_list_unlock(wi_list_t *);

WI_EXPORT uint32_t						wi_list_count(wi_list_t *);
WI_EXPORT wi_list_node_t *				wi_list_first_node(wi_list_t *);
WI_EXPORT void *						wi_list_first_data(wi_list_t *);
WI_EXPORT wi_list_node_t *				wi_list_last_node(wi_list_t *);
WI_EXPORT void *						wi_list_last_data(wi_list_t *);
WI_EXPORT wi_list_node_t *				wi_list_node_with_data(wi_list_t *, void *);
WI_EXPORT wi_list_node_t *				wi_list_node_at_index(wi_list_t *, uint32_t);
WI_EXPORT void *						wi_list_data_at_index(wi_list_t *, uint32_t);
WI_EXPORT wi_boolean_t					wi_list_contains_data(wi_list_t *, void *);
WI_EXPORT uint32_t						wi_list_index_of_data(wi_list_t *, void *);

WI_EXPORT void *						wi_list_node_data(wi_list_node_t *);
WI_EXPORT wi_list_node_t *				wi_list_node_next_node(wi_list_node_t *);
WI_EXPORT void *						wi_list_node_next_data(wi_list_node_t *);
WI_EXPORT wi_list_node_t *				wi_list_node_previous_node(wi_list_node_t *);
WI_EXPORT void *						wi_list_node_previous_data(wi_list_node_t *);

WI_EXPORT wi_enumerator_t *				wi_list_data_enumerator(wi_list_t *);

WI_EXPORT void							wi_list_sort(wi_list_t *, wi_compare_func_t *);
WI_EXPORT void							wi_list_reverse(wi_list_t *);

WI_EXPORT void							wi_list_prepend_data(wi_list_t *, void *);
WI_EXPORT void							wi_list_append_data(wi_list_t *, void *);
WI_EXPORT void							wi_list_append_data_from_list(wi_list_t *, wi_list_t *);
WI_EXPORT void							wi_list_insert_data(wi_list_t *, void *, uint32_t);
WI_EXPORT void							wi_list_insert_data_sorted(wi_list_t *, void *, wi_compare_func_t *);
WI_EXPORT void							wi_list_set_list(wi_list_t *, wi_list_t *);

WI_EXPORT void							wi_list_remove_data(wi_list_t *, void *);
WI_EXPORT void							wi_list_remove_node(wi_list_t *, wi_list_node_t *);
WI_EXPORT void							wi_list_remove_all_data(wi_list_t *);


WI_EXPORT const wi_list_callbacks_t		wi_list_default_callbacks;

#endif /* WI_LIST_H */
