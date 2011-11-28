/* $Id$ */

/*
 *  Copyright (c) 2005-2007 Axel Andersson
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

#ifndef WI_HASH_H
#define WI_HASH_H 1

#include <wired/wi-base.h>
#include <wired/wi-enumerator.h>
#include <wired/wi-runtime.h>

typedef struct _wi_hash						wi_hash_t;

struct _wi_hash_key_callbacks {
	wi_retain_func_t						*retain;
	wi_release_func_t						*release;
	wi_is_equal_func_t						*is_equal;
	wi_description_func_t					*description;
	wi_hash_func_t							*hash;
};
typedef struct _wi_hash_key_callbacks		wi_hash_key_callbacks_t;

struct _wi_hash_value_callbacks {
	wi_retain_func_t						*retain;
	wi_release_func_t						*release;
	wi_is_equal_func_t						*is_equal;
	wi_description_func_t					*description;
};
typedef struct _wi_hash_value_callbacks		wi_hash_value_callbacks_t;


WI_EXPORT wi_runtime_id_t					wi_hash_runtime_id(void);

WI_EXPORT wi_hash_t *						wi_hash_alloc(void);
WI_EXPORT wi_hash_t *						wi_hash_init(wi_hash_t *);
WI_EXPORT wi_hash_t *						wi_hash_init_with_capacity(wi_hash_t *, wi_uinteger_t);
WI_EXPORT wi_hash_t *						wi_hash_init_with_capacity_and_callbacks(wi_hash_t *, wi_uinteger_t, wi_hash_key_callbacks_t, wi_hash_value_callbacks_t);
WI_EXPORT wi_hash_t *						wi_hash_init_with_data_and_keys(wi_hash_t *, ...) WI_SENTINEL;

WI_EXPORT void								wi_hash_wrlock(wi_hash_t *);
WI_EXPORT void								wi_hash_rdlock(wi_hash_t *);
WI_EXPORT void								wi_hash_unlock(wi_hash_t *);

WI_EXPORT wi_uinteger_t						wi_hash_count(wi_hash_t *);
WI_EXPORT wi_array_t *						wi_hash_all_keys(wi_hash_t *);
WI_EXPORT wi_array_t *						wi_hash_all_values(wi_hash_t *);
WI_EXPORT wi_array_t *						wi_hash_keys_sorted_by_value(wi_hash_t *, wi_compare_func_t *);

WI_EXPORT wi_enumerator_t *					wi_hash_key_enumerator(wi_hash_t *);
WI_EXPORT wi_enumerator_t *					wi_hash_data_enumerator(wi_hash_t *);

WI_EXPORT void								wi_hash_set_data_for_key(wi_hash_t *, void *, void *);
WI_EXPORT void								wi_hash_add_entries_from_hash(wi_hash_t *, wi_hash_t *);
WI_EXPORT void *							wi_hash_data_for_key(wi_hash_t *, void *);
WI_EXPORT void								wi_hash_set_hash(wi_hash_t *, wi_hash_t *);

WI_EXPORT void								wi_hash_remove_data_for_key(wi_hash_t *, void *);
WI_EXPORT void								wi_hash_remove_all_data(wi_hash_t *);


WI_EXPORT const wi_hash_key_callbacks_t		wi_hash_default_key_callbacks;
WI_EXPORT const wi_hash_key_callbacks_t		wi_hash_null_key_callbacks;
WI_EXPORT const wi_hash_value_callbacks_t	wi_hash_default_value_callbacks;
WI_EXPORT const wi_hash_value_callbacks_t	wi_hash_null_value_callbacks;

#endif /* WI_HASH_H */
