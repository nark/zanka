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

#ifndef WR_MAIN_H
#define WR_MAIN_H 1

#include <signal.h>

#define WR_WIRE_PATH					".wire"
#define WR_WIRE_CONFIG_PATH				".wire/config"

enum _wr_completer {
	WR_COMPLETER_NONE					= 0,
	WR_COMPLETER_COMMAND,
	WR_COMPLETER_NICKNAME,
	WR_COMPLETER_BOOKMARK,
	WR_COMPLETER_LOCAL_FILENAME,
	WR_COMPLETER_IGNORE
};
typedef enum _wr_completer				wr_completer_t;

typedef wi_boolean_t					wr_runloop_callback_func_t(wi_socket_t *);


char *									wr_readline_bookmark_generator(const char *, int);

wi_string_t *							wr_string_for_bytes(wi_file_offset_t);

void									wr_runloop_init(void);

void									wr_runloop_add_socket(wi_socket_t *, wr_runloop_callback_func_t *);
void									wr_runloop_remove_socket(wi_socket_t *);

void									wr_runloop_run(void);
void									wr_runloop_run_for_socket(wi_socket_t *, wi_time_interval_t, wi_uinteger_t);


extern volatile sig_atomic_t			wr_running;

extern wi_boolean_t						wr_debug;
extern wi_date_t						*wr_start_date;

#endif /* WR_MAIN_H */
