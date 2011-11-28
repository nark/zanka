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

#import "NSNumberAdditions.h"
#import "WCTracker.h"
#import "WCTrackers.h"

@implementation WCTracker

- (id)initWithType:(WCTrackerType)type {
	self = [super init];
	
	// --- get parameters
	_type = type;
	
	// --- create array
	if(_type != WCTrackerTypeServer)
		_children = [[NSMutableArray alloc] init];

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
	
	[coder decodeValueOfObjCType:@encode(WCTrackerType) at:&_type];
	[coder decodeValueOfObjCType:@encode(WCTrackerState) at:&_state];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_count];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_users];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_guest];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_download];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_files];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_size];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_protocol];

	_name			= [[coder decodeObject] retain];
	_description	= [[coder decodeObject] retain];
	_service		= [[coder decodeObject] retain];
	_url			= [[coder decodeObject] retain];
	_children		= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(WCTrackerType) at:&_type];
	[coder encodeValueOfObjCType:@encode(WCTrackerState) at:&_state];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_count];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_guest];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_download];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_files];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_size];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_protocol];
	
	[coder encodeObject:_name];
	[coder encodeObject:_description];
	[coder encodeObject:_service];
	[coder encodeObject:_url];
	[coder encodeObject:_children];
}



#pragma mark -

- (void)setType:(WCTrackerType)value {
	_type = value;
}



- (WCTrackerType)type {
	return _type;
}



#pragma mark -

- (void)setState:(WCTrackerState)value {
	_state = value;
}



- (WCTrackerState)state {
	return _state;
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

- (void)setUsers:(unsigned int)value {
	_users = value;
}



- (unsigned int)users {
	return _users;
}



#pragma mark -

- (void)setSpeed:(unsigned int)value {
	_speed = value;
}



- (unsigned int)speed {
	return _speed;
}



#pragma mark -

- (void)setGuest:(BOOL)value {
	_guest = value;
}



- (BOOL)guest {
	return _guest;
}



#pragma mark -

- (void)setDownload:(BOOL)value {
	_download = value;
}



- (BOOL)download {
	return _download;
}



#pragma mark -

- (void)setFiles:(unsigned int)value {
	_files = value;
}



- (unsigned int)files {
	return _files;
}



#pragma mark -

- (void)setSize:(unsigned long long)value {
	_size = value;
}



- (unsigned long long)size {
	return _size;
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

- (void)setProtocol:(double)value {
	_protocol = value;
}



- (double)protocol {
	return _protocol;
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



- (unsigned int)servers {
	NSEnumerator		*enumerator;
	WCTracker			*child;
	unsigned int		count = 0;

	// --- loop over children
	enumerator = [_children objectEnumerator];
	
	while((child = [enumerator nextObject])) {
		if([child type] == WCTrackerTypeCategory)
			count += [child servers];
		else if([child type] == WCTrackerTypeServer)
			count++;
	}

	return count;
}



- (NSMutableArray *)filteredChildren:(NSString *)filter {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSRange				range;
	WCTracker			*child;
	
	// --- return unfiltered
	if(!filter || [filter length] == 0)
		return _children;
	
	// --- loop over children
	array = [NSMutableArray array];
	enumerator = [_children objectEnumerator];
	
	while((child = [enumerator nextObject])) {
		// --- let categories through
		if([child type] == WCTrackerTypeCategory) {
			[array addObject:child];
			
			continue;
		}

		// --- search in server names
		range = [[child name] rangeOfString:filter options:NSCaseInsensitiveSearch];
		
		if(range.length > 0) {
			[array addObject:child];
			
			continue;
		}
		
		// --- search in server descriptions names
		range = [[child description] rangeOfString:filter options:NSCaseInsensitiveSearch];
		
		if(range.length > 0) {
			[array addObject:child];
			
			continue;
		}
	}
	
	return array;
}



- (void)sortChildrenUsingSelector:(SEL)selector {
	NSEnumerator	*enumerator;
	WCTracker		*tracker;
	
	enumerator = [_children objectEnumerator];
	
	while((tracker = [enumerator nextObject]))
		[tracker sortChildrenUsingSelector:selector];
	
	[_children sortUsingSelector:selector];
}



#pragma mark -

- (NSComparisonResult)nameSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- sort by name
	return [_name compare:[other name] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)speedSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by speed
	if(_speed > [other speed])
		return NSOrderedAscending;
	else if(_speed < [other speed])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)usersSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by users
	if(_users > [other users])
		return NSOrderedAscending;
	else if(_users < [other users])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)guestSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by guest access
	if(_guest && ![other guest])
		return NSOrderedAscending;
	else if(!_guest && [other guest])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)downloadSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by guest access
	if(_download && ![other download])
		return NSOrderedAscending;
	else if(!_download && [other download])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)filesSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by files
	if(_files > [other files])
		return NSOrderedAscending;
	else if(_files < [other files])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)sizeSort:(WCTracker *)other {
	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	// --- then sort by size
	if(_size > [other size])
		return NSOrderedAscending;
	else if(_size < [other size])
		return NSOrderedDescending;
	
	// --- ordered same - sort by name instead
	return [self nameSort:other];
}



- (NSComparisonResult)descriptionSort:(WCTracker *)other {
	NSComparisonResult		result;

	// --- categories before servers
	if(_type == WCTrackerTypeServer && [other type] != WCTrackerTypeServer)
		return NSOrderedDescending;
	else if(_type == WCTrackerTypeCategory && [other type] != WCTrackerTypeCategory)
		return NSOrderedAscending;
	
	result = [_description compare:[other description] options:NSCaseInsensitiveSearch];
	
	// --- ordered same - sort by name instead
	if(result == NSOrderedSame)
		result = [self nameSort:other];
		
	return result;
}

@end
