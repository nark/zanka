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

#ifndef WR_USERS_H
#define WR_USERS_H 1

typedef wi_uinteger_t				wr_uid_t;
typedef wi_uinteger_t				wr_icon_t;

typedef struct _wr_user				wr_user_t;

enum _wr_user_color {
	WR_USER_COLOR_BLACK				= 0,
	WR_USER_COLOR_RED				= 1,
	WR_USER_COLOR_ORANGE			= 2,
	WR_USER_COLOR_GREEN				= 3,
	WR_USER_COLOR_BLUE				= 4,
	WR_USER_COLOR_PURPLE			= 5
};
typedef enum _wr_user_color			wr_user_color_t;


void								wr_users_init(void);
void								wr_users_clear(void);

char *								wr_readline_nickname_generator(const char *, int);

wr_user_t *							wr_user_with_message(wi_p7_message_t *);

wr_user_t *							wr_user_alloc(void);
wr_user_t *							wr_user_init_with_message(wr_user_t *, wi_p7_message_t *);

wr_uid_t							wr_user_id(wr_user_t *);

void								wr_user_set_idle(wr_user_t *, wi_boolean_t);
wi_boolean_t						wr_user_is_idle(wr_user_t *);
void								wr_user_set_admin(wr_user_t *, wi_boolean_t);
wi_boolean_t						wr_user_is_admin(wr_user_t *);
void								wr_user_set_nick(wr_user_t *, wi_string_t *);
wi_string_t *						wr_user_nick(wr_user_t *);
void								wr_user_set_status(wr_user_t *, wi_string_t *);
wi_string_t *						wr_user_status(wr_user_t *);
wr_user_color_t						wr_user_color(wr_user_t *);

#endif /* WR_USERS_H */
