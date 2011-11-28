/* $Id$ */

/*
 *  Copyright (c) 2004-2007 Axel Andersson
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
#include <wired/wired.h>

#include "ignores.h"

struct _wr_ignore {
	wi_runtime_base_t				base;
	
	wr_iid_t						iid;
	wi_string_t						*string;
	wi_regexp_t						*regexp;
};  


static void							wr_ignore_dealloc(wi_runtime_instance_t *);

static wr_iid_t						wr_ignore_iid(void);


wi_mutable_array_t					*wr_ignores;

static wi_runtime_id_t				wr_ignore_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_ignore_runtime_class = {
	"wr_ignore_t",
	wr_ignore_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_ignores_init(void) {
	wr_ignore_runtime_id = wi_runtime_register_class(&wr_ignore_runtime_class);

	wr_ignores = wi_array_init(wi_mutable_array_alloc());
}



wi_boolean_t wr_is_ignored(wi_string_t *string) {
	wi_enumerator_t	*enumerator;
	wr_ignore_t		*ignore;
	
	enumerator = wi_array_data_enumerator(wr_ignores);
	
	while((ignore = wi_enumerator_next_data(enumerator))) {
		if(wr_ignore_match(ignore, string))
			return true;
	}
	
	return false;
}



#pragma mark -

char * wr_readline_ignore_generator(const char *text, int state) {
	static wi_uinteger_t	index;
	wi_string_t				*name;
	wr_ignore_t				*ignore;
	wi_uinteger_t			count;
	
	if(state == 0)
		index = 0;

	name		= wi_string_with_cstring(text);
	count		= wi_array_count(wr_ignores);
	
	while(index < count) {
		ignore = WI_ARRAY(wr_ignores, index++);
		
		if(wi_string_index_of_string(ignore->string, name, WI_STRING_SMART_CASE_INSENSITIVE) == 0)
			return strdup(wi_string_cstring(ignore->string));
	}
	
	return NULL;
}



#pragma mark -

wr_ignore_t * wr_ignore_alloc(void) {
	return wi_runtime_create_instance(wr_ignore_runtime_id, sizeof(wr_ignore_t));
}



wr_ignore_t * wr_ignore_init_with_string(wr_ignore_t *ignore, wi_string_t *string) {
	ignore->iid			= wr_ignore_iid();
	ignore->string		= wi_retain(string);
	ignore->regexp		= wi_regexp_init_with_string(wi_regexp_alloc(),
		wi_string_with_format(WI_STR("/%@/i"), string));
	
	return ignore;
}



static void wr_ignore_dealloc(wi_runtime_instance_t *instance) {
	wr_ignore_t		*ignore = instance;
	
	wi_release(ignore->string);
	wi_release(ignore->regexp);
}



#pragma mark -

static wr_iid_t wr_ignore_iid(void) {
	wr_ignore_t		*ignore;

	if(wi_array_count(wr_ignores) > 0) {
		ignore = wi_array_last_data(wr_ignores);
		
		return ignore->iid + 1;
	}

	return 1;
}



#pragma mark -

wr_iid_t wr_ignore_id(wr_ignore_t *ignore) {
	return ignore->iid;
}



wi_string_t * wr_ignore_string(wr_ignore_t *ignore) {
	return ignore->string;
}



wi_boolean_t wr_ignore_match(wr_ignore_t *ignore, wi_string_t *string) {
	return wi_regexp_matches_string(ignore->regexp, string);
}



#pragma mark -

wr_ignore_t * wr_ignore_with_iid(wr_iid_t iid) {
	wi_enumerator_t		*enumerator;
	wr_ignore_t			*ignore, *value = NULL;

	enumerator = wi_array_data_enumerator(wr_ignores);
	
	while((ignore = wi_enumerator_next_data(enumerator))) {
		if(ignore->iid == iid) {
			value = ignore;

			break;
		}
	}

	return value;
}



wr_ignore_t * wr_ignore_with_string(wi_string_t *string) {
	wi_enumerator_t		*enumerator;
	wr_ignore_t			*ignore;
	
	enumerator = wi_array_data_enumerator(wr_ignores);
	
	while((ignore = wi_enumerator_next_data(enumerator))) {
		if(wi_is_equal(ignore->string, string))
			return ignore;
	}

	return NULL;
}
