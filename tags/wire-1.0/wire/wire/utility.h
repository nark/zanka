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

#ifndef WR_UTILITY_H
#define WR_UTILITY_H 1

#include <stdbool.h>
#include <iconv.h>


/* utility functions */
void 							wr_iso8601_to_time(char *, struct tm *);
void							wr_text_convert(iconv_t, char *, int *);
void							wr_text_format_size(char *, unsigned long long, size_t);
void							wr_text_format_count(char *, unsigned long long, size_t);
void							wr_path_expand(char *, char *, size_t);


/* extension functions */
void							getopt_reset_np(void);
char *							basename_np(const char *path);
char *							dirname_np(const char *path);


/* list functions */
struct wr_list_node {
	void						*data;
	struct wr_list_node			*next, *previous;
};
typedef struct wr_list_node		wr_list_node_t;

struct wr_list {
	struct wr_list_node			*first, *last;
	unsigned int				count;
};
typedef struct wr_list			wr_list_t;


#define WR_LIST_LOCK(list)
	
#define WR_LIST_UNLOCK(list)

#define WR_LIST_FOREACH(list, node, var) \
	for((node) = (list).first; \
	(node) != NULL && ((var) = (node)->data) != NULL; \
	(node) = (node)->next)

#define WR_LIST_FIRST(list) \
	(list).first

#define WR_LIST_LAST(list) \
	(list).last

#define WR_LIST_PREVIOUS(list_node) \
	(list_node)->previous

#define WR_LIST_NEXT(list_node) \
	(list_node)->next

#define WR_LIST_DATA(list_node) \
	(list_node)->data

#define WR_LIST_COUNT(list) \
	(list).count


void							wr_list_create(wr_list_t *);
void							wr_list_free(wr_list_t *);
wr_list_node_t *				wr_list_add(wr_list_t *, void *);
void							wr_list_delete(wr_list_t *, wr_list_node_t *);
wr_list_node_t *				wr_list_get_node(wr_list_t *, void *);


/* argv functions */
void							wr_argv_create(char *, int, int *, char ***);
void							wr_argv_create_wired(char *, int *, char ***);
void							wr_argv_free(int, char **);


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

#endif /* WR_UTILITY_H */
