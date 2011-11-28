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

@class WCAccount, WCConnection;

@interface WCAccountEditor : WCWindowController {
	IBOutlet NSPopUpButton		*_typePopUpButton;
	IBOutlet NSMenuItem			*_userMenuItem;
	IBOutlet NSMenuItem			*_groupMenuItem;
	
    IBOutlet NSTextField		*_nameTextField;
    IBOutlet NSSecureTextField	*_passwordTextField;

	IBOutlet NSPopUpButton		*_groupPopUpButton;
	IBOutlet NSMenuItem			*_noneMenuItem;
	
    IBOutlet NSButton			*_postNewsButton;
    IBOutlet NSButton			*_clearNewsButton;
    IBOutlet NSButton			*_getUserInfoButton;
	IBOutlet NSButton			*_broadcastButton;

    IBOutlet NSButton			*_downloadButton;
    IBOutlet NSButton			*_uploadButton;
	IBOutlet NSButton			*_uploadAnywhereButton;
    IBOutlet NSButton			*_createFoldersButton;
    IBOutlet NSButton			*_moveButton;
    IBOutlet NSButton			*_deleteButton;
    IBOutlet NSButton			*_viewDropBoxButton;

    IBOutlet NSButton			*_createAccountsButton;
    IBOutlet NSButton			*_editAccountsButton;
    IBOutlet NSButton			*_deleteAccountsButton;
    IBOutlet NSButton			*_elevatePrivilegesButton;
    IBOutlet NSButton			*_kickUsersButton;
    IBOutlet NSButton			*_banUsersButton;
	IBOutlet NSButton			*_cannotBeKickedButton;
	
	IBOutlet NSTextField		*_downloadSpeedTextField;
	IBOutlet NSTextField		*_uploadSpeedTextField;
	
	IBOutlet NSButton			*_selectAllButton;
	IBOutlet NSButton			*_okButton;
	
	NSMutableArray				*_groups;
	
	WCAccount					*_account;

	NSString					*_password;
	NSString					*_group;
}


#define 						WCAccountEditorShouldShowUser	@"WCAccountEditorShouldShowUser"
#define 						WCAccountEditorShouldShowGroup	@"WCAccountEditorShouldShowGroup"


- (id)							initWithConnection:(WCConnection *)connection;
- (id)							initWithConnection:(WCConnection *)connection edit:(WCAccount *)account;

- (IBAction)					create:(id)sender;
- (IBAction)					edit:(id)sender;
- (IBAction)					selectAll:(id)sender;
- (IBAction)					type:(id)sender;
- (IBAction)					group:(id)sender;

@end
