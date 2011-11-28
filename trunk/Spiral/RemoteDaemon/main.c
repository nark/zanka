/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>

#include <stdlib.h>

#include <dns_sd.h>

#include <wired/wired.h>

static wi_socket_t *				srd_listen(void);
static void							srd_accept(wi_socket_t *);
static void							srd_accept_thread(wi_runtime_instance_t *);
static void							srd_server(wi_p7_socket_t *);
static void							srd_launch_spiral(void);
static wi_p7_socket_t *				srd_connect_spiral(void);
static void							srd_register_spiral(wi_p7_message_t *, wi_address_t *);
static void							srd_fsevents_thread(wi_runtime_instance_t *);
static void							srd_fsevents_callback(wi_string_t *);
static void							srd_usage(void);


static wi_string_t					*srd_spiral_path;
static wi_uuid_t					*srd_spiral_id;
static wi_p7_spec_t					*srd_p7_spec;
static wi_rsa_t						*srd_rsa;
static wi_address_t					*srd_listen_address;
static DNSServiceRef				srd_dnssd_service;
static wi_fsevents_t				*srd_fsevents;

static wi_address_t					*srd_spiral_address;
static wi_condition_lock_t			*srd_spiral_address_lock;


int main(int argc, const char **argv) {
	wi_pool_t		*pool;
	wi_socket_t		*socket;
	wi_string_t		*path;
	int				ch;
	
	wi_initialize();
	wi_load(argc, argv);
	
	pool = wi_pool_init(wi_pool_alloc());

	wi_log_tool				= true;
	wi_log_level			= WI_LOG_DEBUG;
	srd_spiral_address_lock	= wi_condition_lock_init_with_condition(wi_condition_lock_alloc(), 0);
	
	while((ch = getopt(argc, (char * const *) argv, "s:i:")) != -1) {
		switch(ch) {
			case 's':
				wi_release(srd_spiral_path);
				srd_spiral_path = wi_retain(wi_string_with_cstring(optarg));
				break;
			
			case 'i':
				wi_release(srd_spiral_id);
				srd_spiral_id = wi_uuid_init_with_string(wi_uuid_alloc(), wi_string_with_cstring(optarg));
				break;
			
			case 'h':
			case '?':
			default:
				srd_usage();
				break;
		}
	}
	
	if(!srd_spiral_path || !srd_spiral_id)
		srd_usage();
	
	path = wi_string_by_appending_path_component(srd_spiral_path, WI_STR("Contents/Resources/remote.xml"));
	
	srd_p7_spec = wi_p7_spec_init_with_file(wi_p7_spec_alloc(), path, WI_P7_SERVER);
	
	if(!srd_p7_spec)
		wi_log_error(WI_STR("Could not open protocol %@: %m"), path);
	
	srd_rsa = wi_rsa_init_with_bits(wi_rsa_alloc(), 1024);
	
	if(!srd_rsa)
		wi_log_error(WI_STR("Could not create RSA key: %m"));

	srd_fsevents = wi_fsevents_init(wi_fsevents_alloc());
	
	if(!srd_fsevents)
		wi_log_error(WI_STR("Could not create fsevents: %m"));
	
	wi_fsevents_add_path(srd_fsevents, srd_spiral_path);
	wi_fsevents_set_callback(srd_fsevents, srd_fsevents_callback);
	
	if(!wi_thread_create_thread(srd_fsevents_thread, NULL))
	   wi_log_error(WI_STR("Could not create a thread: %m"));
	
	signal(SIGPIPE, SIG_IGN);

	socket = srd_listen();
	
	srd_accept(socket);
	
	return 0;
}



static wi_socket_t * srd_listen(void) {
	wi_socket_t				*socket;
	wi_address_t			*address;
	DNSServiceErrorType		err;
	
	address = wi_address_wildcard_for_family(WI_ADDRESS_IPV4);
	socket = wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP);
	
	if(!socket)
		wi_log_error(WI_STR("Could not create socket: %m"));
	
	if(!wi_socket_listen(socket)) {
		wi_log_error(WI_STR("Could not listen on %@ port %u: %m"),
			wi_address_string(address), wi_socket_port(socket));
	}
	
	srd_listen_address = wi_retain(wi_socket_address(socket));
	
	err = DNSServiceRegister(&srd_dnssd_service,
							 0,
							 kDNSServiceInterfaceIndexAny,
							 NULL,
							 "_spiral._tcp",
							 NULL,
							 NULL,
							 htons(wi_address_port(srd_listen_address)),
							 0,
							 NULL,
							 NULL,
							 NULL);
	
	if(err != kDNSServiceErr_NoError)
		wi_log_warn(WI_STR("Could not register for DNS service discovery: %d"), err);
	
	return wi_autorelease(socket);
}



static void srd_accept(wi_socket_t *accept_socket) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_address_t		*address;
	wi_string_t			*ip;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	while(true) {
		wi_pool_drain(pool);

		socket = wi_socket_accept(accept_socket, 10.0, &address);

		if(!address) {
			wi_log_warn(WI_STR("Could not accept a connection: %m"));
			
			continue;
		}
		
		ip = wi_address_string(address);
		
		if(!socket) {
			wi_log_warn(WI_STR("Could not accept a connection for %@: %m"), ip);
			
			continue;
		}
		
		if(!wi_thread_create_thread(srd_accept_thread, socket))
			wi_log_warn(WI_STR("Could not create a thread for %@: %m"), ip);
	}
	
	wi_release(pool);
}



static void srd_accept_thread(wi_runtime_instance_t *instance) {
	wi_pool_t			*pool;
	wi_socket_t			*socket = instance;
	wi_p7_socket_t		*p7_socket;
	wi_string_t			*ip;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	ip = wi_address_string(wi_socket_address(socket));
	
	p7_socket = wi_autorelease(wi_p7_socket_init_with_socket(wi_p7_socket_alloc(), socket, srd_p7_spec));
	wi_p7_socket_set_private_key(p7_socket, srd_rsa);
	
	if(wi_p7_socket_accept(p7_socket, 10.0, WI_P7_ALL))
		srd_server(p7_socket);
	else
		wi_log_warn(WI_STR("Could not accept a P7 connection for %@: %m"), ip);
	
	wi_release(pool);
}



static void srd_server(wi_p7_socket_t *p7_socket) {
	wi_p7_socket_t			*spiral_p7_socket = NULL;
	wi_socket_t				*socket, *spiral_socket = NULL, *waiting_socket;
	wi_p7_message_t			*message;
	wi_mutable_array_t		*sockets;
	wi_pool_t				*pool;
	wi_string_t				*name;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	message = wi_p7_message_with_name(WI_STR("spiral.application_id"), srd_p7_spec);
	wi_p7_message_set_uuid_for_name(message, srd_spiral_id, WI_STR("spiral.application_id"));
	wi_p7_socket_write_message(p7_socket, 0.0, message);
	
	socket = wi_p7_socket_socket(p7_socket);
	sockets = wi_array_init_with_data(wi_mutable_array_alloc(), socket, NULL);

	while(true) {
		wi_pool_drain(pool);
		
		waiting_socket = wi_socket_wait_multiple(sockets, 0.0);
		
		if(waiting_socket == socket) {
			message = wi_p7_socket_read_message(p7_socket, 10.0);
			
			if(!message)
				break;
			
			if(!wi_p7_spec_verify_message(srd_p7_spec, message))
				continue;
			
			name = wi_p7_message_name(message);
			
			if(wi_is_equal(name, WI_STR("spiral.register"))) {
				srd_register_spiral(message, wi_socket_address(socket));
			}
			else if(wi_is_equal(name, WI_STR("spiral.connect")) && !spiral_p7_socket) {
				srd_launch_spiral();
				
				spiral_p7_socket = wi_retain(srd_connect_spiral());
	
				if(spiral_p7_socket) {
					spiral_socket = wi_p7_socket_socket(spiral_p7_socket);
					wi_mutable_array_add_data(sockets, spiral_socket);
					
					wi_p7_socket_write_message(spiral_p7_socket, 10.0, message);
				} else {
					break;
				}
			}
			else if(spiral_p7_socket) {
				wi_p7_socket_write_message(spiral_p7_socket, 10.0, message);
			}
		}
		else if(waiting_socket == spiral_socket) {
			message = wi_p7_socket_read_message(spiral_p7_socket, 10.0);
			
			if(!message) {
				wi_condition_lock_lock(srd_spiral_address_lock);
				
				wi_release(srd_spiral_address);
				srd_spiral_address = NULL;
				
				wi_condition_lock_unlock_with_condition(srd_spiral_address_lock, 0);
				break;
			}
			
			if(!wi_p7_spec_verify_message(srd_p7_spec, message))
				continue;
			
			wi_p7_socket_write_message(p7_socket, 10.0, message);
		}
	}
	
	wi_release(sockets);
	wi_release(spiral_p7_socket);
	wi_release(pool);
}



static void srd_launch_spiral(void) {
	LSApplicationParameters		parameters;
	CFMutableArrayRef			array;
	CFStringRef					string;
	FSRef						fsRef;
	OSStatus					status;
	
	status = FSPathMakeRef((const UInt8 *) wi_string_cstring(srd_spiral_path), &fsRef, NULL);
	
	if(status == noErr) {
		string = CFStringCreateWithFormat(NULL, NULL, CFSTR("%u"), wi_address_port(srd_listen_address));

		array = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
		CFArrayAppendValue(array, CFSTR("-remote"));
		CFArrayAppendValue(array, string);
		
		parameters.version				= 0;
		parameters.flags				= kLSLaunchDefaults;
		parameters.application			= &fsRef;
		parameters.asyncLaunchRefCon	= NULL;
		parameters.environment			= NULL;
		parameters.argv					= array;
		parameters.initialEvent			= NULL;
		
		status = LSOpenApplication(&parameters, NULL);
		
		if(status != noErr)
			wi_log_warn(WI_STR("Could not launch Spiral: %d"), status);
		
		CFRelease(string);
		CFRelease(array);
	} else {
		wi_log_warn(WI_STR("Could not locate Spiral: %d"), status);
	}
}



static void srd_register_spiral(wi_p7_message_t *message, wi_address_t *address) {
	wi_p7_uint32_t		port;
	
	wi_condition_lock_lock(srd_spiral_address_lock);
	
	wi_release(srd_spiral_address);
	srd_spiral_address = wi_copy(address);
	
	wi_p7_message_get_uint32_for_name(message, &port, WI_STR("spiral.port"));
	wi_address_set_port(srd_spiral_address, port);
	
	wi_condition_lock_unlock_with_condition(srd_spiral_address_lock, 1);
}



static wi_p7_socket_t * srd_connect_spiral(void) {
	wi_socket_t			*socket;
	wi_p7_socket_t		*p7_socket;
	wi_address_t		*address;
	wi_uinteger_t		i;
	
	for(i = 0; i < 10; i++) {
		if(i > 0)
			wi_thread_sleep(0.5);
		
		if(wi_condition_lock_lock_when_condition(srd_spiral_address_lock, 1, 10.0))
			address = wi_autorelease(wi_copy(srd_spiral_address));
		else
			address = NULL;
		
		wi_condition_lock_unlock(srd_spiral_address_lock);
			
		if(address) {
			socket = wi_autorelease(wi_socket_init_with_address(wi_socket_alloc(), address, WI_SOCKET_TCP));
			wi_socket_set_direction(socket, WI_SOCKET_WRITE);
			wi_socket_set_interactive(socket, true);
			
			if(!wi_socket_connect(socket, 10.0)) {
				wi_log_warn(WI_STR("Could not connect to %@: %m"), wi_address_string(address));
				
				continue;
			}
			
			p7_socket = wi_autorelease(wi_p7_socket_init_with_socket(wi_p7_socket_alloc(), socket, srd_p7_spec));
			
			if(!wi_p7_socket_connect(p7_socket,
									 10.0,
									 0,
									 WI_P7_BINARY,
									 WI_STR("guest"),
									 wi_string_sha1(WI_STR("")))) {
				wi_log_warn(WI_STR("Could not connect to %@: %m"), wi_address_string(address));
				
				continue;
			}
			
			if(p7_socket)
				return p7_socket;
		}
	}
	
	return NULL;
}



static void srd_fsevents_thread(wi_runtime_instance_t *instance) {
	wi_pool_t		*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	while(true) {
		if(!wi_fsevents_run_with_timeout(srd_fsevents, 0.0))
			wi_log_warn(WI_STR("Could not listen on fsevents: %m"));
		
		wi_pool_drain(pool);
	}
	
	wi_release(pool);
}



static void srd_fsevents_callback(wi_string_t *path) {
	wi_task_t		*task;
	wi_string_t		*plist;
	
	plist = wi_string_by_expanding_tilde_in_path(WI_STR("~/Library/LaunchAgents/com.zankasoftware.SpiralRemote.plist"));
	task = wi_task_launched_task_with_path(WI_STR("/bin/launchctl"), wi_array_with_data(WI_STR("unload"), WI_STR("-w"), plist, NULL));
}



static void srd_usage(void) {
	fprintf(stderr,
"Usage: SpiralRemote -s spiral -i identifier\n\
\n\
Options:\n\
    -s             path to Spiral.app\n\
    -i             Spiral identifier\n\
\n\
By Axel Andersson <axel@zankasoftware.com>\n");

	exit(2);
}
