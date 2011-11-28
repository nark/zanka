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
#import "WCClient.h"
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
	[[_connection client] sendCommand:[NSString stringWithFormat:
		@"%@", WCGroupsCommand]];

	// --- set up for edit or create
	if(account) {
		_account = [account retain];

		switch([_account type]) {
			case WCAccountTypeUser:
				// --- switch to user
				[_typePopUpButton selectItem:_userMenuItem];
				[self type:self];

				// --- send read command
				[[_connection client] sendCommand:[NSString stringWithFormat:
					@"%@ %@", WCReadUserCommand, [_account name]]];
				break;
			
			case WCAccountTypeGroup:
				// --- switch to group
				[_typePopUpButton selectItem:_groupMenuItem];
				[self type:self];
				
				// --- send read command
				[[_connection client] sendCommand:[NSString stringWithFormat:
					@"%@ %@", WCReadGroupCommand, [_account name]]];
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

	[_connection release];
	[_groups release];
	[_account release];
	[_password release];
	[_group release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"AccountEditor"];
	
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
	if([[fields objectAtIndex:3] intValue] == 1)
		[_getUserInfoButton setState:NSOnState];
	else
		[_getUserInfoButton setState:NSOffState];
	
	if([[fields objectAtIndex:4] intValue] == 1)
		[_broadcastButton setState:NSOnState];
	else
		[_broadcastButton setState:NSOffState];
	
	if([[fields objectAtIndex:5] intValue] == 1)
		[_postNewsButton setState:NSOnState];
	else
		[_postNewsButton setState:NSOffState];
	
	if([[fields objectAtIndex:6] intValue] == 1)
		[_clearNewsButton setState:NSOnState];
	else
		[_clearNewsButton setState:NSOffState];
	
	if([[fields objectAtIndex:7] intValue] == 1)
		[_downloadButton setState:NSOnState];
	else
		[_downloadButton setState:NSOffState];
	
	if([[fields objectAtIndex:8] intValue] == 1)
		[_uploadButton setState:NSOnState];
	else
		[_uploadButton setState:NSOffState];
	
	if([[fields objectAtIndex:9] intValue] == 1)
		[_uploadAnywhereButton setState:NSOnState];
	else
		[_uploadAnywhereButton setState:NSOffState];
	
	if([[fields objectAtIndex:10] intValue] == 1)
		[_createFoldersButton setState:NSOnState];
	else
		[_createFoldersButton setState:NSOffState];
	
	if([[fields objectAtIndex:11] intValue] == 1)
		[_moveButton setState:NSOnState];
	else
		[_moveButton setState:NSOffState];
	
	if([[fields objectAtIndex:12] intValue] == 1)
		[_deleteButton setState:NSOnState];
	else
		[_deleteButton setState:NSOffState];
	
	if([[fields objectAtIndex:13] intValue] == 1)
		[_viewDropBoxButton setState:NSOnState];
	else
		[_viewDropBoxButton setState:NSOffState];
	
	if([[fields objectAtIndex:14] intValue] == 1)
		[_createAccountsButton setState:NSOnState];
	else
		[_createAccountsButton setState:NSOffState];
	
	if([[fields objectAtIndex:15] intValue] == 1)
		[_editAccountsButton setState:NSOnState];
	else
		[_editAccountsButton setState:NSOffState];

	if([[fields objectAtIndex:16] intValue] == 1)
		[_deleteAccountsButton setState:NSOnState];
	else
		[_deleteAccountsButton setState:NSOffState];
	
	if([[fields objectAtIndex:17] intValue] == 1)
		[_elevatePrivilegesButton setState:NSOnState];
	else
		[_elevatePrivilegesButton setState:NSOffState];
	
	if([[fields objectAtIndex:18] intValue] == 1)
		[_kickUsersButton setState:NSOnState];
	else
		[_kickUsersButton setState:NSOffState];
	
	if([[fields objectAtIndex:19] intValue] == 1)
		[_banUsersButton setState:NSOnState];
	else
		[_banUsersButton setState:NSOffState];
	
	if([[fields objectAtIndex:20] intValue] == 1)
		[_cannotBeKickedButton setState:NSOnState];
	else
		[_cannotBeKickedButton setState:NSOffState];

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

	if([[fields objectAtIndex:1] intValue] == 1)
		[_getUserInfoButton setState:NSOnState];
	else
		[_getUserInfoButton setState:NSOffState];

	if([[fields objectAtIndex:2] intValue] == 1)
		[_broadcastButton setState:NSOnState];
	else
		[_broadcastButton setState:NSOffState];
	
	if([[fields objectAtIndex:3] intValue] == 1)
		[_postNewsButton setState:NSOnState];
	else
		[_postNewsButton setState:NSOffState];
	
	if([[fields objectAtIndex:4] intValue] == 1)
		[_clearNewsButton setState:NSOnState];
	else
		[_clearNewsButton setState:NSOffState];
	
	if([[fields objectAtIndex:5] intValue] == 1)
		[_downloadButton setState:NSOnState];
	else
		[_downloadButton setState:NSOffState];
	
	if([[fields objectAtIndex:6] intValue] == 1)
		[_uploadButton setState:NSOnState];
	else
		[_uploadButton setState:NSOffState];
	
	if([[fields objectAtIndex:7] intValue] == 1)
		[_uploadAnywhereButton setState:NSOnState];
	else
		[_uploadAnywhereButton setState:NSOffState];
	
	if([[fields objectAtIndex:8] intValue] == 1)
		[_createFoldersButton setState:NSOnState];
	else
		[_createFoldersButton setState:NSOffState];
	
	if([[fields objectAtIndex:9] intValue] == 1)
		[_moveButton setState:NSOnState];
	else
		[_moveButton setState:NSOffState];
	
	if([[fields objectAtIndex:10] intValue] == 1)
		[_deleteButton setState:NSOnState];
	else
		[_deleteButton setState:NSOffState];
	
	if([[fields objectAtIndex:11] intValue] == 1)
		[_viewDropBoxButton setState:NSOnState];
	else
		[_viewDropBoxButton setState:NSOffState];

	if([[fields objectAtIndex:12] intValue] == 1)
		[_createAccountsButton setState:NSOnState];
	else
		[_createAccountsButton setState:NSOffState];
	
	if([[fields objectAtIndex:13] intValue] == 1)
		[_editAccountsButton setState:NSOnState];
	else
		[_editAccountsButton setState:NSOffState];

	if([[fields objectAtIndex:14] intValue] == 1)
		[_deleteAccountsButton setState:NSOnState];
	else
		[_deleteAccountsButton setState:NSOffState];

	if([[fields objectAtIndex:15] intValue] == 1)
		[_elevatePrivilegesButton setState:NSOnState];
	else
		[_elevatePrivilegesButton setState:NSOffState];
	
	if([[fields objectAtIndex:16] intValue] == 1)
		[_kickUsersButton setState:NSOnState];
	else
		[_kickUsersButton setState:NSOffState];
	
	if([[fields objectAtIndex:17] intValue] == 1)
		[_banUsersButton setState:NSOnState];
	else
		[_banUsersButton setState:NSOffState];
	
	if([[fields objectAtIndex:18] intValue] == 1)
		[_cannotBeKickedButton setState:NSOnState];
	else
		[_cannotBeKickedButton setState:NSOffState];

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
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@%@%@%@%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			WCCreateUserCommand,
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
			[_uploadSpeedTextField intValue] * 1024]];
	}
	else if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			WCCreateGroupCommand,
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
			[_uploadSpeedTextField intValue] * 1024]];
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
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@%@%@%@%@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			WCEditUserCommand,
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
			[_uploadSpeedTextField intValue] * 1024]];
	} else {
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u%@%u",
			WCEditGroupCommand,
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
			[_uploadSpeedTextField intValue] * 1024]];
	}

	// --- close window
	[self close];
}



- (IBAction)selectAll:(id)sender {
	if([_postNewsButton isEnabled])
		[_postNewsButton setState:NSOnState];
	
	if([_clearNewsButton isEnabled])
		[_clearNewsButton setState:NSOnState];
	
	if([_getUserInfoButton isEnabled])
		[_getUserInfoButton setState:NSOnState];
	
	if([_broadcastButton isEnabled])
		[_broadcastButton setState:NSOnState];
	
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
		
		// --- can we give privileges that we do not possess?
		if(![[_connection account] elevatePrivileges]) {
			if([[_connection account] getUserInfo])
				[_getUserInfoButton setEnabled:YES];
			else
				[_getUserInfoButton setEnabled:NO];
			
			if([[_connection account] broadcast])
				[_broadcastButton setEnabled:YES];
			else
				[_broadcastButton setEnabled:NO];
			
			if([[_connection account] postNews])
				[_postNewsButton setEnabled:YES];
			else
				[_postNewsButton setEnabled:NO];
			
			if([[_connection account] clearNews])
				[_clearNewsButton setEnabled:YES];
			else
				[_clearNewsButton setEnabled:NO];
			
			if([[_connection account] download])
				[_downloadButton setEnabled:YES];
			else
				[_downloadButton setEnabled:NO];
			
			if([[_connection account] upload])
				[_uploadButton setEnabled:YES];
			else
				[_uploadButton setEnabled:NO];
			
			if([[_connection account] uploadAnywhere])
				[_uploadAnywhereButton setEnabled:YES];
			else
				[_uploadAnywhereButton setEnabled:NO];
			
			if([[_connection account] createFolders])
				[_createFoldersButton setEnabled:YES];
			else
				[_createFoldersButton setEnabled:NO];
			
			if([[_connection account] moveFiles])
				[_moveButton setEnabled:YES];
			else
				[_moveButton setEnabled:NO];
			
			if([[_connection account] deleteFiles])
				[_deleteButton setEnabled:YES];
			else
				[_deleteButton setEnabled:NO];
			
			if([[_connection account] viewDropBoxes])
				[_viewDropBoxButton setEnabled:YES];
			else
				[_viewDropBoxButton setEnabled:NO];
			
			if([[_connection account] createAccounts])
				[_createAccountsButton setEnabled:YES];
			else
				[_createAccountsButton setEnabled:NO];
			
			if([[_connection account] editAccounts])
				[_editAccountsButton setEnabled:YES];
			else
				[_editAccountsButton setEnabled:NO];
			
			if([[_connection account] deleteAccounts])
				[_deleteAccountsButton setEnabled:YES];
			else
				[_deleteAccountsButton setEnabled:NO];
			
			if([[_connection account] elevatePrivileges])
				[_elevatePrivilegesButton setEnabled:YES];
			else
				[_elevatePrivilegesButton setEnabled:NO];
			
			if([[_connection account] kickUsers])
				[_kickUsersButton setEnabled:YES];
			else
				[_kickUsersButton setEnabled:NO];
			
			if([[_connection account] banUsers])
				[_banUsersButton setEnabled:YES];
			else
				[_banUsersButton setEnabled:NO];
			
			if([[_connection account] cannotBeKicked])
				[_cannotBeKickedButton setEnabled:YES];
			else
				[_cannotBeKickedButton setEnabled:NO];
		} else {
			// --- enable buttons
			[_postNewsButton setEnabled:YES];
			[_clearNewsButton setEnabled:YES];
			[_getUserInfoButton setEnabled:YES];
			[_broadcastButton setEnabled:YES];
			
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
		}

		[_selectAllButton setEnabled:YES];
	} else {
		// --- send read group command
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@", WCReadGroupCommand, [[_groupPopUpButton selectedItem] title]]];
		
		// --- disable buttons
		[_postNewsButton setEnabled:NO];
		[_clearNewsButton setEnabled:NO];
		[_getUserInfoButton setEnabled:NO];
		[_broadcastButton setEnabled:NO];
		
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
