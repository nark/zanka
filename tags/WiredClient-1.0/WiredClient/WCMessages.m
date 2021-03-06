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
#import "WCPublicChat.h"
#import "WCReceiveMessage.h"
#import "WCSendMessage.h"
#import "WCSettings.h"
#import "WCSplitView.h"
#import "WCURLTextView.h"
#import "WCUser.h"

@implementation WCMessages

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Messages"];
	
	// --- get parameters
	_connection = [connection retain];

	// --- init our array of messages
	_messages = [[NSMutableArray alloc] init];
	
	// --- load the window
	[self window];
	
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
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(messagesShouldShowBroadcast:)
		name:WCMessagesShouldShowBroadcast
		object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_messages release];
	[_connection release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSFont		*font;
	
	// --- reply on double-click
	[_messageListTableView setDoubleAction:@selector(reply:)];
	
	// --- use a smaller font for the message list
	font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	[[_nickTableColumn dataCell] setFont:font];
	[[_timeTableColumn dataCell] setFont:font];
	
	// --- set window positions
	[self setWindowFrameAutosaveName:@"Messages"];
	[self setShouldCascadeWindows:NO];

	// --- split view position
	[_messageSplitView setAutosaveName:@"Messages"];
	
	// --- table view position
	[_messageListTableView setAutosaveName:@"Messages"];
	[_messageListTableView setAutosaveTableColumns:YES];
	
	// --- set up window
	[self update];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- set titles when host is resolved
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"Messages", @"Messages window title"), 0x2014, [_connection name]]];

	// --- show window
	if([[WCSettings objectForKey:WCShowMessages] boolValue])
		[self showWindow:self];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				forKey:WCShowMessages];

	// --- update the unread count
	[WCSharedMain setUnread:[WCSharedMain unread] - _unread];
	[WCSharedMain updateIcon];
	
	[_messageListTableView setDataSource:NULL];

	[self close];
	[self release];
}



- (void)messagesShouldShowBroadcast:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *uid, *message;
	WCConnection	*connection;
	WCUser			*user;

	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- get the fields of the input buffer
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	uid			= [fields objectAtIndex:0];
	message		= [fields objectAtIndex:1];
	
	// --- get the user
	user		= [[[_connection chat] users] objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- check ignore
	if([user ignore])
		return;
	
	// --- show panel
	NSRunAlertPanel([NSString stringWithFormat:
						NSLocalizedString(@"Broadcast from %@ on %@", @"Broadcast dialog title (nick, server)"),
						[user nick],
						[_connection name]],
					message, NULL, NULL, NULL);
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		// --- dump all messages
		[_messages removeAllObjects];
		[_messageListTableView reloadData];
	
		// --- update the unread count
		[WCSharedMain setUnread:[WCSharedMain unread] - _unread];
		_unread = 0;
		[WCSharedMain updateIcon];
	}
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		value = NO;
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:)) {
		if([[[NSApp currentEvent] characters] characterAtIndex:0] == NSEnterCharacter) {
			[self send:self];
			
			value = YES;
		}
	}
	
	return value;
}



#pragma mark -

- (void)showBroadcast {
	if(![_broadcastWindow isVisible]) {
		[_broadcastWindow center];
		[_broadcastTextView setString:@""];
	}
	
	[_broadcastWindow makeKeyAndOrderFront:self];
}



- (void)update {
	// --- font
	[_messageTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];

	// --- color
	[_messageTextView setForeColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];
	[_messageTextView setBackColor:[WCSettings archivedObjectForKey:WCMessageBackgroundColor]];
	[_messageTextView setURLColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
	[_messageTextView setEventColor:[WCSettings archivedObjectForKey:WCEventTextColor]];
	[_broadcastTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
	[_broadcastTextView setBackgroundColor:[WCSettings archivedObjectForKey:WCMessageBackgroundColor]];
	[_broadcastTextView setTextColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];
	[_broadcastTextView setInsertionPointColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];

	// --- parse text
	[[_messageTextView textStorage]
		replaceCharactersInRange:NSMakeRange(0, [[_messageTextView string] length])
		withAttributedString:[_messageTextView scan:[_messageTextView string]]];
	
	// --- mark it as updated
	[_messageTextView setNeedsDisplay:YES];
}



#pragma mark -

- (void)receive:(NSString *)argument {
	NSArray			*fields;
	NSString		*uid, *msg;
	WCUser			*user;
	WCMessage		*message;

	// --- parse the message
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	uid		= [fields objectAtIndex:0];
	msg		= [fields objectAtIndex:1];
	
	// --- get the user
	user	= [[[_connection chat] users] objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- check ignore
	if([user ignore])
		return;
	
	// --- create a message
	message = [[WCMessage alloc] initWithType:WCMessageTypeFrom];
	[message setUser:user];
	[message setMessage:msg];
	[message setDate:[NSDate date]];
	
	// --- add it to our array of messages
	[self add:message];
	
	if([[WCSettings objectForKey:WCShowMessagesInForeground] boolValue]) {
		[message setRead:YES];

		// --- display an actual receive message window if we should
		[(WCReceiveMessage *) [WCReceiveMessage alloc] initWithConnection:_connection message:message];
	} else {
		[message setRead:NO];

		// --- bump the count of unread messages
		[WCSharedMain setUnread:[WCSharedMain unread] + 1];
		_unread++;
		[WCSharedMain updateIcon];
	}
	
	[message release];
}



- (void)add:(WCMessage *)message {
	[_messages addObject:message];

	[_messageListTableView deselectAll:self];
	[_messageListTableView reloadData];
}



#pragma mark -

- (int)unread {
	return _unread;
}



- (void)setUnread:(int)value {
	_unread = value;
}



#pragma mark -

- (IBAction)reply:(id)sender {
	WCMessage	*message, *newMessage;
	int			row;
	
	// --- get row number
	row	= [_messageListTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get message
	message = [_messages objectAtIndex:[_messages count] - row - 1];
	
	// --- create a new message
	newMessage = [[WCMessage alloc] initWithType:WCMessageTypeTo];
	[newMessage setRead:YES];
	[newMessage setUser:[message user]];
	[newMessage setDate:[NSDate date]];
	
	// --- send new message in response
	[(WCSendMessage *) [WCSendMessage alloc] initWithConnection:_connection message:newMessage];

	[newMessage release];
}



- (IBAction)clearHistory:(id)sender {
	if([_messages count] > 0) {
		// --- bring up an alert
		NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to clear the message history?", @"Clear messages dialog title"),
						  NSLocalizedString(@"Clear", @"Clear messages dialog button"),
						  @"Cancel",
						  NULL,
						  [self window],
						  self,
						  @selector(clearSheetDidEnd: returnCode: contextInfo:),
						  NULL,
						  NULL,
						  NSLocalizedString(@"This cannot be undone.", @"Clear messages dialog description"),
						  NULL);
	}
}



- (IBAction)send:(id)sender {
	[[_connection client] sendCommand:WCBroadcastCommand withArgument:[_broadcastTextView string]];

	[_broadcastWindow close];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_messages count];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	WCMessage	*message;
	int			row;
	
	// --- get row
	row = [_messageListTableView selectedRow];

	if(row < 0) {
		[_messageTextView setString:@""];
		
		return;
	}
	
	// --- get message
	message = [_messages objectAtIndex:[_messages count] - row - 1];
	
	// --- set that it's read
	if(![message read]) {
		[WCSharedMain setUnread:[WCSharedMain unread] - 1];
		_unread--;
		[WCSharedMain updateIcon];
		
		[message setRead:YES];
		[_messageListTableView setNeedsDisplay:YES];
	}
	
	// --- show message
	[[_messageTextView textStorage] setAttributedString:[_messageTextView scan:[message message]]];
}



- (void)tableView:(NSTableView *)sender willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)column row:(int)row {
	WCMessage			*message;
	NSString			*string;
	NSFont				*boldFont;
	NSAttributedString	*boldString;
	NSDictionary		*attributes;
	
	// --- get message
	message = [_messages objectAtIndex:[_messages count] - row - 1];
	string	= [self tableView:sender objectValueForTableColumn:column row:row];
	
	if(![message read]) {
		// --- set bold font for unread messages
		boldFont	= [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
		attributes	= [NSDictionary dictionaryWithObjectsAndKeys:
							boldFont, NSFontAttributeName,
							NULL];
		boldString	= [[NSAttributedString alloc] initWithString:string attributes:attributes];
		
		[cell setAttributedStringValue:boldString];
	} else {
		[cell setStringValue:string];
	}
}



- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	WCMessage		*message;
	
	message = [_messages objectAtIndex:[_messages count] - row - 1];
	
	if(column == _nickTableColumn) {
		if([message type] == WCMessageTypeFrom) {
			return [NSString stringWithFormat:
				 NSLocalizedString(@"From: %@", @"Message from (nick)"), [[message user] nick]];
		} else {
			return [NSString stringWithFormat:
				NSLocalizedString(@"To: %@", @"Message to"), [[message user] nick]];
		}
	}
	else if(column == _timeTableColumn) {
		return [message date];
	}
	
	return NULL;
}

@end
