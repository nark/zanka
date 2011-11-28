/* $Id$ */

/*
 *  Copyright (c) 2011 Axel Andersson
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

#ifndef WR_TOPIC_H
#define WR_TOPIC_H 1

#include "users.h"

typedef struct _wr_topic			wr_topic_t;


void								wr_topics_init(void);

wr_topic_t *						wr_topic_with_message(wi_p7_message_t *);
wr_topic_t *						wr_topic_with_user(wr_user_t *);

wr_topic_t *						wr_topic_alloc(void);
wr_topic_t *						wr_topic_init_with_message(wr_topic_t *, wi_p7_message_t *);
wr_topic_t *						wr_topic_init_with_user(wr_topic_t *, wr_user_t *);

wi_string_t *						wr_topic_user_nick(wr_topic_t *);
wi_string_t *						wr_topic_topic(wr_topic_t *);
wi_date_t *							wr_topic_time(wr_topic_t *);

#endif /* WR_TOPIC_H */
