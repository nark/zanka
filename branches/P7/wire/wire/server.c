/* $Id$ */

/*
 *  Copyright (c) 2004-2011 Axel Andersson
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

#include <wired/wired.h>

#include "server.h"

static void							wr_server_dealloc(wi_runtime_instance_t *);


struct _wr_server {
	wi_runtime_base_t				base;

	wi_string_t						*name;
	wi_string_t						*description;
	wi_date_t						*start_time;
	wi_uinteger_t					files_count;
	wi_file_offset_t				files_size;
	wi_string_t						*application_name;
	wi_string_t						*application_version;
	wi_uinteger_t					application_build;
	wi_string_t						*os_name;
	wi_string_t						*os_version;
	wi_string_t						*arch;
};


static wi_runtime_id_t				wr_server_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_server_runtime_class = {
	"wr_server_t",
	wr_server_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_servers_init(void) {
	wr_server_runtime_id = wi_runtime_register_class(&wr_server_runtime_class);
}



#pragma mark -

wr_server_t * wr_server_with_message(wi_p7_message_t *message) {
	return wi_autorelease(wr_server_init_with_message(wr_server_alloc(), message));
}



#pragma mark -

wr_server_t * wr_server_alloc(void) {
	return wi_runtime_create_instance(wr_server_runtime_id, sizeof(wr_server_t));
}



wr_server_t * wr_server_init_with_message(wr_server_t *server, wi_p7_message_t *message) {
	wi_p7_uint64_t		files_count, files_size;
	wi_p7_uint32_t		application_build;
	
	wi_p7_message_get_uint32_for_name(message, &application_build, WI_STR("wired.info.application.build"));
	wi_p7_message_get_uint64_for_name(message, &files_count, WI_STR("wired.info.files.count"));
	wi_p7_message_get_uint64_for_name(message, &files_size, WI_STR("wired.info.files.size"));
	
	server->name					= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.name")));
	server->description				= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.description")));
	server->start_time				= wi_retain(wi_p7_message_date_for_name(message, WI_STR("wired.info.start_time")));
	server->files_count				= files_count;
	server->files_size				= files_size;
	server->application_name		= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.application.name")));
	server->application_version		= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.application.version")));
	server->application_build		= application_build;
	server->os_name					= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.os.name")));
	server->os_version				= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.os.version")));
	server->arch					= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.info.arch")));

	return server;
}



static void wr_server_dealloc(wi_runtime_instance_t *instance) {
	wr_server_t		*server = instance;
	
	wi_release(server->name);
	wi_release(server->description);
	wi_release(server->start_time);
	wi_release(server->application_name);
	wi_release(server->application_version);
	wi_release(server->os_name);
	wi_release(server->os_version);
	wi_release(server->arch);
}



#pragma mark -

wi_string_t * wr_server_name(wr_server_t *server) {
	return server->name;
}



wi_string_t * wr_server_description(wr_server_t *server) {
	return server->description;
}



wi_date_t * wr_server_start_time(wr_server_t *server) {
	return server->start_time;
}



wi_uinteger_t wr_server_files_count(wr_server_t *server) {
	return server->files_count;
}



wi_file_offset_t wr_server_files_size(wr_server_t *server) {
	return server->files_size;
}



wi_string_t * wr_server_application_name(wr_server_t *server) {
	return server->application_name;
}



wi_string_t * wr_server_application_version(wr_server_t *server) {
	return server->application_version;
}



wi_uinteger_t wr_server_application_build(wr_server_t *server) {
	return server->application_build;
}



wi_string_t * wr_server_os_name(wr_server_t *server) {
	return server->os_name;
}



wi_string_t * wr_server_os_version(wr_server_t *server) {
	return server->os_version;
}



wi_string_t * wr_server_arch(wr_server_t *server) {
	return server->arch;
}
