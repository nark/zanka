/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "WCLink.h"
#import "WCLinkConnection.h"

NSString * const WCLinkConnectionWillConnectNotification				= @"WCLinkConnectionWillConnectNotification";
NSString * const WCLinkConnectionDidConnectNotification					= @"WCLinkConnectionDidConnectNotification";
NSString * const WCLinkConnectionWillDisconnectNotification				= @"WCLinkConnectionWillDisconnectNotification";
NSString * const WCLinkConnectionDidCloseNotification					= @"WCLinkConnectionDidCloseNotification";
NSString * const WCLinkConnectionDidTerminateNotification				= @"WCLinkConnectionDidTerminateNotification";

NSString * const WCLinkConnectionReceivedMessageNotification			= @"WCLinkConnectionReceivedMessageNotification";
NSString * const WCLinkConnectionReceivedErrorMessageNotification		= @"WCLinkConnectionReceivedErrorMessageNotification";
NSString * const WCLinkConnectionReceivedInvalidMessageNotification		= @"WCLinkConnectionReceivedInvalidMessageNotification";
NSString * const WCLinkConnectionSentMessageNotification				= @"WCLinkConnectionSentMessageNotification";

NSString * const WCLinkConnectionLoggedInNotification					= @"WCLinkConnectionLoggedInNotification";


@implementation WCLinkConnection

- (id)init {
	self = [super init];
	
	_notificationCenter = [[NSNotificationCenter alloc] init];
	
	_linkNotificationCenter = [[WIP7NotificationCenter alloc] init];
	[_linkNotificationCenter setTransactionFieldName:@"wired.transaction"];
	
	[self addObserver:self
			 selector:@selector(linkConnectionDidConnect:)
				 name:WCLinkConnectionDidConnectNotification];

	[self addObserver:self
			 selector:@selector(linkConnectionDidTerminate:)
				 name:WCLinkConnectionDidTerminateNotification];
	
	[self addObserver:self
			 selector:@selector(linkConnectionDidClose:)
				 name:WCLinkConnectionDidCloseNotification];

	[self addObserver:self selector:@selector(wiredSendPing:) messageName:@"wired.send_ping"];
	
	[self retain];
	
	return self;
}



- (void)dealloc {
	[self removeObserver:self];
	
	[_link release];
	[_notificationCenter release];
	[_linkNotificationCenter release];

	[_error release];
	
	[super dealloc];
}



#pragma mark -

- (void)linkConnectionDidConnect:(NSNotification *)notification {
	[self sendMessage:[self clientInfoMessage] fromObserver:self selector:@selector(wiredClientInfoReply:)];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[NSObject cancelPreviousPerformRequestsWithTarget:_link];
	[_link setDelegate:NULL];
	[_link release];
	_link = NULL;
	
	[self autorelease];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	[_link release];
	_link = NULL;
}



- (void)wiredSendPing:(WIP7Message *)message {
	[self replyMessage:[WIP7Message messageWithName:@"wired.ping" spec:WCP7Spec] toMessage:message];
}



- (void)wiredClientInfoReply:(WIP7Message *)message {
	[self sendMessage:[self setNickMessage]];
	[self sendMessage:[self setStatusMessage]];
	[self sendMessage:[self setIconMessage]];
	[self sendMessage:[self loginMessage] fromObserver:self selector:@selector(wiredLoginReply:)];
}



- (void)wiredLoginReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.login"])
		[self postNotificationName:WCLinkConnectionLoggedInNotification object:self];
}



#pragma mark -

- (void)addObserver:(id)observer selector:(SEL)action name:(NSString *)name {
	[_notificationCenter addObserver:observer selector:action name:name];
}



- (void)addObserver:(id)observer selector:(SEL)action messageName:(NSString *)messageName {
	[_linkNotificationCenter addObserver:observer selector:action messageName:messageName];
}



- (void)removeObserver:(id)observer {
	[_notificationCenter removeObserver:observer];
	[_linkNotificationCenter removeObserver:observer];
}



- (void)removeObserver:(id)observer name:(NSString *)name {
	[_notificationCenter removeObserver:observer name:name];
}



- (void)removeObserver:(id)observer messageName:(NSString *)messageName {
	[_linkNotificationCenter removeObserver:observer messageName:messageName];
}



- (void)removeObserver:(id)observer message:(WIP7Message *)message {
	[_linkNotificationCenter removeObserver:observer message:message];
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
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name object:object userInfo:userInfo];
}



#pragma mark -

- (NSUInteger)sendMessage:(WIP7Message *)message {
	WIP7UInt32		transaction;
	
	transaction = ++_transaction;
	
	[message setUInt32:transaction forName:@"wired.transaction"];
	
	[_link sendMessage:message];
	
	return transaction;
}



- (NSUInteger)sendMessage:(WIP7Message *)message fromObserver:(id)observer selector:(SEL)selector {
	WIP7UInt32		transaction;
	
	transaction = ++_transaction;
	
	[message setUInt32:transaction forName:@"wired.transaction"];
	
	[_linkNotificationCenter addObserver:observer selector:selector message:message];
	[_link performSelector:@selector(sendMessage:) withObject:message afterDelay:0.0];
	
	return transaction;
}



- (void)replyMessage:(WIP7Message *)reply toMessage:(WIP7Message *)message {
	WIP7UInt32		transaction;
	
	if([message getUInt32:&transaction forName:@"wired.transaction"])
		[reply setUInt32:transaction forName:@"wired.transaction"];
	
	[_link sendMessage:reply];
}



#pragma mark -

- (void)linkConnected:(WCLink *)link {
	[self postNotificationName:WCLinkConnectionDidConnectNotification object:self];
}



- (void)linkClosed:(WCLink *)link error:(WIError *)error {
	[_error release];
	_error = [error retain];
	
	[self postNotificationName:WCLinkConnectionDidCloseNotification object:self];
}



- (void)linkTerminated:(WCLink *)link {
	[self postNotificationName:WCLinkConnectionDidTerminateNotification object:self];
}



- (void)link:(WCLink *)link sentMessage:(WIP7Message *)message {
	[_notificationCenter postNotificationName:WCLinkConnectionSentMessageNotification object:message];
}



- (void)link:(WCLink *)link receivedMessage:(WIP7Message *)message {
	WIError			*error;
	
	[message setContextInfo:self];
	
	if([[_link socket] verifyMessage:message error:&error]) {
		if([[message name] isEqualToString:@"wired.error"])
			[_notificationCenter postNotificationName:WCLinkConnectionReceivedErrorMessageNotification object:message];
		else
			[_notificationCenter postNotificationName:WCLinkConnectionReceivedMessageNotification object:message];

		[_linkNotificationCenter postMessage:message];
	} else {
		[_notificationCenter postNotificationName:WCLinkConnectionReceivedInvalidMessageNotification
										   object:message
										 userInfo:[NSDictionary dictionaryWithObject:error forKey:@"WCError"]];
	}
}



#pragma mark -

- (void)connect {
	_disconnecting = NO;
	
	[self postNotificationName:WCLinkConnectionWillConnectNotification object:self];
	
	_link = [[WCLink alloc] initLinkWithURL:[self URL]];
	[_link setDelegate:self];
	[_link connect];
}



- (void)disconnect {
	_disconnecting = YES;
	
	[self postNotificationName:WCLinkConnectionWillDisconnectNotification object:self];

	[_link disconnect];
}



- (void)terminate {
	if(_link && [_link isReading])
		[_link terminate];
	else
		[self postNotificationName:WCLinkConnectionDidTerminateNotification object:self];
}



#pragma mark -

- (WIP7Socket *)socket {
	return [_link socket];
}



- (BOOL)isConnected {
	return (_link != NULL);
}



- (BOOL)isDisconnecting {
	return _disconnecting;
}



- (WCError *)error {
	return _error;
}

@end
