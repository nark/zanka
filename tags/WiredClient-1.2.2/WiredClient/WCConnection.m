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
#import "NSNotificationCenterAdditions.h"
#import "NSStringAdditions.h"
#import "WCAccount.h"
#import "WCAccountEditor.h"
#import "WCAccounts.h"
#import "WCCache.h"
#import "WCConnection.h"
#import "WCConsole.h"
#import "WCError.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCMain.h"
#import "WCNews.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCSecureSocket.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCSettings.h"
#import "WCToolbar.h"
#import "WCTracker.h"
#import "WCTrackers.h"
#import "WCTransfers.h"
#import "WCUserInfo.h"

@implementation WCConnection

- (id)initServerConnectionWithURL:(NSURL *)url {
	return [self initServerConnectionWithURL:url name:NULL];
}



- (id)initServerConnectionWithURL:(NSURL *)url name:(NSString *)name {
	self = [super init];
	
	// --- set type
	_type		= WCConnectionTypeServer;
	
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
	
	// --- initiate socket
	_socket		= [(WCSecureSocket *) [WCSecureSocket alloc] initWithConnection:self];
	[_socket setCiphers:[WCSettings objectForKey:WCSSLControlCiphers]];
	[_socket setNoDelay:YES];
	[_socket setLocking:YES];
	
	// --- initiate public chat controller last so it'll be in focus
	_chat		= [(WCPublicChat *) [WCPublicChat alloc] initWithConnection:self];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionHasAttached:)
			   name:WCConnectionHasAttached
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldCancel:)
			   name:WCConnectionShouldCancel
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionGotServerError:)
			   name:WCConnectionGotServerError
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
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(nickDidChange:)
			   name:WCNickDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
        addObserver:self
		   selector:@selector(statusDidChange:)
			   name:WCStatusDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
        addObserver:self
		   selector:@selector(iconDidChange:)
			   name:WCIconDidChange
			 object:NULL];
	
	// --- we need these in the threads
	[_console retain];
	
	// --- start connection
	[NSThread detachNewThreadSelector:@selector(serverThread:) toTarget:self withObject:NULL];

	return self;
}



- (id)initTrackerConnectionWithURL:(NSURL *)url tracker:(WCTracker *)tracker {
	self = [super init];
	
	// --- set type
	_type		= WCConnectionTypeTracker;
	
	// --- get parameters
	_tracker	= [tracker retain];
	
	// --- initiate data controllers
	_error		= [(WCError *) [WCError alloc] initWithConnection:self];

	// --- initiate socket
	_socket		= [(WCSecureSocket *) [WCSecureSocket alloc] initWithConnection:self];
	[_socket setCiphers:[WCSettings objectForKey:WCSSLControlCiphers]];
	[_socket setNoDelay:YES];
	[_socket setLocking:YES];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];

	// --- start connection
	[NSThread detachNewThreadSelector:@selector(trackerThread:) toTarget:self withObject:NULL];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_timer release];
	[_cache release];
	[_server release];
	[_tracker release];
	
	[_console release];
	
	[super dealloc];
}



#pragma mark -

- (void)connectionHasAttached:(NSNotification *)notification {
	NSString		*uid;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	uid			= [[notification object] objectAtIndex:1];
	
	if(connection != self)
		return;
	
	// --- get uid
	_uid = [uid intValue];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != self)
		return;
	
	if(_connected) {
		[_socket close];
		
		_connected = NO;
	}

	[_timer invalidate];
	
	[self release];
}



- (void)connectionShouldCancel:(NSNotification *)notification {
	if([notification object] != self)
		return;
	
	if(_connected) {
		[_socket close];
		
		_connected = NO;
	}
	
	_cancelled = YES;
}



- (void)connectionGotServerError:(NSNotification *)notification {
	WCConnection	*connection;
	BOOL			handled = NO;
	int				error;
	
	connection  = [[notification object] objectAtIndex:0];
	error		= [[[notification object] objectAtIndex:1] intValue];
	
	if(connection != self)
		return;
	
	if([_sender respondsToSelector:@selector(connectionShouldHandleError:)])
		handled = [_sender connectionShouldHandleError:error];
	
	if(handled)
		return;

	switch(error) {
		case 500:
			[[self error] setError:WCServerErrorCommandFailed];
			[[self error] raiseError];
			break;
		
		case 501:
			[[self error] setError:WCServerErrorCommandNotRecognized];
			[[self error] raiseError];
			break;
			
		case 502:
			[[self error] setError:WCServerErrorCommandNotImplemented];
			[[self error] raiseError];
			break;
			
		case 503:
			[[self error] setError:WCServerErrorSyntaxError];
			[[self error] raiseError];
			break;
			
		case 510:
			[[self error] setError:WCServerErrorLoginFailed];
			[[self error] raiseErrorInWindow:[WCSharedMain shownWindow]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionShouldTerminate
				object:self];		
			break;
			
		case 511:
			[[self error] setError:WCServerErrorBanned];
			[[self error] raiseErrorInWindow:[WCSharedMain shownWindow]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionShouldTerminate
				object:self];
			break;
			
		case 512:
			[[self error] setError:WCServerErrorClientNotFound];
			[[self error] raiseError];
			break;
			
		case 513:
			[[self error] setError:WCServerErrorAccountNotFound];
			[[self error] raiseError];
			break;
			
		case 514:
			[[self error] setError:WCServerErrorAccountExists];
			[[self error] raiseError];
			break;
			
		case 515:
			[[self error] setError:WCServerErrorCannotBeDisconnected];
			[[self error] raiseError];
			break;
			
		case 516:
			[[self error] setError:WCServerErrorPermissionDenied];
			[[self error] raiseError];
			break;
			
		case 520:
			[[self error] setError:WCServerErrorFileNotFound];
			[[self error] raiseError];
			break;
			
		case 521:
			[[self error] setError:WCServerErrorFileExists];
			[[self error] raiseError];
			break;
			
		case 522:
			[[self error] setError:WCServerErrorChecksumMismatch];
			[[self error] raiseError];
			break;
			
		case 523:
			[[self error] setError:WCServerErrorQueueLimitExceeded];
			[[self error] raiseError];
			break;
	}
}



- (void)connectionGotServerInfo:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *version, *protocol, *name, *description, *started, *files = NULL, *size = NULL;
	NSURL			*url;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != self)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	version		= [fields objectAtIndex:0];
	protocol	= [fields objectAtIndex:1];
	name		= [fields objectAtIndex:2];
	description = [fields objectAtIndex:3];
	started		= [fields objectAtIndex:4];
	
	// --- protocol 1.1
	if([protocol doubleValue] >= 1.1) {
		files	= [fields objectAtIndex:5];
		size	= [fields objectAtIndex:6];
	}
	
	// --- set values
	[_server setVersion:version];
	[_server setName:name];
	[_server setProtocol:[protocol doubleValue]];
	[_server setDescription:description];
	[_server setStarted:[NSDate dateWithISO8601String:started]];
	
	// --- protocol 1.1
	if([_server protocol] >= 1.1) {
		[_server setFiles:[files unsignedIntValue]];
		[_server setSize:[size unsignedLongLongValue]];
	}
	
	if(!_received) {
		// --- check protocol version
		if([protocol doubleValue] > WCServerProtocolVersion) {
			[_error setError:WCApplicationErrorProtocolMismatch];
			[_error raiseError];
		}
		
		// --- get url
		url = [_server URL];
		
		// --- rest of login
		[self sendCommand:WCNickCommand
			 withArgument:[WCSettings objectForKey:WCNick]
			   withSender:self];
		
		// --- protocol 1.1
		if([_server protocol] >= 1.1) {
			[self sendCommand:WCIconCommand
				 withArgument:[WCSettings objectForKey:WCIcon]
				 withArgument:[WCSettings objectForKey:WCCustomIcon]
				   withSender:self];
			[self sendCommand:WCStatusCommand
				 withArgument:[WCSettings objectForKey:WCStatus]
				   withSender:self];
		} else {
			[self sendCommand:WCIconCommand
				 withArgument:[WCSettings objectForKey:WCIcon]
				   withSender:self];
		}
		
		[self sendCommand:WCClientCommand
			 withArgument:[WCSharedMain clientVersion]
			   withSender:self];
		[self sendCommand:WCUserCommand
			 withArgument:[[url user] length] > 0
				? [[url user] stringByReplacingURLPercentEscapes]
				: @"guest"
			   withSender:self];
		[self sendCommand:WCPassCommand
			 withArgument:[[url password] length] > 0
				? [[[url password] stringByReplacingURLPercentEscapes] SHA1]
				: @""
			   withSender:self];
		[self sendCommand:WCPrivilegesCommand withSender:self];
		[self sendCommand:WCWhoCommand 
			 withArgument:[NSString stringWithFormat:@"%u", 1]
			   withSender:self];
		
		if([WCSettings boolForKey:WCLoadNewsOnLogin])
			[self sendCommand:WCNewsCommand withSender:self];
		
		// --- protocol 1.1
		if([_server protocol] >= 1.1)
			[self sendCommand:WCBannerCommand withSender:self];
		
		// --- only do that once
		_received = YES;
	}

	// --- announce changing
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCConnectionServerInfoDidChange
		object:connection];
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



- (void)nickDidChange:(NSNotification *)notification {
    [self sendCommand:WCNickCommand
		 withArgument:[WCSettings objectForKey:WCNick]
		   withSender:self];
}



- (void)statusDidChange:(NSNotification *)notification {
    [self sendCommand:WCStatusCommand
		 withArgument:[WCSettings objectForKey:WCStatus]
		   withSender:self];
}



- (void)iconDidChange:(NSNotification *)notification {
    if([_server protocol] >= 1.1) {
        [self sendCommand:WCIconCommand
			 withArgument:[WCSettings objectForKey:WCIcon]
			 withArgument:[WCSettings objectForKey:WCCustomIcon]
			   withSender:self];
    } else {
        [self sendCommand:WCIconCommand
			 withArgument:[WCSettings objectForKey:WCIcon]
			   withSender:self];
    }
}



#pragma mark -

- (void)serverThread:(id)arg {
	NSAutoreleasePool	*pool;
	NSURL				*url;
	int					port;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];
	
	// --- get url
	url = _type == WCConnectionTypeServer ? [_server URL] : [_tracker URL];
	port = [url port] ? [[url port] intValue] : 2000;
	
	// --- connect to the host
	if([_socket connectToHost:[url host] port:port] < 0) {
		if(!_cancelled) {
			// --- raise socket error
			[_error raiseErrorInWindow:[WCSharedMain shownWindow]
						  withArgument:[url host]];
			
			// --- announce shutdown
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCConnectionShouldTerminate
				object:self];
		}
			
		goto end;
	}
	
	// --- mark connected
	_connected = YES;
	
	// --- ping at intervals
	_timer = [NSTimer scheduledTimerWithTimeInterval:60
											  target:self
											selector:@selector(pingTimer:)
											userInfo:NULL
											 repeats:YES];
	[_timer retain];
	
	// --- initial login
	[self sendCommand:WCHelloCommand withSender:self];
	
	// --- start reading from server
	[_socket readInBackgroundAndNotify];
		
	// --- pre-mature disconnect from server
	if(_connected) {
		[[NSNotificationCenter defaultCenter]
			mainThreadPostNotificationName:WCConnectionHasClosed
			object:self];
		
		_connected = NO;
	}
	
	// --- controlled connection termination
	if(_cancelled) {
		[[NSNotificationCenter defaultCenter]
			mainThreadPostNotificationName:WCConnectionShouldTerminate
			object:self];
	}
	
end:
	// --- clean up
	[_socket release];
	_socket = NULL;
	
	[pool release];
}



- (void)trackerThread:(id)arg {
	NSAutoreleasePool	*pool;
	NSURL				*url;
	int					port;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];
	
	// --- get url
	url = _type == WCConnectionTypeServer ? [_server URL] : [_tracker URL];
	port = [url port] ? [[url port] intValue] : 2002;
	
	// --- connect to the host
	if([_socket connectToHost:[url host] port:port] < 0) {
		// --- raise socket error
		[_error raiseErrorInWindow:[[WCSharedMain trackers] shownWindow]
					  withArgument:[url host]];
		
		[[NSNotificationCenter defaultCenter]
			mainThreadPostNotificationName:WCConnectionShouldTerminate
			object:self];
		
		goto end;
	}
	
	// --- mark connected
	_connected = YES;
	
	// --- initial login
	[self sendCommand:WCHelloCommand withSender:self];
	[self sendCommand:WCClientCommand
		 withArgument:[WCSharedMain clientVersion]
		   withSender:self];
	[self sendCommand:WCCategoriesCommand withSender:self];
	[self sendCommand:WCServersCommand withSender:self];
	
	// --- start reading from server
	[_socket readInBackgroundAndNotify];
	
	// --- pre-mature disconnect from server
	if(_connected) {
		[[NSNotificationCenter defaultCenter]
			mainThreadPostNotificationName:WCConnectionHasClosed
			object:self];
		
		_connected = NO;
	}
	
end:
	// --- clean up
	[_socket release];
	[pool release];
}



- (void)pingTimer:(NSTimer *)timer {
	[self sendCommand:WCPingCommand withSender:self];
}



#pragma mark -

- (void)sendCommand:(NSString *)command withSender:(id)sender {
	[self sendCommand:command
		 withArgument:NULL
		 withArgument:NULL
		 withArgument:NULL
		   withSender:sender];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withSender:(id)sender {
	[self sendCommand:command
		 withArgument:argument1
		 withArgument:NULL
		 withArgument:NULL
		   withSender:sender];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withSender:(id)sender {
	[self sendCommand:command
		 withArgument:argument1
		 withArgument:argument2
		 withArgument:NULL
		   withSender:sender];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3 withSender:(id)sender {
	NSString	*string = command;
	NSData		*data;
	
	// --- add arguments
	if(argument3) {
		string = [NSString stringWithFormat:@"%@ %@%@%@%@%@",
			command, argument1, WCFieldSeparator, argument2, WCFieldSeparator, argument3];
	}
	else if(argument2) {
		string = [NSString stringWithFormat:@"%@ %@%@%@",
			command, argument1, WCFieldSeparator, argument2];
	}
	else if(argument1) {
		string = [NSString stringWithFormat:@"%@ %@",
			command, argument1];
	}
	
	// --- save sender
	_sender = sender;
	
	// --- write to console
	[_console print:[NSString stringWithFormat:@"%@\n", string]
			  color:[NSColor blackColor]];
	
	// --- get data
	data = [[NSString stringWithFormat:@"%@%@", string, WCMessageSeparator] 
		dataUsingEncoding:NSUTF8StringEncoding];

	// --- send the command
	[_socket write:data];
}



- (void)clearSender:(id)sender {
	if(_sender == sender)
		_sender = NULL;
}



- (void)receiveData:(NSData *)data {
	NSString	*string, *argument;
	NSColor		*color;
	int			message;
	
	// --- decode buffer
	string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	if(!string)
		return;
	   
	// --- parse string
	message = [[string substringToIndex:WCMessageLength] intValue];
	argument = [string substringFromIndex:WCMessageLength + 1];
	color = [NSColor blueColor];
	
	switch(message) {
		case 200:
			if(_type == WCConnectionTypeServer) {
				[[NSNotificationCenter defaultCenter]
					mainThreadPostNotificationName:WCConnectionGotServerInfo
					object:[NSArray arrayWithObjects:self, argument, NULL]];
			}
			else if(_type == WCConnectionTypeTracker) {
				[[NSNotificationCenter defaultCenter]
					mainThreadPostNotificationName:WCConnectionGotTrackerInfo
					object:[NSArray arrayWithObjects:self, argument, NULL]];
			}
			break;
			
		case 201:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCConnectionHasAttached
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 202:
			break;
		
		case 203:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCConnectionGotServerBanner
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 300:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCChatShouldPrintChat
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 301:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCChatShouldPrintAction
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 302:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserHasJoined
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;

		case 303:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserHasLeft
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 304:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserHasChanged
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 305:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCMessagesShouldShowMessage
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 306:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserWasKicked
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 307:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserWasBanned
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 308:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserInfoShouldShowInfo
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 309:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCMessagesShouldShowBroadcast
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 310:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCChatShouldAddUser
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 311:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCChatShouldCompleteUsers
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 320:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCNewsShouldAddNews
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 321:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCNewsShouldCompleteNews
				object:self];
			break;
		
		case 322:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCNewsShouldAddNewNews
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 330:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCPrivateChatShouldShowChat
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 331:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCPrivateChatShouldShowInvite
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 332:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCPrivateChatUserDeclinedInvite
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 340:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCUserIconHasChanged
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 341:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCChatShouldShowTopic
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 400:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTransfersShouldStartTransfer
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 401:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTransfersShouldUpdateQueue
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 402:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCFileInfoShouldShowInfo
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 410:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCFilesShouldAddFile
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 411:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCFilesShouldCompleteFiles
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 420:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCSearchShouldAddFile
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 421:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCSearchShouldCompleteFiles
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 500:
		case 501:
		case 502:
		case 503:
		case 510:
		case 511:
		case 512:
		case 513:
		case 514:
		case 515:
		case 516:
		case 520:
		case 521:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCConnectionGotServerError
				object:[NSArray arrayWithObjects:self, [NSNumber numberWithInt:message], NULL]];
			break;

		case 600:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountEditorShouldShowUser
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 601:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountEditorShouldShowGroup
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 602:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCConnectionGotPrivileges
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 610:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountsShouldAddUser
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 611:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountsShouldCompleteUsers
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 620:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountsShouldAddGroup
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 621:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCAccountsShouldCompleteGroups
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		case 710:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTrackersShouldAddCategory
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
				
		case 711:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTrackersShouldCompleteCategories
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 720:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTrackersShouldAddServer
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
			
		case 721:
			[[NSNotificationCenter defaultCenter]
				mainThreadPostNotificationName:WCTrackersShouldCompleteServers
				object:[NSArray arrayWithObjects:self, argument, NULL]];
			break;
		
		default:
			color = [NSColor redColor];
			break;
	}
	
	// --- log to console
	[_console print:[NSString stringWithFormat:@"%d %@\n", message, argument] color:color];
	[string release];
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



- (WCSecureSocket *)socket {
	return _socket;
}



- (WCToolbar *)toolbar {
	return _toolbar;
}



- (WCTransfers *)transfers {
	return _transfers;
}



#pragma mark -

- (WCConnectionType)type {
	return _type;
}



- (WCCache *)cache {
	return _cache;
}



- (WCServer *)server {
	return _server;
}



- (WCTracker *)tracker {
	return _tracker;
}



- (NSString *)name {
	return [_server name];
}



- (NSURL *)URL {
	return _type == WCConnectionTypeServer
		? [_server URL]
		: [_tracker URL];
}



- (WCAccount *)account {
	return [_server account];
}



- (BOOL)connected {
	return [_socket connected];
}



- (unsigned int)uid {
	return _uid;
}



- (double)protocol {
	return [_server protocol];
}

@end
