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

#import "NSDateAdditions.h"
#import "WCMessage.h"
#import "WCUser.h"

@implementation WCMessage

- (id)initWithType:(unsigned int)type {
	self = [super init];
	
	// --- get parameters
	_type = type;
	
	return self;
}



- (void)dealloc {
	[_user release];
	[_message release];
    [_date release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_read];

	_user		= [[coder decodeObject] retain];
	_message	= [[coder decodeObject] retain];
    _date		= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_read];
	
	[coder encodeObject:_user];
	[coder encodeObject:_message];
	[coder encodeObject:_date];
}



#pragma mark -

- (void)setType:(unsigned int)value {
	_type = value;
}



- (unsigned int)type {
	return _type;
}



#pragma mark -

- (void)setRead:(BOOL)value {
	_read = value;
}



- (BOOL)read {
	return _read;
}



#pragma mark -

- (void)setUser:(WCUser *)value {
	[value retain];
	[_user release];
	
	_user = value;
}



- (WCUser *)user {
	return _user;
}



#pragma mark -

- (void)setMessage:(NSString *)value {
	[value retain];
	[_message release];
	
	_message = value;
}



- (NSString *)message {
	return _message;
}



#pragma mark -

- (void)setDate:(NSDate *)value {
	[value retain];
	[_date release];
	
	_date = value;
}



- (NSString *)date {
	return [_date localizedDateWithFormat:NSShortTimeDateFormatString];
}

@end
