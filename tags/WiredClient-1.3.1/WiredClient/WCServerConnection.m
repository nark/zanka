/* $Id$ */

/*
 *  Copyright (c) 2005-2006 Axel Andersson
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

#import "NSAlert-WCAdditions.h"
#import "NSNotificationCenter-WCAdditions.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCApplicationController.h"
#import "WCCache.h"
#import "WCConsole.h"
#import "WCLink.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCTransfers.h"

@interface WCServerConnection(Private)

- (id)_initServerConnectionWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark;

- (void)_connect;
- (void)_login;

@end


@implementation WCServerConnection(Private)

- (id)_initServerConnectionWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark {
	self = [super initWithWindowNibName:@"Connection"];
	
	[self retain];

	_bookmark = [bookmark retain];
	
	_server = [[WCServer alloc] init];
	[_server setURL:url];
	
	_notificationCenter = [[NSNotificationCenter alloc] init];
	
	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(nickDidChange:)
			   name:WCNickDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(statusDidChange:)
			   name:WCStatusDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(iconDidChange:)
			   name:WCIconDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChange];

	[self addObserver:self
			 selector:@selector(connectionDidConnect:)
				 name:WCConnectionDidConnect];

	[self addObserver:self
			 selector:@selector(connectionWillTerminate:)
				 name:WCConnectionWillTerminate];

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
			 selector:@selector(connectionReceivedError:)
				 name:WCConnectionReceivedError];

	[self addObserver:self
			 selector:@selector(serverConnectionWillReconnect:)
				 name:WCServerConnectionWillReconnect];

	[self addObserver:self
			 selector:@selector(serverConnectionReceivedServerInfo:)
				 name:WCServerConnectionReceivedServerInfo];

	[self addObserver:self
			 selector:@selector(serverConnectionReceivedSelf:)
				 name:WCServerConnectionReceivedSelf];
	
	[self addObserver:self
			 selector:@selector(serverConnectionReceivedPing:)
				 name:WCServerConnectionReceivedPing];

	[self addObserver:self
			 selector:@selector(serverConnectionReceivedBanner:)
				 name:WCServerConnectionReceivedBanner];

	[self addObserver:self
			 selector:@selector(serverConnectionReceivedPrivileges:)
				 name:WCServerConnectionReceivedPrivileges];

	[self addObserver:self
			 selector:@selector(serverConnectionShouldHide:)
				 name:WCServerConnectionShouldHide];

	[self addObserver:self
			 selector:@selector(serverConnectionShouldUnhide:)
				 name:WCServerConnectionShouldUnhide];

	return self;
}



- (void)_connect {
	if(!_cache) {
		_cache			= [[WCCache alloc] initWithCapacity:100];

#if defined(DEBUG) || defined(TEST)
		_console		= [[WCConsole consoleWithConnection:self] retain];
#endif
		
		_accounts		= [[WCAccounts accountsWithConnection:self] retain];
		_news			= [[WCNews newsWithConnection:self] retain];
		_messages		= [[WCMessages messagesWithConnection:self] retain];
		_search			= [[WCSearch searchWithConnection:self] retain];
		_serverInfo		= [[WCServerInfo serverInfoWithConnection:self] retain];
		_transfers		= [[WCTransfers transfersWithConnection:self] retain];

		_chat			= [[WCPublicChat publicChatWithConnection:self] retain];
	}

	_link = [[WCLink alloc] initLinkWithURL:[_server URL]];
	[_link setDelegate:self];
	[_link connect];
}



- (void)_login {
	NSString	*user, *password, *nick, *status;
	WIURL		*url;
	
	nick = [_bookmark objectForKey:WCBookmarksNick];
	
	if([nick length] == 0)
		nick = [WCSettings objectForKey:WCNick];

	[_link sendCommand:WCNickCommand withArgument:nick];

	if([_server protocol] >= 1.1) {
		[_link sendCommand:WCIconCommand
			 withArgument:@"0"
			 withArgument:[WCSettings objectForKey:WCCustomIcon]];
		
		status = [_bookmark objectForKey:WCBookmarksStatus];
		
		if([status length] == 0)
			status = [WCSettings objectForKey:WCStatus];
		
		[_link sendCommand:WCStatusCommand withArgument:status];
	}

	url = [_server URL];
	user = [[url user] length] > 0 ? [url user] : WCDefaultLogin;
	password = [[url password] length] > 0 ? [[url password] SHA1] : @"";

	[_link sendCommand:WCClientCommand withArgument:[[WCApplicationController sharedController] clientVersion]];
	[_link sendCommand:WCUserCommand withArgument:user];
	[_link sendCommand:WCPassCommand withArgument:password];
}

@end


@implementation WCServerConnection

+ (id)serverConnection {
	return [[[self alloc] _initServerConnectionWithURL:NULL bookmark:NULL] autorelease];
}



+ (id)serverConnectionWithURL:(WIURL *)url {
	return [[[self alloc] _initServerConnectionWithURL:url bookmark:NULL] autorelease];
}



+ (id)serverConnectionWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark {
	return [[[self alloc] _initServerConnectionWithURL:url bookmark:bookmark] autorelease];
}



- (void)dealloc {
	[self removeObserver:self];
	
	[_bookmark release];
	
	[_server release];
	[_cache release];
	
	[_notificationCenter release];

	[_console release];
	[_accounts release];
	[_news release];
	[_messages release];
	[_search release];
	[_serverInfo release];
	[_transfers release];
	[_chat release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Connection"];

	if([[_server URL] hostpair])
		[_addressTextField setStringValue:[[_server URL] hostpair]];
	
	if([[_server URL] user])
		[_loginTextField setStringValue:[[_server URL] user]];

	if([[_server URL] password])
		[_passwordTextField setStringValue:[[_server URL] password]];
}



- (void)windowWillClose:(NSNotification *)notification {
	if(!_dismissingWindow && !_reconnecting && [[notification object] isOnScreen]) {
		_closingWindow = YES;
		
		[self postNotificationName:WCConnectionShouldTerminate object:self];
	}
}



- (void)nickDidChange:(NSNotification *)notification {
	NSString	*nick;
	
	nick = [_bookmark objectForKey:WCBookmarksNick];
	
	if([nick length] == 0)
		nick = [WCSettings objectForKey:WCNick];

	[_link sendCommand:WCNickCommand withArgument:nick];
}



- (void)statusDidChange:(NSNotification *)notification {
	NSString	*status;
	
	if([_server protocol] >= 1.1) {
		status = [_bookmark objectForKey:WCBookmarksStatus];
		
		if([status length] == 0)
			status = [WCSettings objectForKey:WCStatus];
		
		[_link sendCommand:WCStatusCommand withArgument:status];
	}
}



- (void)iconDidChange:(NSNotification *)notification {
	if([_server protocol] >= 1.1) {
		[_link sendCommand:WCIconCommand
			 withArgument:@"0"
			 withArgument:[WCSettings objectForKey:WCCustomIcon]];
	}
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	NSDictionary	*bookmark;
	NSString		*nick, *status;
	
	bookmark = [notification userInfo];
	
	if([[bookmark objectForKey:WCBookmarksIdentifier] isEqualToString:[_bookmark objectForKey:WCBookmarksIdentifier]]) {
		nick = [bookmark objectForKey:WCBookmarksNick];
		
		if([nick length] == 0)
			nick = [WCSettings objectForKey:WCNick];
		
		[_link sendCommand:WCNickCommand withArgument:nick];

		status = [bookmark objectForKey:WCBookmarksStatus];
		
		if([status length] == 0)
			status = [WCSettings objectForKey:WCStatus];

		[_link sendCommand:WCStatusCommand withArgument:status];
	}
}



- (void)connectionDidConnect:(NSNotification *)notification {
	[_link sendCommand:WCHelloCommand];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	if(!_closingWindow)
		[self close];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	[self postNotificationName:WCConnectionWillTerminate object:self];
	
	if(_link && [_link isReading])
		[_link terminate];
	else
		[self postNotificationName:WCConnectionDidTerminate object:self];
}



- (void)connectionDidTerminate:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];

	[_link release];
	_link = NULL;
}



- (void)connectionDidClose:(NSNotification *)notification {
	WCError		*error;
	
	[_progressIndicator stopAnimation:self];
	
	[_link release];
	_link = NULL;

	if(!_loginFailed) {
		error = [[notification userInfo] objectForKey:WCErrorKey];
		
		if(error) {
			if([[self window] isMiniaturized])
				[self showWindow:self];
			
			if([[self window] isVisible]) {
				[[NSNotificationCenter defaultCenter] postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsError];
				[[error alert] beginSheetModalForWindow:[self window]];
			}
		}
		
		if(![[self window] isVisible])
			[self postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsServerDisconnected];
	}
	
	[_connectButton setEnabled:YES];
}



- (void)connectionReceivedError:(NSNotification *)notification {
	WCError		*error;
	
	error = [[notification userInfo] objectForKey:WCErrorKey];
	
	if([[self window] isMiniaturized])
		[self showWindow:self];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsError];

	if([[self window] isVisible])
		[[error alert] beginSheetModalForWindow:[self window]];
	else
		[[error alert] runModal];
	
	if([error code] == 510 || [error code] == 511) {
		_loginFailed = YES;
		
		[_link close];
	}
}



- (void)serverConnectionWillReconnect:(NSNotification *)notification {
	_reconnecting = YES;
}



- (void)serverConnectionReceivedServerInfo:(NSNotification *)notification {
	NSArray		*fields;
	NSString	*version, *protocol, *name, *description, *started, *files, *size;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	version		= [fields safeObjectAtIndex:0];
	protocol	= [fields safeObjectAtIndex:1];
	name		= [fields safeObjectAtIndex:2];
	description = [fields safeObjectAtIndex:3];
	started		= [fields safeObjectAtIndex:4];
	files		= [fields safeObjectAtIndex:5];
	size		= [fields safeObjectAtIndex:6];

	[_server setName:name];
	[_server setServerDescription:description];
	[_server setServerVersion:version];
	[_server setProtocol:[protocol doubleValue]];
	[_server setStartupDate:[NSDate dateWithISO8601String:started]];
	[_server setFiles:[files unsignedIntValue]];
	[_server setSize:[size unsignedLongLongValue]];

	if(!_sentLogin) {
		[self _login];

		_sentLogin = YES;
	}
	
	[[self window] setTitle:[self name] withSubtitle:NSLS(@"Connect", @"Connect window title")];

	[self postNotificationName:WCServerConnectionServerInfoDidChange object:self];
}



- (void)serverConnectionReceivedSelf:(NSNotification *)notification {
	[_link sendCommand:WCPrivilegesCommand];
	[_link sendCommand:WCWhoCommand withArgument:[NSSWF:@"%u", 1]];
	[_link sendCommand:WCNewsCommand];

	if([_server protocol] >= 1.1)
		[_link sendCommand:WCBannerCommand];

	_dismissingWindow = YES;
	[[self window] close];
	_dismissingWindow = NO;
	
	_reconnecting = NO;
	
	[self postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsServerConnected];
	
	[self postNotificationName:WCServerConnectionLoggedIn object:self];
}



- (void)serverConnectionReceivedPing:(NSNotification *)notification {
}



- (void)serverConnectionReceivedBanner:(NSNotification *)notification {
	NSString		*banner;
	NSArray			*fields;
	NSData			*data;
	NSImage			*image;

	fields = [[notification userInfo] objectForKey:WCArgumentsKey];
	banner = [fields safeObjectAtIndex:0];

	data = [NSData dataWithBase64EncodedString:banner];
	image = [[NSImage alloc] initWithData:data];
	[_server setBanner:image];
	[image release];

	[self postNotificationName:WCServerConnectionBannerDidChange object:self];
}



- (void)serverConnectionReceivedPrivileges:(NSNotification *)notification {
	NSArray		*arguments;
	
	arguments = [[notification userInfo] objectForKey:WCArgumentsKey];
	
	[_server setAccount:[WCAccount userAccountWithPrivilegesArguments:arguments]];

	[self postNotificationName:WCServerConnectionPrivilegesDidChange object:self];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	_hidden = YES;
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	_hidden = NO;
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
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name object:object userInfo:userInfo];
}



- (void)postNotificationName:(NSString *)name eventTag:(int)tag {
	[_notificationCenter mainThreadPostNotificationName:name eventTag:tag];
	
	[[NSNotificationCenter defaultCenter] mainThreadPostNotificationName:name eventTag:tag];
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



- (void)ignoreError:(unsigned int)error {
	_ignoreErrorMessage	= error;
	_ignoreErrorTime	= [NSDate timeIntervalSinceReferenceDate];
}



#pragma mark -

- (void)linkConnected:(WCLink *)link {
	[self postNotificationName:WCConnectionDidConnect object:self];
}



- (void)linkClosed:(WCLink *)link error:(WIError *)error {
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



- (void)link:(WCLink *)link receivedMessage:(unsigned int)message arguments:(NSArray *)arguments {
	NSString				*name = NULL;
	NSMutableDictionary		*userInfo;
	WCError					*error;
	
	userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		arguments,							WCArgumentsKey,
		[NSNumber numberWithInt:message],	WCMessageKey,
		NULL];

	switch(message) {
		case 200:
			name = WCServerConnectionReceivedServerInfo;
			break;
		
		case 201:
			name = WCServerConnectionReceivedSelf;
			break;
			
		case 202:
			name = WCServerConnectionReceivedPing;
			break;
			
		case 203:
			name = WCServerConnectionReceivedBanner;
			break;
		
		case 300:
			name = WCChatReceivedChat;
			break;

		case 301:
			name = WCChatReceivedActionChat;
			break;

		case 302:
			name = WCChatReceivedUserJoin;
			break;

		case 303:
			name = WCChatReceivedUserLeave;
			break;

		case 304:
			name = WCChatReceivedUserChange;
			break;

		case 305:
			name = WCMessagesReceivedMessage;
			break;

		case 306:
			name = WCChatReceivedUserKick;
			break;

		case 307:
			name = WCChatReceivedUserBan;
			break;

		case 308:
			name = WCUserInfoReceivedUserInfo;
			break;

		case 309:
			name = WCMessagesReceivedBroadcast;
			break;

		case 310:
			name = WCChatReceivedUser;
			break;

		case 311:
			name = WCChatCompletedUsers;
			break;

		case 320:
			name = WCNewsShouldAddNews;
			break;

		case 321:
			name = WCNewsShouldCompleteNews;
			break;

		case 322:
			name = WCNewsShouldAddNewNews;
			break;

		case 330:
			name = WCPrivateChatReceivedCreate;
			break;

		case 331:
			name = WCPrivateChatReceivedInvite;
			break;

		case 332:
			name = WCPrivateChatReceivedDecline;
			break;

		case 340:
			name = WCChatReceivedUserIconChange;
			break;

		case 341:
			name = WCChatReceivedTopic;
			break;

		case 400:
			name = WCTransfersReceivedTransferStart;
			break;

		case 401:
			name = WCTransfersReceivedQueueUpdate;
			break;

		case 402:
			name = WCFileInfoReceivedFileInfo;
			break;

		case 410:
			name = WCFilesReceivedFile;
			break;

		case 411:
			name = WCFilesCompletedFiles;
			break;

		case 420:
			name = WCSearchReceivedFile;
			break;

		case 421:
			name = WCSearchCompletedFiles;
			break;

		case 600:
			name = WCAccountEditorReceivedUser;
			break;

		case 601:
			name = WCAccountEditorReceivedGroup;
			break;

		case 602:
			name = WCServerConnectionReceivedPrivileges;
			break;

		case 610:
			name = WCAccountsReceivedUser;
			break;

		case 611:
			name = WCAccountsCompletedUsers;
			break;

		case 620:
			name = WCAccountsReceivedGroup;
			break;

		case 621:
			name = WCAccountsCompletedGroups;
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

- (IBAction)connect:(id)sender {
	WIURL		*url;
	
	url = [WIURL URLWithScheme:@"wired" hostpair:[_addressTextField stringValue]];
	[url setUser:[_loginTextField stringValue]];
	[url setPassword:[_passwordTextField stringValue]];
	
	[_server setURL:url];

	[self connect];
}



#pragma mark -

- (void)connect {
	[_connectButton setEnabled:NO];
	[_progressIndicator startAnimation:self];
	
	_sentLogin		= NO;
	_loginFailed	= NO;
	
	[self _connect];
}



- (void)close {
	[_link close];
}



- (void)terminate {
	[self postNotificationName:WCConnectionShouldTerminate object:self];
}



- (void)reconnect {
	[self postNotificationName:WCServerConnectionWillReconnect object:self];

	[self showWindow:self];
	
	[self connect];
}



- (void)hide {
	[self postNotificationName:WCServerConnectionShouldHide object:self];
}



- (void)unhide {
	[self postNotificationName:WCServerConnectionShouldUnhide object:self];
}



#pragma mark -

- (WIURL *)URL {
	return [_server URL];
}



- (WISocket *)socket {
	return [_link socket];
}



- (BOOL)isConnected {
	return (_link != NULL);
}



- (double)protocol {
	return [_server protocol];
}



#pragma mark -

- (BOOL)isReconnecting {
	return _reconnecting;
}



- (BOOL)isHidden {
	return _hidden;
}



- (void)setBookmark:(NSDictionary *)bookmark {
	[bookmark retain];
	[_bookmark release];
	
	_bookmark = bookmark;
}



- (NSDictionary *)bookmark {
	return _bookmark;
}



- (NSString *)name {
	return [_server name];
}



- (NSString *)identifier {
	if(_bookmark)
		return [_bookmark objectForKey:WCBookmarksIdentifier];

	return [[_server URL] hostpair];
}



- (WCAccount *)account {
	return [_server account];
}



- (WCServer *)server {
	return _server;
}



- (WCCache *)cache {
	return _cache;
}



#pragma mark -

- (WCAccounts *)accounts {
	return _accounts;
}



- (WCPublicChat *)chat {
	return _chat;
}



- (WCConsole *)console {
	return _console;
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



- (WCTransfers *)transfers {
	return _transfers;
}

@end
