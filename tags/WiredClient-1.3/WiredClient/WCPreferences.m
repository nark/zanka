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

#import "WCKeychain.h"
#import "WCPreferences.h"
#import "WCTrackers.h"

#define WCBookmarksPasswordMagic		@"869815172a9e5882c46ee2e2c084f29d2aa7e890"


@interface WCPreferences(Private)

- (void)_validate;

- (NSToolbar *)_toolbar;

- (void)_reloadEvents;
- (void)_selectTab:(NSString *)identifier;
- (void)_selectTabViewItem:(NSTabViewItem *)item;

- (void)_loadSettings;
- (void)_saveSettings;
- (void)_selectBookmark;
- (void)_unselectBookmark;
- (void)_updateEvents;
- (void)_touchEvents;
- (void)_selectTrackerBookmark;
- (void)_unselectTrackerBookmark;

- (void)_setIcon:(NSImage *)icon;

@end


@implementation WCPreferences(Private)

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
	[toolbar setAllowsUserCustomization:YES];
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
	
	enumerator = [[WCSettings objectForKey:WCEvents] objectEnumerator];
	events = [NSMutableDictionary dictionary];
	
	while((event = [enumerator nextObject]))
		[events setObject:event forKey:[event objectForKey:WCEventsEvent]];

	enumerator = [[[WCSettings defaults] objectForKey:WCEvents] objectEnumerator];
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
			
			if([event boolForKey:WCEventsPlaySound] || [event boolForKey:WCEventsBounceInDock] || [event boolForKey:WCEventsPostInChat])
				[item setImage:[NSImage imageNamed:@"EventOn"]];
			else
				[item setImage:[NSImage imageNamed:@"EventOff"]];
			
			[[_eventsPopUpButton menu] addItem:item];
		}
	}
	
	[WCSettings setObject:[events allValues] forKey:WCEvents];
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
	[_nickTextField setStringValue:[WCSettings objectForKey:WCNick]];
	[_statusTextField setStringValue:[WCSettings objectForKey:WCStatus]];
	[_iconImageView setImage:[NSImage imageWithData:
		[NSData dataWithBase64EncodedString:[WCSettings objectForKey:WCCustomIcon]]]];
	
	[_showConnectAtStartupButton setState:[WCSettings boolForKey:WCShowConnectAtStartup]];
	[_showDockAtStartupButton setState:[WCSettings boolForKey:WCShowDockAtStartup]];
	[_showTrackersAtStartupButton setState:[WCSettings boolForKey:WCShowTrackersAtStartup]];

	[_autoHideOnSwitchButton setState:[WCSettings boolForKey:WCAutoHideOnSwitch]];
	[_confirmDisconnectButton setState:[WCSettings boolForKey:WCConfirmDisconnect]];
	
	// --- interface/chat
	[_chatTextColorWell setColor:[WCSettings objectForKey:WCChatTextColor]];
	[_chatBackgroundColorWell setColor:[WCSettings objectForKey:WCChatBackgroundColor]];
	[_chatURLsColorWell setColor:[WCSettings objectForKey:WCChatURLsColor]];
	[_chatEventsColorWell setColor:[WCSettings objectForKey:WCChatEventsColor]];
	[_chatFontTextField setStringValue:[[WCSettings objectForKey:WCChatFont] displayNameWithSize]];
	[_chatUserListFontTextField setStringValue:[[WCSettings objectForKey:WCChatUserListFont] displayNameWithSize]];
	[_chatUserListIconSizeMatrix selectCellWithTag:[WCSettings intForKey:WCChatUserListIconSize]];
	[_chatUserListAlternateRowsButton setState:[WCSettings boolForKey:WCChatUserListAlternateRows]];

	// --- interface/messages
	[_messagesTextColorWell setColor:[WCSettings objectForKey:WCMessagesTextColor]];
	[_messagesBackgroundColorWell setColor:[WCSettings objectForKey:WCMessagesBackgroundColor]];
	[_messagesFontTextField setStringValue:[[WCSettings objectForKey:WCMessagesFont] displayNameWithSize]];
	[_messagesListFontTextField setStringValue:[[WCSettings objectForKey:WCMessagesListFont] displayNameWithSize]];
	[_messagesListAlternateRowsButton setState:[WCSettings boolForKey:WCMessagesListAlternateRows]];
	
	// --- interface/news
	[_newsTextColorWell setColor:[WCSettings objectForKey:WCNewsTextColor]];
	[_newsTitlesColorWell setColor:[WCSettings objectForKey:WCNewsTitlesColor]];
	[_newsBackgroundColorWell setColor:[WCSettings objectForKey:WCNewsBackgroundColor]];
	[_newsFontTextField setStringValue:[[WCSettings objectForKey:WCNewsFont] displayNameWithSize]];

	// --- interface/files
	[_filesFontTextField setStringValue:[[WCSettings objectForKey:WCFilesFont] displayNameWithSize]];
	[_filesAlternateRowsButton setState:[WCSettings boolForKey:WCFilesAlternateRows]];

	// --- interface/transfers
	[_transfersShowProgressBarButton setState:[WCSettings boolForKey:WCTransfersShowProgressBar]];
	[_transfersAlternateRowsButton setState:[WCSettings boolForKey:WCTransfersAlternateRows]];

	// --- interface/preview
	[_previewTextColorWell setColor:[WCSettings objectForKey:WCPreviewTextColor]];
	[_previewBackgroundColorWell setColor:[WCSettings objectForKey:WCPreviewBackgroundColor]];
	[_previewFontTextField setStringValue:[[WCSettings objectForKey:WCPreviewFont] displayNameWithSize]];
	
	// --- interface/trackers
	[_trackersAlternateRowsButton setState:[WCSettings boolForKey:WCTrackersAlternateRows]];

	// --- bookmarks
	[_bookmarksNickTextField setPlaceholderString:[_nickTextField stringValue]];
	[_bookmarksStatusTextField setPlaceholderString:[_statusTextField stringValue]];
	[self _selectBookmark];
	[_bookmarksTableView reloadData];
	
	// --- chat
	[_chatStyleMatrix selectCellWithTag:[WCSettings intForKey:WCChatStyle]];
	[_historyScrollbackButton setState:[WCSettings boolForKey:WCHistoryScrollback]];
	[_historyScrollbackModifierPopUpButton selectItemWithTag:
		[WCSettings intForKey:WCHistoryScrollbackModifier]];
	[_tabCompleteNicksButton setState:[WCSettings boolForKey:WCTabCompleteNicks]];
	[_tabCompleteNicksTextField setStringValue:[WCSettings objectForKey:WCTabCompleteNicksString]];
	[_timestampChatButton setState:[WCSettings boolForKey:WCTimestampChat]];
	[_timestampChatIntervalTextField setStringValue:[NSSWF:@"%.0f",
		[WCSettings doubleForKey:WCTimestampChatInterval] / 60.0]];
	[_timestampEveryLineButton setState:[WCSettings boolForKey:WCTimestampEveryLine]];
	[_timestampEveryLineColorWell setColor:[WCSettings objectForKey:WCTimestampEveryLineColor]];
	
	[_highlightsTableView reloadData];
	[_ignoresTableView reloadData];

	// --- events
	[self _updateEvents];
	
	// --- files
	[_downloadFolderTextField setStringValue:[[WCSettings objectForKey:WCDownloadFolder] stringByAbbreviatingWithTildeInPath]];
	[_openFoldersInNewWindowsButton setState:[WCSettings boolForKey:WCOpenFoldersInNewWindows]];
	[_queueTransfersButton setState:[WCSettings boolForKey:WCQueueTransfers]];
	[_encryptTransfersButton setState:[WCSettings boolForKey:WCEncryptTransfers]];
	[_removeTransfersButton setState:[WCSettings boolForKey:WCRemoveTransfers]];
	
	// --- trackers
	[self _selectTrackerBookmark];
	[_trackerBookmarksTableView reloadData];
	
	[self _validate];
}



- (void)_saveSettings {
	// --- general
	if(![[_nickTextField stringValue] isEqualToString:[WCSettings objectForKey:WCNick]]) {
		[WCSettings setObject:[_nickTextField stringValue] forKey:WCNick];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCNickDidChange];
	}
	
	if(![[_statusTextField stringValue] isEqualToString:[WCSettings objectForKey:WCStatus]]) {
		[WCSettings setObject:[_statusTextField stringValue] forKey:WCStatus];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCStatusDidChange];
	}
	
	[WCSettings setBool:[_showConnectAtStartupButton state] forKey:WCShowConnectAtStartup];
	[WCSettings setBool:[_showDockAtStartupButton state] forKey:WCShowDockAtStartup];
	[WCSettings setBool:[_showTrackersAtStartupButton state] forKey:WCShowTrackersAtStartup];

	[WCSettings setBool:[_autoHideOnSwitchButton state] forKey:WCAutoHideOnSwitch];
	[WCSettings setBool:[_confirmDisconnectButton state] forKey:WCConfirmDisconnect];
	
	// --- interface/chat
	[WCSettings setObject:[_chatTextColorWell color] forKey:WCChatTextColor];
	[WCSettings setObject:[_chatBackgroundColorWell color] forKey:WCChatBackgroundColor];
	[WCSettings setObject:[_chatURLsColorWell color] forKey:WCChatURLsColor];
	[WCSettings setObject:[_chatEventsColorWell color] forKey:WCChatEventsColor];
	[WCSettings setInt:[[_chatUserListIconSizeMatrix selectedCell] tag] forKey:WCChatUserListIconSize];
	[WCSettings setBool:[_chatUserListAlternateRowsButton state] forKey:WCChatUserListAlternateRows];

	// --- interface/messages
	[WCSettings setObject:[_messagesTextColorWell color] forKey:WCMessagesTextColor];
	[WCSettings setObject:[_messagesBackgroundColorWell color] forKey:WCMessagesBackgroundColor];
	[WCSettings setBool:[_messagesListAlternateRowsButton state] forKey:WCMessagesListAlternateRows];
	
	// --- interface/news
	[WCSettings setObject:[_newsTextColorWell color] forKey:WCNewsTextColor];
	[WCSettings setObject:[_newsTitlesColorWell color] forKey:WCNewsTitlesColor];
	[WCSettings setObject:[_newsBackgroundColorWell color] forKey:WCNewsBackgroundColor];

	// --- interface/files
	[WCSettings setBool:[_filesAlternateRowsButton state] forKey:WCFilesAlternateRows];

	// --- interface/transfers
	[WCSettings setBool:[_transfersShowProgressBarButton state] forKey:WCTransfersShowProgressBar];
	[WCSettings setBool:[_transfersAlternateRowsButton state] forKey:WCTransfersAlternateRows];

	// --- interface/trackers
	[WCSettings setBool:[_trackersAlternateRowsButton state] forKey:WCTrackersAlternateRows];

	// --- interface/preview
	[WCSettings setObject:[_previewTextColorWell color] forKey:WCPreviewTextColor];
	[WCSettings setObject:[_previewBackgroundColorWell color] forKey:WCPreviewBackgroundColor];

	// --- bookmarks
	[self _unselectBookmark];

	// --- chat
	[WCSettings setInt:[[_chatStyleMatrix selectedCell] tag] forKey:WCChatStyle];
	[WCSettings setBool:[_historyScrollbackButton state] forKey:WCHistoryScrollback];
	[WCSettings setInt:[[_historyScrollbackModifierPopUpButton selectedItem] tag]
				forKey:WCHistoryScrollbackModifier];
	[WCSettings setBool:[_tabCompleteNicksButton state] forKey:WCTabCompleteNicks];
	[WCSettings setObject:[_tabCompleteNicksTextField stringValue] forKey:WCTabCompleteNicksString];
	[WCSettings setBool:[_timestampChatButton state] forKey:WCTimestampChat];
	[WCSettings setInt:[_timestampChatIntervalTextField intValue] * 60 forKey:WCTimestampChatInterval];
	[WCSettings setBool:[_timestampEveryLineButton state] forKey:WCTimestampEveryLine];
	[WCSettings setObject:[_timestampEveryLineColorWell color] forKey:WCTimestampEveryLineColor];
	
	// --- events
	[self _updateEvents];

	// --- files
	[WCSettings setObject:[_downloadFolderTextField stringValue] forKey:WCDownloadFolder];
	[WCSettings setBool:[_openFoldersInNewWindowsButton state] forKey:WCOpenFoldersInNewWindows];
	[WCSettings setBool:[_queueTransfersButton state] forKey:WCQueueTransfers];
	[WCSettings setBool:[_encryptTransfersButton state] forKey:WCEncryptTransfers];
	[WCSettings setBool:[_removeTransfersButton state] forKey:WCRemoveTransfers];

	// --- trackers
	[self _unselectTrackerBookmark];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChange object:self];
}



- (void)_selectBookmark {
	NSDictionary	*bookmark;
	int				row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row >= 0) {
		bookmark = [WCSettings bookmarkAtIndex:row];
		
		[_bookmarksNameTextField setEnabled:YES];
		[_bookmarksAddressTextField setEnabled:YES];
		[_bookmarksLoginTextField setEnabled:YES];
		[_bookmarksPasswordTextField setEnabled:YES];
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
		
		[_bookmarksNickTextField setStringValue:[bookmark objectForKey:WCBookmarksNick]];
		[_bookmarksStatusTextField setStringValue:[bookmark objectForKey:WCBookmarksStatus]];
	} else {
		[_bookmarksNameTextField setEnabled:NO];
		[_bookmarksAddressTextField setEnabled:NO];
		[_bookmarksLoginTextField setEnabled:NO];
		[_bookmarksPasswordTextField setEnabled:NO];
		[_bookmarksNickTextField setEnabled:NO];
		[_bookmarksStatusTextField setEnabled:NO];

		[_bookmarksNameTextField setStringValue:@""];
		[_bookmarksAddressTextField setStringValue:@""];
		[_bookmarksLoginTextField setStringValue:@""];
		[_bookmarksPasswordTextField setStringValue:@""];
		[_bookmarksNickTextField setStringValue:@""];
		[_bookmarksStatusTextField setStringValue:@""];
	}
}



- (void)_unselectBookmark {
	NSMutableDictionary		*bookmark;
	NSString				*password;
	int						row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	bookmark = [[WCSettings bookmarkAtIndex:row] mutableCopy];
	[bookmark setObject:[_bookmarksNameTextField stringValue] forKey:WCBookmarksName];
	[bookmark setObject:[_bookmarksAddressTextField stringValue] forKey:WCBookmarksAddress];
	[bookmark setObject:[_bookmarksLoginTextField stringValue] forKey:WCBookmarksLogin];
	[bookmark setObject:[_bookmarksNickTextField stringValue] forKey:WCBookmarksNick];
	[bookmark setObject:[_bookmarksStatusTextField stringValue] forKey:WCBookmarksStatus];
	
	if(![[WCSettings bookmarkAtIndex:row] isEqualToDictionary:bookmark]) {
		[WCSettings setBookmark:bookmark atIndex:row];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self userInfo:bookmark];
	}
	
	if(_passwordTouched) {
		password = [_bookmarksPasswordTextField stringValue];
		
		if(![password isEqualToString:WCBookmarksPasswordMagic]) {
			if([password length] > 0)
				[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
			else
				[[WCKeychain keychain] deletePasswordForBookmark:bookmark];
		}
		
		_passwordTouched = NO;
	}
	
	[bookmark release];
}



- (void)_updateEvents {
	NSMutableDictionary	*newEvent;
	NSDictionary		*event;
	int					tag;
	BOOL				on;
	
	if(_selectedEvent > 0) {
		newEvent = [[WCSettings eventForTag:_selectedEvent] mutableCopy];
		[newEvent setInt:_selectedEvent forKey:WCEventsEvent];
		[newEvent setBool:[_playSoundButton state] forKey:WCEventsPlaySound];
		[newEvent setObject:[_soundsPopUpButton titleOfSelectedItem] forKey:WCEventsSound];
		[newEvent setBool:[_bounceInDockButton state] forKey:WCEventsBounceInDock];
		[newEvent setBool:[_postInChatButton state] forKey:WCEventsPostInChat];
		[WCSettings setEvent:newEvent forTag:_selectedEvent];
		[newEvent release];
	}
	
	tag = [_eventsPopUpButton tagOfSelectedItem];
	event = [WCSettings eventForTag:tag];
	[_playSoundButton setState:[event boolForKey:WCEventsPlaySound]];
	
	if([(NSString *) [event objectForKey:WCEventsSound] length] > 0)
		[_soundsPopUpButton selectItemWithTitle:[event objectForKey:WCEventsSound]];

	[_bounceInDockButton setState:[event boolForKey:WCEventsBounceInDock]];
	[_postInChatButton setState:[event boolForKey:WCEventsPostInChat]];
	
	on = (tag == WCEventsUserJoined || tag == WCEventsUserChangedNick || tag == WCEventsUserLeft || tag == WCEventsUserChangedStatus);
	[_postInChatButton setEnabled:on];

	[self _touchEvents];
	
	_selectedEvent = tag;
}



- (void)_touchEvents {
	BOOL	on;
	
	on = [_playSoundButton state] || [_bounceInDockButton state] || [_postInChatButton state];
	[[_eventsPopUpButton selectedItem] setImage:[NSImage imageNamed:on ? @"EventOn" : @"EventOff"]];
	
	[_soundsPopUpButton setEnabled:[_playSoundButton state]];
}



- (void)_selectTrackerBookmark {
	NSDictionary	*trackerBookmark;
	int				row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row >= 0) {
		trackerBookmark = [WCSettings trackerBookmarkAtIndex:row];
		
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
	int						row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	trackerBookmark = [[WCSettings trackerBookmarkAtIndex:row] mutableCopy];
	[trackerBookmark setObject:[_trackerBookmarksNameTextField stringValue] forKey:WCTrackerBookmarksName];
	[trackerBookmark setObject:[_trackerBookmarksAddressTextField stringValue] forKey:WCTrackerBookmarksAddress];
	
	if(![[WCSettings trackerBookmarkAtIndex:row] isEqualToDictionary:trackerBookmark]) {
		[WCSettings setTrackerBookmark:trackerBookmark atIndex:row];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self userInfo:trackerBookmark];
	}
	
	[trackerBookmark release];
}



#pragma mark -

- (void)_setIcon:(NSImage *)icon {
	NSBitmapImageRep	*imageRep;
	NSImage				*image;
	NSData				*data;
	NSSize				iconSize, size;
	
	iconSize = size = [icon size];
	
	if(iconSize.width > 32.0 || iconSize.height > 32.0) {
		if(iconSize.width > 32.0 && iconSize.height <= 32.0)
			size = NSMakeSize(32.0, iconSize.height);
		else if(iconSize.width <= 32.0 && iconSize.height > 32.0)
			size = NSMakeSize(iconSize.height, 32.0);
		else if(iconSize.width > iconSize.height)
			size = NSMakeSize(32.0, 32.0 * (iconSize.width / iconSize.height));
		else if(iconSize.width < iconSize.height)
			size = NSMakeSize(32.0 * (iconSize.width / iconSize.height), 32.0);
		else
			size = NSMakeSize(32.0, 32.0);

		[icon setScalesWhenResized:YES];
		[icon setSize:size];
	}

	if(NSEqualSizes(iconSize, size)) {
		image = icon;
	} else {
		image = [[NSImage alloc] initWithSize:size];
		[image lockFocus];
		[icon drawAtPoint:NSZeroPoint
				 fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
				operation:NSCompositeCopy
				 fraction:1.0];
		[image unlockFocus];

		[_iconImageView setImage:image];
		[image release];
	}

	imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	data = [imageRep representationUsingType:NSPNGFileType properties:NULL];

	[WCSettings setObject:[data base64EncodedString] forKey:WCCustomIcon];
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange];
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



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator	*enumerator;
	NSArray			*sounds;
	NSString		*path;
	WIColorCell		*colorCell;

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

	[self _loadSettings];
	[self _selectTab:@"General"];
}



- (void)windowWillClose:(NSNotification *)notification {
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
	int						row;
	
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
		
		dictionary = [[WCSettings bookmarkAtIndex:row] mutableCopy];
		[dictionary setObject:[_bookmarksNameTextField stringValue] forKey:WCBookmarksName];
		[WCSettings setBookmark:dictionary atIndex:row];
		[dictionary release];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self userInfo:dictionary];

		[_bookmarksTableView reloadData];
	}
	else if(object == _bookmarksPasswordTextField) {
		_passwordTouched = YES;
	}
	else if(object == _trackerBookmarksNameTextField) {
		row = [_trackerBookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		dictionary = [[WCSettings trackerBookmarkAtIndex:row] mutableCopy];
		[dictionary setObject:[_trackerBookmarksNameTextField stringValue] forKey:WCTrackerBookmarksName];
		[WCSettings setTrackerBookmark:dictionary atIndex:row];
		[dictionary release];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self userInfo:dictionary];
		
		[_trackerBookmarksTableView reloadData];
	}
}



#pragma mark -

- (void)selectToolbarItem:(id)sender {
	NSTabViewItem   *item;

	item = [_preferencesTabView tabViewItemWithIdentifier:[sender itemIdentifier]];
	
	if(item)
		[self _selectTabViewItem:item];
}



- (void)changeChatFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCChatFont]];
	[WCSettings setObject:font forKey:WCChatFont];
	[_chatFontTextField setStringValue:[font displayNameWithSize]];
}



- (void)changeChatUserListFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCChatUserListFont]];
	[WCSettings setObject:font forKey:WCChatUserListFont];
	[_chatUserListFontTextField setStringValue:[font displayNameWithSize]];
}



- (void)changeMessagesFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCMessagesFont]];
	[WCSettings setObject:font forKey:WCMessagesFont];
	[_messagesFontTextField setStringValue:[font displayNameWithSize]];
}



- (void)changeMessagesListFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCMessagesListFont]];
	[WCSettings setObject:font forKey:WCMessagesListFont];
	[_messagesListFontTextField setStringValue:[font displayNameWithSize]];
}



- (void)changeNewsFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCNewsFont]];
	[WCSettings setObject:font forKey:WCNewsFont];
	[_newsFontTextField setStringValue:[font displayNameWithSize]];
	
	font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
	[WCSettings setObject:font forKey:WCNewsTitlesFont];
}



- (void)changeFilesFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCFilesFont]];
	[WCSettings setObject:font forKey:WCFilesFont];
	[_filesFontTextField setStringValue:[font displayNameWithSize]];
}



- (void)changePreviewFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[WCSettings objectForKey:WCPreviewFont]];
	[WCSettings setObject:font forKey:WCPreviewFont];
	[_previewFontTextField setStringValue:[font displayNameWithSize]];
}



#pragma mark -

- (IBAction)showWindow:(id)sender {
	[[self window] setTitle:[[_preferencesTabView selectedTabViewItem] label]];
	
	[super showWindow:self];
}



- (IBAction)icon:(id)sender {
	[self _setIcon:[_iconImageView image]];
}



- (IBAction)setIcon:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:[NSImage imageFileTypes]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(iconPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)iconPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSData		*data;
	NSImage		*image;

	if(returnCode == NSOKButton) {
		data = [NSData dataWithContentsOfFile:[openPanel filename]];
		image = [NSImage imageWithData:data];
		
		if(image) {
			[_iconImageView setImage:image];
			[self _setIcon:image];
		}
	}
}



- (IBAction)clearIcon:(id)sender {
	[_iconImageView setImage:NULL];

	[WCSettings setObject:@"" forKey:WCCustomIcon];
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChange];
}



- (IBAction)showFontPanel:(id)sender {
	NSFontManager	*fontManager;
	NSFont			*font = NULL;
	
	fontManager = [NSFontManager sharedFontManager];
	
	if(sender == _chatFontButton) {
		font = [WCSettings objectForKey:WCChatFont];
		[fontManager setAction:@selector(changeChatFont:)];
	}
	if(sender == _chatUserListFontButton) {
		font = [WCSettings objectForKey:WCChatUserListFont];
		[fontManager setAction:@selector(changeChatUserListFont:)];
	}
	else if(sender == _messagesFontButton) {
		font = [WCSettings objectForKey:WCMessagesFont];
		[fontManager setAction:@selector(changeMessagesFont:)];
	}
	else if(sender == _messagesListFontButton) {
		font = [WCSettings objectForKey:WCMessagesListFont];
		[fontManager setAction:@selector(changeMessagesListFont:)];
	}
	else if(sender == _newsFontButton) {
		font = [WCSettings objectForKey:WCNewsFont];
		[fontManager setAction:@selector(changeNewsFont:)];
	}
	else if(sender == _filesFontButton) {
		font = [WCSettings objectForKey:WCFilesFont];
		[fontManager setAction:@selector(changeFilesFont:)];
	}
	else if(sender == _previewFontButton) {
		font = [WCSettings objectForKey:WCPreviewFont];
		[fontManager setAction:@selector(changePreviewFont:)];
	}
	
	if(font) {
		[fontManager setSelectedFont:font isMultiple:NO];
		[fontManager orderFrontFontPanel:self];
	}
}



- (IBAction)showColorPanel:(id)sender {
	NSColorPanel	*colorPanel;
	int				row;
	
	row = [_highlightsTableView selectedRow];
	
	if(row < 0)
		return;
	
	colorPanel = [NSColorPanel sharedColorPanel];
	[colorPanel setTarget:self];
	[colorPanel setAction:@selector(selectHighlightColor:)];
	[colorPanel setColor:NSColorFromString([[WCSettings highlightAtIndex:row] objectForKey:WCHighlightsColor])];
	[colorPanel makeKeyAndOrderFront:self];
}



- (IBAction)selectHighlightColor:(id)sender {
	NSMutableDictionary		*highlight;
	int						row;
	
	if(_highlightsTableView == [[self window] firstResponder]) {
		row = [_highlightsTableView selectedRow];
		
		if(row < 0)
			return;
		
		highlight = [[WCSettings highlightAtIndex:row] mutableCopy];
		[highlight setObject:NSStringFromColor([sender color]) forKey:WCHighlightsColor];
		[WCSettings setHighlight:highlight atIndex:row];
		[highlight release];
		
		[_highlightsTableView reloadData];
	}
}



- (IBAction)selectEvent:(id)sender {
	[self _updateEvents];
}



- (IBAction)touchEvent:(id)sender {
	[self _touchEvents];
	
	if(sender == _playSoundButton && [_playSoundButton state])
		[NSSound playSoundNamed:[_soundsPopUpButton titleOfSelectedItem]];
}



- (IBAction)selectSound:(id)sender {
	[NSSound playSoundNamed:[_soundsPopUpButton titleOfSelectedItem]];
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



- (void)downloadFolderPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[_downloadFolderTextField setStringValue:[[openPanel filename] stringByAbbreviatingWithTildeInPath]];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary	*bookmark;
	
	bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled bookmark"),	WCBookmarksName,
		@"",										WCBookmarksAddress,
		@"",										WCBookmarksLogin,
		[NSString UUIDString],						WCBookmarksIdentifier,
		@"",										WCBookmarksNick,
		@"",										WCBookmarksStatus,
		NULL];
	[WCSettings addBookmark:bookmark];
	[_bookmarksTableView reloadData];
	
	[_bookmarksTableView selectRow:[[WCSettings objectForKey:WCBookmarks] count] - 1
			  byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];
}



- (IBAction)deleteBookmark:(id)sender {
	NSString	*name;
	int			row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[WCSettings bookmarkAtIndex:row] objectForKey:WCBookmarksName];
	
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



- (void)deleteBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int			row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_bookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		[[WCKeychain keychain] deletePasswordForBookmark:[WCSettings bookmarkAtIndex:row]];
		[WCSettings removeBookmarkAtIndex:row];
		[_bookmarksTableView reloadData];
		
		row = row == 0 ? 0 : row - 1;
		
		if(row != [_bookmarksTableView selectedRow])
			[_bookmarksTableView selectRow:row byExtendingSelection:NO];
		else
			[self _selectBookmark];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];
	}
}



- (IBAction)addHighlight:(id)sender {
	NSDictionary	*highlight;
	NSColor			*color;
	int				row;
	
	row = [[WCSettings objectForKey:WCHighlights] count] - 1;
	
	if(row >= 0)
		color = NSColorFromString([[WCSettings highlightAtIndex:row] objectForKey:WCHighlightsColor]);
	else
		color = [NSColor yellowColor];
	
	highlight = [NSDictionary dictionaryWithObjectsAndKeys:
		@"",						WCHighlightsPattern,
		NSStringFromColor(color),	WCHighlightsColor,
		NULL];
	[WCSettings addHighlight:highlight];

	[_highlightsTableView reloadData];
	[_highlightsTableView selectRow:[[WCSettings objectForKey:WCHighlights] count] - 1
				byExtendingSelection:NO];
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



- (void)deleteHighlightSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int			row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_highlightsTableView selectedRow];
		
		if(row < 0)
			return;
		
		[WCSettings removeHighlightAtIndex:row];
		
		[_highlightsTableView reloadData];
		[_highlightsTableView selectRow:row == 0 ? 0 : row - 1 byExtendingSelection:NO];
	}
}



- (IBAction)addIgnore:(id)sender {
	NSDictionary	*ignore;
	
	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled ignore"),		WCIgnoresNick,
		@"",										WCIgnoresLogin,
		@"",										WCIgnoresAddress,
		NULL];
	[WCSettings addIgnore:ignore];
	
	[_ignoresTableView reloadData];
	[_ignoresTableView selectRow:[[WCSettings objectForKey:WCIgnores] count] - 1
			byExtendingSelection:NO];
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



- (void)deleteIgnoreSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int			row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_ignoresTableView selectedRow];
		
		if(row < 0)
			return;
		
		[WCSettings removeIgnoreAtIndex:row];
		
		[_ignoresTableView reloadData];
		[_ignoresTableView selectRow:row == 0 ? 0 : row - 1 byExtendingSelection:NO];
	}
}



- (IBAction)addTrackerBookmark:(id)sender {
	NSDictionary	*trackerBookmark;
	
	trackerBookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled tracker bookmark"),	WCTrackerBookmarksName,
		@"",												WCTrackerBookmarksAddress,
		NULL];
	[WCSettings addTrackerBookmark:trackerBookmark];
	[_trackerBookmarksTableView reloadData];
	
	[_trackerBookmarksTableView selectRow:[[WCSettings objectForKey:WCTrackerBookmarks] count] - 1
					 byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];
}



- (IBAction)deleteTrackerBookmark:(id)sender {
	NSString	*name;
	int			row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[WCSettings trackerBookmarkAtIndex:row] objectForKey:WCTrackerBookmarksName];
	
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



- (void)deleteTrackerBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	int			row;

	if(returnCode == NSAlertDefaultReturn) {
		row = [_trackerBookmarksTableView selectedRow];
		
		if(row < 0)
			return;
		
		[WCSettings removeTrackerBookmarkAtIndex:row];
		[_trackerBookmarksTableView reloadData];
		
		row = row == 0 ? 0 : row - 1;
		
		if(row != [_trackerBookmarksTableView selectedRow])
			[_trackerBookmarksTableView selectRow:row byExtendingSelection:NO];
		else
			[self _selectTrackerBookmark];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == _bookmarksTableView)
		return [[WCSettings objectForKey:WCBookmarks] count];
	else if(tableView == _highlightsTableView)
		return [[WCSettings objectForKey:WCHighlights] count];
	else if(tableView == _ignoresTableView)
		return [[WCSettings objectForKey:WCIgnores] count];
	else if(tableView == _trackerBookmarksTableView)
		return [[WCSettings objectForKey:WCTrackerBookmarks] count];

	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	NSDictionary	*dictionary;
		
	if(tableView == _bookmarksTableView) {
		dictionary = [WCSettings bookmarkAtIndex:row];
		
		if(column == _bookmarksNameTableColumn)
			return [dictionary objectForKey:WCBookmarksName];
	}
	else if(tableView == _highlightsTableView) {
		dictionary = [WCSettings highlightAtIndex:row];
		
		if(column == _highlightsPatternTableColumn)
			return [dictionary objectForKey:WCHighlightsPattern];
		else if(column == _highlightsColorTableColumn)
			return NSColorFromString([dictionary objectForKey:WCHighlightsColor]);
	}
	else if(tableView == _ignoresTableView) {
		dictionary = [WCSettings ignoreAtIndex:row];
		
		if(column == _ignoresNickTableColumn)
			return [dictionary objectForKey:WCIgnoresNick];
		else if(column == _ignoresLoginTableColumn)
			return [dictionary objectForKey:WCIgnoresLogin];
		else if(column == _ignoresAddressTableColumn)
			return [dictionary objectForKey:WCIgnoresAddress];
	}
	else if(tableView == _trackerBookmarksTableView) {
		dictionary = [WCSettings trackerBookmarkAtIndex:row];
		
		if(column == _trackerBookmarksNameTableColumn)
			return [dictionary objectForKey:WCTrackerBookmarksName];
	}

	return NULL;
}



- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSMutableDictionary		*dictionary;
		
	if(tableView == _highlightsTableView) {
		dictionary = [[WCSettings highlightAtIndex:row] mutableCopy];
		
		if(tableColumn == _highlightsPatternTableColumn)
			[dictionary setObject:object forKey:WCHighlightsPattern];
		
		[WCSettings setHighlight:dictionary atIndex:row];
		[dictionary release];
	}
	else if(tableView == _ignoresTableView) {
		dictionary = [[WCSettings ignoreAtIndex:row] mutableCopy];
		
		if(tableColumn == _ignoresNickTableColumn)
			[dictionary setObject:object forKey:WCIgnoresNick];
		else if(tableColumn == _ignoresLoginTableColumn)
			[dictionary setObject:object forKey:WCIgnoresLogin];
		else if(tableColumn == _ignoresAddressTableColumn)
			[dictionary setObject:object forKey:WCIgnoresAddress];
	
		[WCSettings setIgnore:dictionary atIndex:row];
		[dictionary release];
	}
}



- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(int)row {
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
		[pasteboard setString:[NSSWF:@"%d", [[items objectAtIndex:0] intValue]] forType:WCBookmarkPboardType];
		
		return YES;
	}
	else if(tableView == _trackerBookmarksTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCTrackerBookmarkPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%d", [[items objectAtIndex:0] intValue]] forType:WCTrackerBookmarkPboardType];
		
		return YES;
	}

	return NO;
}



- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation{
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSMutableArray	*dictionary;
	NSPasteboard	*pasteboard;
	NSArray			*types;
	int				fromRow;
	
	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];
	
	if([types containsObject:WCBookmarkPboardType]) {
		fromRow = [[pasteboard stringForType:WCBookmarkPboardType] intValue];
		dictionary = [[WCSettings objectForKey:WCBookmarks] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[WCSettings setObject:dictionary forKey:WCBookmarks];
		[dictionary release];
		
		[tableView selectRow:(row == (int) [dictionary count]) ? row - 1 : row byExtendingSelection:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:self];

		return YES;
	}
	else if([types containsObject:WCHighlightPboardType]) {
		fromRow = [[pasteboard stringForType:WCHighlightPboardType] intValue];
		dictionary = [[WCSettings objectForKey:WCHighlights] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[WCSettings setObject:dictionary forKey:WCHighlights];
		[dictionary release];
		
		return YES;
	}
	else if([types containsObject:WCIgnorePboardType]) {
		fromRow = [[pasteboard stringForType:WCIgnorePboardType] intValue];
		dictionary = [[WCSettings objectForKey:WCIgnores] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[WCSettings setObject:dictionary forKey:WCIgnores];
		[dictionary release];
		
		return YES;
	}
	else if([types containsObject:WCTrackerBookmarkPboardType]) {
		fromRow = [[pasteboard stringForType:WCTrackerBookmarkPboardType] intValue];
		dictionary = [[WCSettings objectForKey:WCTrackerBookmarks] mutableCopy];
		[dictionary moveObjectAtIndex:fromRow toIndex:row];
		[WCSettings setObject:dictionary forKey:WCTrackerBookmarks];
		[dictionary release];
		
		[tableView selectRow:(row == (int) [dictionary count]) ? row - 1 : row byExtendingSelection:NO];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChange object:self];

		return YES;
	}
	
	return NO;
}

@end
