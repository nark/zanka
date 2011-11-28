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

@class WCConnection, WCSecureSocket, WCServer;

@interface WCClient : NSObject {
	WCConnection				*_connection;
	WCSecureSocket				*_socket;
	WCServer					*_server;
	
	NSTimer						*_timer;
	
	BOOL						_banner;
}


#define							WCPermissionWasDenied	@"WCPermissionWasDenied"

#define							WCLoginTimeOut			30

#define							WCMessageSeparator		@"\4"
#define							WCFieldSeparator		@"\34"
#define							WCGroupSeparator		@"\35"
#define							WCRecordSeparator		@"\36"
#define							WCMessageLength			3

#define							WCBanCommand			@"BAN"
#define							WCBroadcastCommand		@"BROADCAST"
#define							WCClearNewsCommand		@"CLEARNEWS"
#define							WCClientCommand			@"CLIENT"
#define							WCCreateUserCommand		@"CREATEUSER"
#define							WCCreateGroupCommand	@"CREATEGROUP"
#define							WCDeclineCommand		@"DECLINE"
#define							WCDeleteCommand			@"DELETE"
#define							WCDeleteUserCommand		@"DELETEUSER"
#define							WCDeleteGroupCommand	@"DELETEGROUP"
#define							WCEditUserCommand		@"EDITUSER"
#define							WCEditGroupCommand		@"EDITGROUP"
#define							WCFolderCommand			@"FOLDER"
#define							WCGetCommand			@"GET"
#define							WCGroupsCommand			@"GROUPS"
#define							WCHelloCommand			@"HELLO"
#define							WCIconCommand			@"ICON"
#define							WCInfoCommand			@"INFO"
#define							WCInviteCommand			@"INVITE"
#define							WCJoinCommand			@"JOIN"
#define							WCKickCommand			@"KICK"
#define							WCLeaveCommand			@"LEAVE"
#define							WCListCommand			@"LIST"
#define							WCMeCommand				@"ME"
#define							WCMoveCommand			@"MOVE"
#define							WCMessageCommand		@"MSG"
#define							WCNewsCommand			@"NEWS"
#define							WCNickCommand			@"NICK"
#define							WCPassCommand			@"PASS"
#define							WCPingCommand			@"PING"
#define							WCPostCommand			@"POST"
#define							WCPrivateChatCommand	@"PRIVCHAT"
#define							WCPrivilegesCommand		@"PRIVILEGES"
#define							WCPutCommand			@"PUT"
#define							WCReadUserCommand		@"READUSER"
#define							WCReadGroupCommand		@"READGROUP"
#define							WCSayCommand			@"SAY"
#define							WCSearchCommand			@"SEARCH"
#define							WCStatCommand			@"STAT"
#define							WCTransferCommand		@"TRANSFER"
#define							WCUserCommand			@"USER"
#define							WCUsersCommand			@"USERS"
#define							WCWhoCommand			@"WHO"


- (id)							initWithConnection:(WCConnection *)connection type:(unsigned int)type server:(WCServer *)server;

- (void)						connect:(NSURL *)url;
- (BOOL)						connected;

- (WCSecureSocket *)			socket;
- (BOOL)						banner;

- (int)							read;

- (void)						sendCommand:(NSString *)command;
- (void)						sendCommand:(NSString *)command withArgument:(NSString *)argument;

@end
