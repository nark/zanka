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

#import "WCClient.h"
#import "WCSecureSocket.h"
#import "WCTracker.h"
#import "WCTrackers.h"

@implementation WCTracker

- (id)initWithType:(unsigned int)type {
	self = [super init];
	
	// --- get parameters
	_type = type;
	
	switch(_type) {
		case WCTrackerTypeRendezvous:
			_children = [[NSMutableArray alloc] init];
			break;
	}

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_name release];
	[_description release];
	[_service release];
	[_url release];
	[_children release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_count];

	_name			= [[coder decodeObject] retain];
	_description	= [[coder decodeObject] retain];
	_service		= [[coder decodeObject] retain];
	_url			= [[coder decodeObject] retain];
	_children		= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_count];
	
	[coder encodeObject:_name];
	[coder encodeObject:_description];
	[coder encodeObject:_service];
	[coder encodeObject:_url];
	[coder encodeObject:_children];
}



#pragma mark -

- (void)setType:(unsigned int)value {
	_type = value;
}



- (unsigned int)type {
	return _type;
}



#pragma mark -

- (void)setCount:(unsigned int)value {
	_count = value;
}



- (unsigned int)count {
	return _count;
}



#pragma mark -

- (void)setName:(NSString *)value {
	[value retain];
	[_name release];
	
	_name = value;
}



- (NSString *)name {
	return _name;
}



#pragma mark -

- (void)setDescription:(NSString *)value {
	[value retain];
	[_description release];
	
	_description = value;
}



- (NSString *)description {
	return _description;
}



#pragma mark -

- (void)setService:(NSNetService *)value {
	[value retain];
	[_service release];
	
	_service = value;
}



- (NSNetService *)service {
	return _service;
}



#pragma mark -

- (void)setURL:(NSURL *)value {
	[value retain];
	[_url release];
	
	_url = value;
}



- (NSURL *)URL {
	return _url;
}



#pragma mark -

- (void)addChild:(WCTracker *)child {
	[_children addObject:child];
}



- (void)removeChild:(WCTracker *)child {
	[_children removeObject:child];
}



- (NSMutableArray *)children {
	return _children;
}



#pragma mark -

- (NSComparisonResult)nameSort:(WCTracker *)other {
	// --- sort by name
	return [_name compare:[other name] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)descriptionSort:(WCTracker *)other {
	NSComparisonResult		result;
	
	result = [_description compare:[other description] options:NSCaseInsensitiveSearch];
	
	// --- ordered same - sort by name instead
	if(result == NSOrderedSame)
		result = [self nameSort:other];
		
	return result;
}

@end
