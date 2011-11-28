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

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>

#include <wired/wi-base.h>
#include <wired/wi-macros.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>

#include "wi-private.h"

wi_string_t					*wi_root_path = NULL;

wi_boolean_t				wi_chrooted = false;


void wi_initialize(void) {
	wi_runtime_register();

	wi_address_register();
	wi_array_register();
	wi_data_register();
	wi_date_register();
	wi_error_register();
	wi_file_register();
	wi_hash_register();
	wi_host_register();
	wi_list_register();
	wi_lock_register();
	wi_log_register();
	wi_number_register();
	wi_regexp_register();
	wi_pool_register();
	wi_process_register();
	wi_set_register();
	wi_settings_register();
	wi_socket_register();
	wi_string_register();
	
#ifdef WI_TERMCAP
	wi_terminal_register();
#endif

	wi_thread_register();

#if WI_PTHREADS
	wi_timer_register();
#endif

	wi_url_register();
	wi_uuid_register();
	wi_version_register();
	
	wi_lock_initialize();
	wi_runtime_initialize();

	wi_array_initialize();
	wi_hash_initialize();
	wi_list_initialize();
	wi_set_initialize();

	wi_string_initialize();

	wi_address_initialize();
	wi_data_initialize();
	wi_date_initialize();
	wi_error_initialize();
	wi_file_initialize();
	wi_host_initialize();
	wi_log_initialize();
	wi_number_initialize();
	wi_pool_initialize();
	wi_process_initialize();
	wi_regexp_initialize();
	wi_settings_initialize();
	wi_socket_initialize();
	
#ifdef WI_TERMCAP
	wi_terminal_initialize();
#endif

	wi_thread_initialize();

#if WI_PTHREADS
	wi_timer_initialize();
#endif

	wi_url_initialize();
	wi_uuid_initialize();
	wi_version_initialize();
}



void wi_load(int argc, const char **argv) {
	wi_pool_t		*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	wi_process_load(argc, argv);
	
	wi_release(pool);
}



#pragma mark -

void wi_abort(void) {
	abort();
}



void wi_crash(void) {
	*((char *) NULL) = 0;
}



#pragma mark -

wi_string_t * wi_full_path(wi_string_t *path) {
	if(!path)
		return NULL;
	else if(!wi_root_path)
		return path;
	else if(wi_string_has_prefix(path, WI_STR("/")))
		return path;
	else if(wi_chrooted)
		return wi_string_with_format(WI_STR("/%@"), path);
	else
		return wi_string_with_format(WI_STR("%@/%@"), wi_root_path, path);
}



#pragma mark -

wi_hash_code_t wi_hash_cstring(const char *s) {
	wi_hash_code_t	hash = 0;

	if(s) {
		while(1) {
			if(*s == '\0') break;
			hash ^= (unsigned char) *s++;
			if(*s == '\0') break;
			hash ^= (unsigned char) *s++ << 8;
			if(*s == '\0') break;
			hash ^= (unsigned char) *s++ << 16;
			if(*s == '\0') break;
			hash ^= (unsigned char) *s++ << 24;
		}
	}

	return (wi_hash_code_t) hash;
}



wi_hash_code_t wi_hash_pointer(const void *p) {
#if defined(__x86_64__) || defined(__ppc64__) || defined(__sparc64__)
	return (wi_hash_code_t) ((((uint64_t) p) >> 32) ^ ((uint64_t) p));
#else
	return (wi_hash_code_t) ((((uint32_t) p) >> 16) ^ ((uint32_t) p));
#endif
}



wi_hash_code_t wi_hash_int(int i) {
	return (wi_hash_code_t) WI_ABS(i);
}



wi_hash_code_t wi_hash_double(double d) {
	double		i;

    i = rint(WI_ABS(d));
	
    return (wi_hash_code_t) fmod(i, (double) 0xFFFFFFFF) + ((d - i) * 0xFFFFFFFF);
}
