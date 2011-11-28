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

#import "WCTopic.h"

@interface WCTopic(Private)

- (void)_setChatID:(unsigned int)chatID;
- (void)_setNick:(NSString *)nick;
- (void)_setLogin:(NSString *)login;
- (void)_setAddress:(NSString *)address;
- (void)_setDate:(NSDate *)date;
- (void)_setTopic:(NSString *)topic;

@end


@implementation WCTopic(Private)

- (void)_setChatID:(unsigned int)chatID {
	_chatID = chatID;
}



- (void)_setNick:(NSString *)nick {
	[nick retain];
	[_nick release];

	_nick = nick;
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



- (void)_setDate:(NSDate *)date {
	[date retain];
	[_date release];

	_date = date;
}



- (void)_setTopic:(NSString *)topic {
	[topic retain];
	[_topic release];

	_topic = topic;
}

@end


@implementation WCTopic

+ (id)topicWithArguments:(NSArray *)arguments {
	WCTopic		*topic;
	
	topic = [[self alloc] init];
	[topic _setChatID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	[topic _setNick:[arguments safeObjectAtIndex:1]];
	[topic _setLogin:[arguments safeObjectAtIndex:2]];
	[topic _setAddress:[arguments safeObjectAtIndex:3]];
	[topic _setDate:[NSDate dateWithISO8601String:[arguments safeObjectAtIndex:4]]];
	[topic _setTopic:[arguments safeObjectAtIndex:5]];
	
	return [topic autorelease];
}



- (void)dealloc {
	[_nick release];
	[_login release];
	[_address release];
	[_date release];
	[_topic release];

	[super dealloc];
}


#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	WIDecode(coder, _chatID);
	WIDecode(coder, _nick);
	WIDecode(coder, _login);
	WIDecode(coder, _address);
	WIDecode(coder, _date);
	WIDecode(coder, _topic);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _chatID);
	WIEncode(coder, _nick);
	WIEncode(coder, _login);
	WIEncode(coder, _address);
	WIEncode(coder, _date);
	WIEncode(coder, _topic);
}



#pragma mark -

- (unsigned int)chatID {
	return _chatID;
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


- (NSDate *)date {
	return _date;
}



- (NSString *)topic {
	return _topic;
}

@end
