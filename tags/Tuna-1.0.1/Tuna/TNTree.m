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

#import "TNNode.h"
#import "TNTree.h"

@implementation TNTree

- (id)init {
	TNNode		*node;
	
	self = [super init];
	
	_rootNodes = [[NSMutableArray alloc] initWithCapacity:10];
	
	node = [[TNNode alloc] init];
	[_rootNodes addObject:node];
	[node release];
	
	_variables	= [[NSMutableDictionary alloc] initWithCapacity:10];

	return self;
}



- (void)dealloc {
	[_rootNodes release];
	[_variables release];
	
	[super dealloc];
}




#pragma mark -

- (void)pushRootNode:(TNNode *)node {
	[_rootNodes addObject:node];
}



- (void)popRootNode {
	[_rootNodes removeLastObject];
}



- (TNNode *)rootNode {
	return [_rootNodes lastObject];
}



- (void)restoreRootNode {
	while([_rootNodes count] > 1)
		[_rootNodes removeObjectAtIndex:1];
}



- (BOOL)canRestoreRootNode {
	return ([_rootNodes count] > 1);
}



#pragma mark -

- (NSString *)version {
	return [_variables objectForKey:@"XS_VERSION"];
}



- (unsigned int)frequency {
	return [[_variables objectForKey:@"hz"] unsignedIntValue];
}



- (double)userTime {
	double		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (double) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_utime"] unsignedIntValue];
}



- (double)systemTime {
	double		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (double) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_stime"] unsignedIntValue];
}



- (double)wallclockTime {
	double		secondsPerTicks;
	
	secondsPerTicks = 1.0 / (double) [self frequency];
	
	return secondsPerTicks * [[_variables objectForKey:@"rrun_rtime"] unsignedIntValue];
}

@end
