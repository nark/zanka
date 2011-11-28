/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import <WiredAdditions/NSNumber-WIAdditions.h>

@implementation NSNumber(WINumberAdditions)

+ (NSNumber *)numberWithTimeval:(struct timeval)tv {
	double		d;

	d = tv.tv_sec + ((double) tv.tv_usec / 1000000.0);

	return [NSNumber numberWithDouble:d];
}



- (struct timeval)timevalValue {
	struct timeval	tv;
	double			d;

	d = [self doubleValue];
	tv.tv_sec = (time_t) floor(d);
	tv.tv_usec = (suseconds_t) ((d - tv.tv_sec) * 1000000.0);

	return tv;
}



#pragma mark -

#if MAC_OS_X_VERSION_10_5 > MAC_OS_X_VERSION_MAX_ALLOWED

+ (NSNumber *)numberWithInteger:(NSInteger)integer {
	return [self numberWithInt:integer];
}



+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)integer {
	return [self numberWithUnsignedInt:integer];
}



- (id)initWithInteger:(NSInteger)integer {
	return [self initWithInt:integer];
}



- (id)initWithUnsignedInteger:(NSUInteger)integer {
	return [self initWithUnsignedInt:integer];
}



- (NSInteger)integerValue {
	return [self intValue];
}



- (NSInteger)unsignedIntegerValue {
	return [self unsignedIntValue];
}

#endif

@end
