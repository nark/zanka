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

#ifndef WD_UTILITY_H
#define WD_UTILITY_H 1

#include <sys/param.h>
#include <sys/types.h>
#include <time.h>

#include "config.h"

enum {
	WD_LOG_NORMAL				= 0,
	WD_LOG_VERBOSE1,
	WD_LOG_VERBOSE2,
	WD_LOG_MAX
};


struct wd_list_node {
	void						*data;
	struct wd_list_node			*next, *previous;
};

struct wd_list {
	struct wd_list_node			*first, *last;
	pthread_mutex_t				mutex;
};


void							wd_expand_path(char *, char *, size_t);
void							wd_time_to_iso8601(struct tm *, char *, size_t);

#ifdef HAVE_CORESERVICES_CORESERVICES_H
bool							wd_apple_is_alias(char *);
int								wd_apple_resolve_alias(char *, char *, size_t);
int								wd_apple_resolve_alias_path(char *, char *, size_t);
#endif

void							wd_log(int, char *, ...);
void							wd_log_l(int, char *, ...);
void							wd_log_ll(int, char *, ...);

void							wd_list_create(struct wd_list *);
void							wd_list_free(struct wd_list *);
void							wd_list_add(struct wd_list *, void *);
void							wd_list_delete(struct wd_list *, struct wd_list_node *);

#ifndef HAVE_STRSEP
char *							strsep(char **, const char *);
#endif

#ifndef HAVE_STRCASESTR
char *							strcasestr(const char *, const char *);
#endif

#ifndef HAVE_STRLCPY
size_t							strlcpy(char *, const char *, size_t);
#endif

#endif /* WD_UTILITY_H */
