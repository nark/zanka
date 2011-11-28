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

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <syslog.h>
#include <openssl/ssl.h>
#include <wired/wired.h>

#include "clients.h"
#include "main.h"
#include "servers.h"
#include "settings.h"
#include "tracker.h"
#include "version.h"

static void						wt_cleanup(void);
static void						wt_usage(void);
static void						wt_version(void);

static void						wt_write_pid(void);
static void						wt_delete_pid(void);
static void						wt_delete_status(void);

static void						wt_signals_init(void);
static void						wt_block_signals(void);
static int						wt_wait_signals(void);
static void						wt_signal_thread(wi_runtime_instance_t *);
static void						wt_signal_crash(int);


wi_boolean_t					wt_running = true;

wi_address_family_t				wt_address_family = WI_ADDRESS_NULL;

wi_lock_t						*wt_status_lock;
wi_date_t						*wt_start_date;
wi_uinteger_t					wt_current_servers, wt_total_clients;
wi_uinteger_t					wt_current_users;
wi_uinteger_t					wt_current_files;
wi_file_offset_t				wt_current_size;


int main(int argc, const char **argv) {
	wi_mutable_array_t		*arguments;
	wi_pool_t				*pool;
	wi_string_t				*string, *root_path;
	int						ch, facility;
	wi_boolean_t			test_config, daemonize, change_directory, switch_user;

	/* init libwired */
	wi_initialize();
	wi_load(argc, argv);
	
	pool					= wi_pool_init(wi_pool_alloc());
	wi_log_syslog			= true;
	wi_log_syslog_facility	= LOG_DAEMON;

	/* init core systems */
	wt_version_init();
	wt_status_lock			= wi_lock_init(wi_lock_alloc());
	wt_start_date			= wi_date_init(wi_date_alloc());
	
	/* set defaults */
	root_path				= WI_STR(WT_ROOT);
	wi_settings_config_path	= wi_string_init_with_cstring(wi_string_alloc(), WT_CONFIG_PATH);
	test_config				= false;
	daemonize				= true;
	change_directory		= true;
	switch_user				= true;

	/* init reexec argument list */
	arguments				= wi_array_init(wi_mutable_array_alloc());

	/* parse command line switches */
	while((ch = getopt(argc, (char * const *) argv, "46Dd:f:hi:L:ls:tuVvXx")) != -1) {
		switch(ch) {
			case '4':
				wt_address_family = WI_ADDRESS_IPV4;
				break;

			case '6':
				wt_address_family = WI_ADDRESS_IPV6;
				break;

			case 'D':
				daemonize = false;
				wi_log_stderr = true;
				break;

			case 'd':
				root_path = wi_string_with_cstring(optarg);
				break;

			case 'f':
				wi_release(wi_settings_config_path);
				wi_settings_config_path = wi_string_init_with_cstring(wi_string_alloc(), optarg);
				break;

			case 'i':
				wi_log_limit = wi_string_uint32(wi_string_with_cstring(optarg));
				break;

			case 'L':
				wi_log_syslog = false;
				wi_log_file = true;

				wi_release(wi_log_path);
				wi_log_path = wi_string_init_with_cstring(wi_string_alloc(), optarg);
				break;

			case 'l':
				wi_log_level++;
				break;

			case 's':
				string = wi_string_with_cstring(optarg);
				facility = wi_log_syslog_facility_with_name(string);
				
				if(facility < 0)
					wi_log_fatal(WI_STR("Could not find syslog facility \"%@\": %m"), string);
				
				wi_log_syslog_facility = facility;
				break;

			case 't':
				test_config = true;
				break;

			case 'u':
				break;

			case 'V':
			case 'v':
				wt_version();
				break;
				
			case 'X':
				daemonize = false;
				break;
				
			case 'x':
				daemonize = false;
				change_directory = false;
				switch_user = false;
				break;
			
			case '?':
			case 'h':
			default:
				wt_usage();
				break;
		}
		
		wi_mutable_array_add_data(arguments, wi_string_with_format(WI_STR("-%c"), ch));
		
		if(optarg)
			wi_mutable_array_add_data(arguments, wi_string_with_cstring(optarg));
	}
	
	/* detach */
	if(daemonize) {
		wi_mutable_array_add_data(arguments, WI_STR("-X"));
		
		switch(wi_fork()) {
			case -1:
				wi_log_fatal(WI_STR("Could not fork: %m"));
				break;
				
			case 0:
				if(!wi_execv(wi_string_with_cstring(argv[0]), arguments))
					wi_log_fatal(WI_STR("Could not execute %s: %m"), argv[0]);
				break;
				
				default:
				_exit(0);
				break;
		}
	}
	
	wi_release(arguments);
	
	/* change directory */
	if(change_directory) {
		if(!wi_fs_change_directory(root_path))
			wi_log_error(WI_STR("Could not change directory to %@: %m"), root_path);
	}
	
	/* open log */
	wi_log_open();

	/* init subsystems */
	wt_ssl_init();
	wt_clients_init();
	wt_servers_init();

	/* read the config file */
	wt_settings_init();

	if(!wt_settings_read_config())
		exit(1);

	/* apply settings */
	wt_settings_apply_settings();

	if(test_config) {
		printf("Config OK\n");

		exit(0);
	}

	/* dump command line */
	wi_log_info(WI_STR("Started as %@ %@"),
		wi_process_path(wi_process()),
		wi_array_components_joined_by_string(wi_process_arguments(wi_process()), WI_STR(" ")));

	/* init tracker */
	wi_log_info(WI_STR("Starting Wired Tracker version %@"), wt_version_string);
	wt_tracker_init();

	/* switch user/group */
	if(switch_user)
		wi_switch_user(wt_settings.user, wt_settings.group);
		
	/* create tracker threads after privilege drop */
	wt_signals_init();
	wt_block_signals();
	wt_servers_schedule();
	wt_tracker_create_threads();
	wt_write_pid();
	wt_write_status(true);
	
	/* clean up pool after startup */
	wi_pool_drain(pool);
	
	/* enter the signal handling thread in the main thread */
	wt_signal_thread(NULL);

	/* dropped out */
	wt_cleanup();
	wi_log_close();
	wi_release(pool);

	return 0;
}



static void wt_cleanup(void) {
	wt_delete_pid();
	wt_delete_status();
}



static void wt_usage(void) {
	fprintf(stderr,
"Usage: trackerd [-Dlhtv] [-d path] [-f file] [-i lines] [-L file] [-s facility]\n\
\n\
Options:\n\
    -4             listen on IPv4 addresses only\n\
    -6             listen on IPv6 addresses only\n\
    -D             do not daemonize\n\
    -d path        set the server root path\n\
    -f file        set the config file to load\n\
    -h             display this message\n\
    -i lines       set limit on number of lines for -L\n\
    -L             set alternate file for log output\n\
    -l             increase log level\n\
    -s facility    set the syslog(3) facility\n\
    -t             run syntax test on config\n\
    -v             display version information\n\
\n\
By Axel Andersson <%s>\n", WT_BUGREPORT);

	exit(2);
}



static void wt_version(void) {
	fprintf(stderr, "Wired Tracker %s, protocol %s, %s\n",
		wi_string_cstring(wt_version_string),
		wi_string_cstring(wt_protocol_version_string),
		SSLeay_version(SSLEAY_VERSION));

	exit(2);
}



#pragma mark -

static void wt_write_pid(void) {
	wi_string_t		*string;

	if(wt_settings.pid) {
		string = wi_string_with_format(WI_STR("%d\n"), getpid());

		if(!wi_string_write_to_file(string, wt_settings.pid))
			wi_log_warn(WI_STR("Could not write to %@: %m"), wt_settings.pid);
	}
}



static void wt_delete_pid(void) {
	if(wt_settings.pid) {
		if(!wi_fs_delete_path(wt_settings.pid))
			wi_log_warn(WI_STR("Could not delete %@: %m"), wt_settings.pid);
	}
}



void wt_write_status(wi_boolean_t force) {
	static wi_time_interval_t	update;
	wi_string_t					*string;
	wi_time_interval_t			interval;

	interval = wi_time_interval();

	if(!force && interval - update < 1.0)
		return;

	update = interval;

	wi_process_set_name(wi_process(), wi_string_with_format(WI_STR("%u %@"),
		wt_current_servers,
		wt_current_servers == 1
			? WI_STR("server")
			: WI_STR("servers")));

	if(wt_settings.status) {
		string = wi_string_with_format(WI_STR("%.0f %u %u %u %u %llu\n"),
									   wi_date_time_interval(wt_start_date),
									   wt_current_servers,
									   wt_total_clients,
									   wt_current_users,
									   wt_current_files,
									   wt_current_size);
		
		if(!wi_string_write_to_file(string, wt_settings.status))
			wi_log_warn(WI_STR("Could not write to %@: %m"), wt_settings.status);
	}
}



static void wt_delete_status(void) {
	if(wt_settings.status) {
		if(!wi_fs_delete_path(wt_settings.status))
			wi_log_warn(WI_STR("Could not delete %@: %m"), wt_settings.status);
	}
}



#pragma mark -

static void wt_signals_init(void) {
	signal(SIGILL, wt_signal_crash);
	signal(SIGABRT, wt_signal_crash);
	signal(SIGFPE, wt_signal_crash);
	signal(SIGBUS, wt_signal_crash);
	signal(SIGSEGV, wt_signal_crash);
}



static void wt_block_signals(void) {
	wi_thread_block_signals(SIGHUP, SIGINT, SIGTERM, SIGQUIT, SIGPIPE, 0);
}



static int wt_wait_signals(void) {
	return wi_thread_wait_for_signals(SIGHUP, SIGINT, SIGTERM, SIGQUIT, SIGPIPE, 0);
}



static void wt_signal_thread(wi_runtime_instance_t *arg) {
	wi_pool_t		*pool;
	unsigned int	i = 0;
	int				signal;
	
	pool = wi_pool_init(wi_pool_alloc());

	while(wt_running) {
		signal = wt_wait_signals();
		
		switch(signal) {
			case SIGPIPE:
				wi_log_warn(WI_STR("Signal PIPE received, ignoring"));
				break;

			case SIGHUP:
				wi_log_info(WI_STR("Signal HUP received, reloading configuration"));
				wt_settings_read_config();
				wt_settings_apply_settings();
				break;

			case SIGINT:
				wi_log_info(WI_STR("Signal INT received, quitting"));
				wt_running = false;
				break;

			case SIGQUIT:
				wi_log_info(WI_STR("Signal QUIT received, quitting"));
				wt_running = false;
				break;

			case SIGTERM:
				wi_log_info(WI_STR("Signal TERM received, quitting"));
				wt_running = false;
				break;
		}
		
		if(++i % 10 == 0)
			wi_pool_drain(pool);
	}
	
	wi_release(pool);
}



static void wt_signal_crash(int sigraised) {
	wt_cleanup();
	
	sleep(360);

	if(signal(sigraised, SIG_DFL) != SIG_ERR)
		raise(sigraised);
}
