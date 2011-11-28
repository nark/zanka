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

@interface WCPreferences : WIWindowController {
	IBOutlet NSTabView					*_preferencesTabView;
	IBOutlet NSTabView					*_interfaceTabView;
	IBOutlet NSTabView					*_chatTabView;

	IBOutlet NSTextField				*_nickTextField;
	IBOutlet NSTextField				*_statusTextField;
	IBOutlet NSImageView				*_iconImageView;
	IBOutlet NSButton					*_showConnectAtStartupButton;
	IBOutlet NSButton					*_showDockAtStartupButton;
	IBOutlet NSButton					*_showTrackersAtStartupButton;
	IBOutlet NSButton					*_autoHideOnSwitchButton;
	IBOutlet NSButton					*_confirmDisconnectButton;
	
	IBOutlet NSColorWell				*_chatTextColorWell;
	IBOutlet NSColorWell				*_chatBackgroundColorWell;
	IBOutlet NSColorWell				*_chatURLsColorWell;
	IBOutlet NSColorWell				*_chatEventsColorWell;
	IBOutlet NSTextField				*_chatFontTextField;
	IBOutlet NSButton					*_chatFontButton;
	IBOutlet NSTextField				*_chatUserListFontTextField;
	IBOutlet NSButton					*_chatUserListFontButton;
	IBOutlet NSMatrix					*_chatUserListIconSizeMatrix;
	IBOutlet NSButton					*_chatUserListAlternateRowsButton;

	IBOutlet NSColorWell				*_messagesTextColorWell;
	IBOutlet NSColorWell				*_messagesBackgroundColorWell;
	IBOutlet NSTextField				*_messagesFontTextField;
	IBOutlet NSButton					*_messagesFontButton;
	IBOutlet NSTextField				*_messagesListFontTextField;
	IBOutlet NSButton					*_messagesListFontButton;
	IBOutlet NSButton					*_messagesListAlternateRowsButton;
	
	IBOutlet NSColorWell				*_newsTextColorWell;
	IBOutlet NSColorWell				*_newsBackgroundColorWell;
	IBOutlet NSColorWell				*_newsTitlesColorWell;
	IBOutlet NSTextField				*_newsFontTextField;
	IBOutlet NSButton					*_newsFontButton;

	IBOutlet NSTextField				*_filesFontTextField;
	IBOutlet NSButton					*_filesFontButton;
	IBOutlet NSButton					*_filesAlternateRowsButton;

	IBOutlet NSButton					*_transfersShowProgressBarButton;
	IBOutlet NSButton					*_transfersAlternateRowsButton;

	IBOutlet NSColorWell				*_previewTextColorWell;
	IBOutlet NSColorWell				*_previewBackgroundColorWell;
	IBOutlet NSTextField				*_previewFontTextField;
	IBOutlet NSButton					*_previewFontButton;
	
	IBOutlet NSButton					*_trackersAlternateRowsButton;

	IBOutlet NSTableView				*_bookmarksTableView;
	IBOutlet NSButton					*_addBookmarkButton;
	IBOutlet NSButton					*_deleteBookmarkButton;
	IBOutlet NSTableColumn				*_bookmarksNameTableColumn;
	IBOutlet NSTextField				*_bookmarksNameTextField;
	IBOutlet NSTextField				*_bookmarksAddressTextField;
	IBOutlet NSTextField				*_bookmarksLoginTextField;
	IBOutlet NSSecureTextField			*_bookmarksPasswordTextField;
	IBOutlet NSButton					*_bookmarksAutoJoinButton;
	IBOutlet NSTextField				*_bookmarksNickTextField;
	IBOutlet NSTextField				*_bookmarksStatusTextField;
	
	IBOutlet NSMatrix					*_chatStyleMatrix;
	IBOutlet NSButton					*_historyScrollbackButton;
	IBOutlet NSPopUpButton				*_historyScrollbackModifierPopUpButton;
	IBOutlet NSButton					*_tabCompleteNicksButton;
	IBOutlet NSTextField				*_tabCompleteNicksTextField;
	IBOutlet NSButton					*_timestampChatButton;
	IBOutlet NSTextField				*_timestampChatIntervalTextField;
	IBOutlet NSButton					*_timestampEveryLineButton;
	IBOutlet NSColorWell				*_timestampEveryLineColorWell;
	IBOutlet NSButton					*_showSmileysButton;
	
	IBOutlet NSTableView				*_highlightsTableView;
	IBOutlet NSButton					*_addHiglightButton;
	IBOutlet NSButton					*_deleteHiglightButton;
	IBOutlet NSTableColumn				*_highlightsPatternTableColumn;
	IBOutlet NSTableColumn				*_highlightsColorTableColumn;
	
	IBOutlet NSTableView				*_ignoresTableView;
	IBOutlet NSButton					*_addIgnoreButton;
	IBOutlet NSButton					*_deleteIgnoreButton;
	IBOutlet NSTableColumn				*_ignoresNickTableColumn;
	IBOutlet NSTableColumn				*_ignoresLoginTableColumn;
	IBOutlet NSTableColumn				*_ignoresAddressTableColumn;
	
	IBOutlet NSPopUpButton				*_eventsPopUpButton;
	IBOutlet NSButton					*_playSoundButton;
	IBOutlet NSPopUpButton				*_soundsPopUpButton;
	IBOutlet NSButton					*_bounceInDockButton;
	IBOutlet NSButton					*_postInChatButton;
	IBOutlet NSButton					*_showDialogButton;
	
	IBOutlet NSTextField				*_downloadFolderTextField;
	IBOutlet NSButton					*_openFoldersInNewWindowsButton;
	IBOutlet NSButton					*_queueTransfersButton;
	IBOutlet NSButton					*_encryptTransfersButton;
	IBOutlet NSButton					*_removeTransfersButton;

	IBOutlet NSTableView				*_trackerBookmarksTableView;
	IBOutlet NSButton					*_addTrackerBookmarkButton;
	IBOutlet NSButton					*_deleteTrackerBookmarkButton;
	IBOutlet NSTableColumn				*_trackerBookmarksNameTableColumn;
	IBOutlet NSTextField				*_trackerBookmarksNameTextField;
	IBOutlet NSTextField				*_trackerBookmarksAddressTextField;

	NSMutableDictionary					*_toolbarItems;
	int									_selectedEvent;
	BOOL								_passwordTouched;
	
	NSTabViewItem						*_selectedTabViewItem;
}


#define	WCPreferencesToolbar			@"WCPreferencesToolbar"

#define WCPreferencesDidChange			@"WCPreferencesDidChange"
#define WCBookmarksDidChange			@"WCBookmarksDidChange"
#define WCTrackerBookmarksDidChange		@"WCTrackerBookmarksDidChange"
#define WCNickDidChange					@"WCNickDidChange"
#define WCStatusDidChange				@"WCStatusDidChange"
#define WCIconDidChange					@"WCIconDidChange"

#define WCBookmarkPboardType			@"WCBookmarkPboardType"
#define WCHighlightPboardType			@"WCHighlightPboardType"
#define WCIgnorePboardType				@"WCIgnorePboardType"
#define WCTrackerBookmarkPboardType		@"WCTrackerBookmarkPboardType"


+ (WCPreferences *)preferences;

- (IBAction)icon:(id)sender;
- (IBAction)setIcon:(id)sender;
- (IBAction)clearIcon:(id)sender;
- (IBAction)showFontPanel:(id)sender;
- (IBAction)selectEvent:(id)sender;
- (IBAction)touchEvent:(id)sender;
- (IBAction)selectSound:(id)sender;
- (IBAction)selectDownloadFolder:(id)sender;

- (IBAction)addBookmark:(id)sender;
- (IBAction)deleteBookmark:(id)sender;
- (IBAction)addHighlight:(id)sender;
- (IBAction)deleteHighlight:(id)sender;
- (IBAction)addIgnore:(id)sender;
- (IBAction)deleteIgnore:(id)sender;
- (IBAction)addTrackerBookmark:(id)sender;
- (IBAction)deleteTrackerBookmark:(id)sender;

@end
