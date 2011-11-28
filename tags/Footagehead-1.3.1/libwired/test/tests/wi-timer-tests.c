/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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

#include <wired/wired.h>

WI_TEST_EXPORT void						wi_test_timer(void);


#ifdef WI_PTHREADS
static void								_wi_test_timer_function(wi_timer_t *);


static wi_uinteger_t					_wi_test_timer_hits;
#endif


void wi_test_timer(void) {
#ifdef WI_PTHREADS
	wi_timer_t		*timer;
	
	timer = wi_autorelease(wi_timer_init_with_function(wi_timer_alloc(), _wi_test_timer_function, 0.01, false));
	wi_timer_set_data(timer, &_wi_test_timer_hits);
	wi_timer_schedule(timer);
	
	wi_thread_sleep(0.1);
	
	WI_TEST_ASSERT_EQUALS(_wi_test_timer_hits, 5U, "");
#endif
}



#ifdef WI_PTHREADS

static void _wi_test_timer_function(wi_timer_t *timer) {
	wi_uinteger_t		*hits;
	
	hits = wi_timer_data(timer);
	
	if(++(*hits) == 5)
		wi_timer_invalidate(timer);
	else
		wi_timer_schedule(timer);
}

#endif
