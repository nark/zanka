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

#import <unistd.h>
#import "NSStringAdditions.h"
#import "WCAccountEditor.h"
#import "WCAccounts.h"
#import "WCClient.h"
#import "WCConsole.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCMain.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCSecureSocket.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCSettings.h"
#import "WCTracker.h"
#import "WCTrackers.h"
#import "WCTransfers.h"
#import "WCUserInfo.h"

@implementation WCClient

- (id)initWithConnection:(WCConnection *)connection type:(unsigned int)type server:(WCServer *)server {
	self = [super init];
	
	// --- get parameters
	_connection	= [connection retain];
	_server		= [server retain];
	
	// --- we need these
	[[connection console] retain];
	[[connection error] retain];
	
	// --- spawn socket
	_socket		= [(WCSecureSocket *) [WCSecureSocket alloc] initWithConnection:connection type:type];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(nickDidChange:)
			   name:WCNickDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(iconDidChange:)
			   name:WCIconDidChange
			 object:NULL];

	return self;
}



- (id)initWithConnection:(WCConnection *)connection type:(unsigned int)type tracker:(WCTracker *)tracker {
	self = [super init];

	// --- get parameters
	_connection	= [connection retain];
	_tracker	= [tracker retain];
	
	// --- we need these
	[[_connection error] retain];
	[[_connection console] retain];
	
	// --- spawn socket
	_socket		= [(WCSecureSocket *) [WCSecureSocket alloc] initWithConnection:connection type:type];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[[_connection console] release];
	[[_connection error] release];

	[_socket release];
	
	[_timer release];

	[_server release];
	[_connection release];
	[_tracker release];

	[super dealloc];
}



#pragma mark -

- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection) {
		[_socket close];
		
		[_timer invalidate];
		
		[self release];
	}
}



- (void)nickDidChange:(NSNotification *)notification {
	[self sendCommand:WCNickCommand withArgument:[WCSettings objectForKey:WCNick]];
}



- (void)iconDidChange:(NSNotification *)notification {
	[self sendCommand:WCIconCommand withArgument:[WCSettings objectForKey:WCIcon]];
}



#pragma mark -

- (void)connectToServer:(NSURL *)url {
	// --- ping at intervals
	_timer = [NSTimer scheduledTimerWithTimeInterval:60
											  target:self
											selector:@selector(pingTimer:)
											userInfo:NULL
											 repeats:YES];
	[_timer retain];
	
	// --- fork a client thread
	[NSThread detachNewThreadSelector:@selector(clientThread:) toTarget:self withObject:url];
}



- (void)connectToTracker:(NSURL *)url {
	// --- fork a tracker thread
	[NSThread detachNewThreadSelector:@selector(trackerThread:) toTarget:self withObject:url];
}



- (BOOL)connected {
	return [_socket connected];
}



- (void)clientThread:(NSURL *)url {
	NSAutoreleasePool	*pool;
	int					bytes;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];
	
	// --- unset this when we get the result on the banner
	_banner = YES;

	// --- connect to the host
	if([_socket connectToHost:[url host] port:[url port] ? [[url port] intValue] : 2000] < 0) {
		// --- raise socket error
		[[_connection error] raiseErrorInWindow:[WCSharedMain shownWindow]
								   withArgument:[url host]];

		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionShouldTerminate
			object:_connection];

		goto end;
	}
	
	// --- login
	[self sendCommand:WCHelloCommand];
	[self sendCommand:WCNickCommand withArgument:[WCSettings objectForKey:WCNick]];
	[self sendCommand:WCIconCommand withArgument:[WCSettings objectForKey:WCIcon]];
	[self sendCommand:WCClientCommand withArgument:[WCSharedMain versionString]];

	[self sendCommand:WCUserCommand withArgument:[[url user] length] > 0
		? [[url user] stringByReplacingURLPercentEscapes]
		: @"guest"];
	[self sendCommand:WCPassCommand withArgument:[[url password] length] > 0
		? [[[url password] stringByReplacingURLPercentEscapes] SHA1]
		: @""];
	[self sendCommand:WCPrivilegesCommand];
	[self sendCommand:WCWhoCommand withArgument:[NSString stringWithFormat:@"%d", 1]];

	if([[WCSettings objectForKey:WCLoadNewsOnLogin] boolValue])
		[self sendCommand:WCNewsCommand];
	
	// --- start reading from server
	bytes = [self read];
	
	// --- if the loop ended pre-maturily, post notification
	if(bytes <= 0 && [_socket connected]) {
		[_socket close];
		
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionHasClosed
			object:_connection];
	}

end:
	[pool release];
}



- (void)trackerThread:(NSURL *)url {
	NSAutoreleasePool	*pool;
	int					bytes;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];
	
	// --- connect to the host
	if([_socket connectToHost:[url host] port:[url port] ? [[url port] intValue] : 2002] < 0) {
		// --- raise socket error
		[[_connection error] raiseErrorInWindow:[[WCSharedMain trackers] shownWindow]
								   withArgument:[url host]];
		
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionShouldTerminate
			object:_connection];
		
		goto end;
	}
	
	// --- login
	[self sendCommand:WCHelloCommand];
	[self sendCommand:WCClientCommand withArgument:[WCSharedMain versionString]];
	[self sendCommand:WCCategoriesCommand];
	[self sendCommand:WCServersCommand];
	
	// --- start reading from server
	bytes = [self read];
	
	// --- if the loop ended pre-maturily, post notification
	if(bytes <= 0 && [_socket connected]) {
		[_socket close];
		
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionHasClosed
			object:_connection];
	}
	
end:
	[pool release];
}



- (int)read {
	NSAutoreleasePool	*pool;
	NSMutableData		*buffer;
	NSString			*string, *each, *message, *argument;
	NSArray				*array;
	NSEnumerator		*enumerator;
	int					bytes;
	
	// --- init our temporary data buffer
	buffer = [[NSMutableData alloc] initWithCapacity:WCClientBufferSize];
	
	while((bytes = [_socket read:buffer]) > 0) {
		// --- create a pool
		pool = [[NSAutoreleasePool alloc] init];

		// --- decode buffer
		string = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
		
		if(!string) {
			// --- invalid UTF-8 input, kill buffer
			[buffer setLength:0];
		}
		else if([[string substringFromIndex:[string length] - 1] isEqualToString:WCMessageSeparator]) {
			// --- the server may give us several messages in one swoop here
			array		= [string componentsSeparatedByString:WCMessageSeparator];
			enumerator	= [array objectEnumerator];
			
			while((each = [enumerator nextObject]) != NULL && [each length] > 0) {
				message		= [each substringToIndex:WCMessageLength];
				argument	= [each substringFromIndex:WCMessageLength + 1];

				// --- parse this message in the main thread
				[self performSelectorOnMainThread:@selector(parseMessage:)
					  withObject:[NSArray arrayWithObjects:message, argument, NULL]
					  waitUntilDone:YES];
			}
	
			// --- kill buffer
			[buffer setLength:0];
		}
		
		[string release];
		[pool release];
	}
	
	[buffer release];
	
	return bytes;
}



- (void)pingTimer:(NSTimer *)timer {
	[self sendCommand:WCPingCommand];
}



#pragma mark -

- (WCSecureSocket *)socket {
	return _socket;
}



- (BOOL)banner {
	return _banner;
}



#pragma mark -

- (void)sendCommand:(NSString *)command {
	[self sendCommand:command withArgument:NULL];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument {
	NSString	*string;
	
	if(argument)
		string = [NSString stringWithFormat:@"%@ %@", command, argument];
	else
		string = command;
	
	// --- write to console
	[[_connection console] print:[NSString stringWithFormat:@"%@\n", string]
						   color:[NSColor blackColor]];

	// --- send the command
	[_socket write:[[NSString stringWithFormat:@"%@%@", string, WCMessageSeparator] 
							  dataUsingEncoding:NSUTF8StringEncoding]];
}



- (void)parseMessage:(NSArray *)arguments {
	NSString	*argument;
	NSColor		*color;
	int			message;
	
	message		= [[arguments objectAtIndex:0] intValue];
	argument	= [arguments objectAtIndex:1];
	color		= [NSColor blueColor];
	
	switch(message) {
		case 200:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionGotServerInfo
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 201:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionHasAttached
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 202:
			break;
			
		case 300:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCChatShouldPrintChat
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 301:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCChatShouldPrintAction
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 302:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserHasJoined
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;

		case 303:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserHasLeft
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 304:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserHasChanged
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 305:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCMessagesShouldShowMessage
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 306:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserWasKicked
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 307:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserWasBanned
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 308:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCUserInfoShouldShowInfo
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 309:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCMessagesShouldShowBroadcast
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 310:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCChatShouldAddUser
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 311:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCChatShouldCompleteUsers
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 320:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCNewsShouldAddNews
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 321:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCNewsShouldCompleteNews
				object:_connection];
			break;
		
		case 322:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCNewsShouldAddNewNews
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 330:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCPrivateChatShouldShowChat
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 331:
			[[_connection chat] showInvite:argument];
			break;
		
		case 332:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCPrivateChatUserDeclinedInvite
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 400:
			_banner = NO;
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTransfersShouldStartTransfer
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 401:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTransfersShouldUpdateQueue
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 402:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFileInfoShouldShowInfo
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 410:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldAddFile
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 411:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldCompleteFiles
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 420:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCSearchShouldAddFile
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 421:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCSearchShouldCompleteFiles
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 500:
			[[_connection error] setError:WCServerErrorCommandFailed];
			[[_connection error] raiseError];
			break;
		
		case 501:
			[[_connection error] setError:WCServerErrorCommandNotRecognized];
			[[_connection error] raiseError];
			break;
		
		case 502:
			[[_connection error] setError:WCServerErrorCommandNotImplemented];
			[[_connection error] raiseError];
			break;
			
		case 503:
			[[_connection error] setError:WCServerErrorSyntaxError];
			[[_connection error] raiseError];
			break;
		
		case 510:
			[[_connection error] setError:WCServerErrorLoginFailed];
			[[_connection error] raiseErrorInWindow:[WCSharedMain shownWindow]];
	
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionShouldTerminate
				object:_connection];

			[_socket close];
			break;
			
		case 511:
			[[_connection error] setError:WCServerErrorBanned];
			[[_connection error] raiseErrorInWindow:[WCSharedMain shownWindow]];

			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionShouldTerminate
				object:_connection];
			
			[_socket close];
			break;
		
		case 512:
			[[_connection error] setError:WCServerErrorClientNotFound];
			[[_connection error] raiseError];
			break;
		
		case 513:
			[[_connection error] setError:WCServerErrorAccountNotFound];
			[[_connection error] raiseError];
			break;
		
		case 514:
			[[_connection error] setError:WCServerErrorAccountExists];
			[[_connection error] raiseError];
			break;
		
		case 515:
			[[_connection error] setError:WCServerErrorCannotBeDisconnected];
			[[_connection error] raiseError];
			break;
		
		case 516:
			if(_banner) {
				[[NSNotificationCenter defaultCenter]
					postNotificationName:WCServerInfoShouldShowBanner
					object:[NSArray arrayWithObjects:_connection, @"", NULL]];
				
				_banner = NO;
			} else {
				[[_connection error] setError:WCServerErrorPermissionDenied];
				[[_connection error] raiseError];
			}
			break;
		
		case 520:
			if(_banner) {
				[[NSNotificationCenter defaultCenter]
					postNotificationName:WCServerInfoShouldShowBanner
					object:[NSArray arrayWithObjects:_connection, @"", NULL]];
				
				_banner = NO;
			} else {
				[[_connection error] setError:WCServerErrorFileNotFound];
				[[_connection error] raiseError];
			}
			break;
		
		case 521:
			[[_connection error] setError:WCServerErrorFileExists];
			[[_connection error] raiseError];
			break;
		
		case 600:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountEditorShouldShowUser
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 601:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountEditorShouldShowGroup
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 602:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCConnectionGotPrivileges
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 610:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountsShouldAddUser
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 611:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountsShouldCompleteUsers
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 620:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountsShouldAddGroup
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 621:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCAccountsShouldCompleteGroups
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
		
		case 710:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTrackersShouldAddCategory
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
				
		case 711:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTrackersShouldCompleteCategories
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 720:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTrackersShouldAddServer
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
			
		case 721:
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCTrackersShouldCompleteServers
				object:[NSArray arrayWithObjects:_connection, argument, NULL]];
			break;
					
		default:
			color = [NSColor redColor];
			break;
	}
	
	// --- log to console
	[[_connection console] print:[NSString stringWithFormat:@"%d %@\n", message, argument]
						   color:color];
}

@end
