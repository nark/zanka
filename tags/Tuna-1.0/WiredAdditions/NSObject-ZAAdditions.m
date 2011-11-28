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

#import <ZankaAdditions/NSInvocation-ZAAdditions.h>
#import <ZankaAdditions/NSObject-ZAAdditions.h>
#import <ZankaAdditions/NSThread-ZAAdditions.h>

@implementation NSObject(ZAObjectPropertylistSerialization)

- (BOOL)isKindOfPropertyListSerializableClass {
	return ([self isKindOfClass:[NSData class]] ||
			[self isKindOfClass:[NSDate class]] ||
			[self isKindOfClass:[NSNumber class]] ||
			[self isKindOfClass:[NSString class]] ||
			[self isKindOfClass:[NSArray class]] ||
			[self isKindOfClass:[NSDictionary class]]);
}

@end



@implementation NSObject(ZAObjectAdditions)

+ (NSBundle *)bundle {
	return [NSBundle bundleForClass:self];
}



- (NSBundle *)bundle {
	return [[self class] bundle];
}



#pragma mark -

- (void)performSelectorOnce:(SEL)selector afterDelay:(NSTimeInterval)delay {
	[self performSelectorOnce:selector withObject:NULL afterDelay:delay];
}



- (void)performSelectorOnce:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:NULL];
	[self performSelector:selector withObject:object afterDelay:delay];
}

@end



@implementation NSObject(ZADeepMutableCopying)

- (id)deepMutableCopy {
	return [self deepMutableCopyWithZone:NULL];
}



- (id)deepMutableCopyWithZone:(NSZone *)zone {
	if([self respondsToSelector:@selector(mutableCopyWithZone:)])
		return [(id) self mutableCopyWithZone:zone];
	else if([self respondsToSelector:@selector(copyWithZone:)])
		return [(id) self copyWithZone:zone];
	
	return NULL;
}

@end




@implementation NSObject(ZAThreadScheduling)

- (void)performSelectorOnMainThread:(SEL)action {
	[self performSelectorOnMainThread:action withObject:NULL waitUntilDone:NO];
}



- (void)performSelectorOnMainThread:(SEL)action withObject:(id)object1 {
	[self performSelectorOnMainThread:action withObject:object1 waitUntilDone:NO];
}



- (void)performSelectorOnMainThread:(SEL)action withObject:(id)object1 withObject:(id)object2 {
	NSInvocation	*invocation;
	
	if([NSThread isMainThread]) {
		[self performSelector:action withObject:object1 withObject:object2];
	} else {
		invocation = [NSInvocation invocationWithTarget:self action:action];
		[invocation setArgument:&object1 atIndex:2];
		[invocation setArgument:&object2 atIndex:3];
		[self performInvocationOnMainThread:invocation];
	}
}



- (void)performSelectorOnMainThread:(SEL)action withObject:(id)object1 withObject:(id)object2 withObject:(id)object3 {
	NSInvocation	*invocation;
	
	invocation = [NSInvocation invocationWithTarget:self action:action];
	[invocation setArgument:&object1 atIndex:2];
	[invocation setArgument:&object2 atIndex:3];
	[invocation setArgument:&object3 atIndex:4];
	
	if([NSThread isMainThread])
		[invocation invoke];
	else
		[self performInvocationOnMainThread:invocation];
}



- (void)performInvocationOnMainThread:(NSInvocation *)invocation {
	[invocation retainArguments];
	[invocation performSelectorOnMainThread:@selector(invoke) withObject:NULL waitUntilDone:NO];
}

@end
