/* $Id$ */

/*
 *  Copyright (c) 2005-2007 Axel Andersson
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

#import "WCApplicationController.h"
#import "WCLink.h"
#import "WCTracker.h"
#import "WCTrackerConnection.h"
#import "WCTrackers.h"

@interface WCTrackerConnection(Private)

- (id)_initTrackerConnectionWithURL:(WIURL *)url tracker:(WCTracker *)tracker;

@end


@implementation WCTrackerConnection(Private)

- (id)_initTrackerConnectionWithURL:(WIURL *)url tracker:(WCTracker *)tracker {
	self = [super init];
	
	[self retain];
	
	_tracker = [tracker retain];
	
	_link = [[WCLink alloc] initLinkWithURL:url];
	[_link setDelegate:self];

	_notificationCenter = [[NSNotificationCenter alloc] init];
	
	[self addObserver:self
			 selector:@selector(connectionDidConnect:)
				 name:WCConnectionDidConnect];
	
	[self addObserver:self
			 selector:@selector(connectionShouldTerminate:)
				 name:WCConnectionShouldTerminate];

	[self addObserver:self
			 selector:@selector(connectionDidTerminate:)
				 name:WCConnectionDidTerminate];
	
	[self addObserver:self
			 selector:@selector(connectionDidClose:)
				 name:WCConnectionDidClose];
	
	[self addObserver:self
			 selector:@selector(trackerConnectionReceivedTrackerInfo:)
				 name:WCTrackerConnectionReceivedTrackerInfo];
	
	return self;
}

@end


@implementation WCTrackerConnection

+ (id)trackerConnectionWithURL:(WIURL *)url tracker:(WCTracker *)tracker {
	return [[[self alloc] _initTrackerConnectionWithURL:url tracker:tracker] autorelease];
}




- (void)dealloc {
	[self removeObserver:self];
	
	[_tracker release];

	[_notificationCenter release];
	
	[super dealloc];
}



#pragma mark -

- (void)connectionDidConnect:(NSNotification *)notification {
	[_link sendCommand:WCHelloCommand];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	[self postNotificationName:WCConnectionWillTerminate object:self];

	if(_link && [_link isReading])
		[_link terminate];
	else
		[self postNotificationName:WCConnectionDidTerminate object:self];
}



- (void)connectionDidTerminate:(NSNotification *)notification {
	[_link release];
	_link = NULL;
	
	[self autorelease];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[_link release];
	_link = NULL;
}



- (void)trackerConnectionReceivedTrackerInfo:(NSNotification *)notification {
	NSArray		*fields;
	NSString	*version, *protocol, *name, *description, *started;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	version		= [fields safeObjectAtIndex:0];
	protocol	= [fields safeObjectAtIndex:1];
	name		= [fields safeObjectAtIndex:2];
	description = [fields safeObjectAtIndex:3];
	started		= [fields safeObjectAtIndex:4];
	
	[_tracker setProtocol:[protocol doubleValue]];
	
	[_link sendCommand:WCClientCommand withArgument:[[WCApplicationController sharedController] clientVersion]];
	[_link sendCommand:WCCategoriesCommand];
	[_link sendCommand:WCServersCommand];
}



#pragma mark -

- (void)addObserver:(id)target selector:(SEL)action name:(NSString *)name {
	[_notificationCenter addObserver:target selector:action name:name object:NULL];
}



- (void)removeObserver:(id)target {
	[_notificationCenter removeObserver:target];
}



- (void)removeObserver:(id)target name:(NSString *)name {
	[_notificationCenter removeObserver:target name:name object:NULL];
}



- (void)postNotificationName:(NSString *)name {
	[_notificationCenter mainThreadPostNotificationName:name];
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name];
}



- (void)postNotificationName:(NSString *)name object:(id)object {
	[_notificationCenter mainThreadPostNotificationName:name object:object];
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name object:object];
}



- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
	[_notificationCenter mainThreadPostNotificationName:name object:object userInfo:userInfo];
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name object:object];
}



#pragma mark -

- (void)sendCommand:(NSString *)command {
	[_link sendCommand:command];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 {
	[_link sendCommand:command withArgument:argument1];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 {
	[_link sendCommand:command withArgument:argument1 withArgument:argument2];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3 {
	[_link sendCommand:command withArgument:argument1 withArgument:argument2 withArgument:argument3];
}



- (void)sendCommand:(NSString *)command withArguments:(NSArray *)arguments {
	[_link sendCommand:command withArguments:arguments];
}



- (void)ignoreError:(WCProtocolMessage)error {
	_ignoreErrorMessage	= error;
	_ignoreErrorTime	= [NSDate timeIntervalSinceReferenceDate];
}



#pragma mark -

- (void)linkConnected:(WCLink *)link {
	[self postNotificationName:WCConnectionDidConnect object:self];
}



- (void)linkClosed:(WCLink *)link error:(WNError *)error {
	if(error)
		[self postNotificationName:WCConnectionDidClose object:self userInfo:[NSDictionary dictionaryWithObject:error forKey:WCErrorKey]];
	else
		[self postNotificationName:WCConnectionDidClose object:self];
}



- (void)linkTerminated:(WCLink *)link {
	[self postNotificationName:WCConnectionDidTerminate object:self];
}



- (void)link:(WCLink *)link sentCommand:(NSString *)command {
	[self postNotificationName:WCConnectionSentCommand object:command];
}



- (void)link:(WCLink *)link receivedMessage:(WCProtocolMessage)message arguments:(NSArray *)arguments {
	NSString				*name = NULL;
	NSMutableDictionary		*userInfo;
	WCError					*error;
	
	userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		arguments,							WCArgumentsKey,
		[NSNumber numberWithInt:message],	WCMessageKey,
		NULL];

	switch(message) {
		case 200:
			name = WCTrackerConnectionReceivedTrackerInfo;
			break;
			
		case 710:
			name = WCTrackersReceivedCategory;
			break;

		case 711:
			name = WCTrackersCompletedCategories;
			break;

		case 720:
			name = WCTrackersReceivedServer;
			break;

		case 721:
			name = WCTrackersCompletedServers;
			break;

		default:
			if(message >= 500 && message <= 599) {
				if(_ignoreErrorMessage != message || _ignoreErrorTime < [NSDate timeIntervalSinceReferenceDate] - 5.0) {
					name = WCConnectionReceivedError;
					error = [WCError errorWithDomain:WCWiredErrorDomain
												code:message
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												[arguments safeObjectAtIndex:0],	WIArgumentErrorKey,
												NULL]];
					
					[userInfo setObject:error forKey:WCErrorKey];
				}
				
				_ignoreErrorMessage = 0;
			}
			break;
	}

#if defined(DEBUG) || defined(TEST)
	[self postNotificationName:WCConnectionReceivedMessage
						object:[NSSWF:@"%u %@", message, [arguments componentsJoinedByString:@"\t"]]];
#endif

	if(name)
		[self postNotificationName:name object:self userInfo:userInfo];
}



#pragma mark -

- (void)connect {
	[_link connect];
}



- (void)disconnect {
	[_link disconnect];
}



- (void)terminate {
	[self postNotificationName:WCConnectionShouldTerminate object:self];
}



#pragma mark -

- (WIURL *)URL {
	return [_link URL];
}



- (WNSocket *)socket {
	return [_link socket];
}



- (BOOL)isConnected {
	return (_link != NULL);
}



- (double)protocol {
	return [_tracker protocol];
}



#pragma mark -

- (WCTracker *)tracker {
	return _tracker;
}

@end
