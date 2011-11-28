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

#ifndef WI_PRIVATE_H
#define WI_PRIVATE_H 1

#include <sys/types.h>
#include <regex.h>
#include <wired/wi-base.h>
#include <wired/wi-error.h>

WI_EXPORT void					wi_address_register(void);
WI_EXPORT void					wi_array_register(void);
WI_EXPORT void					wi_data_register(void);
WI_EXPORT void					wi_date_register(void);
WI_EXPORT void					wi_error_register(void);
WI_EXPORT void					wi_file_register(void);
WI_EXPORT void					wi_hash_register(void);
WI_EXPORT void					wi_host_register(void);
WI_EXPORT void					wi_list_register(void);
WI_EXPORT void					wi_lock_register(void);
WI_EXPORT void					wi_log_register(void);
WI_EXPORT void					wi_number_register(void);
WI_EXPORT void					wi_pool_register(void);
WI_EXPORT void					wi_process_register(void);
WI_EXPORT void					wi_regexp_register(void);
WI_EXPORT void					wi_runtime_register(void);
WI_EXPORT void					wi_set_register(void);
WI_EXPORT void					wi_settings_register(void);
WI_EXPORT void					wi_socket_register(void);
WI_EXPORT void					wi_string_register(void);
WI_EXPORT void					wi_terminal_register(void);
WI_EXPORT void					wi_timer_register(void);
WI_EXPORT void					wi_thread_register(void);
WI_EXPORT void					wi_url_register(void);
WI_EXPORT void					wi_uuid_register(void);
WI_EXPORT void					wi_version_register(void);

WI_EXPORT void					wi_address_initialize(void);
WI_EXPORT void					wi_array_initialize(void);
WI_EXPORT void					wi_data_initialize(void);
WI_EXPORT void					wi_date_initialize(void);
WI_EXPORT void					wi_error_initialize(void);
WI_EXPORT void					wi_file_initialize(void);
WI_EXPORT void					wi_hash_initialize(void);
WI_EXPORT void					wi_host_initialize(void);
WI_EXPORT void					wi_list_initialize(void);
WI_EXPORT void					wi_lock_initialize(void);
WI_EXPORT void					wi_log_initialize(void);
WI_EXPORT void					wi_number_initialize(void);
WI_EXPORT void					wi_pool_initialize(void);
WI_EXPORT void					wi_process_initialize(void);
WI_EXPORT void					wi_regexp_initialize(void);
WI_EXPORT void					wi_runtime_initialize(void);
WI_EXPORT void					wi_set_initialize(void);
WI_EXPORT void					wi_settings_initialize(void);
WI_EXPORT void					wi_socket_initialize(void);
WI_EXPORT void					wi_string_initialize(void);
WI_EXPORT void					wi_terminal_initialize(void);
WI_EXPORT void					wi_timer_initialize(void);
WI_EXPORT void					wi_thread_initialize(void);
WI_EXPORT void					wi_url_initialize(void);
WI_EXPORT void					wi_uuid_initialize(void);
WI_EXPORT void					wi_version_initialize(void);

WI_EXPORT void					wi_process_load(int, const char **);


WI_EXPORT wi_string_t *			wi_full_path(wi_string_t *);


WI_EXPORT wi_hash_code_t		wi_hash_cstring(const char *);
WI_EXPORT wi_hash_code_t		wi_hash_pointer(const void *);
WI_EXPORT wi_hash_code_t		wi_hash_int(int);
WI_EXPORT wi_hash_code_t		wi_hash_double(double);


WI_EXPORT void					wi_error_enter_thread(void);
WI_EXPORT void					wi_error_set_error(wi_error_domain_t, int);
WI_EXPORT void					wi_error_set_errno(int);
WI_EXPORT void					wi_error_set_ssl_error(void);
WI_EXPORT void					wi_error_set_regex_error(regex_t *, int);
WI_EXPORT void					wi_error_set_lib_error(int);


WI_EXPORT void					wi_socket_exit_thread(void);


WI_EXPORT wi_boolean_t			wi_chrooted;

#endif /* WI_PRIVATE_H */
