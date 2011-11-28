/* $Id$ */

/*
 *  Copyright (c) 2004 Axel Andersson
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

#include <sys/types.h>
#include <stdio.h>
#include <stdbool.h>
#include <signal.h>

#include "client.h"
#include "utility.h"


enum wr_completer {
	WR_COMPLETER_NONE				= 0,
	WR_COMPLETER_COMMAND,
	WR_COMPLETER_NICKNAME,
	WR_COMPLETER_BOOKMARK,
	WR_COMPLETER_FILENAME,
	WR_COMPLETER_DIRECTORY,
	WR_COMPLETER_LOCAL_FILENAME,
	WR_COMPLETER_IGNORE
};
typedef enum wr_completer			wr_completer_t;


#define WR_VERSION_STRING_SIZE		128

#define WR_TERM_BUFFER_SIZE			10240


void								wr_usage(void);
void								wr_version(void);

void								wr_sig_winch(int);
void								wr_sig_int(int);

void								wr_init_term(void);
void								wr_dealloc_term(void);
void								wr_term_flush (void);
int									wr_term_putc(int);
void								wr_term_puts(char *, size_t);
void								wr_term_cm(int, int);
void								wr_term_ce(void);
void								wr_term_cl(void);
void								wr_term_cs(int, int);
void								wr_term_clear(void);
char *								wr_term_buffer_get_line(int);
int									wr_term_buffer_count_lines(char *, size_t);
void								wr_term_buffer_draw_line(char *, size_t);

void								wr_init_readline(void);
void								wr_dealloc_readline(void);
void								wr_rl_callback(char *);
int									wr_rl_redraw(int, int);
void								wr_rl_pageup(void);
void								wr_rl_pagedown(void);
void								wr_rl_home(void);
void								wr_rl_end(void);
char **								wr_rl_completion_function(const char *, int, int);
void								wr_rl_completion_display_matches(char **, int, int);
char *								wr_rl_filename_quoting_function(char *, int, char *);
char *								wr_rl_filename_dequoting_function(char *, int);

char *								wr_rl_bookmark_generator(const char *, int);

void								wr_loop(bool, int, double);

void								wr_printf(char *fmt, ...);
void								wr_printf_block(char *fmt, ...);
void								wr_printf_prefix(char *fmt, ...);

void								wr_print_say(char *, char *);
void								wr_print_me(char *, char *);
void								wr_print_user(wr_user_t *, unsigned int);
void								wr_print_file(wr_file_t *, unsigned int);

void								wr_draw_header(void);
void								wr_draw_transfers(void);
void								wr_draw_divider(void);


extern volatile sig_atomic_t		wr_running;
extern volatile sig_atomic_t		wr_signal;

extern char							wr_version_string[WR_VERSION_STRING_SIZE];
extern bool							wr_debug;
extern time_t						wr_start_time;

extern iconv_t						wr_conv_from;
extern iconv_t						wr_conv_to;

extern char							wr_termcap[2048];
extern char							wr_termcap_buffer[512];

extern char							*wr_term_buffer;
extern int							wr_term_buffer_size;
extern int							wr_term_buffer_offset;

extern char							wr_term_flush_buffer[32];
extern int							wr_term_flush_offset;
extern int							wr_term_last_co;

extern int							CO, LI;
extern char							*CE, *CL, *CM, *CS;

#endif /* WR_MAIN_H */
