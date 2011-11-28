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

#ifdef HAVE_CARBON_CARBON_H
#include <Carbon/Carbon.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <syslog.h>
#include <openssl/md5.h>
#include <openssl/bio.h>
#include <openssl/evp.h>

#include "main.h"
#include "server.h"
#include "settings.h"
#include "utility.h"


void wd_expand_path(char *out, char *path, size_t length) {
	if(path[0] == '/')
		strlcpy(out, path, length);
	else if(wd_chroot)
		snprintf(out, length, "/%s", path);
	else
		snprintf(out, length, "%s/%s", wd_root, path);
}



void wd_time_to_iso8601(time_t value, char *out, size_t length) {
	struct tm	tm;
	char		date[20], offset[7];
	
	/* get time */
	localtime_r(&value, &tm);
	
	/* get offset */
	strftime(offset, sizeof(offset), "%z", &tm);
	
	/* transpose it */
	if(strlen(offset) == 5) {
		offset[6] = '\0';
		offset[5] = offset[4];
		offset[4] = offset[3];
		offset[3] = ':';
	}
	
	/* get rest of date */
	strftime(date, sizeof(date), "%Y-%m-%dT%H:%M:%S", &tm);
	
	/* write out */
	snprintf(out, length, "%s%s", date, offset);
}



char * wd_base64_encode(char *path) {
	BIO				*bio, *b64;
	FILE			*fp, *tmp;
	char			*data = NULL, buffer[BUFSIZ], *p;
	int				data_size, data_offset, length, bytes;

	/* get a temp file */
	tmp = tmpfile();

	/* create BIOs */
	b64	= BIO_new(BIO_f_base64());
	bio = BIO_new_fp(tmp, BIO_NOCLOSE);
	bio = BIO_push(b64, bio);
	
	/* open source */
	fp = fopen(path, "r");
	
	if(!fp) {
		wd_log(LOG_ERR, "Could not open %s: %s",
			path, strerror(errno));
	
		goto end;
	}
	
	/* write source to BIO */
	while((bytes = fread(buffer, 1, sizeof(buffer), fp)))
		BIO_write(bio, buffer, bytes);

	fclose(fp);

	/* release BIO */
	BIO_flush(bio);
	BIO_free_all(bio);

	/* start over on temp file */
	rewind(tmp);

	/* init data pointer to hold output */
	data_size = WD_BASE64_INITIAL_SIZE;
	data = (char *) malloc(data_size);
	memset(data, 0, data_size);
	data_offset = 0;

	/* read from temp file */
	while(fgets(buffer, sizeof(buffer), tmp)) {
		/* remove the linebreak if any */
		if((p = strchr(buffer, '\n')) != NULL)
			*p = '\0';
		
		/* get length */
		length = strlen(buffer);

		/* expand? */
		if(data_offset + length >= data_size) {
			data_size += length;
			data = (char *) realloc(data, data_size);
		}

		/* append to banner */
		strlcat(data + data_offset, buffer, data_size - data_offset);
		data_offset += length;
	}
	
end:
	if(fp)
		fclose(fp);
		
	if(tmp)
		fclose(tmp);

	return data;
}



#pragma mark -

#ifdef HAVE_CARBON_CARBON_H

bool wd_apple_is_invisible(char *path) {
	CFStringRef			string;
	CFURLRef			url;
	LSItemInfoRecord	itemInfoRecord;
	
	/* create CFURL from path */
	string	= CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
	url		= CFURLCreateWithFileSystemPath(NULL, string, kCFURLPOSIXPathStyle, false);
	
	/* get LS info */
	LSCopyItemInfoForURL(url, kLSRequestBasicFlagsOnly, &itemInfoRecord);
	
	CFRelease(string);
	CFRelease(url);

	return itemInfoRecord.flags & kLSItemInfoIsInvisible;
}

#endif



#ifdef HAVE_CORESERVICES_CORESERVICES_H

/*
	The Apple alias functions are based on work by Devin Teske,
	devinteske@hotmail.com. Used with permission.
*/

bool wd_apple_is_alias(char *path) {
	FSRef		fsRef;
	Boolean		isDir, isAlias;

	if(wd_chroot)
		return false;
	
	if(FSPathMakeRef(path, &fsRef, NULL) != 0)
		return false;
			
	if(FSIsAliasFile(&fsRef, &isAlias, &isDir) != 0)
		return false;
	
	return isAlias;
}



int wd_apple_resolve_alias(char *dst, char *src, size_t size) {
	FSRef		fsPath;
	Boolean		isDir, isAlias;
	
	strlcpy(dst, src, size);
	
	if(!wd_chroot) {
		if(FSPathMakeRef(src, &fsPath, NULL) != 0)
			return -1;
			
		if(FSIsAliasFile(&fsPath, &isAlias, &isDir) != 0)
			return -1;
	
		if(FSResolveAliasFile(&fsPath, true, &isDir, &isAlias) != 0)
			return -1;
	
		if(FSRefMakePath(&fsPath, dst, size) != 0)
			return -1;
	}

	return 1;
}



int wd_apple_resolve_alias_path(char *src, char *dst, size_t size) {
	char	temp[MAXPATHLEN], resolved[MAXPATHLEN];
	int		i;

	strlcpy(dst, src, size);

	if(!wd_chroot) {
		memset(resolved, 0, sizeof(resolved));
		memset(temp, 0, sizeof(temp));
	
		while(*src) {
			strlcpy(temp, resolved, sizeof(temp));
			i = strlen(temp);
	
			if(*resolved)
				temp[i++] = '/';
	
			while(*src && *src != '/')
				temp[i++] = *src++;
	
			temp[i] = '\0';
	
			if(*src == '/') {
				while(*src == '/')
					src++;
			}
	
			if(wd_apple_resolve_alias(resolved, temp, sizeof(resolved)) < 0)
				return -1;
		}
	
		strlcpy(dst, resolved, size);
	}
	
	return 1;
}

#endif



#pragma mark -

unsigned int					wd_log_lines;


void wd_log(int priority, char *fmt, ...) {
	FILE		*fp;
	char		*buffer, date[16], path[MAXPATHLEN];
	struct tm	tm;
	time_t		now;
	va_list		ap;
	
	va_start(ap, fmt);
	
	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
		
	/* create a timestamp if needed */
	if(wd_debug || !wd_syslog) {
		now = time(NULL);
		localtime_r(&now, &tm);
		strftime(date, sizeof(date), "%b %e %H:%M:%S", &tm);
	}
	
	/* when debugging, always log to stderr */
	if(wd_debug)
		fprintf(stderr, "%s wired[%d]: %s\n", date, getpid(), buffer);
	
	if(wd_syslog) {
		/* log to syslog */
		syslog(priority, "%s", buffer);
	}
	else if(wd_log_file) {
		/* log to file */
		wd_expand_path(path, wd_log_path, sizeof(path));
		fp = fopen(path, "a");
		
		if(fp) {
			/* write */
			fprintf(fp, "%s wired[%d]: %s\n", date, getpid(), buffer);
			fclose(fp);

			/* truncate? */
			if(wd_log_limit > 0) {
				if(wd_log_lines % (int) ((double) wd_log_limit / 10) == 0) {
					wd_log_truncate(wd_log_limit);
					
					wd_log_lines = wd_log_limit;
				}
			}
			
			/* increase lines */
			wd_log_lines++;
		}
	}
	
	/* log LOG_WARNING and LOG_ERR to stderr during startup */
	if(wd_startup && !wd_debug && (priority == LOG_WARNING || priority == LOG_ERR))
		fprintf(stderr, "wired: %s\n", buffer);
	
	/* exit on LOG_ERR */
	if(wd_startup && priority == LOG_ERR)
		exit(1);

	free(buffer);
}



void wd_log_l(int facility, char *fmt, ...) {
	char		*buffer;
	va_list		ap;
	
	if(wd_log_level < WD_LOG_VERBOSE1)
		return;
	
	va_start(ap, fmt);
	
	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
	
	wd_log(facility, "%s", buffer);
	
	free(buffer);
}



void wd_log_ll(int facility, char *fmt, ...) {
	char		*buffer;
	va_list		ap;
	
	if(wd_log_level < WD_LOG_VERBOSE2)
		return;
	
	va_start(ap, fmt);
	
	if(vasprintf(&buffer, fmt, ap) == -1 || buffer == NULL)
		return;
	
	wd_log(facility, "%s", buffer);
	
	free(buffer);
}



void wd_log_truncate(unsigned int lines) {
	FILE			*fp = NULL, *tmp = NULL;
	struct stat		sb;
	char			buffer[BUFSIZ], path[MAXPATHLEN];
	off_t			position;
	int				n, ch = EOF;
	
	/* get path */
	wd_expand_path(path, wd_log_path, sizeof(path));

	/* get file size */
	if(stat(path, &sb) < 0)
		goto end;
	
	if(sb.st_size == 0)
		goto end;
	
	/* open file */
	fp = fopen(path, "r");
	
	if(!fp)
		goto end;
	
	/* open temporary file */
	tmp = tmpfile();
	
	if(!tmp)
		goto end;
	
	for(position = sb.st_size - 2; lines > 0 && position >= 0; position--) {
		if(fseeko(fp, position, SEEK_SET) < 0)
			goto end;
		
		ch = fgetc(fp);
		
		if(ch == '\n')
			lines--;
		else if(ch == EOF && ferror(fp))
			goto end;
	}
	
	/* put back last char if we read to start of file */
	if(position < 0 && lines > 0 && ch != EOF)
		ungetc(ch, fp);

	/* read the old news file and append it to the temporary file */
	while((n = fread(buffer, 1, sizeof(buffer), fp)))
		fwrite(buffer, 1, n, tmp);
	
	/* reopen the log file as writable */
	fp = freopen(path, "w", fp);
	
	if(!fp)
		goto end;

	/* start over at the beginning of the temporary file */
	rewind(tmp);

	/* now copy the temporary file to the log file */
	while((n = fread(buffer, 1, sizeof(buffer), tmp)))
		fwrite(buffer, 1, n, fp);
	
end:
	/* clean up */
	if(fp)
		fclose(fp);
	
	if(tmp)
		fclose(tmp);
}



#pragma mark -

void wd_list_create(wd_list_t *list) {
	/* init list */
	list->first = list->last = NULL;
	list->count = 0;
	
	pthread_mutex_init(&(list->mutex), NULL);
}



void wd_list_free(wd_list_t *list) {
	wd_list_node_t	*node, *node_next;

	/* clear list */
	WD_LIST_LOCK(*list);
	for(node = WD_LIST_FIRST(*list); node != NULL; node = node_next) {
		node_next = WD_LIST_NEXT(node);
			
		wd_list_delete(list, node);
	}
	WD_LIST_UNLOCK(*list);

	/* free objects */
	pthread_mutex_destroy(&(list->mutex));
}



wd_list_node_t * wd_list_add(wd_list_t *list, void *data) {
	wd_list_node_t		*node;
	
	/* create a node */
	node = (wd_list_node_t *) malloc(sizeof(wd_list_node_t));
	memset(node, 0, sizeof(wd_list_node_t));
	
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



void wd_list_delete(wd_list_t *list, wd_list_node_t *node) {
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



#pragma mark -

void wd_argv_create_wired(char *input, int *argc_out, char ***argv_out) {
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
		
		while(*input && *input != WD_FIELD_SEPARATOR)
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



void wd_argv_free(int argc, char **argv) {
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
		if(siz != 0)
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
