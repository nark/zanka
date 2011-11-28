/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

@interface WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_updateStatus;
- (void)_validate;

- (WCAccount *)_accountAtIndex:(NSUInteger)index;
- (WCAccount *)_selectedAccount;
- (NSArray *)_selectedAccounts;
- (void)_sortAccounts;
- (void)_reloadAccounts;

@end


@implementation WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Accounts"
								   name:NSLS(@"Accounts", @"Accounts window title")
							 connection:connection];

	_allAccounts	= [[NSMutableArray alloc] init];
	_shownAccounts	= [[NSMutableArray alloc] init];
	_userImage		= [[NSImage imageNamed:@"User"] retain];
	_groupImage		= [[NSImage imageNamed:@"Group"] retain];

	[self window];

	[[self connection] addObserver:self
						  selector:@selector(accountsShouldReload:)
							  name:WCAccountsShouldReload];

	[[self connection] addObserver:self
						  selector:@selector(accountsReceivedUser:)
							  name:WCAccountsReceivedUser];

	[[self connection] addObserver:self
						  selector:@selector(accountsCompletedUsers:)
							  name:WCAccountsCompletedUsers];

	[[self connection] addObserver:self
						  selector:@selector(accountsReceivedGroup:)
							  name:WCAccountsReceivedGroup];

	[[self connection] addObserver:self
						  selector:@selector(accountsCompletedGroups:)
							  name:WCAccountsCompletedGroups];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_update {
}



- (void)_updateStatus {
	[_statusTextField setStringValue:[NSSWF:
		NSLS(@"%lu %@, %lu %@", "Accounts status (users, 'user(s)', groups, 'group(s)')"),
		_users,
		_users == 1
			? NSLS(@"user", @"User singular")
			: NSLS(@"users", @"User plural"),
		_groups,
		_groups == 1
			? NSLS(@"group", @"Group singular")
			: NSLS(@"groups", @"Group plural")]];
}



- (void)_validate {
	WCAccount	*account;
	NSInteger	row;
	BOOL		connected;

	account = [[self connection] account];
	connected = [[self connection] isConnected];
	row = [_accountsTableView selectedRow];

	if(row < 0) {
		[_editButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
	} else {
		[_editButton setEnabled:([account editAccounts] && connected)];
		[_deleteButton setEnabled:([account deleteAccounts] && connected)];
	}

	[_addButton setEnabled:([account createAccounts] && connected)];
	[_reloadButton setEnabled:([account editAccounts] && connected)];
}



#pragma mark -

- (WCAccount *)_accountAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_accountsTableView sortOrder] == WISortDescending)
		? [_shownAccounts count] - index - 1
		: index;
	
	return [_shownAccounts objectAtIndex:i];
}



- (WCAccount *)_selectedAccount {
	NSInteger		row;

	row = [_accountsTableView selectedRow];

	if(row < 0)
		return NULL;

	return [self _accountAtIndex:row];
}



- (NSArray *)_selectedAccounts {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;

	array = [NSMutableArray array];
	indexes = [_accountsTableView selectedRowIndexes];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		[array addObject:[self _accountAtIndex:index]];
		
		index = [indexes indexGreaterThanIndex:index];
	}

	return array;
}



- (void)_sortAccounts {
	NSTableColumn   *tableColumn;

	tableColumn = [_accountsTableView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		[_shownAccounts sortUsingSelector:@selector(compareName:)];
	else if(tableColumn == _typeTableColumn)
		[_shownAccounts sortUsingSelector:@selector(compareType:)];
}



- (void)_reloadAccounts {
	[_progressIndicator startAnimation:self];

	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];

	_users = _groups = 0;
	[_statusTextField setStringValue:@""];
	[_accountsTableView reloadData];

	[[self connection] sendCommand:WCUsersCommand];
	[[self connection] sendCommand:WCGroupsCommand];
}

@end


@implementation WCAccounts

+ (id)accountsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAccountsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_userImage release];
	[_groupImage release];

	[_allAccounts release];
	[_shownAccounts release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WIIconCell		*iconCell;

	iconCell = [[WIIconCell alloc] init];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	[_accountsTableView setTarget:self];
	[_accountsTableView setDoubleAction:@selector(edit:)];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	[_accountsTableView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[[self window] makeFirstResponder:_accountsTableView];

	[self _update];
	[self _updateStatus];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCAccountsWindow"] restoreSize:YES visibility:![self isHidden]];
	[_accountsTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCAccountsTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCAccountsWindow"];
	[windowTemplate setObject:[_accountsTableView propertiesDictionary] forKey:@"WCAccountsTableView"];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[super connectionWillTerminate:notification];

	[self close];
	[self autorelease];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];
	
	_users = _groups = 0;
	
	_received = NO;
	
	[self _validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _validate];

	if(!_received) {
		if([[[self connection] account] editAccounts])
			[self _reloadAccounts];

		_received = YES;
	}
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)accountsShouldReload:(NSNotification *)notification {
	[self _reloadAccounts];
}



- (void)accountsReceivedUser:(NSNotification *)notification {
	[_allAccounts addObject:[WCAccount userAccountWithAccountsArguments:
		[[notification userInfo] objectForKey:WCArgumentsKey]]];

	_users++;
}



- (void)accountsCompletedUsers:(NSNotification *)notification {
}



- (void)accountsReceivedGroup:(NSNotification *)notification {
	[_allAccounts addObject:[WCAccount groupAccountWithAccountsArguments:
		[[notification userInfo] objectForKey:WCArgumentsKey]]];

	_groups++;
}



- (void)accountsCompletedGroups:(NSNotification *)notification {
	[_shownAccounts setArray:_allAccounts];

	[_progressIndicator stopAnimation:self];
	[self _sortAccounts];
	[self _updateStatus];
	[_accountsTableView reloadData];
}



#pragma mark -

- (NSArray *)accounts {
	return _shownAccounts;
}



- (NSArray *)users {
	NSEnumerator	*enumerator;
	NSMutableArray	*accounts;
	WCAccount		*account;

	accounts = [NSMutableArray array];
	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account type] == WCAccountUser)
			[accounts addObject:account];
	}

	return accounts;
}



- (NSArray *)groups {
	NSEnumerator	*enumerator;
	NSMutableArray	*accounts;
	WCAccount		*account;

	accounts = [NSMutableArray array];
	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account type] == WCAccountGroup)
			[accounts addObject:account];
	}

	return accounts;
}



- (WCAccount *)userWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCAccount		*account;

	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account type] == WCAccountUser && [[account name] isEqualToString:name])
			return account;
	}

	return NULL;
}



- (WCAccount *)groupWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCAccount		*account;

	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account type] == WCAccountGroup && [[account name] isEqualToString:name])
			return account;
	}

	return NULL;
}



#pragma mark -

- (IBAction)add:(id)sender {
	[WCAccountEditor accountEditorWithConnection:[self connection]];
}



- (IBAction)edit:(id)sender {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	
	if(![_editButton isEnabled])
		return;

	enumerator = [[self _selectedAccounts] objectEnumerator];

	while((account = [enumerator nextObject]))
		[WCAccountEditor accountEditorWithConnection:[self connection] account:account];
}



- (IBAction)delete:(id)sender {
	NSString	*title;

	if([_accountsTableView numberOfSelectedRows] == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete account dialog title (filename)"),
			[[self _selectedAccount] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete account dialog title (count)"),
			[_accountsTableView numberOfSelectedRows]];
	}

	NSBeginAlertSheet(title,
					  NSLS(@"Delete", @"Delete account dialog button title"),
					  NSLS(@"Cancel", @"Delete account dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete account dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	NSString		*command;
	WCAccount		*account;

	if(returnCode == NSAlertDefaultReturn) {
		enumerator = [[self _selectedAccounts] objectEnumerator];

		while((account = [enumerator nextObject])) {
			command = [account type] == WCAccountUser ? WCDeleteUserCommand : WCDeleteGroupCommand;
		
			[[self connection] sendCommand:command withArgument:[account name]];
		}

		[self _reloadAccounts];
	}
}



- (IBAction)reload:(id)sender {
	[self _reloadAccounts];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownAccounts count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCAccount	*account;

	account = [self _accountAtIndex:row];

	if(tableColumn == _nameTableColumn) {
		return [account name];
	}
	else if(tableColumn == _typeTableColumn) {
		switch([account type]) {
			case WCAccountUser:
				return NSLS(@"User", @"Account type");
				break;

			case WCAccountGroup:
				return NSLS(@"Group", @"Account type");
				break;
		}
	}

	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if(tableColumn == _nameTableColumn) {
		if([[self _accountAtIndex:row] type] == WCAccountUser)
			[cell setImage:_userImage];
		else
			[cell setImage:_groupImage];
	}
}


- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self _accountAtIndex:row] name];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_accountsTableView setHighlightedTableColumn:tableColumn];
	[self _sortAccounts];
	[_accountsTableView reloadData];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
}

@end
