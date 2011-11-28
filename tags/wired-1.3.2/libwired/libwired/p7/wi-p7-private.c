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

#include <wired/wi-string.h>
#include <wired/wi-p7-private.h>

#include <libxml/tree.h>

wi_string_t * wi_p7_xml_string_for_attribute(xmlNodePtr node, wi_string_t *attribute) {
	xmlChar			*prop;
	wi_string_t		*string;
	
	prop = xmlGetProp(node, (xmlChar *) wi_string_cstring(attribute));
	
	if(!prop)
		return NULL;
	
	string = wi_string_with_cstring((const char *) prop);
	
	xmlFree(prop);
	
	return string;
}



wi_integer_t wi_p7_xml_integer_for_attribute(xmlNodePtr node, wi_string_t *attribute) {
	wi_string_t		*string;
	
	string = wi_p7_xml_string_for_attribute(node, attribute);
	
	if(!string)
		return 0;
	
	return wi_string_integer(string);
}

#endif
