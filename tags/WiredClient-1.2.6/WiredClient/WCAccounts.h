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

@class WCConnection, WCTableView;

@interface WCAccounts : WCWindowController {
	IBOutlet WCTableView				*_accountsTableView;

	IBOutlet NSProgressIndicator		*_progressIndicator;

	IBOutlet NSTextField				*_statusTextField;
	
	IBOutlet NSButton					*_addButton;
	IBOutlet NSButton					*_editButton;
	IBOutlet NSButton					*_deleteButton;
	IBOutlet NSButton					*_reloadButton;
	
	NSMutableArray						*_allAccounts, *_shownAccounts;
	NSImage								*_userImage, *_groupImage;
	int									_users, _groups;
}


#define WCAccountsShouldReload			@"WCAccountsShouldReload"
#define WCAccountsShouldAddUser			@"WCAccountsShouldAddUser"
#define WCAccountsShouldCompleteUsers	@"WCAccountsShouldCompleteUsers"
#define WCAccountsShouldAddGroup		@"WCAccountsShouldAddGroup"
#define WCAccountsShouldCompleteGroups	@"WCAccountsShouldCompleteGroups"


- (id)									initWithConnection:(WCConnection *)connection;

- (void)								update;
- (void)								updateStatus;
- (void)								updateButtons;
- (WCAccount *)							selectedAccount;
- (NSArray *)							selectedAccounts;

- (IBAction)							add:(id)sender;
- (IBAction)							edit:(id)sender;
- (IBAction)							delete:(id)sender;
- (IBAction)							reload:(id)sender;

@end
