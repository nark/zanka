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

#ifndef WR_WINDOWS_H
#define WR_WINDOWS_H 1

#include "files.h"
#include "users.h"

#define WR_PREFIX						"[wire] "

#define WR_PREFIX_COLOR					"\033[32m"
#define WR_INTERFACE_COLOR				"\033[44m"
#define WR_NICK_COLOR					"\033[1;37m"
#define WR_STATUS_COLOR					"\033[1;37m"
#define WR_HIGHLIGHT_COLOR				"\033[1;33m"
#define WR_SAY_COLOR					"\033[34m"
#define WR_ME_COLOR						"\033[1;33m"

#define WR_ADMIN_COLOR					"\033[1;31m"
#define WR_ADMIN_IDLE_COLOR				"\033[31m"
#define WR_USER_COLOR					"\033[1;37m"
#define WR_USER_IDLE_COLOR				"\033[37m"

#define WR_UPLOADS_COLOR				"\033[1;32m"
#define WR_DROPBOX_COLOR				"\033[1;31m"
#define WR_DIRECTORY_COLOR				"\033[1;34m"
#define WR_FILE_COLOR					"\033[0m"

#define WR_END_COLOR					"\033[0m"

#define WR_PUBLIC_CID					1

#define WR_WINDOW_BUFFER_INITIAL_SIZE	10240


enum _wr_window_type {
	WR_WINDOW_TYPE_CHAT,
	WR_WINDOW_TYPE_USER
};
typedef enum _wr_window_type			wr_window_type_t;


enum _wr_window_status {
	WR_WINDOW_STATUS_IDLE				= 0,
	WR_WINDOW_STATUS_ACTION,
	WR_WINDOW_STATUS_CHAT,
	WR_WINDOW_STATUS_HIGHLIGHT
};
typedef enum _wr_window_status			wr_window_status_t;


typedef uint32_t						wr_cid_t;


struct _wr_topic {
	wi_string_t							*nick;
	wi_string_t							*date;
	wi_string_t							*topic;
};
typedef struct _wr_topic				wr_topic_t;


typedef uint32_t						wr_wid_t;


struct _wr_window {
	wi_runtime_base_t					base;
	
	wr_wid_t							wid;
	wr_window_type_t					type;
	wr_window_status_t					status;
	
	wr_uid_t							uid;
	wr_cid_t							cid;
	
	wr_topic_t							topic;
	
	wi_terminal_buffer_t				*buffer;
};
typedef struct _wr_window				wr_window_t;


void									wr_init_windows(void);
void									wr_clear_windows(void);

wr_window_t *							wr_window_alloc(void);
wr_window_t *							wr_window_init(wr_window_t *);
wr_window_t *							wr_window_init_with_chat(wr_window_t *, wr_cid_t);
wr_window_t *							wr_window_init_with_user(wr_window_t *, wr_user_t *);

void									wr_windows_add_window(wr_window_t *);
void									wr_windows_close_window(wr_window_t *);
void									wr_windows_show_next(void);
void									wr_windows_show_previous(void);
void									wr_windows_show_window(wr_window_t *);

wr_window_t *							wr_window_with_chat(wr_cid_t);
wr_window_t *							wr_window_with_user(wr_user_t *);

void									wr_printf(wi_string_t *, ...);
void									wr_wprintf(wr_window_t *window, wi_string_t *, ...);
void									wr_printf_prefix(wi_string_t *, ...);
void									wr_wprintf_prefix(wr_window_t *, wi_string_t *, ...);
void									wr_printf_block(wi_string_t *, ...);
void									wr_wprintf_block(wr_window_t *, wi_string_t *, ...);
void									wr_wprint(wr_window_t *window, wi_string_t *);
void									wr_wprint_say(wr_window_t *, wi_string_t *, wi_string_t *);
void									wr_wprint_me(wr_window_t *, wi_string_t *, wi_string_t *);
void									wr_wprint_msg(wr_window_t *, wi_string_t *, wi_string_t *);
void									wr_print_server_info(void);
void									wr_print_topic(void);
void									wr_print_users(void);
void									wr_print_user(wr_user_t *, unsigned int);
void									wr_print_file(wr_file_t *, wi_boolean_t, unsigned int);

void									wr_draw_header(void);
void									wr_draw_transfers(wi_boolean_t);
void									wr_draw_divider(void);


extern wr_window_t						*wr_console_window;
extern wr_window_t						*wr_current_window;

extern wi_list_t						*wr_windows;

#endif /* WR_WINDOWS_H */
