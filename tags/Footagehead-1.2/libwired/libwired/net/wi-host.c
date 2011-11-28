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

#include <sys/param.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <netdb.h>
#include <net/if.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <errno.h>

#ifdef HAVE_IFADDRS_H
#include <ifaddrs.h>
#endif

#include <wired/wi-address.h>
#include <wired/wi-host.h>
#include <wired/wi-list.h>
#include <wired/wi-pool.h>
#include <wired/wi-string.h>

#include "wi-private.h"

struct _wi_host {
	wi_runtime_base_t					base;
	
	wi_string_t							*string;
};


static void								_wi_host_dealloc(wi_runtime_instance_t *);
static wi_runtime_instance_t *			_wi_host_copy(wi_runtime_instance_t *);
static wi_boolean_t						_wi_host_is_equal(wi_runtime_instance_t *, wi_runtime_instance_t *);
static wi_string_t *					_wi_host_description(wi_runtime_instance_t *);

static wi_list_t *						_wi_host_all_interface_addresses(void);
static wi_list_t *						_wi_host_addresses_for_string(wi_string_t *string);


static wi_runtime_id_t					_wi_host_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_host_runtime_class = {
	"wi_host_t",
	_wi_host_dealloc,
	_wi_host_copy,
	_wi_host_is_equal,
	_wi_host_description,
	NULL
};



void wi_host_register(void) {
	_wi_host_runtime_id = wi_runtime_register_class(&_wi_host_runtime_class);
}



void wi_host_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_host_runtime_id(void) {
	return _wi_host_runtime_id;
}



#pragma mark -

wi_host_t * wi_host(void) {
	return wi_autorelease(wi_host_init(wi_host_alloc()));
}



wi_host_t * wi_host_with_string(wi_string_t *string) {
	return wi_autorelease(wi_host_init_with_string(wi_host_alloc(), string));
}



#pragma mark -

wi_host_t * wi_host_alloc(void) {
	return wi_runtime_create_instance(_wi_host_runtime_id, sizeof(wi_host_t));
}



wi_host_t * wi_host_init(wi_host_t *host) {
	return host;
}



wi_host_t * wi_host_init_with_string(wi_host_t *host, wi_string_t *string) {
	host->string = wi_retain(string);
	
	return host;
}



static void _wi_host_dealloc(wi_runtime_instance_t *instance) {
	wi_host_t		*host = instance;
	
	wi_release(host->string);
}



static wi_runtime_instance_t * _wi_host_copy(wi_runtime_instance_t *instance) {
	wi_host_t		*host = instance;
	
	return host->string
		? wi_host_init_with_string(wi_host_alloc(), host->string)
		: wi_host_init(wi_host_alloc());
}



static wi_boolean_t _wi_host_is_equal(wi_runtime_instance_t *instance1, wi_runtime_instance_t *instance2) {
	wi_host_t			*host1 = instance1;
	wi_host_t			*host2 = instance2;
	wi_list_t			*addresses1;
	wi_list_t			*addresses2;
	wi_list_node_t		*node;
	wi_address_t		*address;
	wi_boolean_t		equal = false;

	addresses1 = wi_host_addresses(host1);
	addresses2 = wi_host_addresses(host2);
	
	if(addresses1 && addresses2) {
		WI_LIST_FOREACH(addresses1, node, address) {
			if(wi_list_contains_data(addresses2, address)) {
				equal = true;
				
				break;
			}
		}
	}
	
	return equal;
}



static wi_string_t * _wi_host_description(wi_runtime_instance_t *instance) {
	wi_host_t		*host = instance;
	
	return wi_string_with_format(WI_STR("<%s %p>{addresses = %@}"),
		wi_runtime_class_name(host),
		host,
		wi_host_addresses(host));
}



#pragma mark -

static wi_list_t * _wi_host_all_interface_addresses(void) {
#if defined(HAVE_GETIFADDRS) && !defined(HAVE_GLIBC)
	wi_list_t			*list;
	wi_address_t		*address;
	struct ifaddrs		*ifap, *ifp;

	if(getifaddrs(&ifap) < 0) {
		wi_error_set_errno(errno);
		
		return NULL;
	}

	list = wi_list_init(wi_list_alloc());

	for(ifp = ifap; ifp; ifp = ifp->ifa_next) {
		if(ifp->ifa_addr->sa_family != AF_INET && ifp->ifa_addr->sa_family != AF_INET6)
			continue;

		if(!(ifp->ifa_flags & IFF_UP))
			continue;
		
		address = wi_address_init_with_sa(wi_address_alloc(), ifp->ifa_addr);
		wi_list_append_data(list, address);
		wi_release(address);
	}

	freeifaddrs(ifap);
	
	if(wi_list_count(list) == 0) {
		wi_error_set_lib_error(WI_ERROR_HOST_NOAVAILABLEADDRESSES);
		
		wi_release(list);
		list = NULL;
	}
	
	return wi_autorelease(list);
#else
	wi_list_t				*list;

	list = wi_list_init(wi_list_alloc());
	wi_list_append_data(list, wi_address_wildcard_for_family(WI_ADDRESS_IPV4));
	wi_list_append_data(list, wi_address_wildcard_for_family(WI_ADDRESS_IPV6));

	return wi_autorelease(list);
#endif
}



static wi_list_t * _wi_host_addresses_for_string(wi_string_t *string) {
	wi_list_t			*list;
	wi_address_t		*address;
	struct addrinfo		*aiap, *aip;
	int					err;

	err = getaddrinfo(wi_string_cstring(string), NULL, NULL, &aiap);

	if(err != 0) {
		wi_error_set_error(WI_ERROR_DOMAIN_GAI, err);
		
		return NULL;
	}
	
	list = wi_list_init(wi_list_alloc());

	for(aip = aiap; aip; aip = aip->ai_next) {
		if(aip->ai_protocol != 0 && aip->ai_protocol != IPPROTO_TCP)
			continue;
		
		if(aip->ai_family != AF_INET && aip->ai_family != AF_INET6)
			continue;

		address = wi_address_init_with_sa(wi_address_alloc(), aip->ai_addr);
		wi_list_append_data(list, address);
		wi_release(address);
	}

	freeaddrinfo(aiap);

	if(wi_list_count(list) == 0) {
		wi_error_set_lib_error(WI_ERROR_HOST_NOAVAILABLEADDRESSES);
		
		wi_release(list);
		list = NULL;
	}

	return wi_autorelease(list);
}



#pragma mark -

wi_address_t * wi_host_address(wi_host_t *host) {
	wi_list_t		*addresses;
	
	addresses = wi_host_addresses(host);

	if(!addresses)
		return NULL;
	
	return wi_list_first_data(addresses);
}



wi_list_t * wi_host_addresses(wi_host_t *host) {
	return host->string
		? _wi_host_addresses_for_string(host->string)
		: _wi_host_all_interface_addresses();
}
