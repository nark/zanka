/* $Id$ */

/*
 *  Copyright (c) 2005-2007 Axel Andersson
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
#include <fcntl.h>
#include <time.h>
#include <errno.h>

#ifdef WI_CRYPTO
#include <openssl/rand.h>
#endif

#ifdef HAVE_PATHS_H
#include <paths.h>
#endif

#ifdef HAVE_MACHINE_PARAM_H
#include <machine/param.h>
#endif

#include <wired/wi-assert.h>
#include <wired/wi-base.h>
#include <wired/wi-log.h>
#include <wired/wi-runtime.h>
#include <wired/wi-private.h>
#include <wired/wi-string.h>
#include <wired/wi-system.h>

wi_boolean_t wi_change_root(void) {
	tzset();
	
#ifdef WI_CRYPTO
	RAND_status();
#endif

	if(chroot(wi_string_cstring(wi_root_path)) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	wi_chrooted = true;
	
	return true;
}



#ifndef HAVE_DAEMON

/*-
 * Copyright (c) 1990, 1993
 *      The Regents of the University of California. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. N NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL "/dev/null"
#endif

static int daemon(int nochdir, int noclose) {
	int		fd;

	switch(fork()) {
		case -1:
			return -1;
			break;
	
		case 0:
			break;

		default:
			_exit(0);
			break;
	}

	if(setsid() < 0)
		return -1;

	if(!nochdir)
		(void) chdir("/");

	if(!noclose && (fd = open(_PATH_DEVNULL, O_RDWR, 0)) >= 0) {
		(void) dup2(fd, STDIN_FILENO);
		(void) dup2(fd, STDOUT_FILENO);
		(void) dup2(fd, STDERR_FILENO);
		if(fd > 2)
			(void) close(fd);
	}

	return 0;
}

#endif

wi_boolean_t wi_daemon(void) {
	if(daemon(1, 1) < 0) {
		wi_error_set_errno(errno);
		
		return false;
	}
	
	return true;
}



#pragma mark -

void wi_switch_user(uid_t uid, gid_t gid) {
	wi_string_t		*path;
	struct passwd	*user;
	struct group	*group;
	uid_t			euid;
	gid_t			egid;
	
	path = wi_full_path(wi_log_path);

	if(path) {
		if(chown(wi_string_cstring(path), uid, gid) < 0) {
			wi_log_warn(WI_STR("Could not change owner of %@: %s"),
				path, strerror(errno));
		}
	}
	
	if(gid != getegid()) {
		user = getpwuid(uid);
		
		if(user) {
			if(initgroups(user->pw_name, gid) < 0) {
				wi_log_warn(WI_STR("Could not set group privileges: %s"),
					strerror(errno));
			}
		}
			
		if(setgid(gid) < 0) {
			wi_log_warn(WI_STR("Could not drop group privileges: %s"),
				strerror(errno));
		}
	}

	if(uid != geteuid()) {
		if(setuid(uid) < 0) {
			wi_log_warn(WI_STR("Could not drop user privileges: %s"),
				strerror(errno));
		}
	}

	euid = geteuid();
	egid = getegid();
	user = getpwuid(euid);
	group = getgrgid(egid);
	
	if(user && group) {
		wi_log_info(WI_STR("Operating as user %s (%d), group %s (%d)"),
			user->pw_name, user->pw_uid, group->gr_name, group->gr_gid);
	} else {
		wi_log_info(WI_STR("Operating as user %d, group %d"),
			euid, egid);
	}
}



wi_string_t * wi_user_name(void) {
	char			*env;
	struct passwd	*pwd;
	
	env = getenv("USER");
	
	if(env)
		return wi_string_with_cstring(env);
	
	pwd = getpwuid(getuid());
	
	if(!pwd)
		return NULL;
	
	return wi_string_with_cstring(pwd->pw_name);
}



wi_string_t * wi_user_home(void) {
	char			*env;
	struct passwd	*pwd;
	
	env = getenv("HOME");
	
	if(env)
		return wi_string_with_cstring(env);
	
	pwd = getpwuid(getuid());
	
	if(!pwd)
		return NULL;
	
	return wi_string_with_cstring(pwd->pw_dir);
}



#pragma mark -

wi_uinteger_t wi_page_size(void) {
#if defined(HAVE_GETPAGESIZE)
	return getpagesize();
#elif defined(PAGESIZE)
	return PAGESIZE;
#elif defined(EXEC_PAGESIZE)
	return EXEC_PAGESIZE;
#elif defined(NBPG)
#ifdef CLSIZE
	return NBPG * CLSIZE
#else
	return NBPG;
#endif
#elif defined(NBPC)
	return NBPC;
#else
	return 4096;
#endif
}



#pragma mark -

void * wi_malloc(size_t size) {
	void		*pointer;
	
	pointer = calloc(1, size);
	
	if(pointer == NULL)
		wi_crash();

	return pointer;
}



void * wi_realloc(void *pointer, size_t size) {
	void		*newpointer;
	
	newpointer = realloc(pointer, size);
	
	if(newpointer == NULL)
		wi_crash();
	
	return newpointer;
}



void wi_free(void *pointer) {
	if(pointer)
		free(pointer);
}



#pragma mark -

void wi_getopt_reset(void) {
#ifdef __GLIBC__
	optind = 0;
#else
	optind = 1;
#endif

#if HAVE_DECL_OPTRESET
	optreset = 1;
#endif
}
