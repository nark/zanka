/* $Id$ */

/*
 *  Copyright (c) 2004-2007 Axel Andersson
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

#include <openssl/ssl.h>
#include <readline/readline.h>
#include <wired/wired.h>

#include "version.h"

wi_string_t					*wr_version_string;
wi_string_t					*wr_protocol_version_string;
wi_string_t					*wr_client_version_string;


void wr_version_init(void) {
	wr_version_string			= wi_string_init_with_format(wi_string_alloc(), WI_STR("%s (%u)"), WR_VERSION, WI_REVISION);
	wr_protocol_version_string	= wi_string_init_with_cstring(wi_string_alloc(), WR_PROTOCOL_VERSION);
	wr_client_version_string	= wi_string_init_with_format(wi_string_alloc(), WI_STR("Wire/%@ (%@; %@; %@) (%s; readline %s)"),
		wr_version_string,
		wi_process_os_name(wi_process()),
		wi_process_os_release(wi_process()),
		wi_process_os_arch(wi_process()),
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);
}
