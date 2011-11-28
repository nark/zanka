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

@class WCAccounts;

@interface WCAccountsController : NSObject {
	IBOutlet NSTableView			*_tableView;
	IBOutlet NSButton				*_addButton;
	IBOutlet NSButton				*_deleteButton;
	
	IBOutlet NSPopUpButton			*_typePopUpButton;
	IBOutlet NSTextField			*_nameTextField;
	IBOutlet NSTextField			*_passwordTextField;
	IBOutlet NSPopUpButton			*_groupPopUpButton;
	
	IBOutlet NSButton				*_getUserInfoButton;
	IBOutlet NSButton				*_broadcastButton;
	IBOutlet NSButton				*_postNewsButton;
	IBOutlet NSButton				*_clearNewsButton;
	IBOutlet NSButton				*_downloadButton;
	IBOutlet NSButton				*_uploadButton;
	IBOutlet NSButton				*_uploadAnywhereButton;
	IBOutlet NSButton				*_createFoldersButton;
	IBOutlet NSButton				*_moveFilesButton;
	IBOutlet NSButton				*_deleteFilesButton;
	IBOutlet NSButton				*_viewDropBoxesButton;
	IBOutlet NSButton				*_createAccountsButton;
	IBOutlet NSButton				*_editAccountsButton;
	IBOutlet NSButton				*_deleteAccountsButton;
	IBOutlet NSButton				*_elevatePrivilegesButton;
	IBOutlet NSButton				*_kickUsersButton;
	IBOutlet NSButton				*_banUsersButton;
	IBOutlet NSButton				*_cannotBeKickedButton;
	IBOutlet NSButton				*_setTopicButton;
	
//	IBOutlet NSTextField			*_downloadsTextField;
	IBOutlet NSTextField			*_downloadSpeedTextField;
//	IBOutlet NSTextField			*_uploadsTextField;
	IBOutlet NSTextField			*_uploadSpeedTextField;

	NSMutableArray					*_accounts;
	WCAccounts						*_users;
	WCAccounts						*_groups;
	BOOL							_selected;
	
	NSImage							*_userImage, *_groupImage;
	
	BOOL							_touched;
}


#define WCAccountsDidChange			@"WCAccountsDidChange"


+ (WCAccountsController *)accountsController;

- (void)awakeFromController;
- (BOOL)saveFromController;

- (IBAction)touch:(id)sender;
- (IBAction)add:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)selectType:(id)sender;
- (IBAction)selectGroup:(id)sender;

@end
