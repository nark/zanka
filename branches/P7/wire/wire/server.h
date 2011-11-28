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

#ifndef WR_SERVER_H
#define WR_SERVER_H 1

typedef struct _wr_server			wr_server_t;


void								wr_servers_init(void);

wr_server_t *						wr_server_with_message(wi_p7_message_t *);

wr_server_t *						wr_server_alloc(void);
wr_server_t *						wr_server_init_with_message(wr_server_t *, wi_p7_message_t *);

wi_string_t *						wr_server_name(wr_server_t *);
wi_string_t *						wr_server_description(wr_server_t *);
wi_date_t *							wr_server_start_time(wr_server_t *);
wi_uinteger_t						wr_server_files_count(wr_server_t *);
wi_file_offset_t					wr_server_files_size(wr_server_t *);
wi_string_t *						wr_server_application_name(wr_server_t *);
wi_string_t *						wr_server_application_version(wr_server_t *);
wi_uinteger_t						wr_server_application_build(wr_server_t *);
wi_string_t *						wr_server_os_name(wr_server_t *);
wi_string_t *						wr_server_os_version(wr_server_t *);
wi_string_t *						wr_server_arch(wr_server_t *);

#endif /* WR_SERVER_H */
