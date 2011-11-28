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

#import "WCTracker.h"

@interface WCTracker(Private)

- (id)_initWithType:(WCTrackerType)type;

- (void)_setIcon:(NSImage *)icon;
- (void)_setName:(NSString *)name;
- (void)_setServerDescription:(NSString *)serverDescription;
- (void)_setUsers:(NSUInteger)users;
- (void)_setSpeed:(NSUInteger)speed;
- (void)_setFiles:(NSUInteger)files;
- (void)_setSize:(WIFileOffset)size;
- (void)_setGuest:(BOOL)value;
- (void)_setDownload:(BOOL)value;
- (void)_setURL:(WIURL *)url;
- (void)_setNetService:(NSNetService *)netService;

- (NSComparisonResult)_compareName:(WCTracker *)tracker;

@end


@implementation WCTracker(Private)

- (id)_initWithType:(WCTrackerType)type {
	self = [super init];

	_type = type;

	if([self type] != WCTrackerServer)
		_children = [[NSMutableArray alloc] init];

	return self;
}



#pragma mark -

- (void)_setIcon:(NSImage *)icon {
	[icon retain];
	[_icon release];

	_icon = icon;
}



- (void)_setName:(NSString *)value {
	[value retain];
	[_name release];

	_name = value;
}



- (void)_setServerDescription:(NSString *)value {
	[value retain];
	[_serverDescription release];

	_serverDescription = value;
}



- (void)_setUsers:(NSUInteger)users {
	_users = users;
}



- (void)_setSpeed:(NSUInteger)speed {
	_speed = speed;
}



- (void)_setFiles:(NSUInteger)files {
	_files = files;
}



- (void)_setSize:(WIFileOffset)size {
	_size = size;
}



- (void)_setGuest:(BOOL)guest {
	_guest = guest;
}



- (void)_setDownload:(BOOL)download {
	_download = download;
}



- (void)_setURL:(WIURL *)value {
	[value retain];
	[_url release];

	_url = value;
}



- (void)_setNetService:(NSNetService *)value {
	[value retain];
	[_netService release];

	_netService = value;
}



#pragma mark -

- (NSComparisonResult)_compareName:(WCTracker *)tracker {
	return [[self name] compare:[tracker name] options:NSCaseInsensitiveSearch];
}

@end


@implementation WCTracker

+ (id)bonjourTracker {
	WCTracker	*tracker;
	
	tracker = [[self alloc] _initWithType:WCTrackerBonjour];
	[tracker _setName:@"Bonjour"];
	[tracker _setIcon:[NSImage imageNamed:@"Bonjour"]];

	return [tracker autorelease];
}



+ (id)bonjourServerWithNetService:(NSNetService *)netService {
	WCTracker	*server;
	
	server = [[self alloc] _initWithType:WCTrackerServer];
	[server _setName:[netService name]];
	[server _setNetService:netService];
	
	return [server autorelease];
}



+ (id)trackerWithBookmark:(NSDictionary *)bookmark {
	WCTracker	*tracker;
	
	tracker = [[self alloc] _initWithType:WCTrackerTracker];
	[tracker _setName:[bookmark objectForKey:WCTrackerBookmarksName]];
	[tracker _setURL:[WIURL URLWithString:[bookmark objectForKey:WCTrackerBookmarksAddress] scheme:@"wiredtracker"]];
	
	return [tracker autorelease];
}



+ (id)trackerCategoryWithName:(NSString *)name {
	WCTracker	*category;
	
	category = [[self alloc] _initWithType:WCTrackerCategory];
	[category _setName:name];
	
	return [category autorelease];
}



+ (id)trackerServerWithArguments:(NSArray *)arguments {
	WCTracker		*server;
	
	server = [[self alloc] _initWithType:WCTrackerServer];
	[server _setURL:[WIURL URLWithString:[arguments safeObjectAtIndex:1] scheme:@"wired"]];
	[server _setName:[arguments safeObjectAtIndex:2]];
	[server _setUsers:[[arguments safeObjectAtIndex:3] unsignedIntValue]];
	[server _setSpeed:[[arguments safeObjectAtIndex:4] unsignedIntValue]];
	[server _setGuest:([[arguments safeObjectAtIndex:5] unsignedIntValue] == 1)];
	[server _setDownload:([[arguments safeObjectAtIndex:6] unsignedIntValue] == 1)];
	[server _setFiles:[[arguments safeObjectAtIndex:7] unsignedIntValue]];
	[server _setSize:[[arguments safeObjectAtIndex:8] unsignedLongLongValue]];
	[server _setServerDescription:[arguments safeObjectAtIndex:9]];

	return [server autorelease];
}



- (void)dealloc {
	[_name release];
	[_serverDescription release];
	[_url release];
	[_netService release];

	[_children release];

	[super dealloc];
}



#pragma mark -

- (void)setState:(WCTrackerState)value {
	_state = value;
}



- (WCTrackerState)state {
	return _state;
}



- (void)setProtocol:(double)value {
	_protocol = value;
}



- (double)protocol {
	return _protocol;
}



#pragma mark -

- (WCTrackerType)type {
	return _type;
}



- (NSImage *)icon {
	return _icon;
}



- (NSString *)name {
	return _name;
}



- (NSString *)nameWithNumberOfServers {
	return [self nameWithNumberOfServersMatchingFilter:NULL];
}



- (NSString *)nameWithNumberOfServersMatchingFilter:(NSString *)filter {
	if(_type == WCTrackerCategory || _type == WCTrackerTracker)
		return [NSSWF:@"%@ (%lu)", [self name], [self numberOfServersMatchingFilter:filter]];

	return [self name];
}



- (NSString *)serverDescription {
	return _serverDescription;
}



- (NSUInteger)users {
	return _users;
}



- (NSUInteger)speed {
	return _speed;
}



- (NSUInteger)files {
	return _files;
}



- (WIFileOffset)size {
	return _size;
}



- (BOOL)guest {
	return _guest;
}



- (BOOL)download {
	return _download;
}



- (WIURL *)URL {
	return _url;
}



- (NSNetService *)netService {
	return _netService;
}



- (BOOL)matchesFilter:(NSString *)filter {
	if(!filter || [filter length] == 0)
		return YES;
	
	if([_name rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound)
		return YES;

	if(_serverDescription && [_serverDescription rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound)
		return YES;
	
	return NO;
}



#pragma mark -

- (void)addChild:(WCTracker *)child {
	[_children addObject:child];
}



- (void)removeChild:(WCTracker *)child {
	[_children removeObject:child];
}



- (void)removeAllChildren {
	[_children removeAllObjects];
}



- (NSEnumerator *)childEnumerator {
	return [_children objectEnumerator];
}



- (void)sortChildrenUsingSelector:(SEL)selector {
	NSEnumerator	*enumerator;
	WCTracker		*tracker;
	
	enumerator = [self childEnumerator];
	
	while((tracker = [enumerator nextObject]))
		[tracker sortChildrenUsingSelector:selector];
	
	[_children sortUsingSelector:selector];
}



- (NSArray *)childrenMatchingFilter:(NSString *)filter {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	WCTracker			*child;

	if(!filter || [filter length] == 0)
		return _children;

	array = [NSMutableArray array];
	enumerator = [self childEnumerator];

	while((child = [enumerator nextObject])) {
		if([child type] == WCTrackerCategory || [child matchesFilter:filter])
			[array addObject:child];
	}

	return array;
}



#pragma mark -

- (WCTracker *)categoryWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCTracker		*child;
	
	enumerator = [self childEnumerator];
	
	while((child = [enumerator nextObject])) {
		if([child type] == WCTrackerCategory && [[child name] isEqualToString:name])
			return child;
	}
	
	return NULL;
}



- (WCTracker *)categoryForPath:(NSString *)path {
	NSEnumerator	*enumerator;
	NSArray			*components;
	NSString		*component;
	WCTracker		*child, *category;
	
	components	= [path componentsSeparatedByString:@"/"];

	if([components count] == 0)
		return self;
	
	category = self;
	enumerator = [components objectEnumerator];
	
	while((component = [enumerator nextObject])) {
		child = [category categoryWithName:component];
		
		if(!child)
			break;
		
		category = child;
	}
	
	return category;
}



- (NSUInteger)numberOfServers {
	return [self numberOfServersMatchingFilter:NULL];
}



- (NSUInteger)numberOfServersMatchingFilter:(NSString *)filter {
	NSEnumerator		*enumerator;
	WCTracker			*child;
	NSUInteger			count = 0;
	
	enumerator = [self childEnumerator];
	
	while((child = [enumerator nextObject])) {
		if([child type] == WCTrackerCategory)
			count += [child numberOfServersMatchingFilter:filter];
		else if([child type] == WCTrackerServer && [child matchesFilter:filter])
			count++;
	}
	
	return count;
}



#pragma mark -

- (NSComparisonResult)compareType:(WCTracker *)tracker {
	if([self type] == WCTrackerServer && [tracker type] != WCTrackerServer)
		return NSOrderedDescending;
	else if([self type] == WCTrackerCategory && [tracker type] != WCTrackerCategory)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareName:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareUsers:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self users] > [tracker users])
			return NSOrderedDescending;
		else if([self users] < [tracker users])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareSpeed:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self speed] > [tracker speed])
			return NSOrderedDescending;
		else if([self speed] < [tracker speed])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareGuest:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self guest] && ![tracker guest])
			return NSOrderedDescending;
		else if(![self guest] && [tracker guest])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareDownload:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self download] && ![tracker download])
			return NSOrderedDescending;
		else if(![self download] && [tracker download])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareFiles:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self files] > [tracker files])
			return NSOrderedDescending;
		else if([self files] < [tracker files])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareSize:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame) {
		if([self size] > [tracker size])
			return NSOrderedDescending;
		else if([self size] < [tracker size])
			return NSOrderedAscending;
	}
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}



- (NSComparisonResult)compareDescription:(WCTracker *)tracker {
	NSComparisonResult		result;
	
	result = [self compareType:tracker];
	
	if(result == NSOrderedSame)
		result = [[self serverDescription] compare:[tracker serverDescription] options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self _compareName:tracker];
	
	return result;
}

@end
