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

#import "WCIconMatrix.h"
#import "WCIcons.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSettings.h"
#import "WCToolbar.h"

@implementation WCPreferences

- (id)init {
	self = [super initWithWindowNibName:@"Preferences"];
	
	// --- initiate the toolbar
	_toolbar = [[WCToolbar alloc] initWithPreferences:self];

	// --- load the window
	[self window];

	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(iconsShouldReload:)
			   name:WCIconsShouldReload
			 object:NULL];
	
	return self;
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator		*enumerator, *soundEnumerator;
	NSMutableArray		*sounds;
	NSArray				*types, *files;
	NSString			*path, *sound;
	NSFont				*font;
	
	// --- load initial icons
	[_iconMatrix updateIcons];
	
	// --- edit on double-click
	[_bookmarkTableView setDoubleAction:@selector(editBookmark:)];
	[_trackerTableView setDoubleAction:@selector(editTracker:)];
	[_ignoreTableView setDoubleAction:@selector(editIgnore:)];
	
	// --- we're doing drag'n'drop
	[_bookmarkTableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL]];
	[_trackerTableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL]];
	[_ignoreTableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL]];
		
	// --- no row yet
	_currentRow = -1;

	// --- use a smaller font for the lists
	font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
	[[_bookmarkNameTableColumn dataCell] setFont:font];
	[[_bookmarkAddressTableColumn dataCell] setFont:font];
	[[_bookmarkLoginTableColumn dataCell] setFont:font];
	[[_trackerNameTableColumn dataCell] setFont:font];
	[[_trackerAddressTableColumn dataCell] setFont:font];
	[[_ignoreNickTableColumn dataCell] setFont:font];
	[[_ignoreLoginTableColumn dataCell] setFont:font];
	[[_ignoreAddressTableColumn dataCell] setFont:font];
	
	// --- load sounds
	sounds		= [NSMutableArray array];
	types		= [NSSound soundUnfilteredFileTypes];
	enumerator	= [NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES)
					objectEnumerator];
	
	while((path = [enumerator nextObject])) {
		path = [path stringByAppendingPathComponent:@"Sounds"];
		files = [[NSFileManager defaultManager] directoryContentsAtPath:path];
		soundEnumerator = [[files pathsMatchingExtensions:types] objectEnumerator];

		while((sound = [soundEnumerator nextObject]))
			[sounds addObject:[sound stringByDeletingPathExtension]];
	}

	[_soundsPopUpButton addItemsWithTitles:[sounds sortedArrayUsingSelector:@selector(compare:)]];

	// --- add a toolbar
	[[self window] setToolbar:[_toolbar preferencesToolbar]];

	// --- window position
	[[self window] center];

	// --- table view positions
	[_bookmarkTableView setAutosaveName:@"Bookmarks"];
	[_bookmarkTableView setAutosaveTableColumns:YES];
	[_trackerTableView setAutosaveName:@"Trackers"];
	[_trackerTableView setAutosaveTableColumns:YES];
	[_ignoreTableView setAutosaveName:@"Ignores"];
	[_ignoreTableView setAutosaveTableColumns:YES];
}



- (void)iconsShouldReload:(NSNotification *)notification {
	[_iconMatrix updateIcons];
}


- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if(returnCode == NSOKButton)
		[_downloadFolderTextField setStringValue:[[openPanel filenames] objectAtIndex:0]];
}



#pragma mark -

- (IBAction)showWindow:(id)sender {
	int		row, column, icon;
	
	// --- personal
	[_nickTextField setStringValue:[WCSettings objectForKey:WCNick]];

	icon = [[WCSettings objectForKey:WCIcon] intValue];
	
	if(icon == 0)
		icon = 128;

	[_iconMatrix selectCellWithTag:icon];

	// --- scroll so that the selected icon is visible
	if([_iconMatrix getRow:&row column:&column ofCell:[_iconMatrix selectedCell]])
		[_iconMatrix scrollCellToVisibleAtRow:row column:column];

	// --- general
	_currentFont = [WCSettings archivedObjectForKey:WCTextFont];
	[_fontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentFont displayName], [_currentFont pointSize]]];

	if([[WCSettings objectForKey:WCShowConnectAtStartup] boolValue])
		[_showConnectAtStartupButton setState:NSOnState];
	else
		[_showConnectAtStartupButton setState:NSOffState];

	if([[WCSettings objectForKey:WCConfirmDisconnect] boolValue])
		[_confirmDisconnectButton setState:NSOnState];
	else
		[_confirmDisconnectButton setState:NSOffState];

	// --- chat
	[_chatTextColorWell setColor:[WCSettings archivedObjectForKey:WCChatTextColor]];
	[_chatBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCChatBackgroundColor]];
	[_chatEventColorWell setColor:[WCSettings archivedObjectForKey:WCEventTextColor]];
	[_chatURLColorWell setColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
		
	[_nickCompleteWithTextField setStringValue:[WCSettings objectForKey:WCNickCompleteWith]];

	if([[WCSettings objectForKey:WCShowEventTimestamps] boolValue])
		[_showEventTimestampsButton setState:NSOnState];
	else
		[_showEventTimestampsButton setState:NSOffState];

	if([[WCSettings objectForKey:WCShowChatTimestamps] boolValue])
		[_showChatTimestampsButton setState:NSOnState];
	else
		[_showChatTimestampsButton setState:NSOffState];

	// --- news
	[_newsTextColorWell setColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_newsBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];

	if([[WCSettings objectForKey:WCLoadNewsOnLogin] boolValue])
		[_loadNewsOnLoginButton setState:NSOnState];
	else
		[_loadNewsOnLoginButton setState:NSOffState];
	
	if([(NSString *) [WCSettings objectForKey:WCSoundForNewPosts] length] > 0)
		[_soundsPopUpButton selectItemWithTitle:[WCSettings objectForKey:WCSoundForNewPosts]];

	// --- messages
	[_messageTextColorWell setColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];
	[_messageBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCMessageBackgroundColor]];

	if([[WCSettings objectForKey:WCShowMessagesInForeground] boolValue])
		[_showMessagesInForegroundButton setState:NSOnState];
	else
		[_showMessagesInForegroundButton setState:NSOffState];
		
	// --- files
	[_downloadFolderTextField setStringValue:[WCSettings objectForKey:WCDownloadFolder]];

	if([[WCSettings objectForKey:WCOpenFoldersInNewWindows] boolValue])
		[_openFoldersInNewWindowsButton setState:NSOnState];
	else
		[_openFoldersInNewWindowsButton setState:NSOffState];
		
	if([[WCSettings objectForKey:WCQueueTransfers] boolValue])
		[_queueTransfersButton setState:NSOnState];
	else
		[_queueTransfersButton setState:NSOffState];

	if([[WCSettings objectForKey:WCEncryptTransfers] boolValue])
		[_encryptTransfersButton setState:NSOnState];
	else
		[_encryptTransfersButton setState:NSOffState];

	// --- show the window
	[super showWindow:self];
}



- (void)selectTab:(NSString *)identifier {
	[_preferencesTabView selectTabViewItemWithIdentifier:identifier];
}



#pragma mark -

- (IBAction)ok:(id)sender {
	NSString		*nick;
	int				icon;
	
	// --- personal
	nick = [_nickTextField stringValue];
	
	if(![nick isEqualToString:[WCSettings objectForKey:WCNick]]) {
		// --- make sure we only change the nick if it's actually changed
		[WCSettings setObject:nick forKey:WCNick];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCNickDidChange object:NULL];
	}

	icon = [[_iconMatrix selectedCell] tag];
	
	if(icon != [[WCSettings objectForKey:WCIcon] intValue]) {
		// --- make sure we only change the icon if it's actually changed
		[WCSettings setObject:[NSNumber numberWithInt:icon] forKey:WCIcon];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange object:NULL];
	}
	
	// --- general
	[WCSettings setArchivedObject:_currentFont forKey:WCTextFont];

	if([_showConnectAtStartupButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCShowConnectAtStartup];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCShowConnectAtStartup];

	if([_confirmDisconnectButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCConfirmDisconnect];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCConfirmDisconnect];

	// --- chat
	[WCSettings setArchivedObject:[_chatTextColorWell color] forKey:WCChatTextColor];
	[WCSettings setArchivedObject:[_chatBackgroundColorWell color] forKey:WCChatBackgroundColor];
	[WCSettings setArchivedObject:[_chatEventColorWell color] forKey:WCEventTextColor];
	[WCSettings setArchivedObject:[_chatURLColorWell color] forKey:WCURLTextColor];

	[WCSettings setObject:[_nickCompleteWithTextField stringValue] forKey:WCNickCompleteWith];

	if([_showEventTimestampsButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCShowEventTimestamps];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCShowEventTimestamps];

	if([_showChatTimestampsButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCShowChatTimestamps];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCShowChatTimestamps];

	// --- news
	[WCSettings setArchivedObject:[_newsTextColorWell color] forKey:WCNewsTextColor];
	[WCSettings setArchivedObject:[_newsBackgroundColorWell color] forKey:WCNewsBackgroundColor];

	if([_loadNewsOnLoginButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCLoadNewsOnLogin];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCLoadNewsOnLogin];

	[WCSettings setObject:[[_soundsPopUpButton selectedItem] tag] == 0
					? [_soundsPopUpButton titleOfSelectedItem]
					: @""
				forKey:WCSoundForNewPosts];

	// --- messages
	[WCSettings setArchivedObject:[_messageTextColorWell color] forKey:WCMessageTextColor];
	[WCSettings setArchivedObject:[_messageBackgroundColorWell color] forKey:WCMessageBackgroundColor];

	if([_showMessagesInForegroundButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCShowMessagesInForeground];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCShowMessagesInForeground];
		
	// --- files
	[WCSettings setObject:[_downloadFolderTextField stringValue] forKey:WCDownloadFolder];

	if([_openFoldersInNewWindowsButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCOpenFoldersInNewWindows];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCOpenFoldersInNewWindows];
	
	if([_queueTransfersButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCQueueTransfers];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCQueueTransfers];
	
	if([_encryptTransfersButton state] == NSOnState)
		[WCSettings setObject:[NSNumber numberWithBool:YES] forKey:WCEncryptTransfers];
	else
		[WCSettings setObject:[NSNumber numberWithBool:NO] forKey:WCEncryptTransfers];
	
	// --- broadcast preferences change
	[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChange object:NULL];

	// --- close
	[self close];
}



- (IBAction)showFontPanel:(id)sender {
	NSFontManager		*fontManager;
	
	fontManager = [NSFontManager sharedFontManager];

	[fontManager setSelectedFont:[WCSettings archivedObjectForKey:WCTextFont]
					  isMultiple:NO];
	[fontManager orderFrontFontPanel:self];
}



- (void)changeFont:(id)sender {
	NSFont			*font;
	
	font			= [WCSettings archivedObjectForKey:WCTextFont];
	_currentFont	= [sender convertFont:font];
	
	[_fontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentFont displayName], [_currentFont pointSize]]];
}



- (IBAction)selectDownloadFolder:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];
	
	// --- set options
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	
	// --- run panel
	[openPanel beginSheetForDirectory:[_downloadFolderTextField stringValue]
			   file:NULL
			   types:NULL
			   modalForWindow:[self window]
			   modalDelegate:self
			   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
			   contextInfo:NULL];
	
}



- (IBAction)selectSound:(id)sender {
	if([[sender selectedItem] tag] == 0)
		[[NSSound soundNamed:[sender titleOfSelectedItem]] play];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_bookmarkPanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)editBookmark:(id)sender {
	NSDictionary	*bookmark;
	int				row;
	
	// --- get row
	row = [_bookmarkTableView selectedRow];
	
	if(row < 0)
		return;

	// --- get bookmark
	bookmark = [[WCSettings objectForKey:WCBookmarks] objectAtIndex:row];
	
	// --- fill out fields
	[_bookmarkNameTextField setStringValue:[bookmark objectForKey:@"Name"]];
	[_bookmarkAddressTextField setStringValue:[bookmark objectForKey:@"Address"]];
	[_bookmarkLoginTextField setStringValue:[bookmark objectForKey:@"Login"]];
	[_bookmarkPasswordTextField setStringValue:[bookmark objectForKey:@"Password"]];
	
	// --- save current row
	_currentRow = row;
	
	// --- show sheet
	[NSApp beginSheet:_bookmarkPanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)deleteBookmark:(id)sender {
	NSMutableArray	*bookmarks;
	int				row;
	
	// --- get row
	row = [_bookmarkTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- delete
	bookmarks = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];
	[bookmarks removeObjectAtIndex:row];
	
	// --- set new
	[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
	
	// --- reload
	[_bookmarkTableView reloadData];
}



#pragma mark -

- (IBAction)okBookmark:(id)sender {
	NSMutableArray		*bookmarks;
	NSMutableDictionary	*bookmark;
	
	// --- create mutable bookmarks
	bookmarks = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];
	
	// --- remove old if user changed name
	if(_currentRow > -1) {
		// --- get bookmark
		bookmark = [NSMutableDictionary dictionaryWithDictionary:
						[bookmarks objectAtIndex:_currentRow]];
		
		// --- update fields
		[bookmark setObject:[_bookmarkNameTextField stringValue] forKey:@"Name"];
		[bookmark setObject:[_bookmarkAddressTextField stringValue] forKey:@"Address"];
		[bookmark setObject:[_bookmarkLoginTextField stringValue] forKey:@"Login"];
		[bookmark setObject:[_bookmarkPasswordTextField stringValue] forKey:@"Password"];
		
		// --- replace in bookmarks
		[bookmarks replaceObjectAtIndex:_currentRow
				   withObject:[NSDictionary dictionaryWithDictionary:bookmark]];
		
		_currentRow = -1;
	} else {
		// --- create bookmark
		bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
			[_bookmarkNameTextField stringValue], @"Name",
			[_bookmarkAddressTextField stringValue], @"Address",
			[_bookmarkLoginTextField stringValue], @"Login",
			[_bookmarkPasswordTextField stringValue], @"Password",
			NULL];

		// --- add to bookmarks
		[bookmarks addObject:bookmark];
	}
		
	// --- set new bookmarks
	[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
	
	// --- reload
	[_bookmarkTableView reloadData];

	// --- close sheet
	[self cancelBookmark:self];
}



- (IBAction)cancelBookmark:(id)sender {
	// --- close sheet
	[NSApp endSheet:_bookmarkPanel];
	[_bookmarkPanel close];
	
	// --- clear for next round
	[_bookmarkNameTextField setStringValue:@""];
	[_bookmarkAddressTextField setStringValue:@""];
	[_bookmarkLoginTextField setStringValue:@""];
	[_bookmarkPasswordTextField setStringValue:@""];
}



#pragma mark -

- (IBAction)addTracker:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_trackerPanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)editTracker:(id)sender {
	NSDictionary	*tracker;
	int				row;
	
	// --- get row
	row = [_trackerTableView selectedRow];
	
	if(row < 0)
		return;

	// --- get bookmark
	tracker = [[WCSettings objectForKey:WCTrackerBookmarks] objectAtIndex:row];
	
	// --- fill out fields
	[_trackerNameTextField setStringValue:[tracker objectForKey:@"Name"]];
	[_trackerAddressTextField setStringValue:[tracker objectForKey:@"Address"]];
	
	// --- save current row
	_currentRow = row;
	
	// --- show sheet
	[NSApp beginSheet:_trackerPanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)deleteTracker:(id)sender {
	NSMutableArray	*trackers;
	int				row;
	
	// --- get row
	row = [_trackerTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- delete
	trackers = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCTrackerBookmarks]];
	[trackers removeObjectAtIndex:row];
	
	// --- set new
	[WCSettings setObject:[NSArray arrayWithArray:trackers] forKey:WCTrackerBookmarks];
	
	// --- reload
	[_trackerTableView reloadData];
}



#pragma mark -

- (IBAction)okTracker:(id)sender {
	NSMutableArray		*trackers;
	NSMutableDictionary	*tracker;
	
	// --- create mutable bookmarks
	trackers = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCTrackerBookmarks]];
	
	// --- remove old if user changed name
	if(_currentRow > -1) {
		// --- get bookmark
		tracker = [NSMutableDictionary dictionaryWithDictionary:
						[trackers objectAtIndex:_currentRow]];
		
		// --- update fields
		[tracker setObject:[_trackerNameTextField stringValue] forKey:@"Name"];
		[tracker setObject:[_trackerAddressTextField stringValue] forKey:@"Address"];
		
		// --- replace in bookmarks
		[trackers replaceObjectAtIndex:_currentRow
				  withObject:[NSDictionary dictionaryWithDictionary:tracker]];
		
		_currentRow = -1;
	} else {
		// --- create bookmark
		tracker = [NSDictionary dictionaryWithObjectsAndKeys:
					[_trackerNameTextField stringValue], @"Name",
					[_trackerAddressTextField stringValue], @"Address",
					NULL];

		// --- add to bookmarks
		[trackers addObject:tracker];
	}
		
	// --- set new bookmarks
	[WCSettings setObject:[NSArray arrayWithArray:trackers] forKey:WCTrackerBookmarks];
	
	// --- reload
	[_trackerTableView reloadData];

	// --- close sheet
	[self cancelTracker:self];
}



- (IBAction)cancelTracker:(id)sender {
	// --- close sheet
	[NSApp endSheet:_trackerPanel];
	[_trackerPanel close];
	
	// --- clear for next round
	[_trackerNameTextField setStringValue:@""];
	[_trackerAddressTextField setStringValue:@""];
}



#pragma mark -

- (IBAction)addIgnore:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_ignorePanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)editIgnore:(id)sender {
	NSDictionary	*ignore;
	int				row;
	
	// --- get row
	row = [_ignoreTableView selectedRow];

	if(row < 0)
		return;

	// --- get bookmark
	ignore = [[WCSettings objectForKey:WCIgnoredUsers] objectAtIndex:row];
	
	// --- fill out fields
	[_ignoreNickTextField setStringValue:[ignore objectForKey:@"Nick"]];
	[_ignoreLoginTextField setStringValue:[ignore objectForKey:@"Login"]];
	[_ignoreAddressTextField setStringValue:[ignore objectForKey:@"Address"]];
	
	// --- save current row
	_currentRow = row;
	
	// --- show sheet
	[NSApp beginSheet:_ignorePanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)deleteIgnore:(id)sender {
	NSMutableArray	*ignores;
	int				row;
	
	// --- get row
	row = [_ignoreTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- delete
	ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnoredUsers]];
	[ignores removeObjectAtIndex:row];
	
	// --- set new
	[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnoredUsers];
	
	// --- reload
	[_ignoreTableView reloadData];
}



#pragma mark -

- (IBAction)okIgnore:(id)sender {
	NSMutableArray		*ignores;
	NSMutableDictionary	*ignore;
	
	// --- create mutable ignores
	ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnoredUsers]];
	
	// --- remove old if user changed name
	if(_currentRow > -1) {
		// --- get ignore
		ignore = [NSMutableDictionary dictionaryWithDictionary:
						[ignores objectAtIndex:_currentRow]];
		
		// --- update fields
		[ignore setObject:[_ignoreNickTextField stringValue] forKey:@"Nick"];
		[ignore setObject:[_ignoreLoginTextField stringValue] forKey:@"Login"];
		[ignore setObject:[_ignoreAddressTextField stringValue] forKey:@"Address"];
		
		// --- replace in ignores
		[ignores replaceObjectAtIndex:_currentRow
				 withObject:[NSDictionary dictionaryWithDictionary:ignore]];
		
		_currentRow = -1;
	} else {
		// --- create ignore
		ignore = [NSDictionary dictionaryWithObjectsAndKeys:
					[_ignoreNickTextField stringValue], @"Nick",
					[_ignoreLoginTextField stringValue], @"Login",
					[_ignoreAddressTextField stringValue], @"Address",
					NULL];

		// --- add to ignores
		[ignores addObject:ignore];
	}
		
	// --- set new ignores
	[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnoredUsers];
	
	// --- reload
	[_ignoreTableView reloadData];

	// --- close sheet
	[self cancelIgnore:self];
}



- (IBAction)cancelIgnore:(id)sender {
	// --- close sheet
	[NSApp endSheet:_ignorePanel];
	[_ignorePanel close];
	
	// --- clear for next round
	[_ignoreNickTextField setStringValue:@""];
	[_ignoreLoginTextField setStringValue:@""];
	[_ignoreAddressTextField setStringValue:@""];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == _bookmarkTableView)
		return [[WCSettings objectForKey:WCBookmarks] count];
	else if(tableView == _trackerTableView)
		return [[WCSettings objectForKey:WCTrackerBookmarks] count];
	else if(tableView == _ignoreTableView)
		return [[WCSettings objectForKey:WCIgnoredUsers] count];
	
	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	if(tableView == _bookmarkTableView) {
		NSDictionary	*bookmark;
	
		// --- get bookmark
		bookmark = [[WCSettings objectForKey:WCBookmarks] objectAtIndex:row];

		if(column == _bookmarkNameTableColumn)
			return [bookmark objectForKey:@"Name"];
		else if(column == _bookmarkAddressTableColumn)
			return [bookmark objectForKey:@"Address"];
		else if(column == _bookmarkLoginTableColumn)
			return [bookmark objectForKey:@"Login"];
	}
	else if(tableView == _trackerTableView) {
		NSDictionary	*tracker;
	
		// --- get tracker
		tracker = [[WCSettings objectForKey:WCTrackerBookmarks] objectAtIndex:row];

		if(column == _trackerNameTableColumn)
			return [tracker objectForKey:@"Name"];
		else if(column == _trackerAddressTableColumn)
			return [tracker objectForKey:@"Address"];
	}
	else if(tableView == _ignoreTableView) {
		NSDictionary	*ignore;
	
		// --- get tracker
		ignore = [[WCSettings objectForKey:WCIgnoredUsers] objectAtIndex:row];

		if(column == _ignoreNickTableColumn)
			return [ignore objectForKey:@"Nick"];
		else if(column == _ignoreLoginTableColumn)
			return [ignore objectForKey:@"Login"];
		else if(column == _ignoreAddressTableColumn)
			return [ignore objectForKey:@"Address"];
	}

	return NULL;
}





- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	int			row;
		
	// --- get row
	row = [[items objectAtIndex:0] intValue];
		
	// --- put in pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[NSString stringWithFormat:@"%d", row] forType:NSStringPboardType];
	
	return YES;
}



- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id 
<NSDraggingInfo>)info proposedRow:(int)row 
proposedDropOperation:(NSTableViewDropOperation)operation{
	// --- only accept drops in between rows
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;
	
	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info 
row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	if(tableView == _bookmarkTableView) {
		NSPasteboard	*pasteboard;
		NSMutableArray	*bookmarks;
		NSDictionary	*bookmark;
		int				fromRow, toRow;
		
		// --- get row of the dragged object
		pasteboard	= [info draggingPasteboard];
		fromRow		= [[pasteboard stringForType:NSStringPboardType] intValue];
		
		// --- create mutable bookmarks and get this one
		bookmarks	= [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];
		bookmark	= [[bookmarks objectAtIndex:fromRow] retain];
		
		// --- remove object and insert object at new row, which is one lower if the row
		//     is below the removed row
		toRow = row < fromRow ? row : row - 1;
		[bookmarks removeObjectAtIndex:fromRow];
		[bookmarks insertObject:bookmark atIndex:toRow];
		[bookmark release];
		
		// --- set new bookmarks
		[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
	
		// --- reload table
		[_bookmarkTableView reloadData];

		return YES;
	}
	else if(tableView == _trackerTableView) {
		NSPasteboard	*pasteboard;
		NSMutableArray	*trackers;
		NSDictionary	*tracker;
		int				fromRow, toRow;
		
		// --- get row of the dragged object
		pasteboard	= [info draggingPasteboard];
		fromRow		= [[pasteboard stringForType:NSStringPboardType] intValue];
		
		// --- create mutable bookmarks and get this one
		trackers	= [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCTrackerBookmarks]];
		tracker		= [[trackers objectAtIndex:fromRow] retain];
		
		// --- remove object and insert object at new row, which is one lower if the row
		//     is below the removed row
		toRow = row < fromRow ? row : row - 1;
		[trackers removeObjectAtIndex:fromRow];
		[trackers insertObject:tracker atIndex:toRow];
		[tracker release];
		
		// --- set new bookmarks
		[WCSettings setObject:[NSArray arrayWithArray:trackers] forKey:WCTrackerBookmarks];
	
		// --- reload table
		[_trackerTableView reloadData];

		return YES;
	}
	else if(tableView == _ignoreTableView) {
		NSPasteboard	*pasteboard;
		NSMutableArray	*ignores;
		NSDictionary	*ignore;
		int				fromRow, toRow;
		
		// --- get row of the dragged object
		pasteboard	= [info draggingPasteboard];
		fromRow		= [[pasteboard stringForType:NSStringPboardType] intValue];
		
		// --- create mutable bookmarks and get this one
		ignores		= [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnoredUsers]];
		ignore		= [[ignores objectAtIndex:fromRow] retain];
		
		// --- remove object and insert object at new row, which is one lower if the row
		//     is below the removed row
		toRow = row < fromRow ? row : row - 1;
		[ignores removeObjectAtIndex:fromRow];
		[ignores insertObject:ignore atIndex:toRow];
		[ignore release];
		
		// --- set new bookmarks
		[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnoredUsers];
	
		// --- reload table
		[_ignoreTableView reloadData];

		return YES;
	}
	
	return NO;
}

@end
