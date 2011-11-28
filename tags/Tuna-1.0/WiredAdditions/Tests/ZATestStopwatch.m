/* $Id$ */

/*
 *  Copyright (c) 2005 Axel Andersson
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

#import "ZATestStopwatch.h"

@implementation ZATestStopwatch

- (void)start:(NSString *)fmt, ... {
	va_list		ap;
	
	sleep(3);
	gettimeofday(&_tv, NULL);
	
	va_start(ap, fmt);
	_length = vprintf([fmt UTF8String], ap);
	_length += printf("...");
	fflush(stdout);
	va_end(ap);
}



- (NSTimeInterval)stop {
	return [self stopAndCompare:0.0];
}



- (NSTimeInterval)stopAndCompare:(NSTimeInterval)t1 {
	struct timeval		tv;
	NSTimeInterval		t;
	unsigned int		l;
	
	gettimeofday(&tv, NULL);
	
	t = 1000.0 * ((tv.tv_sec + ((double) tv.tv_usec / 1000000.0)) - (_tv.tv_sec + ((double) _tv.tv_usec / 1000000.0)));
	l = 80 - _length;
	
	if(t1 > 0)
		printf("%*s %.0f ms, %.2f%% increase\n", l, " ", t, 100 * ((t1 / t) - 1));
	else
		printf("%*s %.0f ms\n", l, " ", t);
	
	return t;
}

@end
