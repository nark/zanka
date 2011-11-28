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

#ifndef WR_USERS_H
#define WR_USERS_H 1

typedef uint32_t					wr_uid_t;
typedef uint32_t					wr_icon_t;

struct _wr_user {
	wi_runtime_base_t				base;
	
	wr_uid_t						uid;
	wi_boolean_t					idle;
	wi_boolean_t					admin;
	
	wi_string_t						*nick;
	wi_string_t						*login;
	wi_string_t						*status;
	wi_string_t						*ip;
};
typedef struct _wr_user				wr_user_t;


void								wr_init_users(void);
void								wr_clear_users(void);

char *								wr_readline_nickname_generator(const char *, int);

wr_user_t *							wr_user_alloc(void);
wr_user_t *							wr_user_init(wr_user_t *);

wr_user_t *							wr_user_with_uid(wr_uid_t);
wr_user_t *							wr_user_with_nick(wi_string_t *);


extern wi_list_t					*wr_users;

extern wr_uid_t						wr_reply_uid;

#endif /* WR_USERS_H */
