/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "ZANotification.h"

@implementation ZANotification

static Class	concreteNotificationClass;

+ (void)initialize {
	if(!concreteNotificationClass)
		concreteNotificationClass = [ZANotification class];
}



+ (NSNotification*)notificationWithName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
	ZANotification		*notification;
	
	notification = (ZANotification *) NSAllocateObject(self, 0, NSDefaultMallocZone());
	notification->_name = [name copyWithZone:[self zone]];
	notification->_object = [object retain];
	notification->_userInfo = [userInfo retain];
	
	return [notification autorelease];
}



- (id)copyWithZone:(NSZone *)zone {
	ZANotification		*notification;
	
	if(NSShouldRetainWithZone(self, zone))
		return [self retain];
	
	notification = (ZANotification *) NSAllocateObject(concreteNotificationClass, 0, NSDefaultMallocZone());
	notification->_name = [_name copyWithZone:[self zone]];
	notification->_object = [_object retain];
	notification->_userInfo = [_userInfo retain];
	
	return notification;
}



- (void)dealloc {
	[_name release];
	[_object release];
	[_userInfo release];
	
	[super dealloc];
}



- (NSString *)name {
	return _name;
}



- (id)object {
	return _object;
}



- (NSDictionary *)userInfo {
	return _userInfo;
}

@end
