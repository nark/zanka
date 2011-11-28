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

#include "config.h"

#include <sys/param.h>
#include <sys/types.h>
#include <stdarg.h>
#include <stdbool.h>
#include <time.h>
#include <regex.h>
#include <pthread.h>

/* utility functions */
#define ARRAY_SIZE(array)		(sizeof(array) / sizeof(*(array)))
#define WD_BASE64_INITIAL_SIZE	BUFSIZ

void							wd_expand_path(char *, char *, size_t);
void							wd_time_to_iso8601(time_t, char *, size_t);
char *							wd_base64_encode(char *);


/* apple functions */
#ifdef HAVE_CARBON_CARBON_H
bool							wd_apple_is_invisible(char *);
#endif

#ifdef HAVE_CORESERVICES_CORESERVICES_H
bool							wd_apple_is_alias(char *);
int								wd_apple_resolve_alias(char *, char *, size_t);
int								wd_apple_resolve_alias_path(char *, char *, size_t);
#endif


/* list functions */
struct wd_list_node {
	void						*data;
	struct wd_list_node			*next, *previous;
};
typedef struct wd_list_node		wd_list_node_t;

struct wd_list {
	struct wd_list_node			*first, *last;
	pthread_mutex_t				mutex;
	unsigned int				count;
};
typedef struct wd_list			wd_list_t;


#define WD_LIST_LOCK(list) \
	pthread_mutex_lock(&((list).mutex))

#define WD_LIST_UNLOCK(list) \
	pthread_mutex_unlock(&((list).mutex))

#define WD_LIST_FOREACH(list, node, var) \
	for((node) = (list).first; \
	(node) != NULL && ((var) = (node)->data) != NULL; \
	(node) = (node)->next)

#define WD_LIST_FIRST(list) \
	(list).first

#define WD_LIST_LAST(list) \
	(list).last

#define WD_LIST_NEXT(list_node) \
	(list_node)->next

#define WD_LIST_DATA(list_node) \
	(list_node)->data

#define WD_LIST_COUNT(list) \
	(list).count


void							wd_list_create(wd_list_t *);
void							wd_list_free(wd_list_t *);
wd_list_node_t *				wd_list_add(wd_list_t *, void *);
void							wd_list_delete(wd_list_t *, wd_list_node_t *);


/* regexp functions */
struct wd_regexp {
	regex_t						regex;
	bool						inited;
};
typedef struct wd_regexp		wd_regexp_t;


#define WD_REGEXP_REGEX(regexp) \
	(regexp).regex

#define WD_REGEXP_INITED(regexp) \
	(regexp).inited

#define WD_REGEXP_MATCH(regexp, match) \
	((regexp).inited && regexec(&(regexp).regex, match, 0, NULL, 0) == 0)


/* log functions */
enum wd_log_level {
	WD_LOG_NORMAL				= 0,
	WD_LOG_VERBOSE1,
	WD_LOG_VERBOSE2,
	WD_LOG_MAX
};
typedef enum wd_log_level		wd_log_level_t;


void							wd_log(int, char *, ...);
void							wd_log_l(int, char *, ...);
void							wd_log_ll(int, char *, ...);
void							wd_log_truncate(unsigned int);


extern unsigned int				wd_log_lines;


/* argv functions */
void							wd_argv_create_wired(char *, int *, char ***);
void							wd_argv_free(int, char **);


/* string functions */
#ifndef HAVE_STRSEP
char *							strsep(char **, const char *);
#endif

#ifndef HAVE_STRCASESTR
char *							strcasestr(const char *, const char *);
#endif

#ifndef HAVE_STRLCAT
size_t							strlcat(char *, const char *, size_t);
#endif

#ifndef HAVE_STRLCPY
size_t							strlcpy(char *, const char *, size_t);
#endif

#ifndef HAVE_VASPRINTF
#ifdef HAVE_VPRINTF
int								vasprintf(char **, const char *, va_list);
#endif
#endif

#endif /* WD_UTILITY_H */
