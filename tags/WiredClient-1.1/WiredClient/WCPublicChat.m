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
#import "WCAccount.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSecureSocket.h"
#import "WCSettings.h"
#import "WCSplitView.h"
#import "WCToolbar.h"
#import "WCTypeAheadTableView.h"
#import "WCUser.h"

@implementation WCPublicChat

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithConnection:connection nib:@"PublicChat"];

	// --- get the parameters
	_cid = 1;
	
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
		selector:@selector(connectionHasClosed:)
		name:WCConnectionHasClosed
			 object:NULL];
		
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WCIconCell		*iconCell;
	
	// --- send private message on double-click
	[_userListTableView setDoubleAction:@selector(sendPrivateMessage:)];
	
	// --- set up our custom cell type
	iconCell = [[WCIconCell alloc] initWithImageWidth:32 whitespace:YES];
	[_nickTableColumn setDataCell:iconCell];
	[iconCell release];

	// --- add the toolbar
	[[self window] setToolbar:[[_connection toolbar] chatToolbar]];
	
	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Public Chat"];
	
	// --- split view position
	[_chatSplitView setAutosaveName:@"Public Chat"];
	[_userListSplitView setAutosaveName:@"Public Chat User List"];

	// --- set up window
	[self update];
	[self updateButtons];
}



- (BOOL)windowShouldClose:(id)sender {
	// --- if we're to confirm, pull down a sheet and handle window closing ourselves
	if([[WCSettings objectForKey:WCConfirmDisconnect] boolValue] == YES &&
	   [[_connection client] connected]) {
		NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to disconnect?", @"Disconnect dialog title"),
						  NSLocalizedString(@"Disconnect", @"Disconnect dialog button"), @"Cancel",
						  NULL,
						  [self window],
						  self,
						  @selector(disconnectSheetDidEnd: returnCode: contextInfo:),
						  NULL,
						  NULL,
						  NSLocalizedString(@"Disconnecting will close any ongoing file transfers.", @"Disconnect dialog description"),
						  NULL);
		
		return NO;
	}

	return YES;
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCConnectionShouldTerminate
		object:_connection];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCConnectedEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCConnectedEventSound]] play];

	// --- set titles when host is resolved
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Chat", @"Chat window title")]];

	// --- show window
	[self showWindow:self];
}



- (void)connectionHasClosed:(NSNotification *)notification {
	if([notification object] == _connection) {
		// --- play sound
		if([(NSString *) [WCSettings objectForKey:WCDisconnectedEventSound] length] > 0)
			[[NSSound soundNamed:[WCSettings objectForKey:WCDisconnectedEventSound]] play];
		
		// --- display connection died error
		[[_connection error] raiseError];
		
		// --- set new title
		[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@ %C %@",
			[_connection name],
			0x2014,
			NSLocalizedString(@"Chat", @"Chat window title"),
			0x2014,
			NSLocalizedString(@"Disconnected", "Chat window title")]];
	}
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	[_userListTableView setDataSource:NULL];

	[self release];
}


// --- contributed by sdz and kim
// --- do we want it?
#if 0
- (void)messagesShouldShowMessage:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *uid, *msg;
	WCConnection	*connection;
	
	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	if(![[WCSettings objectForKey:WCShowMessagesInChat] boolValue])
		return;

	// --- parse the message
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	uid		= [fields objectAtIndex:0];
	msg		= [fields objectAtIndex:1];
	
	// --- construct new argument
	argument = [NSString stringWithFormat:@"%u%@%@%@<<< [%@] %@ >>>",
		1, WCFieldSeparator, uid, WCFieldSeparator, uid, msg];

	// --- broadcast chat received
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCChatShouldPrintChat
		object:[NSArray arrayWithObjects:_connection, argument, NULL]];		
}
#endif



- (void)disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[self close];
}



- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 175;
	else if(splitView == _chatSplitView)
		return proposedMax - 15;
	
	return proposedMax;
}



- (void)kickSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCUser		*user = (WCUser *) contextInfo;

	if(returnCode == NSRunStoppedResponse) {
		// --- send the kick command
		[[_connection client] sendCommand:WCKickCommand withArgument:[NSString stringWithFormat:
			@"%d%@%@", [user uid], WCFieldSeparator, [_kickMessageTextField stringValue]]];
	
		[user release];
	}
	
	// --- close sheet
	[_kickMessagePanel close];
	
	// --- clear for next round
	[_kickMessageTextField setStringValue:@""];
}




- (void)banSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCUser		*user = (WCUser *) contextInfo;

	if(returnCode == NSRunStoppedResponse) {
		// --- send the kick command
		[[_connection client] sendCommand:WCBanCommand withArgument:[NSString stringWithFormat:
			@"%d%@%@", [user uid], WCFieldSeparator, [_banMessageTextField stringValue]]];
		
		[user release];
	}
	
	// --- close sheet
	[_banMessagePanel close];
	
	// --- clear for next round
	[_banMessageTextField setStringValue:@""];
}




#pragma mark -

- (void)showInvite:(NSString *)argument {
	NSArray			*fields;
	NSString		*uid, *cid;
	NSString		*title, *description;
	WCUser			*user;
	int				result;
	
	// --- parse argument
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	
	// --- get user
	user	= [_shownUsers objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- check ignore
	if([user ignore])
		return;
	
	// --- set alert fields
	title = [NSString stringWithFormat:
				NSLocalizedString(@"%@ has invited you to a private chat.",
								  @"Private chat invite dialog title (nick)"),
				[user nick]];
	description	= [NSString stringWithFormat:
				NSLocalizedString(@"Join to open a separate private chat with %@.",
								  @"Private chat invite dialog description (nick)"),
				[user nick]];

	// --- bring up the alert
	result = NSRunAlertPanel(title, description,
							 NSLocalizedString(@"Join", @"Private chat invite button title"),
							 NSLocalizedString(@"Ignore", @"Private chat invite button title"),
							 NSLocalizedString(@"Decline", @"Private chat invite button title"));

	if(result == NSAlertDefaultReturn) {
		// --- create private chat
		[[WCPrivateChat alloc] initWithConnection:_connection inviteUser:0];
		
		// --- send the join command
		[[_connection client] sendCommand:WCJoinCommand withArgument:[NSString stringWithFormat:
			@"%u", (unsigned int) [cid intValue]]];
		
		// --- announce joined
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCPrivateChatShouldShowChat
						  object:[NSArray arrayWithObjects:_connection, cid, NULL]];
	}
	else if(result == NSAlertOtherReturn) {
		// --- send the decline command
		[[_connection client] sendCommand:WCDeclineCommand withArgument:[NSString stringWithFormat:
			@"%u", (unsigned int) [cid intValue]]];
	}
}



- (void)updateButtons {
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow];
	
	if(row < 0) {
		[_privateChatButton setEnabled:NO];
		[_banButton setEnabled:NO];
		[_kickButton setEnabled:NO];
	} else {
		[_privateChatButton setEnabled:YES];

		if([[_connection account] kickUsers])
			[_kickButton setEnabled:YES];
		else
			[_kickButton setEnabled:NO];
	
		if([[_connection account] banUsers])
			[_banButton setEnabled:YES];
		else
			[_banButton setEnabled:NO];
	}
	
	[super updateButtons];
}



- (BOOL)validateMenuItem:(id <NSMenuItem>)item {
	if(item == _getInfoMenuItem)
		return [[_connection account] getUserInfo];
	else if(item == _ignoreMenuItem) {
		NSNumber	*key;
		WCUser		*user;
		int			row;
		
		// --- get row
		row		= [_userListTableView selectedRow]; 
		
		// --- get user
		key		= [_sortedUsers objectAtIndex:row];
		user	= [_shownUsers objectForKey:key];
		
		// --- transpose ignore/unignore
		if([user ignore]) {
			[item setTitle:NSLocalizedString(@"Unignore", "User list menu title")];
			[item setAction:@selector(unignore:)];
		} else {
			[item setTitle:NSLocalizedString(@"Ignore", "User list menu title")];
			[item setAction:@selector(ignore:)];
		}
		
		return YES;
	}
	else if(item == _kickMenuItem)
		return [[_connection account] kickUsers];
	else if(item == _banMenuItem)
		return [[_connection account] banUsers];

	return YES;
}



#pragma mark -

- (IBAction)startPrivateChat:(id)sender {
	NSNumber	*key;
	WCUser		*user;
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow]; 
	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- create private chat
	[(WCPrivateChat *) [WCPrivateChat alloc] initWithConnection:_connection inviteUser:[user uid]];
	
	// --- create private chat on server
	[[_connection client] sendCommand:WCPrivateChatCommand];
}



- (IBAction)ban:(id)sender {
	NSNumber	*key;
	WCUser		*user;
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow];
	 
	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- bring up sheet
	[NSApp beginSheet:_banMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(banSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[user retain]];
}



- (IBAction)kick:(id)sender {
	NSNumber	*key;
	WCUser		*user;
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow]; 

	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- bring up sheet
	[NSApp beginSheet:_kickMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(kickSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[user retain]];
}

@end