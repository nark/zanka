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

WI_TEST_EXPORT void						wi_test_ip(void);


void wi_test_ip(void) {
	WI_TEST_ASSERT_TRUE(wi_ip_matches_string(WI_STR("127.0.0.1"), WI_STR("127.0.0.1")), "");
	WI_TEST_ASSERT_TRUE(wi_ip_matches_string(WI_STR("127.0.0.1"), WI_STR("127.0.0.*")), "");
	WI_TEST_ASSERT_FALSE(wi_ip_matches_string(WI_STR("255.0.0.1"), WI_STR("127.0.0.*")), "");
	WI_TEST_ASSERT_TRUE(wi_ip_matches_string(WI_STR("127.0.0.1"), WI_STR("127.0.0.0/24")), "");
	WI_TEST_ASSERT_FALSE(wi_ip_matches_string(WI_STR("255.0.0.1"), WI_STR("127.0.0.0/24")), "");
	WI_TEST_ASSERT_TRUE(wi_ip_matches_string(WI_STR("::1"), WI_STR("0000:0000:0000:0000:0000:0000:0000:0001")), "");
}
