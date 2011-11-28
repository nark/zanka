/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

- (id)_initWithType:(WCMessageType)type user:(WCUser *)user;

@end


@implementation WCConversation(Private)

- (id)_initWithType:(WCMessageType)type user:(WCUser *)user {
	self = [super init];
	
	_type = type;
	_user = [user retain];
	
	return self;
}

@end


@implementation WCConversation

+ (id)messageConversationWithUser:(WCUser *)user {
	return [[[self alloc] _initWithType:WCMessagePrivateMessage user:user] autorelease];
}



+ (id)broadcastConversationWithUser:(WCUser *)user {
	return [[[self alloc] _initWithType:WCMessageBroadcast user:user] autorelease];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	WIDecode(coder, _type);
	WIDecode(coder, _user);
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _type);
	WIEncode(coder, _user);
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
		[self user]];
}



- (BOOL)isEqual:(id)object {
	if(![self isKindOfClass:[object class]])
		return NO;
	
	return ([self type] == [(WCConversation *) object type]) &&
		   ([[self user] isEqual:[(WCConversation *) object user]]);
}



- (unsigned int)hash {
	return [[self user] hash];
}



#pragma mark -

- (WCMessageType)type {
	return _type;
}



- (WCUser *)user {
	return _user;
}

@end
