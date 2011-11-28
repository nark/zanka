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

#import "WCMessage.h"
#import "WCUser.h"

@interface WCMessage(Private)

- (id)_initWithType:(WCMessageType)type direction:(WCMessageDirection)direction;

- (void)_setUserID:(unsigned int)userID;
- (void)_setMessage:(NSString *)message;
- (void)_setDate:(NSDate *)date;

@end


@implementation WCMessage(Private)

- (id)_initWithType:(WCMessageType)type direction:(WCMessageDirection)direction {
	self = [super init];

	_type = type;
	_direction = direction;

	return self;
}



#pragma mark -

- (void)_setUserID:(unsigned int)userID {
	_userID = userID;
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

@end


@implementation WCMessage

+ (id)messageWithArguments:(NSArray *)arguments {
	WCMessage	*message;

	message = [[self alloc] _initWithType:WCMessagePrivateMessage direction:WCMessageFrom];
	[message _setUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[message _setMessage:[arguments safeObjectAtIndex:1]];
	[message _setDate:[NSDate date]];
	
	return [message autorelease];
}



+ (id)broadcastWithArguments:(NSArray *)arguments {
	WCMessage	*message;

	message = [[self alloc] _initWithType:WCMessageBroadcast direction:WCMessageFrom];
	[message _setUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[message _setMessage:[arguments safeObjectAtIndex:1]];
	[message _setDate:[NSDate date]];
	
	return [message autorelease];
}



+ (id)messageToUser:(WCUser *)user string:(NSString *)string {
	WCMessage	*message;
	
	message = [[self alloc] _initWithType:WCMessagePrivateMessage direction:WCMessageTo];
	[message _setUserID:[user userID]];
	[message _setDate:[NSDate date]];
	[message _setMessage:string];
	
	[message setUser:user];
	[message setRead:YES];

	return [message autorelease];
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

	WIDecode(coder, _type);
	WIDecode(coder, _direction);
	WIDecode(coder, _userID);
	WIDecode(coder, _read);
	WIDecode(coder, _user);
	WIDecode(coder, _message);
	WIDecode(coder, _date);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _type);
	WIEncode(coder, _direction);
	WIEncode(coder, _userID);
	WIEncode(coder, _read);
	WIEncode(coder, _user);
	WIEncode(coder, _message);
	WIEncode(coder, _date);
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
		[self user],
		[self date]];
}



#pragma mark -

- (WCMessageType)type {
	return _type;
}



- (WCMessageDirection)direction {
	return _direction;
}



- (unsigned int)userID {
	return _userID;
}



- (NSString *)message {
	return _message;
}



- (NSDate *)date {
	return _date;
}



- (void)setUser:(WCUser *)user {
	[user retain];
	[_user release];
	
	_user = user;
}



- (WCUser *)user {
	return _user;
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
	
	result = [[self user] compareNick:[message user]];
	
	if(result != NSOrderedSame)
		return result;
	
	return [self compareDate:message];
}



- (NSComparisonResult)compareDate:(WCMessage *)message {
	return [[self date] compare:[message date]];
}

@end
