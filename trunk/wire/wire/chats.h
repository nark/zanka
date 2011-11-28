/* $Id$ */

/*
 *  Copyright (c) 2006 Axel Andersson
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

#ifndef WR_CHATS_H
#define WR_CHATS_H 1

#include "users.h"

typedef uint32_t					wr_cid_t;

typedef struct _wr_chat				wr_chat_t;


void								wr_chats_init(void);
void								wr_chats_clear(void);

void								wr_chats_add_chat(wr_chat_t *);
void								wr_chats_remove_chat(wr_chat_t *);
wr_chat_t *							wr_chats_chat_with_cid(wr_cid_t);

wr_chat_t *							wr_chat_alloc(void);
wr_chat_t *							wr_chat_init(wr_chat_t *);
wr_chat_t *							wr_chat_init_public_chat(wr_chat_t *);
wr_chat_t *							wr_chat_init_private_chat(wr_chat_t *);

void								wr_chat_set_id(wr_chat_t *, wr_cid_t);

wr_cid_t							wr_chat_id(wr_chat_t *);
wi_array_t *						wr_chat_users(wr_chat_t *);

void								wr_chat_add_user(wr_chat_t *, wr_user_t *);
void								wr_chat_remove_user(wr_chat_t *, wr_user_t *);
void								wr_chat_remove_all_users(wr_chat_t *);
wr_user_t *							wr_chat_user_with_uid(wr_chat_t *, wr_uid_t);
wr_user_t *							wr_chat_user_with_nick(wr_chat_t *, wi_string_t *);


extern wr_chat_t					*wr_public_chat;
extern wr_chat_t					*wr_private_chat;
extern wr_uid_t						wr_private_chat_invite_uid;

#endif /* WR_CHATS_H */
