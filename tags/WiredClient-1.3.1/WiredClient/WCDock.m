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

#import "WCDock.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCSettings.h"

@interface WCDock(Private)

- (void)_validate;
- (void)_update;
- (void)_updateStatus;

- (WCServerConnection *)_selectedConnection;
- (WCServerConnection *)_connectionAtIndex:(unsigned int)index;

- (void)_openConnection:(WCServerConnection *)connection;

@end


@implementation WCDock(Private)

- (void)_validate {
	int		row;
	
	row = [_dockTableView selectedRow];

	[_openButton setEnabled:(row >= 0)];
	[_hideButton setEnabled:(row >= 0)];
	[_hideButton setTitle:[[self _selectedConnection] isHidden]
		? NSLS(@"Show", "Show/hide button title")
		: NSLS(@"Hide", "Show/hide button title")];
}



- (void)_update {
	if([WCSettings boolForKey:WCConfirmDisconnect]) {
		[_disconnectMenuItem setTitle:[NSSWF:
			@"%@%C", NSLS(@"Disconnect", @"Disconnect menu item"), 0x2026]];
	} else {
		[_disconnectMenuItem setTitle:NSLS(@"Disconnect", @"Disconnect menu item")];
	}
}



- (void)_updateStatus {
	[_statusTextField setStringValue:[NSSWF:
		NSLS(@"%u %@", @"Dock status (connections, 'connection(s)')"),
		[_shownConnections count],
		[_shownConnections count] == 1
			? NSLS(@"connection", @"Connection singular")
			: NSLS(@"connections", @"Connection plural")]];
}



#pragma mark -

- (WCServerConnection *)_selectedConnection {
	int		row;
	
	row = [_dockTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _connectionAtIndex:row];
}



- (WCServerConnection *)_connectionAtIndex:(unsigned int)index {
	if(index < [_shownConnections count])
		return [_shownConnections objectAtIndex:index];
	
	return NULL;
}



#pragma mark -

- (void)_openConnection:(WCServerConnection *)connection {
	NSEnumerator		*enumerator;
	WCServerConnection	*eachConnection;
	
	if(!connection)
		return;

	if([WCSettings boolForKey:WCAutoHideOnSwitch]) {
		enumerator = [_shownConnections objectEnumerator];
		
		while((eachConnection = [enumerator nextObject])) {
			if(eachConnection != connection && ![eachConnection isHidden])
				[eachConnection hide];
		}
		
		[_dockTableView reloadData];
	}
		
	if([connection isHidden])
		[connection unhide];
		
	[[connection chat] showWindow:self];

	[self _validate];
}

@end


@implementation WCDock

+ (WCDock *)dock {
	static WCDock   *sharedDock;
	
	if(!sharedDock)
		sharedDock = [[self alloc] init];
	
	return sharedDock;
}



- (id)init {
	self = [super initWithWindowNibName:@"Dock"];
	
	_shownConnections   = [[NSMutableArray alloc] init];
	_connectedImage		= [[NSImage imageNamed:@"GreenDrop"] retain];
	_disconnectedImage	= [[NSImage imageNamed:@"RedDrop"] retain];
	_bookmarkImage		= [[NSImage imageNamed:@"Bookmark"] retain];
	_postsImage			= [[NSImage imageNamed:@"News16"] retain];
	_messagesImage		= [[NSImage imageNamed:@"Conversation"] retain];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionDidClose:)
			   name:WCConnectionDidClose];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionLoggedIn:)
			   name:WCServerConnectionLoggedIn];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUsersDidChange:)
			   name:WCChatUsersDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidAddMessage:)
			   name:WCMessagesDidAddMessage];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidReadMessage:)
			   name:WCMessagesDidReadMessage];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidAddPost:)
			   name:WCNewsDidAddPost];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidReadPost:)
			   name:WCNewsDidReadPost];

	return self;
}



#pragma mark -

- (void)windowDidLoad {
	WIIconCell			*iconCell;
	WIMultiImageCell	*imageCell;
	
	iconCell = [[WIIconCell alloc] init];
	[iconCell setImageWidth:14.0];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	imageCell = [[WIMultiImageCell alloc] init];
	[_statusTableColumn setDataCell:imageCell];
	[imageCell release];

	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Dock"];
	
	[_dockTableView setDoubleAction:@selector(open:)];
	[_dockTableView registerForDraggedTypes:[NSArray arrayWithObject:WCServerConnectionPboardType]];
	
	[self _validate];
	[self _update];
	[self _updateStatus];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[_dockTableView reloadData];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	WCServerConnection	*connection;

	connection = [notification object];
	[_shownConnections removeObject:connection];
	[_dockTableView reloadData];
	
	[self _updateStatus];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection, *eachConnection;
	
	connection = [notification object];
	
	if(![_shownConnections containsObject:connection])
		[_shownConnections addObject:connection];

	if([WCSettings boolForKey:WCAutoHideOnSwitch]) {
		enumerator = [_shownConnections objectEnumerator];
		
		while((eachConnection = [enumerator nextObject])) {
			if(eachConnection != connection && ![connection isHidden])
				[eachConnection hide];
		}
	}

	[_dockTableView reloadData];
	[self _updateStatus];
}



- (void)chatUsersDidChange:(NSNotification *)notification {
	[_dockTableView reloadData];
}



- (void)messagesDidAddMessage:(NSNotification *)notification {
	[_dockTableView reloadData];
}



- (void)messagesDidReadMessage:(NSNotification *)notification {
	[_dockTableView reloadData];
}



- (void)newsDidAddPost:(NSNotification *)notification {
	[_dockTableView reloadData];
}



- (void)newsDidReadPost:(NSNotification *)notification {
	[_dockTableView reloadData];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;

	selector = [item action];
	
	if(selector == @selector(hideConnection:) ||
	   selector == @selector(nextConnection:) ||
	   selector == @selector(previousConnection:))
		return ([_shownConnections count] > 0);
	else if(selector == @selector(disconnect:))
		return [[self _selectedConnection] isConnected];
	else if(selector == @selector(makeLayoutDefault:))
		return [[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]];
	else if(selector == @selector(restoreLayoutToDefault:))
		return ([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]] &&
				[WCSettings windowTemplateForKey:WCWindowTemplatesDefault] != NULL);
	else if(selector == @selector(restoreAllLayoutsToDefault:))
		return ([_shownConnections count] > 0 && [WCSettings windowTemplateForKey:WCWindowTemplatesDefault] != NULL);

	return YES;
}



#pragma mark -

- (unsigned int)openConnections {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection;
	unsigned int		count;
	
	enumerator = [_shownConnections objectEnumerator];
	count = 0;
	
	while((connection = [enumerator nextObject])) {
		if([connection isConnected])
			count++;
	}
	
	return count;
}



#pragma mark -

- (IBAction)open:(id)sender {
	[self _openConnection:[self _selectedConnection]];
}



- (IBAction)hide:(id)sender {
	WCServerConnection	*connection;
	
	connection = [self _selectedConnection];
	
	if([connection isHidden])
		[connection unhide];
	else
		[connection hide];

	[self _validate];
	[_dockTableView setNeedsDisplay:YES];
}



- (IBAction)addBookmark:(id)sender {
	[[[self _selectedConnection] chat] addBookmark:self];
	
	[_dockTableView reloadData];
}



- (IBAction)disconnect:(id)sender {
	WCServerConnection	*connection;
	
	connection = [self _selectedConnection];
	
	if([connection isHidden])
		[connection unhide];
	
	[[connection chat] disconnect:self];
}



- (IBAction)hideConnection:(id)sender {
	WCServerConnection	*connection;
	
	connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];
	[connection hide];
	
	[self _validate];
	[_dockTableView setNeedsDisplay:YES];
}



- (IBAction)nextConnection:(id)sender {
	WCServerConnection	*connection, *nextConnection;
	int					i;
	
	if([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]]) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];

		i = [_shownConnections indexOfObject:connection] + 1;
		
		if((unsigned int) i >= [_shownConnections count])
			i = 0;
			
		nextConnection = [self _connectionAtIndex:i];
	} else {
		connection = NULL;

		nextConnection = [self _connectionAtIndex:0];
	}
	
	if(nextConnection && connection != nextConnection)
		[self _openConnection:nextConnection];
}



- (IBAction)previousConnection:(id)sender {
	WCServerConnection	*connection, *previousConnection;
	int					i;
	
	if([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]]) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];

		i = [_shownConnections indexOfObject:connection] - 1;
		
		if(i < 0)
			i = [_shownConnections count] - 1;

		previousConnection = [self _connectionAtIndex:i];
	} else {
		connection = NULL;

		previousConnection = [_shownConnections lastObject];
	}

	if(previousConnection && connection != previousConnection)
		[self _openConnection:previousConnection];
}



- (IBAction)makeLayoutDefault:(id)sender {
	NSAlert				*alert;
	WCServerConnection	*connection;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Make Current Layout Default?", @"Make layout default dialog title")
							defaultButton:NSLS(@"OK", @"Make layout default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Make layout default dialog button title")
				informativeTextWithFormat:NSLS(@"This will set the windows for the currently shown connection as the default layout.", @"Make layout default dialog button description")];
	
	if([alert runModal] == NSAlertDefaultReturn) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];
		[connection postNotificationName:WCServerConnectionShouldSaveWindowTemplate];
		
		[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:[connection identifier]]
							   forKey:WCWindowTemplatesDefault];
	}
}



- (IBAction)restoreLayoutToDefault:(id)sender {
	NSAlert				*alert;
	WCServerConnection	*connection;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Restore Layout To Default?", @"Restore layout to default dialog title")
							defaultButton:NSLS(@"OK", @"Restore layout to default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Restore layout to default dialog button title")
				informativeTextWithFormat:NSLS(@"This will restore all windows for the currently shown connection to the previously saved default layout.", @"Restore layout to default dialog button description")];

	if([alert runModal] == NSAlertDefaultReturn) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];
		
		[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:WCWindowTemplatesDefault]
							   forKey:[connection identifier]];
		
		[connection postNotificationName:WCServerConnectionShouldLoadWindowTemplate];
	}
}



- (IBAction)restoreAllLayoutsToDefault:(id)sender {
	NSAlert				*alert;
	WCServerConnection	*connection;
	unsigned int		i, count;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Restore All Layouts To Default?", @"Restore all layouts to default dialog title")
							defaultButton:NSLS(@"OK", @"Restore all layouts to default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Restore all layouts to default dialog button title")
				informativeTextWithFormat:NSLS(@"This will restore all windows for all connections to the previously saved default layout.", @"Restore all layouts to default dialog button description")];

	if([alert runModal] == NSAlertDefaultReturn) {
		count = [_shownConnections count];
		
		for(i = 0; i < count; i++) {
			connection = [_shownConnections objectAtIndex:i];
			
			[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:WCWindowTemplatesDefault]
								   forKey:[connection identifier]];
			
			[connection postNotificationName:WCServerConnectionShouldLoadWindowTemplate];
		}
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownConnections count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	WCServerConnection	*connection;
	NSImage				*image;
	NSMutableArray		*images;
	
	connection = [self _connectionAtIndex:row];
	
	if(tableColumn == _nameTableColumn) {
		// --- status icon and name
		image = [connection isConnected] ? _connectedImage : _disconnectedImage;

		if([connection isHidden])
			image = [image tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]];
		
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[connection name],	WIIconCellTitleKey,
			image,				WIIconCellIconKey,
			NULL];
	}
	else if(tableColumn == _usersTableColumn) {
		// --- number of users
		return [NSSWF:@"%u", [[[connection chat] users] count]];
	}
	else if(tableColumn == _statusTableColumn) {
		images = [NSMutableArray array];
		
		// --- has bookmark?
		if([connection bookmark]) {
			[images addObject:[connection isHidden]
				? [_bookmarkImage tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]]
				: _bookmarkImage];
		}

		// --- has unread posts?
		if([[connection news] numberOfUnreadPosts] > 0) {
			[images addObject:[connection isHidden]
				? [_postsImage tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]]
				: _postsImage];
		}

		// --- has unread messages?
		if([[connection messages] numberOfUnreadMessages] > 0) {
			[images addObject:[connection isHidden]
				? [_messagesImage tintedImageWithColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]]
				: _messagesImage];
		}
		
		return images;
	}
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	if([cell respondsToSelector:@selector(setTextColor:)]) {
		[cell setTextColor:[[self _connectionAtIndex:row] isHidden]
			? [NSColor grayColor]
			: [NSColor blackColor]];
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
	[self _updateStatus];
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	int			row;
	
	row = [[items objectAtIndex:0] intValue];
	
	[pasteboard declareTypes:[NSArray arrayWithObject:WCServerConnectionPboardType] owner:NULL];
	[pasteboard setString:[NSSWF:@"%d", row] forType:WCServerConnectionPboardType];
	
	return YES;
}



- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;
	
	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	int				fromRow;
	
	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];
	
	if([types containsObject:WCServerConnectionPboardType]) {
		fromRow = [[pasteboard stringForType:WCServerConnectionPboardType] intValue];
		[_shownConnections moveObjectAtIndex:fromRow toIndex:row];
		[_dockTableView reloadData];
		
		return YES;
	}
	
	return NO;
}

@end
