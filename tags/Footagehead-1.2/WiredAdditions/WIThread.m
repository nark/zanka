/* $Id$ */

/*
 *  Copyright (c) 2006 Axel Andersson
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

#import <WiredAdditions/NSInvocation-WIAdditions.h>
#import <WiredAdditions/WIThread.h>

@interface WIThread(Private)

+ (void)_threadTrampoline:(id)arg;

@end


@implementation WIThread(Private)

+ (void)_threadTrampoline:(id)arg {
	NSInvocation	*invocation = arg;

	wi_thread_enter_thread();
	
	[invocation invoke];

	wi_thread_exit_thread();
}

@end


@implementation WIThread

+ (void)detachNewThreadSelector:(SEL)selector toTarget:(id)target withObject:(id)argument {
	NSInvocation	*invocation;
	
	invocation = [NSInvocation invocationWithTarget:target action:selector];
	[invocation setArgument:&argument atIndex:2];
	[invocation retainArguments];
	
	[super detachNewThreadSelector:@selector(_threadTrampoline:) toTarget:self withObject:invocation];
}

@end
