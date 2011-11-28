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

#ifndef WR_CLIENT_H
#define WR_CLIENT_H 1

#include "server.h"

#define WR_MESSAGE_SEPARATOR			'\4'
#define WR_MESSAGE_SEPARATOR_STR		"\4"
#define WR_FIELD_SEPARATOR				'\34'
#define WR_GROUP_SEPARATOR_STR			"\35"
#define WR_RECORD_SEPARATOR_STR			"\36"

#define WR_PROTOCOL						1.0

#define WR_CONTROL_PORT					2000
#define WR_TRANSFER_PORT				2001
#define WR_TRACKER_PORT					2002

#define WR_BUFFER_INITIAL_SIZE			BUFSIZ
#define WR_BUFFER_MAX_SIZE				131072

#define WR_CHECKSUM_SIZE				1048576


void									wr_client_init(void);

wi_boolean_t							wr_set_charset(wi_string_t *);

void									wr_connect(wi_string_t *, wi_uinteger_t, wi_string_t *, wi_string_t *);
void									wr_disconnect(void);

wi_boolean_t							wr_send_command(wi_string_t *, ...);
wi_boolean_t							wr_send_command_on_socket(wi_socket_t *, wi_string_t *, ...);


extern wi_string_encoding_t				*wr_client_string_encoding;
extern wi_string_encoding_t				*wr_server_string_encoding;

extern wi_string_t						*wr_host;
extern wi_uinteger_t					wr_port;

extern wr_server_t						*wr_server;

extern wi_string_t						*wr_nick;
extern wi_string_t						*wr_status;
extern wi_string_t						*wr_icon;
extern wi_string_t						*wr_login;
extern wi_string_t						*wr_password;

extern wi_string_t						*wr_icon_path;
extern wi_string_t						*wr_timestamp_format;

extern uint64_t							wr_received_bytes;
extern uint64_t							wr_transferred_bytes;

extern wi_integer_t						wr_news_count;
extern wi_integer_t						wr_news_limit;

extern wi_time_interval_t				wr_ping_time;

extern wi_socket_tls_t					*wr_socket_tls;
extern wi_socket_t						*wr_socket;
extern wi_address_t						*wr_address;

extern wi_boolean_t						wr_connected;
extern wi_boolean_t						wr_logged_in;

#endif /* WR_CLIENT_H */
