/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#ifndef WD_CHATS_H
#define WD_CHATS_H 1

#include <wired/wired.h>

#include "clients.h"

#define WD_PUBLIC_CID					1


struct _wd_topic {
	wi_string_t							*topic;

	wi_date_t							*date;

	wi_string_t							*nick;
	wi_string_t							*login;
	wi_string_t							*ip;
};
typedef struct _wd_topic				wd_topic_t;


typedef unsigned int					wd_cid_t;

struct _wd_chat {
	wi_runtime_base_t					base;
	
	wd_cid_t							cid;
	wd_topic_t							topic;
	wi_list_t							*clients;
};
typedef struct _wd_chat					wd_chat_t;


void									wd_init_chats(void);
void									wd_dump_chats(void);

wd_chat_t *								wd_chat_alloc(void);
wd_chat_t *								wd_chat_init(wd_chat_t *);
wd_chat_t *								wd_chat_init_public(wd_chat_t *);
wd_chat_t *								wd_chat_init_private(wd_chat_t *);

wd_chat_t *								wd_chat_with_cid(wd_cid_t);

wi_boolean_t							wd_chat_contains_client(wd_chat_t *, wd_client_t *);
void									wd_chat_add_client(wd_chat_t *, wd_client_t *);
void									wd_chat_remove_client(wd_chat_t *, wd_client_t *);
void									wd_chat_reply_client_list(wd_chat_t *);

void									wd_chat_set_topic(wd_chat_t *, wi_string_t *);
void									wd_chat_reply_topic(wd_chat_t *);
void									wd_chat_broadcast_topic(wd_chat_t *);

void									wd_chats_remove_client(wd_client_t *);


extern wi_list_t						*wd_chats;

#endif /* WD_CHATS_H */
