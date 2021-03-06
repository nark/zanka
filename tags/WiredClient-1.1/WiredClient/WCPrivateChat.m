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
#import "WCClient.h"
#import "WCConnection.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSettings.h"
#import "WCSplitView.h"
#import "WCTypeAheadTableView.h"
#import "WCUser.h"

@implementation WCPrivateChat

- (id)initWithConnection:(WCConnection *)connection inviteUser:(int)inviteUser {
	self = [super initWithConnection:connection nib:@"PrivateChat"];

	// --- get parameters
	_inviteUser		= inviteUser;

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
		selector:@selector(privateChatShouldShowChat:)
		name:WCPrivateChatShouldShowChat
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(privateChatUserDeclinedInvite:)
		name:WCPrivateChatUserDeclinedInvite
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
	
	// --- register for drag'n'drop
	[_userListTableView registerForDraggedTypes:[NSArray arrayWithObjects:WCDragUser, NULL]];

	// --- set up our custom cell type
	iconCell = [[WCIconCell alloc] initWithImageWidth:32 whitespace:YES];
	[_nickTableColumn setDataCell:iconCell];
	[iconCell release];

	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Private Chat"];
	
	// --- split view position
	[_chatSplitView setAutosaveName:@"Private Chat"];
	[_userListSplitView setAutosaveName:@"Private Chat User List"];

	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Private Chat", @"Private chat window title")]];

	// --- set up window
	[self update];
}



- (void)windowWillClose:(NSNotification *)notification {
	// --- send leave command
	[[_connection client] sendCommand:WCLeaveCommand withArgument:[NSString stringWithFormat:
		@"%u", _cid]];
	
	[_userListTableView setDataSource:NULL];

	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)privateChatUserDeclinedInvite:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *uid, *cid;
	WCConnection	*connection;
	WCUser			*user;

	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	
	if((unsigned int) [cid intValue] != _cid)
		return;

	// --- get user
	user	= [[[_connection chat] users] objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- print event
	[self printEvent:[NSString stringWithFormat:
		NSLocalizedString(@"%@ has declined invitation", @"Private chat decline message (nick)"),
		[user nick]]];
}



- (void)privateChatShouldShowChat:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;
		
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
		
	// --- get chat id
	_cid = [argument intValue];
	
	// --- request user list
	[[_connection client] sendCommand:WCWhoCommand withArgument:[NSString stringWithFormat:
		@"%u", _cid]];

	// --- send invite command if we've got a user waiting
	if(_inviteUser > 0) {
		[[_connection client] sendCommand:WCInviteCommand withArgument:[NSString stringWithFormat:
			@"%d%@%u", _inviteUser, WCFieldSeparator, _cid]];
	}

	// --- stop receiving
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
				  name:WCPrivateChatShouldShowChat
				object:NULL];
	
	// --- stop receiving
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
				  name:WCPrivateChatShouldShowChat
				object:NULL];
	
	// --- show window
	[self showWindow:self];
}



- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 64;
	else if(splitView == _chatSplitView)
		return proposedMax - 15;
	
	return proposedMax;
}



#pragma mark -

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
	
	return YES;
}



#pragma mark -

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id 
<NSDraggingInfo>)info proposedRow:(int)row 
proposedDropOperation:(NSTableViewDropOperation)operation {
	if(row < 0)
		return NSDragOperationGeneric;
	
	return NSDragOperationNone;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info 
row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSData			*data;
	WCUser			*user;

	// --- get user from pasteboard
	pasteboard	= [info draggingPasteboard];
	data		= [pasteboard dataForType:WCDragUser];
	user		= [NSUnarchiver unarchiveObjectWithData:data];
	
	// --- send invite command
	[[_connection client] sendCommand:WCInviteCommand withArgument:[NSString stringWithFormat:
		@"%d%@%u", [user uid], WCFieldSeparator, _cid]];

	return YES;
}

@end