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

#import "NSDataAdditions.h"
#import "NSPopUpButtonAdditions.h"
#import "WCIconMatrix.h"
#import "WCIcons.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSettings.h"
#import "WCTrackers.h"
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
	NSData				*data;
	NSImage				*image;
	int					row, column, icon;
	
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

		while((sound = [[soundEnumerator nextObject] stringByDeletingPathExtension])) {
			[_connectedEventPopUpButton addItemWithTitle:sound];
			[_disconnectedEventPopUpButton addItemWithTitle:sound];
			[_chatEventPopUpButton addItemWithTitle:sound];
			[_userJoinEventPopUpButton addItemWithTitle:sound];
			[_userLeaveEventPopUpButton addItemWithTitle:sound];
			[_messagesEventPopUpButton addItemWithTitle:sound];
			[_newsEventPopUpButton addItemWithTitle:sound];
			[_broadcastEventPopUpButton addItemWithTitle:sound];
			[_transferStartedEventPopUpButton addItemWithTitle:sound];
			[_transferDoneEventPopUpButton addItemWithTitle:sound];
		}
	}

	// --- add a toolbar
	[[self window] setToolbar:[_toolbar preferencesToolbar]];

	// --- window position
	[[self window] center];
	
	// --- default tab
	[self selectTab:@"General"];

	// --- table view positions
	[_bookmarkTableView setAutosaveName:@"Bookmarks"];
	[_bookmarkTableView setAutosaveTableColumns:YES];
	[_trackerTableView setAutosaveName:@"Trackers"];
	[_trackerTableView setAutosaveTableColumns:YES];
	[_ignoreTableView setAutosaveName:@"Ignores"];
	[_ignoreTableView setAutosaveTableColumns:YES];

	// --- general
	_currentTextFont = [WCSettings archivedObjectForKey:WCTextFont];
	[_eventColorWell setColor:[WCSettings archivedObjectForKey:WCEventTextColor]];
	[_URLColorWell setColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
	[_fontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentTextFont displayName], [_currentTextFont pointSize]]];
	
	[_showConnectAtStartupButton setState:[WCSettings boolForKey:WCShowConnectAtStartup]];
	[_showTransfersAtStartupButton setState:[WCSettings boolForKey:WCShowTrackersAtStartup]];
	[_confirmDisconnectButton setState:[WCSettings boolForKey:WCConfirmDisconnect]];
	
	// --- personal
	[_nickTextField setStringValue:[WCSettings objectForKey:WCNick]];
	[_statusTextField setStringValue:[WCSettings objectForKey:WCStatus]];
	
	data = [NSData dataWithBase64EncodedString:[WCSettings objectForKey:WCCustomIcon]];
	image = [[NSImage alloc] initWithData:data];
	
	if(image) {
		[_iconImageView setImage:image];
		[image release];
	}
	
	icon = [WCSettings intForKey:WCIcon];
	
	if(icon == 0)
		icon = 128;
	
	[_iconMatrix selectCellWithTag:icon];
	
	if([_iconMatrix getRow:&row column:&column ofCell:[_iconMatrix selectedCell]])
		[_iconMatrix scrollCellToVisibleAtRow:row column:column];
	
	// --- chat
	[_chatTextColorWell setColor:[WCSettings archivedObjectForKey:WCChatTextColor]];
	[_chatBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCChatBackgroundColor]];
	
	[_chatStyleMatrix selectCellWithTag:[WCSettings intForKey:WCChatStyle]];
	[_iconSizeMatrix selectCellWithTag:[WCSettings intForKey:WCIconSize]];
	[_historyScrollbackButton setState:[WCSettings boolForKey:WCHistoryScrollback]];
	[_historyScrollbackModifierPopUpButton selectItemWithTag:
		[WCSettings intForKey:WCHistoryScrollbackModifier]];
	[_tabCompleteNicksButton setState:[WCSettings boolForKey:WCTabCompleteNicks]];
	[_tabCompleteNicksTextField setStringValue:[WCSettings objectForKey:WCTabCompleteNicksString]];
	[_highlightWordsButton setState:[WCSettings boolForKey:WCHighlightWords]];
	[_highlightWordsColorWell setColor:
		[WCSettings archivedObjectForKey:WCHighlightWordsTextColor]];
	[_timestampChatButton setState:[WCSettings boolForKey:WCTimestampChat]];
	[_timestampChatIntervalTextField setStringValue:[NSString stringWithFormat:@"%.0f",
		(double) [WCSettings intForKey:WCTimestampChatInterval] / (double) 60]];
	[_timestampEveryLineButton setState:[WCSettings boolForKey:WCTimestampEveryLine]];
	[_timestampEveryLineColorWell setColor:
		[WCSettings archivedObjectForKey:WCTimestampEveryLineTextColor]];
	
	[_showJoinLeaveButton setState:[WCSettings boolForKey:WCShowJoinLeave]];
	[_showNickChangesButton setState:[WCSettings boolForKey:WCShowNickChanges]];
	
	// --- news
	_currentNewsFont = [WCSettings archivedObjectForKey:WCNewsFont];
	[_newsFontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentNewsFont displayName], [_currentNewsFont pointSize]]];
	
	[_newsTextColorWell setColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_newsBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];
	
	[_loadNewsOnLoginButton setState:[WCSettings boolForKey:WCLoadNewsOnLogin]];
	
	// --- messages
	[_messageTextColorWell setColor:[WCSettings archivedObjectForKey:WCMessageTextColor]];
	[_messageBackgroundColorWell setColor:[WCSettings archivedObjectForKey:WCMessageBackgroundColor]];
	
	[_showMessagesInForegroundButton setState:[WCSettings boolForKey:WCShowMessagesInForeground]];
	
	// --- files
	[_downloadFolderTextField setStringValue:[WCSettings objectForKey:WCDownloadFolder]];
	
	[_openFoldersInNewWindowsButton setState:[WCSettings boolForKey:WCOpenFoldersInNewWindows]];
	[_queueTransfersButton setState:[WCSettings boolForKey:WCQueueTransfers]];
	[_encryptTransfersButton setState:[WCSettings boolForKey:WCEncryptTransfers]];
	[_removeTransfersButton setState:[WCSettings boolForKey:WCRemoveTransfers]];

	// --- sounds
	if([(NSString *) [WCSettings objectForKey:WCConnectedEventSound] length] > 0) {
		[_connectedEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCConnectedEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCDisconnectedEventSound] length] > 0) {
		[_disconnectedEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCDisconnectedEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCChatEventSound] length] > 0) {
		[_chatEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCChatEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCUserJoinEventSound] length] > 0) {
		[_userJoinEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCUserJoinEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCUserLeaveEventSound] length] > 0) {
		[_userLeaveEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCUserLeaveEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCMessagesEventSound] length] > 0) {
		[_messagesEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCMessagesEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCNewsEventSound] length] > 0) {
		[_newsEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCNewsEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCBroadcastEventSound] length] > 0) {
		[_broadcastEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCBroadcastEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCTransferStartedEventSound] length] > 0) {
		[_transferStartedEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCTransferStartedEventSound]];
	}
	
	if([(NSString *) [WCSettings objectForKey:WCTransferDoneEventSound] length] > 0) {
		[_transferDoneEventPopUpButton selectItemWithTitle:
			[WCSettings objectForKey:WCTransferDoneEventSound]];
	}
}



- (BOOL)windowShouldClose:(id)sender {
	// --- general
	[WCSettings setArchivedObject:_currentTextFont forKey:WCTextFont];
	
	[WCSettings setArchivedObject:[_eventColorWell color] forKey:WCEventTextColor];
	[WCSettings setArchivedObject:[_URLColorWell color] forKey:WCURLTextColor];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_showConnectAtStartupButton state] == NSOnState)] 
				   forKey:WCShowConnectAtStartup];

	[WCSettings setObject:[NSNumber numberWithBool:([_showTransfersAtStartupButton state] == NSOnState)] 
				   forKey:WCShowTrackersAtStartup];

	[WCSettings setObject:[NSNumber numberWithBool:([_confirmDisconnectButton state] == NSOnState)] 
				   forKey:WCConfirmDisconnect];
	
	// --- personal
	if(![[_nickTextField stringValue] isEqualToString:[WCSettings objectForKey:WCNick]]) {
		// --- make sure we only change the nick if it's actually changed
		[WCSettings setObject:[_nickTextField stringValue] forKey:WCNick];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCNickDidChange object:NULL];
	}
	
	if(![[_statusTextField stringValue] isEqualToString:[WCSettings objectForKey:WCStatus]]) {
		// --- make sure we only change the nick if it's actually changed
		[WCSettings setObject:[_statusTextField stringValue] forKey:WCStatus];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCStatusDidChange object:NULL];
	}
	
	if([[_iconMatrix selectedCell] tag] != [WCSettings intForKey:WCIcon]) {
		// --- make sure we only change the icon if it's actually changed
		[WCSettings setObject:[NSNumber numberWithInt:[[_iconMatrix selectedCell] tag]]
					   forKey:WCIcon];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange object:NULL];
	}
	
	// --- chat
	[WCSettings setArchivedObject:[_chatTextColorWell color] forKey:WCChatTextColor];
	[WCSettings setArchivedObject:[_chatBackgroundColorWell color] forKey:WCChatBackgroundColor];

	[WCSettings setObject:[NSNumber numberWithInt:[[_chatStyleMatrix selectedCell] tag]]
				   forKey:WCChatStyle];
	
	[WCSettings setObject:[NSNumber numberWithInt:[[_iconSizeMatrix selectedCell] tag]]
				   forKey:WCIconSize];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_historyScrollbackButton state] == NSOnState)] 
				   forKey:WCHistoryScrollback];
	[WCSettings setObject:[NSNumber numberWithInt:[[_historyScrollbackModifierPopUpButton selectedItem] tag]]
				   forKey:WCHistoryScrollbackModifier];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_tabCompleteNicksButton state] == NSOnState)] 
				   forKey:WCTabCompleteNicks];
	[WCSettings setObject:[_tabCompleteNicksTextField stringValue] forKey:WCTabCompleteNicksString];

	[WCSettings setObject:[NSNumber numberWithBool:([_highlightWordsButton state] == NSOnState)] 
				   forKey:WCHighlightWords];
	[WCSettings setArchivedObject:[_highlightWordsColorWell color] 
						   forKey:WCHighlightWordsTextColor];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_timestampChatButton state] == NSOnState)] 
				   forKey:WCTimestampChat];
	[WCSettings setObject:[NSNumber numberWithInt:[_timestampChatIntervalTextField intValue] * 60]
				   forKey:WCTimestampChatInterval];

	[WCSettings setObject:[NSNumber numberWithBool:([_timestampEveryLineButton state] == NSOnState)] 
				   forKey:WCTimestampEveryLine];
	[WCSettings setArchivedObject:[_timestampEveryLineColorWell color] 
						   forKey:WCTimestampEveryLineTextColor];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_showJoinLeaveButton state] == NSOnState)] 
				   forKey:WCShowJoinLeave];
	[WCSettings setObject:[NSNumber numberWithBool:([_showNickChangesButton state] == NSOnState)] 
				   forKey:WCShowNickChanges];
	
	// --- news
	[WCSettings setArchivedObject:_currentNewsFont forKey:WCNewsFont];
	
	[WCSettings setArchivedObject:[_newsTextColorWell color] forKey:WCNewsTextColor];
	[WCSettings setArchivedObject:[_newsBackgroundColorWell color] forKey:WCNewsBackgroundColor];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_loadNewsOnLoginButton state] == NSOnState)] 
				   forKey:WCLoadNewsOnLogin];
	
	// --- messages
	[WCSettings setArchivedObject:[_messageTextColorWell color] forKey:WCMessageTextColor];
	[WCSettings setArchivedObject:[_messageBackgroundColorWell color] forKey:WCMessageBackgroundColor];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_showMessagesInForegroundButton state] == NSOnState)] 
				   forKey:WCShowMessagesInForeground];
	
	// --- files
	[WCSettings setObject:[_downloadFolderTextField stringValue] forKey:WCDownloadFolder];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_openFoldersInNewWindowsButton state] == NSOnState)] 
				   forKey:WCOpenFoldersInNewWindows];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_queueTransfersButton state] == NSOnState)] 
				   forKey:WCQueueTransfers];
	
	[WCSettings setObject:[NSNumber numberWithBool:([_encryptTransfersButton state] == NSOnState)] 
				   forKey:WCEncryptTransfers];

	[WCSettings setObject:[NSNumber numberWithBool:([_removeTransfersButton state] == NSOnState)] 
				   forKey:WCRemoveTransfers];

	// --- sounds
	[WCSettings setObject:[[_connectedEventPopUpButton selectedItem] tag] == 0
		? [_connectedEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCConnectedEventSound];
	
	[WCSettings setObject:[[_disconnectedEventPopUpButton selectedItem] tag] == 0
		? [_disconnectedEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCDisconnectedEventSound];
	
	[WCSettings setObject:[[_chatEventPopUpButton selectedItem] tag] == 0
		? [_chatEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCChatEventSound];
	
	[WCSettings setObject:[[_userJoinEventPopUpButton selectedItem] tag] == 0
		? [_userJoinEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCUserJoinEventSound];
	
	[WCSettings setObject:[[_userLeaveEventPopUpButton selectedItem] tag] == 0
		? [_userLeaveEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCUserLeaveEventSound];
	
	[WCSettings setObject:[[_messagesEventPopUpButton selectedItem] tag] == 0
		? [_messagesEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCMessagesEventSound];
	
	[WCSettings setObject:[[_newsEventPopUpButton selectedItem] tag] == 0
		? [_newsEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCNewsEventSound];
	
	[WCSettings setObject:[[_broadcastEventPopUpButton selectedItem] tag] == 0
		? [_broadcastEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCBroadcastEventSound];
	
	[WCSettings setObject:[[_transferStartedEventPopUpButton selectedItem] tag] == 0
		? [_transferStartedEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCTransferStartedEventSound];
	
	[WCSettings setObject:[[_transferDoneEventPopUpButton selectedItem] tag] == 0
		? [_transferDoneEventPopUpButton titleOfSelectedItem]
		: @""
				   forKey:WCTransferDoneEventSound];
	
	// --- broadcast preferences change
	[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChange object:NULL];
	
	return YES;
}



- (void)iconsShouldReload:(NSNotification *)notification {
	[_iconMatrix updateIcons];
}


- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if(returnCode == NSOKButton)
		[_downloadFolderTextField setStringValue:[[openPanel filenames] objectAtIndex:0]];
}



- (void)wordsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	// --- close sheet
	[_highlightWordsPanel close];
}



- (void)bookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSMutableArray			*bookmarks;
	NSMutableDictionary		*bookmark;
	NSNumber				*row = (NSNumber *) contextInfo;
	
	if(returnCode == NSRunStoppedResponse) {
		// --- create mutable bookmarks
		bookmarks = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];

		if(row) {
			// --- get bookmark
			bookmark = [NSMutableDictionary dictionaryWithDictionary:
				[bookmarks objectAtIndex:[row intValue]]];
			
			// --- update fields
			[bookmark setObject:[_bookmarkNameTextField stringValue]
						 forKey:WCBookmarksName];
			[bookmark setObject:[_bookmarkAddressTextField stringValue]
						 forKey:WCBookmarksAddress];
			[bookmark setObject:[_bookmarkLoginTextField stringValue]
						 forKey:WCBookmarksLogin];
			[bookmark setObject:[_bookmarkPasswordTextField stringValue]
						 forKey:WCBookmarksPassword];
			
			// --- replace in bookmarks
			[bookmarks replaceObjectAtIndex:[row intValue]
								 withObject:[NSDictionary dictionaryWithDictionary:bookmark]];
			
			[row release];
		} else {
			// --- create bookmark
			bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
				[_bookmarkNameTextField stringValue],		WCBookmarksName,
				[_bookmarkAddressTextField stringValue],	WCBookmarksAddress,
				[_bookmarkLoginTextField stringValue],		WCBookmarksLogin,
				[_bookmarkPasswordTextField stringValue],   WCBookmarksPassword,
				NULL];
			
			// --- add to bookmarks
			[bookmarks addObject:bookmark];
		}

		// --- set new bookmarks
		[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
		
		// --- reload
		[_bookmarkTableView reloadData];
		
		// --- reflect change in the menu
		[WCSharedMain updateBookmarksMenu];
	}

	// --- close sheet
	[_bookmarkPanel close];
	
	// --- clear for next round
	[_bookmarkNameTextField setStringValue:@""];
	[_bookmarkAddressTextField setStringValue:@""];
	[_bookmarkLoginTextField setStringValue:@""];
	[_bookmarkPasswordTextField setStringValue:@""];
}
	



- (void)trackerSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSMutableArray			*trackers;
	NSMutableDictionary		*tracker;
	NSNumber				*row = (NSNumber *) contextInfo;
	
	if(returnCode == NSRunStoppedResponse) {
		// --- create mutable trackers
		trackers = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCTrackerBookmarks]];
		
		if(row) {
			// --- get tracker
			tracker = [NSMutableDictionary dictionaryWithDictionary:
				[trackers objectAtIndex:[row intValue]]];
			
			// --- update fields
			[tracker setObject:[_trackerNameTextField stringValue]
						forKey:WCTrackerBookmarksName];
			[tracker setObject:[_trackerAddressTextField stringValue]
						forKey:WCTrackerBookmarksAddress];
			
			// --- replace in trackers
			[trackers replaceObjectAtIndex:[row intValue]
								withObject:[NSDictionary dictionaryWithDictionary:tracker]];
			
			[row release];
		} else {
			// --- create tracker
			tracker = [NSDictionary dictionaryWithObjectsAndKeys:
				[_trackerNameTextField stringValue],		WCTrackerBookmarksName,
				[_trackerAddressTextField stringValue],		WCTrackerBookmarksAddress,
				NULL];
			
			// --- add to trackers
			[trackers addObject:tracker];
		}
		
		// --- set new trackers
		[WCSettings setObject:[NSArray arrayWithArray:trackers] forKey:WCTrackerBookmarks];
		
		// --- reflect change in the trackers
		[[WCSharedMain trackers] updateTrackers];
		
		// --- reload
		[_trackerTableView reloadData];
	}
	
	// --- close sheet
	[_trackerPanel close];
	
	// --- clear for next round
	[_trackerNameTextField setStringValue:@""];
	[_trackerAddressTextField setStringValue:@""];
}



- (void)ignoreSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSMutableArray			*ignores;
	NSMutableDictionary		*ignore;
	NSNumber				*row = (NSNumber *) contextInfo;
	
	if(returnCode == NSRunStoppedResponse) {
		// --- create mutable ignores
		ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnores]];
		
		if(row) {
			// --- get ignore
			ignore = [NSMutableDictionary dictionaryWithDictionary:
				[ignores objectAtIndex:[row intValue]]];
			
			// --- update fields
			[ignore setObject:[_ignoreNickTextField stringValue] forKey:WCIgnoresNick];
			[ignore setObject:[_ignoreLoginTextField stringValue] forKey:WCIgnoresLogin];
			[ignore setObject:[_ignoreAddressTextField stringValue] forKey:WCIgnoresAddress];
			
			// --- replace in ignores
			[ignores replaceObjectAtIndex:[row intValue]
							   withObject:[NSDictionary dictionaryWithDictionary:ignore]];
			
			[row release];
		} else {
			// --- create ignore
			ignore = [NSDictionary dictionaryWithObjectsAndKeys:
				[_ignoreNickTextField stringValue],			WCIgnoresNick,
				[_ignoreLoginTextField stringValue],		WCIgnoresLogin,
				[_ignoreAddressTextField stringValue],		WCIgnoresAddress,
				NULL];
			
			// --- add to ignores
			[ignores addObject:ignore];
		}
		
		// --- set new ignores
		[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnores];
		
		// --- reload
		[_ignoreTableView reloadData];
	}
	
	// --- close sheet
	[_ignorePanel close];
	
	// --- clear for next round
	[_ignoreNickTextField setStringValue:@""];
	[_ignoreLoginTextField setStringValue:@""];
	[_ignoreAddressTextField setStringValue:@""];
}



#pragma mark -

- (IBAction)showWindow:(id)sender {
	// --- set title
	[[self window] setTitle:[[_preferencesTabView selectedTabViewItem] label]];

	// --- show the window
	[super showWindow:self];
}



- (void)selectTab:(NSString *)identifier {
	NSTabViewItem   *item;
	NSBox			*box;
	NSRect			rect;
	int				i, toolbar = 0;
	
	// --- get toolbar height
	if([[[self window] toolbar] isVisible]) {
		rect = [NSWindow contentRectForFrameRect:[[self window] frame]
									   styleMask:[[self window] styleMask]];
		toolbar = rect.size.height - [[[self window] contentView] frame].size.height;
	}
	
	// --- get tab
	i		= [_preferencesTabView indexOfTabViewItemWithIdentifier:identifier];
	item	= [_preferencesTabView tabViewItemAtIndex:i];
	box		= [[[item view] subviews] objectAtIndex:0];
	
	// --- figure out new window frame
	rect = [NSWindow frameRectForContentRect:[box frame] styleMask:[[self window] styleMask]];
	rect.origin = [[self window] frame].origin;
	rect.size.height += toolbar;
	rect.origin.y -= (rect.size.height - [[self window] frame].size.height);
	
	// --- move content far, far away
	[box setFrameOrigin:NSMakePoint(10000, 0)];
	[box setNeedsDisplay:YES];

	// --- select tab
	[_preferencesTabView selectTabViewItem:item];
	[[self window] setFrame:rect display:YES animate:YES];
	
	// --- move content back into place
	[box setFrameOrigin:NSMakePoint(0, 0)];
	[box setNeedsDisplay:YES];
}




#pragma mark -

- (IBAction)showFontPanel:(id)sender {
	NSFontManager		*fontManager;
	
	fontManager = [NSFontManager sharedFontManager];
	
	if([[sender alternateTitle] isEqualToString:WCTextFont])
		[fontManager setAction:@selector(changeTextFont:)];
	else if([[sender alternateTitle] isEqualToString:WCNewsFont])
		[fontManager setAction:@selector(changeNewsFont:)];
	
	[fontManager setSelectedFont:[WCSettings archivedObjectForKey:[sender alternateTitle]] 
					  isMultiple:NO];
	[fontManager orderFrontFontPanel:self];
}



- (void)changeTextFont:(id)sender {
	NSFont			*font;
	
	font				= [WCSettings archivedObjectForKey:WCTextFont];
	_currentTextFont	= [sender convertFont:font];
	
	[_fontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentTextFont displayName], [_currentTextFont pointSize]]];
}



- (void)changeNewsFont:(id)sender {
	NSFont			*font;
	
	font				= [WCSettings archivedObjectForKey:WCNewsFont];
	_currentNewsFont	= [sender convertFont:font];
	
	[_newsFontTextField setStringValue:[NSString stringWithFormat:
		@"%@ %.1fpt", [_currentNewsFont displayName], [_currentNewsFont pointSize]]];
}



- (IBAction)setIcon:(id)sender {
	NSBitmapImageRep  *imageRep;
	NSImage				*image, *icon = NULL;
	NSData				*data;
	NSString			*string;
	NSSize				size;
	
	// --- get image
	image = [_iconImageView image];
	
	// --- set scaling
	if([image size].width <= 32 && [image size].height <= 32)
		size = [image size];
	else if([image size].width >= 32 && [image size].height <= 32)
		size = NSMakeSize(32, [image size].height);
	else if([image size].width <= 32 && [image size].height >= 32)
		size = NSMakeSize([image size].height, 32);
	else if([image size].width > [image size].height)
		size = NSMakeSize(32, 32 * ([image size].width / [image size].height));
	else
		size = NSMakeSize(32 * ([image size].width / [image size].height), 32);
	
	if(!NSEqualSizes([image size], size)) {
		// --- create new image
		icon = [[NSImage alloc] initWithSize:size];
		[icon lockFocus];
		[image setSize:size];
		[image drawAtPoint:NSZeroPoint
				  fromRect:NSMakeRect(0, 0, size.width, size.height)
				 operation:NSCompositeCopy
				  fraction:1.0];
		[icon unlockFocus];
		
		// --- set new image
		[_iconImageView setImage:icon];
		[icon release];
	}
	
	// --- get image
	image = [_iconImageView image];
	
	// --- create PNG
	imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	data = [imageRep representationUsingType:NSPNGFileType properties:NULL];	
	string = [data base64EncodedString];
	
	// --- set in prefs
	[WCSettings setObject:string forKey:WCCustomIcon];

	// --- broadcast change immediately
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange object:NULL];
}



- (IBAction)clearIcon:(id)sender {
	// --- set image
	[_iconImageView setImage:NULL];
	
	// --- set in prefs
	[WCSettings setObject:@"" forKey:WCCustomIcon];
	
	// --- broadcast change immediately
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange object:NULL];
}



- (IBAction)useOldIcon:(id)sender {
	NSImage		*image;
	
	// --- disable interpolation
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	// --- set icon from set
	image = [WCIcons objectForKey:[NSNumber numberWithInt:[[_iconMatrix selectedCell] tag]]];
	[_iconImageView setImage:image];
	
	// --- trigger update
	[self setIcon:sender];	
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

- (IBAction)showWordsSheet:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_highlightWordsPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(wordsSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}	



- (IBAction)addWord:(id)sender {
	NSMutableArray		*words;
	
	// --- add empty string
	words = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCHighlightWordsWords]];
	[words addObject:@""];
	[WCSettings setObject:[NSArray arrayWithArray:words] forKey:WCHighlightWordsWords];
	
	// --- reload table
	[_highlightWordsTableView reloadData];
	
	// --- edit new string
	[_highlightWordsTableView selectRow:[words count] - 1 byExtendingSelection:NO];
	[_highlightWordsTableView editColumn:
		[[_highlightWordsTableView tableColumns] indexOfObject:_highlightWordsWordTableColumn]
									 row:[words count] - 1
							   withEvent:NULL
								  select:YES];
}



- (IBAction)deleteWord:(id)sender {
	NSMutableArray		*words;
	int					row;
	
	row = [_highlightWordsTableView selectedRow];

	words = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCHighlightWordsWords]];
	[words removeObjectAtIndex:row];
	[WCSettings setObject:[NSArray arrayWithArray:words] forKey:WCHighlightWordsWords];
	
	[_highlightWordsTableView reloadData];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_bookmarkPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(bookmarkSheetDidEnd:returnCode:contextInfo:)
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
	[_bookmarkNameTextField setStringValue:[bookmark objectForKey:WCBookmarksName]];
	[_bookmarkAddressTextField setStringValue:[bookmark objectForKey:WCBookmarksAddress]];
	[_bookmarkLoginTextField setStringValue:[bookmark objectForKey:WCBookmarksLogin]];
	[_bookmarkPasswordTextField setStringValue:[bookmark objectForKey:WCBookmarksPassword]];
	
	// --- show sheet
	[NSApp beginSheet:_bookmarkPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(bookmarkSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSNumber alloc] initWithInt:row]];
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
	
	// --- reflect change in the menu
	[WCSharedMain updateBookmarksMenu];
}



#pragma mark -

- (IBAction)addTracker:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_trackerPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(trackerSheetDidEnd:returnCode:contextInfo:)
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
	[_trackerNameTextField setStringValue:[tracker objectForKey:WCTrackerBookmarksName]];
	[_trackerAddressTextField setStringValue:[tracker objectForKey:WCTrackerBookmarksAddress]];
	
	// --- show sheet
	[NSApp beginSheet:_trackerPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(trackerSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSNumber alloc] initWithInt:row]];
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
	
	// --- reflect change in the menu
	[[WCSharedMain trackers] updateTrackers];
}



#pragma mark -

- (IBAction)addIgnore:(id)sender {
	// --- show sheet
	[NSApp beginSheet:_ignorePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(ignoreSheetDidEnd:returnCode:contextInfo:)
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
	ignore = [[WCSettings objectForKey:WCIgnores] objectAtIndex:row];
	
	// --- fill out fields
	[_ignoreNickTextField setStringValue:[ignore objectForKey:WCIgnoresNick]];
	[_ignoreLoginTextField setStringValue:[ignore objectForKey:WCIgnoresLogin]];
	[_ignoreAddressTextField setStringValue:[ignore objectForKey:WCIgnoresAddress]];
	
	// --- show sheet
	[NSApp beginSheet:_ignorePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(ignoreSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSNumber alloc] initWithInt:row]];
}



- (IBAction)deleteIgnore:(id)sender {
	NSMutableArray	*ignores;
	int				row;
	
	// --- get row
	row = [_ignoreTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- delete
	ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnores]];
	[ignores removeObjectAtIndex:row];
	
	// --- set new
	[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnores];
	
	// --- reload
	[_ignoreTableView reloadData];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == _highlightWordsTableView)
		return [[WCSettings objectForKey:WCHighlightWordsWords] count];
	else if(tableView == _bookmarkTableView)
		return [[WCSettings objectForKey:WCBookmarks] count];
	else if(tableView == _trackerTableView)
		return [[WCSettings objectForKey:WCTrackerBookmarks] count];
	else if(tableView == _ignoreTableView)
		return [[WCSettings objectForKey:WCIgnores] count];
	
	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	if(tableView == _highlightWordsTableView) {
		if(column == _highlightWordsWordTableColumn)
			return [[WCSettings objectForKey:WCHighlightWordsWords] objectAtIndex:row];
	}
	else if(tableView == _bookmarkTableView) {
		NSDictionary	*bookmark;
	
		// --- get bookmark
		bookmark = [[WCSettings objectForKey:WCBookmarks] objectAtIndex:row];

		if(column == _bookmarkNameTableColumn)
			return [bookmark objectForKey:WCBookmarksName];
		else if(column == _bookmarkAddressTableColumn)
			return [bookmark objectForKey:WCBookmarksAddress];
		else if(column == _bookmarkLoginTableColumn)
			return [bookmark objectForKey:WCBookmarksLogin];
	}
	else if(tableView == _trackerTableView) {
		NSDictionary	*tracker;
	
		// --- get tracker
		tracker = [[WCSettings objectForKey:WCTrackerBookmarks] objectAtIndex:row];

		if(column == _trackerNameTableColumn)
			return [tracker objectForKey:WCTrackerBookmarksName];
		else if(column == _trackerAddressTableColumn)
			return [tracker objectForKey:WCTrackerBookmarksAddress];
	}
	else if(tableView == _ignoreTableView) {
		NSDictionary	*ignore;
	
		// --- get tracker
		ignore = [[WCSettings objectForKey:WCIgnores] objectAtIndex:row];

		if(column == _ignoreNickTableColumn)
			return [ignore objectForKey:WCIgnoresNick];
		else if(column == _ignoreLoginTableColumn)
			return [ignore objectForKey:WCIgnoresLogin];
		else if(column == _ignoreAddressTableColumn)
			return [ignore objectForKey:WCIgnoresAddress];
	}

	return NULL;
}



- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSMutableArray		*words;
	
	if(tableView == _highlightWordsTableView) {
		if(tableColumn == _highlightWordsWordTableColumn) {
			words = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCHighlightWordsWords]];
			[words replaceObjectAtIndex:row withObject:object];
			[WCSettings setObject:[NSArray arrayWithArray:words] forKey:WCHighlightWordsWords];
		}
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSTableView		*tableView;
	int				row;
	
	tableView = [notification object];
	row = [tableView selectedRow];
	
	if(tableView == _highlightWordsTableView)
		[_highlightWordsDeleteButton setEnabled:(row >= 0)];
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
		
		// --- reload menu
		[WCSharedMain updateBookmarksMenu];

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
		ignores		= [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnores]];
		ignore		= [[ignores objectAtIndex:fromRow] retain];
		
		// --- remove object and insert object at new row, which is one lower if the row
		//     is below the removed row
		toRow = row < fromRow ? row : row - 1;
		[ignores removeObjectAtIndex:fromRow];
		[ignores insertObject:ignore atIndex:toRow];
		[ignore release];
		
		// --- set new bookmarks
		[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnores];
	
		// --- reload table
		[_ignoreTableView reloadData];

		return YES;
	}
	
	return NO;
}

@end
