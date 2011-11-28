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
#import "NSImageAdditions.h"
#import "WCIcons.h"
#import "WCSettings.h"
#import "WCUser.h"

@implementation WCUser

- (void)dealloc {
	[_nick release];
	[_login release];
	[_address release];
	[_host release];
	[_joinTime release];
	[_iconImage release];

	[super dealloc];
}


#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_uid];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_idle];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_admin];
	[coder decodeValueOfObjCType:@encode(int) at:&_icon];

	_nick		= [[coder decodeObject] retain];
	_login		= [[coder decodeObject] retain];
	_address	= [[coder decodeObject] retain];
	_host		= [[coder decodeObject] retain];
	_status		= [[coder decodeObject] retain];
	_iconImage	= [[coder decodeObject] retain];
	_joinTime	= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_uid];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_idle];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_admin];
	[coder encodeValueOfObjCType:@encode(int) at:&_icon];
	
	[coder encodeObject:_nick];
	[coder encodeObject:_login];
	[coder encodeObject:_address];
	[coder encodeObject:_host];
	[coder encodeObject:_status];
	[coder encodeObject:_iconImage];
	[coder encodeObject:_joinTime];
}



#pragma mark -

- (void)setUid:(unsigned int)value {
	_uid = value;
}



- (unsigned int)uid {
	return _uid;
}



#pragma mark -

- (void)setIdle:(BOOL)value {
	_idle = value;
}



- (BOOL)idle {
	return _idle;
}



#pragma mark -

- (void)setAdmin:(BOOL)value {
	_admin = value;
}



- (BOOL)admin {
	return _admin;
}



#pragma mark -

- (void)setIcon:(int)value {
	_icon = value;
}



- (void)setIconImage:(NSImage *)value {
	[value retain];
	[_iconImage release];
	
	_iconImage = value;
}



- (NSImage *)icon {
	NSImage		*image;
	
	image = _iconImage
		? _iconImage
		: [WCIcons objectForKey:[NSNumber numberWithInt:_icon]];

	return _idle
		? [image tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]]
		: image;
}



#pragma mark -

- (void)setNick:(NSString *)value {
	[value retain];
	[_nick release];
	
	_nick = value;
}



- (NSString *)nick {
	return _nick;
}



#pragma mark -

- (void)setLogin:(NSString *)value {
	[value retain];
	[_login release];
	
	_login = value;
}



- (NSString *)login {
	return _login;
}



#pragma mark -

- (void)setAddress:(NSString *)value {
	[value retain];
	[_address release];

	_address = value;
}



- (NSString *)address {
	return _address;
}


#pragma mark -

- (void)setHost:(NSString *)value {
	[value retain];
	[_host release];
	
	_host = value;
}



- (NSString *)host {
	return _host;
}



#pragma mark -

- (void)setStatus:(NSString *)value {
	[value retain];
	[_status release];
	
	_status = value;
}



- (NSString *)status {
	return _status;
}



#pragma mark -

- (void)setJoinTime:(NSDate *)value {
	[value retain];
	[_joinTime release];
	
	_joinTime = value;
}



- (NSDate *)joinTime {
	return _joinTime;
}



#pragma mark -

- (NSColor *)color {
	if(_idle && _admin)
		return [NSColor colorWithCalibratedHue:0.0 saturation:0.5 brightness:1.0 alpha:1.0];
	else if(_idle)
		return [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.5 alpha:1.0];
	else if(_admin)
		return [NSColor colorWithCalibratedHue:0.0 saturation:1.0 brightness:1.0 alpha:1.0];
	else
		return [NSColor colorWithCalibratedHue:0.0 saturation:0.0 brightness:0.0 alpha:1.0];
}



- (BOOL)ignore {
	NSEnumerator	*enumerator;
	NSArray			*ignores;
	NSDictionary	*ignore;
	BOOL			nick, login, address;
	
	ignores		= [WCSettings objectForKey:WCIgnores];
	enumerator	= [ignores objectEnumerator];
	
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

- (NSComparisonResult)joinTimeSort:(WCUser *)other {
	return [_joinTime compare:[other joinTime]];
}

@end
