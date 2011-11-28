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
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <pwd.h>
#include <grp.h>
#include <netdb.h>

#include <wired/wi-array.h>
#include <wired/wi-compat.h>
#include <wired/wi-date.h>
#include <wired/wi-file.h>
#include <wired/wi-list.h>
#include <wired/wi-log.h>
#include <wired/wi-settings.h>
#include <wired/wi-string.h>
#include <wired/wi-regexp.h>
#include <wired/wi-runtime.h>

#include "wi-private.h"

struct _wi_settings {
	wi_runtime_base_t				base;
	
	wi_settings_spec_t				*spec;
	uint32_t						count;
	
	wi_string_t						*file;
	uint32_t						line;

	wi_boolean_t					chroot;
};


static wi_boolean_t					_wi_settings_parse_setting(wi_settings_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_value(wi_settings_t *, wi_string_t *, wi_string_t *);
static uint32_t						_wi_settings_index_of_name(wi_settings_t *, wi_string_t *);
static void							_wi_settings_log_error(wi_settings_t *, wi_string_t *);

static wi_boolean_t					_wi_settings_set_bool(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_number(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_string(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_string_list(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_path(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_user(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_group(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_port(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_regexp(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);
static wi_boolean_t					_wi_settings_set_time_interval(wi_settings_t *, uint32_t, wi_string_t *, wi_string_t *);

static void							_wi_settings_clear(wi_settings_t *);
static void							_wi_settings_clear_bool(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_number(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_string(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_string_list(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_user(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_group(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_regexp(wi_settings_t *, uint32_t);
static void							_wi_settings_clear_time_interval(wi_settings_t *, uint32_t);


wi_string_t							*wi_settings_config_path = NULL;

static wi_runtime_id_t				_wi_settings_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			_wi_settings_runtime_class = {
	"wi_settings_t",
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
};


void wi_settings_register(void) {
	_wi_settings_runtime_id = wi_runtime_register_class(&_wi_settings_runtime_class);
}



void wi_settings_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_settings_runtime_id(void) {
	return _wi_settings_runtime_id;
}



#pragma mark -

wi_settings_t * wi_settings_alloc(void) {
	return wi_runtime_create_instance(_wi_settings_runtime_id, sizeof(wi_settings_t));
}



wi_settings_t * wi_settings_init_with_spec(wi_settings_t *settings, wi_settings_spec_t *spec, uint32_t count) {
	settings->spec = spec;
	settings->count = count;
	
	return settings;
}



#pragma mark -

wi_boolean_t wi_settings_read_file(wi_settings_t *settings, wi_boolean_t chroot) {
	wi_file_t		*file;
	wi_string_t		*path, *string;
	wi_boolean_t	result = true;
	
	path = wi_full_path(wi_settings_config_path);
	file = wi_file_for_reading(path);
	
	if(!file) {
		wi_log_err(WI_STR("Could not open %@: %s"),
			path, strerror(errno));
		
		return false;
	}
	
	wi_log_info(WI_STR("Reading %@"), path);
	_wi_settings_clear(settings);
	
	settings->file		= path;
	settings->line		= 0;
	settings->chroot	= chroot;
	
	while((string = wi_file_read_line(file))) {
		settings->line++;

		if(wi_string_length(string) > 0 && !wi_string_has_prefix(string, WI_STR("#"))) {
			if(!_wi_settings_parse_setting(settings, string))
				result = false;
		}
	}

	settings->file = NULL;

	return result;
}



#pragma mark -

static wi_boolean_t _wi_settings_parse_setting(wi_settings_t *settings, wi_string_t *string) {
	wi_array_t		*array;
	wi_string_t		*name, *value;
	wi_boolean_t	result = false;
	
	array = wi_string_components_separated_by_string(string, WI_STR("="));
	
	if(wi_array_count(array) != 2) {
		wi_error_set_lib_error(WI_ERROR_SETTINGS_SYNTAXERROR);
		
		_wi_settings_log_error(settings, string);

		return false;
	}
	
	name	= wi_string_by_deleting_surrounding_whitespace(WI_ARRAY(array, 0));
	value	= wi_string_by_deleting_surrounding_whitespace(WI_ARRAY(array, 1));
	result	= _wi_settings_set_value(settings, name, value);
	
	if(!result)
		_wi_settings_log_error(settings, name);

	return result;
}



static wi_boolean_t _wi_settings_set_value(wi_settings_t *settings, wi_string_t *name, wi_string_t *value) {
	uint32_t		index;
	wi_boolean_t	result = false;
	
	index = _wi_settings_index_of_name(settings, name);
	
	if(index == WI_NOT_FOUND) {
		wi_error_set_lib_error(WI_ERROR_SETTINGS_UNKNOWNSETTING);
		
		return false;
	}
	
	wi_log_debug(WI_STR("  %@ = %@"), name, value);
	
	switch(settings->spec[index].type) {
		case WI_SETTINGS_NUMBER:
			result = _wi_settings_set_number(settings, index, name, value);
			break;

		case WI_SETTINGS_BOOL:
			result = _wi_settings_set_bool(settings, index, name, value);
			break;

		case WI_SETTINGS_STRING:
			result = _wi_settings_set_string(settings, index, name, value);
			break;

		case WI_SETTINGS_STRING_LIST:
			result = _wi_settings_set_string_list(settings, index, name, value);
			break;

		case WI_SETTINGS_PATH:
			result = _wi_settings_set_path(settings, index, name, value);
			break;

		case WI_SETTINGS_USER:
			result = _wi_settings_set_user(settings, index, name, value);
			break;

		case WI_SETTINGS_GROUP:
			result = _wi_settings_set_group(settings, index, name, value);
			break;

		case WI_SETTINGS_PORT:
			result = _wi_settings_set_port(settings, index, name, value);
			break;
		
		case WI_SETTINGS_REGEXP:
			result = _wi_settings_set_regexp(settings, index, name, value);
			break;
		
		case WI_SETTINGS_TIME_INTERVAL:
			result = _wi_settings_set_time_interval(settings, index, name, value);
			break;
	}
	
	return result;
}



static uint32_t _wi_settings_index_of_name(wi_settings_t *settings, wi_string_t *name) {
	const char		*cstring;
	uint32_t		i, min, max;
	int				cmp;

	cstring = wi_string_cstring(name);
	min = 0;
	max = settings->count - 1;

	do {
		i = (min + max) / 2;
		cmp	= strcasecmp(cstring, settings->spec[i].name);

		if(cmp == 0)
			return i;
		else if(cmp < 0 && max > 0)
			max = i - 1;
		else
			min = i + 1;
	} while(min <= max);

	return WI_NOT_FOUND;
}



static void _wi_settings_log_error(wi_settings_t *settings, wi_string_t *name) {
	wi_log_warn(WI_STR("Could not interpret the setting \"%@\" at %@ line %d: %m"),
		name, settings->file, settings->line);
}



#pragma mark -

wi_boolean_t _wi_settings_set_bool(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	*(wi_boolean_t *) settings->spec[index].setting = wi_string_bool(value);
	
	return true;
}



wi_boolean_t _wi_settings_set_number(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	*(uint32_t *) settings->spec[index].setting = wi_string_uint32(value);
	
	return true;
}



wi_boolean_t _wi_settings_set_string(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	wi_string_t		**string = (wi_string_t **) settings->spec[index].setting;

	wi_release(*string);
	*string = wi_retain(value);
	
	return true;
}



wi_boolean_t _wi_settings_set_string_list(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	wi_list_t		**list = (wi_list_t **) settings->spec[index].setting;

	wi_list_append_data(*list, value);

	return true;
}



wi_boolean_t _wi_settings_set_path(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	wi_string_t		**string = (wi_string_t **) settings->spec[index].setting;
	
	if(*string)
		wi_release(*string);

	if(wi_string_has_prefix(value, WI_STR("/")))
		*string = wi_retain(value);
	else if(settings->chroot)
		*string = wi_string_init_with_format(wi_string_alloc(), WI_STR("/%@"), value);
	else
		*string = wi_string_init_with_format(wi_string_alloc(), WI_STR("%@/%@"), wi_root_path, value);

	wi_string_normalize_path(*string);
	
	return true;
}



wi_boolean_t _wi_settings_set_user(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	struct passwd		*user;
	
	user = getpwnam(wi_string_cstring(value));
	
	if(!user)
		user = getpwuid(wi_string_uint32(value));

	if(!user) {
		wi_error_set_lib_error(WI_ERROR_SETTINGS_NOSUCHUSER);

		return false;
	}

	*(uid_t *) settings->spec[index].setting = user->pw_uid;
	
	return true;
}



wi_boolean_t _wi_settings_set_group(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	struct group		*group;
	
	group = getgrnam(wi_string_cstring(value));
	
	if(!group)
		group = getgrgid(wi_string_uint32(value));

	if(!group) {
		wi_error_set_lib_error(WI_ERROR_SETTINGS_NOSUCHGROUP);

		return false;
	}

	*(gid_t *) settings->spec[index].setting = group->gr_gid;
	
	return true;
}



static wi_boolean_t _wi_settings_set_port(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	struct servent		*servent;
	uint32_t			port;
	
	port = wi_string_uint32(value);
	
	if(port > 65535) {
		wi_error_set_lib_error(WI_ERROR_SETTINGS_INVALIDPORT);
		
		return false;
	}
	
	if(port == 0) {
		servent = getservbyname(wi_string_cstring(value), "tcp");
		
		if(!servent) {
			wi_error_set_lib_error(WI_ERROR_SETTINGS_NOSUCHSERVICE);

			return false;
		}
		
		port = servent->s_port;
	}
	
	*(uint32_t *) settings->spec[index].setting = port;
	
	return true;
}



wi_boolean_t _wi_settings_set_regexp(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	wi_regexp_t		**regexp = (wi_regexp_t **) settings->spec[index].setting;
	
	*regexp = wi_regexp_init_with_string(wi_regexp_alloc(), value);

	return (*regexp != NULL);
}



wi_boolean_t _wi_settings_set_time_interval(wi_settings_t *settings, uint32_t index, wi_string_t *name, wi_string_t *value) {
	*(wi_time_interval_t *) settings->spec[index].setting = wi_string_double(value);
	
	return true;
}



#pragma mark -

static void _wi_settings_clear(wi_settings_t *settings) {
	uint32_t		i;
	
	for(i = 0; i < settings->count; i++) {
		switch(settings->spec[i].type) {
			case WI_SETTINGS_NUMBER:
			case WI_SETTINGS_PORT:
				_wi_settings_clear_number(settings, i);
				break;
				
			case WI_SETTINGS_BOOL:
				_wi_settings_clear_bool(settings, i);
				break;
				
			case WI_SETTINGS_STRING:
			case WI_SETTINGS_PATH:
				_wi_settings_clear_string(settings, i);
				break;
				
			case WI_SETTINGS_STRING_LIST:
				_wi_settings_clear_string_list(settings, i);
				break;
				
			case WI_SETTINGS_USER:
				_wi_settings_clear_user(settings, i);
				break;
				
			case WI_SETTINGS_GROUP:
				_wi_settings_clear_group(settings, i);
				break;
				
			case WI_SETTINGS_REGEXP:
				_wi_settings_clear_regexp(settings, i);
				break;
				
			case WI_SETTINGS_TIME_INTERVAL:
				_wi_settings_clear_time_interval(settings, i);
				break;
		}
	}
}



static void _wi_settings_clear_bool(wi_settings_t *settings, uint32_t index) {
	*(wi_boolean_t *) settings->spec[index].setting = false;
}



static void _wi_settings_clear_number(wi_settings_t *settings, uint32_t index) {
	*(uint32_t *) settings->spec[index].setting = 0;
}



static void _wi_settings_clear_string(wi_settings_t *settings, uint32_t index) {
	wi_string_t		**string = (wi_string_t **) settings->spec[index].setting;
				
	wi_release(*string);
	*string = NULL;
}



static void _wi_settings_clear_string_list(wi_settings_t *settings, uint32_t index) {
	wi_list_t	**list = (wi_list_t **) settings->spec[index].setting;
		
	wi_release(*list);
	*list = wi_list_init(wi_list_alloc());
}



static void _wi_settings_clear_user(wi_settings_t *settings, uint32_t index) {
	*(uid_t *) settings->spec[index].setting = geteuid();
}



static void _wi_settings_clear_group(wi_settings_t *settings, uint32_t index) {
	*(gid_t *) settings->spec[index].setting = getegid();
}



static void _wi_settings_clear_regexp(wi_settings_t *settings, uint32_t index) {
	wi_regexp_t		**regexp = (wi_regexp_t **) settings->spec[index].setting;
		
	wi_release(*regexp);
	*regexp = NULL;
}



static void _wi_settings_clear_time_interval(wi_settings_t *settings, uint32_t index) {
	*(wi_time_interval_t *) settings->spec[index].setting = 0.0;
}
