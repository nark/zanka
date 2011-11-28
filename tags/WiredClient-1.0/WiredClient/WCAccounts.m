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
#import "WCAccountEditor.h"
#import "WCAccounts.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSettings.h"

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
	NSImageCell		*imageCell;

	// --- set up the icon column for images
	imageCell = [[NSImageCell alloc] init];
	[_iconTableColumn setDataCell:imageCell];
	[imageCell release];

	// --- double-click
	[_accountsTableView setDoubleAction:@selector(edit:)];
	
	// --- window position
	[self setWindowFrameAutosaveName:@"Accounts"];
	[self setShouldCascadeWindows:NO];
	
	// --- start off in the table view
	[[self window] makeFirstResponder:_accountsTableView];

	// --- set up window
	[self update];
	[self updateStatus];
	[self updateButtons];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"Accounts", @"Accounts window title"), 0x2014, [_connection name]]];

	// --- show window
	if([[WCSettings objectForKey:WCShowAccounts] boolValue])
		[self showWindow:self];
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
	[_shownAccounts sortUsingSelector:@selector(nameSort:)];
	
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
		name:WCAccountsShouldAddGroup
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCAccountsShouldCompleteGroups
		object:NULL];

	// --- enter the accumulated accounts
	[_shownAccounts removeAllObjects];
	[_shownAccounts addObjectsFromArray:_allAccounts];

	// --- sort the list
	[_shownAccounts sortUsingSelector:@selector(nameSort:)];

	// --- we're done
	[_progressIndicator stopAnimation:self];
	[self updateStatus];
	
	// --- update table
	[_accountsTableView reloadData];
	[_accountsTableView setNeedsDisplay:YES];
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		NSString	*command;
		WCAccount	*account;
		
		// --- get account
		account = (WCAccount *) contextInfo;
		
		switch([account type]) {
			case WCAccountTypeUser:
				command = WCDeleteUserCommand;
				break;
			
			case WCAccountTypeGroup:
			default:
				command = WCDeleteGroupCommand;
				break;
		}
		
		// --- send delete command
		[[_connection client] sendCommand:command withArgument:[account name]];
		
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
			: NSLocalizedString(@"groups", @"Group plural")
		]];

	[_statusTextField setNeedsDisplay:YES];
}



- (void)updateButtons {
	int			row;
	
	// --- get row
	row = [_accountsTableView selectedRow];
	
	if(row < 0) {
		[_editButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
	} else {
		if([[_connection account] editAccounts])
			[_editButton setEnabled:YES];
		else
			[_editButton setEnabled:NO];

		if([[_connection account] deleteAccounts])
			[_deleteButton setEnabled:YES];
		else
			[_deleteButton setEnabled:NO];
	}

	if([[_connection account] createAccounts])
		[_addButton setEnabled:YES];
	else
		[_addButton setEnabled:NO];

	if([[_connection account] editAccounts])
		[_reloadButton setEnabled:YES];
	else
		[_reloadButton setEnabled:NO];
}



#pragma mark -

- (IBAction)add:(id)sender {
	// --- start editor
	[(WCAccountEditor *) [WCAccountEditor alloc] initWithConnection:_connection];
}



- (IBAction)edit:(id)sender {
	WCAccount	*account;
	int			row;
	
	// --- get row number
	row	= [_accountsTableView selectedRow];

	if(row < 0)
		return;

	// --- check if we can edit
	if(![[_connection account] editAccounts]) {
		[[_connection error] setError:WCApplicationErrorCannotEditAccounts];
		[[_connection error] raiseErrorInWindow:[self shownWindow]];
		
		return;
	}
	
	// --- get file
	account = [_shownAccounts objectAtIndex:row];
	
	// --- start editor
	[(WCAccountEditor *) [WCAccountEditor alloc] initWithConnection:_connection edit:account];
}



- (IBAction)delete:(id)sender {
	NSString	*title;
	WCAccount	*account;
	int			row;
	
	// --- get row number
	row	= [_accountsTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	account = [_shownAccounts objectAtIndex:row];
	title = [NSString stringWithFormat:NSLocalizedString(
				@"Are you sure you want to delete \"%@\"?", @"Delete account dialog title (filename)"),
				[account name]];

	NSBeginAlertSheet(title,
					  NSLocalizedString(@"Delete", @"Delete account dialog button title"), @"Cancel",
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd: returnCode: contextInfo:),
					  NULL,
					  (void *) account,
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
	[[_connection client] sendCommand:WCUsersCommand];
	[[_connection client] sendCommand:WCGroupsCommand];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownAccounts count];
}



- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	WCAccount	*account;

	// --- get account
	account	= [_shownAccounts objectAtIndex:row];
	
	// --- populate columns
	if(column == _iconTableColumn) {
		switch([account type]) {
			case WCAccountTypeUser:
				return _userImage;
				break;
			
			case WCAccountTypeGroup:
				return _groupImage;
				break;
		}
		
		return NULL;
	}
	else if(column == _nameTableColumn) {
		return [account name];
	}
	
	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}

@end
