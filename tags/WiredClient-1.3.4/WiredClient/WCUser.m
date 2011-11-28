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

#import "WCUser.h"

@interface WCUser(Private)

- (void)_setChatID:(WCChatID)chatID;
- (void)_setUserID:(WCUserID)userID;
- (void)_setLogin:(NSString *)login;
- (void)_setAddress:(NSString *)address;
- (void)_setHost:(NSString *)host;
- (void)_setJoinDate:(NSDate *)joinDate;

@end


@implementation WCUser(Private)

- (void)_setChatID:(WCChatID)chatID {
	_chatID = chatID;
}



- (void)_setUserID:(WCUserID)userID {
	_userID = userID;
}



- (void)_setLogin:(NSString *)login {
	[login retain];
	[_login release];

	_login = login;
}



- (void)_setAddress:(NSString *)address {
	[address retain];
	[_address release];

	_address = address;
}


- (void)_setHost:(NSString *)host {
	[host retain];
	[_host release];

	_host = host;
}



- (void)_setJoinDate:(NSDate *)joinDate {
	[joinDate retain];
	[_joinDate release];

	_joinDate = joinDate;
}

@end


@implementation WCUser

+ (id)userWithArguments:(NSArray *)arguments {
	NSData			*data;
	NSImage			*image;
	WCUser			*user;
	NSSize			size;

	user = [[self alloc] init];
	[user _setChatID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[user _setUserID:[[arguments safeObjectAtIndex:1] unsignedIntValue]];
	[user setIdle:[[arguments safeObjectAtIndex:2] isEqualToString:@"1"]];
	[user setAdmin:[[arguments safeObjectAtIndex:3] isEqualToString:@"1"]];
	[user setNick:[arguments safeObjectAtIndex:5]];
	[user _setLogin:[arguments safeObjectAtIndex:6]];
	[user _setAddress:[arguments safeObjectAtIndex:7]];
	[user _setHost:[arguments safeObjectAtIndex:8]];
	[user setStatus:[arguments safeObjectAtIndex:9]];
	[user _setJoinDate:[NSDate date]];

	data = [NSData dataWithBase64EncodedString:[arguments safeObjectAtIndex:10]];
	image = [[NSImage alloc] initWithData:data];
	
	if(image) {
		size = [image size];
		
		if(size.width > 0.0 && size.height > 0.0)
			[user setIcon:image];

		[image release];
	}

	return [user autorelease];
}



- (void)dealloc {
	[_nick release];
	[_login release];
	[_address release];
	[_host release];
	[_status release];
	[_icon release];
	[_joinDate release];

	[super dealloc];
}


#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(typeof(_chatID)) at:&_chatID];
	[coder decodeValueOfObjCType:@encode(typeof(_userID)) at:&_userID];
	[coder decodeValueOfObjCType:@encode(typeof(_idle)) at:&_idle];
	[coder decodeValueOfObjCType:@encode(typeof(_admin)) at:&_admin];

	_nick		= [[coder decodeObject] retain];
	_login		= [[coder decodeObject] retain];
	_address	= [[coder decodeObject] retain];
	_host		= [[coder decodeObject] retain];
	_status		= [[coder decodeObject] retain];
	_icon		= [[coder decodeObject] retain];
	_joinDate	= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(typeof(_chatID)) at:&_chatID];
	[coder encodeValueOfObjCType:@encode(typeof(_userID)) at:&_userID];
	[coder encodeValueOfObjCType:@encode(typeof(_idle)) at:&_idle];
	[coder encodeValueOfObjCType:@encode(typeof(_admin)) at:&_admin];

	[coder encodeObject:_nick];
	[coder encodeObject:_login];
	[coder encodeObject:_address];
	[coder encodeObject:_host];
	[coder encodeObject:_status];
	[coder encodeObject:_icon];
	[coder encodeObject:_joinDate];
}



#pragma mark -

- (BOOL)isEqual:(id)object {
	if(![self isKindOfClass:[object class]])
		return NO;
	
	return [self userID] == [object userID];
}



- (NSUInteger)hash {
	return [self userID];
}



#pragma mark -

- (void)setIdle:(BOOL)value {
	_idle = value;
}



- (void)setAdmin:(BOOL)value {
	_admin = value;
}



- (void)setIcon:(NSImage *)icon {
	[icon retain];
	[_icon release];

	_icon = icon;
}



- (void)setNick:(NSString *)nick {
	[nick retain];
	[_nick release];

	_nick = nick;
}



- (void)setStatus:(NSString *)status {
	[status retain];
	[_status release];

	_status = status;
}



#pragma mark -

- (WCChatID)chatID {
	return _chatID;
}



- (WCUserID)userID {
	return _userID;
}



- (BOOL)isIdle {
	return _idle;
}



- (BOOL)isAdmin {
	return _admin;
}



- (NSImage *)icon {
	return _icon;
}



- (NSImage *)iconWithIdleTint:(BOOL)value {
	return _idle && value
		? [_icon tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]]
		: _icon;
}



- (NSString *)nick {
	return _nick;
}



- (NSString *)login {
	return _login;
}



- (NSString *)address {
	return _address;
}



- (NSString *)host {
	return _host;
}



- (NSString *)status {
	return _status;
}



- (NSDate *)joinDate {
	return _joinDate;
}



#pragma mark -

- (NSColor *)color {
	if([self isIdle] && [self isAdmin])
		return [NSColor colorWithCalibratedHue:0.0 saturation:0.5 brightness:1.0 alpha:1.0];
	else if([self isIdle])
		return [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.5 alpha:1.0];
	else if([self isAdmin])
		return [NSColor colorWithCalibratedHue:0.0 saturation:1.0 brightness:1.0 alpha:1.0];

	return [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.0 alpha:1.0];
}



- (BOOL)isIgnored {
	NSEnumerator	*enumerator;
	NSDictionary	*ignore;
	BOOL			nick, login, address;

	enumerator = [[WCSettings objectForKey:WCIgnores] objectEnumerator];

	while((ignore = [enumerator nextObject])) {
		nick = login = address = NO;

		if([[ignore objectForKey:WCIgnoresNick] isEqualToString:[self nick]] ||
		   [[ignore objectForKey:WCIgnoresNick] isEqualToString:@""])
			nick = YES;

		if([[ignore objectForKey:WCIgnoresLogin] isEqualToString:[self login]] ||
		   [[ignore objectForKey:WCIgnoresLogin] isEqualToString:@""])
			login = YES;

		if([[ignore objectForKey:WCIgnoresAddress] isEqualToString:[self address]] ||
		   [[ignore objectForKey:WCIgnoresAddress] isEqualToString:@""])
			address = YES;

		if(nick && login && address)
			return YES;
	}

	return NO;
}



#pragma mark -

- (NSComparisonResult)compareNick:(WCUser *)user {
	return [[self nick] compare:[user nick] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareJoinDate:(WCUser *)user {
	return [[self joinDate] compare:[user joinDate]];
}

@end
