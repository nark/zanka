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

#import <Cocoa/Cocoa.h>
#import "WCWindowController.h"

@class WCConnection, WCURLTextView, WCSplitView, WCTypeAheadTableView;

@protocol WCTableViewMenuValidation, WCTableViewInfoCopying;

@protocol WCGetInfoValidation

- (IBAction)						info:(id)sender;

- (BOOL)							canGetInfo;

@end

@interface WCChat : WCWindowController <WCGetInfoValidation, WCTableViewInfoCopying> {
	IBOutlet NSScrollView			*_chatOutputScrollView;
	IBOutlet WCURLTextView			*_chatOutputTextView;
	IBOutlet NSTextView				*_chatInputTextView;
	
	IBOutlet WCSplitView			*_chatSplitView;
	IBOutlet WCSplitView			*_userListSplitView;
	IBOutlet WCTypeAheadTableView	*_userListTableView;
	
	IBOutlet NSButton				*_privateMessageButton;
	IBOutlet NSButton				*_infoButton;

	IBOutlet NSTableColumn			*_nickTableColumn;
	
	NSMutableArray					*_commandHistory;
	unsigned int					_currentCommand;
	
	NSMutableDictionary				*_allUsers, *_shownUsers;
	NSArray							*_sortedUsers;

	unsigned int					_cid;
}


#define								WCChatShouldAddUser				@"WCChatShouldAddUser"
#define								WCChatShouldCompleteUsers		@"WCChatShouldCompleteUsers"
#define								WCChatShouldReloadListing		@"WCChatShouldReloadListing"
#define								WCUserHasJoined					@"WCUserHasJoined"
#define								WCUserHasLeft					@"WCUserHasLeft"
#define								WCUserHasChanged				@"WCUserHasChanged"
#define								WCUserWasKicked					@"WCUserWasKicked"
#define								WCUserWasBanned					@"WCUserWasBanned"
#define								WCChatShouldPrintChat			@"WCChatShouldPrintChat"
#define								WCChatShouldPrintAction			@"WCChatShouldPrintAction"
		
#define								WCChatPrepend					13

#define								WCDragUser						@"WCDragUser"


- (id)								initWithConnection:(WCConnection *)connection nib:(NSString *)nib;

- (void)							update;
- (void)							updateButtons;
- (void)							saveChatToURL:(NSURL *)url;
- (NSMutableDictionary *)			users;
- (unsigned int)					cid;
		
- (IBAction)						sendPrivateMessage:(id)sender;
- (IBAction)						info:(id)sender;
- (IBAction)						ignore:(id)sender;
- (IBAction)						unignore:(id)sender;
	
- (void)							printEvent:(NSString *)argument;
- (BOOL)							parseCommand:(NSString *)argument;
	
@end
