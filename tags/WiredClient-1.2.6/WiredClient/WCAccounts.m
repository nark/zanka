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

#import "NSWindowControllerAdditions.h"
#import "WCAccount.h"
#import "WCAccountEditor.h"
#import "WCAccounts.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSettings.h"
#import "WCTableView.h"

@implementation WCAccounts

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Accounts"];
	
	// --- get parameters
	_connection		= [connection retain];
	
	// --- arrays of the accounts
	_allAccounts	= [[NSMutableArray alloc] init];
	_shownAccounts	= [[NSMutableArray alloc] init];
	
	// --- load images
	_userImage		= [[NSImage imageNamed:@"User"] retain];
	_groupImage		= [[NSImage imageNamed:@"Group"] retain];
	
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
		   selector:@selector(connectionPrivilegesDidChange:)
			   name:WCConnectionPrivilegesDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountsShouldReload:)
			   name:WCAccountsShouldReload
			 object:NULL];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_userImage release];
	[_groupImage release];
	
	[_allAccounts release];
	[_shownAccounts release];
	[_connection release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WCIconCell		*iconCell;

	// --- set up our custom cell type
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[iconCell setControlSize:NSSmallControlSize];
	[[_accountsTableView tableColumnWithIdentifier:@"Name"] setDataCell:iconCell];
	[iconCell release];

	// --- double-click
	[_accountsTableView setDoubleAction:@selector(edit:)];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	
	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Accounts"];
	
	// --- table view position
	[_accountsTableView setAutosaveName:@"Accounts"];
	[_accountsTableView setAutosaveTableColumns:YES];
	
	// --- start off in the table view
	[[self window] makeFirstResponder:_accountsTableView];

	// --- set up window
	[self update];
	[self updateStatus];
	[self updateButtons];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
		
	// --- show window
	if([WCSettings boolForKey:WCShowAccounts])
		[self showWindow:self];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Accounts", @"Accounts window title")]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				forKey:WCShowAccounts];

	[_accountsTableView setDataSource:NULL];

	[self close];
	[self release];
}



- (void)connectionPrivilegesDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- update buttons
	[self updateButtons];
	
	// --- load accounts
	if([[_connection account] editAccounts])
		[self reload:self];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}



- (void)accountsShouldReload:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	[self reload:self];
}



- (void)accountsShouldAddUser:(NSNotification *)notification {
	NSString		*argument;
	WCAccount		*account;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- allocate an account and set its name
	account = [[WCAccount alloc] initWithType:WCAccountTypeUser];
	[account setName:argument];
	
	// --- add it to our array of accounts
	[_allAccounts addObject:account];
	_users++;

	[account release];

	// --- update table
	[_accountsTableView reloadData];
	[_accountsTableView setNeedsDisplay:YES];
}



- (void)accountsShouldCompleteUsers:(NSNotification *)notification {
	NSString			*argument;
	WCConnection		*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- stop receiving these notifications
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountsShouldAddUser
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountsShouldCompleteUsers
		object:NULL];

	// --- enter the accumulated accounts
	[_shownAccounts removeAllObjects];
	[_shownAccounts addObjectsFromArray:_allAccounts];

	// --- sort the list
	[_shownAccounts sortUsingSelector:@selector(compareName:)];
	
	// --- update table
	[_accountsTableView reloadData];
	[_accountsTableView setNeedsDisplay:YES];
}



- (void)accountsShouldAddGroup:(NSNotification *)notification {
	NSString		*argument;
	WCAccount		*account;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- allocate an account and set its name
	account = [[WCAccount alloc] initWithType:WCAccountTypeGroup];
	[account setName:argument];
	
	// --- add it to our array of accounts
	[_allAccounts addObject:account];
	_groups++;

	[account release];

	// --- update table
	[_accountsTableView reloadData];
	[_accountsTableView setNeedsDisplay:YES];
}



- (void)accountsShouldCompleteGroups:(NSNotification *)notification {
	NSString			*argument, *identifier;
	WCConnection		*connection;
	
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

	// --- enter the accumulated accounts
	[_shownAccounts removeAllObjects];
	[_shownAccounts addObjectsFromArray:_allAccounts];

	// --- get identifier
	identifier = [[_accountsTableView highlightedTableColumn] identifier];

	// --- sort the list
	if([identifier isEqualToString:@"Name"])
		[_shownAccounts sortUsingSelector:@selector(compareName:)];
	else if([identifier isEqualToString:@"Type"])
		[_shownAccounts sortUsingSelector:@selector(compareType:)];
	
	// --- we're done
	[_progressIndicator stopAnimation:self];
	[self updateStatus];
	
	// --- update table
	[_accountsTableView reloadData];
	[_accountsTableView setNeedsDisplay:YES];
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	NSString		*command;
	WCAccount		*account;
	
	if(returnCode == NSAlertDefaultReturn) {
		// --- get accounts
		enumerator = [[self selectedAccounts] objectEnumerator];
		
		while((account = [enumerator nextObject])) {
			// --- set command
			command = [account type] == WCAccountTypeUser ? WCDeleteUserCommand : WCDeleteGroupCommand;

			// --- send delete command
			[_connection sendCommand:command withArgument:[account name] withSender:self];
		}
		
		// --- reload listing
		[self reload:self];
	}
}



#pragma mark -

- (void)update {
	;
}



- (void)updateStatus {
	// --- set the status field
	[_statusTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%d %@, %d %@", "Accounts status (users, 'user(s)', groups, 'group(s)')"),
		_users,
		_users == 1
			? NSLocalizedString(@"user", @"User singular")
			: NSLocalizedString(@"users", @"User plural"),
		_groups,
		_groups == 1
			? NSLocalizedString(@"group", @"Group singular")
			: NSLocalizedString(@"groups", @"Group plural") ]];
}



- (void)updateButtons {
	int			row;
	
	// --- get row
	row = [_accountsTableView selectedRow];
	
	if(row < 0) {
		[_editButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
	} else {
		[_editButton setEnabled:[[_connection account] editAccounts]];
		[_deleteButton setEnabled:[[_connection account] deleteAccounts]];
	}

	[_addButton setEnabled:[[_connection account] createAccounts]];
	[_reloadButton setEnabled:[[_connection account] editAccounts]];
}



- (WCAccount *)selectedAccount {
	int		i, row;
	
	// --- get row
	row = [_accountsTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	// --- get account
	i = [_accountsTableView sortDescending]
		? [_shownAccounts count] - (unsigned int) row - 1
		: (unsigned int) row;
	
	return [_shownAccounts objectAtIndex:i];
}



- (NSArray *)selectedAccounts {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSNumber			*row;
	int					i;
	
	// --- get rows
	array = [NSMutableArray array];
	enumerator = [_accountsTableView selectedRowEnumerator];
	
	while((row = [enumerator nextObject])) {
		// --- get account
		i = [_accountsTableView sortDescending]
			? [_shownAccounts count] - [row unsignedIntValue] - 1
			: [row unsignedIntValue];
		
		[array addObject:[_shownAccounts objectAtIndex:i]];
	}
	
	return array;
}



#pragma mark -

- (IBAction)add:(id)sender {
	// --- start editor
	[(WCAccountEditor *) [WCAccountEditor alloc] initWithConnection:_connection];
}



- (IBAction)edit:(id)sender {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	
	// --- get rows
	enumerator = [[self selectedAccounts] objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		// --- start editor
		[(WCAccountEditor *) [WCAccountEditor alloc] initWithConnection:_connection edit:account];
	}
}



- (IBAction)delete:(id)sender {
	NSString	*title;
	int			count;
	
	// --- get rows
	count = [_accountsTableView numberOfSelectedRows];
	
	if(count == 0)
		return;

	// --- set title
	if(count == 1) {
		title = [NSString stringWithFormat:
			NSLocalizedString(@"Are you sure you want to delete \"%@\"?", @"Delete account dialog title (filename)"),
			[[self selectedAccount] name]];
	} else {
		title = [NSString stringWithFormat:
			NSLocalizedString(@"Are you sure you want to delete %u items?", @"Delete account dialog title (count)"),
			count];
	}
	
	// --- run dialog
	NSBeginAlertSheet(title,
					  NSLocalizedString(@"Delete", @"Delete account dialog button title"),
					  NSLocalizedString(@"Cancel", @"Delete account dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLocalizedString(@"This cannot be undone.", @"Delete account dialog description"));
}



- (IBAction)reload:(id)sender {
	// --- we are now loading
	if(sender != self)
		[_progressIndicator startAnimation:self];
	
	// --- remove files
	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];

	// --- reset
	_users = _groups = 0;
	[_statusTextField setStringValue:@""];
	[_accountsTableView reloadData];
	
	// --- re-subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(accountsShouldAddUser:)
		name:WCAccountsShouldAddUser
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(accountsShouldCompleteUsers:)
		name:WCAccountsShouldCompleteUsers
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

	// --- send the list commands
	[_connection sendCommand:WCUsersCommand withSender:self];
	[_connection sendCommand:WCGroupsCommand withSender:self];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownAccounts count];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	NSString	*identifier;
	
	// --- get identifier
	identifier = [tableColumn identifier];
	
	// --- re-sort
	if([identifier isEqualToString:@"Name"])
		[_shownAccounts sortUsingSelector:@selector(compareName:)];
	else if([identifier isEqualToString:@"Type"])
		[_shownAccounts sortUsingSelector:@selector(compareType:)];
	
	// --- select new column header
	[_accountsTableView setHighlightedTableColumn:tableColumn];
	[_accountsTableView reloadData];
}



- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	WCAccount	*account;
	NSString	*identifier;
	int			i;

	// --- get account
	i = [_accountsTableView sortDescending]
		? [_shownAccounts count] - (unsigned int) row - 1
		: (unsigned int) row;
	account = [_shownAccounts objectAtIndex:i];
	identifier = [tableColumn identifier];
	
	// --- populate columns
	if([identifier isEqualToString:@"Name"]) {
		NSImage		*icon = NULL;
		
		switch([account type]) {
			case WCAccountTypeUser:
				icon = _userImage;
				break;
				
			case WCAccountTypeGroup:
				icon = _groupImage;
				break;
		}

		return [NSDictionary dictionaryWithObjectsAndKeys:
			[account name],		WCIconCellNameKey,
			icon,				WCIconCellImageKey,
			NULL];
	}
	else if([identifier isEqualToString:@"Type"]) {
		switch([account type]) {
			case WCAccountTypeUser:
				return NSLocalizedString(@"User", @"Account type");
				break;
				
			case WCAccountTypeGroup:
				return NSLocalizedString(@"Group", @"Account type");
				break;
		}
	}
	
	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}

@end
