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

enum WCConnectionType {
	WCConnectionTypeServer					= 0,
	WCConnectionTypeTracker
};
typedef enum WCConnectionType				WCConnectionType;


@protocol WCConnectionErrorHandling

- (BOOL)									connectionShouldHandleError:(int)error;

@end


@class WCAccounts, WCPublicChat, WCConsole, WCError, WCMessages, WCAccount;
@class WCNews, WCSearch, WCSecureSocket, WCToolbar, WCTransfers, WCServer;
@class WCCache, WCServerInfo, WCTracker;

@interface WCConnection : NSObject {
	WCAccounts								*_accounts;
	WCPublicChat							*_chat;
	WCConsole								*_console;
	WCError									*_error;
	WCMessages								*_messages;
	WCNews									*_news;
	WCSearch								*_search;
	WCSecureSocket							*_socket;
	WCServerInfo							*_serverInfo;
	WCToolbar								*_toolbar;
	WCTransfers								*_transfers;
	
	WCCache									*_cache;
	WCServer								*_server;
	WCTracker								*_tracker;
	
	id										_sender;
	NSTimer									*_timer;
	WCConnectionType						_type;
	unsigned int							_uid;
	BOOL									_connected, _cancelled, _received;
}


#define WCServerProtocolVersion				1.1
#define WCTrackerProtocolVersion			1.0

#define WCMessageSeparator					@"\4"
#define WCFieldSeparator					@"\34"
#define WCGroupSeparator					@"\35"
#define WCRecordSeparator					@"\36"
#define WCMessageLength						3

#define WCBanCommand						@"BAN"
#define WCBannerCommand						@"BANNER"
#define WCBroadcastCommand					@"BROADCAST"
#define WCCategoriesCommand					@"CATEGORIES"
#define WCClearNewsCommand					@"CLEARNEWS"
#define WCClientCommand						@"CLIENT"
#define WCCommentCommand					@"COMMENT"
#define WCCreateUserCommand					@"CREATEUSER"
#define WCCreateGroupCommand				@"CREATEGROUP"
#define WCDeclineCommand					@"DECLINE"
#define WCDeleteCommand						@"DELETE"
#define WCDeleteUserCommand					@"DELETEUSER"
#define WCDeleteGroupCommand				@"DELETEGROUP"
#define WCEditUserCommand					@"EDITUSER"
#define WCEditGroupCommand					@"EDITGROUP"
#define WCFolderCommand						@"FOLDER"
#define WCGetCommand						@"GET"
#define WCGroupsCommand						@"GROUPS"
#define WCHelloCommand						@"HELLO"
#define WCIconCommand						@"ICON"
#define WCInfoCommand						@"INFO"
#define WCInviteCommand						@"INVITE"
#define WCJoinCommand						@"JOIN"
#define WCKickCommand						@"KICK"
#define WCLeaveCommand						@"LEAVE"
#define WCListCommand						@"LIST"
#define WCMeCommand							@"ME"
#define WCMoveCommand						@"MOVE"
#define WCMessageCommand					@"MSG"
#define WCNewsCommand						@"NEWS"
#define WCNickCommand						@"NICK"
#define WCPassCommand						@"PASS"
#define WCPingCommand						@"PING"
#define WCPostCommand						@"POST"
#define WCPrivateChatCommand				@"PRIVCHAT"
#define WCPrivilegesCommand					@"PRIVILEGES"
#define WCPutCommand						@"PUT"
#define WCReadUserCommand					@"READUSER"
#define WCReadGroupCommand					@"READGROUP"
#define WCSayCommand						@"SAY"
#define WCSearchCommand						@"SEARCH"
#define WCServersCommand					@"SERVERS"
#define WCStatCommand						@"STAT"
#define WCStatusCommand						@"STATUS"
#define WCTopicCommand						@"TOPIC"
#define WCTransferCommand					@"TRANSFER"
#define WCTypeCommand						@"TYPE"
#define WCUserCommand						@"USER"
#define WCUsersCommand						@"USERS"
#define WCWhoCommand						@"WHO"

#define WCConnectionHasAttached				@"WCConnectionHasAttached"
#define WCConnectionHasClosed				@"WCConnectionHasClosed"
#define WCConnectionShouldTerminate			@"WCConnectionShouldTerminate"
#define WCConnectionShouldCancel			@"WCConnectionShouldCancel"

#define WCConnectionGotServerError			@"WCConnectionGotServerError"
#define WCConnectionGotServerInfo			@"WCConnectionGotServerInfo"
#define WCConnectionServerInfoDidChange		@"WCConnectionServerInfoDidChange"
#define WCConnectionGotServerBanner			@"WCConnectionGotServerBanner"
#define WCConnectionServerBannerDidChange	@"WCConnectionServerBannerDidChange"
#define WCConnectionGotPrivileges			@"WCConnectionGotPrivileges"
#define WCConnectionPrivilegesDidChange		@"WCConnectionPrivilegesDidChange"

#define WCConnectionGotTrackerInfo			@"WCConnectionGotTrackerInfo"


- (id)										initServerConnectionWithURL:(NSURL *)url;
- (id)										initServerConnectionWithURL:(NSURL *)url name:(NSString *)name;
- (id)										initTrackerConnectionWithURL:(NSURL *)url tracker:(WCTracker *)tracker;

- (void)									sendCommand:(NSString *)command withSender:(id)sender;
- (void)									sendCommand:(NSString *)command withArgument:(NSString *)argument1 withSender:(id)sender;
- (void)									sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withSender:(id)sender;
- (void)									sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3 withSender:(id)sender;
- (void)									clearSender:(id)sender;
- (void)									receiveData:(NSData *)data;
	
- (WCAccounts *)							accounts;
- (WCPublicChat *)							chat;
- (WCConsole *)								console;
- (WCError *)								error;
- (WCMessages *)							messages;
- (WCNews *)								news;
- (WCSearch *)								search;
- (WCServerInfo *)							serverInfo;
- (WCSecureSocket *)						socket;
- (WCToolbar *)								toolbar;
- (WCTransfers *)							transfers;

- (WCConnectionType)						type;
- (WCCache *)								cache;
- (WCServer *)								server;
- (WCTracker *)								tracker;
- (NSString *)								name;
- (NSURL *)									URL;
- (WCAccount *)								account;
- (BOOL)									connected;
- (unsigned int)							uid;
- (double)									protocol;

@end
