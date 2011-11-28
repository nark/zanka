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

#ifndef WR_CLIENT_H
#define WR_CLIENT_H 1

#include "server.h"

#define WR_PORT							4871


void									wr_client_init(void);

wi_boolean_t							wr_client_set_charset(wi_string_t *);

void									wr_client_connect(wi_string_t *, wi_uinteger_t, wi_string_t *, wi_string_t *);
void									wr_client_disconnect(void);

void									wr_client_send_message(wi_p7_message_t *);
void									wr_client_reply_message(wi_p7_message_t *, wi_p7_message_t *);


extern wi_string_encoding_t				*wr_client_string_encoding;
extern wi_string_encoding_t				*wr_server_string_encoding;

extern wi_string_t						*wr_nick;
extern wi_string_t						*wr_status;
extern wi_data_t						*wr_icon;
extern wi_string_t						*wr_icon_path;
extern wi_string_t						*wr_timestamp_format;

extern wr_server_t						*wr_server;

extern wi_socket_t						*wr_socket;
extern wi_p7_socket_t					*wr_p7_socket;

extern wi_string_t						*wr_password;

extern wi_boolean_t						wr_connected;

#endif /* WR_CLIENT_H */
