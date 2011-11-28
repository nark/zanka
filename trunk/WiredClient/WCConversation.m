/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "WCConversation.h"
#import "WCUser.h"

@interface WCConversation(Private)

- (id)_initWithType:(WCMessageType)type user:(WCUser *)user connection:(WCServerConnection *)connection;

@end


@implementation WCConversation(Private)

- (id)_initWithType:(WCMessageType)type user:(WCUser *)user connection:(WCServerConnection *)connection {
	self = [super init];
	
	_type = type;
	_key = [[[self class] keyForType:type user:user connection:connection] retain];
	_userNick = [[user nick] retain];
	
	return self;
}

@end


@implementation WCConversation

+ (NSString *)keyForType:(WCMessageType)type user:(WCUser *)user connection:(WCServerConnection *)connection {
	return [NSSWF:@"%d_%u_%lu", type, [user userID], [connection connectionID]];
}



#pragma mark -

+ (id)messageConversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithType:WCMessagePrivateMessage user:user connection:connection] autorelease];
}



+ (id)broadcastConversationWithUser:(WCUser *)user connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithType:WCMessageBroadcast user:user connection:connection] autorelease];
}



#pragma mark -

- (void)dealloc {
	[_key release];
	[_userNick release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(typeof(_type)) at:&_type];

	_key		= [[coder decodeObject] retain];
	_userNick	= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(typeof(_type)) at:&_type];
	[coder encodeObject:_key];
	[coder encodeObject:_userNick];
}



#pragma mark -

- (NSString *)description {
	NSString	*type = @"";
	
	switch([self type]) {
		case WCMessagePrivateMessage:
			type = @"message";
			break;
			
		case WCMessageBroadcast:
			type = @"broadcast";
			break;
	}
	
	return [NSSWF:@"<%@ %p>{type = %@, user = %@}",
		[self className],
		self,
		type,
		[self userNick]];
}



- (BOOL)isEqual:(id)object {
	if(![self isKindOfClass:[object class]])
		return NO;
	
	return [[self key] isEqualToString:[object key]];
}



- (NSUInteger)hash {
	return [[self key] hash];
}



#pragma mark -

- (WCMessageType)type {
	return _type;
}



- (NSString *)key {
	return _key;
}



- (NSString *)userNick {
	return _userNick;
}

@end
