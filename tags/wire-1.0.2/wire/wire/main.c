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

#include "config.h"

#include <sys/types.h>
#include <sys/utsname.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <dirent.h>
#include <libgen.h>

#ifdef HAVE_TERMCAP_H
#include <termcap.h>
#endif

#ifdef HAVE_TERMIOS_H
#include <termios.h>
#endif

#include <readline/readline.h>
#include <readline/history.h>
#include <openssl/err.h>
#include <iconv.h>

#include "client.h"
#include "commands.h"
#include "main.h"
#include "utility.h"


volatile sig_atomic_t				wr_running = 1;
volatile sig_atomic_t				wr_signal;

char								wr_version_string[WR_VERSION_STRING_SIZE];
bool								wr_debug;
time_t								wr_start_time;

iconv_t								wr_conv_from;
iconv_t								wr_conv_to;

char								wr_termcap[2048];
char								wr_termcap_buffer[512];

char								*wr_term_buffer;
int									wr_term_buffer_size;
int									wr_term_buffer_offset;

char								wr_term_flush_buffer[32];
int									wr_term_flush_offset;

int									wr_term_lines;
int									wr_term_last_co;
int									wr_term_current_li;

int									CO, LI;
char								*CE, *CL, *CM, *CS;


int main(int argc, char *argv[]) {
	FILE			*fp;
	struct utsname	name;
	char			path[MAXPATHLEN], charset[64], charset_from[64];
	int				ch;
	
	/* default charset */
	strlcpy(charset, "ISO-8859-1", sizeof(charset));

	/* parse command line switches */
	while((ch = getopt(argc, argv, "Dc:hVv")) != -1) {
		switch(ch) {
			case 'D':
				wr_debug = true;
				break;
			
			case 'c':
				strlcpy(charset, optarg, sizeof(charset));
				snprintf(charset, sizeof(charset), "%s//IGNORE//TRANSLIT", optarg);
				break;
			
			case 'V':
			case 'v':
				wr_version();
				break;

			case '?':
			case 'h':
			default:
				wr_usage();
				break;
		}
	}

	argc -= optind;
	argv += optind;
	
	/* do not print errors about getopt() */
	opterr = 0;
	
	/* create version string */
	uname(&name);

	snprintf(wr_version_string, sizeof(wr_version_string),
		"Wire/%s (%s; %s; %s) (%s; readline %s)",
		WR_PACKAGE_VERSION,
		name.sysname,
		name.release,
		WR_CPU,
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);
	
	/* init signals */
	signal(SIGPIPE, SIG_IGN);
	signal(SIGWINCH, wr_sig_winch);
	signal(SIGINT, wr_sig_int);
	signal(SIGTERM, wr_sig_int);
	signal(SIGQUIT, wr_sig_int);

	/* create ~/.wire */
	snprintf(path, sizeof(path), "%s/.wire", getenv("HOME"));
	mkdir(path, 0755);
	
	/* init boot time */
	wr_start_time = time(NULL);

	/* init lists */
	wr_list_create(&wr_users);
	wr_list_create(&wr_transfers);

	/* init settings */
	strlcpy(wr_nick, getenv("USER"), sizeof(wr_nick));
	wr_icon = 500;
	
	/* init terminal */
	wr_init_readline();
	wr_init_term();

	/* init OpenSSL */
	wr_init_ssl();

	/* set charset to */
	snprintf(charset_from, sizeof(charset_from), "%s//IGNORE//TRANSLIT", charset);

	/* init iconv */
	wr_conv_from = iconv_open(charset_from, "UTF-8");
	wr_conv_to = iconv_open("UTF-8//IGNORE//TRANSLIT", charset);

	if(wr_conv_from == (iconv_t) -1) {
		wr_printf_prefix("Could not open iconv: %s: %s\n",
			charset, strerror(errno));
	}

	if(wr_conv_to == (iconv_t) -1) {
		wr_printf_prefix("Could not open iconv: %s: %s\n",
			"UTF-8", strerror(errno));
	}

	/* open default settings */
	snprintf(path, sizeof(path), "%s/.wire/config", getenv("HOME"));
	fp = fopen(path, "r");
	
	if(!fp) {
		wr_printf_prefix("%s: %s\n", path, strerror(errno));
	} else {
		wr_parse_file(fp);

		fclose(fp);
	}
	
	/* read specified bookmark */
	if(*argv) {
		snprintf(path, sizeof(path), "%s/.wire/%s", getenv("HOME"), *argv);
		fp = fopen(path, "r");
		
		if(!fp) {
			wr_printf_prefix("%s: %s\n", path, strerror(errno));
		} else {
			wr_parse_file(fp);

			fclose(fp);
		}
	}
	
	/* enter event loop */
	wr_loop(true, 0, 0.0);
	
	/* clean up */
	wr_dealloc_readline();
	wr_dealloc_term();
	
	return 0;
}



void wr_usage(void) {
	fprintf(stderr,
"Usage: wire [-Dhv] [-c charset] bookmark\n\
\n\
Options:\n\
    -D             enable debug mode\n\
    -c charset     set character set\n\
    -h             display this message\n\
    -v             display version information\n\
\n\
If specified, ~/.wire/<bookmark> is loaded on startup.\n\
\n\
By Axel Andersson <%s>\n", WR_BUGREPORT);
	
	exit(2);
}



void wr_version(void) {
	fprintf(stderr, "Wire %s, protocol %s, %s, readline %s\n",
		WR_PACKAGE_VERSION,
		WR_PROTOCOL_VERSION,
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);

	exit(2);
}



#pragma mark -

void wr_sig_winch(int sigraised) {
	struct winsize		win;
	
	if(ioctl(STDOUT_FILENO, TIOCGWINSZ, &win) < 0)
		return;
		
	LI = win.ws_row;
	CO = win.ws_col;
	
	wr_term_lines = LI - 3;
	wr_term_cs(LI - 3, 1 + WR_LIST_COUNT(wr_transfers));

	wr_rl_redraw(0, 0);
}



void wr_sig_int(int sigraised) {
	/* mark exit */
	wr_running = 0;
}



#pragma mark -

void wr_init_term(void) {
	char	*env, *term, *bp;
	int		t;
	
	/* init buffer */
	wr_term_buffer_size = WR_TERM_BUFFER_SIZE;
	wr_term_buffer = (char *) malloc(wr_term_buffer_size);
	wr_term_buffer_offset = 0;

	/* get terminal */
	bp = wr_termcap_buffer;
	env = getenv("TERM");
	term = env ? env : "vt100";
	t = tgetent(wr_termcap, term);
	
	if(t == -1) {
		fprintf(stderr, "Could not access the termcap database\n");
		exit(1);
	}
	else if(t == 0) {
		fprintf(stderr, "Could not find a termcap entry for '%s'\n", term);
		exit(1);
	}
	
	/* get number of columns */
	env = getenv("COLUMNS");
	
	if(env)
		CO = strtol(env, NULL, 10);
	else
		CO = tgetnum("co");
		
	if(CO <= 0)
		CO = 80;

	/* get number of rows */
	env = getenv("LINES");
	
	if(env)
		LI = strtol(env, NULL, 10);
	else
		LI = tgetnum("li");
		
	if(LI <= 0)
		LI = 24;

	/* get terminal capabilities we use */
	CE = tgetstr("ce", &bp);
	CL = tgetstr("cl", &bp);
	CM = tgetstr("cm", &bp);
	CS = tgetstr("cs", &bp);
	
	/* set number of lines available to output */
	wr_term_lines = LI - 3;
	
	/* clear screen */
	wr_term_cs(LI - 3, 1);
	wr_term_cl();
	
	/* draw interface */
	wr_draw_header();
	wr_draw_divider();
}



void wr_dealloc_term(void) {
	wr_term_cs(-1, -1);
	wr_term_cm(0, LI - 1);
	
	write(STDOUT_FILENO, "\r", 1);
}



void wr_term_flush(void) {
	write(STDOUT_FILENO, wr_term_flush_buffer, wr_term_flush_offset);
	wr_term_flush_offset = 0;
}



int wr_term_putc(int ch) {
	if(wr_term_flush_offset == sizeof(wr_term_flush_buffer))
		wr_term_flush();

	wr_term_flush_buffer[wr_term_flush_offset] = (char) ch;
	wr_term_flush_offset++;

	return ch;
}



void wr_term_puts(char *buffer, size_t length) {
	wr_term_cm(wr_term_last_co, LI - 3);
	
	if(wr_term_last_co == 0)
		wr_term_putc('\n');
	
	wr_term_flush();
	
	if(buffer[length - 1] != '\n') {
		wr_term_last_co += length;
	} else {
		wr_term_last_co = 0;
		length--;
	}
	
	write(STDOUT_FILENO, buffer, length);
	
	wr_term_cm(rl_point % CO, LI - 1);
}



void wr_term_cm(int col, int row) {
	tputs(tgoto(CM, col, row), 0, wr_term_putc);
	wr_term_flush();
}



void wr_term_cl(void) {
	tputs(CL, 0, wr_term_putc);
	wr_term_flush();
}



void wr_term_ce(void) {
	tputs(CE, 0, wr_term_putc);
	wr_term_flush();
}



void wr_term_cs(int col, int row) {
	tputs(tgoto(CS, col, row), 0, wr_term_putc);
	wr_term_flush();
}



void wr_term_clear(void) {
	wr_term_cl();
	
	wr_term_current_li = 0;

	wr_term_buffer_offset = 0;
	memset(wr_term_buffer, 0, wr_term_buffer_size);

	wr_draw_header();
	wr_draw_divider();

	wr_term_cm(0, LI - 1);

	rl_on_new_line();
	rl_redisplay();
}



char * wr_term_buffer_get_line(int line) {
	char	*p;
	int		i = 0;
	
	if(!line)
		return wr_term_buffer;
	
	for(p = wr_term_buffer; p < wr_term_buffer + wr_term_buffer_offset; p++) {
		if(*p == '\n') {
			i++;
			
			if(i == line) {
				return p + 1 >= wr_term_buffer + wr_term_buffer_offset
					? NULL
					: p + 1;
			}
		}
	}
	
	if(i == line - 1)
		return p;
	
	return NULL;
}



int wr_term_buffer_count_lines(char *buffer, size_t length) {
	char	*p;
	int		i = 0;
	
	for(p = buffer; p < buffer + length; p++) {
		if(*p == '\n')
			i++;
	}
	
	return i;
}



void wr_term_buffer_draw_line(char *line, size_t length) {
	wr_term_cl();

	wr_draw_header();
	wr_draw_transfers();
	wr_draw_divider();

	wr_term_cm(0, 1 + WR_LIST_COUNT(wr_transfers));
	write(STDOUT_FILENO, line, length);
	wr_term_cm(0, LI - 1);
	
	rl_on_new_line();
	rl_redisplay();
}




#pragma mark -

void wr_init_readline(void) {
	rl_initialize();
	using_history();
	
	rl_readline_name = "wire";
	
	rl_completer_quote_characters = rl_basic_quote_characters;
	rl_filename_quote_characters = " ";
	
	rl_attempted_completion_function = wr_rl_completion_function;
	rl_completion_display_matches_hook = wr_rl_completion_display_matches;
	rl_filename_quoting_function = wr_rl_filename_quoting_function;
	rl_filename_dequoting_function = wr_rl_filename_dequoting_function;
	
	rl_callback_handler_install(NULL, wr_rl_callback);
	
	rl_bind_key(0xC, wr_rl_redraw);
	rl_generic_bind(ISFUNC, "\033[5~", (char *) wr_rl_pageup, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[6~", (char *) wr_rl_pagedown, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[1~", (char *) wr_rl_home, rl_get_keymap());
	rl_generic_bind(ISFUNC, "\033[4~", (char *) wr_rl_end, rl_get_keymap());
}



void wr_dealloc_readline(void) {
	rl_callback_handler_remove();
}



void wr_rl_callback(char *line) {
	if(line && strlen(line) > 0) {
		/* save in history */
		add_history(line);
		
		/* go go command */
		wr_parse_command(line, true);

		/* go back */
		rl_point = 0;
		rl_end = 0;
		wr_term_cm(rl_point % CO, LI - 1);
		wr_term_ce();
	}
}



int wr_rl_redraw(int start, int end) {
	char	*line_first, *line_last;
	int		lines;
	
	lines = wr_term_buffer_count_lines(wr_term_buffer, wr_term_buffer_offset);

	if(lines < wr_term_lines)
		line_first = wr_term_buffer_get_line(0);
	else
		line_first = wr_term_buffer_get_line(lines - wr_term_lines);

	line_last = wr_term_buffer + wr_term_buffer_offset;
	
	if(!line_first || !line_last)
		return 0;
	
	wr_term_buffer_draw_line(line_first, (line_last - 1) - line_first);

	return 0;
}



void wr_rl_pageup(void) {
	char	*line_first, *line_last;
	int		line;
	
	line = wr_term_current_li > 2 * wr_term_lines
		? wr_term_current_li - (2 * wr_term_lines)
		: 0;
	
	line_first = wr_term_buffer_get_line(line);
	line_last = wr_term_buffer_get_line(line + wr_term_lines);
	
	if(!line_first || !line_last)
		return;
	
	wr_term_current_li = line + wr_term_lines;
	wr_term_buffer_draw_line(line_first, (line_last - 1) - line_first);
}



void wr_rl_pagedown(void) {
	char	*line_first, *line_last;
	int		lines;
	
	lines = wr_term_buffer_count_lines(wr_term_buffer, wr_term_buffer_offset);

	if(wr_term_current_li + wr_term_lines > lines - 1) {
		line_first = wr_term_buffer_get_line(lines - wr_term_lines);
		line_last = wr_term_buffer + wr_term_buffer_offset;
	} else {
		line_first = wr_term_buffer_get_line(wr_term_current_li);
		line_last = wr_term_buffer_get_line(wr_term_current_li + wr_term_lines);
	}
	
	if(!line_first || !line_last)
		return;
	
	if(wr_term_current_li + wr_term_lines > lines)
		wr_term_current_li = lines;
	else
		wr_term_current_li += wr_term_lines;
	
	wr_term_buffer_draw_line(line_first, (line_last - 1) - line_first);
}



void wr_rl_home(void) {
	char	*line_first, *line_last;
	
	line_first = wr_term_buffer_get_line(0);
	line_last = wr_term_buffer_get_line(wr_term_lines);
	
	if(!line_first || !line_last)
		return;
	
	wr_term_current_li = wr_term_lines;
	wr_term_buffer_draw_line(line_first, (line_last - 1) - line_first);
}



void wr_rl_end(void) {
	char	*line_first, *line_last;
	int		lines;
	
	lines = wr_term_buffer_count_lines(wr_term_buffer, wr_term_buffer_offset);
	line_first = wr_term_buffer_get_line(lines - wr_term_lines);
	line_last = wr_term_buffer + wr_term_buffer_offset;
	
	if(!line_first || !line_last)
		return;
	
	wr_term_current_li = lines;
	wr_term_buffer_draw_line(line_first, (line_last - 1) - line_first);
}



char ** wr_rl_completion_function(const char *text, int start, int end) {
	char			**matches = NULL;
	wr_completer_t	completer;
	int				i = 0;
	bool			add = true;

#ifdef HAVE_RL_COMPLETION_MATCHES
	completer = wr_command_completer(rl_line_buffer);
	
	switch(completer) {
		case WR_COMPLETER_COMMAND:
			rl_filename_completion_desired = 0;
			rl_filename_quoting_desired = 0;
			rl_completion_append_character = ' ';
	
			matches = rl_completion_matches(text, wr_rl_command_generator);
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
	
			matches = rl_completion_matches(text, wr_rl_nickname_generator);
			break;
		
		case WR_COMPLETER_FILENAME:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = '\0';
			
			wr_ls_state = WR_LS_COMPLETING;

			matches = rl_completion_matches(text, wr_rl_filename_generator);
			break;
		
		case WR_COMPLETER_LOCAL_FILENAME:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = '\0';

			matches = rl_completion_matches(text, rl_filename_completion_function);
			break;
		
		case WR_COMPLETER_DIRECTORY:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = '/';

			wr_ls_state = WR_LS_COMPLETING_DIRECTORY;

			matches = rl_completion_matches(text, wr_rl_filename_generator);
			break;
		
		case WR_COMPLETER_BOOKMARK:
			rl_filename_completion_desired = 1;
			rl_filename_quoting_desired = 1;
			rl_completion_append_character = ' ';
	
			matches = rl_completion_matches(text, wr_rl_bookmark_generator);
			break;
		
		case WR_COMPLETER_IGNORE:
			rl_completion_append_character = ' ';
	
			matches = rl_completion_matches(text, wr_rl_ignore_generator);
			break;
		
		default:
			break;
	}
#endif
	
	if(matches && text[0] != '/' && start == 0) {
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



void wr_rl_completion_display_matches(char **matches, int num_matches, int max_length) {
	int		i, x;
	
	wr_printf_prefix("Possible matches:\n");
	
	for(i = 1, x = 0; i <= num_matches; i++) {
		wr_printf("   %s%*s",
			matches[i],
			max_length - strlen(matches[i]) + 1,
			" ");
		
		x += max_length + 3;

		if(x >= CO - max_length - max_length) {
			x = 0;

			wr_printf("\n");
		}
	}

	if(x != 0)
		wr_printf("\n");
}



char * wr_rl_filename_quoting_function(char *text, int match_type, char *quote_pointer) {
	char	*value;
	int		i, bytes;
	
	bytes = (strlen(text) * 2) + 1;
	value = (char *) malloc(bytes);
	
	for(i = 0; *text && i < bytes; i++) {
		if(isspace(*text))
			value[i++] = '\\';

		value[i] = *text++;
	}
	
	value[i] = '\0';
	
	return value;
}



char * wr_rl_filename_dequoting_function(char *text, int quote_char) {
	char	*value;
	int		i, bytes;
	
	bytes = strlen(text) + 1;
	value = (char *) malloc(bytes);
	
	for(i = 0; *text && i < bytes; i++) {
		if(*text == '\\')
			text++;

		value[i] = *text++;
	}
	
	value[i] = '\0';
	
	return value;
}



#pragma mark -

char * wr_rl_bookmark_generator(const char *text, int state) {
	static int				length;
	static wr_list_t		bookmarks;
	static wr_list_node_t	*node;
	DIR						*dir;
	struct dirent			*dp;
	char					*name;
	char					path[MAXPATHLEN];
	
	if(!state) {
		/* re-create list */
		wr_list_free(&bookmarks);
		wr_list_create(&bookmarks);

		/* save length */
		length = strlen(text);
		
		/* open directory */
		snprintf(path, sizeof(path), "%s/.wire/", getenv("HOME"));
		dir = opendir(path);
		
		if(dir) {
			/* add directory entries to list */
			while((dp = readdir(dir))) {
				if(dp->d_name[0] != '.' && strcmp(dp->d_name, "config") != 0)
					wr_list_add(&bookmarks, strdup(dp->d_name));
			}
		}
		
		closedir(dir);

		node = WR_LIST_FIRST(bookmarks);
	}
	
	/* loop over bookmarks and find a match */
	for(; node != NULL; ) {
		name = WR_LIST_DATA(node);
		node = WR_LIST_NEXT(node);
		
		if(strncmp(text, name, length) == 0)
			return strdup(name);
	}
	
	return NULL;
}



#pragma mark -

void wr_loop(bool input, int value, double timeout) {
	wr_list_node_t	*node;
	wr_transfer_t	*transfer;
	struct timeval	tv, now, timeout_tv, redraw_tv;
	fd_set			rfds, wfds;
	char			*buffer, transfer_buffer[1024];
	double			redraw = 0.0;
	unsigned int	buffer_size, buffer_offset;
	int				bytes, pending, state, message, fd, max_fd;

	/* init buffer */
	buffer_size = WR_BUFFER_SIZE;
	buffer = (char *) malloc(buffer_size);
	buffer_offset = 0;

	/* get time */
	gettimeofday(&now, NULL);
	timeout_tv = redraw_tv = now;

	/* enter loop */
	while(wr_running) {
		do {
			FD_ZERO(&rfds);
			FD_ZERO(&wfds);
			
			/* include stdin? */
			if(input)
				FD_SET(STDIN_FILENO, &rfds);

			/* begin at stdin */
			max_fd = STDIN_FILENO;
			
			/* add control socket */
			if(wr_socket != -1) {
				max_fd = wr_socket;
				FD_SET(wr_socket, &rfds);
			}
			
			/* add transfers */
			WR_LIST_LOCK(wr_transfers);
			WR_LIST_FOREACH(wr_transfers, node, transfer) {
				if(transfer->sd > 0) {
					if(transfer->type == WR_TRANSFER_DOWNLOAD)
						FD_SET(transfer->sd, &rfds);
					else
						FD_SET(transfer->sd, &wfds);
					
					if(transfer->sd > max_fd)
						max_fd = transfer->sd;
				}
			}
			WR_LIST_UNLOCK(wr_transfers);
			
			/* select */
			tv.tv_sec = 0;
			tv.tv_usec = 100000;
			state = select(max_fd + 1, &rfds, &wfds, NULL, &tv);
			
			/* get time */
			gettimeofday(&now, NULL);
			
			/* check for timeout */
			if(timeout > 0.0) {
				timeout -= now.tv_sec - timeout_tv.tv_sec;
				timeout -= (now.tv_usec - timeout_tv.tv_usec) / (double) 1000000;
				
				if(timeout <= 0.0)
					goto end;
			}
			
			/* check for transfers redraw */
			if(WR_LIST_COUNT(wr_transfers) > 0) {
				redraw += now.tv_sec - redraw_tv.tv_sec;
				redraw += (now.tv_usec - redraw_tv.tv_usec) / (double) 1000000;
	
				if(redraw >= 1.0) {
					wr_draw_transfers();
					redraw = 0.0;
				}
			}

			/* reset time */
			timeout_tv = redraw_tv = now;
		} while(state == 0);

		if(state < 0) {
			if(errno == EINTR) {
				/* got a signal */
				continue;
			} else {
				/* error in TCP communication */
				wr_printf_prefix("Could not select: %s\n",
					strerror(errno));

				break;
			}
		}
		
		/* loop over file descriptors */
		for(fd = STDIN_FILENO; fd <= max_fd; fd++) {
			if(FD_ISSET(fd, &rfds)) {
				if(fd == STDIN_FILENO) {
					/* read from readline */
					rl_callback_read_char();
				}
				else if(fd == wr_socket) {
					/* read from socket */
					bytes = SSL_read(wr_ssl, buffer + buffer_offset,
									 buffer_size - buffer_offset);
				
					if(bytes <= 0) {
						wr_close();
						
						continue;
					}

					if(buffer[buffer_offset + bytes - 1] != 4) {
						/* increase buffer by SSL_pending() bytes or,
						   if we've reached the 16k limit in SSL/TLS,
						   by initial buffer size */
						pending = SSL_pending(wr_ssl);

						if(pending == 0)
							pending = WR_BUFFER_SIZE;

						/* increase buffer size */
						buffer_size += pending;
						buffer = (char *) realloc(buffer, buffer_size);
						buffer_offset += bytes;
					} else {
						/* chomp separator */
						buffer[buffer_offset + bytes - 1] = '\0';

						/* dispatch message */
						message = wr_parse_message(buffer);
						
						/* exit? */
						if(value > 0) {
							if(message == value)
								goto end;
							
							if(message >= 500 && message <= 599)
								goto end;
						}

						/* reset */
						buffer_offset = 0;
					}
				}
			}
			
			if(FD_ISSET(fd, &rfds) || FD_ISSET(fd, &wfds)) {
				/* get transfer */
				transfer = wr_get_transfer_with_sd(fd);
				
				if(!transfer)
					continue;
				
				if(transfer->type == WR_TRANSFER_DOWNLOAD) {
					/* read from socket */
					bytes = SSL_read(transfer->ssl, transfer_buffer,
									 sizeof(transfer_buffer));
				} else {
					/* read from file */
					bytes = fread(transfer_buffer, 1, sizeof(transfer_buffer),
								  transfer->fp);
				}
				
				if(bytes <= 0) {
					wr_draw_transfers();

					if(bytes == -1) {
						/* print failure */
							wr_printf_prefix("Transfer of \"%s\" failed: %s\n",
								transfer->path,
								ERR_reason_error_string(ERR_get_error()));
					}
					else if(bytes == 0) {
						if(transfer->transferred == transfer->size) {
							/* print success */
							wr_printf_prefix("Transfer of \"%s\" completed\n",
								transfer->path);
								
							if(transfer->type == WR_TRANSFER_DOWNLOAD) {
								/* move partial */
								rename(transfer->local_path_partial,
									   transfer->local_path);
							}
						}
					}
					
					wr_close_transfer(transfer);
					wr_draw_transfers();
					
					/* get next */
					node = WR_LIST_FIRST(wr_transfers);
					
					if(node) {
						/* get transfer */
						transfer = WR_LIST_DATA(node);
						
						if(transfer->state == WR_TRANSFER_WAITING) {
							if(transfer->type == WR_TRANSFER_DOWNLOAD) {
								/* set state */
								wr_stat_state = WR_STAT_TRANSFER;
								
								/* request file information */
								wr_send_command("STAT %s%s",
									transfer->path,
									WR_MESSAGE_SEPARATOR);
							} else {
								/* request transfer */
								wr_send_command("PUT %s%s%llu%s%s%s",
									transfer->path,
									WR_FIELD_SEPARATOR,
									transfer->size,
									WR_FIELD_SEPARATOR,
									transfer->checksum,
									WR_MESSAGE_SEPARATOR);
							}
						}
					}
					
					continue;
				}
				
				/* bump bytes */
				transfer->transferred += bytes;
				
				if(transfer->type == WR_TRANSFER_DOWNLOAD) {
					/* write to file */
					fwrite(transfer_buffer, bytes, 1, transfer->fp);
				} else {
					/* write to socket */
					SSL_write(transfer->ssl, transfer_buffer, bytes);
				}
			}
		}
	}

end:
	/* clean up */
	if(buffer)
		free(buffer);
}



#pragma mark -

void wr_printf(char *fmt, ...) {
	char		*buffer;
	int			length, lines;
	va_list		ap;

	va_start(ap, fmt);

	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
		
	length = strlen(buffer);

	/* expand buffer? */
	if(wr_term_buffer_offset + length >= wr_term_buffer_size) {
		wr_term_buffer_size += WR_TERM_BUFFER_SIZE;
		wr_term_buffer = (char *) realloc(wr_term_buffer, wr_term_buffer_size);
	}
	
	/* append to buffer */
	strlcpy(wr_term_buffer + wr_term_buffer_offset,
			buffer,
			wr_term_buffer_size - wr_term_buffer_offset);
	wr_term_buffer_offset += length;
	
	/* print to term */
	lines = wr_term_buffer_count_lines(wr_term_buffer, wr_term_buffer_offset - length);

	if(wr_term_current_li == lines) {
		wr_term_current_li += 
			wr_term_buffer_count_lines(buffer, length);
		wr_term_puts(buffer, length);
	}
	
	free(buffer);
	va_end(ap);
}



void wr_printf_block(char *fmt, ...) {
	char		*buffer, *q, *p;
	va_list		ap;

	va_start(ap, fmt);

	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
	
	q = buffer;
	
	/* print with indent */
	while((p = strsep(&q, "\n")) != 0)
		wr_printf("   %s\n", p);

	free(buffer);
	va_end(ap);
}



void wr_printf_prefix(char *fmt, ...) {
	char		*buffer;
	va_list		ap;

	va_start(ap, fmt);

	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
	
	/* print with prefix */
	wr_printf("%s[wire] %s%s",
		"\033[32m",
		"\033[0m",
		buffer);

	free(buffer);
	va_end(ap);
}



#pragma mark -

void wr_print_say(char *nick, char *chat) {
	/* print with format */
	wr_printf("%s<%s%s%s%s%s>%s %s\n",
		"\033[34m",
		"\033[0m",
		"\033[0;1m",
		nick,
		"\033[0m",
		"\033[34m",
		"\033[0m",
		chat);
}



void wr_print_me(char *nick, char *chat) {
	/* print with format */
	wr_printf("%s*%s %s %s\n",
		"\033[1;33m",
		"\033[0m",
		nick,
		chat);
}



void wr_print_user(wr_user_t *user, unsigned int max_length) {
	char	*color;
	
	/* get color */
	if(user->admin && !user->idle)
		color = "\033[1;31m";
	else if(user->admin)
		color = "\033[0;31m";
	else if(!user->idle)
		color = "\033[1;37m";
	else
		color = "\033[0;37m";
	
	/* print with format */
	wr_printf("   %s%s%s%*s%s%*s%s\n",
		color,
		user->nick,
		"\033[0m",
		max_length - strlen(user->nick) + 1,
		" ",
		user->login,
		max_length - strlen(user->login) + 1,
		" ",
		user->ip);
}



void wr_print_file(wr_file_t *file, unsigned int max_length) {
	char	*color, size[32];
	
	/* get color */
	if(file->type != WR_FILE_FILE)
		color = "\033[1;34m";
	else
		color = "\033[0m";
	
	/* get size */
	if(file->type == WR_FILE_FILE)
		wr_text_format_size(size, file->size, sizeof(size));
	else
		wr_text_format_count(size, file->size, sizeof(size));

	/* print with format */
	wr_printf("   %s%s%s%s%*s%s\n",
		color,
		file->name,
		"\033[0m",
		file->type != WR_FILE_FILE
			? "/"
			: " ",
		max_length - strlen(file->name) + 4,
		" ",
		size);
}



#pragma mark -

void wr_draw_header(void) {
	char	status[CO * 2], divider[CO * 2];
	
	/* move to header */
	wr_term_cm(0, 0);
	
	/* write status */
	snprintf(status, sizeof(status), "%*s",
		(int) strlen(wr_topic) > CO
			? CO
			: (int) strlen(wr_topic),
		wr_topic);
	snprintf(divider, sizeof(divider), "%s%s%*s%s",
		"\033[44m",
		status,
		(int) (CO - strlen(status)),
		" ",
		"\033[0m");
	write(STDOUT_FILENO, divider, strlen(divider));
	
	/* move to input */
	wr_term_cm(rl_point % CO, LI - 1);
}



void wr_draw_transfers(void) {
	wr_list_node_t	*node;
	wr_transfer_t	*transfer;
	char			status[CO * 2], left[CO * 2], right[CO * 22];
	char			transferred[16], size[16], speed[16];
	unsigned int	seconds, bytes;
	time_t			now;
	int				i = 0;
	
	/* get time */
	now = time(NULL);
	
	/* reset number of lines available to output */
	wr_term_lines = LI - 3 - WR_LIST_COUNT(wr_transfers);
	
	/* reset scroll region */
	wr_term_cs(LI - 3, 1 + WR_LIST_COUNT(wr_transfers));
	
	WR_LIST_LOCK(wr_transfers);
	WR_LIST_FOREACH(wr_transfers, node, transfer) {
		/* move to line */
		wr_term_cm(0, 1 + i);
		wr_term_ce();
		
		if(transfer->state == WR_TRANSFER_RUNNING && now - transfer->start_time > 0) {
			/* set speed */
			seconds = now - transfer->start_time;
	
			if(seconds < 1)
				seconds = 1;
				
			bytes = transfer->transferred - transfer->offset;
			
			transfer->speed = (double) bytes / (double) seconds;
	
			/* get byte strings */
			wr_text_format_size(transferred, transfer->transferred, sizeof(transferred));
			wr_text_format_size(size, transfer->size, sizeof(size));
			wr_text_format_size(speed, transfer->speed, sizeof(speed));
			
			/* write right-hand status */
			snprintf(right, sizeof(right), "%s/%s, %s/s",
				transferred,
				size,
				speed);
		}
		else if(transfer->state == WR_TRANSFER_QUEUED) {
			/* write right-hand status */
			snprintf(right, sizeof(right), "queued at %u",
				transfer->queue);
		}
		else {
			/* write right-hand status */
			snprintf(right, sizeof(right), "waiting");
		}
		
		/* write left-hand status */
		snprintf(left, sizeof(left), "%u %3.0f%%  %*s",
			transfer->tid,
			transfer->size > 0
				? 100 * ((double) transfer->transferred / (double) transfer->size)
				: 0,
			(int) ((double) CO / 2),
			basename_np(transfer->path));
			
		/* write status */
		snprintf(status, sizeof(status), "%s%*s%s",
			left,
			(int) (CO - strlen(right) - strlen(left)),
			" ",
			right);
		write(STDOUT_FILENO, status, strlen(status));
		
		/* bump transfer */
		i++;
	}
	WR_LIST_UNLOCK(wr_transfers);
	
	/* move to input */
	wr_term_cm(rl_point % CO, LI - 1);
}



void wr_draw_divider(void) {
	char	base[MAXPATHLEN];
	char	status[CO * 2], range[CO], divider[CO * 2];
	int		lines;

	/* move to divider */
	wr_term_cm(0, LI - 2);

	/* get basename */
	strlcpy(base, basename(wr_files_cwd), sizeof(base));

	if(strcmp(base, ".") == 0)
		strlcpy(base, "/", sizeof(base));
	
	/* write status */
	if(wr_socket >= 0 && strlen(wr_server) > 0) {
		snprintf(status, sizeof(status), "[wire] %s - %s - %u %s - %s",
			wr_nick,
			wr_server,
			wr_users.count,
			wr_users.count == 1
				? "user"
				: "users",
			base);	
	} else {
		snprintf(status, sizeof(status), "[wire] %s",
			wr_nick);
	}

	lines = wr_term_buffer_count_lines(wr_term_buffer, wr_term_buffer_offset);

	if(wr_term_current_li == lines)
		memset(range, 0, sizeof(range));
	else if(wr_term_current_li <= wr_term_lines)
		strlcpy(range, "TOP", sizeof(range));
	else
		snprintf(range, sizeof(range), "%.0f%%", 100 * (double) wr_term_current_li / (double) lines);
	
	snprintf(divider, sizeof(divider), "%s%s%*s%s%s",
		"\033[44m",
		status,
		(int) (CO - strlen(status) - strlen(range)),
		" ",
		range,
		"\033[0m");
	write(STDOUT_FILENO, divider, strlen(divider));
	
	/* move to input */
	wr_term_cm(rl_point % CO, LI - 1);
}
