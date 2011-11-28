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

#ifndef WT_TRACKER_H
#define WT_TRACKER_H 1

#define WT_SERVER_PORT				2000
#define WT_TRACKER_PORT				2002

#define WT_MESSAGE_SEPARATOR		'\4'
#define WT_MESSAGE_SEPARATOR_STR	"\4"
#define WT_FIELD_SEPARATOR			'\34'
#define WT_GROUP_SEPARATOR			'\35'
#define WT_RECORD_SEPARATOR			'\36'


void								wt_tracker_init(void);
void								wt_tracker_create_threads(void);
void								wt_tracker_apply_settings(void);

void								wt_ssl_init(void);

void								wt_reply(unsigned int, wi_string_t *, ...);

#endif /* WT_TRACKER_H */