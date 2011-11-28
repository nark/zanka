/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
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

#import "TNPerlNode.h"
#import "TNPerlTree.h"

@implementation TNPerlTree

+ (Class)nodeClass {
	return [TNPerlNode class];
}



#pragma mark -

- (id)init {
	self = [super init];
	
	_variables	= [[NSMutableDictionary alloc] initWithCapacity:10];

	return self;
}



- (void)dealloc {
	[_variables release];
	
	[super dealloc];
}




#pragma mark -

- (NSString *)version {
	return [_variables objectForKey:@"XS_VERSION"];
}



- (NSUInteger)frequency {
	return [[_variables objectForKey:@"hz"] unsignedIntegerValue];
}



- (NSTimeInterval)userTime {
	NSTimeInterval		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (NSTimeInterval) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_utime"] unsignedIntegerValue];
}



- (NSTimeInterval)systemTime {
	NSTimeInterval		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (NSTimeInterval) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_stime"] unsignedIntegerValue];
}



- (NSTimeInterval)wallclockTime {
	NSTimeInterval		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (NSTimeInterval) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_rtime"] unsignedIntegerValue];
}

@end
