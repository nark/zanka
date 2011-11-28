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

#include <sys/param.h>
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>
#include <libgen.h>

#include "commands.h"
#include "main.h"
#include "utility.h"


void wr_iso8601_to_time(char *iso8601, struct tm *time) {
	char		date[26], offset[7];
	time_t		clock;
	
	/* remove ":" from time zone offset */
	strlcpy(offset, iso8601 + 19, sizeof(offset));
	strlcpy(offset + 3, offset + 4, sizeof(offset));
	
	/* create new string */
	snprintf(date, sizeof(date), "%.19s%s", iso8601, offset);
	
	/* create time struct from string */
	strptime(date, "%Y-%m-%dT%H:%M:%S%z", time);
	clock = mktime(time);
	time = localtime(&clock);
}



void wr_text_convert(iconv_t conv, char *inbuffer, int *inbytes) {
	char		*in, *out, *outbuffer;
	size_t		outbytes, length;

	/* exit if invalid iconv */
	if(conv == (iconv_t) -1)
		return;

	/* init buffer */
	length = outbytes = *inbytes * 2;
	outbuffer = (char *) malloc(outbytes);
	memset(outbuffer, 0, outbytes);
	out = outbuffer;
	in = inbuffer;

	/* convert */
	if(iconv(conv, (const char **) &in, (size_t *) inbytes, &out, &outbytes) != (iconv_t) -1) {
		/* copy back */
		memcpy(inbuffer, outbuffer, length - outbytes);
		inbuffer[length - outbytes] = '\0';

		/* set new length */
		*inbytes = length - outbytes;
	} else {
		/* print error */
		wr_printf_prefix("iconv: %s\n", strerror(errno));
	}

	free(outbuffer);
}



void wr_text_format_size(char *out, unsigned long long size, size_t length) {
    double		kb, mb, gb, tb, pb;
	
	/* set size */
	if(size < 1000) {
		snprintf(out, length, "%llu %s", size, size == 1 ? "byte" : "bytes");
		
		return;
	}
	
	kb = size / 1024;
	
	if(kb < 1000) {
		snprintf(out, length, "%.1f KB", kb);
		
		return;
	}
	
	mb = kb / 1024;
	
	if(mb < 1000) {
		snprintf(out, length, "%.1f MB", mb);
		
		return;
	}
	
	gb = mb / 1024;
	
	if(gb < 1000) {
		snprintf(out, length, "%.1f GB", gb);
		
		return;
	}
	
	tb = gb / 1024;
	
	if(tb < 1000) {
		snprintf(out, length, "%.1f TB", tb);
		
		return;
	}
	
	pb = tb / 1024;
	
	if(pb < 1000) {
		snprintf(out, length, "%.1f PB", pb);
		
		return;
	}
	
	/* clear */
	memset(out, 0, length);
}



void wr_text_format_count(char *out, unsigned long long count, size_t length) {
	/* set count */
	snprintf(out, length, "%llu %s", count, count == 1 ? "item" : "items");
}



void wr_path_expand(char *out, char *in, size_t length) {
	char	path[MAXPATHLEN];
	char	*ap, *p, *q;
	
	if(in[0] == '/') {
		strlcpy(path, in, length);
	} else {
		strlcpy(path, wr_files_cwd, length);

		if(wr_files_cwd[strlen(wr_files_cwd) - 1] != '/')
			strlcat(path, "/", length);
			
		strlcat(path, in, length);
	}
	
	strlcpy(out, "/", length);
	p = path;
	
	while((ap = strsep(&p, "/"))) {
		if(strcmp(ap, ".") == 0)
			continue;
		
		if(strcmp(ap, "..") == 0) {
			if((q = strrchr(out, '/')))
				*q = '\0';
			
			continue;
		}

		if(out[strlen(out) - 1] != '/')
			strlcat(out, "/", length);

		strlcat(out, ap, length);
	}
	
	if(strlen(out) == 0)
		strlcpy(out, "/", length);
}



#pragma mark -

void getopt_reset_np(void) {
#ifdef __GLIBC__
	optind = 0;
#else
	optind = 1;
#endif

#if HAVE_DECL_OPTRESET
	optreset = 1;
#endif
}



char * basename_np(const char *path) {
	static char		*base;
	char			real_path[MAXPATHLEN];
	
	strlcpy(real_path, path, sizeof(real_path));
	
	if(real_path[strlen(real_path) - 1] == '/') {
		base = "";
		
		return base;
	}
	
	base = basename(real_path);
	
	if(strcmp(base, ".") == 0)
		base = "";

	return base;
}



char * dirname_np(const char *path) {
	char	real_path[MAXPATHLEN];
	
	strlcpy(real_path, path, sizeof(real_path));
	
	return dirname(real_path);
}



#pragma mark -

void wr_list_create(wr_list_t *list) {
	list->first = list->last = NULL;
	list->count = 0;
}



void wr_list_free(wr_list_t *list) {
	wr_list_node_t	*node, *node_next;
	
	WR_LIST_LOCK(*list);
	for(node = WR_LIST_FIRST(*list); node != NULL; node = node_next) {
		node_next = WR_LIST_NEXT(node);
			
		wr_list_delete(list, node);
	}
	WR_LIST_UNLOCK(*list);
}



wr_list_node_t * wr_list_add(wr_list_t *list, void *data) {
	wr_list_node_t	*node;
	
	/* create a node */
	node = (wr_list_node_t *) malloc(sizeof(wr_list_node_t));
	memset(node, 0, sizeof(wr_list_node_t));
	
	/* set data pointer */
	node->data = data;

	/* reorder list */
	node->next = NULL;
	
	if(!list->first) {
		list->first = node;
		node->previous = NULL;
	} else {
		list->last->next = node;
		node->previous = list->last;
	}
	
	list->last = node;
	
	/* maintain count */
	list->count++;
	
	return node;
}



void wr_list_delete(wr_list_t *list, wr_list_node_t *node) {
	/* reorder list */
	if(node == list->first) {
		list->first = node->next;

		if(list->first)
			list->first->previous = NULL;

		if(node == list->last)
			list->last = NULL;
	}
	else if(node == list->last) {
		list->last = node->previous;
		list->last->next = NULL;
	} else {
		node->previous->next = node->next;
		node->next->previous = node->previous;
	}
	
	/* free data pointer */
	if(node->data)
		free(node->data);

	/* free node */
	free(node);
	
	/* maintain count */
	list->count--;
}



wr_list_node_t * wr_list_get_node(wr_list_t *list, void *data) {
	wr_list_node_t	*node;
	void			*this_data;
	
	WR_LIST_LOCK(*list);
	WR_LIST_FOREACH(*list, node, this_data) {
		if(this_data == data)
			return node;
	}
	WR_LIST_UNLOCK(*list);
	
	return NULL;
}



#pragma mark -

void wr_argv_create(char *input, int index, int *argc_out, char ***argv_out) {
	char		**argv;
	char		*buffer, *end;
	int			argc = 0, maxargc = 8;
	int			squote, dquote, bsquote;
	
	buffer = (char *) malloc(strlen(input) + 1);
	argv = (char **) malloc(maxargc * sizeof(char *));
	squote = dquote = bsquote = 0;

	while(*input) {
		/* skip leading space */
		if(argc != index) {
			while(isspace(*input))
				input++;
		}
			
		/* expand argv */
		if(argc >= maxargc - 1) {
			maxargc *= 2;
			argv = (char **) realloc (argv, maxargc * sizeof (char *));
			argv[argc] = NULL;
		}
		
		/* scan next field */
		end = buffer;
		
		while(*input) {
			if(argc == index) {
				*end++ = *input++;
				
				continue;
			}
			
			if(isspace(*input) && !squote && !dquote && !bsquote)
				break;
			
			if(bsquote) {
				bsquote = 0;
				*end++ = *input;
			}
			else if(squote) {
				if(*input == '\'')
					squote = 0;
				else
					*end++ = *input;
			}
			else if(dquote) {
				if(*input == '"')
					dquote = 0;
				else
					*end++ = *input;
			}
			else {
				if(*input == '\'')
					squote = 1;
				else if(*input == '"')
					dquote = 1;
				else if(*input == '\\')
					bsquote = 1;
				else
					*end++ = *input;
			}
			
			input++;
		}
	
		*end = '\0';
		
		/* enter field */
		argv[argc] = strdup(buffer);
		argc++;
		argv[argc] = NULL;

		/* skip tailing space */
		if(argc != index) {
			while(isspace(*input))
				input++;
		}
	}

	*argc_out = argc;
	*argv_out = argv;
	
	free(buffer);
}



void wr_argv_create_wired(char *input, int *argc_out, char ***argv_out) {
	char		**argv;
	char		*buffer, *end;
	int			argc = 0, maxargc = 8;
	
	buffer = (char *) malloc(strlen(input) + 1);
	argv = (char **) malloc(maxargc * sizeof(char *));

	do {
		/* expand argv */
		if(argc >= maxargc - 1) {
			maxargc *= 2;
			argv = (char **) realloc (argv, maxargc * sizeof (char *));
			argv[argc] = NULL;
		}
		
		/* scan next field */
		end = buffer;
		
		while(*input && *input != 28)
			*end++ = *input++;
			
		*end = '\0';
		
		/* enter field */
		argv[argc] = strdup(buffer);
		argc++;
		argv[argc] = NULL;
	} while(*input++);

	*argc_out = argc;
	*argv_out = argv;
	
	free(buffer);
}



void wr_argv_free(int argc, char **argv) {
	int			i;
	
	for(i = 0; i < argc; i++)
		free(argv[i]);
	
	free(argv);
}



#pragma mark -

#ifndef HAVE_STRSEP

/*      $OpenBSD: strsep.c,v 1.5 2003/06/11 21:08:16 deraadt Exp $        */

/*-
 * Copyright (c) 1990, 1993
 *      The Regents of the University of California.  All rights reserved.
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
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

char * strsep(char **stringp, const char *delim) {
	char		*s;
	const char	*spanp;
	int			c, sc;
	char		*tok;

	if((s = *stringp) == NULL)
		return NULL;

	for(tok = s;;) {
		c		= *s++;
		spanp	= delim;

		do {
			if((sc = *spanp++) == c) {
				if(c == 0)
					s = NULL;
				else
					s[-1] = 0;

				*stringp = s;

				return tok;
			}
		} while(sc != 0);
	}
	/* NOTREACHED */
}

#endif



#ifndef HAVE_STRCASESTR

/* $FreeBSD: /repoman/r/ncvs/src/lib/libc/string/strsep.c,v 1.5 2002/03/21 18:44:54 obrien Exp $ */

/*-
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Chris Torek.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

char * strcasestr(const char *s, const char *find) {
	char	c, sc;
	size_t	len;

	if((c = *find++) != 0) {
		c	= tolower((unsigned char) c);
		len	= strlen(find);

		do {
			do {
				if((sc = *s++) == 0)
					return NULL;
			} while((char) tolower((unsigned char) sc) != c);
		} while(strncasecmp(s, find, len) != 0);

		s--;
	}

	return ((char *) s);
}

#endif



#ifndef HAVE_STRLCAT

/*	$OpenBSD: strlcat.c,v 1.11 2003/06/17 21:56:24 millert Exp $	*/

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

size_t strlcat(char *dst, const char *src, size_t siz) {
	register char *d		= dst;
	register const char *s	= src;
	register size_t n		= siz;
	size_t					dlen;

	while(n-- != 0 && *d != '\0')
		d++;

	dlen	= d - dst;
	n		= siz - dlen;

	if(n == 0)
		return (dlen + strlen(s));

	while(*s != '\0') {
		if(n != 1) {
			*d++ = *s;
			n--;
		}
		s++;
	}

	*d = '\0';

	return (dlen + (s - src));
}

#endif



#ifndef HAVE_STRLCPY

/*	$OpenBSD: strlcpy.c,v 1.7 2003/04/12 21:56:39 millert Exp $	*/

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND TODD C. MILLER DISCLAIMS ALL
 * WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL TODD C. MILLER BE LIABLE
 * FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

size_t strlcpy(char *dst, const char *src, size_t siz) {
	register char *d		= dst;
	register const char *s	= src;
	register size_t n		= siz;

	if(n != 0 && --n != 0) {
		do {
			if((*d++ = *s++) == 0)
				break;
		} while (--n != 0);
	}

	if(n == 0) {
		if (siz != 0)
			*d = '\0';
		while(*s++)
			;
	}

	return(s - src - 1);
}

#endif



#ifndef HAVE_VASPRINTF
#ifdef HAVE_VPRINTF

int vasprintf(char **buffer, const char *fmt, va_list ap) {
	FILE	*tmp;
	int		bytes;

	tmp = tmpfile();

	if(!tmp)
		goto err;

	bytes = vfprintf(tmp, fmt, ap);

	if(bytes < 0)
		goto err;

	*buffer = (char *) malloc(bytes + 1);

	if(!*buffer)
		goto err;

	fseek(tmp, 0, SEEK_SET);
	fread(*buffer, 1, bytes, tmp);
	fclose(tmp);

	(*buffer)[bytes] = '\0';

	return bytes;

err:
	if(tmp)
		fclose(tmp);

	*buffer = NULL;

	return -1;
}

#endif
#endif
