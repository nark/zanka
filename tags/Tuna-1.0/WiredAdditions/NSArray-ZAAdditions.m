/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import <ZankaAdditions/NSArray-ZAAdditions.h>

@implementation NSArray(ZAArrayAdditions)

- (NSString *)stringAtIndex:(unsigned int)index {
	if(index < [self count])
		return [self objectAtIndex:index];
	
	return @"";
}



- (id)safeObjectAtIndex:(unsigned int)index {
	if(index < [self count])
		return [self objectAtIndex:index];
	
	return NULL;
}



#pragma mark -

- (int)indexOfString:(NSString *)string {
	return [self indexOfString:string options:0];
}



- (int)indexOfString:(NSString *)string options:(int)options {
	NSEnumerator	*enumerator;
	NSRange			range;
	id				object;
	int				i = 0;

	enumerator = [self objectEnumerator];

	while((object = [enumerator nextObject])) {
		if([object isKindOfClass:[NSString class]]) {
			range = [object rangeOfString:string options:options];
			
			if(range.location != NSNotFound)
				return i;
		}
		
		i++;
	}

	return -1;
}



- (BOOL)containsString:(NSString *)string {
	return ([self indexOfString:string options:0] >= 0);
}



- (BOOL)containsString:(NSString *)string options:(int)options {
	return ([self indexOfString:string options:options] >= 0);
}



- (NSArray *)stringsMatchingString:(NSString *)string {
	return [self stringsMatchingString:string options:0];
}



- (NSArray *)stringsMatchingString:(NSString *)string options:(int)options {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	NSRange			range;
	id				object;
	
	array = [NSMutableArray array];
	enumerator = [self objectEnumerator];
	
	while((object = [enumerator nextObject])) {
		if([object isKindOfClass:[NSString class]]) {
			range = [object rangeOfString:string options:options];
			
			if(range.location != NSNotFound)
				[array addObject:object];
		}
	}
	
	return array;
}


- (void)makeObjectsPerformSelector:(SEL)selector withObject:(id)object1 withObject:(id)object2 {
	NSEnumerator	*enumerator;
	id				object;

	enumerator = [self objectEnumerator];

	while((object = [enumerator nextObject]))
		objc_msgSend(object, selector, object1, object2);
}



- (void)makeObjectsPerformSelector:(SEL)selector withBool:(BOOL)value {
	NSEnumerator	*enumerator;
	id				object;

	enumerator = [self objectEnumerator];

	while((object = [enumerator nextObject]))
		objc_msgSend(object, selector, value);
}



- (NSArray *)subarrayFromIndex:(unsigned int)index {
	return [self subarrayWithRange:NSMakeRange(index, [self count] - index)];
}



- (NSArray *)reversedArray {
	NSEnumerator	*enumerator;
	NSMutableArray  *array;
	id				object;
	
	array = [NSMutableArray array];
	enumerator = [self reverseObjectEnumerator];
	
	while((object = [enumerator nextObject]))
		[array addObject:object];

	return array;
}



#pragma mark -


- (NSNumber *)minimumNumber {
	NSEnumerator	*enumerator;
	NSNumber		*number = NULL;
	id				object;
	
	enumerator = [self objectEnumerator];
	
	while((object = [enumerator nextObject])) {
		if([object isKindOfClass:[NSNumber class]]) {
			if(!number)
				number = object;
			else if([object unsignedLongLongValue] < [number unsignedLongLongValue])
				number = object;
		}
	}
	
	return number;
}



- (NSNumber *)maximumNumber {
	NSEnumerator	*enumerator;
	NSNumber		*number = NULL;
	id				object;
	
	enumerator = [self objectEnumerator];
	
	while((object = [enumerator nextObject])) {
		if([object isKindOfClass:[NSNumber class]]) {
			if(!number)
				number = object;
			else if([object unsignedLongLongValue] > [number unsignedLongLongValue])
				number = object;
		}
	}
	
	return number;
}

@end



@implementation NSArray(ZADeepMutableCopying)

- (NSMutableArray *)deepMutableCopyWithZone:(NSZone *)zone {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	id				object, copy;
	
	array = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
	enumerator = [self objectEnumerator];
	
	while((object = [enumerator nextObject])) {
		copy = [object deepMutableCopyWithZone:zone];
		[array addObject:copy];
		[copy release];
	}
	
	return array;
}

@end



@implementation NSMutableArray(ZAMutableArrayAdditions)

- (void)moveObjectAtIndex:(unsigned int)from toIndex:(unsigned int)to {
	id		object;

	if(from != to) {
		object = [self objectAtIndex:from];

		[object retain];
		[self removeObjectAtIndex:from];
		[self insertObject:object atIndex:to <= from ? to : to - 1];
		[object release];
	}
}



- (void)reverseArray {
	[self setArray:[self reversedArray]];
}

@end