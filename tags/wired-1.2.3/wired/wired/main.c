/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#ifdef HAVE_CORESERVICES_CORESERVICES_H
#include <CoreServices/CoreServices.h>
#endif

#include <sys/types.h>
#include <sys/utsname.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <openssl/rand.h>
#include <openssl/ssl.h>
#include <pthread.h>

#define SYSLOG_NAMES
#include <syslog.h>
#undef SYSLOG_NAMES

#include "accounts.h"
#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


volatile sig_atomic_t	wd_running = 1;
volatile sig_atomic_t	wd_reload;
volatile sig_atomic_t	wd_reregister;
volatile sig_atomic_t	wd_reindex;
volatile sig_atomic_t	wd_signal;

char					wd_root[MAXPATHLEN];
char					wd_config[MAXPATHLEN];
char					wd_version_string[WD_VERSION_STRING_SIZE];
char					*wd_banner;

bool					wd_syslog = true;
bool					wd_log_file = false;
char					wd_log_path[MAXPATHLEN];
unsigned int			wd_log_level;
unsigned int			wd_log_limit;

bool					wd_debug;
bool					wd_startup = true;
bool					wd_chroot;

pthread_mutex_t			wd_status_mutex = PTHREAD_MUTEX_INITIALIZER;
time_t					wd_start_time;
unsigned int			wd_current_users, wd_total_users;
unsigned int			wd_current_downloads, wd_total_downloads;
unsigned int			wd_current_uploads, wd_total_uploads;
unsigned long long		wd_downloads_traffic, wd_uploads_traffic;


int main(int argc, char *argv[]) {
	struct utsname	name;
	char			path[MAXPATHLEN], *syslog_flag = NULL;
	int 			i, ch;
	bool			no_chroot = false, test_config = false;
	int				syslog_facility = LOG_DAEMON, syslog_options = 0;
	
	/* default paths */
	strlcpy(wd_root, WD_ROOT, sizeof(wd_root));
	strlcpy(wd_config, WD_CONFIG_FILE, sizeof(wd_config));
	
	/* parse command line switches */
	while((ch = getopt(argc, argv, "Dd:f:hi:L:ls:tuVv")) != -1) {
		switch(ch) {
			case 'D':
				wd_debug = true;
				break;
				
			case 'd':
				realpath(optarg, wd_root);
				break;
			
			case 'f':
				strlcpy(wd_config, optarg, sizeof(wd_config));
				break;
			
			case 'i':
				wd_log_limit = strtoul(optarg, NULL, 10);
				break;
			
			case 'L':
				wd_syslog = false;
				wd_log_file = true;
				
				strlcpy(wd_log_path, optarg, sizeof(wd_log_path));
				break;
			
			case 'l':
				wd_log_level++;
				break;
			
			case 's':
				for(i = 0; facilitynames[i].c_name != NULL; i++) {
				    if(strcmp(optarg, facilitynames[i].c_name) == 0)
				    	break;
				}
				
				if(facilitynames[i].c_name)
					syslog_facility = facilitynames[i].c_val;
				else
					syslog_flag = strdup(optarg);
				break;
			
			case 't':
				test_config = true;
				break;
			
			case 'u':
				no_chroot = true;
				break;
			
			case 'V':
			case 'v':
				wd_version();
				break;
			
			case '?':
			case 'h':
			default:
				wd_usage();
				break;
		}
	}

	argc -= optind;
	argv += optind;
	
	if(wd_debug || wd_syslog) {
		/* test facility */
		if(syslog_flag) {
			wd_syslog = false;
			wd_log(LOG_ERR, "Could not locate the syslog facility \"%s\"",
				syslog_flag);
		}

		/* set options */
		syslog_options = LOG_PID | LOG_NDELAY;
		
		/* open log */
		openlog("wired", syslog_options, syslog_facility);
	}
	
	if(!no_chroot) {
		/* mark entry into chroot */
		wd_chroot = true;
		
		/* set time zone before chroot */
		tzset();

		/* trigger read of /dev/random before chroot */
		RAND_status();

		/* change root directory */
		if(chroot(wd_root) < 0) {
			wd_log(LOG_ERR, "Could not change root to %s: %s",
				wd_root, strerror(errno));
		}
		
		/* reset root */
		strlcpy(wd_root, "/", sizeof(wd_root));
	}
	
	/* create version string */
	uname(&name);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
	/* include CoreFoundation version number for Mac OS X */
	snprintf(wd_version_string, sizeof(wd_version_string),
		"Wired/%s (%s; %s; %s) (%s; CoreFoundation %.1f)",
		WD_PACKAGE_VERSION,
		name.sysname,
		name.release,
		WD_CPU,
		SSLeay_version(SSLEAY_VERSION),
		kCFCoreFoundationVersionNumber);
#else
	snprintf(wd_version_string, sizeof(wd_version_string),
		"Wired/%s (%s; %s; %s) (%s)",
		WD_PACKAGE_VERSION,
		name.sysname,
		name.release,
		WD_CPU,
		SSLeay_version(SSLEAY_VERSION));
#endif
	
	/* init SSL */
	wd_init_ssl();
	
	/* read the config file */
	if(wd_read_config() < 0)
		exit(1);
	
	/* log and exit if we're just checking the config */
	if(test_config) {
		printf("Config OK\n");
		
		exit(0);
	}
	
	/* apply config */
	wd_apply_config();
	
	/* save a copy of the startup settings */
	wd_frozen_settings = wd_settings;
	
	/* detach (don't chdir, don't close i/o channels) */
	if(!wd_debug) {
		if(daemon(1, 1) < 0) {
			wd_log(LOG_ERR, "Could not become a daemon: %s",
				strerror(errno));
		}
	}
	
	/* set up our signals */
	signal(SIGPIPE, SIG_IGN);
	signal(SIGHUP, wd_sig_reload);
	signal(SIGUSR1, wd_sig_reregister);
	signal(SIGUSR2, wd_sig_reindex);
	signal(SIGHUP, wd_sig_reload);
	signal(SIGINT, wd_sig_quit);
	signal(SIGTERM, wd_sig_quit);
	signal(SIGQUIT, wd_sig_quit);

	/* init server */
	wd_start_time = time(NULL);
	wd_log(LOG_INFO, "Starting Wired version %s", WD_PACKAGE_VERSION);
	wd_init_server();
	wd_log(LOG_INFO, "Listening on %s, ports %d-%d",
		strlen(wd_frozen_settings.address) > 0
			? inet_ntoa(wd_ctl_addr.sin_addr)
			: "all available addresses",
		wd_frozen_settings.port,
		wd_frozen_settings.port + 1);
	
	/* init tracker */
	if(wd_frozen_settings._register)
		wd_init_tracker();
	
	/* switch user/group on log file */
	if(wd_log_file) {
		wd_expand_path(path, wd_log_path, sizeof(path));
		
		if(chown(path, wd_frozen_settings.user->pw_uid,
		               wd_frozen_settings.group->gr_gid) < 0) {
			wd_log(LOG_ERR, "Could not change owner of %s: %s",
				path, strerror(errno));
		}
	}
	
	/* switch user/group */
	if(geteuid() != wd_frozen_settings.user->pw_uid ||
	   getegid() != wd_frozen_settings.group->gr_gid) {
		if(initgroups(wd_frozen_settings.user->pw_name,
                      wd_frozen_settings.group->gr_gid) < 0) {
			wd_log(LOG_ERR, "Could not set group privileges: %s",
				strerror(errno));
		}

		if(setgid(wd_frozen_settings.group->gr_gid) < 0) {
			wd_log(LOG_ERR, "Could not drop group privileges: %s",
				strerror(errno));
		}

		if(setuid(wd_frozen_settings.user->pw_uid) < 0) {
			wd_log(LOG_ERR, "Could not drop user privileges: %s",
				strerror(errno));
		}
	}
	
	/* write pid and status */
	wd_write_pid();
	wd_write_status();
	
	/* startup done */
	wd_startup = false;
	
	/* enter the utility handling thread in the main thread */
	wd_utility_thread(NULL);
	
	/* dropped out of loop */
	switch(wd_signal) {
		case SIGINT:
			wd_log(LOG_INFO, "Signal INT received, quitting");
			break;

		case SIGQUIT:
			wd_log(LOG_INFO, "Signal QUIT received, quitting");
			break;

		case SIGTERM:
			wd_log(LOG_INFO, "Signal TERM received, quitting");
			break;
	}
	
	/* clean up */
	wd_delete_pid();
	wd_delete_status();
	
	return 0;
}



void wd_usage(void) {
	fprintf(stderr,
"Usage: wired [-Dllhtuv] [-d path] [-f file] [-i lines] [-L file] [-s facility]\n\
\n\
Options:\n\
    -D             enable debug mode\n\
    -d path        set the server root path\n\
    -f file        set the config file to load\n\
    -h             display this message\n\
    -i lines       set limit on number of lines for -L\n\
    -L file        set alternate file for log output\n\
    -l             increase log level (can be used twice)\n\
    -s facility    set the syslog(3) facility\n\
    -t             run syntax test on config\n\
    -u             do not chroot(2) to root path\n\
    -v             display version information\n\
\n\
By Axel Andersson <%s>\n", WD_BUGREPORT);

	exit(2);
}



void wd_version(void) {
#ifdef HAVE_CORESERVICES_CORESERVICES_H
	fprintf(stderr, "Wired %s, protocol %s, %s, CoreFoundation %.1f\n",
		WD_PACKAGE_VERSION,
		WD_PROTOCOL_VERSION,
		SSLeay_version(SSLEAY_VERSION),
		kCFCoreFoundationVersionNumber);
#else
	fprintf(stderr, "Wired %s, protocol %s, %s\n",
		WD_PACKAGE_VERSION,
		WD_PROTOCOL_VERSION,
		SSLeay_version(SSLEAY_VERSION));
#endif

	exit(2);
}



#pragma mark -

void wd_write_pid(void) {
	FILE	*fp;
	
	if(strlen(wd_frozen_settings.pid) > 0) {
		fp = fopen(wd_frozen_settings.pid, "w");
	
		if(!fp) {
			wd_log(LOG_ERR, "Could not open %s: %s",
				wd_frozen_settings.pid, strerror(errno));
		} else {
			fprintf(fp, "%d\n", getpid());
			fclose(fp);
		}
	}
}



void wd_delete_pid(void) {
	if(strlen(wd_frozen_settings.pid) > 0) {
		if(unlink(wd_frozen_settings.pid) < 0) {
			wd_log(LOG_WARNING, "Could not delete %s: %s",
				wd_frozen_settings.pid, strerror(errno));
		}
	}
}



void wd_write_status(void) {
	static double	last;
	struct timeval	tv;
	double			now;
	FILE			*fp;
	char			path[MAXPATHLEN];
	
	gettimeofday(&tv, NULL);
	now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
	
	if(now - last < 1.0)
		return;
	
	last = now;
	
#ifdef HAVE_SETPROCTITLE
	setproctitle("%u %s", wd_current_users, wd_current_users == 1 ? "user" : "users");
#endif

	if(strlen(wd_settings.status) > 0) {
		snprintf(path, sizeof(path), "%s~", wd_settings.status);
		fp = fopen(path, "w");
	
		if(!fp) {
			wd_log(LOG_ERR, "Could not open %s: %s",
				path, strerror(errno));
		} else {
			fprintf(fp, "%ld %u %u %u %u %u %u %llu %llu\n",
					wd_start_time,
					wd_current_users,
					wd_total_users,
					wd_current_downloads,
					wd_total_downloads,
					wd_current_uploads,
					wd_total_uploads,
					wd_downloads_traffic,
					wd_uploads_traffic);
			fclose(fp);

			rename(path, wd_settings.status);
		}
	}
}



void wd_delete_status(void) {
	if(strlen(wd_settings.status) > 0) {
		if(unlink(wd_settings.status) < 0) {
			wd_log(LOG_WARNING, "Could not delete %s: %s",
				wd_settings.status, strerror(errno));
		}
	}
}



#pragma mark -

void wd_sig_reload(int sigraised) {
	wd_reload = 1;
	wd_signal = sigraised;
}



void wd_sig_reregister(int sigraised) {
	wd_reregister = 1;
	wd_signal = sigraised;
}


void wd_sig_reindex(int sigraised) {
	wd_reindex = 1;
	wd_signal = sigraised;
}


void wd_sig_quit(int sigraised) {
	wd_running = 0;
	wd_signal = sigraised;
}
