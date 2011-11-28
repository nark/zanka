/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

#import "WCConnection.h"

@class WCServer, WCCache, WCAccount;
@class WCLink;
@class WCAccounts, WCPublicChat, WCConsole, WCMessages, WCNews, WCSearch, WCServerInfo, WCTransfers;

@interface WCServerConnection : WIWindowController <WCConnection> {
	IBOutlet NSTextField							*_addressTextField;
	IBOutlet NSTextField							*_loginTextField;
	IBOutlet NSSecureTextField						*_passwordTextField;
	
	IBOutlet NSProgressIndicator					*_progressIndicator;
	
	IBOutlet NSButton								*_connectButton;

	NSUInteger										_connectionID;
	WCUserID										_userID;
	
	NSDictionary									*_bookmark;
	
	WCServer										*_server;
	WCCache											*_cache;
	
	WCLink											*_link;
	NSNotificationCenter							*_notificationCenter;
	
	WCAccounts										*_accounts;
	WCPublicChat									*_chat;
	WCConsole										*_console;
	WCMessages										*_messages;
	WCNews											*_news;
	WCSearch										*_search;
	WCServerInfo									*_serverInfo;
	WCTransfers										*_transfers;
	
	WCProtocolMessage								_ignoreErrorMessage;
	NSTimeInterval									_ignoreErrorTime;
	
	BOOL											_sentLogin;
	BOOL											_loginFailed;
	BOOL											_dismissingWindow;
	BOOL											_closingWindow;
	BOOL											_disconnecting;
	BOOL											_manuallyReconnecting;
	BOOL											_shouldAutoReconnect;
	BOOL											_autoReconnecting;
	BOOL											_hidden;
}


#define WCServerConnectionWillReconnect				@"WCServerConnectionWillReconnect"
#define WCServerConnectionShouldHide				@"WCServerConnectionShouldHide"
#define WCServerConnectionShouldUnhide				@"WCServerConnectionShouldUnhide"
#define WCServerConnectionTriggeredEvent			@"WCServerConnectionTriggeredEvent"

#define WCServerConnectionShouldLoadWindowTemplate	@"WCServerConnectionShouldLoadWindowTemplate"
#define WCServerConnectionShouldSaveWindowTemplate	@"WCServerConnectionShouldSaveWindowTemplate"

#define WCServerConnectionServerInfoDidChange		@"WCServerConnectionServerInfoDidChange"
#define WCServerConnectionLoggedIn					@"WCServerConnectionLoggedIn"
#define WCServerConnectionBannerDidChange			@"WCServerConnectionBannerDidChange"
#define WCServerConnectionPrivilegesDidChange		@"WCServerConnectionPrivilegesDidChange"

#define WCServerConnectionReceivedServerInfo		@"WCServerConnectionReceivedServerInfo"
#define WCServerConnectionReceivedSelf				@"WCServerConnectionReceivedSelf"
#define WCServerConnectionReceivedPing				@"WCServerConnectionReceivedPing"
#define WCServerConnectionReceivedBanner			@"WCServerConnectionReceivedBanner"
#define WCServerConnectionReceivedPrivileges		@"WCServerConnectionReceivedPrivileges"

#define WCAccountEditorReceivedUser					@"WCAccountEditorReceivedUser"
#define WCAccountEditorReceivedGroup				@"WCAccountEditorReceivedGroup"

#define WCAccountsReceivedUser						@"WCAccountsReceivedUser"
#define WCAccountsCompletedUsers					@"WCAccountsCompletedUsers"
#define WCAccountsReceivedGroup						@"WCAccountsReceivedGroup"
#define WCAccountsCompletedGroups					@"WCAccountsCompletedGroups"

#define WCChatReceivedUser							@"WCChatShouldAddUser"
#define WCChatCompletedUsers						@"WCChatShouldCompleteUsers"
#define WCChatReceivedUserJoin						@"WCChatReceivedUserJoin"
#define WCChatReceivedUserLeave						@"WCChatReceivedUserLeave"
#define WCChatReceivedUserChange					@"WCChatReceivedUserChange"
#define WCChatReceivedUserIconChange				@"WCChatReceivedUserIconChange"
#define WCChatReceivedUserKick						@"WCChatReceivedUserKick"
#define WCChatReceivedUserBan						@"WCChatReceivedUserBan"
#define WCChatReceivedChat							@"WCChatReceivedChat"
#define WCChatReceivedActionChat					@"WCChatReceivedActionChat"
#define WCChatReceivedTopic							@"WCChatReceivedTopic"

#define WCFileInfoReceivedFileInfo					@"WCFileInfoReceivedFileInfo"

#define WCFilesReceivedFile							@"WCFilesReceivedFile"
#define WCFilesCompletedFiles						@"WCFilesCompletedFiles"

#define WCMessagesReceivedMessage					@"WCMessagesReceivedMessage"
#define WCMessagesReceivedBroadcast					@"WCMessagesReceivedBroadcast"

#define WCNewsShouldAddNews							@"WCNewsShouldAddNews"
#define WCNewsShouldCompleteNews					@"WCNewsShouldCompleteNews"
#define WCNewsShouldAddNewNews						@"WCNewsShouldAddNewNews"

#define WCPrivateChatReceivedCreate					@"WCPrivateChatReceivedCreate"
#define WCPrivateChatReceivedInvite					@"WCPrivateChatReceivedInvite"
#define WCPrivateChatReceivedDecline				@"WCPrivateChatReceivedDecline"

#define WCSearchReceivedFile						@"WCSearchReceivedFile"
#define WCSearchCompletedFiles						@"WCSearchCompletedFiles"

#define WCTransfersReceivedTransferStart			@"WCTransfersReceivedTransferStart"
#define WCTransfersReceivedQueueUpdate				@"WCTransfersReceivedQueueUpdate"

#define WCUserInfoReceivedUserInfo					@"WCUserInfoReceivedUserInfo"

#define WCServerConnectionEventConnectionKey		@"WCServerConnectionEventConnectionKey"
#define WCServerConnectionEventInfo1Key				@"WCServerConnectionEventInfo1Key"
#define WCServerConnectionEventInfo2Key				@"WCServerConnectionEventInfo2Key"


+ (id)serverConnection;
+ (id)serverConnectionWithURL:(WIURL *)url;
+ (id)serverConnectionWithURL:(WIURL *)url bookmark:(NSDictionary *)bookmark;

- (IBAction)connect:(id)sender;

- (void)reconnect;
- (void)hide;
- (void)unhide;

- (void)triggerEvent:(int)event;
- (void)triggerEvent:(int)event info1:(id)info1;
- (void)triggerEvent:(int)event info1:(id)info1 info2:(id)info2;

- (BOOL)isDisconnecting;
- (BOOL)isReconnecting;
- (BOOL)isManuallyReconnecting;
- (BOOL)isAutoReconnecting;
- (BOOL)isHidden;
- (void)setBookmark:(NSDictionary *)bookmark;
- (NSUInteger)connectionID;
- (WCUserID)userID;
- (NSDictionary *)bookmark;
- (NSString *)name;
- (NSString *)identifier;
- (WCAccount *)account;
- (WCServer *)server;
- (WCCache *)cache;

- (WCAccounts *)accounts;
- (WCPublicChat *)chat;
- (WCConsole *)console;
- (WCMessages *)messages;
- (WCNews *)news;
- (WCSearch *)search;
- (WCServerInfo *)serverInfo;
- (WCTransfers *)transfers;

@end
