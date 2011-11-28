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

#include <wired/wi-byteorder.h>
#include <wired/wi-p7-message.h>
#include <wired/wi-p7-socket.h>
#include <wired/wi-p7-spec.h>
#include <wired/wi-p7-private.h>
#include <wired/wi-private.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

#include <libxml/tree.h>
#include <libxml/parser.h>
#include <string.h>

#define _WI_P7_MESSAGE_BINARY_BUFFER_INITIAL_SIZE	8192
#define _WI_P7_MESSAGE_BINARY_HEADER_SIZE			4


static void											_wi_p7_message_dealloc(wi_runtime_instance_t *);
static wi_string_t *								_wi_p7_message_description(wi_runtime_instance_t *);

static wi_string_t *								_wi_p7_message_field_string_value(wi_p7_message_t *, wi_string_t *, wi_p7_type_t);
static wi_boolean_t									_wi_p7_message_get_binary_buffer_for_reading_for_id(wi_p7_message_t *, uint32_t, wi_p7_type_t, unsigned char **, uint32_t *);
static wi_boolean_t									_wi_p7_message_get_binary_buffer_for_reading_for_name(wi_p7_message_t *, wi_string_t *, unsigned char **, uint32_t *);
static wi_boolean_t									_wi_p7_message_get_binary_buffer_for_writing_for_name(wi_p7_message_t *, wi_string_t *, uint32_t, unsigned char **, uint32_t *);
static void											_wi_p7_message_set_xml_field(wi_p7_message_t *, wi_p7_type_t, wi_string_t *, wi_string_t *);
static xmlNodePtr									_wi_p7_message_xml_node_for_name(wi_p7_message_t *, wi_string_t *);
static wi_string_t *								_wi_p7_message_xml_value_for_name(wi_p7_message_t *, wi_string_t *);
static wi_p7_type_t									_wi_p7_message_xml_type_for_name(wi_p7_message_t *, wi_string_t *);


static wi_runtime_id_t								_wi_p7_message_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t							_wi_p7_message_runtime_class = {
    "wi_p7_message_t",
    _wi_p7_message_dealloc,
    NULL,
    NULL,
    _wi_p7_message_description,
    NULL
};



void wi_p7_message_register(void) {
    _wi_p7_message_runtime_id = wi_runtime_register_class(&_wi_p7_message_runtime_class);
}



void wi_p7_message_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_p7_message_runtime_id(void) {
    return _wi_p7_message_runtime_id;
}



#pragma mark -

wi_p7_message_t * wi_p7_message_with_name(wi_string_t *message_name, wi_p7_socket_t *p7_socket) {
	return wi_autorelease(wi_p7_message_init_with_name(wi_p7_message_alloc(), message_name, p7_socket));
}



#pragma mark -

wi_p7_message_t * wi_p7_message_alloc(void) {
    return wi_runtime_create_instance(_wi_p7_message_runtime_id, sizeof(wi_p7_message_t));
}



wi_p7_message_t * wi_p7_message_init(wi_p7_message_t *p7_message, wi_p7_socket_t *p7_socket) {
	p7_message->spec = wi_retain(wi_p7_socket_spec(p7_socket));
	p7_message->serialization = wi_p7_socket_serialization(p7_socket);

	return p7_message;
}



wi_p7_message_t * wi_p7_message_init_with_name(wi_p7_message_t *p7_message, wi_string_t *message_name, wi_p7_socket_t *p7_socket) {
	p7_message = wi_p7_message_init(p7_message, p7_socket);

	if(p7_message->serialization == WI_P7_BINARY) {
		p7_message->binary_capacity	= _WI_P7_MESSAGE_BINARY_BUFFER_INITIAL_SIZE;
		p7_message->binary_buffer	= wi_malloc(p7_message->binary_capacity);
		p7_message->binary_size		= _WI_P7_MESSAGE_BINARY_HEADER_SIZE;
	} else {
		p7_message->xml_doc			= xmlNewDoc((xmlChar *) "1.0");
		p7_message->xml_root_node	= xmlNewNode(NULL, (xmlChar *) "message");

		xmlDocSetRootElement(p7_message->xml_doc, p7_message->xml_root_node);
			
		p7_message->xml_ns = xmlNewNs(p7_message->xml_root_node, (xmlChar *) "http://www.zankasoftware.com/P7/Message", (xmlChar *) "p7");
		xmlSetNs(p7_message->xml_root_node, p7_message->xml_ns);
	}

	if(!wi_p7_message_set_name(p7_message, message_name)) {
		wi_release(p7_message);
		
		return NULL;
	}
	
	return p7_message;
}



static void _wi_p7_message_dealloc(wi_runtime_instance_t *instance) {
	wi_p7_message_t		*p7_message = instance;
	
	wi_release(p7_message->spec);
	wi_release(p7_message->name);
	
	if(p7_message->binary_buffer)
		wi_free(p7_message->binary_buffer);

	if(p7_message->xml_buffer)
		xmlFree(p7_message->xml_buffer);
	
	wi_release(p7_message->xml_string);
	
	if(p7_message->xml_doc)
		xmlFreeDoc(p7_message->xml_doc);
}



static wi_string_t * _wi_p7_message_description(wi_runtime_instance_t *instance) {
	wi_p7_message_t		*p7_message = instance;
	wi_hash_t			*fields;
	wi_enumerator_t		*enumerator;
	wi_string_t			*description, *xml_string, *field_name;
	
	description = wi_string_init_with_format(wi_string_alloc(), WI_STR("<%@ %p>{name = %@, serialization = %@"),
        wi_runtime_class_name(p7_message),
        p7_message,
		p7_message->name,
		p7_message->serialization == WI_P7_BINARY ? WI_STR("binary") : WI_STR("xml"));
	
	if(p7_message->serialization == WI_P7_BINARY) {
		wi_string_append_format(description, WI_STR(", buffer = %@, fields = (\n"),
			wi_data_with_bytes_no_copy(p7_message->binary_buffer, p7_message->binary_size, false));
	} else {
		if(p7_message->xml_string)
			xml_string = p7_message->xml_string;
		else
			xml_string = wi_string_with_bytes(p7_message->xml_buffer, p7_message->xml_length);
			
		wi_string_append_format(description, WI_STR(", xml = \"%@\", fields = (\n"),
			xml_string);
	}
	
	fields = wi_p7_message_fields(p7_message);
	enumerator = wi_hash_key_enumerator(fields);
	
	while((field_name = wi_enumerator_next_data(enumerator))) {
		wi_string_append_format(description, WI_STR("    %@ = %@\n"),
			field_name, wi_hash_data_for_key(fields, field_name));
	}

	wi_string_append_string(description, WI_STR(")}"));
	
	return wi_autorelease(description);
}



#pragma mark -

/* Copyright (C) 1989-1991 Apple Computer, Inc.
 *
 * All rights reserved.
 *
 * Warranty Information
 *  Even though Apple has reviewed this software, Apple makes no warranty
 *  or representation, either express or implied, with respect to this
 *  software, its quality, accuracy, merchantability, or fitness for a
 *  particular purpose.  As a result, this software is provided "as is,"
 *  and you, its user, are assuming the entire risk as to its quality
 *  and accuracy.
 *
 * This code may be used and freely distributed as long as it includes
 * this copyright notice and the above warranty information.
 *
 * Machine-independent I/O routines for IEEE floating-point numbers.
 *
 * NaN's and infinities are converted to HUGE_VAL or HUGE, which
 * happens to be infinity on IEEE machines.  Unfortunately, it is
 * impossible to preserve NaN's in a machine-independent way.
 * Infinities are, however, preserved on IEEE machines.
 *
 * These routines have been tested on the following machines:
 *	Apple Macintosh, MPW 3.1 C compiler
 *	Apple Macintosh, THINK C compiler
 *	Silicon Graphics IRIS, MIPS compiler
 *	Cray X/MP and Y/MP
 *	Digital Equipment VAX
 *	Sequent Balance (Multiprocesor 386)
 *	NeXT
 *
 *
 * Implemented by Malcolm Slaney and Ken Turkowski.
 *
 * Malcolm Slaney contributions during 1988-1990 include big- and little-
 * endian file I/O, conversion to and from Motorola's extended 80-bit
 * floating-point format, and conversions to and from IEEE single-
 * precision floating-point format.
 *
 * In 1991, Ken Turkowski implemented the conversions to and from
 * IEEE double-precision format, added more precision to the extended
 * conversions, and accommodated conversions involving +/- infinity,
 * NaN's, and denormalized numbers.
 */

#define _WI_P7_MESSAGE_IEEE754_EXP_MAX			2047
#define _WI_P7_MESSAGE_IEEE754_EXP_OFFSET		1023
#define _WI_P7_MESSAGE_IEEE754_EXP_SIZE			11
#define _WI_P7_MESSAGE_IEEE754_EXP_POSITION		(32 - _WI_P7_MESSAGE_IEEE754_EXP_SIZE - 1)


static double									_wi_p7_message_ieee754_to_double(const unsigned char *);
static void										_wi_p7_message_double_to_ieee754(double, unsigned char *);


static double _wi_p7_message_ieee754_to_double(const unsigned char *bytes) {
	double			value;
	int32_t			mantissa, exp;
	uint32_t		first, second;

	first	= (((uint32_t) (bytes[0] & 0xFF) << 24) |
			   ((uint32_t) (bytes[1] & 0xFF) << 16) |
			   ((uint32_t) (bytes[2] & 0xFF) <<  8) |
			    (uint32_t) (bytes[3] & 0xFF));
	second	= (((uint32_t) (bytes[4] & 0xFF) << 24) |
			   ((uint32_t) (bytes[5] & 0xFF) << 16) |
			   ((uint32_t) (bytes[6] & 0xFF) <<  8) |
			    (uint32_t) (bytes[7] & 0xFF));
	
	if(first == 0 && second == 0) {
		value = 0.0;
	} else {
		exp = (first & 0x7FF00000) >> _WI_P7_MESSAGE_IEEE754_EXP_POSITION;

		if(exp == _WI_P7_MESSAGE_IEEE754_EXP_MAX) {	/* Infinity or NaN */
			value = HUGE_VAL;	/* Map NaN's to infinity */
		} else {
			if(exp == 0) {	/* Denormalized number */
				mantissa	= (first & 0x000FFFFF);
				value		= ldexp((double) mantissa, exp - _WI_P7_MESSAGE_IEEE754_EXP_OFFSET - _WI_P7_MESSAGE_IEEE754_EXP_POSITION + 1);
				value		+= ldexp((double) second,   exp - _WI_P7_MESSAGE_IEEE754_EXP_OFFSET - _WI_P7_MESSAGE_IEEE754_EXP_POSITION + 1 - 32);
			} else {	/* Normalized number */
				mantissa	= (first & 0x000FFFFF) + 0x00100000;	/* Insert hidden bit */
				value		= ldexp((double) mantissa, exp - _WI_P7_MESSAGE_IEEE754_EXP_OFFSET - _WI_P7_MESSAGE_IEEE754_EXP_POSITION);
				value		+= ldexp((double) second,   exp - _WI_P7_MESSAGE_IEEE754_EXP_OFFSET - _WI_P7_MESSAGE_IEEE754_EXP_POSITION - 32);
			}
		}
	}

	if(first & 0x80000000)
		return -value;
	else
		return value;
}



static void _wi_p7_message_double_to_ieee754(double value, unsigned char *bytes) {
	double		fmantissa, fsmantissa;
	int32_t		sign, exp, mantissa, shift;
	uint32_t	first, second;

	if(value < 0.0) {	/* Can't distinguish a negative zero */
		sign	= 0x80000000;
		value	*= -1;
	} else {
		sign	= 0;
	}

	if(value == 0.0) {
		first	= 0;
		second	= 0;
	} else {
		fmantissa = frexp(value, &exp);

		if((exp > _WI_P7_MESSAGE_IEEE754_EXP_MAX - _WI_P7_MESSAGE_IEEE754_EXP_OFFSET + 1) || !(fmantissa < 1.0)) {
			/* NaN's and infinities fail second test */
			first = sign | 0x7FF00000;	/* +/- infinity */
			second = 0;
		} else {
			if (exp < -(_WI_P7_MESSAGE_IEEE754_EXP_OFFSET - 2)) {	/* Smaller than normalized */
				shift = (_WI_P7_MESSAGE_IEEE754_EXP_POSITION + 1) + (_WI_P7_MESSAGE_IEEE754_EXP_OFFSET - 2) + exp;
				
				if(shift < 0) {	/* Too small for something in the MS word */
					first = sign;
					shift += 32;
					
					if(shift < 0)	/* Way too small: flush to zero */
						second = 0;
					else			/* Pretty small demorn */
						second = (uint32_t) floor(ldexp(fmantissa, shift));
				} else {			/* Nonzero denormalized number */
					fsmantissa	= ldexp(fmantissa, shift);
					mantissa	= (int32_t) floor(fsmantissa);
					first		= sign | mantissa;
					second		= (uint32_t) floor(ldexp(fsmantissa - mantissa, 32));
				}
			} else {	/* Normalized number */
				fsmantissa	= ldexp(fmantissa, _WI_P7_MESSAGE_IEEE754_EXP_POSITION + 1);
				mantissa	= (int32_t) floor(fsmantissa);
				mantissa	-= (1L << _WI_P7_MESSAGE_IEEE754_EXP_POSITION);	/* Hide MSB */
				fsmantissa	-= (1L << _WI_P7_MESSAGE_IEEE754_EXP_POSITION);
				first		= sign | ((int32_t) ((exp + _WI_P7_MESSAGE_IEEE754_EXP_OFFSET - 1)) << _WI_P7_MESSAGE_IEEE754_EXP_POSITION) | mantissa;
				second		= (uint32_t) floor(ldexp(fsmantissa - mantissa, 32));
			}
		}
	}
	
	bytes[0] = first >> 24;
	bytes[1] = first >> 16;
	bytes[2] = first >>  8;
	bytes[3] = first;
	bytes[4] = second >> 24;
	bytes[5] = second >> 16;
	bytes[6] = second >>  8;
	bytes[7] = second;
}



#pragma mark -

static wi_string_t * _wi_p7_message_field_string_value(wi_p7_message_t *p7_message, wi_string_t *field_name, wi_p7_type_t type_id) {
	wi_string_t				*field_value = NULL;
	wi_uuid_t				*uuid;
	wi_date_t				*date;
	wi_p7_boolean_t			p7_bool;
	wi_p7_enum_t			p7_enum;
	wi_p7_int32_t			p7_int32;
	wi_p7_uint32_t			p7_uint32;
	wi_p7_int64_t			p7_int64;
	wi_p7_uint64_t			p7_uint64;
	wi_p7_double_t			p7_double;
	wi_p7_oobdata_t			p7_oobdata;
	wi_string_t				*string;
	wi_data_t				*data;
	
	switch(type_id) {
		case WI_P7_BOOL:
			if(wi_p7_message_get_bool_for_name(p7_message, &p7_bool, field_name))
				field_value = wi_string_with_format(WI_STR("%@"), p7_bool ? WI_STR("true") : WI_STR("false"));
			break;
			
		case WI_P7_ENUM:
			if(wi_p7_message_get_enum_for_name(p7_message, &p7_enum, field_name))
				field_value = wi_p7_spec_enum_name(p7_message->spec, wi_p7_spec_field_id(p7_message->spec, field_name), p7_enum);
			break;
			
		case WI_P7_INT32:
			if(wi_p7_message_get_int32_for_name(p7_message, &p7_int32, field_name))
				field_value = wi_string_with_format(WI_STR("%d"), p7_int32);
			break;
			
		case WI_P7_UINT32:
			if(wi_p7_message_get_uint32_for_name(p7_message, &p7_uint32, field_name))
				field_value = wi_string_with_format(WI_STR("%u"), p7_uint32);
			break;
			
		case WI_P7_INT64:
			if(wi_p7_message_get_int64_for_name(p7_message, &p7_int64, field_name))
				field_value = wi_string_with_format(WI_STR("%lld"), p7_int64);
			break;
			
		case WI_P7_UINT64:
			if(wi_p7_message_get_uint64_for_name(p7_message, &p7_uint64, field_name))
				field_value = wi_string_with_format(WI_STR("%llu"), p7_uint64);
			break;
			
		case WI_P7_DOUBLE:
			if(wi_p7_message_get_double_for_name(p7_message, &p7_double, field_name))
				field_value = wi_string_with_format(WI_STR("%0.16f"), p7_double);
			break;
			
		case WI_P7_STRING:
			string = wi_p7_message_string_for_name(p7_message, field_name);
			
			if(string)
				field_value = wi_string_with_format(WI_STR("\"%@\""), string);
			break;
		
		case WI_P7_UUID:
			uuid = wi_p7_message_uuid_for_name(p7_message, field_name);
			
			if(uuid)
				field_value = wi_string_with_format(WI_STR("%@"), wi_uuid_string(uuid));
			break;
		
		case WI_P7_DATE:
			date = wi_p7_message_date_for_name(p7_message, field_name);
			
			if(date)
				field_value = wi_string_with_format(WI_STR("%@"), wi_date_iso8601_string(date));
			break;
			
		case WI_P7_DATA:
			data = wi_p7_message_data_for_name(p7_message, field_name);
			
			if(data)
				field_value = wi_string_with_format(WI_STR("%@"), data);
			break;
			
		case WI_P7_OOBDATA:
			if(wi_p7_message_get_oobdata_for_name(p7_message, &p7_oobdata, field_name))
				field_value = wi_string_with_format(WI_STR("%llu"), p7_oobdata);
			break;
	}
	
	return field_value;
}



static wi_boolean_t _wi_p7_message_get_binary_buffer_for_reading_for_id(wi_p7_message_t *p7_message, uint32_t in_field_id, wi_p7_type_t in_type_id, unsigned char **out_buffer, uint32_t *out_field_size) {
	unsigned char		*buffer, *start;
	uint32_t			message_size, field_id, field_size;
	
	message_size = p7_message->binary_size - _WI_P7_MESSAGE_BINARY_HEADER_SIZE;
	buffer = start = p7_message->binary_buffer + _WI_P7_MESSAGE_BINARY_HEADER_SIZE;
	
	while((uint32_t) (buffer - start) < message_size) {
		field_id = wi_read_swap_big_to_host_int32(buffer, 0);

		buffer += sizeof(field_id);

		field_size = wi_p7_spec_field_size(p7_message->spec, field_id);
		
		if(field_size == 0) {
			field_size = wi_read_swap_big_to_host_int32(buffer, 0);
			
			buffer += sizeof(field_size);
		}
		
		if((in_field_id > 0 && field_id == in_field_id) ||
		   (in_type_id > 0 && wi_p7_spec_field_type(p7_message->spec, field_id) == in_type_id)) {
			if(out_buffer)
				*out_buffer = buffer;
			
			if(out_field_size)
				*out_field_size = field_size;
			
			return true;
		}
		
		buffer += field_size;
	}
	
	return false;
}



static wi_boolean_t _wi_p7_message_get_binary_buffer_for_reading_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name, unsigned char **out_buffer, uint32_t *out_field_size) {
	uint32_t		field_id;
	
	field_id = wi_p7_spec_field_id(p7_message->spec, field_name);
	
	if(field_id == WI_P7_SPEC_FIELD_ID_NULL) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_UNKNOWNFIELD,
			WI_STR("No id found for field \"%@\""), field_name);

		return false;
	}
	
	return _wi_p7_message_get_binary_buffer_for_reading_for_id(p7_message, field_id, 0, out_buffer, out_field_size);
}



static wi_boolean_t _wi_p7_message_get_binary_buffer_for_writing_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name, uint32_t length, unsigned char **out_buffer, uint32_t *out_field_id) {
	uint32_t		field_id, field_size, old_size, new_size;
	
	field_id = wi_p7_spec_field_id(p7_message->spec, field_name);
	
	if(field_id == WI_P7_SPEC_FIELD_ID_NULL) {
		wi_error_set_libwired_p7_error(WI_ERROR_P7_UNKNOWNFIELD,
			WI_STR("No id found for field \"%@\""), field_name);
		
		return false;
	}
	
	if(length > 0)
		field_size = length;
	else
		field_size = wi_p7_spec_field_size(p7_message->spec, field_id);
	
	if(_wi_p7_message_get_binary_buffer_for_reading_for_id(p7_message, field_id, 0, out_buffer, &old_size)) {
		if(field_size == old_size)
			return true;
	}
	
	new_size = sizeof(field_id) + field_size;
	
	if(length > 0)
		new_size += sizeof(length);

	if(p7_message->binary_size + new_size > p7_message->binary_capacity) {
		p7_message->binary_capacity	*= 2;
		p7_message->binary_buffer	= wi_realloc(p7_message->binary_buffer, p7_message->binary_capacity);
	}

	if(out_buffer)
		*out_buffer = p7_message->binary_buffer + p7_message->binary_size;
	
	if(out_field_id)
		*out_field_id = field_id;
	
	p7_message->binary_size += new_size;
	
	return true;
}



static void _wi_p7_message_set_xml_field(wi_p7_message_t *p7_message, wi_p7_type_t type_id, wi_string_t *field_name, wi_string_t *field_value) {
	xmlNodePtr		node;
	
	node = _wi_p7_message_xml_node_for_name(p7_message, field_name);
	
	if(!node) {
		node = xmlNewNode(p7_message->xml_ns, (xmlChar *) "field");
		xmlSetProp(node, (xmlChar *) "name", (xmlChar *) wi_string_cstring(field_name));
		xmlSetProp(node, (xmlChar *) "type", (xmlChar *) wi_string_cstring(wi_p7_spec_type_name(p7_message->spec, type_id)));
		xmlAddChild(p7_message->xml_root_node, node);
	}
	
	xmlNodeSetContent(node, (xmlChar *) wi_string_cstring(field_value));
}



static xmlNodePtr _wi_p7_message_xml_node_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	xmlNodePtr		node, foundNode = NULL;
	xmlChar			*prop;
	const char		*name;
	
	name = wi_string_cstring(field_name);
	
	for(node = p7_message->xml_root_node->children; node != NULL; node = node->next) {
		if(node->type == XML_ELEMENT_NODE) {
			prop = xmlGetProp(node, (xmlChar *) "name");

			if(prop) {
				if(strcmp((const char *) prop, name) == 0)
					foundNode = node;

				xmlFree(prop);
			}
			
			if(foundNode)
				return foundNode;
		}
	}
	
	return NULL;
}



static wi_string_t * _wi_p7_message_xml_value_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_string_t		*string;
	xmlNodePtr		node;
	xmlChar			*content;
	
	node = _wi_p7_message_xml_node_for_name(p7_message, field_name);
	
	if(!node)
		return NULL;
	
	content = xmlNodeGetContent(node);
	
	if(!content)
		return NULL;
	
	string = wi_string_with_cstring((const char *) content);
	
	xmlFree(content);
	
	return string;
}



static wi_p7_type_t _wi_p7_message_xml_type_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	xmlNodePtr		node;
	xmlChar			*prop;
	wi_p7_type_t	type = WI_P7_SPEC_TYPE_ID_NULL;
	
	node = _wi_p7_message_xml_node_for_name(p7_message, field_name);
	
	if(!node)
		return WI_P7_SPEC_TYPE_ID_NULL;
	
	prop = xmlGetProp(node, (xmlChar *) "type");
	
	if(prop) {
		type = wi_p7_spec_type_id(p7_message->spec, wi_string_with_cstring_no_copy((char *) prop, false));
		
		xmlFree(prop);
		
		return type;
	}
	
	return WI_P7_SPEC_TYPE_ID_NULL;
}



#pragma mark -

void wi_p7_message_serialize(wi_p7_message_t *p7_message) {
	if(p7_message->serialization == WI_P7_XML) {
		if(p7_message->xml_buffer) {
			xmlFree(p7_message->xml_buffer);
		
			p7_message->xml_buffer = NULL;
		}
		
		xmlDocDumpMemory(p7_message->xml_doc, &p7_message->xml_buffer, &p7_message->xml_length);
	}
}



void wi_p7_message_deserialize(wi_p7_message_t *p7_message) {
	if(p7_message->serialization == WI_P7_BINARY) {
		p7_message->binary_id = wi_read_swap_big_to_host_int32(p7_message->binary_buffer, 0);
		p7_message->name = wi_retain(wi_p7_spec_message_name(p7_message->spec, p7_message->binary_id));
	} else {
		p7_message->xml_doc = xmlParseDoc((xmlChar *) wi_string_cstring(p7_message->xml_string));
		
		if(p7_message->xml_doc) {
			p7_message->xml_root_node = xmlDocGetRootElement(p7_message->xml_doc);
			
			if(p7_message->xml_root_node)
				p7_message->name = wi_retain(wi_p7_xml_string_for_attribute(p7_message->xml_root_node, WI_STR("name")));
		}
	}
}



#pragma mark -

wi_boolean_t wi_p7_message_set_name(wi_p7_message_t *p7_message, wi_string_t *name) {
	if(p7_message->serialization == WI_P7_BINARY) {
		p7_message->binary_id = wi_p7_spec_message_id(p7_message->spec, name);
		
		if(p7_message->binary_id == WI_P7_SPEC_MESSAGE_ID_NULL) {
			wi_error_set_libwired_p7_error(WI_ERROR_P7_UNKNOWNMESSAGE,
				WI_STR("No id found for message \"%@\""), name);

			return false;
		}
		
		wi_write_swap_host_to_big_int32(p7_message->binary_buffer, 0, p7_message->binary_id);
	} else {
		xmlSetProp(p7_message->xml_root_node, (xmlChar *) "name", (xmlChar *) wi_string_cstring(name));
	}
	
	wi_retain(name);
	wi_release(p7_message->name);
	
	p7_message->name = name;
	
	return true;
}



wi_string_t * wi_p7_message_name(wi_p7_message_t *p7_message) {
	return p7_message->name;
}



#pragma mark -

wi_hash_t * wi_p7_message_fields(wi_p7_message_t *p7_message) {
	wi_hash_t			*fields;
	wi_string_t			*field_name, *type_name, *field_value;
	xmlNodePtr			node;
	unsigned char		*buffer, *start;
	wi_p7_type_t		type_id;
	uint32_t			message_size, field_id, field_size;
	
	fields = wi_hash_init(wi_hash_alloc());

	if(p7_message->serialization == WI_P7_BINARY) {
		message_size = p7_message->binary_size - _WI_P7_MESSAGE_BINARY_HEADER_SIZE;
		buffer = start = p7_message->binary_buffer + _WI_P7_MESSAGE_BINARY_HEADER_SIZE;
		
		while((uint32_t) (buffer - start) < message_size) {
			field_id = wi_read_swap_big_to_host_int32(buffer, 0);
			buffer += sizeof(field_id);

			field_size = wi_p7_spec_field_size(p7_message->spec, field_id);
			
			if(field_size == 0) {
				field_size = wi_read_swap_big_to_host_int32(buffer, 0);
				
				buffer += sizeof(field_size);
			}
			
			field_name		= wi_p7_spec_field_name(p7_message->spec, field_id);
			type_id			= wi_p7_spec_field_type(p7_message->spec, field_id);
			field_value		= _wi_p7_message_field_string_value(p7_message, field_name, type_id);

			wi_hash_set_data_for_key(fields, field_value, field_name);

			buffer += field_size;
		}
	} else {
		if(p7_message->xml_root_node) {
			for(node = p7_message->xml_root_node->children; node != NULL; node = node->next) {
				if(node->type == XML_ELEMENT_NODE) {
					field_name		= wi_p7_xml_string_for_attribute(node, WI_STR("name"));
					type_name		= wi_p7_xml_string_for_attribute(node, WI_STR("type"));
					type_id			= wi_p7_spec_type_id(p7_message->spec, type_name);
					field_value		= _wi_p7_message_field_string_value(p7_message, field_name, type_id);
					
					wi_hash_set_data_for_key(fields, field_value, field_name);
				}
			}
		}
	}
	
	return wi_autorelease(fields);
}



#pragma mark -

wi_boolean_t wi_p7_message_set_bool_for_name(wi_p7_message_t *p7_message, wi_p7_boolean_t value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;

	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		
		binary[4] = value ? 1 : 0;
	} else {
		string = wi_string_with_format(WI_STR("%u"), value ? 1 : 0);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_BOOL, field_name, string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_get_bool_for_name(wi_p7_message_t *p7_message, wi_p7_boolean_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		*value = (binary[0] == 1) ? true : false;
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_bool(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_enum_for_name(wi_p7_message_t *p7_message, wi_p7_enum_t value, wi_string_t *field_name) {
	wi_string_t		*string;

	if(p7_message->serialization == WI_P7_BINARY) {
		return wi_p7_message_set_uint32_for_name(p7_message, (wi_p7_uint32_t) value, field_name);
	} else {
		string = wi_string_with_format(WI_STR("%u"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_ENUM, field_name, string);
		
		return true;
	}
}



wi_boolean_t wi_p7_message_get_enum_for_name(wi_p7_message_t *p7_message, wi_p7_enum_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	wi_p7_uint32_t	p7_uint32;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!wi_p7_message_get_uint32_for_name(p7_message, &p7_uint32, field_name))
			return false;
		
		*value = (wi_p7_enum_t) p7_uint32;
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_uint32(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_int32_for_name(wi_p7_message_t *p7_message, wi_p7_int32_t value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;

	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		wi_write_swap_host_to_big_int32(binary, 4, value);
	} else {
		string = wi_string_with_format(WI_STR("%d"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_INT32, field_name, string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_get_int32_for_name(wi_p7_message_t *p7_message, wi_p7_int32_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		*value = wi_read_swap_big_to_host_int32(binary, 0);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_int32(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_uint32_for_name(wi_p7_message_t *p7_message, wi_p7_uint32_t value, wi_string_t *field_name) {
	wi_string_t		*string;

	if(p7_message->serialization == WI_P7_BINARY) {
		return wi_p7_message_set_int32_for_name(p7_message, (wi_p7_int32_t) value, field_name);
	} else {
		string = wi_string_with_format(WI_STR("%u"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_UINT32, field_name, string);
		
		return true;
	}
}



wi_boolean_t wi_p7_message_get_uint32_for_name(wi_p7_message_t *p7_message, wi_p7_uint32_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	wi_p7_int32_t	p7_int32;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!wi_p7_message_get_int32_for_name(p7_message, &p7_int32, field_name))
			return false;
		
		*value = (wi_p7_uint32_t) p7_int32;
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_uint32(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_int64_for_name(wi_p7_message_t *p7_message, wi_p7_int64_t value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;

	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		wi_write_swap_host_to_big_int64(binary, 4, value);
	} else {
		string = wi_string_with_format(WI_STR("%lld"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_INT64, field_name, string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_get_int64_for_name(wi_p7_message_t *p7_message, wi_p7_int64_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		*value = wi_read_swap_big_to_host_int64(binary, 0);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_int64(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_uint64_for_name(wi_p7_message_t *p7_message, wi_p7_uint64_t value, wi_string_t *field_name) {
	wi_string_t		*string;

	if(p7_message->serialization == WI_P7_BINARY) {
		return wi_p7_message_set_int64_for_name(p7_message, (wi_p7_int64_t) value, field_name);
	} else {
		string = wi_string_with_format(WI_STR("%llu"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_UINT64, field_name, string);
		
		return true;
	}
}



wi_boolean_t wi_p7_message_get_uint64_for_name(wi_p7_message_t *p7_message, wi_p7_uint64_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	wi_p7_int64_t	p7_int64;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!wi_p7_message_get_int64_for_name(p7_message, &p7_int64, field_name))
			return false;
		
		*value = (wi_p7_uint64_t) p7_int64;
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_uint64(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_double_for_name(wi_p7_message_t *p7_message, wi_p7_double_t value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;

	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		
		_wi_p7_message_double_to_ieee754(value, binary + 4);
	} else {
		string = wi_string_with_format(WI_STR("%f"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_DOUBLE, field_name, string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_get_double_for_name(wi_p7_message_t *p7_message, wi_p7_double_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		*value = _wi_p7_message_ieee754_to_double(binary);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_double(string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_set_oobdata_for_name(wi_p7_message_t *p7_message, wi_p7_oobdata_t value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;

	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		wi_write_swap_host_to_big_int64(binary, 4, value);
	} else {
		string = wi_string_with_format(WI_STR("%llu"), value);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_OOBDATA, field_name, string);
	}
	
	return true;
}



wi_boolean_t wi_p7_message_get_oobdata_for_name(wi_p7_message_t *p7_message, wi_p7_oobdata_t *value, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		*value = wi_read_swap_big_to_host_int64(binary, 0);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return false;
		
		*value = wi_string_uint64(string);
	}
	
	return true;
}



#pragma mark -

wi_boolean_t wi_p7_message_set_string_for_name(wi_p7_message_t *p7_message, wi_string_t *string, wi_string_t *field_name) {
	unsigned char	*binary;
	uint32_t		field_size, field_id;
	
	if(!string)
		string = WI_STR("");
	
	if(p7_message->serialization == WI_P7_BINARY) {
		field_size = wi_string_length(string) + 1;
		
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, field_size, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		wi_write_swap_host_to_big_int32(binary, 4, field_size);
		
		memcpy(binary + 8, wi_string_cstring(string), field_size);
	} else {
		_wi_p7_message_set_xml_field(p7_message, WI_P7_STRING, field_name, string);
	}
		
	return true;
}



wi_string_t * wi_p7_message_string_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_size;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, &field_size))
			return NULL;
		
		return wi_string_with_bytes_no_copy(binary, field_size, false);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return NULL;
		
		return string;
	}
}



wi_boolean_t wi_p7_message_set_data_for_name(wi_p7_message_t *p7_message, wi_data_t *data, wi_string_t *field_name) {
	unsigned char	*binary;
	uint32_t		field_size, field_id;
	
	if(!data)
		data = wi_data();
	
	if(p7_message->serialization == WI_P7_BINARY) {
		field_size = wi_data_length(data);
		
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, field_size, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		wi_write_swap_host_to_big_int32(binary, 4, field_size);
		
		memcpy(binary + 8, wi_data_bytes(data), field_size);
	} else {
		_wi_p7_message_set_xml_field(p7_message, WI_P7_DATA, field_name, wi_data_base64(data));
	}
		
	return true;
}



wi_data_t * wi_p7_message_data_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_size;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, &field_size))
			return NULL;
		
		return wi_data_with_bytes_no_copy(binary, field_size, false);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return NULL;
		
		return wi_autorelease(wi_data_init_with_base64(wi_data_alloc(), string));
	}
}



wi_boolean_t wi_p7_message_set_number_for_name(wi_p7_message_t *p7_message, wi_number_t *number, wi_string_t *field_name) {
	if(!number)
		number = wi_number_with_int32(0);
	
	if(wi_number_type(number) == WI_NUMBER_BOOL) {
		return wi_p7_message_set_bool_for_name(p7_message, wi_number_bool(number), field_name);
	} else {
		switch(wi_number_storage_type(number)) {
			case WI_NUMBER_STORAGE_INT32:
				return wi_p7_message_set_int32_for_name(p7_message, wi_number_int32(number), field_name);
				break;

			case WI_NUMBER_STORAGE_INT64:
				return wi_p7_message_set_int64_for_name(p7_message, wi_number_int64(number), field_name);
				break;

			case WI_NUMBER_STORAGE_FLOAT:
				return wi_p7_message_set_double_for_name(p7_message, wi_number_float(number), field_name);
				break;

			case WI_NUMBER_STORAGE_DOUBLE:
				return wi_p7_message_set_double_for_name(p7_message, wi_number_double(number), field_name);
				break;
		}
	}
	
	return false;
}



wi_number_t * wi_p7_message_number_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_p7_int32_t			p7_int32;
	wi_p7_int64_t			p7_int64;
	wi_p7_double_t			p7_double;
	wi_p7_type_t			type_id;
	uint32_t				field_id;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		field_id = wi_p7_spec_field_id(p7_message->spec, field_name);
		
		if(field_id == WI_P7_SPEC_FIELD_ID_NULL)
			return NULL;
		
		type_id = wi_p7_spec_field_type(p7_message->spec, field_id);
	} else {
		type_id = _wi_p7_message_xml_type_for_name(p7_message, field_name);
	}
	
	switch(type_id) {
		case WI_P7_INT32:
			if(wi_p7_message_get_int32_for_name(p7_message, &p7_int32, field_name))
				return wi_number_with_int32(p7_int32);
			break;
		
		case WI_P7_INT64:
			if(wi_p7_message_get_int64_for_name(p7_message, &p7_int64, field_name))
				return wi_number_with_int64(p7_int64);
			break;
		
		case WI_P7_DOUBLE:
			if(wi_p7_message_get_double_for_name(p7_message, &p7_double, field_name))
				return wi_number_with_double(p7_double);
			break;
		
		default:
			break;
	}
	
	return NULL;
}



wi_boolean_t wi_p7_message_set_uuid_for_name(wi_p7_message_t *p7_message, wi_uuid_t *uuid, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id;
	
	if(!uuid)
		return false;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		
		wi_uuid_get_bytes(uuid, binary + 4);
	} else {
		string = wi_uuid_string(uuid);

		_wi_p7_message_set_xml_field(p7_message, WI_P7_UUID, field_name, string);
	}
	
	return true;
}



wi_uuid_t * wi_p7_message_uuid_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, NULL))
			return false;
		
		return wi_uuid_with_bytes(binary);
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return NULL;
		
		return wi_uuid_with_string(string);
	}
	
	return NULL;
}



wi_boolean_t wi_p7_message_set_date_for_name(wi_p7_message_t *p7_message, wi_date_t *date, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_id, field_size;
	
	if(!date)
		date = wi_date();
	
	string = wi_date_iso8601_string(date);
	
	if(p7_message->serialization == WI_P7_BINARY) {
		field_size = wi_string_length(string) + 1;
		
		if(!_wi_p7_message_get_binary_buffer_for_writing_for_name(p7_message, field_name, 0, &binary, &field_id))
			return false;
		
		wi_write_swap_host_to_big_int32(binary, 0, field_id);
		
		memcpy(binary + 4, wi_string_cstring(string), field_size);
	} else {
		_wi_p7_message_set_xml_field(p7_message, WI_P7_DATE, field_name, string);
	}
	
	return true;
}



wi_date_t * wi_p7_message_date_for_name(wi_p7_message_t *p7_message, wi_string_t *field_name) {
	wi_string_t		*string;
	unsigned char	*binary;
	uint32_t		field_size;
	
	if(p7_message->serialization == WI_P7_BINARY) {
		if(!_wi_p7_message_get_binary_buffer_for_reading_for_name(p7_message, field_name, &binary, &field_size))
			return NULL;
		
		return wi_date_with_iso8601_string(wi_string_with_bytes_no_copy(binary, field_size, false));
	} else {
		string = _wi_p7_message_xml_value_for_name(p7_message, field_name);
		
		if(!string)
			return NULL;
		
		return wi_date_with_iso8601_string(string);
	}
	
	return NULL;
}

#endif
