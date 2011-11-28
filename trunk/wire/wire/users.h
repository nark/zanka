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

#ifndef WR_USERS_H
#define WR_USERS_H 1

typedef wi_uinteger_t				wr_uid_t;
typedef wi_uinteger_t				wr_icon_t;

typedef struct _wr_user				wr_user_t;


void								wr_users_init(void);
void								wr_users_clear(void);

char *								wr_readline_nickname_generator(const char *, int);

wr_user_t *							wr_user_alloc(void);
wr_user_t *							wr_user_init_with_arguments(wr_user_t *, wi_array_t *);

void								wr_user_set_idle(wr_user_t *, wi_boolean_t);
void								wr_user_set_admin(wr_user_t *, wi_boolean_t);
void								wr_user_set_nick(wr_user_t *, wi_string_t *);
void								wr_user_set_status(wr_user_t *, wi_string_t *);

wr_uid_t							wr_user_id(wr_user_t *);
wi_boolean_t						wr_user_is_idle(wr_user_t *);
wi_boolean_t						wr_user_is_admin(wr_user_t *);
wi_string_t *						wr_user_nick(wr_user_t *);
wi_string_t *						wr_user_status(wr_user_t *);


extern wr_uid_t						wr_reply_uid;

#endif /* WR_USERS_H */
