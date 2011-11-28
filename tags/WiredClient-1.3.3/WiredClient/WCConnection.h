/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#define WCServerProtocolVersion			1.1
#define WCTrackerProtocolVersion		1.0

#define WCControlPort					2000
#define WCTransferPort					2001
#define WCTrackerPort					2002

#define WCBonjourName					@"_wired._tcp."

#define WCDefaultLogin					@"guest"

#define WCMessageSeparator				@"\4"
#define WCFieldSeparator				@"\34"
#define WCGroupSeparator				@"\35"
#define WCRecordSeparator				@"\36"

#define WCMessageLength					3

#define WCBanCommand					@"BAN"
#define WCBannerCommand					@"BANNER"
#define WCBroadcastCommand				@"BROADCAST"
#define WCCategoriesCommand				@"CATEGORIES"
#define WCClearNewsCommand				@"CLEARNEWS"
#define WCClientCommand					@"CLIENT"
#define WCCommentCommand				@"COMMENT"
#define WCCreateUserCommand				@"CREATEUSER"
#define WCCreateGroupCommand			@"CREATEGROUP"
#define WCDeclineCommand				@"DECLINE"
#define WCDeleteCommand					@"DELETE"
#define WCDeleteUserCommand				@"DELETEUSER"
#define WCDeleteGroupCommand			@"DELETEGROUP"
#define WCEditUserCommand				@"EDITUSER"
#define WCEditGroupCommand				@"EDITGROUP"
#define WCFolderCommand					@"FOLDER"
#define WCGetCommand					@"GET"
#define WCGroupsCommand					@"GROUPS"
#define WCHelloCommand					@"HELLO"
#define WCIconCommand					@"ICON"
#define WCInfoCommand					@"INFO"
#define WCInviteCommand					@"INVITE"
#define WCJoinCommand					@"JOIN"
#define WCKickCommand					@"KICK"
#define WCLeaveCommand					@"LEAVE"
#define WCListCommand					@"LIST"
#define WCListRecursiveCommand			@"LISTRECURSIVE"
#define WCMeCommand						@"ME"
#define WCMoveCommand					@"MOVE"
#define WCMessageCommand				@"MSG"
#define WCNewsCommand					@"NEWS"
#define WCNickCommand					@"NICK"
#define WCPassCommand					@"PASS"
#define WCPingCommand					@"PING"
#define WCPostCommand					@"POST"
#define WCPrivateChatCommand			@"PRIVCHAT"
#define WCPrivilegesCommand				@"PRIVILEGES"
#define WCPutCommand					@"PUT"
#define WCReadUserCommand				@"READUSER"
#define WCReadGroupCommand				@"READGROUP"
#define WCSayCommand					@"SAY"
#define WCSearchCommand					@"SEARCH"
#define WCServersCommand				@"SERVERS"
#define WCStatCommand					@"STAT"
#define WCStatusCommand					@"STATUS"
#define WCTopicCommand					@"TOPIC"
#define WCTransferCommand				@"TRANSFER"
#define WCTypeCommand					@"TYPE"
#define WCUserCommand					@"USER"
#define WCUsersCommand					@"USERS"
#define WCWhoCommand					@"WHO"

#define WCConnectionDidConnect			@"WCConnectionDidConnect"
#define WCConnectionDidClose			@"WCConnectionDidClose"
#define WCConnectionWillTerminate		@"WCConnectionWillTerminate"
#define WCConnectionShouldTerminate		@"WCConnectionShouldTerminate"
#define WCConnectionDidTerminate		@"WCConnectionDidTerminate"

#define WCConnectionReceivedMessage		@"WCConnectionReceivedMessage"
#define WCConnectionReceivedError		@"WCConnectionReceivedError"
#define WCConnectionSentCommand			@"WCConnectionSentCommand"

#define WCArgumentsKey					@"WCArgumentsKey"
#define WCMessageKey					@"WCMessageKey"
#define WCErrorKey						@"WCErrorKey"


typedef uint32_t						WCProtocolInt32;
typedef uint64_t						WCProtocolInt64;

typedef WCProtocolInt32					WCProtocolMessage;				
typedef WCProtocolInt32					WCUserID;
typedef WCProtocolInt32					WCChatID;


@protocol WCConnection <NSObject>

- (void)addObserver:(id)target selector:(SEL)action name:(NSString *)name;
- (void)removeObserver:(id)target;
- (void)removeObserver:(id)target name:(NSString *)name;
- (void)postNotificationName:(NSString *)name;
- (void)postNotificationName:(NSString *)name object:(id)object;
- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo;

- (void)sendCommand:(NSString *)command;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3;
- (void)sendCommand:(NSString *)command withArguments:(NSArray *)arguments;
- (void)ignoreError:(WCProtocolMessage)error;

- (void)connect;
- (void)disconnect;
- (void)terminate;

- (WIURL *)URL;
- (WISocket *)socket;
- (BOOL)isConnected;
- (double)protocol;

@end
