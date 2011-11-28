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

#import "WCMessage.h"
#import "WCUser.h"

@interface WCMessage(Private)

- (id)_initWithType:(WCMessageType)type direction:(WCMessageDirection)direction;

- (void)_setUserID:(WCUserID)userID;
- (void)_setUserNick:(NSString *)userNick;
- (void)_setMessage:(NSString *)message;
- (void)_setDate:(NSDate *)date;
- (void)_setConversation:(WCConversation *)conversation;

@end


@implementation WCMessage(Private)

- (id)_initWithType:(WCMessageType)type direction:(WCMessageDirection)direction {
	self = [super init];

	_type = type;
	_direction = direction;

	return self;
}



#pragma mark -

- (void)_setUserID:(WCUserID)userID {
	_userID = userID;
}



- (void)_setUserNick:(NSString *)userNick {
	[userNick retain];
	[_userNick release];

	_userNick = userNick;
}



- (void)_setMessage:(NSString *)message {
	[message retain];
	[_message release];

	_message = message;
}



- (void)_setDate:(NSDate *)date {
	[date retain];
	[_date release];

	_date = date;
}



- (void)_setConversation:(WCConversation *)conversation {
	[conversation retain];
	[_conversation release];

	_conversation = conversation;
}

@end


@implementation WCMessage

+ (id)messageWithArguments:(NSArray *)arguments user:(WCUser *)user conversation:(WCConversation *)conversation {
	WCMessage	*message;

	message = [[self alloc] _initWithType:WCMessagePrivateMessage direction:WCMessageFrom];
	[message _setUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[message _setUserNick:[user nick]];
	[message _setMessage:[arguments safeObjectAtIndex:1]];
	[message _setDate:[NSDate date]];
	[message _setConversation:conversation];
	
	return [message autorelease];
}



+ (id)broadcastWithArguments:(NSArray *)arguments user:(WCUser *)user conversation:(WCConversation *)conversation {
	WCMessage	*message;

	message = [[self alloc] _initWithType:WCMessageBroadcast direction:WCMessageFrom];
	[message _setUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[message _setUserNick:[user nick]];
	[message _setMessage:[arguments safeObjectAtIndex:1]];
	[message _setDate:[NSDate date]];
	[message _setConversation:conversation];
	
	return [message autorelease];
}



+ (id)messageToUser:(WCUser *)user string:(NSString *)string conversation:(WCConversation *)conversation {
	WCMessage	*message;
	
	message = [[self alloc] _initWithType:WCMessagePrivateMessage direction:WCMessageTo];
	[message _setUserID:[user userID]];
	[message _setUserNick:[user nick]];
	[message _setDate:[NSDate date]];
	[message _setMessage:string];
	[message _setConversation:conversation];
	
	[message setRead:YES];

	return [message autorelease];
}



- (void)dealloc {
	[_userNick release];
	[_message release];
	[_date release];
	[_conversation release];

	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(typeof(_type)) at:&_type];
	[coder decodeValueOfObjCType:@encode(typeof(_direction)) at:&_direction];
	[coder decodeValueOfObjCType:@encode(typeof(_userID)) at:&_userID];
	[coder decodeValueOfObjCType:@encode(typeof(_read)) at:&_read];
	
	_userNick		= [[coder decodeObject] retain];
	_message		= [[coder decodeObject] retain];
	_date			= [[coder decodeObject] retain];
	_conversation	= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(typeof(_type)) at:&_type];
	[coder encodeValueOfObjCType:@encode(typeof(_direction)) at:&_direction];
	[coder encodeValueOfObjCType:@encode(typeof(_userID)) at:&_userID];
	[coder encodeValueOfObjCType:@encode(typeof(_read)) at:&_read];
	[coder encodeObject:_userNick];
	[coder encodeObject:_message];
	[coder encodeObject:_date];
	[coder encodeObject:_conversation];
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
	
	return [NSSWF:@"<%@ %p>{type = %@, user = %@, date = %@}",
		[self className],
		self,
		type,
		[self userNick],
		[self date]];
}



#pragma mark -

- (WCMessageType)type {
	return _type;
}



- (WCMessageDirection)direction {
	return _direction;
}



- (WCUserID)userID {
	return _userID;
}



- (NSString *)userNick {
	return _userNick;
}



- (NSString *)message {
	return _message;
}



- (NSDate *)date {
	return _date;
}



- (WCConversation *)conversation {
	return _conversation;
}



- (void)setRead:(BOOL)read {
	_read = read;
}



- (BOOL)isRead {
	return _read;
}



#pragma mark -

- (NSComparisonResult)compareType:(WCMessage *)message {
	if([self type] == WCMessageBroadcast && [message type] != WCMessageBroadcast)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareUser:(WCMessage *)message {
	NSComparisonResult	result;
	
	result = [[self userNick] compare:[message userNick] options:NSCaseInsensitiveSearch];
	
	if(result != NSOrderedSame)
		return result;
	
	return [self compareDate:message];
}



- (NSComparisonResult)compareDate:(WCMessage *)message {
	return [[self date] compare:[message date]];
}

@end
