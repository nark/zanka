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

#import "NSStringAdditions.h"
#import "WCAccount.h"
#import "WCAccountEditor.h"
#import "WCAccounts.h"
#import "WCConnection.h"
#import "WCMain.h"

@implementation WCAccountEditor

- (id)initWithConnection:(WCConnection *)connection {
	return [self initWithConnection:connection edit:NULL];
}



- (id)initWithConnection:(WCConnection *)connection edit:(WCAccount *)account {
	self = [super initWithWindowNibName:@"AccountEditor"];
	
	// --- get parameters
	_connection = [connection retain];
	
	// --- init array of groups
	_groups = [[NSMutableArray alloc] init];

	// --- load the window
	[self window];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionServerInfoDidChange:)
			   name:WCConnectionServerInfoDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountEditorShouldShowUser:)
			   name:WCAccountEditorShouldShowUser
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountEditorShouldShowGroup:)
			   name:WCAccountEditorShouldShowGroup
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountsShouldAddGroup:)
			   name:WCAccountsShouldAddGroup
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountsShouldCompleteGroups:)
			   name:WCAccountsShouldCompleteGroups
			 object:NULL];

	// --- send groups command
	[_connection sendCommand:WCGroupsCommand withSender:self];

	// --- set up for edit or create
	if(account) {
		_account = [account retain];

		switch([_account type]) {
			case WCAccountTypeUser:
				// --- switch to user
				[_typePopUpButton selectItem:_userMenuItem];
				[self type:self];

				// --- send read command
				[_connection sendCommand:WCReadUserCommand
							withArgument:[_account name]
							  withSender:self];
				break;
			
			case WCAccountTypeGroup:
				// --- switch to group
				[_typePopUpButton selectItem:_groupMenuItem];
				[self type:self];
				
				// --- send read command
				[_connection sendCommand:WCReadGroupCommand
							withArgument:[_account name]
							  withSender:self];
				break;
		}

		// --- switch to edit
		[_okButton setAction:@selector(edit:)];
		[_okButton setTitle:NSLocalizedString(@"Save", @"Account Editor button title")];

		[_typePopUpButton setEnabled:NO];
		[_nameTextField setEnabled:NO];
	} else {
		// --- switch to create
		[_okButton setAction:@selector(create:)];
		[_okButton setTitle:NSLocalizedString(@"Add", @"Account Editor button title")];

		[_typePopUpButton setEnabled:YES];
		[_nameTextField setEnabled:YES];
	}

	// --- show the window
	[self group:self];
	[self showWindow:self];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connection clearSender:self];

	[_connection release];
	[_groups release];
	[_account release];
	[_password release];
	[_group release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSRect		rect;
	NSSize		size;
	
	// --- we're only interested in the window position, so save size
	size = [[self window] frame].size;
	
	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"AccountEditor"];
	
	// --- reset size
	rect = [[self window] frame];
	rect.size = size;
	[[self window] setFrame:rect display:NO];
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Account Editor", @"Account editor window title")]];
	
	// --- menu icons
	[_userMenuItem setImage:[NSImage imageNamed:@"User"]];
	[_groupMenuItem setImage:[NSImage imageNamed:@"Group"]];
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Account Editor", @"Account editor window title")]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)accountEditorShouldShowUser:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *name, *password, *group;
	WCConnection	*connection;
	BOOL			elevate;
	int				limit;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	name		= [fields objectAtIndex:0];
	password	= [fields objectAtIndex:1];
	group		= [fields objectAtIndex:2];

	if(![name isEqualToString:[_account name]])
		return;

	// --- stop receiving the notification
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountEditorShouldShowUser
		object:NULL];

	// --- save the password and group
	_password	= [password retain];
	_group		= [group retain];
	
	// --- can we give privileges that we do not possess?
	elevate = [[_connection account] elevatePrivileges];
	
	// --- set fields
	[_nameTextField setStringValue:name];
	[_passwordTextField setStringValue:password];

	// --- select group
	if([_group length] > 0)
		[_groupPopUpButton selectItemWithTitle:_group];
	
	[self group:self];
	
	// --- set buttons
	[_getUserInfoButton setState:[[fields objectAtIndex:3] intValue]];
	[_broadcastButton setState:[[fields objectAtIndex:4] intValue]];
	[_postNewsButton setState:[[fields objectAtIndex:5] intValue]];
	[_clearNewsButton setState:[[fields objectAtIndex:6] intValue]];
	
	if([_connection protocol] >= 1.1)
		[_setTopicButton setState:[[fields objectAtIndex:23] intValue]];
	
	[_downloadButton setState:[[fields objectAtIndex:7] intValue]];
	[_uploadButton setState:[[fields objectAtIndex:8] intValue]];
	[_uploadAnywhereButton setState:[[fields objectAtIndex:9] intValue]];
	[_createFoldersButton setState:[[fields objectAtIndex:10] intValue]];
	[_moveButton setState:[[fields objectAtIndex:11] intValue]];
	[_deleteButton setState:[[fields objectAtIndex:12] intValue]];
	[_viewDropBoxButton setState:[[fields objectAtIndex:13] intValue]];
	
	[_createAccountsButton setState:[[fields objectAtIndex:14] intValue]];
	[_editAccountsButton setState:[[fields objectAtIndex:15] intValue]];
	[_deleteAccountsButton setState:[[fields objectAtIndex:16] intValue]];
	[_elevatePrivilegesButton setState:[[fields objectAtIndex:17] intValue]];
	[_kickUsersButton setState:[[fields objectAtIndex:18] intValue]];
	[_banUsersButton setState:[[fields objectAtIndex:19] intValue]];
	[_cannotBeKickedButton setState:[[fields objectAtIndex:20] intValue]];

	// --- set text fields
	limit = [[fields objectAtIndex:21] intValue] / 1024;
	
	if(limit > 0)
		[_downloadSpeedTextField setIntValue:limit];

	limit = [[fields objectAtIndex:22] intValue] / 1024;
	
	if(limit > 0)
		[_uploadSpeedTextField setIntValue:limit];
}



- (void)accountEditorShouldShowGroup:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *name;
	WCConnection	*connection;
	BOOL			user = NO, elevate;
	int				limit;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	name		= [fields objectAtIndex:0];

	if(![name isEqualToString:[_account name]]) {
		user = ([_typePopUpButton selectedItem] == _userMenuItem);
		
		if(!user)
			return;
	}

	// --- stop receiving the notification
	if(!user) {
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:WCAccountEditorShouldShowGroup
			object:NULL];
	}

	// --- can we give privileges that we do not possess?
	elevate = [[_connection account] elevatePrivileges];
	
	// --- set buttons
	if(!user)
		[_nameTextField setStringValue:name];

	[_getUserInfoButton setState:[[fields objectAtIndex:1] intValue]];
	[_broadcastButton setState:[[fields objectAtIndex:2] intValue]];
	[_postNewsButton setState:[[fields objectAtIndex:3] intValue]];
	[_clearNewsButton setState:[[fields objectAtIndex:4] intValue]];

	if([_connection protocol] >= 1.1)
		[_setTopicButton setState:[[fields objectAtIndex:21] intValue]];

	[_downloadButton setState:[[fields objectAtIndex:5] intValue]];
	[_uploadButton setState:[[fields objectAtIndex:6] intValue]];
	[_uploadAnywhereButton setState:[[fields objectAtIndex:7] intValue]];
	[_createFoldersButton setState:[[fields objectAtIndex:8] intValue]];
	[_moveButton setState:[[fields objectAtIndex:9] intValue]];
	[_deleteButton setState:[[fields objectAtIndex:10] intValue]];
	[_viewDropBoxButton setState:[[fields objectAtIndex:11] intValue]];

	[_createAccountsButton setState:[[fields objectAtIndex:12] intValue]];
	[_editAccountsButton setState:[[fields objectAtIndex:13] intValue]];
	[_deleteAccountsButton setState:[[fields objectAtIndex:14] intValue]];
	[_elevatePrivilegesButton setState:[[fields objectAtIndex:14] intValue]];
	[_kickUsersButton setState:[[fields objectAtIndex:16] intValue]];
	[_banUsersButton setState:[[fields objectAtIndex:17] intValue]];
	[_cannotBeKickedButton setState:[[fields objectAtIndex:18] intValue]];

	// --- set text fields
	limit = [[fields objectAtIndex:19] intValue] / 1024;
	
	if(limit > 0)
		[_downloadSpeedTextField setIntValue:limit];

	limit = [[fields objectAtIndex:20] intValue] / 1024;
	
	if(limit > 0)
		[_uploadSpeedTextField setIntValue:limit];

}


- (void)accountsShouldAddGroup:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- add it to our array of group names
	[_groups addObject:argument];
}



- (void)accountsShouldCompleteGroups:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- stop receiving these notifications
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountsShouldAddGroup
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountsShouldCompleteGroups
		object:NULL];

	// --- sort the list
	[_groups sortUsingSelector:@selector(compare:)];

	// --- enter the accumulated groups in our menu
	[_groupPopUpButton addItemsWithTitles:_groups];
}



#pragma mark -

- (IBAction)create:(id)sender {
	NSString		*password, *group;
	
	// --- very interesting bug.. if it remains editable and in focus and the user hits
	//     return instead of clicking on the button, the window is not released
	//     when [self close] is called
	//     instead, app crashes and burns with a weird backtrack in NSSecureTextField
	[_passwordTextField setEditable:NO];
	
	// --- don't encrypt the password if the field is empty, just send
	if([[_passwordTextField stringValue] isEqualToString:@""])
		password = @"";
	else
		password = [[_passwordTextField stringValue] SHA1];

	// --- get group
	if([_groupPopUpButton selectedItem] != _noneMenuItem)
		group = [_groupPopUpButton titleOfSelectedItem];
	else
		group = @"";
	
	// --- send create account command
	if([_typePopUpButton selectedItem] == _userMenuItem) {
		[_connection sendCommand:WCCreateUserCommand
					withArgument:[NSString stringWithFormat:
				@"%@%@%@%@%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			[_nameTextField stringValue],
			WCFieldSeparator,
			password,
			WCFieldSeparator,
			group,
			WCFieldSeparator,
			[_getUserInfoButton intValue],
			WCFieldSeparator,
			[_broadcastButton intValue],
			WCFieldSeparator,
			[_postNewsButton intValue],
			WCFieldSeparator,
			[_clearNewsButton intValue],
			WCFieldSeparator,
			[_downloadButton intValue],
			WCFieldSeparator,
			[_uploadButton intValue],
			WCFieldSeparator,
			[_uploadAnywhereButton intValue],
			WCFieldSeparator,
			[_createFoldersButton intValue],
			WCFieldSeparator,
			[_moveButton intValue],
			WCFieldSeparator,
			[_deleteButton intValue],
			WCFieldSeparator,
			[_viewDropBoxButton intValue],
			WCFieldSeparator,
			[_createAccountsButton intValue],
			WCFieldSeparator,
			[_editAccountsButton intValue],
			WCFieldSeparator,
			[_deleteAccountsButton intValue],
			WCFieldSeparator,
			[_elevatePrivilegesButton intValue],
			WCFieldSeparator,
			[_kickUsersButton intValue],
			WCFieldSeparator,
			[_banUsersButton intValue],
			WCFieldSeparator,
			[_cannotBeKickedButton intValue],
			WCFieldSeparator,
			[_downloadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			[_uploadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			[_setTopicButton intValue]]
					  withSender:self];
	}
	else if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[_connection sendCommand:WCCreateGroupCommand
					withArgument:[NSString stringWithFormat:
			@"%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			[_nameTextField stringValue],
			WCFieldSeparator,
			[_getUserInfoButton intValue],
			WCFieldSeparator,
			[_broadcastButton intValue],
			WCFieldSeparator,
			[_postNewsButton intValue],
			WCFieldSeparator,
			[_clearNewsButton intValue],
			WCFieldSeparator,
			[_downloadButton intValue],
			WCFieldSeparator,
			[_uploadButton intValue],
			WCFieldSeparator,
			[_uploadAnywhereButton intValue],
			WCFieldSeparator,
			[_createFoldersButton intValue],
			WCFieldSeparator,
			[_moveButton intValue],
			WCFieldSeparator,
			[_deleteButton intValue],
			WCFieldSeparator,
			[_viewDropBoxButton intValue],
			WCFieldSeparator,
			[_createAccountsButton intValue],
			WCFieldSeparator,
			[_editAccountsButton intValue],
			WCFieldSeparator,
			[_deleteAccountsButton intValue],
			WCFieldSeparator,
			[_elevatePrivilegesButton intValue],
			WCFieldSeparator,
			[_kickUsersButton intValue],
			WCFieldSeparator,
			[_banUsersButton intValue],
			WCFieldSeparator,
			[_cannotBeKickedButton intValue],
			WCFieldSeparator,
			[_downloadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			[_uploadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			[_setTopicButton intValue]]
					  withSender:self];
	}
	
	// --- tell accounts to reload
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCAccountsShouldReload
		object:_connection];
		
	// --- close window
	[self close];
}



- (IBAction)edit:(id)sender {
	NSString		*password, *group;
	
	// --- very interesting bug.. if it remains editable and in focus and the user hits
	//     return instead of clicking on the button, the window is not released
	//     when [self close] is called
	//     instead, app crashes and burns with a weird backtrack in NSSecureTextField
	[_passwordTextField setEditable:NO];
	
	// --- don't encrypt the password if the field is empty, just send
	if([[_passwordTextField stringValue] isEqualToString:@""]) {
		password = @"";
	} else {
		// --- only send a new encrypted password if it's actually changed
		if([_password isEqualToString:[_passwordTextField stringValue]])
			password = _password;
		else
			password = [[_passwordTextField stringValue] SHA1];
	}
	
	// --- get group
	if([_groupPopUpButton selectedItem] != _noneMenuItem)
		group = [_groupPopUpButton titleOfSelectedItem];
	else
		group = @"";
	
	// --- send edit account command
	if([_account type] == WCAccountTypeUser) {
		[_connection sendCommand:WCEditUserCommand
					withArgument:[NSString stringWithFormat:
			@"%@%@%@%@%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			[_nameTextField stringValue],
			WCFieldSeparator,
			password,
			WCFieldSeparator,
			group,
			WCFieldSeparator,
			[_getUserInfoButton intValue],
			WCFieldSeparator,
			[_broadcastButton intValue],
			WCFieldSeparator,
			[_postNewsButton intValue],
			WCFieldSeparator,
			[_clearNewsButton intValue],
			WCFieldSeparator,
			[_downloadButton intValue],
			WCFieldSeparator,
			[_uploadButton intValue],
			WCFieldSeparator,
			[_uploadAnywhereButton intValue],
			WCFieldSeparator,
			[_createFoldersButton intValue],
			WCFieldSeparator,
			[_moveButton intValue],
			WCFieldSeparator,
			[_deleteButton intValue],
			WCFieldSeparator,
			[_viewDropBoxButton intValue],
			WCFieldSeparator,
			[_createAccountsButton intValue],
			WCFieldSeparator,
			[_editAccountsButton intValue],
			WCFieldSeparator,
			[_deleteAccountsButton intValue],
			WCFieldSeparator,
			[_elevatePrivilegesButton intValue],
			WCFieldSeparator,
			[_kickUsersButton intValue],
			WCFieldSeparator,
			[_banUsersButton intValue],
			WCFieldSeparator,
			[_cannotBeKickedButton intValue],
			WCFieldSeparator,
			[_downloadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			[_uploadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			[_setTopicButton intValue]]
					  withSender:self];
	} else {
		[_connection sendCommand:WCEditGroupCommand
					withArgument:[NSString stringWithFormat:
			@"%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			[_nameTextField stringValue],
			WCFieldSeparator,
			[_getUserInfoButton intValue],
			WCFieldSeparator,
			[_broadcastButton intValue],
			WCFieldSeparator,
			[_postNewsButton intValue],
			WCFieldSeparator,
			[_clearNewsButton intValue],
			WCFieldSeparator,
			[_downloadButton intValue],
			WCFieldSeparator,
			[_uploadButton intValue],
			WCFieldSeparator,
			[_uploadAnywhereButton intValue],
			WCFieldSeparator,
			[_createFoldersButton intValue],
			WCFieldSeparator,
			[_moveButton intValue],
			WCFieldSeparator,
			[_deleteButton intValue],
			WCFieldSeparator,
			[_viewDropBoxButton intValue],
			WCFieldSeparator,
			[_createAccountsButton intValue],
			WCFieldSeparator,
			[_editAccountsButton intValue],
			WCFieldSeparator,
			[_deleteAccountsButton intValue],
			WCFieldSeparator,
			[_elevatePrivilegesButton intValue],
			WCFieldSeparator,
			[_kickUsersButton intValue],
			WCFieldSeparator,
			[_banUsersButton intValue],
			WCFieldSeparator,
			[_cannotBeKickedButton intValue],
			WCFieldSeparator,
			[_downloadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			[_uploadSpeedTextField intValue] * 1024,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			0,
			WCFieldSeparator,
			[_setTopicButton intValue]]
					  withSender:self];
	}

	// --- close window
	[self close];
}



- (IBAction)selectAll:(id)sender {
	// --- check all the buttons we can access
	if([_getUserInfoButton isEnabled])
		[_getUserInfoButton setState:NSOnState];
	
	if([_broadcastButton isEnabled])
		[_broadcastButton setState:NSOnState];
	
	if([_setTopicButton isEnabled])
		[_setTopicButton setState:NSOnState];
	
	if([_postNewsButton isEnabled])
		[_postNewsButton setState:NSOnState];

	if([_clearNewsButton isEnabled])
		[_clearNewsButton setState:NSOnState];
	
	if([_downloadButton isEnabled])
		[_downloadButton setState:NSOnState];
	
	if([_uploadButton isEnabled])
		[_uploadButton setState:NSOnState];
	
	if([_uploadAnywhereButton isEnabled])
		[_uploadAnywhereButton setState:NSOnState];
	
	if([_createFoldersButton isEnabled])
		[_createFoldersButton setState:NSOnState];

	if([_moveButton isEnabled])
		[_moveButton setState:NSOnState];
	
	if([_deleteButton isEnabled])
		[_deleteButton setState:NSOnState];
	
	if([_viewDropBoxButton isEnabled])
		[_viewDropBoxButton setState:NSOnState];
	
	if([_createAccountsButton isEnabled])
		[_createAccountsButton setState:NSOnState];
	
	if([_editAccountsButton isEnabled])
		[_editAccountsButton setState:NSOnState];
	
	if([_deleteAccountsButton isEnabled])
		[_deleteAccountsButton setState:NSOnState];
	
	if([_elevatePrivilegesButton isEnabled])
		[_elevatePrivilegesButton setState:NSOnState];
	
	if([_kickUsersButton isEnabled])
		[_kickUsersButton setState:NSOnState];
	
	if([_banUsersButton isEnabled])
		[_banUsersButton setState:NSOnState];
	
	if([_cannotBeKickedButton isEnabled])
		[_cannotBeKickedButton setState:NSOnState];
}



- (IBAction)type:(id)sender {
	if([_typePopUpButton selectedItem] == _userMenuItem) {
		[_passwordTextField setEnabled:YES];
		[_groupPopUpButton setEnabled:YES];
		
		[self group:self];
	}
	else if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[_passwordTextField setEnabled:NO];
		[_groupPopUpButton setEnabled:NO];
		
		[_groupPopUpButton selectItem:_noneMenuItem];
		[self group:self];
	}
}



- (IBAction)group:(id)sender {
	if([_groupPopUpButton selectedItem] == _noneMenuItem || ![[_groupPopUpButton selectedItem] title]) {
		// --- select none
		[_groupPopUpButton selectItem:_noneMenuItem];
		
		if([[_connection account] elevatePrivileges]) {
			// --- enable all buttons
			[_getUserInfoButton setEnabled:YES];
			[_broadcastButton setEnabled:YES];
			[_setTopicButton setEnabled:YES];
			[_postNewsButton setEnabled:YES];
			[_clearNewsButton setEnabled:YES];
			
			[_downloadButton setEnabled:YES];
			[_uploadButton setEnabled:YES];
			[_uploadAnywhereButton setEnabled:YES];
			[_createFoldersButton setEnabled:YES];
			[_moveButton setEnabled:YES];
			[_deleteButton setEnabled:YES];
			[_viewDropBoxButton setEnabled:YES];
			
			[_createAccountsButton setEnabled:YES];
			[_editAccountsButton setEnabled:YES];
			[_deleteAccountsButton setEnabled:YES];
			[_elevatePrivilegesButton setEnabled:YES];
			[_kickUsersButton setEnabled:YES];
			[_banUsersButton setEnabled:YES];
			[_cannotBeKickedButton setEnabled:YES];
			
			[_downloadSpeedTextField setEnabled:YES];
			[_uploadSpeedTextField setEnabled:YES];
		} else {
			// --- enable those we have
			[_getUserInfoButton setEnabled:[[_connection account] getUserInfo]];
			[_broadcastButton setEnabled:[[_connection account] broadcast]];
			[_setTopicButton setEnabled:[[_connection account] setTopic]];
			[_postNewsButton setEnabled:[[_connection account] postNews]];
			[_clearNewsButton setEnabled:[[_connection account] clearNews]];
			
			[_downloadButton setEnabled:[[_connection account] download]];
			[_uploadButton setEnabled:[[_connection account] upload]];
			[_uploadAnywhereButton setEnabled:[[_connection account] uploadAnywhere]];
			[_createFoldersButton setEnabled:[[_connection account] createFolders]];
			[_moveButton setEnabled:[[_connection account] alterFiles]];
			[_deleteButton setEnabled:[[_connection account] deleteFiles]];
			[_viewDropBoxButton setEnabled:[[_connection account] viewDropBoxes]];
			
			[_createAccountsButton setEnabled:[[_connection account] createAccounts]];
			[_editAccountsButton setEnabled:[[_connection account] editAccounts]];
			[_deleteAccountsButton setEnabled:[[_connection account] deleteAccounts]];
			[_elevatePrivilegesButton setEnabled:[[_connection account] elevatePrivileges]];
			[_kickUsersButton setEnabled:[[_connection account] kickUsers]];
			[_banUsersButton setEnabled:[[_connection account] banUsers]];
			[_cannotBeKickedButton setEnabled:[[_connection account] cannotBeKicked]];
		}

		[_selectAllButton setEnabled:YES];
	} else {
		// --- send read group command
		[_connection sendCommand:WCReadGroupCommand
					withArgument:[[_groupPopUpButton selectedItem] title]
					  withSender:self];
		
		// --- disable buttons
		[_getUserInfoButton setEnabled:NO];
		[_broadcastButton setEnabled:NO];
		[_setTopicButton setEnabled:NO];
		[_postNewsButton setEnabled:NO];
		[_clearNewsButton setEnabled:NO];
		
		[_downloadButton setEnabled:NO];
		[_uploadButton setEnabled:NO];
		[_uploadAnywhereButton setEnabled:NO];
		[_createFoldersButton setEnabled:NO];
		[_moveButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
		[_viewDropBoxButton setEnabled:NO];
		
		[_createAccountsButton setEnabled:NO];
		[_editAccountsButton setEnabled:NO];
		[_deleteAccountsButton setEnabled:NO];
		[_elevatePrivilegesButton setEnabled:NO];
		[_kickUsersButton setEnabled:NO];
		[_banUsersButton setEnabled:NO];
		[_cannotBeKickedButton setEnabled:NO];
		
		[_downloadSpeedTextField setEnabled:NO];
		[_uploadSpeedTextField setEnabled:NO];

		[_selectAllButton setEnabled:NO];
	}
}

@end
