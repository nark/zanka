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

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <readline/readline.h>
#include <wired/wired.h>

#include "client.h"
#include "commands.h"
#include "files.h"
#include "ignores.h"
#include "main.h"
#include "terminal.h"
#include "transfers.h"
#include "users.h"
#include "version.h"
#include "windows.h"

static void							wr_cleanup(void);
static void							wr_usage(void);
static void							wr_version(void);

static void							wr_init_signals(void);
static void							wr_sig_winch(int);
static void							wr_sig_int(int);
static void							wr_sig_crash(int);

static void							wr_wi_log_callback(wi_string_t *);

static int							wr_runloop(wi_list_t *, wi_time_interval_t);
static int							wr_runloop_stdin_callback(wi_socket_t *);


static wi_list_t					*wr_runloop_sockets;

volatile sig_atomic_t				wr_running = 1;

wi_boolean_t						wr_debug;
wi_date_t							*wr_start_date;


int main(int argc, const char **argv) {
	wi_pool_t			*pool;
	wi_string_t			*homepath, *wirepath, *path, *component;
	wi_file_t			*file;	
	int					ch;

	/* init libwired */
	wi_initialize();
	wi_load(argc, argv);
	
	pool			= wi_pool_init(wi_pool_alloc());
	wi_log_callback	= wr_wi_log_callback;
	
	/* init core systems */
	wr_init_version();
	wr_start_date	= wi_date_init(wi_date_alloc());
	
	/* set defaults */
	wr_nick			= wi_retain(wi_user_name());
	homepath		= wi_user_home();

	/* parse command line switches */
	while((ch = getopt(argc, (char * const *) argv, "Dc:hVv")) != -1) {
		switch(ch) {
			case 'D':
				wr_debug = true;

				wi_log_level = WI_LOG_DEBUG;
				wi_log_file = true;
				wi_log_path = WI_STR("wire.out");
				wi_log_callback = NULL;
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

	/* open log */
	wi_log_open();
	
	/* create ~/.wire */
	wirepath = wi_string_by_appending_path_component(homepath, WI_STR(WR_WIRE_PATH));
	wi_file_create_directory(wirepath, 0700);
	
	/* init subsystems */
	wr_init_signals();
	wr_init_terminal();
	wr_init_readline();
	wr_init_windows();
	wr_init_client();
	wr_init_runloop();
	wr_init_users();
	wr_init_ignores();
	wr_init_files();
	wr_init_transfers();
	wr_init_server();
	
	/* open default settings */
	path = wi_string_by_appending_path_component(homepath, WI_STR(WR_WIRE_CONFIG_PATH));
	file = wi_file_for_reading(path);

	if(file)
		wr_parse_file(file);
	else
		wr_printf_prefix(WI_STR("%@: %m"), path);

	/* read specified bookmark */
	if(*argv) {
		component	= wi_string_with_cstring(*argv);
		path		= wi_string_by_appending_path_component(wirepath, component);
		file		= wi_file_for_reading(path);

		if(file)
			wr_parse_file(file);
		else
			wr_printf_prefix(WI_STR("%@: %m"), path);
	}
	
	wi_release(pool);
	pool = wi_pool_init(wi_pool_alloc());
	
	/* enter event loop */
	wr_runloop_run();

	/* clean up */
	wr_cleanup();
	wi_release(pool);
	
	return 0;
}



static void wr_cleanup(void) {
	wr_close_terminal();
	wr_close_readline();
}



static void wr_usage(void) {
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



static void wr_version(void) {
	fprintf(stderr, "Wire %s, protocol %s, %s, readline %s\n",
		wi_string_cstring(wr_version_string),
		wi_string_cstring(wr_protocol_version_string),
		SSLeay_version(SSLEAY_VERSION),
		rl_library_version);

	exit(2);
}



#pragma mark -

static void wr_init_signals(void) {
	signal(SIGPIPE, SIG_IGN);
	signal(SIGWINCH, wr_sig_winch);
	signal(SIGINT, wr_sig_int);
	signal(SIGTERM, wr_sig_int);
	signal(SIGQUIT, wr_sig_int);
	signal(SIGILL, wr_sig_crash);
	signal(SIGBUS, wr_sig_crash);
	signal(SIGSEGV, wr_sig_crash);
	signal(SIGABRT, wr_sig_crash);
}



static void wr_sig_winch(int sigraised) {
	wr_terminal_resize();
}



static void wr_sig_int(int sigraised) {
	wr_running = 0;
}



static void wr_sig_crash(int sigraised) {
	wr_cleanup();
	
	if(signal(sigraised, SIG_DFL) != SIG_ERR)
		raise(sigraised);
}



#pragma mark -

static void wr_wi_log_callback(wi_string_t *string) {
	wr_printf_prefix(WI_STR("%@"), string);
}



#pragma mark -

char * wr_readline_bookmark_generator(const char *text, int state) {
	static wi_array_t		*bookmarks;
	static unsigned int		index, count, length;
	wi_string_t				*path, *string, *bookmark;
	char					*match = NULL;
	
	if(state == 0) {
		wi_release(bookmarks);

		path = wi_user_home();
		wi_string_append_path_component(path, WI_STR(WR_WIRE_PATH));
		
		bookmarks = wi_retain(wi_file_directory_contents_at_path(path));
		index = 0;
		count = wi_array_count(bookmarks);
		length = strlen(text);
	}
	
	string = wi_string_with_cstring(text);

	while(index < count) {
		bookmark = wi_array_data_at_index(bookmarks, index);
		index++;

		if(wi_string_index_of_string(bookmark, string, WI_STRING_SMART_CASE_INSENSITIVE) == 0) {
			match = strdup(wi_string_cstring(bookmark));
			
			break;
		}
	}

	return match;
}



#pragma mark -

void wr_init_runloop(void) {
	wr_runloop_sockets = wi_list_init(wi_list_alloc());
}



void wr_runloop_add_socket(wi_socket_t *socket, wr_runloop_callback_func_t *callback) {
	wi_socket_set_data(socket, callback);
	wi_list_append_data(wr_runloop_sockets, socket);
}



void wr_runloop_remove_socket(wi_socket_t *socket) {
	wi_list_remove_data(wr_runloop_sockets, socket);
}



void wr_runloop_run(void) {
	wi_pool_t			*pool;
	wi_socket_t			*socket;
	wi_time_interval_t	interval, ping_interval;
	unsigned int		i = 0;
	int					result;
	
	pool = wi_pool_init(wi_pool_alloc());

	socket = wi_socket_init_with_descriptor(wi_socket_alloc(), STDIN_FILENO);
	wi_socket_set_direction(socket, WI_SOCKET_READ);
	wr_runloop_add_socket(socket, &wr_runloop_stdin_callback);
	wi_release(socket);
	
	ping_interval = wi_time_interval();
	
	while(wr_running) {
		if(!pool)
			pool = wi_pool_init(wi_pool_alloc());
	
		result = wr_runloop(wr_runloop_sockets, 30.0);
		
		if(result < 0 && wr_connected) {
			interval = wi_time_interval();
			
			if(interval - ping_interval > 60.0) {
				wr_send_command(WI_STR("PING"));
				
				ping_interval = interval;
			}
			
			wi_release(pool);
			pool = NULL;
		}
		
		if(++i % 100 == 0) {
			wi_release(pool);
			pool = NULL;
		}
	}
	
	wi_release(pool);
}



void wr_runloop_run_for_socket(wi_socket_t *socket, wi_time_interval_t timeout, unsigned int message) {
	wi_list_t		*list;
	int				result;
	
	list = wi_list_init_with_data(wi_list_alloc(), socket, NULL);
	
	while(wr_running) {
		result = wr_runloop(list, timeout);
		
		if(result < 0 || (unsigned int) result == message || (result >= 500 && result < 600))
			break;
	}
	
	wi_release(list);
}



#pragma mark -

static int wr_runloop(wi_list_t *list, wi_time_interval_t timeout) {
	wi_socket_t					*socket;
	wr_runloop_callback_func_t	*callback;
	
	socket = wi_socket_wait_multiple(list, timeout);
	
	if(socket) {
		callback = wi_socket_data(socket);
		
		return (*callback)(socket);
	}
	
	return -1;
}



static int wr_runloop_stdin_callback(wi_socket_t *socket) {
	wr_readline_read();
	
	return 1;
}
