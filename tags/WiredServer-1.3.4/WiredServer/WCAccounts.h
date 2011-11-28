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

enum WCAccountType {
	WCAccountUser			= 1,
	WCAccountGroup			= 2
};
typedef enum WCAccountType	WCAccountType;


@interface WCAccount : NSObject {
	NSMutableArray			*_fields;
	WCAccountType			_type;
}


- (id)initWithType:(WCAccountType)type;
- (id)initWithRecord:(NSString *)record type:(WCAccountType)type;
- (id)initWithName:(NSString *)name type:(WCAccountType)type;

- (void)setType:(WCAccountType)type;
- (WCAccountType)type;
- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setPassword:(NSString *)name;
- (NSString *)password;
- (void)setGroup:(NSString *)name;
- (NSString *)group;
- (void)setGetUserInfo:(BOOL)value;
- (BOOL)getUserInfo;
- (void)setBroadcast:(BOOL)value;
- (BOOL)broadcast;
- (void)setPostNews:(BOOL)value;
- (BOOL)postNews;
- (void)setClearNews:(BOOL)value;
- (BOOL)clearNews;
- (void)setDownload:(BOOL)value;
- (BOOL)download;
- (void)setUpload:(BOOL)value;
- (BOOL)upload;
- (void)setUploadAnywhere:(BOOL)value;
- (BOOL)uploadAnywhere;
- (void)setCreateFolders:(BOOL)value;
- (BOOL)createFolders;
- (void)setMoveFiles:(BOOL)value;
- (BOOL)moveFiles;
- (void)setDeleteFiles:(BOOL)value;
- (BOOL)deleteFiles;
- (void)setViewDropBoxes:(BOOL)value;
- (BOOL)viewDropBoxes;
- (void)setCreateAccounts:(BOOL)value;
- (BOOL)createAccounts;
- (void)setEditAccounts:(BOOL)value;
- (BOOL)editAccounts;
- (void)setDeleteAccounts:(BOOL)value;
- (BOOL)deleteAccounts;
- (void)setElevatePrivileges:(BOOL)value;
- (BOOL)elevatePrivileges;
- (void)setKickUsers:(BOOL)value;
- (BOOL)kickUsers;
- (void)setBanUsers:(BOOL)value;
- (BOOL)banUsers;
- (void)setCannotBeKicked:(BOOL)value;
- (BOOL)cannotBeKicked;
- (void)setDownloadSpeed:(int)value;
- (int)downloadSpeed;
- (void)setUploadSpeed:(int)value;
- (int)uploadSpeed;
- (void)setDownloads:(int)value;
- (int)downloads;
- (void)setUploads:(int)value;
- (int)uploads;
- (void)setSetTopic:(BOOL)value;
- (BOOL)setTopic;

@end


@interface WCAccounts : NSObject {
	NSMutableArray			*_accounts;
	NSRecursiveLock			*_lock;
	WIDateFormatter			*_dateFormatter;
}


- (id)initWithString:(NSString *)string type:(WCAccountType)type;
- (id)initWithData:(NSData *)data type:(WCAccountType)type;
- (id)initWithContentsOfFile:(NSString *)file type:(WCAccountType)type;
- (id)initWithContentsOfURL:(NSURL *)url type:(WCAccountType)type;

- (void)addAccount:(WCAccount *)account;
- (void)deleteAccount:(WCAccount *)account;

- (NSUInteger)count;
- (NSArray *)accounts;
- (WCAccount *)accountWithName:(NSString *)name;

- (BOOL)writeToFile:(NSString *)file;
- (BOOL)writeToURL:(NSURL *)url;

@end
