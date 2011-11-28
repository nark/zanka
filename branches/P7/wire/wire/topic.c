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

#include "config.h"

#include <wired/wired.h>

#include "topic.h"

static void							wr_topic_dealloc(wi_runtime_instance_t *);


struct _wr_topic {
	wi_runtime_base_t				base;

	wi_string_t						*user_nick;
	wi_string_t						*topic;
	wi_date_t						*time;
};


static wi_runtime_id_t				wr_topic_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t			wr_topic_runtime_class = {
	"wr_topic_t",
	wr_topic_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wr_topics_init(void) {
	wr_topic_runtime_id = wi_runtime_register_class(&wr_topic_runtime_class);
}



#pragma mark -

wr_topic_t * wr_topic_with_message(wi_p7_message_t *message) {
	return wi_autorelease(wr_topic_init_with_message(wr_topic_alloc(), message));
}



wr_topic_t * wr_topic_with_user(wr_user_t *user) {
	return wi_autorelease(wr_topic_init_with_user(wr_topic_alloc(), user));
}



#pragma mark -

wr_topic_t * wr_topic_alloc(void) {
	return wi_runtime_create_instance(wr_topic_runtime_id, sizeof(wr_topic_t));
}



wr_topic_t * wr_topic_init_with_message(wr_topic_t *topic, wi_p7_message_t *message) {
	topic->user_nick	= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.user.nick")));
	topic->topic		= wi_retain(wi_p7_message_string_for_name(message, WI_STR("wired.chat.topic.topic")));
	topic->time			= wi_retain(wi_p7_message_date_for_name(message, WI_STR("wired.chat.topic.time")));

	return topic;
}



wr_topic_t * wr_topic_init_with_user(wr_topic_t *topic, wr_user_t *user) {
	topic->topic = wi_retain(wr_user_nick(user));

	return topic;
}



static void wr_topic_dealloc(wi_runtime_instance_t *instance) {
	wr_topic_t		*topic = instance;
	
	wi_release(topic->user_nick);
	wi_release(topic->topic);
	wi_release(topic->time);
}



#pragma mark -

wi_string_t * wr_topic_user_nick(wr_topic_t *topic) {
	return topic->user_nick;
}



wi_string_t * wr_topic_topic(wr_topic_t *topic) {
	return topic->topic;
}



wi_date_t * wr_topic_time(wr_topic_t *topic) {
	return topic->time;
}
