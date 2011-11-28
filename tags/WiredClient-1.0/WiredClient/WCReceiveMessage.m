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
#import "WCConnection.h"
#import "WCMain.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCReceiveMessage.h"
#import "WCSendMessage.h"
#import "WCSettings.h"
#import "WCURLTextView.h"
#import "WCUser.h"

@implementation WCReceiveMessage

- (id)initWithConnection:(WCConnection *)connection message:(WCMessage *)message {
	self = [super initWithWindowNibName:@"ReceiveMessage"];
	
	// --- get parameters
	_connection = [connection retain];
	_message = [message retain];
		
	// --- load the window
	[self window];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];
	
	// --- show the window
	[self showWindow:self];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connection release];
	[_message release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- set the values
	[_nickTextField setStringValue:[[_message user] nick]];
	[_messageTextView setString:[_message message]];
	
	// --- window position
	[[self window] center];

	// --- set up the message window
	[self update];
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}




#pragma mark -

- (void)update {
	// --- set color and font from preferences
	[_messageTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
	[_messageTextView setForeColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];
	[_messageTextView setBackColor:[WCSettings archivedObjectForKey:WCMessageBackgroundColor]];
	[_messageTextView setURLColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
	[_messageTextView setEventColor:[WCSettings archivedObjectForKey:WCEventTextColor]];

	// --- parse text
	[[_messageTextView textStorage]
		replaceCharactersInRange:NSMakeRange(0, [[_messageTextView string] length])
		withAttributedString:[_messageTextView scan:[_messageTextView string]]];
}



#pragma mark -

- (IBAction)reply:(id)sender {
	WCMessage	*message;

	// --- create a message
	message = [[WCMessage alloc] initWithType:WCMessageTypeTo];
	[message setRead:YES];
	[message setUser:[_message user]];

	// --- send a new message
	[[WCSendMessage alloc] initWithConnection:_connection message:message];

	// --- close window
	[self close];

	[message release];
}

@end
