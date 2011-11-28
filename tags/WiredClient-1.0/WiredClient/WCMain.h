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

@class WCIcons, WCSettings, WCStats, WCTextFinder, WCTrackers, WCStats, WCPreferences, WCConnection;

@interface WCMain : NSWindowController {
	WCIcons							*_icons;
	WCSettings						*_settings;
	WCStats							*_stats;

	WCTextFinder					*_textFinder;
	WCTrackers						*_trackers;
	WCPreferences					*_preferences;
	
	IBOutlet NSMenu					*_connectionMenu;
	IBOutlet NSMenuItem				*_serverInfoMenuItem;
	IBOutlet NSMenuItem				*_chatMenuItem;
	IBOutlet NSMenuItem				*_newsMenuItem;
	IBOutlet NSMenuItem				*_messagesMenuItem;
	IBOutlet NSMenuItem				*_filesMenuItem;
	IBOutlet NSMenuItem				*_transfersMenuItem;
	IBOutlet NSMenuItem				*_searchMenuItem;
	IBOutlet NSMenuItem				*_consoleMenuItem;
	IBOutlet NSMenuItem				*_accountsMenuItem;
	IBOutlet NSMenuItem				*_saveChatMenuItem;
	IBOutlet NSMenuItem				*_getInfoMenuItem;
	IBOutlet NSMenuItem				*_postNewMenuItem;
	IBOutlet NSMenuItem				*_broadcastMenuItem;
	IBOutlet NSMenuItem				*_disconnectMenuItem;

	IBOutlet NSMenu					*_filesMenu;
	IBOutlet NSMenuItem				*_newFolderMenuItem;
	IBOutlet NSMenuItem				*_reloadMenuItem;
	IBOutlet NSMenuItem				*_deleteMenuItem;
	IBOutlet NSMenuItem				*_backMenuItem;
	IBOutlet NSMenuItem				*_forwardMenuItem;
	
	IBOutlet NSMenu					*_bookmarksMenu;
	IBOutlet NSMenuItem				*_addBookmarkMenuItem;

	IBOutlet NSTextField			*_addressTextField;
	IBOutlet NSTextField			*_loginTextField;
	IBOutlet NSSecureTextField		*_passwordTextField;
	IBOutlet NSProgressIndicator	*_progressIndicator;
	
	id								_activeWindow;
	WCConnection					*_activeConnection, *_runningConnection;
	
	unsigned int					_connections;
	NSString						*_version;
	unsigned int					_unread;
}


extern WCMain						*WCSharedMain;


#define								WCApplicationSupportPath	@"~/Library/Application Support/Wired Client"


- (void)							updateMenus;
- (void)							updateIcon;
- (void)							updateBookmarksMenu;
- (void)							handleStatsKey;
- (void)							saveStats:(NSTimer *)timer;

- (NSString *)						version;
- (unsigned int)					unread;
- (void)							setUnread:(unsigned int)value;

- (void)							showConnect:(NSURL *)url;
- (IBAction)						connectWithWindow:(id)sender;
- (IBAction)						connectWithWindow:(id)sender name:(NSString *)bookmark;
- (NSWindow *)						shownWindow;

- (IBAction)						about:(id)sender;
- (IBAction)						preferences:(id)sender;

- (IBAction)						connect:(id)sender;
- (IBAction)						showTrackers:(id)sender;
- (IBAction)						serverInfo:(id)sender;
- (IBAction)						chat:(id)sender;
- (IBAction)						news:(id)sender;
- (IBAction)						messages:(id)sender;
- (IBAction)						files:(id)sender;
- (IBAction)						transfers:(id)sender;
- (IBAction)						search:(id)sender;
- (IBAction)						console:(id)sender;
- (IBAction)						accounts:(id)sender;
- (IBAction)						saveChat:(id)sender;
- (IBAction)						getInfo:(id)sender;
- (IBAction)						postNews:(id)sender;
- (IBAction)						broadcast:(id)sender;
- (IBAction)						disconnect:(id)sender;

- (IBAction)						findPanel:(id)sender;
- (IBAction)						findNext:(id)sender;
- (IBAction)						findPrevious:(id)sender;
- (IBAction)						useSelectionForFind:(id)sender;
- (IBAction)						jumpToSelection:(id)sender;

- (IBAction)						largerText:(id)sender;
- (IBAction)						smallerText:(id)sender;

- (IBAction)						newFolder:(id)sender;
- (IBAction)						reload:(id)sender;
- (IBAction)						delete:(id)sender;
- (IBAction)						back:(id)sender;
- (IBAction)						forward:(id)sender;

- (IBAction)						addBookmark:(id)sender;
- (IBAction)						bookmark:(id)sender;

@end
