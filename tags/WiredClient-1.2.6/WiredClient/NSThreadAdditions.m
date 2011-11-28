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

#import "NSThreadAdditions.h"

@implementation NSThread(WCScheduling)

static NSThread						*mainThread;
static NSPortDelegateObject			*mainThreadPortDelegate;


+ (void)load {
	[NSThread setMainThread];
}



+ (void)setMainThread {
	NSPort		*port;
	
	mainThreadPortDelegate = [[NSPortDelegateObject alloc] init];
	
	port = [[NSPort alloc] init];
	[port setDelegate:mainThreadPortDelegate];
	[port scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	mainThread = [NSThread currentThread];
	[[mainThread threadDictionary] setObject:port forKey:NSThreadPortKey];
	
	[port release];
}



+ (NSThread *)mainThread {
	return mainThread;
}



+ (BOOL)isMainThread {
	return ([NSThread currentThread] == mainThread);
}

@end



@implementation NSObject(WCScheduling)

- (void)performSelectorOnMainThread:(SEL)selector {
	if([NSThread isMainThread]) {
		[self performSelector:selector];
	} else {
		[self performSelectorOnMainThread:selector withObject:NULL withObject:NULL withObject:NULL];
	}
}



- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)object1 {
	if([NSThread isMainThread]) {
		[self performSelector:selector withObject:object1];
	} else {
		[self performSelectorOnMainThread:selector withObject:object1 withObject:NULL withObject:NULL];
	}
}



- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)object1 withObject:(id)object2 {
	if([NSThread isMainThread]) {
		[self performSelector:selector withObject:object1 withObject:object2];
	} else {
		[self performSelectorOnMainThread:selector withObject:object1 withObject:object2 withObject:NULL];
	}
}



- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)object1 withObject:(id)object2 withObject:(id)object3 {
	NSInvocation				*invocation;
	NSPortMessage				*portMessage;
	NSPort						*port;
	NSMutableData				*data;
	struct NSInvocationMessage	*message;
	
	invocation = [NSInvocation invocationWithMethodSignature:
		[self methodSignatureForSelector:selector]];
	[invocation setTarget:self];
	[invocation setSelector:selector];
	
	if(object3) {
		[invocation setArgument:&object1 atIndex:2];
		[invocation setArgument:&object2 atIndex:3];
		[invocation setArgument:&object3 atIndex:4];
	}
	else if(object2) {
		[invocation setArgument:&object1 atIndex:2];
		[invocation setArgument:&object2 atIndex:3];
	}
	else if(object1) {
		[invocation setArgument:&object1 atIndex:2];
	}

	[invocation retainArguments];
	[invocation retain];
	
	data = [NSMutableData dataWithLength:sizeof(struct NSInvocationMessage)];
	message = (struct NSInvocationMessage *) [data mutableBytes];
	message->invocation = invocation;
	
	port = [[[NSThread mainThread] threadDictionary] objectForKey:NSThreadPortKey];
	portMessage = [[NSPortMessage alloc] initWithSendPort:port
											  receivePort:NULL
											   components:[NSArray arrayWithObjects:data, NULL]];
	[portMessage sendBeforeDate:[NSDate distantFuture]];
	[portMessage release];
}

@end



@implementation NSPortDelegateObject

- (void)handlePortMessage:(NSPortMessage *)portMessage {
	NSData						*data;
	NSInvocation				*invocation;
	struct NSInvocationMessage  *message;
	
	data = [[portMessage components] objectAtIndex:0];
	message = (struct NSInvocationMessage *) [data bytes];
	invocation = message->invocation;

	[invocation invoke];
	[invocation release];
}

@end
