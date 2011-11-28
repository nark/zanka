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

#include "config.h"

#ifdef WI_P7

#include <libxml/tree.h>
#include <libxml/parser.h>
#include <libxml/xmlerror.h>
#include <libxml/xpath.h>
#include <string.h>

#include <wired/wi-array.h>
#include <wired/wi-hash.h>
#include <wired/wi-log.h>
#include <wired/wi-p7-message.h>
#include <wired/wi-p7-spec.h>
#include <wired/wi-p7-private.h>
#include <wired/wi-private.h>
#include <wired/wi-set.h>
#include <wired/wi-string.h>

typedef struct _wi_p7_spec_type				_wi_p7_spec_type_t;
typedef struct _wi_p7_spec_field			_wi_p7_spec_field_t;
typedef struct _wi_p7_spec_message			_wi_p7_spec_message_t;
typedef struct _wi_p7_spec_parameter		_wi_p7_spec_parameter_t;
typedef struct _wi_p7_spec_transaction		_wi_p7_spec_transaction_t;
typedef struct _wi_p7_spec_andor			_wi_p7_spec_andor_t;
typedef struct _wi_p7_spec_reply			_wi_p7_spec_reply_t;


struct _wi_p7_spec_type {
	wi_runtime_base_t						base;
	
	wi_string_t								*name;
	wi_uinteger_t							size;
	wi_uinteger_t							id;
};

static _wi_p7_spec_type_t *					_wi_p7_spec_type_with_node(wi_p7_spec_t *, xmlNodePtr);
static void									_wi_p7_spec_type_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_type_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_type_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_type_runtime_class = {
    "_wi_p7_spec_type_t",
    _wi_p7_spec_type_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_type_description,
    NULL
};



struct _wi_p7_spec_field {
	wi_runtime_base_t						base;
	
	wi_string_t								*name;
	wi_uinteger_t							id;
	_wi_p7_spec_type_t						*type;
	wi_hash_t								*enums_name;
	wi_hash_t								*enums_id;
};

static _wi_p7_spec_field_t *				_wi_p7_spec_field_with_node(wi_p7_spec_t *, xmlNodePtr);
static void									_wi_p7_spec_field_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_field_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_field_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_field_runtime_class = {
    "_wi_p7_spec_field_t",
    _wi_p7_spec_field_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_field_description,
    NULL
};



struct _wi_p7_spec_message {
	wi_runtime_base_t						base;
	
	wi_string_t								*name;
	wi_uinteger_t							id;
	wi_hash_t								*parameters;
};

static _wi_p7_spec_message_t *				_wi_p7_spec_message_with_node(wi_p7_spec_t *, xmlNodePtr);
static void									_wi_p7_spec_message_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_message_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_message_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_message_runtime_class = {
    "_wi_p7_spec_message_t",
    _wi_p7_spec_message_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_message_description,
    NULL
};



struct _wi_p7_spec_parameter {
	wi_runtime_base_t						base;
	
	_wi_p7_spec_field_t						*field;
	wi_boolean_t							required;
};

static _wi_p7_spec_parameter_t *			_wi_p7_spec_parameter_with_node(wi_p7_spec_t *, xmlNodePtr, _wi_p7_spec_message_t *);
static void									_wi_p7_spec_parameter_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_parameter_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_parameter_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_parameter_runtime_class = {
    "_wi_p7_spec_parameter_t",
    _wi_p7_spec_parameter_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_parameter_description,
    NULL
};



enum _wi_p7_spec_originator {
	_WI_P7_SPEC_BOTH = 1,
	_WI_P7_SPEC_CLIENT,
	_WI_P7_SPEC_SERVER
};
typedef enum _wi_p7_spec_originator			_wi_p7_spec_originator_t;

struct _wi_p7_spec_transaction {
	wi_runtime_base_t						base;

	_wi_p7_spec_message_t					*message;
	_wi_p7_spec_originator_t				originator;
	wi_boolean_t							required;
	_wi_p7_spec_andor_t						*andor;
};

static _wi_p7_spec_transaction_t *			_wi_p7_spec_transaction_with_node(wi_p7_spec_t *, xmlNodePtr);
static wi_string_t *						_wi_p7_spec_transaction_originator(_wi_p7_spec_transaction_t *);
static void									_wi_p7_spec_transaction_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_transaction_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_transaction_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_transaction_runtime_class = {
    "_wi_p7_spec_transaction_t",
    _wi_p7_spec_transaction_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_transaction_description,
    NULL
};



enum _wi_p7_spec_andor_type {
	_WI_P7_SPEC_AND,
	_WI_P7_SPEC_OR
};
typedef enum _wi_p7_spec_andor_type			_wi_p7_spec_andor_type_t;

struct _wi_p7_spec_andor {
	wi_runtime_base_t						base;

	_wi_p7_spec_andor_type_t				type;
	wi_array_t								*children;
	wi_array_t								*replies_array;
	wi_hash_t								*replies_hash;
};

static _wi_p7_spec_andor_t *				_wi_p7_spec_andor(_wi_p7_spec_andor_type_t, wi_p7_spec_t *, xmlNodePtr, _wi_p7_spec_transaction_t *);
static void									_wi_p7_spec_andor_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_andor_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_andor_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_andor_runtime_class = {
    "_wi_p7_spec_andor_t",
    _wi_p7_spec_andor_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_andor_description,
    NULL
};



#define _WI_P7_SPEC_REPLY_ONE_OR_ZERO		-1
#define _WI_P7_SPEC_REPLY_ZERO_OR_MORE		-2
#define _WI_P7_SPEC_REPLY_ONE_OR_MORE		-3

struct _wi_p7_spec_reply {
	wi_runtime_base_t						base;

	_wi_p7_spec_message_t					*message;
	wi_integer_t							count;
	wi_boolean_t							required;
};

static _wi_p7_spec_reply_t *				_wi_p7_spec_reply_with_node(wi_p7_spec_t *, xmlNodePtr, _wi_p7_spec_transaction_t *);
static wi_string_t *						_wi_p7_spec_reply_count(_wi_p7_spec_reply_t *);
static void									_wi_p7_spec_reply_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_reply_description(wi_runtime_instance_t *);

static wi_runtime_id_t						_wi_p7_spec_reply_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_reply_runtime_class = {
    "_wi_p7_spec_reply_t",
    _wi_p7_spec_reply_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_reply_description,
    NULL
};



struct _wi_p7_spec {
	wi_runtime_base_t						base;
	
	wi_string_t								*xml;
	
	wi_string_t								*filename;
	wi_string_t								*name;
	double									version;
	
	wi_set_t								*compatible_protocols;
	
	wi_hash_t								*messages_name, *messages_id;
	wi_hash_t								*fields_name, *fields_id;
	wi_hash_t								*types_name, *types_id;
	wi_hash_t								*transactions_name;
};

static wi_p7_spec_t *						_wi_p7_spec_init(wi_p7_spec_t *);
static wi_p7_spec_t *						_wi_p7_spec_init_builtin_spec(wi_p7_spec_t *);

static void									_wi_p7_spec_dealloc(wi_runtime_instance_t *);
static wi_string_t *						_wi_p7_spec_description(wi_runtime_instance_t *);

static wi_boolean_t							_wi_p7_spec_load_builtin(wi_p7_spec_t *);
static wi_boolean_t							_wi_p7_spec_load_file(wi_p7_spec_t *, wi_string_t *);
static wi_boolean_t							_wi_p7_spec_load_string(wi_p7_spec_t *, wi_string_t *);
static wi_boolean_t							_wi_p7_spec_load_spec(wi_p7_spec_t *, xmlDocPtr);
static wi_boolean_t							_wi_p7_spec_load_types(wi_p7_spec_t *, xmlNodePtr);
static wi_boolean_t							_wi_p7_spec_load_fields(wi_p7_spec_t *, xmlNodePtr);
static wi_boolean_t							_wi_p7_spec_load_messages(wi_p7_spec_t *, xmlNodePtr);
static wi_boolean_t							_wi_p7_spec_load_transactions(wi_p7_spec_t *, xmlNodePtr);

static wi_boolean_t							_wi_p7_spec_is_compatible(wi_p7_spec_t *, wi_p7_spec_t *);
static wi_boolean_t							_wi_p7_spec_transaction_is_compatible(wi_p7_spec_t *, _wi_p7_spec_transaction_t *, _wi_p7_spec_transaction_t *);
static wi_boolean_t							_wi_p7_spec_andor_is_compatible(wi_p7_spec_t *, _wi_p7_spec_transaction_t *, _wi_p7_spec_andor_t *, _wi_p7_spec_andor_t *);
static wi_boolean_t							_wi_p7_spec_replies_are_compatible(wi_p7_spec_t *, _wi_p7_spec_transaction_t *, _wi_p7_spec_andor_t *, _wi_p7_spec_andor_t *, wi_boolean_t);
static wi_boolean_t							_wi_p7_spec_reply_is_compatible(wi_p7_spec_t *, _wi_p7_spec_transaction_t *, _wi_p7_spec_reply_t *, _wi_p7_spec_reply_t *, wi_boolean_t);
static wi_boolean_t							_wi_p7_spec_message_is_compatible(wi_p7_spec_t *, _wi_p7_spec_transaction_t *, _wi_p7_spec_message_t *, _wi_p7_spec_message_t *);

static wi_p7_spec_t							*_wi_p7_spec_builtin_spec;

static xmlChar								_wi_p7_spec_builtin[] =
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
	"<p7:protocol xmlns:p7=\"http://www.zankasoftware.com/P7/Specification\""
	"			 xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""
	"			 xsi:schemaLocation=\"http://www.zankasoftware.com/P7/Specification p7-specification.xsd\""
	"			 name=\"P7\" version=\"1.0\">"
	"	<p7:types>"
	"		<p7:type name=\"bool\" id=\"1\" size=\"1\" />"
	"		<p7:type name=\"enum\" id=\"2\" size=\"4\" />"
	"		<p7:type name=\"int32\" id=\"3\" size=\"4\" />"
	"		<p7:type name=\"uint32\" id=\"4\" size=\"4\" />"
	"		<p7:type name=\"int64\" id=\"5\" size=\"8\" />"
	"		<p7:type name=\"uint64\" id=\"6\" size=\"8\" />"
	"		<p7:type name=\"double\" id=\"7\" size=\"8\" />"
	"		<p7:type name=\"string\" id=\"8\" />"
	"		<p7:type name=\"uuid\" id=\"9\" size=\"16\" />"
	"		<p7:type name=\"date\" id=\"10\" size=\"26\" />"
	"		<p7:type name=\"data\" id=\"11\" />"
	"		<p7:type name=\"oobdata\" id=\"12\" size=\"8\" />"
	"	</p7:types>"
	""
	"	<p7:fields>"
	"		<p7:field name=\"p7.handshake.version\" type=\"double\" id=\"1\" />"
	"		<p7:field name=\"p7.handshake.protocol_name\" type=\"string\" id=\"2\" />"
	"		<p7:field name=\"p7.handshake.protocol_version\" type=\"double\" id=\"3\" />"
	"		<p7:field name=\"p7.handshake.compression\" type=\"enum\" id=\"4\">"
	"			<p7:enum name=\"p7.handshake.compression.deflate\" value=\"0\" />"
	"		</p7:field>"
	"		<p7:field name=\"p7.handshake.encryption\" type=\"enum\" id=\"5\">"
	"			<p7:enum name=\"p7.handshake.encryption.rsa_aes128_sha1\" value=\"0\" />"
	"			<p7:enum name=\"p7.handshake.encryption.rsa_aes192_sha1\" value=\"1\" />"
	"			<p7:enum name=\"p7.handshake.encryption.rsa_aes256_sha1\" value=\"2\" />"
	"			<p7:enum name=\"p7.handshake.encryption.rsa_bf128_sha1\" value=\"3\" />"
	"			<p7:enum name=\"p7.handshake.encryption.rsa_3des192_sha1\" value=\"4\" />"
	"		</p7:field>"
	"		<p7:field name=\"p7.handshake.checksum\" type=\"enum\" id=\"6\">"
	"			<p7:enum name=\"p7.handshake.checksum.sha1\" value=\"0\" />"
	"		</p7:field>"
	"		<p7:field name=\"p7.handshake.compatibility_check\" type=\"bool\" id=\"7\" />"
	""
	"		<p7:field name=\"p7.encryption.public_key\" id=\"8\" type=\"data\" />"
	"		<p7:field name=\"p7.encryption.cipher_key\" id=\"9\" type=\"data\" />"
	"		<p7:field name=\"p7.encryption.cipher_iv\" id=\"10\" type=\"data\" />"
	"		<p7:field name=\"p7.encryption.username\" id=\"11\" type=\"data\" />"
	"		<p7:field name=\"p7.encryption.client_password\" id=\"12\" type=\"data\" />"
	"		<p7:field name=\"p7.encryption.server_password\" id=\"13\" type=\"data\" />"
	""
	"		<p7:field name=\"p7.compatibility_check.specification\" id=\"14\" type=\"string\" />"
	"		<p7:field name=\"p7.compatibility_check.status\" id=\"15\" type=\"bool\" />"
	"	</p7:fields>"
	""
	"	<p7:messages>"
	"		<p7:message name=\"p7.handshake\" id=\"1\">"
	"			<p7:parameter field=\"p7.handshake.version\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.protocol_name\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.protocol_version\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.encryption\" />"
	"			<p7:parameter field=\"p7.handshake.compression\" />"
	"			<p7:parameter field=\"p7.handshake.checksum\" />"
	"		</p7:message>"
	""
	"		<p7:message name=\"p7.handshake.reply\" id=\"2\">"
	"			<p7:parameter field=\"p7.handshake.version\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.protocol_name\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.protocol_version\" use=\"required\" />"
	"			<p7:parameter field=\"p7.handshake.encryption\" />"
	"			<p7:parameter field=\"p7.handshake.compression\" />"
	"			<p7:parameter field=\"p7.handshake.checksum\" />"
	"			<p7:parameter field=\"p7.handshake.compatibility_check\" />"
	"		</p7:message>"

	"		<p7:message name=\"p7.handshake.acknowledge\" id=\"3\">"
	"			<p7:parameter field=\"p7.handshake.compatibility_check\" />"
	"		</p7:message>"
	""
	"		<p7:message name=\"p7.encryption\" id=\"4\">"
	"			<p7:parameter field=\"p7.encryption.public_key\" use=\"required\" />"
	"		</p7:message>"
	""
	"		<p7:message name=\"p7.encryption.reply\" id=\"5\">"
	"			<p7:parameter field=\"p7.encryption.cipher_key\" use=\"required\" />"
	"			<p7:parameter field=\"p7.encryption.cipher_iv\" />"
	"			<p7:parameter field=\"p7.encryption.username\" use=\"required\" />"
	"			<p7:parameter field=\"p7.encryption.client_password\" use=\"required\" />"
	"		</p7:message>"
	""
	"		<p7:message name=\"p7.encryption.acknowledge\" id=\"6\">"
	"			<p7:parameter field=\"p7.encryption.server_password\" use=\"required\" />"
	"		</p7:message>"
	""
	"		<p7:message name=\"p7.compatibility_check.specification\" id=\"7\">"
	"			<p7:parameter field=\"p7.compatibility_check.specification\" use=\"required\" />"
	"		</p7:message>"
	"		"
	"		<p7:message name=\"p7.compatibility_check.status\" id=\"8\">"
	"			<p7:parameter field=\"p7.compatibility_check.status\" use=\"required\" />"
	"		</p7:message>"
	"	</p7:messages>"
	""
	"	<p7:transactions>"
	"		<p7:transaction message=\"p7.handshake\" originator=\"client\" use=\"required\">"
	"			<p7:reply message=\"p7.handshake.reply\" count=\"1\" use=\"required\" />"
	"		</p7:transaction>"
	""
	"		<p7:transaction message=\"p7.handshake.reply\" originator=\"server\" use=\"required\">"
	"			<p7:reply message=\"p7.handshake.acknowledge\" count=\"1\" use=\"required\" />"
	"		</p7:transaction>"
	""
	"		<p7:transaction message=\"p7.encryption\" originator=\"server\" use=\"required\">"
	"			<p7:reply message=\"p7.encryption.reply\" count=\"1\" use=\"required\" />"
	"		</p7:transaction>"
	""
	"		<p7:transaction message=\"p7.encryption.reply\" originator=\"client\" use=\"required\">"
	"			<p7:reply message=\"p7.encryption.acknowledge\" count=\"1\" use=\"required\" />"
	"		</p7:transaction>"
	""
	"		<p7:transaction message=\"p7.compatibility_check.specification\" originator=\"both\" use=\"required\">"
	"			<p7:reply message=\"p7.compatibility_check.status\" count=\"1\" use=\"required\" />"
	"		</p7:transaction>"
	"	</p7:transactions>"
	"</p7:protocol>";

static wi_runtime_id_t						_wi_p7_spec_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t					_wi_p7_spec_runtime_class = {
    "wi_p7_spec_t",
    _wi_p7_spec_dealloc,
    NULL,
    NULL,
    _wi_p7_spec_description,
    NULL
};



void wi_p7_spec_register(void) {
    _wi_p7_spec_runtime_id = wi_runtime_register_class(&_wi_p7_spec_runtime_class);
    _wi_p7_spec_type_runtime_id = wi_runtime_register_class(&_wi_p7_spec_type_runtime_class);
    _wi_p7_spec_field_runtime_id = wi_runtime_register_class(&_wi_p7_spec_field_runtime_class);
    _wi_p7_spec_message_runtime_id = wi_runtime_register_class(&_wi_p7_spec_message_runtime_class);
    _wi_p7_spec_parameter_runtime_id = wi_runtime_register_class(&_wi_p7_spec_parameter_runtime_class);
    _wi_p7_spec_transaction_runtime_id = wi_runtime_register_class(&_wi_p7_spec_transaction_runtime_class);
    _wi_p7_spec_andor_runtime_id = wi_runtime_register_class(&_wi_p7_spec_andor_runtime_class);
    _wi_p7_spec_reply_runtime_id = wi_runtime_register_class(&_wi_p7_spec_reply_runtime_class);
}



void wi_p7_spec_initialize(void) {
	xmlInitParser();
}



#pragma mark -

wi_runtime_id_t wi_p7_spec_runtime_id(void) {
    return _wi_p7_spec_runtime_id;
}



#pragma mark -

wi_p7_spec_t * wi_p7_spec_builtin_spec(void) {
	if(!_wi_p7_spec_builtin_spec)
		_wi_p7_spec_builtin_spec = _wi_p7_spec_init_builtin_spec(wi_p7_spec_alloc());
	
	return _wi_p7_spec_builtin_spec;
}



#pragma mark -

wi_p7_spec_t * wi_p7_spec_alloc(void) {
    return wi_runtime_create_instance(_wi_p7_spec_runtime_id, sizeof(wi_p7_spec_t));
}



static wi_p7_spec_t * _wi_p7_spec_init(wi_p7_spec_t *p7_spec) {
	p7_spec->compatible_protocols	= wi_set_init(wi_set_alloc());

	p7_spec->messages_name			= wi_hash_init_with_capacity(wi_hash_alloc(), 500);
	p7_spec->messages_id			= wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
		500, wi_hash_null_key_callbacks, wi_hash_default_value_callbacks);

	p7_spec->fields_name			= wi_hash_init_with_capacity(wi_hash_alloc(), 500);
	p7_spec->fields_id				= wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
		500, wi_hash_null_key_callbacks, wi_hash_default_value_callbacks);

	p7_spec->types_name				= wi_hash_init_with_capacity(wi_hash_alloc(), 20);
	p7_spec->types_id				= wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
		20, wi_hash_null_key_callbacks, wi_hash_default_value_callbacks);

	p7_spec->transactions_name		= wi_hash_init_with_capacity(wi_hash_alloc(), 20);

	return p7_spec;
}



static wi_p7_spec_t * _wi_p7_spec_init_builtin_spec(wi_p7_spec_t *p7_spec) {
	p7_spec = _wi_p7_spec_init(p7_spec);
	p7_spec->filename = wi_retain(WI_STR("(builtin)"));

	if(!_wi_p7_spec_load_builtin(p7_spec)) {
		wi_release(p7_spec);
		
		return NULL;
	}
	
	return p7_spec;
}



wi_p7_spec_t * wi_p7_spec_init_with_file(wi_p7_spec_t *p7_spec, wi_string_t *path) {
	(void) wi_p7_spec_builtin_spec();
	
	p7_spec = _wi_p7_spec_init(p7_spec);
	p7_spec->filename = wi_retain(wi_string_last_path_component(path));
	
	if(!_wi_p7_spec_load_file(p7_spec, path)) {
		wi_release(p7_spec);
		
		return NULL;
	}

	return p7_spec;
}



wi_p7_spec_t * wi_p7_spec_init_with_string(wi_p7_spec_t *p7_spec, wi_string_t *string) {
	(void) wi_p7_spec_builtin_spec();
	
	p7_spec = _wi_p7_spec_init(p7_spec);
	
	if(!_wi_p7_spec_load_string(p7_spec, string)) {
		wi_release(p7_spec);
		
		return NULL;
	}

	return p7_spec;
}



static void _wi_p7_spec_dealloc(wi_runtime_instance_t *instance) {
	wi_p7_spec_t		*p7_spec = instance;
	
	wi_release(p7_spec->xml);

	wi_release(p7_spec->filename);
	wi_release(p7_spec->name);
	wi_release(p7_spec->compatible_protocols);
	
	wi_release(p7_spec->messages_name);
	wi_release(p7_spec->messages_id);
	
	wi_release(p7_spec->fields_name);
	wi_release(p7_spec->fields_id);
	
	wi_release(p7_spec->types_name);
	wi_release(p7_spec->types_id);

	wi_release(p7_spec->transactions_name);
}



static wi_string_t * _wi_p7_spec_description(wi_runtime_instance_t *instance) {
	wi_p7_spec_t		*p7_spec = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@, version = %.1f, types = %@, fields = %@, messages = %@}"),
		wi_runtime_class_name(p7_spec),
		p7_spec,
		p7_spec->name,
		p7_spec->version,
		p7_spec->types_name,
		p7_spec->fields_name,
		p7_spec->messages_name);
}



#pragma mark -

static wi_boolean_t _wi_p7_spec_load_builtin(wi_p7_spec_t *p7_spec) {
	xmlDocPtr		doc;
	
	doc = xmlParseDoc(_wi_p7_spec_builtin);
	
	if(!doc) {
		wi_error_set_libxml2_error();
		
		return false;
	}
	
	if(!_wi_p7_spec_load_spec(p7_spec, doc)) {
		xmlFreeDoc(doc);
		
		return false;
	}

	xmlFreeDoc(doc);
	
	return true;
}



static wi_boolean_t _wi_p7_spec_load_file(wi_p7_spec_t *p7_spec, wi_string_t *path) {
	xmlDocPtr	doc;
	xmlChar		*buffer;
	int			length;
	
	doc = xmlReadFile(wi_string_cstring(path), NULL, 0);
	
	if(!doc) {
		wi_error_set_libxml2_error();
		
		return false;
	}
	
	if(!_wi_p7_spec_load_spec(p7_spec, doc)) {
		xmlFreeDoc(doc);

		return false;
	}
	
	xmlDocDumpMemory(doc, &buffer, &length);
	
	p7_spec->xml = wi_string_init_with_bytes(wi_string_alloc(), (const char *) buffer, length);
	
	xmlFreeDoc(doc);
	xmlFree(buffer);

	return true;
}



static wi_boolean_t _wi_p7_spec_load_string(wi_p7_spec_t *p7_spec, wi_string_t *string) {
	xmlDocPtr	doc;
	xmlChar		*buffer;
	int			length;
	
	doc = xmlReadMemory(wi_string_cstring(string), wi_string_length(string), NULL, NULL, 0);
	
	if(!doc) {
		wi_error_set_libxml2_error();

		return false;
	}
	
	if(!_wi_p7_spec_load_spec(p7_spec, doc)) {
		xmlFreeDoc(doc);

		return false;
	}
	
	xmlDocDumpMemory(doc, &buffer, &length);
	
	p7_spec->xml = wi_string_init_with_bytes(wi_string_alloc(), (const char *) buffer, length);
	
	xmlFree(buffer);
	xmlFreeDoc(doc);

	return true;
}



static wi_boolean_t _wi_p7_spec_load_spec(wi_p7_spec_t *p7_spec, xmlDocPtr doc) {
	wi_string_t		*version;
	xmlNodePtr		root_node, node;
	
	root_node = xmlDocGetRootElement(doc);
	
	p7_spec->name = wi_retain(wi_p7_xml_string_for_attribute(root_node, WI_STR("name")));

	if(!p7_spec->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Protocol has no \"name\""));
		
		return false;
	}
	
	version = wi_p7_xml_string_for_attribute(root_node, WI_STR("version"));
	
	if(!version) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Protocol has no \"version\""));
		
		return false;
	}
	
	p7_spec->version = wi_string_double(version);

	for(node = root_node->children; node != NULL; node = node->next) {
		if(node->type == XML_ELEMENT_NODE) {
			if(strcmp((const char *) node->name, "types") == 0) {
				if(!_wi_p7_spec_load_types(p7_spec, node))
					return false;
			}
			else if(strcmp((const char *) node->name, "fields") == 0) {
				if(!_wi_p7_spec_load_fields(p7_spec, node))
					return false;
			}
			else if(strcmp((const char *) node->name, "messages") == 0) {
				if(!_wi_p7_spec_load_messages(p7_spec, node))
					return false;
			}
			else if(strcmp((const char *) node->name, "transactions") == 0) {
				if(!_wi_p7_spec_load_transactions(p7_spec, node))
					return false;
			}
		}
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_load_types(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	_wi_p7_spec_type_t		*type;
	xmlNodePtr				type_node;
	
	for(type_node = node->children; type_node != NULL; type_node = type_node->next) {
		if(type_node->type == XML_ELEMENT_NODE) {
			type = _wi_p7_spec_type_with_node(p7_spec, type_node);
			
			if(!type)
				return false;
			
			if(wi_log_level >= WI_LOG_DEBUG) {
				if(wi_hash_data_for_key(p7_spec->types_name, type->name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Type with name \"%@\" already exists"),
						type->name);
		
					return false;
				}

				if(wi_hash_data_for_key(p7_spec->types_id, (void *) type->id)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Type with id %lu (name \"%@\") already exists"),
						type->name, type->id);
					
					return false;
				}
			}
			
			wi_hash_set_data_for_key(p7_spec->types_name, type, type->name);
			wi_hash_set_data_for_key(p7_spec->types_id, type, (void *) type->id);
		}
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_load_fields(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	_wi_p7_spec_field_t		*field;
	xmlNodePtr				field_node;
	
	for(field_node = node->children; field_node != NULL; field_node = field_node->next) {
		if(field_node->type == XML_ELEMENT_NODE) {
			field = _wi_p7_spec_field_with_node(p7_spec, field_node);
			
			if(!field)
				return false;
			
			if(wi_log_level >= WI_LOG_DEBUG) {
				if(wi_hash_data_for_key(p7_spec->fields_name, field->name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Field with name \"%@\" already exists"),
						field->name);
					
					return false;
				}
				
				if(wi_hash_data_for_key(p7_spec->fields_id, (void *) field->id)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Field with id %lu (name \"%@\") already exists"),
						field->id, field->name);
					
					return false;
				}
			}

			wi_hash_set_data_for_key(p7_spec->fields_name, field, field->name);
			wi_hash_set_data_for_key(p7_spec->fields_id, field, (void *) field->id);
		}
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_load_messages(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	_wi_p7_spec_message_t	*message;
	xmlNodePtr				message_node;
	
	for(message_node = node->children; message_node != NULL; message_node = message_node->next) {
		if(message_node->type == XML_ELEMENT_NODE) {
			message = _wi_p7_spec_message_with_node(p7_spec, message_node);
			
			if(!message)
				return false;
			
			if(wi_log_level >= WI_LOG_DEBUG) {
				if(wi_hash_data_for_key(p7_spec->messages_name, message->name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Message with name \"%@\" already exists"),
						message->name);
					
					return false;
				}
				
				if(wi_hash_data_for_key(p7_spec->messages_id, (void *) message->id)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Message with id %lu (name \"%@\") already exists"),
						message->id, message->name);
					
					return false;
				}
			}

			wi_hash_set_data_for_key(p7_spec->messages_name, message, message->name);
			wi_hash_set_data_for_key(p7_spec->messages_id, message, (void *) message->id);
		}
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_load_transactions(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	_wi_p7_spec_transaction_t	*transaction;
	xmlNodePtr					transaction_node;
	
	for(transaction_node = node->children; transaction_node != NULL; transaction_node = transaction_node->next) {
		if(transaction_node->type == XML_ELEMENT_NODE) {
			transaction = _wi_p7_spec_transaction_with_node(p7_spec, transaction_node);
			
			if(!transaction)
				return false;
			
			if(wi_log_level >= WI_LOG_DEBUG) {
				if(wi_hash_data_for_key(p7_spec->transactions_name, transaction->message->name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Transaction with message \"%@\" already exists"),
						transaction->message->name);
					
					return false;
				}
			}

			wi_hash_set_data_for_key(p7_spec->transactions_name, transaction, transaction->message->name);
		}
	}
	
	return true;
}



#pragma mark -

wi_boolean_t wi_p7_spec_is_compatible_with_protocol(wi_p7_spec_t *p7_spec, wi_string_t *name, double version) {
	return ((wi_is_equal(p7_spec->name, name) && p7_spec->version == version) ||
			wi_set_contains_data(p7_spec->compatible_protocols, wi_string_with_format(WI_STR("%@ %.1f"), name, version)));
}



wi_boolean_t wi_p7_spec_is_compatible_with_spec(wi_p7_spec_t *p7_spec, wi_p7_spec_t *other_p7_spec) {
	wi_boolean_t	compatible;
	
	compatible = _wi_p7_spec_is_compatible(p7_spec, other_p7_spec);
	
	if(compatible) {
		wi_set_add_data(p7_spec->compatible_protocols, wi_string_with_format(WI_STR("%@ %.1f"),
			other_p7_spec->name, other_p7_spec->version));
	}
	
	return compatible;
}



static wi_boolean_t _wi_p7_spec_is_compatible(wi_p7_spec_t *p7_spec, wi_p7_spec_t *other_p7_spec) {
	wi_enumerator_t				*enumerator;
	wi_string_t					*key;
	_wi_p7_spec_transaction_t	*transaction, *other_transaction;
	
	enumerator = wi_hash_key_enumerator(p7_spec->transactions_name);
	
	while((key = wi_enumerator_next_data(enumerator))) {
		transaction			= wi_hash_data_for_key(p7_spec->transactions_name, key);
		other_transaction	= wi_hash_data_for_key(other_p7_spec->transactions_name, key);
		
		if(!_wi_p7_spec_transaction_is_compatible(p7_spec, transaction, other_transaction))
			return false;
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_transaction_is_compatible(wi_p7_spec_t *p7_spec, _wi_p7_spec_transaction_t *transaction, _wi_p7_spec_transaction_t *other_transaction) {
	if(transaction->required) {
		if(!other_transaction || !other_transaction->required) {
			if(!other_transaction) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Transaction \"%@\" is required, but peer lacks it"),
					transaction->message->name);
			} else {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Transaction \"%@\" is required, but peer has it optional"),
					transaction->message->name);
			}
			
			return false;
		}
	}
	
	if(other_transaction) {
		if(transaction->originator != other_transaction->originator) {
			wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
				WI_STR("Transaction \"%@\" should be sent by %@, but peer sends it by %@"),
				transaction->message->name,
				_wi_p7_spec_transaction_originator(transaction),
				_wi_p7_spec_transaction_originator(other_transaction));

			return false;
		}
		
		if(!_wi_p7_spec_message_is_compatible(p7_spec, transaction, transaction->message, other_transaction->message))
			return false;
		
		if(!_wi_p7_spec_andor_is_compatible(p7_spec, transaction, transaction->andor, other_transaction->andor))
			return false;
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_andor_is_compatible(wi_p7_spec_t *p7_spec, _wi_p7_spec_transaction_t *transaction, _wi_p7_spec_andor_t *andor, _wi_p7_spec_andor_t *other_andor) {
	wi_uinteger_t		i, count, other_count;
	
	if(andor->type != other_andor->type)
		return false;
	
	if(!_wi_p7_spec_replies_are_compatible(p7_spec, transaction, andor, other_andor, false) ||
	   !_wi_p7_spec_replies_are_compatible(p7_spec, transaction, other_andor, andor, true))
		return false;
	
	count = wi_array_count(andor->children);
	other_count = wi_array_count(other_andor->children);
	
	if(count != other_count) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Transaction \"%@\" should have %lu %@, but peer has %lu"),
			transaction->message->name,
			count,
			count == 1
				? WI_STR("child")
				: WI_STR("children"),
			other_count);
		
		return false;
	}
	
	for(i = 0; i < count; i++) {
		if(!_wi_p7_spec_andor_is_compatible(p7_spec, transaction, WI_ARRAY(andor->children, i), WI_ARRAY(other_andor->children, i)))
			return false;
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_replies_are_compatible(wi_p7_spec_t *p7_spec, _wi_p7_spec_transaction_t *transaction, _wi_p7_spec_andor_t *andor, _wi_p7_spec_andor_t *other_andor, wi_boolean_t commutativity) {
	wi_enumerator_t			*enumerator;
	_wi_p7_spec_reply_t		*reply, *other_reply, *each_reply;
	wi_uinteger_t			i, count, index;
	
	if(andor->type != other_andor->type)
		return false;
	
	enumerator = wi_array_data_enumerator(andor->replies_array);
	count = wi_array_count(other_andor->replies_array);
	index = 0;
	
	while((reply = wi_enumerator_next_data(enumerator))) {
		if(reply->required) {
			other_reply = NULL;
			
			for(i = index; i < count; i++) {
				each_reply = WI_ARRAY(other_andor->replies_array, i);
				
				if(each_reply->required) {
					other_reply = each_reply;
					
					break;
				}
			}
			
			index = i + 1;
			
			if(!_wi_p7_spec_reply_is_compatible(p7_spec, transaction, reply, other_reply, commutativity))
				return false;
		} else {
			other_reply = wi_hash_data_for_key(other_andor->replies_hash, reply->message->name);
			
			if(!_wi_p7_spec_reply_is_compatible(p7_spec, transaction, reply, other_reply, commutativity))
				return false;
		}
	}
	
	return true;
}



static wi_boolean_t _wi_p7_spec_reply_is_compatible(wi_p7_spec_t *p7_spec, _wi_p7_spec_transaction_t *transaction, _wi_p7_spec_reply_t *reply, _wi_p7_spec_reply_t *other_reply, wi_boolean_t commutativity) {
	wi_boolean_t	compatible;
	
	if(reply->required) {
		if(!other_reply || !other_reply->required) {
			if(!other_reply) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Reply \"%@\" in transaction \"%@\" is required, but peer lacks it"),
					reply->message->name, transaction->message->name);
			} else {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Reply \"%@\" in transaction \"%@\" is required, but peer has it optional"),
					reply->message->name, transaction->message->name);
			}

			return false;
		}
	}
	
	if(!commutativity) {
		if(other_reply) {
			if(reply->count == _WI_P7_SPEC_REPLY_ONE_OR_ZERO)
				compatible = (other_reply->count == _WI_P7_SPEC_REPLY_ONE_OR_ZERO);
			else if(reply->count == _WI_P7_SPEC_REPLY_ZERO_OR_MORE)
				compatible = (other_reply->count == _WI_P7_SPEC_REPLY_ONE_OR_ZERO || other_reply->count == _WI_P7_SPEC_REPLY_ZERO_OR_MORE);
			else if(reply->count == _WI_P7_SPEC_REPLY_ONE_OR_MORE)
				compatible = (other_reply->count == _WI_P7_SPEC_REPLY_ONE_OR_MORE || other_reply->count > 0);
			else
				compatible = (reply->count == other_reply->count);
			
			if(!compatible) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Reply \"%@\" in transaction \"%@\" should be sent %@, but peer sends it %@"),
					reply->message->name,
					transaction->message->name,
					_wi_p7_spec_reply_count(reply),
					_wi_p7_spec_reply_count(other_reply));
				
				return false;
			}
			
			if(!_wi_p7_spec_message_is_compatible(p7_spec, transaction, reply->message, other_reply->message))
				return false;
		}
	}
	
	return true;
}

	
	
static wi_boolean_t _wi_p7_spec_message_is_compatible(wi_p7_spec_t *p7_spec, _wi_p7_spec_transaction_t *transaction, _wi_p7_spec_message_t *message, _wi_p7_spec_message_t *other_message) {
	wi_enumerator_t			*enumerator;
	wi_string_t				*key;
	_wi_p7_spec_parameter_t	*parameter, *other_parameter;
	_wi_p7_spec_field_t		*field, *other_field;
	
	if(!wi_is_equal(message->name, other_message->name)) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Reply in transaction \"%@\" should be \"%@\", but peer has \"%@\""),
				transaction->message->name, message->name, other_message->name);
		
		return false;
	}
	
	if(message->id != other_message->id) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Message in reply \"%@\" in transaction \"%@\" should have id %lu, but peer has id %lu"),
			message->name, transaction->message->name, message->id, other_message->id);
		
		return false;
	}
	
	enumerator = wi_hash_key_enumerator(message->parameters);
	
	while((key = wi_enumerator_next_data(enumerator))) {
		parameter = wi_hash_data_for_key(message->parameters, key);
		other_parameter = wi_hash_data_for_key(other_message->parameters, key);
		
		if(parameter->required) {
			if(!other_parameter || !other_parameter->required) {
				if(!other_parameter) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Parameter \"%@\" in reply \"%@\" in transaction \"%@\" is required, but peer lacks it"),
						parameter->field->name, message->name, transaction->message->name);
				} else {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Parameter \"%@\" in reply \"%@\" in transaction \"%@\" is required, but peer has it optional"),
						parameter->field->name, message->name, transaction->message->name);
				}
				
				return false;
			}
		}
			
		if(other_parameter) {
			field = parameter->field;
			other_field = other_parameter->field;
			
			if(field->id != other_field->id) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Field in parameter \"%@\" in reply \"%@\" in transaction \"%@\" should have id %lu, but peer has id %lu"),
					parameter->field->name, message->name, transaction->message->name, field->id, other_field->id);
				
				return false;
			}
			
			if(field->type->id != other_field->type->id) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Parameter \"%@\" in reply \"%@\" in transaction \"%@\" should be of type \"%@\", but peer has it as \"%@\""),
					parameter->field->name, message->name, transaction->message->name, field->type->name, other_field->type->name);

				return false;
			}
			
			if(field->type->id == WI_P7_ENUM) {
				if(!wi_is_equal(field->enums_name, other_field->enums_name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Parameter \"%@\" in reply \"%@\" in transaction \"%@\" have enumerations that differ with those of peer"),
						parameter->field->name, message->name, transaction->message->name);
					
					return false;
				}
			}
		}
	}
	
	return true;
}



#pragma mark -

wi_string_t * wi_p7_spec_name(wi_p7_spec_t *p7_spec) {
	return p7_spec->name;
}



double wi_p7_spec_version(wi_p7_spec_t *p7_spec) {
	return p7_spec->version;
}



wi_string_t * wi_p7_spec_xml(wi_p7_spec_t *p7_spec) {
	return p7_spec->xml;
}



wi_uinteger_t wi_p7_spec_message_id(wi_p7_spec_t *p7_spec, wi_string_t *message_name) {
	_wi_p7_spec_message_t	*message;
	
	message = wi_hash_data_for_key(p7_spec->messages_name, message_name);
	
	if(!message && _wi_p7_spec_builtin_spec)
		message = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->messages_name, message_name);
	
	if(!message)
		return WI_P7_SPEC_MESSAGE_ID_NULL;
	
	return message->id;
}



wi_string_t * wi_p7_spec_message_name(wi_p7_spec_t *p7_spec, wi_uinteger_t message_id) {
	_wi_p7_spec_message_t	*message;
	
	message = wi_hash_data_for_key(p7_spec->messages_id, (void *) message_id);
	
	if(!message && _wi_p7_spec_builtin_spec)
		message = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->messages_id, (void *) message_id);
	
	if(!message)
		return NULL;
	
	return message->name;
}



wi_uinteger_t wi_p7_spec_field_id(wi_p7_spec_t *p7_spec, wi_string_t *field_name) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_name, field_name);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_name, field_name);

	if(!field)
		return WI_P7_SPEC_FIELD_ID_NULL;
	
	return field->id;
}



wi_string_t * wi_p7_spec_field_name(wi_p7_spec_t *p7_spec, wi_uinteger_t field_id) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_id, (void *) field_id);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_id, (void *) field_id);
	
	if(!field)
		return NULL;
	
	return field->name;
}



wi_p7_type_t wi_p7_spec_field_type(wi_p7_spec_t *p7_spec, wi_uinteger_t field_id) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_id, (void *) field_id);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_id, (void *) field_id);
	
	if(!field)
		return WI_P7_SPEC_TYPE_ID_NULL;
	
	return field->type->id;
}



wi_uinteger_t wi_p7_spec_field_size(wi_p7_spec_t *p7_spec, wi_uinteger_t field_id) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_id, (void *) field_id);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_id, (void *) field_id);
	
	if(!field)
		return 0;
	
	return field->type->size;
}



wi_p7_type_t wi_p7_spec_type_id(wi_p7_spec_t *p7_spec, wi_string_t *type_name) {
	_wi_p7_spec_type_t		*type;
	
	type = wi_hash_data_for_key(p7_spec->types_name, type_name);
	
	if(!type && _wi_p7_spec_builtin_spec)
		type = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->types_name, type_name);
	
	if(!type)
		return WI_P7_SPEC_TYPE_ID_NULL;
	
	return type->id;
}



wi_string_t * wi_p7_spec_type_name(wi_p7_spec_t *p7_spec, wi_uinteger_t type_id) {
	_wi_p7_spec_type_t		*type;
	
	type = wi_hash_data_for_key(p7_spec->types_id, (void *) type_id);
	
	if(!type && _wi_p7_spec_builtin_spec)
		type = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->types_id, (void *) type_id);

	if(!type)
		return NULL;
	
	return type->name;
}



wi_uinteger_t wi_p7_spec_type_size(wi_p7_spec_t *p7_spec, wi_uinteger_t type_id) {
	_wi_p7_spec_type_t		*type;
	
	type = wi_hash_data_for_key(p7_spec->types_id, (void *) type_id);
	
	if(!type && _wi_p7_spec_builtin_spec)
		type = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->types_id, (void *) type_id);

	if(!type)
		return 0;
	
	return type->size;
}



wi_string_t * wi_p7_spec_enum_name(wi_p7_spec_t *p7_spec, wi_uinteger_t field_id, wi_p7_enum_t enum_value) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_id, (void *) field_id);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_id, (void *) field_id);

	if(!field)
		return NULL;
	
	return wi_hash_data_for_key(field->enums_id, (void *) enum_value);
}



wi_p7_enum_t wi_p7_spec_enum_value(wi_p7_spec_t *p7_spec, wi_uinteger_t field_id, wi_string_t *enum_name) {
	_wi_p7_spec_field_t		*field;
	
	field = wi_hash_data_for_key(p7_spec->fields_id, (void *) field_id);
	
	if(!field && _wi_p7_spec_builtin_spec)
		field = wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_id, (void *) field_id);

	if(!field)
		return WI_P7_SPEC_ENUM_NULL;
	
	return (wi_p7_enum_t) wi_hash_data_for_key(field->enums_name, enum_name);
}



#pragma mark -

wi_boolean_t wi_p7_spec_verify_message(wi_p7_spec_t *p7_spec, wi_p7_message_t *p7_message) {
	wi_enumerator_t			*enumerator;
	wi_hash_t				*fields;
	_wi_p7_spec_message_t	*message;
	_wi_p7_spec_parameter_t	*parameter;
	
	message = wi_hash_data_for_key(p7_spec->messages_name, p7_message->name);
	
	if(!message)
		return false;
	
	fields = wi_p7_message_fields(p7_message);
	enumerator = wi_hash_data_enumerator(message->parameters);
	
	while((parameter = wi_enumerator_next_data(enumerator))) {
		if(parameter->required) {
			if(!wi_hash_data_for_key(fields, parameter->field->name)) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDMESSAGE,
					WI_STR("Parameter \"%@\" in message \"%@\" is required"),
					parameter->field->name, message->name);

				return false;
			}
		}
	}
	
	return true;
}



#pragma mark -

static _wi_p7_spec_type_t * _wi_p7_spec_type_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr type_node) {
	_wi_p7_spec_type_t		*type;
	
    type = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_type_runtime_id, sizeof(_wi_p7_spec_type_t)));
	type->name = wi_retain(wi_p7_xml_string_for_attribute(type_node, WI_STR("name")));
	
	if(!type->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Type has no \"name\""));
		
		return NULL;
	}
	
	type->id = wi_p7_xml_integer_for_attribute(type_node, WI_STR("id"));
	
	if(type->id == WI_P7_SPEC_TYPE_ID_NULL) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Type \"%@\" has no \"id\""),
			type->name);
		
		return NULL;
	}
	
	type->size = wi_p7_xml_integer_for_attribute(type_node, WI_STR("size"));

	return type;
}



static void _wi_p7_spec_type_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_type_t		*type = instance;
	
	wi_release(type->name);
}



static wi_string_t * _wi_p7_spec_type_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_type_t		*type = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@, id = %lu, size = %lu}"),
        wi_runtime_class_name(type),
		type,
		type->name,
		type->id,
		type->size);
}



#pragma mark -

static _wi_p7_spec_field_t * _wi_p7_spec_field_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	xmlNodePtr					enum_node;
	_wi_p7_spec_field_t			*field;
	wi_string_t					*type, *name;
	wi_integer_t				value;
	
    field = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_field_runtime_id, sizeof(_wi_p7_spec_field_t)));

	field->name = wi_retain(wi_p7_xml_string_for_attribute(node, WI_STR("name")));

	if(!field->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Field has no \"name\""));

		return NULL;
	}
	
	type = wi_p7_xml_string_for_attribute(node, WI_STR("type"));

	if(!type) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Field \"%@\" has no \"type\""),
			field->name);

		return NULL;
	}
	
	field->type = wi_retain(wi_hash_data_for_key(p7_spec->types_name, type));
	
	if(!field->type && _wi_p7_spec_builtin_spec)
		field->type = wi_retain(wi_hash_data_for_key(_wi_p7_spec_builtin_spec->types_name, type));
	
	if(!field->type) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Field \"%@\" has an invalid \"type\" (\"%@\")"),
			field->name, type);

		return NULL;
	}
	
	field->id = wi_p7_xml_integer_for_attribute(node, WI_STR("id"));
	
	if(field->id == WI_P7_SPEC_FIELD_ID_NULL) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Field \"%@\" has no \"id\""),
			field->name);

		return NULL;
	}
	
	if(field->type->id == WI_P7_ENUM) {
		field->enums_name = wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
			20, wi_hash_default_key_callbacks, wi_hash_null_value_callbacks);
		field->enums_id = wi_hash_init_with_capacity_and_callbacks(wi_hash_alloc(),
			20, wi_hash_null_key_callbacks, wi_hash_default_value_callbacks);
		
		for(enum_node = node->children; enum_node != NULL; enum_node = enum_node->next) {
			if(enum_node->type == XML_ELEMENT_NODE) {
				name = wi_p7_xml_string_for_attribute(enum_node, WI_STR("name"));
				
				if(!name) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Field \"%@\" enum has no \"name\""),
						field->name);
					
					return NULL;
				}
				
				value = wi_p7_xml_integer_for_attribute(enum_node, WI_STR("value"));
				
				wi_hash_set_data_for_key(field->enums_name, (void *) value, name);
				wi_hash_set_data_for_key(field->enums_id, name, (void *) value);
			}
		}
	}
	
	return field;
}



static void _wi_p7_spec_field_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_field_t		*field = instance;

	wi_release(field->name);
	wi_release(field->type);
	wi_release(field->enums_name);
	wi_release(field->enums_id);
}



static wi_string_t * _wi_p7_spec_field_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_field_t		*field = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@, id = %lu, type = %@}"),
        wi_runtime_class_name(field),
		field,
		field->name,
		field->id,
		field->type);
}



#pragma mark -

static _wi_p7_spec_message_t * _wi_p7_spec_message_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	xmlNodePtr					parameter_node;
	_wi_p7_spec_message_t		*message;
	_wi_p7_spec_parameter_t		*parameter;

    message = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_message_runtime_id, sizeof(_wi_p7_spec_message_t)));
	message->name = wi_retain(wi_p7_xml_string_for_attribute(node, WI_STR("name")));

	if(!message->name) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Message has no name"));
		
		return NULL;
	}
	
	message->id	= wi_p7_xml_integer_for_attribute(node, WI_STR("id"));
	
	if(message->id == WI_P7_SPEC_MESSAGE_ID_NULL) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Message \"%@\" has no \"id\""),
			message->name);

		return NULL;
	}
	
	message->parameters = wi_hash_init_with_capacity(wi_hash_alloc(), 20);

	for(parameter_node = node->children; parameter_node != NULL; parameter_node = parameter_node->next) {
		if(parameter_node->type == XML_ELEMENT_NODE) {
			parameter = _wi_p7_spec_parameter_with_node(p7_spec, parameter_node, message);

			if(!parameter)
				return NULL;
			
			if(wi_log_level >= WI_LOG_DEBUG) {
				if(wi_hash_data_for_key(message->parameters, parameter->field->name)) {
					wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
						WI_STR("Message \"%@\" has a duplicate field \"%@\""),
						message->name, parameter->field->name);
					
					return NULL;
				}
			}
			
			wi_hash_set_data_for_key(message->parameters, parameter, parameter->field->name);
		}
	}
	
	return message;
}



static void _wi_p7_spec_message_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_message_t		*message = instance;
	
	wi_release(message->name);
	wi_release(message->parameters);
}



static wi_string_t * _wi_p7_spec_message_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_message_t		*message = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{name = %@, id = %lu, parameters = %@}"),
        wi_runtime_class_name(message),
		message,
		message->name,
		message->id,
		message->parameters);
}



#pragma mark -

static _wi_p7_spec_parameter_t * _wi_p7_spec_parameter_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr node, _wi_p7_spec_message_t *message) {
	_wi_p7_spec_parameter_t	*parameter;
	wi_string_t				*field, *use;

    parameter = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_parameter_runtime_id, sizeof(_wi_p7_spec_parameter_t)));
	field = wi_p7_xml_string_for_attribute(node, WI_STR("field"));

	if(!field) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Parameter in message \"%@\" has no \"field\""),
			message->name);
		
		return NULL;
	}
	
	parameter->field = wi_retain(wi_hash_data_for_key(p7_spec->fields_name, field));
	
	if(!parameter->field && _wi_p7_spec_builtin_spec)
		parameter->field = wi_retain(wi_hash_data_for_key(_wi_p7_spec_builtin_spec->fields_name, field));
	
	if(!parameter->field) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Parameter in message \"%@\" has an invalid \"field\" (\"%@\")"),
			message->name, field);
		
		return NULL;
	}
	
	use = wi_p7_xml_string_for_attribute(node, WI_STR("use"));

	if(use) {
		if(wi_log_level >= WI_LOG_DEBUG) {
			if(wi_string_case_insensitive_compare(use, WI_STR("required")) != 0 &&
			   wi_string_case_insensitive_compare(use, WI_STR("optional")) != 0) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Parameter \"%@\" in message \"%@\" has an invalid \"use\" (\"%@\")"),
					message->name, parameter->field->name, use);
				
				return NULL;
			}
		}

		parameter->required = (wi_string_case_insensitive_compare(use, WI_STR("required")) == 0);
	}

	return parameter;
}



static void _wi_p7_spec_parameter_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_parameter_t		*parameter = instance;
	
	wi_release(parameter->field);
}



static wi_string_t * _wi_p7_spec_parameter_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_parameter_t		*parameter = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{field = %@, required = %@}"),
        wi_runtime_class_name(parameter),
		parameter,
		parameter->field,
		parameter->required ? WI_STR("true") : WI_STR("false"));
}



#pragma mark -

static _wi_p7_spec_transaction_t * _wi_p7_spec_transaction_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr node) {
	wi_string_t					*message, *originator, *use;
	_wi_p7_spec_transaction_t	*transaction;

    transaction = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_transaction_runtime_id, sizeof(_wi_p7_spec_transaction_t)));
	message = wi_p7_xml_string_for_attribute(node, WI_STR("message"));
	
	if(!message) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Transaction has no \"message\""));
		
		return NULL;
	}

	transaction->message = wi_retain(wi_hash_data_for_key(p7_spec->messages_name, message));

	if(!transaction->message && _wi_p7_spec_builtin_spec)
		transaction->message = wi_retain(wi_hash_data_for_key(_wi_p7_spec_builtin_spec->messages_name, message));
	
	if(!transaction->message) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Transaction has an invalid \"message\" (\"%@\")"),
			message);
		
		return NULL;
	}
	
	originator = wi_p7_xml_string_for_attribute(node, WI_STR("originator"));

	if(!originator) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Transaction \"%@\" has no \"originator\""),
			transaction->message->name);
		
		return NULL;
	}

	if(wi_log_level >= WI_LOG_DEBUG) {
		if(wi_string_case_insensitive_compare(originator, WI_STR("client")) != 0 &&
		   wi_string_case_insensitive_compare(originator, WI_STR("server")) != 0 &&
		   wi_string_case_insensitive_compare(originator, WI_STR("both")) != 0) {
			wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
				WI_STR("Transaction \"%@\" has an invalid \"originator\" (\"%@\")"),
				transaction->message->name, originator);
			
			return NULL;
		}
	}

	if(wi_string_case_insensitive_compare(originator, WI_STR("client")) == 0)
		transaction->originator = _WI_P7_SPEC_CLIENT;
	else if(wi_string_case_insensitive_compare(originator, WI_STR("server")) == 0)
		transaction->originator = _WI_P7_SPEC_SERVER;
	else
		transaction->originator = _WI_P7_SPEC_BOTH;
	
	use = wi_p7_xml_string_for_attribute(node, WI_STR("use"));

	if(use) {
		if(wi_log_level >= WI_LOG_DEBUG) {
			if(wi_string_case_insensitive_compare(use, WI_STR("required")) != 0 &&
			   wi_string_case_insensitive_compare(use, WI_STR("optional"))) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Transaction \"%@\" has an invalid \"use\" (\"%@\")"),
					transaction->message->name, use);
				
				return NULL;
			}
		}

		transaction->required = (wi_string_case_insensitive_compare(use, WI_STR("required")) == 0);
	}

	transaction->andor = wi_retain(_wi_p7_spec_andor(_WI_P7_SPEC_AND, p7_spec, node, transaction));
	
	if(!transaction->andor)
		return NULL;
	
	return transaction;
}



static wi_string_t * _wi_p7_spec_transaction_originator(_wi_p7_spec_transaction_t *transaction) {
	switch(transaction->originator) {
		case _WI_P7_SPEC_CLIENT:	return WI_STR("client");
		case _WI_P7_SPEC_SERVER:	return WI_STR("server");
		case _WI_P7_SPEC_BOTH:		return WI_STR("both");
	}
	
	return NULL;
}



static void _wi_p7_spec_transaction_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_transaction_t		*transaction = instance;
	
	wi_release(transaction->message);
	wi_release(transaction->andor);
}



static wi_string_t * _wi_p7_spec_transaction_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_transaction_t		*transaction = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{message = %@, required = %@, andor = %@}"),
        wi_runtime_class_name(transaction),
		transaction,
		transaction->message->name,
		transaction->required ? WI_STR("true") : WI_STR("false"),
		transaction->andor);
}



#pragma mark -

static _wi_p7_spec_andor_t * _wi_p7_spec_andor(_wi_p7_spec_andor_type_t type, wi_p7_spec_t *p7_spec, xmlNodePtr node, _wi_p7_spec_transaction_t *transaction) {
	xmlNodePtr				andor_node;
	_wi_p7_spec_andor_t		*andor, *child_andor;
	_wi_p7_spec_reply_t		*reply;

    andor = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_andor_runtime_id, sizeof(_wi_p7_spec_andor_t)));
	andor->type = type;
	andor->children = wi_array_init_with_capacity(wi_array_alloc(), 10);
	andor->replies_array = wi_array_init_with_capacity(wi_array_alloc(), 10);
	andor->replies_hash = wi_hash_init_with_capacity(wi_hash_alloc(), 10);

	for(andor_node = node->children; andor_node != NULL; andor_node = andor_node->next) {
		if(andor_node->type == XML_ELEMENT_NODE) {
			if(strcmp((const char *) andor_node->name, "reply") == 0) {
				reply = _wi_p7_spec_reply_with_node(p7_spec, andor_node, transaction);

				if(!reply)
					return NULL;
				
				if(wi_log_level >= WI_LOG_DEBUG) {
					if(wi_hash_data_for_key(andor->replies_hash, reply->message->name)) {
						wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
							WI_STR("Transaction \"%@\" has a duplicate reply \"%@\""),
							transaction->message->name, reply->message->name);
						
						return NULL;
					}
				}
				
				wi_array_add_data(andor->replies_array, reply);
				wi_hash_set_data_for_key(andor->replies_hash, reply, reply->message->name);
			} else {
				if(strcmp((const char *) andor_node->name, "and") == 0)
					child_andor = _wi_p7_spec_andor(_WI_P7_SPEC_AND, p7_spec, andor_node, transaction);
				else
					child_andor = _wi_p7_spec_andor(_WI_P7_SPEC_OR, p7_spec, andor_node, transaction);
				
				wi_array_add_data(andor->children, child_andor);
			}
		}
	}
	
	return andor;
}



static void _wi_p7_spec_andor_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_andor_t		*andor = instance;
	
	wi_release(andor->children);
	wi_release(andor->replies_hash);
	wi_release(andor->replies_array);
}



static wi_string_t * _wi_p7_spec_andor_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_andor_t		*andor = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{type = %@, replies = %@, children = %@}"),
        wi_runtime_class_name(andor),
		andor,
		andor->type == _WI_P7_SPEC_AND ? WI_STR("and") : WI_STR("or"),
		andor->replies_array,
		andor->children);
}



#pragma mark -

static _wi_p7_spec_reply_t * _wi_p7_spec_reply_with_node(wi_p7_spec_t *p7_spec, xmlNodePtr node, _wi_p7_spec_transaction_t *transaction) {
	_wi_p7_spec_reply_t		*reply;
	wi_string_t				*message, *use, *count;

    reply = wi_autorelease(wi_runtime_create_instance(_wi_p7_spec_reply_runtime_id, sizeof(_wi_p7_spec_reply_t)));
	message = wi_p7_xml_string_for_attribute(node, WI_STR("message"));

	if(!message) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Reply in transaction \"%@\" has no \"message\""),
			transaction->message->name);
		
		return NULL;
	}
	
	reply->message = wi_retain(wi_hash_data_for_key(p7_spec->messages_name, message));
	
	if(!reply->message && _wi_p7_spec_builtin_spec)
		reply->message = wi_retain(wi_hash_data_for_key(_wi_p7_spec_builtin_spec->messages_name, message));
	
	if(!reply->message) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Reply in transaction \"%@\" has an invalid \"message\" (\"%@\")"),
			transaction->message->name, message);
		
		return NULL;
	}

	use = wi_p7_xml_string_for_attribute(node, WI_STR("use"));

	if(use) {
		if(wi_log_level >= WI_LOG_DEBUG) {
			if(wi_string_case_insensitive_compare(use, WI_STR("required")) != 0 &&
			   wi_string_case_insensitive_compare(use, WI_STR("optional"))) {
				wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
					WI_STR("Reply \"%@\" in transaction \"%@\" has an invalid \"use\" (\"%@\")"),
					reply->message->name, transaction->message->name, use);
			
				return NULL;
			}
		}

		reply->required = (wi_string_case_insensitive_compare(use, WI_STR("required")) == 0);
	}
	
	count = wi_p7_xml_string_for_attribute(node, WI_STR("count"));
	
	if(!count) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Reply in transaction \"%@\" has no \"count\""),
			transaction->message->name);
		
		return NULL;
	}
	
	if(wi_string_compare(count, WI_STR("?")) == 0)
		reply->count = _WI_P7_SPEC_REPLY_ONE_OR_ZERO;
	else if(wi_string_compare(count, WI_STR("*")) == 0)
		reply->count = _WI_P7_SPEC_REPLY_ZERO_OR_MORE;
	else if(wi_string_compare(count, WI_STR("+")) == 0)
		reply->count = _WI_P7_SPEC_REPLY_ONE_OR_MORE;
	else
		reply->count = wi_string_integer(count);
	
	if(reply->count == 0) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_INVALIDSPEC,
			WI_STR("Reply in transaction \"%@\" has an invalid \"count\" (\"%@\")"),
			transaction->message->name, count);
		
		return NULL;
	}

	return reply;
}



static wi_string_t * _wi_p7_spec_reply_count(_wi_p7_spec_reply_t *reply) {
	if(reply->count == _WI_P7_SPEC_REPLY_ONE_OR_ZERO)
		return WI_STR("one or zero times");
	if(reply->count == _WI_P7_SPEC_REPLY_ZERO_OR_MORE)
		return WI_STR("zero or more times");
	else if(reply->count == _WI_P7_SPEC_REPLY_ONE_OR_MORE)
		return WI_STR("one or more times");

	return wi_string_with_format(WI_STR("%lu %@"), reply->count, (reply->count == 1) ? WI_STR("time") : WI_STR("times"));
}



static void _wi_p7_spec_reply_dealloc(wi_runtime_instance_t *instance) {
	_wi_p7_spec_reply_t		*reply = instance;
	
	wi_release(reply->message);
}



static wi_string_t * _wi_p7_spec_reply_description(wi_runtime_instance_t *instance) {
	_wi_p7_spec_reply_t		*reply = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{message = %@, count = %lu, required = %@}"),
        wi_runtime_class_name(reply),
		reply,
		reply->message->name,
		reply->count,
		reply->required ? WI_STR("true") : WI_STR("false"));
}

#endif
