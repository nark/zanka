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

#import "WCKeychain.h"
#import "WCPreferences.h"
#import "WCTrackers.h"

#define WCBookmarksPasswordMagic		@"869815172a9e5882c46ee2e2c084f29d2aa7e890"


@interface WCPreferences(Private)

- (void)_addTouchActionsToSubviewsInView:(NSView *)view;

- (void)_validate;

- (NSToolbar *)_toolbar;

- (void)_reloadEvents;
- (void)_selectTab:(NSString *)identifier;
- (void)_selectTabViewItem:(NSTabViewItem *)item;

- (void)_loadSettings;
- (void)_saveSettings;

- (void)_selectBookmark;
- (void)_unselectBookmark;
- (void)_selectEvent;
- (void)_touchEvents;
- (void)_selectTrackerBookmark;
- (void)_unselectTrackerBookmark;

@end


@implementation WCPreferences(Private)

- (void)_addTouchActionsToSubviewsInView:(NSView *)view {
	NSEnumerator	*enumerator, *tabViewEnumerator;
	NSTabViewItem	*tabViewItem;
	id				subview;
	
	enumerator = [[view subviews] objectEnumerator];
	
	while((subview = [enumerator nextObject])) {
		if([subview isKindOfClass:[NSTabView class]]) {
			tabViewEnumerator = [[subview tabViewItems] objectEnumerator];
			
			while((tabViewItem = [tabViewEnumerator nextObject])) {
				[self _addTouchActionsToSubviewsInView:[tabViewItem view]];
			}
		} else {
			if([subview isKindOfClass:[NSControl class]]) {
				if(![subview target]) {
					[subview setTarget:self];
					[subview setAction:@selector(touch:)];
				}
			}
			
			[self _addTouchActionsToSubviewsInView:subview];
		}
	}
}



#pragma mark -

- (void)_validate {
	[_deleteBookmarkButton setEnabled:([_bookmarksTableView selectedRow] >= 0)];
	[_deleteHiglightButton setEnabled:([_highlightsTableView selectedRow] >= 0)];
	[_deleteIgnoreButton setEnabled:([_ignoresTableView selectedRow] >= 0)];
	[_deleteTrackerBookmarkButton setEnabled:([_trackerBookmarksTableView selectedRow] >= 0)];
}



#pragma mark -

- (NSToolbar *)_toolbar {
	NSToolbar		*toolbar;
	NSToolbarItem	*item;

	_toolbarItems = [[NSMutableDictionary alloc] init];
	
	// --- general
	item = [NSToolbarItem toolbarItemWithIdentifier:@"General"
											   name:NSLS(@"General", @"General toolbar item")
											content:[NSImage imageNamed:@"General"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- interface
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Interface"
											   name:NSLS(@"Interface", @"Interface toolbar item")
											content:[NSImage imageNamed:@"Interface"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- bookmarks
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Bookmarks"
											   name:NSLS(@"Bookmarks", @"Bookmarks toolbar item")
											content:[NSImage imageNamed:@"Bookmarks"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- general
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Sounds"
											   name:NSLS(@"Sounds", @"Bookmarks toolbar item")
											content:[NSImage imageNamed:@"Sounds"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- chat
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Chat"
											   name:NSLS(@"Chat", @"Chat toolbar item")
											content:[NSImage imageNamed:@"Chat"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];
	
	// --- events
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Events"
											   name:NSLS(@"Events", @"Events toolbar item")
											content:[NSImage imageNamed:@"Events"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];
	
	// --- files
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Files"
											   name:NSLS(@"Files", @"Files toolbar item")
											content:[NSImage imageNamed:@"Folder"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- trackers
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Trackers"
											   name:NSLS(@"Trackers", @"Trackers toolbar item")
											content:[NSImage imageNamed:@"Trackers"]
											 target:self
											 action:@selector(selectToolbarItem:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	toolbar = [[NSToolbar alloc] initWithIdentifier:WCPreferencesToolbar];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];

	return [toolbar autorelease];
}



#pragma mark -

- (void)_reloadEvents {
	NSMutableDictionary		*events, *defaultEvents;
	NSEnumerator			*enumerator;
	NSDictionary			*event;
	NSMenuItem				*item;
	NSNumber				*tag;
	
	[_eventsPopUpButton removeAllItems];
	
	enumerator = [[[WCSettings settings] objectForKey:WCEvents] objectEnumerator];
	events = [NSMutableDictionary dictionary];
	
	while((event = [enumerator nextObject]))
		[events setObject:event forKey:[event objectForKey:WCEventsEvent]];

	enumerator = [[[[WCSettings settings] defaults] objectForKey:WCEvents] objectEnumerator];
	defaultEvents = [NSMutableDictionary dictionary];
	
	while((event = [enumerator nextObject]))
		[defaultEvents setObject:event forKey:[event objectForKey:WCEventsEvent]];

	enumerator = [[NSArray arrayWithObjects:
		[NSNumber numberWithInt:WCEventsServerConnected],
		[NSNumber numberWithInt:WCEventsServerDisconnected],
		[NSNumber numberWithInt:WCEventsError],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:WCEventsUserJoined],
		[NSNumber numberWithInt:WCEventsUserChangedNick],
		[NSNumber numberWithInt:WCEventsUserChangedStatus],
		[NSNumber numberWithInt:WCEventsUserLeft],
		[NSNumber numberWithInt:WCEventsChatReceived],
		[NSNumber numberWithInt:WCEventsHighlightedChatReceived],
		[NSNumber numberWithInt:WCEventsChatInvitationReceived],
		[NSNumber numberWithInt:WCEventsMessageReceived],
		[NSNumber numberWithInt:WCEventsNewsPosted],
		[NSNumber numberWithInt:WCEventsBroadcastReceived],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:WCEventsTransferStarted],
		[NSNumber numberWithInt:WCEventsTransferFinished],
		NULL] objectEnumerator];
	
	while((tag = [enumerator nextObject])) {
		if([tag intValue] == 0) {
			[[_eventsPopUpButton menu] addItem:[NSMenuItem separatorItem]];
		} else {
			event = [events objectForKey:tag];
			
			if(!event) {
				event = [defaultEvents objectForKey:tag];
				[events setObject:event forKey:tag];
			}

			item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
			[item setTag:[tag intValue]];
			
			switch([item tag]) {
				case WCEventsServerConnected:
					[item setTitle:NSLS(@"Server Connected", @"Event")];
					break;

				case WCEventsServerDisconnected:
					[item setTitle:NSLS(@"Server Disconnected", @"Event")];
					break;

				case WCEventsError:
					[item setTitle:NSLS(@"Error", @"Event")];
					break;

				case WCEventsUserJoined:
					[item setTitle:NSLS(@"User Joined", @"Event")];
					break;

				case WCEventsUserChangedNick:
					[item setTitle:NSLS(@"User Changed Nick", @"Event")];
					break;

				case WCEventsUserChangedStatus:
					[item setTitle:NSLS(@"User Changed Status", @"Event")];
					break;

				case WCEventsUserLeft:
					[item setTitle:NSLS(@"User Left", @"Event")];
					break;

				case WCEventsChatReceived:
					[item setTitle:NSLS(@"Chat Received", @"Event")];
					break;

				case WCEventsHighlightedChatReceived:
					[item setTitle:NSLS(@"Highlighted Chat Received", @"Event")];
					break;

				case WCEventsChatInvitationReceived:
					[item setTitle:NSLS(@"Private Chat Invitation Received", @"Event")];
					break;
					
				case WCEventsMessageReceived:
					[item setTitle:NSLS(@"Message Received", @"Event")];
					break;

				case WCEventsNewsPosted:
					[item setTitle:NSLS(@"News Posted", @"Event")];
					break;

				case WCEventsBroadcastReceived:
					[item setTitle:NSLS(@"Broadcast Received", @"Event")];
					break;

				case WCEventsTransferStarted:
					[item setTitle:NSLS(@"Transfer Started", @"Event")];
					break;

				case WCEventsTransferFinished:
					[item setTitle:NSLS(@"Transfer Finished", @"Event")];
					break;
			}
			
			if([event boolForKey:WCEventsPlaySound]  || [event boolForKey:WCEventsBounceInDock] ||
			   [event boolForKey:WCEventsPostInChat] || [event boolForKey:WCEventsShowDialog])
				[item setImage:[NSImage imageNamed:@"EventOn"]];
			else
				[item setImage:[NSImage imageNamed:@"EventOff"]];
			
			[[_eventsPopUpButton menu] addItem:item];
			[item release];
		}
	}
	
	[[WCSettings settings] setObject:[events allValues] forKey:WCEvents];
}



- (void)_selectTab:(NSString *)identifier {
	NSTabViewItem   *item;

	item = [_preferencesTabView tabViewItemWithIdentifier:identifier];
	
	if(item) {
		[self _selectTabViewItem:item];
		
		[[[self window] toolbar] setSelectedItemIdentifier:identifier];
	}
}



- (void)_selectTabViewItem:(NSTabViewItem *)item {
	NSBox		*box;
	NSRect		rect;

	if(_selectedTabViewItem != item) {
		if([[_selectedTabViewItem identifier] isEqualToString:@"Bookmarks"])
			[self _unselectBookmark];
		else if([[_selectedTabViewItem identifier] isEqualToString:@"Trackers"])
			[self _unselectTrackerBookmark];
		
		box = [[[item view] subviews] objectAtIndex:0];
		rect = [[self window] frameRectForContentRect:[box frame]];
		rect.origin = [[self window] frame].origin;
		rect.origin.y -= rect.size.height - [[self window] frame].size.height;

		[box setFrameOrigin:NSMakePoint(10000.0, 0.0)];
		[box setNeedsDisplay:YES];

		[_preferencesTabView selectTabViewItem:item];
		[[self window] setFrame:rect display:YES animate:YES];

		[box setFrameOrigin:NSZeroPoint];
		[box setNeedsDisplay:YES];

		[[self window] setTitle:[item label]];

		_selectedTabViewItem = item;
	}
}



#pragma mark -

- (void)_loadSettings {
	// --- general
	[_nickTextField setStringValue:[[WCSettings settings] objectForKey:WCNick]];
	[_statusTextField setStringValue:[[WCSettings settings] objectForKey:WCStatus]];
	[_iconImageView setImage:[NSImage imageWithData:
		[NSData dataWithBase64EncodedString:[[WCSettings settings] objectForKey:WCCustomIcon]]]];
	
	[_showConnectAtStartupButton setState:[[WCSettings settings] boolForKey:WCShowConnectAtStartup]];
	[_showDockAtStartupButton setState:[[WCSettings settings] boolForKey:WCShowDockAtStartup]];
	[_showTrackersAtStartupButton setState:[[WCSettings settings] boolForKey:WCShowTrackersAtStartup]];

	[_autoHideOnSwitchButton setState:[[WCSettings settings] boolForKey:WCAutoHideOnSwitch]];
	[_preventMultipleConnectionsButton setState:[[WCSettings settings] boolForKey:WCPreventMultipleConnections]];
	[_confirmDisconnectButton setState:[[WCSettings settings] boolForKey:WCConfirmDisconnect]];
	[_autoReconnectButton setState:[[WCSettings settings] boolForKey:WCAutoReconnect]];
	
	// --- interface/chat
	[_chatTextColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatTextColor]]];
	[_chatBackgroundColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatBackgroundColor]]];
	[_chatURLsColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatURLsColor]]];
	[_chatEventsColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatEventsColor]]];
	[_chatFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatFont]] displayNameWithSize]];
	[_chatUserListFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatUserListFont]] displayNameWithSize]];
	[_chatUserListIconSizeMatrix selectCellWithTag:[[WCSettings settings] intForKey:WCChatUserListIconSize]];
	[_chatUserListAlternateRowsButton setState:[[WCSettings settings] boolForKey:WCChatUserListAlternateRows]];

	// --- interface/messages
	[_messagesTextColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_messagesBackgroundColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesBackgroundColor]]];
	[_messagesFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]] displayNameWithSize]];
	[_messagesListFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesListFont]] displayNameWithSize]];
	[_messagesListAlternateRowsButton setState:[[WCSettings settings] boolForKey:WCMessagesListAlternateRows]];
	
	// --- interface/news
	[_newsTextColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTextColor]]];
	[_newsTitlesColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTitlesColor]]];
	[_newsBackgroundColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsBackgroundColor]]];
	[_newsFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]] displayNameWithSize]];

	// --- interface/files
	[_filesFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCFilesFont]] displayNameWithSize]];
	[_filesAlternateRowsButton setState:[[WCSettings settings] boolForKey:WCFilesAlternateRows]];

	// --- interface/transfers
	[_transfersShowProgressBarButton setState:[[WCSettings settings] boolForKey:WCTransfersShowProgressBar]];
	[_transfersAlternateRowsButton setState:[[WCSettings settings] boolForKey:WCTransfersAlternateRows]];

	// --- interface/preview
	[_previewTextColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCPreviewTextColor]]];
	[_previewBackgroundColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCPreviewBackgroundColor]]];
	[_previewFontTextField setStringValue:[[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCPreviewFont]] displayNameWithSize]];
	
	// --- interface/trackers
	[_trackersAlternateRowsButton setState:[[WCSettings settings] boolForKey:WCTrackersAlternateRows]];

	// --- bookmarks
	[_bookmarksNickTextField setPlaceholderString:[_nickTextField stringValue]];
	[_bookmarksStatusTextField setPlaceholderString:[_statusTextField stringValue]];
	[self _selectBookmark];
	[_bookmarksTableView reloadData];
	
	// --- chat
	[_chatStyleMatrix selectCellWithTag:[[WCSettings settings] intForKey:WCChatStyle]];
	[_historyScrollbackButton setState:[[WCSettings settings] boolForKey:WCHistoryScrollback]];
	[_historyScrollbackModifierPopUpButton selectItemWithTag:
		[[WCSettings settings] intForKey:WCHistoryScrollbackModifier]];
	[_tabCompleteNicksButton setState:[[WCSettings settings] boolForKey:WCTabCompleteNicks]];
	[_tabCompleteNicksTextField setStringValue:[[WCSettings settings] objectForKey:WCTabCompleteNicksString]];
	[_timestampChatButton setState:[[WCSettings settings] boolForKey:WCTimestampChat]];
	[_timestampChatIntervalTextField setStringValue:[NSSWF:@"%.0f",
		[[WCSettings settings] doubleForKey:WCTimestampChatInterval] / 60.0]];
	[_timestampEveryLineButton setState:[[WCSettings settings] boolForKey:WCTimestampEveryLine]];
	[_timestampEveryLineColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCTimestampEveryLineColor]]];
	[_showSmileysButton setState:[[WCSettings settings] boolForKey:WCShowSmileys]];
	
	[_highlightsTableView reloadData];
	[_ignoresTableView reloadData];

	// --- events
	[self _selectEvent];
	
	// --- files
	[_downloadFolderTextField setStringValue:[[[WCSettings settings] objectForKey:WCDownloadFolder] stringByAbbreviatingWithTildeInPath]];
	[_openFoldersInNewWindowsButton setState:[[WCSettings settings] boolForKey:WCOpenFoldersInNewWindows]];
	[_queueTransfersButton setState:[[WCSettings settings] boolForKey:WCQueueTransfers]];
	[_encryptTransfersButton setState:[[WCSettings settings] boolForKey:WCEncryptTransfers]];
	[_checkForResourceForksButton setState:[[WCSettings settings] boolForKey:WCCheckForResourceForks]];
	[_removeTransfersButton setState:[[WCSettings settings] boolForKey:WCRemoveTransfers]];
	
	// --- trackers
	[self _selectTrackerBookmark];
	[_trackerBookmarksTableView reloadData];
	
	[self _validate];
}



- (void)_saveSettings {
	NSMutableDictionary	*event;
	NSImage				*image;
	NSString			*string;
	NSData				*data;
	NSInteger			tag;

	// --- general
	if(![[_nickTextField stringValue] isEqualToString:[[WCSettings settings] objectForKey:WCNick]]) {
		[[WCSettings settings] setObject:[_nickTextField stringValue] forKey:WCNick];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCNickDidChange];
	}
	
	if(![[_statusTextField stringValue] isEqualToString:[[WCSettings settings] objectForKey:WCStatus]]) {
		[[WCSettings settings] setObject:[_statusTextField stringValue] forKey:WCStatus];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCStatusDidChange];
	}
	
	image = [_iconImageView image];
	
	if(image) {
		data	= [[NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]] representationUsingType:NSPNGFileType properties:NULL];
		string	= [data base64EncodedString];
		
		if(!string)
			string = @"";
	} else {
		string	= @"";
	}
	
	if(![string isEqualToString:[[WCSettings settings] objectForKey:WCCustomIcon]]) {
		[[WCSettings settings] setObject:string forKey:WCCustomIcon];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange];
	}
	
	[[WCSettings settings] setBool:[_showConnectAtStartupButton state] forKey:WCShowConnectAtStartup];
	[[WCSettings settings] setBool:[_showDockAtStartupButton state] forKey:WCShowDockAtStartup];
	[[WCSettings settings] setBool:[_showTrackersAtStartupButton state] forKey:WCShowTrackersAtStartup];

	[[WCSettings settings] setBool:[_autoHideOnSwitchButton state] forKey:WCAutoHideOnSwitch];
	[[WCSettings settings] setBool:[_preventMultipleConnectionsButton state] forKey:WCPreventMultipleConnections];
	[[WCSettings settings] setBool:[_confirmDisconnectButton state] forKey:WCConfirmDisconnect];
	[[WCSettings settings] setBool:[_autoReconnectButton state] forKey:WCAutoReconnect];
	
	// --- interface/chat
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_chatTextColorWell color]] forKey:WCChatTextColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_chatBackgroundColorWell color]] forKey:WCChatBackgroundColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_chatURLsColorWell color]] forKey:WCChatURLsColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_chatEventsColorWell color]] forKey:WCChatEventsColor];
	[[WCSettings settings] setInt:[[_chatUserListIconSizeMatrix selectedCell] tag] forKey:WCChatUserListIconSize];
	[[WCSettings settings] setBool:[_chatUserListAlternateRowsButton state] forKey:WCChatUserListAlternateRows];

	// --- interface/messages
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_messagesTextColorWell color]] forKey:WCMessagesTextColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_messagesBackgroundColorWell color]] forKey:WCMessagesBackgroundColor];
	[[WCSettings settings] setBool:[_messagesListAlternateRowsButton state] forKey:WCMessagesListAlternateRows];
	
	// --- interface/news
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_newsTextColorWell color]] forKey:WCNewsTextColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_newsTitlesColorWell color]] forKey:WCNewsTitlesColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_newsBackgroundColorWell color]] forKey:WCNewsBackgroundColor];

	// --- interface/files
	[[WCSettings settings] setBool:[_filesAlternateRowsButton state] forKey:WCFilesAlternateRows];

	// --- interface/transfers
	[[WCSettings settings] setBool:[_transfersShowProgressBarButton state] forKey:WCTransfersShowProgressBar];
	[[WCSettings settings] setBool:[_transfersAlternateRowsButton state] forKey:WCTransfersAlternateRows];

	// --- interface/trackers
	[[WCSettings settings] setBool:[_trackersAlternateRowsButton state] forKey:WCTrackersAlternateRows];

	// --- interface/preview
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_previewTextColorWell color]] forKey:WCPreviewTextColor];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_previewBackgroundColorWell color]] forKey:WCPreviewBackgroundColor];

	// --- chat
	[[WCSettings settings] setInt:[[_chatStyleMatrix selectedCell] tag] forKey:WCChatStyle];
	[[WCSettings settings] setBool:[_historyScrollbackButton state] forKey:WCHistoryScrollback];
	[[WCSettings settings] setInt:[[_historyScrollbackModifierPopUpButton selectedItem] tag]
				forKey:WCHistoryScrollbackModifier];
	[[WCSettings settings] setBool:[_tabCompleteNicksButton state] forKey:WCTabCompleteNicks];
	[[WCSettings settings] setObject:[_tabCompleteNicksTextField stringValue] forKey:WCTabCompleteNicksString];
	[[WCSettings settings] setBool:[_timestampChatButton state] forKey:WCTimestampChat];
	[[WCSettings settings] setInt:[_timestampChatIntervalTextField intValue] * 60 forKey:WCTimestampChatInterval];
	[[WCSettings settings] setBool:[_timestampEveryLineButton state] forKey:WCTimestampEveryLine];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[_timestampEveryLineColorWell color]] forKey:WCTimestampEveryLineColor];
	[[WCSettings settings] setBool:[_showSmileysButton state] forKey:WCShowSmileys];
	
	// --- events
	tag = [_eventsPopUpButton tagOfSelectedItem];
	event = [[[WCSettings settings] eventForTag:tag] mutableCopy];
	[event setInt:tag forKey:WCEventsEvent];
	[event setBool:[_playSoundButton state] forKey:WCEventsPlaySound];
	
	string = [_soundsPopUpButton titleOfSelectedItem];
	
	if(string)
		[event setObject:string forKey:WCEventsSound];
	
	[event setBool:[_bounceInDockButton state] forKey:WCEventsBounceInDock];
	[event setBool:[_postInChatButton state] forKey:WCEventsPostInChat];
	[event setBool:[_showDialogButton state] forKey:WCEventsShowDialog];
	[[WCSettings settings] setEvent:event forTag:tag];
	[event release];

	// --- files
	[[WCSettings settings] setObject:[_downloadFolderTextField stringValue] forKey:WCDownloadFolder];
	[[WCSettings settings] setBool:[_openFoldersInNewWindowsButton state] forKey:WCOpenFoldersInNewWindows];
	[[WCSettings settings] setBool:[_queueTransfersButton state] forKey:WCQueueTransfers];
	[[WCSettings settings] setBool:[_encryptTransfersButton state] forKey:WCEncryptTransfers];
	[[WCSettings settings] setBool:[_checkForResourceForksButton state] forKey:WCCheckForResourceForks];
	[[WCSettings settings] setBool:[_removeTransfersButton state] forKey:WCRemoveTransfers];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChange object:self];
}



#pragma mark -

- (void)_selectBookmark {
	NSDictionary	*bookmark;
	NSInteger		row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row >= 0 && (NSUInteger) row < [[[WCSettings settings] objectForKey:WCBookmarks] count]) {
		bookmark = [[WCSettings settings] bookmarkAtIndex:row];
		
		[_bookmarksNameTextField setEnabled:YES];
		[_bookmarksAddressTextField setEnabled:YES];
		[_bookmarksLoginTextField setEnabled:YES];
		[_bookmarksPasswordTextField setEnabled:YES];
		[_bookmarksAutoConnectButton setEnabled:YES];
		[_bookmarksAutoReconnectButton setEnabled:YES];
		[_bookmarksNickTextField setEnabled:YES];
		[_bookmarksStatusTextField setEnabled:YES];

		[_bookmarksNameTextField setStringValue:[bookmark objectForKey:WCBookmarksName]];
		[_bookmarksAddressTextField setStringValue:[bookmark objectForKey:WCBookmarksAddress]];
		[_bookmarksLoginTextField setStringValue:[bookmark objectForKey:WCBookmarksLogin]];

		if([[_bookmarksAddressTextField stringValue] length] > 0 &&
		   [[[WCKeychain keychain] passwordForBookmark:bookmark] length] > 0)
			[_bookmarksPasswordTextField setStringValue:WCBookmarksPasswordMagic];
		else
			[_bookmarksPasswordTextField setStringValue:@""];
		
		[_bookmarksAutoConnectButton setState:[[bookmark objectForKey:WCBookmarksAutoConnect] boolValue]];
		[_bookmarksAutoReconnectButton setState:[[bookmark objectForKey:WCBookmarksAutoReconnect] boolValue]];
		[_bookmarksNickTextField setStringValue:[bookmark objectForKey:WCBookmarksNick]];
		[_bookmarksStatusTextField setStringValue:[bookmark objectForKey:WCBookmarksStatus]];
	} else {
		[_bookmarksNameTextField setEnabled:NO];
		[_bookmarksAddressTextField setEnabled:NO];
		[_bookmarksLoginTextField setEnabled:NO];
		[_bookmarksPasswordTextField setEnabled:NO];
		[_bookmarksAutoConnectButton setEnabled:NO];
		[_bookmarksAutoReconnectButton setEnabled:NO];
		[_bookmarksNickTextField setEnabled:NO];
		[_bookmarksStatusTextField setEnabled:NO];

		[_bookmarksNameTextField setStringValue:@""];
		[_bookmarksAddressTextField setStringValue:@""];
		[_bookmarksLoginTextField setStringValue:@""];
		[_bookmarksPasswordTextField setStringValue:@""];
		[_bookmarksAutoConnectButton setState:NSOffState];
		[_bookmarksAutoReconnectButton setState:NSOffState];
		[_bookmarksNickTextField setStringValue:@""];
		[_bookmarksStatusTextField setStringValue:@""];
	}
}



- (void)_unselectBookmark {
	NSMutableDictionary		*bookmark;
	NSDictionary			*oldBookmark;
	NSString				*password;
	NSInteger				row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0 || (NSUInteger) row >= [[[WCSettings settings] objectForKey:WCBookmarks] count])
		return;
	
	oldBookmark = [[[WCSettings settings] bookmarkAtIndex:row] retain];
	bookmark = [oldBookmark mutableCopy];
	[bookmark setObject:[_bookmarksNameTextField stringValue] forKey:WCBookmarksName];
	[bookmark setObject:[_bookmarksAddressTextField stringValue] forKey:WCBookmarksAddress];
	[bookmark setObject:[_bookmarksLoginTextField stringValue] forKey:WCBookmarksLogin];
	[bookmark setObject:[NSNumber numberWithBool:[_bookmarksAutoConnectButton state]] forKey:WCBookmarksAutoConnect];
	[bookmark setObject:[NSNumber numberWithBool:[_bookmarksAutoReconnectButton state]] forKey:WCBookmarksAutoReconnect];
	[bookmark setObject:[_bookmarksNickTextField stringValue] forKey:WCBookmarksNick];
	[bookmark setObject:[_bookmarksStatusTextField stringValue] forKey:WCBookmarksStatus];
	
	if(![[[WCSettings settings] bookmarkAtIndex:row] isEqualToDictionary:bookmark]) {
		[[WCSettings settings] setBookmark:bookmark atIndex:row];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];
	}
	
	if(![[oldBookmark objectForKey:WCBookmarksAddress] isEqualToString:[bookmark objectForKey:WCBookmarksAddress]] ||
	   ![[oldBookmark objectForKey:WCBookmarksLogin] isEqualToString:[bookmark objectForKey:WCBookmarksLogin]]) {
		password = [[WCKeychain keychain] passwordForBookmark:oldBookmark];
		
		if(password) {
			[[WCKeychain keychain] deletePasswordForBookmark:oldBookmark];
			[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
		}
	}
	
	if(_bookmarkPasswordTouched) {
		password = [_bookmarksPasswordTextField stringValue];
		
		if(![password isEqualToString:WCBookmarksPasswordMagic]) {
			if([password length] > 0)
				[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
			else
				[[WCKeychain keychain] deletePasswordForBookmark:bookmark];
		}
		
		_bookmarkPasswordTouched = NO;
	}
	
	[oldBookmark release];
	[bookmark release];
}



- (void)_selectEvent {
	NSDictionary	*event;
	NSString		*sound;
	NSInteger		tag;
	BOOL			on;
	
	tag = [_eventsPopUpButton tagOfSelectedItem];
	event = [[WCSettings settings] eventForTag:tag];
	[_playSoundButton setState:[event boolForKey:WCEventsPlaySound]];
	
	sound = [event objectForKey:WCEventsSound];
	
	if(sound && [_soundsPopUpButton indexOfItemWithTitle:sound] != -1)
		[_soundsPopUpButton selectItemWithTitle:sound];
	else if ([_soundsPopUpButton numberOfItems] > 0)
		[_soundsPopUpButton selectItemAtIndex:0];

	[_bounceInDockButton setState:[event boolForKey:WCEventsBounceInDock]];
	[_postInChatButton setState:[event boolForKey:WCEventsPostInChat]];
	[_showDialogButton setState:[event boolForKey:WCEventsShowDialog]];
	
	on = (tag == WCEventsUserJoined || tag == WCEventsUserChangedNick || tag == WCEventsUserLeft || tag == WCEventsUserChangedStatus);
	[_postInChatButton setEnabled:on];

	on = (tag == WCEventsMessageReceived || tag == WCEventsBroadcastReceived);
	[_showDialogButton setEnabled:on];

	[self _touchEvents];
}



- (void)_touchEvents {
	BOOL	on;
	
	on = ([_playSoundButton state] || [_bounceInDockButton state] || [_postInChatButton state] || [_showDialogButton state]);
	[[_eventsPopUpButton selectedItem] setImage:[NSImage imageNamed:on ? @"EventOn" : @"EventOff"]];
	
	[_soundsPopUpButton setEnabled:[_playSoundButton state]];
}



- (void)_selectTrackerBookmark {
	NSDictionary	*trackerBookmark;
	NSInteger		row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row >= 0 && (NSUInteger) row < [[[WCSettings settings] objectForKey:WCTrackerBookmarks] count]) {
		trackerBookmark = [[WCSettings settings] trackerBookmarkAtIndex:row];
		
		[_trackerBookmarksNameTextField setEnabled:YES];
		[_trackerBookmarksAddressTextField setEnabled:YES];

		[_trackerBookmarksNameTextField setStringValue:[trackerBookmark objectForKey:WCTrackerBookmarksName]];
		[_trackerBookmarksAddressTextField setStringValue:[trackerBookmark objectForKey:WCTrackerBookmarksAddress]];
	} else {
		[_trackerBookmarksNameTextField setEnabled:NO];
		[_trackerBookmarksAddressTextField setEnabled:NO];

		[_trackerBookmarksNameTextField setStringValue:@""];
		[_trackerBookmarksAddressTextField setStringValue:@""];
	}
}



- (void)_unselectTrackerBookmark {
	NSMutableDictionary		*trackerBookmark;
	NSInteger				row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0 || (NSUInteger) row >= [[[WCSettings settings] objectForKey:WCTrackerBookmarks] count])
		return;
	
	trackerBookmark = [[[WCSettings settings] trackerBookmarkAtIndex:row] mutableCopy];
	[trackerBookmark setObject:[_trackerBookmarksNameTextField stringValue] forKey:WCTrackerBookmarksName];
	[trackerBookmark setObject:[_trackerBookmarksAddressTextField stringValue] forKey:WCTrackerBookmarksAddress];
	
	if(![[[WCSettings settings] trackerBookmarkAtIndex:row] isEqualToDictionary:trackerBookmark]) {
		[[WCSettings settings] setTrackerBookmark:trackerBookmark atIndex:row];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self userInfo:trackerBookmark];
	}
	
	[trackerBookmark release];
}

@end


@implementation WCPreferences

+ (WCPreferences *)preferences {
	static id	sharedPreferences;

	if(!sharedPreferences)
		sharedPreferences = [[self alloc] init];

	return sharedPreferences;
}



- (id)init {
	self = [super initWithWindowNibName:@"Preferences"];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChange];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_toolbarItems release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator	*enumerator;
	NSArray			*sounds;
	NSString		*path;
	WIColorCell		*colorCell;
	
	[_iconImageView setMaxImageSize:NSMakeSize(32.0, 32.0)];
	[_iconImageView setDefaultImage:[NSImage imageNamed:@"DefaultIcon"]];

	colorCell = [[WIColorCell alloc] init];
	[colorCell setEditable:YES];
	[colorCell setTarget:self];
	[colorCell setAction: @selector(showColorPanel:)];
	[_highlightsColorTableColumn setDataCell:colorCell];
	[colorCell release];

	[_bookmarksTableView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[_highlightsTableView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[_ignoresTableView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[_trackerBookmarksTableView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	[_bookmarksTableView registerForDraggedTypes:[NSArray arrayWithObject:WCBookmarkPboardType]];
	[_highlightsTableView registerForDraggedTypes:[NSArray arrayWithObject:WCIgnorePboardType]];
	[_ignoresTableView registerForDraggedTypes:[NSArray arrayWithObject:WCIgnorePboardType]];
	[_trackerBookmarksTableView registerForDraggedTypes:[NSArray arrayWithObject:WCTrackerBookmarkPboardType]];
	
	[self _reloadEvents];
	
	sounds = [[NSFileManager defaultManager] libraryResourcesForTypes:[NSSound soundUnfilteredFileTypes]
														  inDirectory:@"Sounds"];
	enumerator = [sounds objectEnumerator];

	[_soundsPopUpButton removeAllItems];

	while((path = [enumerator nextObject]))
		[_soundsPopUpButton addItemWithTitle:[[path lastPathComponent] stringByDeletingPathExtension]];

	[[self window] setToolbar:[self _toolbar]];
	[[self window] center];

	[self _addTouchActionsToSubviewsInView:[[self window] contentView]];

	[self _loadSettings];
	[self _selectTab:@"General"];
	
	[_interfaceTabView selectFirstTabViewItem:self];
	[_chatTabView selectFirstTabViewItem:self];
}



- (void)windowWillClose:(NSNotification *)notification {
	[self _unselectBookmark];
	[self _unselectTrackerBookmark];
	
	[self _saveSettings];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	return [_toolbarItems objectForKey:identifier];
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"General",
		@"Interface",
		@"Bookmarks",
		@"Chat",
		@"Events",
		@"Files",
		@"Trackers",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarDefaultItemIdentifiers:toolbar];
}



- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarDefaultItemIdentifiers:toolbar];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	[_bookmarksTableView reloadData];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSMutableDictionary		*dictionary;
	id						object;
	NSInteger				row;
	
	object = [notification object];

	if(object == _nickTextField) {
		[_bookmarksNickTextField setPlaceholderString:[_nickTextField stringValue]];
	}
	else if(object == _statusTextField) {
		[_bookmarksStatusTextField setPlaceholderString:[_statusTextField stringValue]];
	}
	else if(object == _bookmarksNameTextField) {
		row = [_bookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		dictionary = [[[WCSettings settings] bookmarkAtIndex:row] mutableCopy];
		[dictionary setObject:[_bookmarksNameTextField stringValue] forKey:WCBookmarksName];
		[[WCSettings settings] setBookmark:dictionary atIndex:row];
		[dictionary release];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];

		[_bookmarksTableView reloadData];
	}
	else if(object == _bookmarksPasswordTextField) {
		_bookmarkPasswordTouched = YES;
	}
	else if(object == _trackerBookmarksNameTextField) {
		row = [_trackerBookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		dictionary = [[[WCSettings settings] trackerBookmarkAtIndex:row] mutableCopy];
		[dictionary setObject:[_trackerBookmarksNameTextField stringValue] forKey:WCTrackerBookmarksName];
		[[WCSettings settings] setTrackerBookmark:dictionary atIndex:row];
		[dictionary release];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];
		
		[_trackerBookmarksTableView reloadData];
	}
}



#pragma mark -

- (IBAction)showWindow:(id)sender {
	[[self window] setTitle:[[_preferencesTabView selectedTabViewItem] label]];
	
	[super showWindow:self];
}



#pragma mark -

- (void)selectToolbarItem:(id)sender {
	NSTabViewItem   *item;

	item = [_preferencesTabView tabViewItemWithIdentifier:[sender itemIdentifier]];
	
	if(item)
		[self _selectTabViewItem:item];
}



- (void)touch:(id)sender {
	[self _saveSettings];
}



- (IBAction)icon:(id)sender {
	[self _saveSettings];
}



- (IBAction)showFontPanel:(id)sender {
	NSFontManager	*fontManager;
	NSFont			*font = NULL;
	
	fontManager = [NSFontManager sharedFontManager];
	
	if(sender == _chatFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatFont]];
		[fontManager setAction:@selector(changeChatFont:)];
	}
	if(sender == _chatUserListFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatUserListFont]];
		[fontManager setAction:@selector(changeChatUserListFont:)];
	}
	else if(sender == _messagesFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]];
		[fontManager setAction:@selector(changeMessagesFont:)];
	}
	else if(sender == _messagesListFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesListFont]];
		[fontManager setAction:@selector(changeMessagesListFont:)];
	}
	else if(sender == _newsFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]];
		[fontManager setAction:@selector(changeNewsFont:)];
	}
	else if(sender == _filesFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCFilesFont]];
		[fontManager setAction:@selector(changeFilesFont:)];
	}
	else if(sender == _previewFontButton) {
		font = [NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCPreviewFont]];
		[fontManager setAction:@selector(changePreviewFont:)];
	}
	
	if(font) {
		[fontManager setSelectedFont:font isMultiple:NO];
		[fontManager orderFrontFontPanel:self];
	}
}



- (void)changeChatFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCChatFont];
	[_chatFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (void)changeChatUserListFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatUserListFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCChatUserListFont];
	[_chatUserListFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (void)changeMessagesFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCMessagesFont];
	[_messagesFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (void)changeMessagesListFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesListFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCMessagesListFont];
	[_messagesListFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (void)changeNewsFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCNewsFont];
	[_newsFontTextField setStringValue:[font displayNameWithSize]];
	
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:[font boldFont]] forKey:WCNewsTitlesFont];
	
	[self _saveSettings];
}



- (void)changeFilesFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCFilesFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCFilesFont];
	[_filesFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (void)changePreviewFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCPreviewFont]]];
	[[WCSettings settings] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:WCPreviewFont];
	[_previewFontTextField setStringValue:[font displayNameWithSize]];
	
	[self _saveSettings];
}



- (IBAction)showColorPanel:(id)sender {
	NSColorPanel	*colorPanel;
	NSInteger		row;
	
	row = [_highlightsTableView selectedRow];
	
	if(row < 0)
		return;
	
	colorPanel = [NSColorPanel sharedColorPanel];
	[colorPanel setTarget:self];
	[colorPanel setAction:@selector(changeHighlightColor:)];
	[colorPanel setColor:WIColorFromString([[[WCSettings settings] highlightAtIndex:row] objectForKey:WCHighlightsColor])];
	[colorPanel makeKeyAndOrderFront:self];
}



- (void)changeHighlightColor:(id)sender {
	NSMutableDictionary		*highlight;
	NSInteger				row;
	
	if(_highlightsTableView == [[self window] firstResponder]) {
		row = [_highlightsTableView selectedRow];
		
		if(row < 0)
			return;
		
		highlight = [[[WCSettings settings] highlightAtIndex:row] mutableCopy];
		[highlight setObject:WIStringFromColor([sender color]) forKey:WCHighlightsColor];
		[[WCSettings settings] setHighlight:highlight atIndex:row];
		[highlight release];
		
		[_highlightsTableView reloadData];
		
		[self _saveSettings];
	}
}



- (IBAction)selectEvent:(id)sender {
	[self _selectEvent];
}



- (IBAction)touchEvent:(id)sender {
	NSString	*sound;
	
	[self _touchEvents];
	
	if(sender == _playSoundButton && [_playSoundButton state]) {
		sound = [_soundsPopUpButton titleOfSelectedItem];
		
		if(sound)
			[NSSound playSoundNamed:sound];
	}
	
	[self _saveSettings];
}



- (IBAction)selectSound:(id)sender {
	NSString	*sound;
	
	sound = [_soundsPopUpButton titleOfSelectedItem];

	if(sound)
		[NSSound playSoundNamed:sound];
	
	[self _saveSettings];
}



- (IBAction)selectDownloadFolder:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:[_downloadFolderTextField stringValue]
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(downloadFolderPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)downloadFolderPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton) {
		[_downloadFolderTextField setStringValue:[[openPanel filename] stringByAbbreviatingWithTildeInPath]];
	
		[self _saveSettings];
	}
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary	*bookmark;
	
	[self _unselectBookmark];
	
	bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled bookmark"),	WCBookmarksName,
		@"",										WCBookmarksAddress,
		@"",										WCBookmarksLogin,
		[NSString UUIDString],						WCBookmarksIdentifier,
		[NSNumber numberWithBool:NO],				WCBookmarksAutoConnect,
		[NSNumber numberWithBool:NO],				WCBookmarksAutoReconnect,
		@"",										WCBookmarksNick,
		@"",										WCBookmarksStatus,
		NULL];
	[[WCSettings settings] addBookmark:bookmark];
	[_bookmarksTableView reloadData];
	
	[_bookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCBookmarks] count] - 1]
					 byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];
}



- (IBAction)deleteBookmark:(id)sender {
	NSString	*name;
	NSInteger	row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[[WCSettings settings] bookmarkAtIndex:row] objectForKey:WCBookmarksName];
	
	NSBeginAlertSheet([NSSWF:NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete bookmark dialog title (bookmark)"), name],
					  NSLS(@"Delete", @"Delete bookmark dialog button title"),
					  NSLS(@"Cancel", @"Delete bookmark dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteBookmarkSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete bookmark dialog description"));
}



- (void)deleteBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSInteger	row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_bookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		[[WCKeychain keychain] deletePasswordForBookmark:[[WCSettings settings] bookmarkAtIndex:row]];
		[[WCSettings settings] removeBookmarkAtIndex:row];
		[_bookmarksTableView reloadData];
		[self _selectBookmark];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];
	}
}



- (IBAction)addHighlight:(id)sender {
	NSDictionary	*highlight;
	NSColor			*color;
	NSInteger		row;
	
	row = [[[WCSettings settings] objectForKey:WCHighlights] count] - 1;
	
	if(row >= 0)
		color = WIColorFromString([[[WCSettings settings] highlightAtIndex:row] objectForKey:WCHighlightsColor]);
	else
		color = [NSColor yellowColor];
	
	highlight = [NSDictionary dictionaryWithObjectsAndKeys:
		@"",						WCHighlightsPattern,
		WIStringFromColor(color),	WCHighlightsColor,
		NULL];
	[[WCSettings settings] addHighlight:highlight];

	row = [[[WCSettings settings] objectForKey:WCHighlights] count] - 1;
	
	[_highlightsTableView reloadData];
	[_highlightsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_highlightsTableView editColumn:0 row:row withEvent:NULL select:YES];
}



- (IBAction)deleteHighlight:(id)sender {
	NSBeginAlertSheet(NSLS(@"Are you sure you want to delete the selected highlight?", @"Delete highlight dialog title (bookmark)"),
					  NSLS(@"Delete", @"Delete highlight dialog button title"),
					  NSLS(@"Cancel", @"Delete highlight dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteHighlightSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete highlight dialog description"));
}



- (void)deleteHighlightSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSInteger	row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_highlightsTableView selectedRow];
		
		if(row < 0)
			return;
		
		[[WCSettings settings] removeHighlightAtIndex:row];
		
		[_highlightsTableView reloadData];
	}
}



- (IBAction)addIgnore:(id)sender {
	NSDictionary	*ignore;
	NSInteger		row;
	
	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled ignore"),		WCIgnoresNick,
		@"",										WCIgnoresLogin,
		@"",										WCIgnoresAddress,
		NULL];
	[[WCSettings settings] addIgnore:ignore];
	
	row = [[[WCSettings settings] objectForKey:WCIgnores] count] - 1;

	[_ignoresTableView reloadData];
	[_ignoresTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_ignoresTableView editColumn:0 row:row withEvent:NULL select:YES];
}



- (IBAction)deleteIgnore:(id)sender {
	NSBeginAlertSheet(NSLS(@"Are you sure you want to delete the selected ignore?", @"Delete ignore dialog title (bookmark)"),
					  NSLS(@"Delete", @"Delete ignore dialog button title"),
					  NSLS(@"Cancel", @"Delete ignore dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteIgnoreSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete ignore dialog description"));
}



- (void)deleteIgnoreSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSInteger	row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_ignoresTableView selectedRow];
		
		if(row < 0)
			return;
		
		[[WCSettings settings] removeIgnoreAtIndex:row];
		[_ignoresTableView reloadData];
	}
}



- (IBAction)addTrackerBookmark:(id)sender {
	NSDictionary	*trackerBookmark;
	
	[self _unselectTrackerBookmark];
	
	trackerBookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled tracker bookmark"),	WCTrackerBookmarksName,
		@"",												WCTrackerBookmarksAddress,
		NULL];
	[[WCSettings settings] addTrackerBookmark:trackerBookmark];
	[_trackerBookmarksTableView reloadData];
	
	[_trackerBookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCTrackerBookmarks] count] - 1]
							byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];
}



- (IBAction)deleteTrackerBookmark:(id)sender {
	NSString	*name;
	NSInteger	row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[[WCSettings settings] trackerBookmarkAtIndex:row] objectForKey:WCTrackerBookmarksName];
	
	NSBeginAlertSheet([NSSWF:NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete tracker bookmark dialog title (bookmark)"), name],
					  NSLS(@"Delete", @"Delete tracker bookmark dialog button title"),
					  NSLS(@"Cancel", @"Delete tracker bookmark dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteTrackerBookmarkSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete tracker bookmark dialog description"));
}



- (void)deleteTrackerBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSInteger	row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_trackerBookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		[[WCSettings settings] removeTrackerBookmarkAtIndex:row];
		[_trackerBookmarksTableView reloadData];
		[self _selectTrackerBookmark];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];
	}
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == _bookmarksTableView)
		return [[[WCSettings settings] objectForKey:WCBookmarks] count];
	else if(tableView == _highlightsTableView)
		return [[[WCSettings settings] objectForKey:WCHighlights] count];
	else if(tableView == _ignoresTableView)
		return [[[WCSettings settings] objectForKey:WCIgnores] count];
	else if(tableView == _trackerBookmarksTableView)
		return [[[WCSettings settings] objectForKey:WCTrackerBookmarks] count];

	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	NSDictionary	*dictionary;
		
	if(tableView == _bookmarksTableView) {
		dictionary = [[WCSettings settings] bookmarkAtIndex:row];
		
		if(column == _bookmarksNameTableColumn)
			return [dictionary objectForKey:WCBookmarksName];
	}
	else if(tableView == _highlightsTableView) {
		dictionary = [[WCSettings settings] highlightAtIndex:row];
		
		if(column == _highlightsPatternTableColumn)
			return [dictionary objectForKey:WCHighlightsPattern];
		else if(column == _highlightsColorTableColumn)
			return WIColorFromString([dictionary objectForKey:WCHighlightsColor]);
	}
	else if(tableView == _ignoresTableView) {
		dictionary = [[WCSettings settings] ignoreAtIndex:row];
		
		if(column == _ignoresNickTableColumn)
			return [dictionary objectForKey:WCIgnoresNick];
		else if(column == _ignoresLoginTableColumn)
			return [dictionary objectForKey:WCIgnoresLogin];
		else if(column == _ignoresAddressTableColumn)
			return [dictionary objectForKey:WCIgnoresAddress];
	}
	else if(tableView == _trackerBookmarksTableView) {
		dictionary = [[WCSettings settings] trackerBookmarkAtIndex:row];
		
		if(column == _trackerBookmarksNameTableColumn)
			return [dictionary objectForKey:WCTrackerBookmarksName];
	}

	return NULL;
}



- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSMutableDictionary		*dictionary;
		
	if(tableView == _highlightsTableView) {
		if((NSUInteger) row < [[[WCSettings settings] objectForKey:WCHighlights] count]) {
			dictionary = [[[WCSettings settings] highlightAtIndex:row] mutableCopy];
			
			if(tableColumn == _highlightsPatternTableColumn)
				[dictionary setObject:object forKey:WCHighlightsPattern];
			
			[[WCSettings settings] setHighlight:dictionary atIndex:row];
			[dictionary release];
		}
	}
	else if(tableView == _ignoresTableView) {
		if((NSUInteger) row < [[[WCSettings settings] objectForKey:WCIgnores] count]) {
			dictionary = [[[WCSettings settings] ignoreAtIndex:row] mutableCopy];
			
			if(tableColumn == _ignoresNickTableColumn)
				[dictionary setObject:object forKey:WCIgnoresNick];
			else if(tableColumn == _ignoresLoginTableColumn)
				[dictionary setObject:object forKey:WCIgnoresLogin];
			else if(tableColumn == _ignoresAddressTableColumn)
				[dictionary setObject:object forKey:WCIgnoresAddress];
		
			[[WCSettings settings] setIgnore:dictionary atIndex:row];
			[dictionary release];
		}
	}
}



- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	if(tableView == _bookmarksTableView)
		[self _unselectBookmark];
	else if(tableView == _trackerBookmarksTableView)
		[self _unselectTrackerBookmark];
	
	return YES;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	if([notification object] == _bookmarksTableView)
		[self _selectBookmark];
	else if([notification object] == _trackerBookmarksTableView)
		[self _selectTrackerBookmark];

	[self _validate];
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	if(tableView == _bookmarksTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCBookmarkPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", [[items objectAtIndex:0] integerValue]] forType:WCBookmarkPboardType];
		
		return YES;
	}
	else if(tableView == _trackerBookmarksTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCTrackerBookmarkPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", [[items objectAtIndex:0] integerValue]] forType:WCTrackerBookmarkPboardType];
		
		return YES;
	}

	return NO;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation{
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSMutableArray	*dictionary;
	NSPasteboard	*pasteboard;
	NSArray			*types;
	NSInteger		fromRow;
	NSUInteger		index;
	
	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];
	
	if([types containsObject:WCBookmarkPboardType]) {
		[self _unselectBookmark];
		
		fromRow = [[pasteboard stringForType:WCBookmarkPboardType] integerValue];
		dictionary = [[[WCSettings settings] objectForKey:WCBookmarks] mutableCopy];
		index = [dictionary moveObjectAtIndex:fromRow toIndex:row];
		[[WCSettings settings] setObject:dictionary forKey:WCBookmarks];
		[dictionary release];
		
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];

		return YES;
	}
	else if([types containsObject:WCHighlightPboardType]) {
		fromRow = [[pasteboard stringForType:WCHighlightPboardType] integerValue];
		dictionary = [[[WCSettings settings] objectForKey:WCHighlights] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[[[WCSettings settings] settings] setObject:dictionary forKey:WCHighlights];
		[dictionary release];
		
		return YES;
	}
	else if([types containsObject:WCIgnorePboardType]) {
		fromRow = [[pasteboard stringForType:WCIgnorePboardType] integerValue];
		dictionary = [[[[WCSettings settings] settings] objectForKey:WCIgnores] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[[[WCSettings settings] settings] setObject:dictionary forKey:WCIgnores];
		[dictionary release];
		
		return YES;
	}
	else if([types containsObject:WCTrackerBookmarkPboardType]) {
		[self _unselectTrackerBookmark];
		
		fromRow = [[pasteboard stringForType:WCTrackerBookmarkPboardType] integerValue];
		dictionary = [[[[WCSettings settings] settings] objectForKey:WCTrackerBookmarks] mutableCopy];
		index = [dictionary moveObjectAtIndex:fromRow toIndex:row];
		[[[WCSettings settings] settings] setObject:dictionary forKey:WCTrackerBookmarks];
		[dictionary release];

		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];

		return YES;
	}
	
	return NO;
}

@end
