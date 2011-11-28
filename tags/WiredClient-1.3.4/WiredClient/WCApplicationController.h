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

@interface WCApplicationController : WIObject <GrowlApplicationBridgeDelegate> {
	IBOutlet NSMenu						*_bookmarksMenu;
	IBOutlet NSMenu						*_insertSmileyMenu;
	IBOutlet NSMenu						*_debugMenu;
	
	IBOutlet NSMenuItem					*_disconnectMenuItem;
	IBOutlet NSMenuItem					*_deleteMenuItem;
	
	IBOutlet SUUpdater					*_updater;
	
	NSString							*_clientVersion;
	NSMutableDictionary					*_smileys;
	NSArray								*_sortedSmileys;
	NSUInteger							_unread;
}


#define WCDateDidChange					@"WCDateDidChange"

#define WCApplicationSupportPath		@"~/Library/Application Support/Wired Client"


+ (WCApplicationController *)sharedController;

- (NSString *)clientVersion;

- (NSArray *)allSmileys;
- (NSString *)pathForSmiley:(NSString *)smiley;

- (IBAction)about:(id)sender;
- (IBAction)preferences:(id)sender;

- (IBAction)connect:(id)sender;

- (IBAction)bookmark:(id)sender;

- (IBAction)showDock:(id)sender;
- (IBAction)showTrackers:(id)sender;
- (IBAction)hideConnection:(id)sender;
- (IBAction)nextConnection:(id)sender;
- (IBAction)previousConnection:(id)sender;
- (IBAction)makeLayoutDefault:(id)sender;
- (IBAction)restoreLayoutToDefault:(id)sender;
- (IBAction)restoreAllLayoutsToDefault:(id)sender;

- (IBAction)releaseNotes:(id)sender;
- (IBAction)manual:(id)sender;

@end
