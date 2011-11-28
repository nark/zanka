/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#ifndef WI_P7_SPEC_H
#define WI_P7_SPEC_H 1

#include <wired/wi-base.h>
#include <wired/wi-runtime.h>

#define WI_P7_SPEC_MESSAGE_ID_NULL		0
#define WI_P7_SPEC_FIELD_ID_NULL		0
#define WI_P7_SPEC_TYPE_ID_NULL			0
#define WI_P7_SPEC_ENUM_NULL			0


WI_EXPORT wi_runtime_id_t				wi_p7_spec_runtime_id(void);

WI_EXPORT wi_p7_spec_t *				wi_p7_spec_builtin_spec(void);

WI_EXPORT wi_p7_spec_t *				wi_p7_spec_alloc(void);
WI_EXPORT wi_p7_spec_t *				wi_p7_spec_init_with_file(wi_p7_spec_t *, wi_string_t *);
WI_EXPORT wi_p7_spec_t *				wi_p7_spec_init_with_string(wi_p7_spec_t *, wi_string_t *);

WI_EXPORT wi_boolean_t					wi_p7_spec_is_compatible_with_spec(wi_p7_spec_t *, wi_p7_spec_t *);

WI_EXPORT wi_string_t *					wi_p7_spec_name(wi_p7_spec_t *);
WI_EXPORT double						wi_p7_spec_version(wi_p7_spec_t *);
WI_EXPORT wi_string_t *					wi_p7_spec_xml(wi_p7_spec_t *);
WI_EXPORT wi_uinteger_t					wi_p7_spec_message_id(wi_p7_spec_t *, wi_string_t *);
WI_EXPORT wi_string_t *					wi_p7_spec_message_name(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_uinteger_t					wi_p7_spec_field_id(wi_p7_spec_t *, wi_string_t *);
WI_EXPORT wi_string_t *					wi_p7_spec_field_name(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_p7_type_t					wi_p7_spec_field_type(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_uinteger_t					wi_p7_spec_field_size(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_p7_type_t					wi_p7_spec_type_id(wi_p7_spec_t *, wi_string_t *);
WI_EXPORT wi_string_t *					wi_p7_spec_type_name(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_uinteger_t					wi_p7_spec_type_size(wi_p7_spec_t *, wi_uinteger_t);
WI_EXPORT wi_string_t *					wi_p7_spec_enum_name(wi_p7_spec_t *, wi_uinteger_t, wi_p7_enum_t);
WI_EXPORT wi_p7_enum_t					wi_p7_spec_enum_value(wi_p7_spec_t *, wi_uinteger_t, wi_string_t *);

WI_EXPORT wi_boolean_t					wi_p7_spec_verify_message(wi_p7_spec_t *, wi_p7_message_t *);

#endif /* WI_P7_SPEC_H */
