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

@class WCAccounts, WCPublicChat, WCClient, WCConsole, WCError, WCMessages, WCAccount;
@class WCNews, WCSearch, WCSecureSocket, WCToolbar, WCTransfers, WCServer, WCCache;
@class WCServerInfo;

@interface WCConnection : NSObject {
	WCAccounts						*_accounts;
	WCPublicChat					*_chat;
	WCClient						*_client;
	WCConsole						*_console;
	WCError							*_error;
	WCMessages						*_messages;
	WCNews							*_news;
	WCSearch						*_search;
	WCServerInfo					*_serverInfo;
	WCToolbar						*_toolbar;
	WCTransfers						*_transfers;
	
	WCCache							*_cache;
	WCServer						*_server;
}


#define								WCProtocolVersion					1.0

#define								WCConnectionHasAttached				@"WCConnectionHasAttached"
#define								WCConnectionHasClosed				@"WCConnectionHasClosed"
#define								WCConnectionShouldTerminate			@"WCConnectionShouldTerminate"
#define								WCConnectionDidBecomeActive			@"WCConnectionDidBecomeActive"

#define								WCConnectionGotServerInfo			@"WCConnectionGotServerInfo"
#define								WCConnectionGotPrivileges			@"WCConnectionGotPrivileges"
#define								WCConnectionPrivilegesDidChange		@"WCConnectionPrivilegesDidChange"


- (id)								initWithURL:(NSURL *)url;
- (id)								initWithURL:(NSURL *)url name:(NSString *)name;

- (WCAccounts *)					accounts;
- (WCPublicChat *)					chat;
- (WCClient *)						client;
- (WCConsole *)						console;
- (WCError *)						error;
- (WCMessages *)					messages;
- (WCNews *)						news;
- (WCSearch *)						search;
- (WCServerInfo *)					serverInfo;
- (WCToolbar *)						toolbar;
- (WCTransfers *)					transfers;

- (WCCache *)						cache;
- (WCServer *)						server;
- (NSString *)						name;
- (NSURL *)							URL;
- (WCAccount *)						account;

@end
