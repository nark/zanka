/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCAccounts.h"
#import "WCAccountsController.h"
#import "WCConfig.h"
#import "WCConfigController.h"
#import "WCDashboardController.h"
#import "WCSettings.h"

static WCAccountsController			*sharedAccountsController;


@interface WCAccountsController(Private)

- (WCAccount *)_selectedAccount;

- (void)_selectAccount:(WCAccount *)account;
- (void)_unselectAccount:(WCAccount *)account;
- (void)_validateAccount:(WCAccount *)account;

- (void)_readUsersFromFile:(NSString *)path;
- (void)_readGroupsFromFile:(NSString *)path;
- (BOOL)_writeUsersToFile:(NSString *)path;
- (BOOL)_writeGroupsToFile:(NSString *)path;

@end


@implementation WCAccountsController(Private)

- (WCAccount *)_selectedAccount {
	NSInteger		row;
	
	row = [_tableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_accounts objectAtIndex:row];
}



#pragma mark -

- (void)_selectAccount:(WCAccount *)account {
	NSEnumerator	*enumerator;
	WCAccount		*group;
	
	[_groupPopUpButton removeAllItems];
	[_groupPopUpButton addItemWithTitle:WCLS(@"none", "Group menu item")];
	enumerator = [[_groups accounts] objectEnumerator];
	
	while((group = [enumerator nextObject]))
		[_groupPopUpButton addItemWithTitle:[group name]];
	
	[self _validateAccount:account];
	
	if(account) {
		[_typePopUpButton selectItemAtIndex:
			[_typePopUpButton indexOfItemWithTag:[account type]]];
		[_nameTextField setStringValue:[account name]];
		[_passwordTextField setStringValue:[account password]];
		
		if([[account group] length] == 0) {
			[_groupPopUpButton selectItemAtIndex:0];
		} else {
			[_groupPopUpButton selectItemWithTitle:[account group]];
			account = [_groups accountWithName:[account group]];
		}
		
		[_getUserInfoButton setState:[account getUserInfo]];
		[_broadcastButton setState:[account broadcast]];
		[_postNewsButton setState:[account postNews]];
		[_clearNewsButton setState:[account clearNews]];
		[_downloadButton setState:[account download]];
		[_uploadButton setState:[account upload]];
		[_uploadAnywhereButton setState:[account uploadAnywhere]];
		[_createFoldersButton setState:[account createFolders]];
		[_moveFilesButton setState:[account moveFiles]];
		[_deleteFilesButton setState:[account deleteFiles]];
		[_viewDropBoxesButton setState:[account viewDropBoxes]];
		[_createAccountsButton setState:[account createAccounts]];
		[_editAccountsButton setState:[account editAccounts]];
		[_deleteAccountsButton setState:[account deleteAccounts]];
		[_elevatePrivilegesButton setState:[account elevatePrivileges]];
		[_kickUsersButton setState:[account kickUsers]];
		[_banUsersButton setState:[account banUsers]];
		[_cannotBeKickedButton setState:[account cannotBeKicked]];
		[_setTopicButton setState:[account setTopic]];
		
/*		if([account downloads] > 0)
			[_downloadsTextField setIntValue:[account downloads]];
		else
			[_downloadsTextField setStringValue:@""];*/
		
		if([account downloadSpeed] > 0)
			[_downloadSpeedTextField setIntValue:[account downloadSpeed] / (float) 1024.0f];
		else
			[_downloadSpeedTextField setStringValue:@""];
		
/*		if([account uploads] > 0)
			[_uploadsTextField setIntValue:[account uploads]];
		else
			[_uploadsTextField setStringValue:@""];*/
		
		if([account uploadSpeed] > 0)
			[_uploadSpeedTextField setIntValue:[account uploadSpeed] / (float) 1024.0f];
		else
			[_uploadSpeedTextField setStringValue:@""];
	}
	
	_selected = YES;
}



- (void)_unselectAccount:(WCAccount *)account {
	if(!_selected)
		return;
	
	[account setName:[_nameTextField stringValue]];
	[account setPassword:[_passwordTextField stringValue]];
	
	if([_groupPopUpButton indexOfSelectedItem] == 0)
		[account setGroup:@""];
	else
		[account setGroup:[_groupPopUpButton titleOfSelectedItem]];
	
	[account setGetUserInfo:[_getUserInfoButton state]];
	[account setBroadcast:[_broadcastButton state]];
	[account setPostNews:[_postNewsButton state]];
	[account setClearNews:[_clearNewsButton state]];
	[account setDownload:[_downloadButton state]];
	[account setUpload:[_uploadButton state]];
	[account setUploadAnywhere:[_uploadAnywhereButton state]];
	[account setCreateFolders:[_createFoldersButton state]];
	[account setMoveFiles:[_moveFilesButton state]];
	[account setDeleteFiles:[_deleteFilesButton state]];
	[account setViewDropBoxes:[_viewDropBoxesButton state]];
	[account setCreateAccounts:[_createAccountsButton state]];
	[account setEditAccounts:[_editAccountsButton state]];
	[account setDeleteAccounts:[_deleteAccountsButton state]];
	[account setElevatePrivileges:[_elevatePrivilegesButton state]];
	[account setKickUsers:[_kickUsersButton state]];
	[account setBanUsers:[_banUsersButton state]];
	[account setCannotBeKicked:[_cannotBeKickedButton state]];
	[account setSetTopic:[_setTopicButton state]];
	
//	[account setDownloads:[_downloadsTextField intValue]];
	[account setDownloadSpeed:[_downloadSpeedTextField intValue] * 1024];
//	[account setUploads:[_uploadsTextField intValue]];
	[account setUploadSpeed:[_uploadSpeedTextField intValue] * 1024];
	
	_selected = NO;
}



- (void)_validateAccount:(WCAccount *)account {
	BOOL	enabled;
	
	enabled = [[WCDashboardController dashboardController] isAuthorized] && (account != NULL);
	[_addButton setEnabled:enabled];
	[_deleteButton setEnabled:enabled];
	[_typePopUpButton setEnabled:enabled];
	[_nameTextField setEnabled:enabled];
	
	enabled = ([[WCDashboardController dashboardController] isAuthorized] && [account type] == WCAccountUser);
	[_passwordTextField setEnabled:enabled];
	[_groupPopUpButton setEnabled:enabled];
	
	enabled = ([[WCDashboardController dashboardController] isAuthorized] && [[account group] length] == 0);
	[_getUserInfoButton setEnabled:enabled];
	[_broadcastButton setEnabled:enabled];
	[_postNewsButton setEnabled:enabled];
	[_clearNewsButton setEnabled:enabled];
	[_downloadButton setEnabled:enabled];
	[_uploadButton setEnabled:enabled];
	[_uploadAnywhereButton setEnabled:enabled];
	[_createFoldersButton setEnabled:enabled];
	[_moveFilesButton setEnabled:enabled];
	[_deleteFilesButton setEnabled:enabled];
	[_viewDropBoxesButton setEnabled:enabled];
	[_createAccountsButton setEnabled:enabled];
	[_editAccountsButton setEnabled:enabled];
	[_deleteAccountsButton setEnabled:enabled];
	[_elevatePrivilegesButton setEnabled:enabled];
	[_kickUsersButton setEnabled:enabled];
	[_banUsersButton setEnabled:enabled];
	[_cannotBeKickedButton setEnabled:enabled];
	[_setTopicButton setEnabled:enabled];
//	[_downloadsTextField setEnabled:enabled];
	[_downloadSpeedTextField setEnabled:enabled];
//	[_uploadsTextField setEnabled:enabled];
	[_uploadSpeedTextField setEnabled:enabled];
}



#pragma mark -

- (void)_readUsersFromFile:(NSString *)path {
	[_accounts removeObjectsInArray:[_users accounts]];
	[_users release];
	_users = [[WCAccounts alloc] initWithContentsOfFile:path type:WCAccountUser];

	[_accounts addObjectsFromArray:[_users accounts]];
	[_accounts sortUsingSelector:@selector(compareName:)];

	[_tableView reloadData];
	
	[self _selectAccount:[self _selectedAccount]];
}



- (void)_readGroupsFromFile:(NSString *)path {
	[_accounts removeObjectsInArray:[_groups accounts]];
	[_groups release];
	_groups = [[WCAccounts alloc] initWithContentsOfFile:path type:WCAccountGroup];
	
	[_accounts addObjectsFromArray:[_groups accounts]];
	[_accounts sortUsingSelector:@selector(compareName:)];

	[_tableView reloadData];
	
	[self _selectAccount:[self _selectedAccount]];
}



- (BOOL)_writeUsersToFile:(NSString *)path {
	NSString				*temp;
	WCDashboardController	*controller;
	WCConfig				*config;
	
	[self _unselectAccount:[self _selectedAccount]];
	
	controller	= [WCDashboardController dashboardController];
	config		= [[WCConfigController configController] config];
	temp		= [NSFileManager temporaryPathWithPrefix:@"users" suffix:@"conf"];
	
	if([_users writeToFile:temp]) {
		if([controller movePath:temp toPath:path]) {
			if([controller changeOwnerOfPath:path
									  toUser:[config stringForKey:@"user"]
									   group:[config stringForKey:@"group"]]) {
				_touched = NO;
				
				return YES;
			}
		}
		
	}
	
	return NO;
}



- (BOOL)_writeGroupsToFile:(NSString *)path {
	NSString				*temp;
	WCDashboardController	*controller;
	WCConfig				*config;
	
	[self _unselectAccount:[self _selectedAccount]];

	controller	= [WCDashboardController dashboardController];
	config		= [[WCConfigController configController] config];
	temp		= [NSFileManager temporaryPathWithPrefix:@"groups" suffix:@"conf"];
	
	if([_groups writeToFile:temp]) {
		if([controller movePath:temp toPath:path]) {
			if([controller changeOwnerOfPath:path
									  toUser:[config stringForKey:@"user"]
									   group:[config stringForKey:@"group"]]) {
				_touched = NO;
				
				return YES;
			}
		}
		
	}
	
	return NO;
}

@end


@implementation WCAccountsController

+ (WCAccountsController *)accountsController {
	return sharedAccountsController;
}



- (id)init {
	self = [super init];
	
	sharedAccountsController = self;
	
	return self;
}



- (void)awakeFromNib {
	WIIconCell		*cell;
	
	_accounts = [[NSMutableArray alloc] init];

	cell = [[WIIconCell alloc] init];
	[[_tableView tableColumnWithIdentifier:@"Name"] setDataCell:cell];  
	[cell release];
	
	_userImage = [[NSImage alloc] initWithContentsOfFile:
		[[self bundle] pathForResource:@"User" ofType:@"tiff"]];
	_groupImage = [[NSImage alloc] initWithContentsOfFile:
		[[self bundle] pathForResource:@"Group" ofType:@"tiff"]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(authorizationStatusDidChange:)
			   name:WCAuthorizationStatusDidChange
			 object:NULL];
}



- (void)awakeFromController {
	[self _readUsersFromFile:WCExpandWiredPath(@"users")];
	[self _readGroupsFromFile:WCExpandWiredPath(@"groups")];
	
	[self _selectAccount:[self _selectedAccount]];
}



- (BOOL)saveFromController {
	if(_touched) {
		if([self _writeUsersToFile:WCExpandWiredPath(@"users")]) {
			if([self _writeGroupsToFile:WCExpandWiredPath(@"groups")]) {
				[[NSNotificationCenter defaultCenter] postNotificationName:WCAccountsDidChange];
				
				return YES;
			}
		}
		
		return NO;
	}
	
	return YES;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_accounts release];
	[_users release];
	[_groups release];
	
	[_userImage release];
	[_groupImage release];
	
	[super dealloc];
}



#pragma mark -

- (void)authorizationStatusDidChange:(NSNotification *)notification {
	[self _validateAccount:[self _selectedAccount]];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	WCAccount	*account;
	
	_touched = YES;
	
	if([notification object] == _nameTextField) {
		account = [self _selectedAccount];
		[account setName:[_nameTextField stringValue]];
		[_tableView reloadData];
	}
}



#pragma mark -

- (IBAction)touch:(id)sender {
	_touched = YES;
}



- (IBAction)add:(id)sender {
	WCAccount   *account;
	NSString	*untitled, *name;
	int			i = 2;
	
	untitled = WCLS(@"Untitled", @"New user name");
	name = untitled;
	
	while(([_users accountWithName:name]))
		name = [NSSWF:@"%@ %u", untitled, i++];
	
	account = [[WCAccount alloc] initWithName:name type:WCAccountUser];
	[_accounts addObject:account];
	[_users addAccount:account];
	[account release];
	
	_touched = YES;
	
	[_tableView reloadData];
	[_tableView selectRow:[_accounts count] - 1 byExtendingSelection:NO];
}



- (IBAction)delete:(id)sender {
	NSString		*name;

	name = [[self _selectedAccount] name];

	NSBeginAlertSheet([NSSWF:WCLS(@"Are you sure you want to delete \"%@\"?", @"Delete account dialog title (account)"), name],
					  WCLS(@"Delete", @"Delete account dialog button title"),
					  WCLS(@"Cancel", @"Delete account dialog button title"),
					  NULL,
					  [_deleteButton window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  WCLS(@"This cannot be undone.", @"Delete account dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WCAccount		*account, *user;
	NSInteger		row;
	
	if(returnCode == NSAlertDefaultReturn) {
		account = [self _selectedAccount];
		
		if([account type] == WCAccountGroup) {
			enumerator = [[_users accounts] objectEnumerator];
			
			while((user = [enumerator nextObject])) {
				if([[user group] isEqualToString:[account name]])
					[user setGroup:@""];
			}
		}
		
		[account retain];
		[_accounts removeObject:account];
		[_users deleteAccount:account];
		[_groups deleteAccount:account];
		[account release];
		
		_touched = YES;
		
		[_tableView reloadData];
		
		row = [_tableView selectedRow];
		row = row == 0 ? 0 : row - 1;
		
		if(row != [_tableView selectedRow])
			[_tableView selectRow:row byExtendingSelection:NO];
		else
			[self _selectAccount:[self _selectedAccount]];
	}
}



- (IBAction)selectType:(id)sender {
	WCAccount   *account;
	
	account = [self _selectedAccount];
	[account setType:[[_typePopUpButton selectedItem] tag]];
	
	switch([account type]) {
		case WCAccountUser:
			[account retain];
			[_groups deleteAccount:account];
			[_users addAccount:account];
			[account release];
			break;
			
		case WCAccountGroup:
			[account retain];
			[_users deleteAccount:account];
			[_groups addAccount:account];
			[account release];
			break;
	}
	
	_touched = YES;
	
	[_tableView reloadData];
	
	[self _selectAccount:account];
}



- (IBAction)selectGroup:(id)sender {
	WCAccount   *account;
	
	account = [self _selectedAccount];
	
	if([_groupPopUpButton indexOfSelectedItem] == 0)
		[account setGroup:@""];
	else
		[account setGroup:[_groupPopUpButton titleOfSelectedItem]];
	
	_touched = YES;
	
	[self _selectAccount:account];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_accounts count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	return [[_accounts objectAtIndex:row] name];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	[cell setImage:([(WCAccount *) [_accounts objectAtIndex:row] type] == WCAccountUser) ? _userImage : _groupImage];
}


- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	[self _unselectAccount:[self _selectedAccount]];
	
	return YES;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _selectAccount:[self _selectedAccount]];
}

@end
