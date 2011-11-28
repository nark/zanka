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

#include "config.h"

#include <stdio.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "ignores.h"
#include "main.h"
#include "terminal.h"
#include "transfers.h"
#include "windows.h"

static void							wr_readline_callback(char *);
static int							wr_readline_char_is_quoted(char *, int);
static int							wr_readline_redraw(int, int);
static int							wr_readline_next(int, int);
static int							wr_readline_previous(int, int);
static void							wr_readline_pageup(void);
static void							wr_readline_pagedown(void);
static void							wr_readline_home(void);
static void							wr_readline_end(void);
static char **						wr_readline_completion_function(const char *, int, int);
#if HAVE_DECL_RL_COMPLETION_DISPLAY_MATCHES_HOOK
static void							wr_readline_completion_display_matches(char **, int, int);
#endif
static char *						wr_readline_filename_quoting_function(char *, int, char *);
static char *						wr_readline_filename_dequoting_function(char *, int);


wi_terminal_t						*wr_terminal;


void wr_terminal_init(void) {
	wi_size_t		size;
	
	wr_terminal = wi_terminal_init(wi_terminal_alloc());
	size = wi_terminal_size(wr_terminal);
	
	wi_terminal_set_scroll(wr_terminal, wi_make_range(1, wi_terminal_size(wr_terminal).height - 3));
	wi_terminal_clear_screen(wr_terminal);
}



void wr_terminal_close(void) {
	wi_terminal_close(wr_terminal);
}



#pragma mark -

void wr_terminal_resize(void) {
	wi_size_t		size;

	size = wi_terminal_lookup_size(wr_terminal);

	if(size.width == 0 || size.height == 0)
		return;

	wi_terminal_set_size(wr_terminal, size);
	wi_terminal_set_scroll(wr_terminal, wi_make_range(1 + wi_array_count(wr_transfers), size.height - 3));
	
	wi_terminal_clear_screen(wr_terminal);
	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
	wi_terminal_buffer_redraw(wr_current_window->buffer);
}



void wr_terminal_redraw(void) {
	wi_terminal_clear_screen(wr_terminal);
	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
	wi_terminal_buffer_redraw(wr_current_window->buffer);
}



void wr_terminal_clear(void) {
	wi_terminal_clear_screen(wr_terminal);
	wi_terminal_buffer_clear(wr_current_window->buffer);
	
	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);

	wi_terminal_move(wr_terminal, wi_make_point(0, wi_terminal_size(wr_terminal).height - 1));

	rl_on_new_line();
	rl_redisplay();
}



void wr_terminal_reset_location(void) {
	wi_size_t		size;
	
	size = wi_terminal_size(wr_terminal);

	wi_terminal_move(wr_terminal, wi_make_point(rl_point % size.width, size.height - 1));
}



#pragma mark -

void wr_readline_init(void) {
	rl_initialize();
	using_history();

	rl_readline_name = "wire";

	rl_completer_quote_characters = "'\"";
	rl_filename_quote_characters = " \t\\\"'";
	rl_char_is_quoted_p = wr_readline_char_is_quoted;

	rl_attempted_completion_function = wr_readline_completion_function;
#if HAVE_DECL_RL_COMPLETION_DISPLAY_MATCHES_HOOK
	rl_completion_display_matches_hook = wr_readline_completion_display_matches;
#endif
	rl_filename_quoting_function = wr_readline_filename_quoting_function;
	rl_filename_dequoting_function = wr_readline_filename_dequoting_function;

	rl_callback_handler_install(NULL, wr_readline_callback);

	rl_bind_key(0x0C, wr_readline_redraw);
	rl_bind_key(0x0E, wr_readline_next);
	rl_bind_key(0x10, wr_readline_previous);

	rl_generic_bind(ISFUNC, "\033[5~", (char *) wr_readline_pageup, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[6~", (char *) wr_readline_pagedown, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[1~", (char *) wr_readline_home, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[4~", (char *) wr_readline_end, rl_get_keymap());
}



void wr_readline_close(void) {
	rl_callback_handler_remove();
}



#pragma mark -

void wr_readline_read(void) {
	rl_callback_read_char();
}



#pragma mark -

static void wr_readline_callback(char *line) {
	if(line && strlen(line) > 0) {
		add_history(line);

		wr_parse_command(wi_string_with_cstring(line), true);

		rl_point = 0;
		rl_end = 0;
		
		wi_terminal_move(wr_terminal, wi_make_point(0, wi_terminal_size(wr_terminal).height - 1));
		wi_terminal_clear_line(wr_terminal);
	}
}



static int wr_readline_char_is_quoted(char *text, int index) {
	int		i;

	for(i = 0; i <= index; i++) {
		if(text[i] == '\\') {
			i++;

			if(i >= index)
				return 1;
		}
	}

	return 0;
}



static int wr_readline_redraw(int start, int end) {
	wi_terminal_clear_screen(wr_terminal);
	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
	wi_terminal_buffer_redraw(wr_current_window->buffer);
	
	return 0;
}



static int wr_readline_next(int start, int end) {
	wr_windows_show_next();

	return 0;
}



static int wr_readline_previous(int start, int end) {
	wr_windows_show_previous();

	return 0;
}



static void wr_readline_pageup(void) {
	wi_terminal_clear_screen(wr_terminal);
	wi_terminal_buffer_pageup(wr_current_window->buffer);

	wr_window_update_status(wr_current_window);

	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
}



static void wr_readline_pagedown(void) {
	wi_terminal_clear_screen(wr_terminal);
	wi_terminal_buffer_pagedown(wr_current_window->buffer);
	
	wr_window_update_status(wr_current_window);

	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
}



static void wr_readline_home(void) {
	wi_terminal_clear_screen(wr_terminal);
	wi_terminal_buffer_home(wr_current_window->buffer);

	wr_window_update_status(wr_current_window);

	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
}



static void wr_readline_end(void) {
	wi_terminal_clear_screen(wr_terminal);
	wi_terminal_buffer_end(wr_current_window->buffer);

	wr_window_update_status(wr_current_window);

	wr_draw_header();
	wr_draw_divider();
	wr_draw_transfers(true);
}



static char ** wr_readline_completion_function(const char *text, int start, int end) {
	char			**matches = NULL;
#ifdef HAVE_RL_COMPLETION_MATCHES
	wr_completer_t	completer;
#endif
	wi_uinteger_t	i;
	wi_boolean_t	add;
	
#ifdef HAVE_RL_COMPLETION_MATCHES
	completer = wr_command_completer(wi_string_with_cstring(rl_line_buffer));

	switch(completer) {
		case WR_COMPLETER_COMMAND:
			rl_filename_completion_desired = 0;
			rl_filename_quoting_desired = 0;
			rl_completion_append_character = ' ';

			matches = rl_completion_matches(text, wr_readline_command_generator);
			break;

		case WR_COMPLETER_NICKNAME:
			if(rl_line_buffer[0] == '/' || start != 0) {
				rl_filename_completion_desired = 1;
				rl_filename_quoting_desired = 1;
				rl_completion_append_character = ' ';
			} else {
				rl_filename_completion_desired = 0;
				rl_filename_quoting_desired = 0;
				rl_completion_append_character = ':';
			}

			matches = rl_completion_matches(text, wr_readline_nickname_generator);
			break;

		case WR_COMPLETER_FILENAME:
			if(wr_connected) {
				rl_filename_completion_desired = 1;
				rl_filename_quoting_desired = 1;
				rl_completion_append_character = '\0';

				wr_ls_state = WR_LS_COMPLETING;

				matches = rl_completion_matches(text, wr_readline_filename_generator);
			}
			break;

		case WR_COMPLETER_LOCAL_FILENAME:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = '\0';

			matches = rl_completion_matches(text, rl_filename_completion_function);
			break;

		case WR_COMPLETER_DIRECTORY:
			if(wr_connected) {
				rl_filename_completion_desired = 1;
				rl_filename_quoting_desired = 1;
				rl_completion_append_character = '/';

				wr_ls_state = WR_LS_COMPLETING_DIRECTORY;

				matches = rl_completion_matches(text, wr_readline_filename_generator);
			}
			break;

		case WR_COMPLETER_BOOKMARK:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = ' ';

			matches = rl_completion_matches(text, wr_readline_bookmark_generator);
			break;

		case WR_COMPLETER_IGNORE:
			rl_completion_append_character = ' ';

			matches = rl_completion_matches(text, wr_readline_ignore_generator);
			break;

		case WR_COMPLETER_NONE:
			break;
	}
#endif

	if(matches && text[0] != '/' && start == 0) {
		add = true;
		i = 0;
		
		while(matches[i + 1]) {
			if(strlen(matches[i]) != strlen(matches[i + 1])) {
				add = false;

				break;
			}

			i++;
		}

		if(add)
			rl_pending_input = ' ';
	}

	rl_attempted_completion_over = 1;

	return matches;
}



#if HAVE_DECL_RL_COMPLETION_DISPLAY_MATCHES_HOOK
static void wr_readline_completion_display_matches(char **matches, int num_matches, int max_length) {
	wi_string_t		*string;
	wi_size_t		size;
	int				i;

	wr_printf_prefix(WI_STR("Possible matches:"));
	
	size = wi_terminal_size(wr_terminal);
	string = NULL;
	
	for(i = 1; i <= num_matches; i++) {
		if(!string)
			string = wi_string_init(wi_string_alloc());

		wi_string_append_format(string, WI_STR("   %s%*s"),
			matches[i],
			max_length - strlen(matches[i]) + 1,
			" ");

		if(wi_terminal_width_of_string(wr_terminal, string) >=
		   size.width - max_length - max_length) {
			wr_printf(WI_STR("%@"), string);
			
			wi_release(string);
			string = NULL;
		}
	}
	
	if(string) {
		wr_printf(WI_STR("%@"), string);
		
		wi_release(string);
	}
}
#endif



static char * wr_readline_filename_quoting_function(char *text, int match_type, char *quote_pointer) {
	char	*value;
	int		i, bytes;

	bytes = (strlen(text) * 2) + 1;
	value = wi_malloc(bytes);

	for(i = 0; *text && i < bytes; i++) {
		if(isspace(*text))
			value[i++] = '\\';

		value[i] = *text++;
	}

	value[i] = '\0';

	return value;
}



static char * wr_readline_filename_dequoting_function(char *text, int quote_char) {
	char	*value;
	int		i, bytes;

	bytes = strlen(text) + 1;
	value = wi_malloc(bytes);

	for(i = 0; *text && i < bytes; i++) {
		if(*text == '\\')
			text++;

		value[i] = *text++;
	}

	value[i] = '\0';

	return value;
}
