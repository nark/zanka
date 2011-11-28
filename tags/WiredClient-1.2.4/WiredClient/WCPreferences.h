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

#import "WCWindowController.h"

@class WCToolbar, WCIconMatrix;

@interface WCPreferences : WCWindowController {
	IBOutlet NSTabView				*_preferencesTabView;
		
	IBOutlet NSTextField			*_fontTextField;
	IBOutlet NSColorWell			*_eventColorWell;
	IBOutlet NSColorWell			*_URLColorWell;
	IBOutlet NSButton				*_showConnectAtStartupButton;
	IBOutlet NSButton				*_showTransfersAtStartupButton;
	IBOutlet NSButton				*_confirmDisconnectButton;
	
	IBOutlet NSTextField			*_nickTextField;
	IBOutlet NSTextField			*_statusTextField;
	IBOutlet WCIconMatrix			*_iconMatrix;
	IBOutlet NSImageView			*_iconImageView;

	IBOutlet NSTableView			*_bookmarkTableView;
	IBOutlet NSTableColumn			*_bookmarkNameTableColumn;
	IBOutlet NSTableColumn			*_bookmarkAddressTableColumn;
	IBOutlet NSTableColumn			*_bookmarkLoginTableColumn;
	IBOutlet NSPanel				*_bookmarkPanel;
	IBOutlet NSTextField			*_bookmarkNameTextField;
	IBOutlet NSTextField			*_bookmarkAddressTextField;
	IBOutlet NSTextField			*_bookmarkLoginTextField;
	IBOutlet NSSecureTextField		*_bookmarkPasswordTextField;

	IBOutlet NSColorWell			*_chatTextColorWell;
	IBOutlet NSColorWell			*_chatBackgroundColorWell;
	IBOutlet NSMatrix				*_chatStyleMatrix;
	IBOutlet NSMatrix				*_iconSizeMatrix;
	IBOutlet NSButton				*_historyScrollbackButton;
	IBOutlet NSPopUpButton			*_historyScrollbackModifierPopUpButton;
	IBOutlet NSButton				*_tabCompleteNicksButton;
	IBOutlet NSTextField			*_tabCompleteNicksTextField;
	IBOutlet NSButton				*_highlightWordsButton;
	IBOutlet NSColorWell			*_highlightWordsColorWell;
	IBOutlet NSPanel				*_highlightWordsPanel;
	IBOutlet NSTableView			*_highlightWordsTableView;
	IBOutlet NSTableColumn			*_highlightWordsWordTableColumn;
	IBOutlet NSButton				*_highlightWordsAddButton;
	IBOutlet NSButton				*_highlightWordsDeleteButton;
	IBOutlet NSButton				*_timestampChatButton;
	IBOutlet NSTextField			*_timestampChatIntervalTextField;
	IBOutlet NSButton				*_timestampEveryLineButton;
	IBOutlet NSColorWell			*_timestampEveryLineColorWell;
	IBOutlet NSButton				*_showJoinLeaveButton;
	IBOutlet NSButton				*_showNickChangesButton;

	IBOutlet NSColorWell			*_messageTextColorWell;
	IBOutlet NSColorWell			*_messageBackgroundColorWell;
	IBOutlet NSButton				*_showMessagesInForegroundButton;
	
	IBOutlet NSTextField			*_newsFontTextField;
	IBOutlet NSColorWell			*_newsTextColorWell;
	IBOutlet NSColorWell			*_newsBackgroundColorWell;
	IBOutlet NSButton				*_loadNewsOnLoginButton;
	
	IBOutlet NSTextField			*_downloadFolderTextField;
	IBOutlet NSButton				*_openFoldersInNewWindowsButton;
	IBOutlet NSButton				*_queueTransfersButton;
	IBOutlet NSButton				*_encryptTransfersButton;
	IBOutlet NSButton				*_removeTransfersButton;
	
	IBOutlet NSTableView			*_trackerTableView;
	IBOutlet NSTableColumn			*_trackerNameTableColumn;
	IBOutlet NSTableColumn			*_trackerAddressTableColumn;
	IBOutlet NSPanel				*_trackerPanel;
	IBOutlet NSTextField			*_trackerNameTextField;
	IBOutlet NSTextField			*_trackerAddressTextField;
	
	IBOutlet NSTableView			*_ignoreTableView;
	IBOutlet NSTableColumn			*_ignoreNickTableColumn;
	IBOutlet NSTableColumn			*_ignoreLoginTableColumn;
	IBOutlet NSTableColumn			*_ignoreAddressTableColumn;
	IBOutlet NSPanel				*_ignorePanel;
	IBOutlet NSTextField			*_ignoreNickTextField;
	IBOutlet NSTextField			*_ignoreLoginTextField;
	IBOutlet NSTextField			*_ignoreAddressTextField;
	
	IBOutlet NSPopUpButton			*_connectedEventPopUpButton;
	IBOutlet NSPopUpButton			*_disconnectedEventPopUpButton;
	IBOutlet NSPopUpButton			*_chatEventPopUpButton;
	IBOutlet NSPopUpButton			*_userJoinEventPopUpButton;
	IBOutlet NSPopUpButton			*_userLeaveEventPopUpButton;
	IBOutlet NSPopUpButton			*_messagesEventPopUpButton;
	IBOutlet NSPopUpButton			*_newsEventPopUpButton;
	IBOutlet NSPopUpButton			*_broadcastEventPopUpButton;
	IBOutlet NSPopUpButton			*_transferStartedEventPopUpButton;
	IBOutlet NSPopUpButton			*_transferDoneEventPopUpButton;

	WCToolbar						*_toolbar;
	
	NSFont							*_currentTextFont, *_currentNewsFont;
}


#define WCPreferencesDidChange		@"WCPreferencesDidChange"
#define WCNickDidChange				@"WCNickDidChange"
#define WCStatusDidChange			@"WCStatusDidChange"
#define WCIconDidChange				@"WCIconDidChange"
	

- (void)							selectTab:(NSString *)identifier;

- (IBAction)						showFontPanel:(id)sender;
- (IBAction)						setIcon:(id)sender;
- (IBAction)						clearIcon:(id)sender;
- (IBAction)						useOldIcon:(id)sender;
- (IBAction)						selectDownloadFolder:(id)sender;
- (IBAction)						selectSound:(id)sender;

- (IBAction)						showWordsSheet:(id)sender;
- (IBAction)						addWord:(id)sender;
- (IBAction)						deleteWord:(id)sender;

- (IBAction)						addBookmark:(id)sender;
- (IBAction)						editBookmark:(id)sender;
- (IBAction)						deleteBookmark:(id)sender;

- (IBAction)						addTracker:(id)sender;
- (IBAction)						editTracker:(id)sender;
- (IBAction)						deleteTracker:(id)sender;

- (IBAction)						addIgnore:(id)sender;
- (IBAction)						editIgnore:(id)sender;
- (IBAction)						deleteIgnore:(id)sender;

@end
