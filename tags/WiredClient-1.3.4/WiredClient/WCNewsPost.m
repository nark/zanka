/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "WCNewsPost.h"

@interface WCNewsPost(Private)

- (id)_initNewsPostWithArguments:(NSArray *)arguments;

@end


@implementation WCNewsPost(Private)

- (id)_initNewsPostWithArguments:(NSArray *)arguments {
	self = [self init];
	
	_userNick	= [[arguments safeObjectAtIndex:0] retain];
	_date		= [arguments safeObjectAtIndex:1] ? [[[WIDateFormatter dateFormatterForRFC3339] dateFromString:[arguments safeObjectAtIndex:1]] retain] : NULL;
	_message	= [[arguments safeObjectAtIndex:2] retain];
	
	if(!_userNick || !_date || !_message) {
		NSLog(@"*** WCNewsPost: invalid arguments: %@", arguments);
		
		[self release];
		
		return NULL;
	}

	return self;
}

@end



@implementation WCNewsPost

+ (id)newsPostWithArguments:(NSArray *)arguments {
	return [[[self alloc] _initNewsPostWithArguments:arguments] autorelease];
}



- (void)dealloc {
	[_userNick release];
	[_date release];
	[_message release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)userNick {
	return _userNick;
}



- (NSDate *)date {
	return _date;
}



- (NSString *)message {
	return _message;
}

@end
