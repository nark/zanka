/* $Id$ */

/*
 *  Copyright (c) 2004-2011 Axel Andersson
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

#ifndef WR_IGNORES_H
#define WR_IGNORES_H 1

typedef wi_uinteger_t				wr_iid_t;

typedef struct _wr_ignore			wr_ignore_t;


void								wr_ignores_init(void);
wi_boolean_t						wr_is_ignored(wi_string_t *);

char *								wr_readline_ignore_generator(const char *, int);

wr_ignore_t *						wr_ignore_alloc(void);
wr_ignore_t *						wr_ignore_init_with_string(wr_ignore_t *, wi_string_t *);

wr_iid_t							wr_ignore_id(wr_ignore_t *);
wi_string_t *						wr_ignore_string(wr_ignore_t *);
wi_boolean_t						wr_ignore_match(wr_ignore_t *, wi_string_t *);

wr_ignore_t *						wr_ignore_with_iid(wr_iid_t);
wr_ignore_t *						wr_ignore_with_string(wi_string_t *);


extern wi_mutable_array_t			*wr_ignores;

#endif /* WR_IGNORES_H */
