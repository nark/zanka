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

#ifndef WR_WINDOWS_H
#define WR_WINDOWS_H 1

#include "chats.h"
#include "topic.h"
#include "users.h"

#define WR_PREFIX							"[wire] "

#define WR_BLACK_COLOR						"\033[0;30m"
#define WR_RED_COLOR						"\033[0;31m"
#define WR_BRIGHT_RED_COLOR					"\033[1;31m"
#define WR_GREEN_COLOR						"\033[0;32m"
#define WR_BRIGHT_GREEN_COLOR				"\033[1;32m"
#define WR_YELLOW_COLOR						"\033[0;33m"
#define WR_BRIGHT_YELLOW_COLOR				"\033[1;33m"
#define WR_BLUE_COLOR						"\033[0;34m"
#define WR_BRIGHT_BLUE_COLOR				"\033[1;34m"
#define WR_MAGENTA_COLOR					"\033[0;35m"
#define WR_BRIGHT_MAGENTA_COLOR				"\033[1;35m"
#define WR_CYAN_COLOR						"\033[0;36m"
#define WR_BRIGHT_CYAN_COLOR				"\033[1;36m"
#define WR_WHITE_COLOR						"\033[0;37m"
#define WR_BRIGHT_WHITE_COLOR				"\033[1;37m"

#define WR_BLACK_BACKGROUND_COLOR			"\033[0;40m"
#define WR_RED_BACKGROUND_COLOR				"\033[0;41m"
#define WR_BRIGHT_RED_BACKGROUND_COLOR		"\033[1;41m"
#define WR_GREEN_BACKGROUND_COLOR			"\033[0;42m"
#define WR_BRIGHT_GREEN_BACKGROUND_COLOR	"\033[1;42m"
#define WR_YELLOW_BACKGROUND_COLOR			"\033[0;43m"
#define WR_BRIGHT_YELLOW_BACKGROUND_COLOR	"\033[1;43m"
#define WR_BLUE_BACKGROUND_COLOR			"\033[0;44m"
#define WR_BRIGHT_BLUE_BACKGROUND_COLOR		"\033[1;44m"
#define WR_MAGENTA_BACKGROUND_COLOR			"\033[0;45m"
#define WR_BRIGHT_MAGENTA_BACKGROUND_COLOR	"\033[1;45m"
#define WR_CYAN_BACKGROUND_COLOR			"\033[0;46m"
#define WR_BRIGHT_CYAN_BACKGROUND_COLOR		"\033[1;46m"
#define WR_WHITE_BACKGROUND_COLOR			"\033[0;47m"
#define WR_BRIGHT_WHITE_BACKGROUND_COLOR	"\033[1;47m"

#define WR_TERMINATE_COLOR					"\033[0;0m"

#define WR_PREFIX_COLOR						WR_GREEN_COLOR
#define WR_INTERFACE_COLOR					WR_BLUE_BACKGROUND_COLOR
#define WR_NICK_COLOR						WR_BRIGHT_WHITE_COLOR
#define WR_STATUS_COLOR						WR_BRIGHT_WHITE_COLOR
#define WR_HIGHLIGHT_COLOR					WR_BRIGHT_YELLOW_COLOR
#define WR_SAY_COLOR						WR_BLUE_COLOR
#define WR_ME_COLOR							WR_BRIGHT_YELLOW_COLOR

#define WR_WINDOW_BUFFER_INITIAL_SIZE		10240


enum _wr_window_type {
	WR_WINDOW_TYPE_CHAT,
	WR_WINDOW_TYPE_USER
};
typedef enum _wr_window_type				wr_window_type_t;


enum _wr_window_status {
	WR_WINDOW_STATUS_IDLE					= 0,
	WR_WINDOW_STATUS_ACTION,
	WR_WINDOW_STATUS_CHAT,
	WR_WINDOW_STATUS_HIGHLIGHT
};
typedef enum _wr_window_status				wr_window_status_t;


typedef wi_uinteger_t						wr_wid_t;


typedef struct _wr_window					wr_window_t;


void										wr_windows_initialize(void);
void										wr_windows_clear(void);

void										wr_windows_set_timestamp_format(wi_string_t *);

void										wr_windows_add_window(wr_window_t *);
void										wr_windows_close_window(wr_window_t *);
wr_window_t *								wr_windows_window_with_chat(wr_chat_t *);
wr_window_t *								wr_windows_window_with_user(wr_user_t *);
void										wr_windows_show_next(void);
void										wr_windows_show_previous(void);
void										wr_windows_show_window(wr_window_t *);

wr_window_t *								wr_window_alloc(void);
wr_window_t *								wr_window_init(wr_window_t *);
wr_window_t *								wr_window_init_with_chat(wr_window_t *, wr_chat_t *);
wr_window_t *								wr_window_init_with_user(wr_window_t *, wr_user_t *);

wr_chat_t *									wr_window_chat(wr_window_t *);
wi_boolean_t								wr_window_is_chat(wr_window_t *);
wi_boolean_t								wr_window_is_public_chat(wr_window_t *);
wi_boolean_t								wr_window_is_private_chat(wr_window_t *);
wi_boolean_t								wr_window_is_user(wr_window_t *);
void										wr_window_update_status(wr_window_t *);

wr_user_t *									wr_window_user(wr_window_t *);

wi_terminal_buffer_t *						wr_window_buffer(wr_window_t *);

void										wr_window_set_topic(wr_window_t *, wr_topic_t *);
wr_topic_t *								wr_window_topic(wr_window_t *);

void										wr_printf(wi_string_t *, ...);
void										wr_wprintf(wr_window_t *window, wi_string_t *, ...);
void										wr_printf_prefix(wi_string_t *, ...);
void										wr_wprintf_prefix(wr_window_t *, wi_string_t *, ...);
void										wr_printf_block(wi_string_t *, ...);
void										wr_wprintf_block(wr_window_t *, wi_string_t *, ...);
void										wr_wprint(wr_window_t *window, wi_string_t *);
void										wr_wprint_say(wr_window_t *, wi_string_t *, wi_string_t *);
void										wr_wprint_me(wr_window_t *, wi_string_t *, wi_string_t *);
void										wr_wprint_msg(wr_window_t *, wi_string_t *, wi_string_t *);
void										wr_print_topic(void);
void										wr_print_users(wr_window_t *);
void										wr_print_user(wr_user_t *, wi_uinteger_t);

void										wr_draw_header(void);
void										wr_draw_divider(void);


extern wr_window_t							*wr_console_window;
extern wr_window_t							*wr_current_window;

#endif /* WR_WINDOWS_H */
