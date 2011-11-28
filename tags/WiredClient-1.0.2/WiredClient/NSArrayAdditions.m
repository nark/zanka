/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSArrayAdditions.h"
#import "WCTracker.h"

@implementation NSArray(WCServerFilter)

- (NSArray *)serverFilter:(NSString *)filter {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSRange				range;
	WCTracker			*item;
	
	// --- return self if no filter
	if(!filter || [filter length] == 0)
		return self;

	// --- get a mutable array
	array = [NSMutableArray array];
	
	// --- get an enumerator
	enumerator = [self objectEnumerator];
	
	// --- loop and insert matching items
	while((item = [enumerator nextObject])) {
		range = [[item name] rangeOfString:filter options:NSCaseInsensitiveSearch];
		
		if(range.length > 0) {
			[array addObject:item];
			
			continue;
		}
		
		range = [[item description] rangeOfString:filter options:NSCaseInsensitiveSearch];
		
		if(range.length > 0) {
			[array addObject:item];
			
			continue;
		}
	}
	
	return [NSArray arrayWithArray:array];
}



- (unsigned int)serverCount {
	NSEnumerator	*enumerator;
	WCTracker		*item;
	unsigned int	count = 0;
	
	// --- get an enumerator
	enumerator = [self objectEnumerator];
	
	// --- loop and add
	while((item = [enumerator nextObject]))
		count++;

	return count;
}

@end