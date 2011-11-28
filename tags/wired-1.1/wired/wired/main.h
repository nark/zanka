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

#ifndef WD_MAIN_H
#define WD_MAIN_H 1

#include <sys/types.h>
#include <sys/param.h>
#include <stdbool.h>
#include <signal.h>
#include <pthread.h>


#define							WD_VERSION_STRING_SIZE			128


void							wd_usage(void);
void							wd_version(void);

void							wd_write_pid(void);
void							wd_delete_pid(void);
void							wd_write_status(void);
void							wd_delete_status(void);

void							wd_sig_reload(int);
void							wd_sig_quit(int);
void							wd_sig_requeue(int);


extern volatile sig_atomic_t	wd_running;
extern volatile sig_atomic_t	wd_reload;
extern volatile sig_atomic_t	wd_signal;

extern char						wd_config[MAXPATHLEN];
extern char						wd_root[MAXPATHLEN];
extern char						wd_version_string[WD_VERSION_STRING_SIZE];

extern bool						wd_syslog;
extern bool						wd_log_file;
extern char						wd_log_path[MAXPATHLEN];
extern unsigned int				wd_log_level;

extern bool						wd_debug;
extern bool						wd_startup;
extern bool						wd_chroot;

extern pthread_mutex_t			wd_status_mutex;
extern time_t					wd_start_time;
extern unsigned int				wd_current_users, wd_total_users;
extern unsigned int				wd_current_downloads, wd_total_downloads;
extern unsigned int				wd_current_uploads, wd_total_uploads;
extern unsigned long long		wd_downloads_traffic, wd_uploads_traffic;

#endif /* WD_MAIN_H */
