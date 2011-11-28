/* $Id$ */

/*
 *  Copyright (c) 2004-2006 Axel Andersson
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


static wi_runtime_id_t				wr_server_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_server_runtime_class = {
	"wr_server_t",
	wr_server_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_init_server(void) {
	wr_server_runtime_id = wi_runtime_register_class(&wr_server_runtime_class);
}



#pragma mark -

wr_server_t * wr_server_alloc(void) {
	return wi_runtime_create_instance(wr_server_runtime_id, sizeof(wr_server_t));
}



wr_server_t * wr_server_init(wr_server_t *server) {
	return server;
}



static void wr_server_dealloc(wi_runtime_instance_t *instance) {
	wr_server_t		*server = instance;
	
	wi_release(server->version);
	wi_release(server->name);
	wi_release(server->description);
	wi_release(server->startdate);
}
