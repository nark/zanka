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

#include "config.h"

#include <sys/time.h>
#include <string.h>
#include <time.h>

#include <wired/wi-date.h>
#include <wired/wi-macros.h>
#include <wired/wi-pool.h>
#include <wired/wi-private.h>
#include <wired/wi-runtime.h>
#include <wired/wi-string.h>

#define _WI_DATE_ISO8601_STRING_SIZE	25
#define _WI_DATE_EPSILON				0.001


struct _wi_date {
	wi_runtime_base_t					base;
	
	wi_time_interval_t					interval;
};


static wi_runtime_instance_t *			_wi_date_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_date_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_hash_code_t					_wi_date_hash(wi_runtime_instance_t *);
static wi_string_t *					_wi_date_description(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_date_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_date_runtime_class = {
	"wi_date_t",
	NULL,
	_wi_date_copy,
	_wi_date_is_equal,
	_wi_date_description,
	_wi_date_hash
};



void wi_date_register(void) {
	_wi_date_runtime_id = wi_runtime_register_class(&_wi_date_runtime_class);
}



void wi_date_initialize(void) {
}



#pragma mark -

wi_time_interval_t wi_time_interval(void) {
	struct timeval	tv;

	gettimeofday(&tv, NULL);
	
	return (wi_time_interval_t) wi_tvtod(tv);
}



wi_string_t * wi_time_interval_string(wi_time_interval_t interval) {
	wi_uinteger_t	days, hours, minutes, seconds;
	
	seconds = interval;
	
	days = seconds / 86400;
	seconds -= days * 86400;

	hours = seconds / 3600;
	seconds -= hours * 3600;

	minutes = seconds / 60;
	seconds -= minutes * 60;

	if(days > 0) {
		return wi_string_with_format(WI_STR("%lu:%.2lu:%.2lu:%.2lu days"),
			days, hours, minutes, seconds);
	}
	else if(hours > 0) {
		return wi_string_with_format(WI_STR("%.2lu:%.2lu:%.2lu hours"),
			hours, minutes, seconds);
	}
	else if(minutes > 0) {
		return wi_string_with_format(WI_STR("%.2lu:%.2lu minutes"),
			minutes, seconds);
	}
	else {
		return wi_string_with_format(WI_STR("00:%.2lu seconds"),
			seconds);
	}
}



#pragma mark -

wi_runtime_id_t wi_date_runtime_id(void) {
	return _wi_date_runtime_id;
}



#pragma mark -

wi_date_t * wi_date(void) {
	return wi_autorelease(wi_date_init(wi_date_alloc()));
}



wi_date_t * wi_date_with_time_interval(wi_time_interval_t interval) {
	return wi_autorelease(wi_date_init_with_time_interval(wi_date_alloc(), interval));
}



wi_date_t * wi_date_with_time(time_t time) {
	return wi_autorelease(wi_date_init_with_time(wi_date_alloc(), time));
}



wi_date_t * wi_date_with_iso8601_string(wi_string_t *string) {
	return wi_autorelease(wi_date_init_with_iso8601_string(wi_date_alloc(), string));
}



#pragma mark -

wi_date_t * wi_date_alloc(void) {
	return wi_runtime_create_instance(_wi_date_runtime_id, sizeof(wi_date_t));
}



wi_date_t * wi_date_init(wi_date_t *date) {
	return wi_date_init_with_time_interval(date, wi_time_interval());
}



wi_date_t * wi_date_init_with_time_interval(wi_date_t *date, wi_time_interval_t interval) {
	date->interval = interval;
	
	return date;
}



wi_date_t * wi_date_init_with_time(wi_date_t *date, time_t time) {
	return wi_date_init_with_time_interval(date, (wi_time_interval_t) time);
}



wi_date_t * wi_date_init_with_tv(wi_date_t *date, struct timeval tv) {
	return wi_date_init_with_time_interval(date, (wi_time_interval_t) wi_tvtod(tv));
}



wi_date_t * wi_date_init_with_ts(wi_date_t *date, struct timespec ts) {
	return wi_date_init_with_time_interval(date, (wi_time_interval_t) wi_tstod(ts));
}



wi_date_t * wi_date_init_with_string(wi_date_t *date, wi_string_t *string, wi_string_t *format) {
	struct tm		tm;
	time_t			time;

	memset(&tm, 0, sizeof(tm));

	if(!strptime(wi_string_cstring(string), wi_string_cstring(format), &tm)) {
		wi_release(date);
		
		return NULL;
	}

	tm.tm_isdst = -1;

	time = mktime(&tm);
	
	return wi_date_init_with_time(date, time);
}



wi_date_t * wi_date_init_with_iso8601_string(wi_date_t *date, wi_string_t *string) {
	wi_string_t		*substring;

	wi_release(date);

	if(wi_string_length(string) < _WI_DATE_ISO8601_STRING_SIZE)
		return NULL;

	substring = wi_string_by_deleting_characters_in_range(string, wi_make_range(22, 1));
	date = wi_date_init_with_string(wi_date_alloc(), substring, WI_STR("%Y-%m-%dT%H:%M:%S%z"));

	if(date)
		return date;

	substring = wi_string_by_deleting_characters_in_range(string, wi_make_range(19, 6));
	date = wi_date_init_with_string(wi_date_alloc(), substring, WI_STR("%Y-%m-%dT%H:%M:%S"));

	return date;
}



static wi_runtime_instance_t * _wi_date_copy(wi_runtime_instance_t *instance) {
	wi_date_t		*date = instance;
	
	return wi_date_init_with_time_interval(wi_date_alloc(), date->interval);
}



static wi_boolean_t _wi_date_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_date_t		*date1 = instance1;
	wi_date_t		*date2 = instance2;
	
	return (WI_MAX(date1, date2) - WI_MIN(date1, date2) < _WI_DATE_EPSILON);
}



static wi_hash_code_t _wi_date_hash(wi_runtime_instance_t *instance) {
	wi_date_t		*date = instance;
	
	return wi_hash_double(date->interval);
}



static wi_string_t * _wi_date_description(wi_runtime_instance_t *instance) {
	wi_date_t		*date = instance;
	
	return wi_string_with_format(WI_STR("<%@ %p>{interval = %.2f}"),
		wi_runtime_class_name(date),
		date,
		date->interval);
}



#pragma mark -

void wi_date_set_time_interval(wi_date_t *date, wi_time_interval_t interval) {
	date->interval = interval;
}



wi_time_interval_t wi_date_time_interval(wi_date_t *date) {
	return date->interval;
}



#pragma mark -

wi_time_interval_t wi_date_time_interval_since_now(wi_date_t *date) {
	return wi_time_interval() - date->interval;
}



wi_time_interval_t wi_date_time_interval_since_date(wi_date_t *date, wi_date_t *otherdate) {
	return otherdate->interval - date->interval;
}



#pragma mark -

wi_string_t * wi_date_string_with_format(wi_date_t *date, wi_string_t *format) {
	struct tm	tm;
	char		string[1024];
	time_t		time;
	
	time = (time_t) date->interval;

	memset(&tm, 0, sizeof(tm));
	
	localtime_r(&time, &tm);
	
	(void) strftime(string, sizeof(string), wi_string_cstring(format), &tm);
	
	return wi_string_with_cstring(string);
}



wi_string_t * wi_date_iso8601_string(wi_date_t *date) {
	wi_string_t		*string;
	
	string = wi_date_string_with_format(date, WI_STR("%Y-%m-%dT%H:%M:%S%z"));
	
	wi_string_insert_string_at_index(string, WI_STR(":"), 22);
	
	return string;
}



wi_string_t * wi_date_time_interval_string(wi_date_t *date) {
	return wi_time_interval_string(date->interval);
}
