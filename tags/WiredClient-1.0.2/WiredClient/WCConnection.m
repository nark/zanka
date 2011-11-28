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

#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCCache.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCConsole.h"
#import "WCError.h"
#import "WCMain.h"
#import "WCNews.h"
#import "WCMessages.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCSecureSocket.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCToolbar.h"
#import "WCTransfers.h"

@implementation WCConnection

- (id)initWithURL:(NSURL *)url {
	return [self initWithURL:url name:NULL];
}



- (id)initWithURL:(NSURL *)url name:(NSString *)name {
	self = [super init];
	
	// --- initate cache
	_cache		= [[WCCache alloc] initWithCount:100];
	
	// --- initiate server
	_server		= [[WCServer alloc] init];
	[_server setName:name];
	[_server setURL:url];
	
	// --- initiate toolbar first
	_toolbar	= [(WCToolbar *) [WCToolbar alloc] initWithConnection:self];

	// --- initiate window controllers
	_accounts	= [(WCAccounts *) [WCAccounts alloc] initWithConnection:self];
	_console	= [(WCConsole *) [WCConsole alloc] initWithConnection:self];
	_news		= [(WCNews *) [WCNews alloc] initWithConnection:self];
	_messages	= [(WCMessages *) [WCMessages alloc] initWithConnection:self];
	_search		= [(WCSearch *) [WCSearch alloc] initWithConnection:self];
	_serverInfo	= [(WCServerInfo *) [WCServerInfo alloc] initWithConnection:self];
	_transfers	= [(WCTransfers *) [WCTransfers alloc] initWithConnection:self];

	// --- initiate data controllers
	_error		= [(WCError *) [WCError alloc] initWithConnection:self];
	_client		= [[WCClient alloc] initWithConnection:self type:WCSocketTypeControl server:_server];
	
	// --- initiate public chat controller last so it'll be in focus
	_chat		= [(WCPublicChat *) [WCPublicChat alloc] initWithConnection:self];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionGotServerInfo:)
		name:WCConnectionGotServerInfo
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionGotPrivileges:)
		name:WCConnectionGotPrivileges
		object:NULL];

	// --- start connection
	[_client connect:url];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_cache release];
	[_server release];
	
	[super dealloc];
}



#pragma mark -

- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == self)
		[self release];
}



- (void)connectionGotServerInfo:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *protocol, *name;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != self)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	protocol	= [fields objectAtIndex:1];
	name		= [fields objectAtIndex:2];
	
	// --- check protocol version
	if([protocol doubleValue] > WCProtocolVersion) {
		[[self error] setError:WCApplicationErrorProtocolMismatch];
		[[self error] raiseError];
	}
	
	// --- set name
	[_server setName:name];
}



- (void)connectionGotPrivileges:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != self)
		return;
	
	// --- set privileges
	[[_server account] setPrivileges:[argument componentsSeparatedByString:WCFieldSeparator]];

	// --- announce changing
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCConnectionPrivilegesDidChange
		object:connection];
}



#pragma mark -

- (WCAccounts *)accounts {
	return _accounts;
}



- (WCPublicChat *)chat {
	return _chat;
}



- (WCClient *)client {
	return _client;
}



- (WCConsole *)console {
	return _console;
}



- (WCError *)error {
	return _error;
}



- (WCMessages *)messages {
	return _messages;
}



- (WCNews *)news {
	return _news;
}



- (WCSearch *)search {
	return _search;
}



- (WCServerInfo *)serverInfo {
	return _serverInfo;
}



- (WCToolbar *)toolbar {
	return _toolbar;
}



- (WCTransfers *)transfers {
	return _transfers;
}



#pragma mark -

- (WCCache *)cache {
	return _cache;
}



- (WCServer *)server {
	return _server;
}



- (NSString *)name {
	return [_server name];
}



- (NSURL *)URL {
	return [_server URL];
}



- (WCAccount *)account {
	return [_server account];
}

@end
