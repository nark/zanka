/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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
#import "WCAccountEditor.h"
#import "WCAccounts.h"

@interface WCAccountEditor(Private)

- (id)_initAccountEditorWithConnection:(WCServerConnection *)connection account:(WCAccount *)account;

- (void)_updateType;
- (void)_updateGroup;

- (void)_setForAccount:(WCAccount *)account;

@end


@implementation WCAccountEditor(Private)

- (id)_initAccountEditorWithConnection:(WCServerConnection *)connection account:(WCAccount *)account {
	self = [super initWithWindowNibName:@"AccountEditor"
								   name:NSLS(@"Account Editor", @"Account editor window title")
							 connection:connection];

	[self setReleasedWhenClosed:YES];
	[self window];

	if(account) {
		if([account type] == WCAccountUser) {
			[_typePopUpButton selectItem:_userMenuItem];

			[[self connection] addObserver:self
								  selector:@selector(accountEditorReceivedUser:)
									  name:WCAccountEditorReceivedUser];
			
			[[self connection] sendCommand:WCReadUserCommand withArgument:[account name]];
		} else {
			[_typePopUpButton selectItem:_groupMenuItem];

			[[self connection] addObserver:self
								  selector:@selector(accountEditorReceivedGroup:)
									  name:WCAccountEditorReceivedGroup];
			
			[[self connection] sendCommand:WCReadGroupCommand withArgument:[account name]];
		}

		[_okButton setAction:@selector(edit:)];
		[_okButton setTitle:NSLS(@"Save", @"Account Editor button title")];

		[_typePopUpButton setEnabled:NO];
		[_nameTextField setEnabled:NO];
		[_nameTextField setStringValue:[account name]];
	} else {
		[_okButton setAction:@selector(create:)];
		[_okButton setTitle:NSLS(@"Add", @"Account Editor button title")];

		[_typePopUpButton setEnabled:YES];
		[_nameTextField setEnabled:YES];
	}

	[self _updateType];
	[self _updateGroup];
	
	[self showWindow:self];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_updateType {
	if([_typePopUpButton selectedItem] == _userMenuItem) {
		[_passwordTextField setEnabled:YES];
		[_groupPopUpButton setEnabled:YES];
	}
	else if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[_passwordTextField setEnabled:NO];
		[_groupPopUpButton setEnabled:NO];

		[_groupPopUpButton selectItem:_noneMenuItem];
	}
}



- (void)_updateGroup {
	NSEnumerator	*enumerator;
	NSButton		*button;
	WCAccount		*account;

	account = [[self connection] account];

	if(![[_groupPopUpButton selectedItem] title])
		[_groupPopUpButton selectItem:_noneMenuItem];

	if([_groupPopUpButton selectedItem] == _noneMenuItem) {
		if(_account)
			[self _setForAccount:_account];

		if([account elevatePrivileges]) {
			enumerator = [_buttons objectEnumerator];

			while((button = [enumerator nextObject]))
				[button setEnabled:YES];

			[_downloadSpeedTextField setEnabled:YES];
			[_uploadSpeedTextField setEnabled:YES];
		} else {
			[_getUserInfoButton setEnabled:[account getUserInfo]];
			[_broadcastButton setEnabled:[account broadcast]];
			[_setTopicButton setEnabled:[account setTopic]];
			[_postNewsButton setEnabled:[account postNews]];
			[_clearNewsButton setEnabled:[account clearNews]];

			[_downloadButton setEnabled:[account download]];
			[_uploadButton setEnabled:[account upload]];
			[_uploadAnywhereButton setEnabled:[account uploadAnywhere]];
			[_createFoldersButton setEnabled:[account createFolders]];
			[_moveButton setEnabled:[account alterFiles]];
			[_deleteButton setEnabled:[account deleteFiles]];
			[_viewDropBoxButton setEnabled:[account viewDropBoxes]];

			[_createAccountsButton setEnabled:[account createAccounts]];
			[_editAccountsButton setEnabled:[account editAccounts]];
			[_deleteAccountsButton setEnabled:[account deleteAccounts]];
			[_elevatePrivilegesButton setEnabled:[account elevatePrivileges]];
			[_kickUsersButton setEnabled:[account kickUsers]];
			[_banUsersButton setEnabled:[account banUsers]];
			[_cannotBeKickedButton setEnabled:[account cannotBeKicked]];
		}

		[_selectAllButton setEnabled:YES];
	} else {
		[[self connection] addObserver:self
							  selector:@selector(accountEditorReceivedGroup:)
								  name:WCAccountEditorReceivedGroup];
		
		[[self connection] sendCommand:WCReadGroupCommand
						  withArgument:[[_groupPopUpButton selectedItem] title]];
		
		enumerator = [_buttons objectEnumerator];

		while((button = [enumerator nextObject]))
			[button setEnabled:NO];

		[_downloadSpeedTextField setEnabled:NO];
		[_uploadSpeedTextField setEnabled:NO];

		[_selectAllButton setEnabled:NO];
	}
}



#pragma mark -

- (void)_setForAccount:(WCAccount *)account {
	[_getUserInfoButton setState:[account getUserInfo]];
	[_broadcastButton setState:[account broadcast]];
	[_postNewsButton setState:[account postNews]];
	[_clearNewsButton setState:[account clearNews]];
	[_setTopicButton setState:[account setTopic]];

	[_downloadButton setState:[account download]];
	[_uploadButton setState:[account upload]];
	[_uploadAnywhereButton setState:[account uploadAnywhere]];
	[_createFoldersButton setState:[account createFolders]];
	[_moveButton setState:[account alterFiles]];
	[_deleteButton setState:[account deleteFiles]];
	[_viewDropBoxButton setState:[account viewDropBoxes]];

	[_createAccountsButton setState:[account createAccounts]];
	[_editAccountsButton setState:[account editAccounts]];
	[_deleteAccountsButton setState:[account deleteAccounts]];
	[_elevatePrivilegesButton setState:[account elevatePrivileges]];
	[_kickUsersButton setState:[account kickUsers]];
	[_banUsersButton setState:[account banUsers]];
	[_cannotBeKickedButton setState:[account cannotBeKicked]];

	if([account downloadSpeedLimit] > 0)
		[_downloadSpeedTextField setIntValue:(double) [account downloadSpeedLimit] / 1024.0];
	else
		[_downloadSpeedTextField setStringValue:@""];

	if([account uploadSpeedLimit] > 0)
		[_uploadSpeedTextField setIntValue:(double) [account uploadSpeedLimit] / 1024.0];
	else
		[_uploadSpeedTextField setStringValue:@""];
}

@end


@implementation WCAccountEditor

+ (id)accountEditorWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAccountEditorWithConnection:connection account:NULL] autorelease];
}



+ (id)accountEditorWithConnection:(WCServerConnection *)connection account:(WCAccount *)account {
	return [[[self alloc] _initAccountEditorWithConnection:connection account:account] autorelease];
}



- (void)dealloc {
	[_buttons release];
	[_account release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator	*enumerator;
	NSArray			*groups;
	NSMenuItem		*item;
	WCAccount		*account;

	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
	
	[self setShouldCascadeWindows:YES];
	[self setShouldSaveWindowFrameOriginOnly:YES];
	[self setWindowFrameAutosaveName:@"AccountEditor"];

	[_userMenuItem setImage:[NSImage imageNamed:@"User"]];
	[_groupMenuItem setImage:[NSImage imageNamed:@"Group"]];

	groups = [[[self connection] accounts] groups];
	enumerator = [groups objectEnumerator];

	while((account = [enumerator nextObject])) {
		item = [[NSMenuItem alloc] initWithTitle:[account name] action:NULL keyEquivalent:@""];
		[item setImage:[NSImage imageNamed:@"Group"]];
		[[_groupPopUpButton menu] addItem:item];
		[item release];
	}
	
	_buttons = [[NSArray alloc] initWithObjects:
		_getUserInfoButton,
		_broadcastButton,
		_setTopicButton,
		_postNewsButton,
		_clearNewsButton,
		_downloadButton,
		_uploadButton,
		_uploadAnywhereButton,
		_createFoldersButton,
		_moveButton,
		_deleteButton,
		_viewDropBoxButton,
		_createAccountsButton,
		_editAccountsButton,
		_deleteAccountsButton,
		_elevatePrivilegesButton,
		_kickUsersButton,
		_banUsersButton,
		_cannotBeKickedButton,
		NULL];
	
	[super windowDidLoad];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[super connectionWillTerminate:notification];

	[self close];
}



- (void)accountEditorReceivedUser:(NSNotification *)notification {
	WCAccount		*account;

	account = [WCAccount userAccountWithAccountArguments:
		[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	[_passwordTextField setStringValue:[account password]];

	if([[account group] length] > 0)
		[_groupPopUpButton selectItemWithTitle:[account group]];

	[self _setForAccount:account];
	
	[self _updateGroup];

	[_account release];
	_account = [account retain];
	
	[[self connection] removeObserver:self name:WCAccountEditorReceivedUser];
}



- (void)accountEditorReceivedGroup:(NSNotification *)notification {
	WCAccount		*account;

	account = [WCAccount groupAccountWithAccountArguments:
		[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if([_typePopUpButton selectedItem] == _groupMenuItem)
		[_nameTextField setStringValue:[account name]];

	[self _setForAccount:account];

	if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[_account release];
		_account = [account retain];
	}

	[[self connection] removeObserver:self name:WCAccountEditorReceivedGroup];
}



#pragma mark -

- (IBAction)create:(id)sender {
	NSString		*password, *group;

	if([[_passwordTextField stringValue] isEqualToString:@""])
		password = @"";
	else
		password = [[_passwordTextField stringValue] SHA1];

	if([_groupPopUpButton selectedItem] != _noneMenuItem)
		group = [_groupPopUpButton titleOfSelectedItem];
	else
		group = @"";

	if([_typePopUpButton selectedItem] == _userMenuItem) {
		[[self connection] sendCommand:WCCreateUserCommand
						 withArguments:[NSArray arrayWithObjects:
							 [_nameTextField stringValue],
							 password,
							 group,
							 [_getUserInfoButton stringValue],
							 [_broadcastButton stringValue],
							 [_postNewsButton stringValue],
							 [_clearNewsButton stringValue],
							 [_downloadButton stringValue],
							 [_uploadButton stringValue],
							 [_uploadAnywhereButton stringValue],
							 [_createFoldersButton stringValue],
							 [_moveButton stringValue],
							 [_deleteButton stringValue],
							 [_viewDropBoxButton stringValue],
							 [_createAccountsButton stringValue],
							 [_editAccountsButton stringValue],
							 [_deleteAccountsButton stringValue],
							 [_elevatePrivilegesButton stringValue],
							 [_kickUsersButton stringValue],
							 [_banUsersButton stringValue],
							 [_cannotBeKickedButton stringValue],
							 [NSNumber numberWithUnsignedInteger:[_downloadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_uploadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_account downloadLimit]],
							 [NSNumber numberWithUnsignedInteger:[_account uploadLimit]],
							 [_setTopicButton stringValue],
							 NULL]];
	}
	else if([_typePopUpButton selectedItem] == _groupMenuItem) {
		[[self connection] sendCommand:WCCreateGroupCommand
						 withArguments:[NSArray arrayWithObjects:
							 [_nameTextField stringValue],
							 [_getUserInfoButton stringValue],
							 [_broadcastButton stringValue],
							 [_postNewsButton stringValue],
							 [_clearNewsButton stringValue],
							 [_downloadButton stringValue],
							 [_uploadButton stringValue],
							 [_uploadAnywhereButton stringValue],
							 [_createFoldersButton stringValue],
							 [_moveButton stringValue],
							 [_deleteButton stringValue],
							 [_viewDropBoxButton stringValue],
							 [_createAccountsButton stringValue],
							 [_editAccountsButton stringValue],
							 [_deleteAccountsButton stringValue],
							 [_elevatePrivilegesButton stringValue],
							 [_kickUsersButton stringValue],
							 [_banUsersButton stringValue],
							 [_cannotBeKickedButton stringValue],
							 [NSNumber numberWithUnsignedInteger:[_downloadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_uploadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_account downloadLimit]],
							 [NSNumber numberWithUnsignedInteger:[_account uploadLimit]],
							 [_setTopicButton stringValue],
							 NULL]];
	}

	[[self connection] postNotificationName:WCAccountsShouldReload object:[self connection]];
	
	[self close];
}



- (IBAction)edit:(id)sender {
	NSString		*password, *group;

	if([[_passwordTextField stringValue] isEqualToString:@""]) {
		password = @"";
	} else {
		if([[_account password] isEqualToString:[_passwordTextField stringValue]])
			password = [_account password];
		else
			password = [[_passwordTextField stringValue] SHA1];
	}

	if([_groupPopUpButton selectedItem] != _noneMenuItem)
		group = [_groupPopUpButton titleOfSelectedItem];
	else
		group = @"";

	if([_account type] == WCAccountUser) {
		[[self connection] sendCommand:WCEditUserCommand
						 withArguments:[NSArray arrayWithObjects:
							 [_nameTextField stringValue],
							 password,
							 group,
							 [_getUserInfoButton stringValue],
							 [_broadcastButton stringValue],
							 [_postNewsButton stringValue],
							 [_clearNewsButton stringValue],
							 [_downloadButton stringValue],
							 [_uploadButton stringValue],
							 [_uploadAnywhereButton stringValue],
							 [_createFoldersButton stringValue],
							 [_moveButton stringValue],
							 [_deleteButton stringValue],
							 [_viewDropBoxButton stringValue],
							 [_createAccountsButton stringValue],
							 [_editAccountsButton stringValue],
							 [_deleteAccountsButton stringValue],
							 [_elevatePrivilegesButton stringValue],
							 [_kickUsersButton stringValue],
							 [_banUsersButton stringValue],
							 [_cannotBeKickedButton stringValue],
							 [NSNumber numberWithUnsignedInteger:[_downloadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_uploadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_account downloadLimit]],
							 [NSNumber numberWithUnsignedInteger:[_account uploadLimit]],
							 [_setTopicButton stringValue],
							 NULL]];
	} else {
		[[self connection] sendCommand:WCEditGroupCommand
						 withArguments:[NSArray arrayWithObjects:
							 [_nameTextField stringValue],
							 [_getUserInfoButton stringValue],
							 [_broadcastButton stringValue],
							 [_postNewsButton stringValue],
							 [_clearNewsButton stringValue],
							 [_downloadButton stringValue],
							 [_uploadButton stringValue],
							 [_uploadAnywhereButton stringValue],
							 [_createFoldersButton stringValue],
							 [_moveButton stringValue],
							 [_deleteButton stringValue],
							 [_viewDropBoxButton stringValue],
							 [_createAccountsButton stringValue],
							 [_editAccountsButton stringValue],
							 [_deleteAccountsButton stringValue],
							 [_elevatePrivilegesButton stringValue],
							 [_kickUsersButton stringValue],
							 [_banUsersButton stringValue],
							 [_cannotBeKickedButton stringValue],
							 [NSNumber numberWithUnsignedInteger:[_downloadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_uploadSpeedTextField intValue] * 1024],
							 [NSNumber numberWithUnsignedInteger:[_account downloadLimit]],
							 [NSNumber numberWithUnsignedInteger:[_account uploadLimit]],
							 [_setTopicButton stringValue],
							 NULL]];
	}
	
	[self close];
}



- (IBAction)selectAll:(id)sender {
	NSEnumerator	*enumerator;
	NSButton		*button;
	
	enumerator = [_buttons objectEnumerator];
	
	while((button = [enumerator nextObject])) {
		if([button isEnabled])
			[button setState:NSOnState];
	}
}



- (IBAction)type:(id)sender {
	[self _updateType];
	[self _updateGroup];
}



- (IBAction)group:(id)sender {
	[self _updateGroup];
}

@end
