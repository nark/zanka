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

enum _WCAccountType {
	WCAccountUser,
	WCAccountGroup
};
typedef enum _WCAccountType		WCAccountType;


@interface WCAccount : WIObject <NSCoding> {
	WCAccountType				_type;
	NSString					*_name;
	NSString					*_password;
	NSString					*_group;
	NSArray						*_privileges;
}


+ (id)userAccountWithPrivilegesArguments:(NSArray *)arguments;
+ (id)userAccountWithAccountsArguments:(NSArray *)arguments;
+ (id)groupAccountWithAccountsArguments:(NSArray *)arguments;
+ (id)userAccountWithAccountArguments:(NSArray *)arguments;
+ (id)groupAccountWithAccountArguments:(NSArray *)arguments;

- (WCAccountType)type;

- (NSString *)name;
- (NSString *)group;
- (NSString *)password;
- (BOOL)getUserInfo;
- (BOOL)broadcast;
- (BOOL)postNews;
- (BOOL)clearNews;
- (BOOL)download;
- (BOOL)upload;
- (BOOL)uploadAnywhere;
- (BOOL)createFolders;
- (BOOL)alterFiles;
- (BOOL)deleteFiles;
- (BOOL)viewDropBoxes;
- (BOOL)createAccounts;
- (BOOL)editAccounts;
- (BOOL)deleteAccounts;
- (BOOL)elevatePrivileges;
- (BOOL)kickUsers;
- (BOOL)banUsers;
- (BOOL)cannotBeKicked;
- (NSUInteger)downloadSpeedLimit;
- (NSUInteger)uploadSpeedLimit;
- (NSUInteger)downloadLimit;
- (NSUInteger)uploadLimit;
- (BOOL)setTopic;

@end
