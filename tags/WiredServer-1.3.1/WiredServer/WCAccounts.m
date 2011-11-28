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

#import "WCAccounts.h"

@implementation WCAccount

- (id)initWithType:(WCAccountType)type {
	self = [super init];
	
	_fields = [[NSMutableArray alloc] init];
	_type = type;
	
	return self;
}



- (id)initWithRecord:(NSString *)record type:(WCAccountType)type {
	self = [self initWithType:type];
	
	[_fields setArray:[record componentsSeparatedByString:@":"]];
	
	if([self type] == WCAccountGroup) {
		[_fields insertObject:@"" atIndex:1];
		[_fields insertObject:@"" atIndex:1];
	}
	
	return self;
}



- (id)initWithName:(NSString *)name type:(WCAccountType)type {
	return [self initWithRecord:[NSSWF:@"%@:::1:0:1:0:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0", name]
						   type:type];
}



- (void)dealloc {
	[_fields release];

	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	NSMutableArray  *fields;
	
	fields = [[_fields mutableCopy] autorelease];
	
	if([self type] == WCAccountGroup) {
		[fields removeObjectAtIndex:1];
		[fields removeObjectAtIndex:1];
	}

	return [fields componentsJoinedByString:@":"];
}



#pragma mark -

- (void)setType:(WCAccountType)type {
	_type = type;
}



- (WCAccountType)type {
	return _type;
}



- (void)setName:(NSString *)name {
	[_fields replaceObjectAtIndex:0 withObject:name];
}



- (NSString *)name {
	return [_fields stringAtIndex:0];
}



- (void)setPassword:(NSString *)password {
	if([self type] == WCAccountUser) {
		if([password length] > 0 && ![password isEqualToString:[self password]])
			password = [password SHA1];
		
		[_fields replaceObjectAtIndex:1 withObject:password];
	}
}



- (NSString *)password {
	if([self type] == WCAccountGroup)
		return @"";
	
	return [_fields stringAtIndex:1];
}



- (void)setGroup:(NSString *)name {
	if([self type] == WCAccountUser)
		[_fields replaceObjectAtIndex:2 withObject:name];
}



- (NSString *)group {
	if([self type] == WCAccountGroup)
		return @"";

	return [_fields stringAtIndex:2];
}



- (void)setGetUserInfo:(BOOL)value {
	[_fields replaceObjectAtIndex:3 withObject:value ? @"1" : @"0"];
}



- (BOOL)getUserInfo {
	return [[_fields stringAtIndex:3] isEqualToString:@"1"];
}



- (void)setBroadcast:(BOOL)value {
	[_fields replaceObjectAtIndex:4 withObject:value ? @"1" : @"0"];
}



- (BOOL)broadcast {
	return [[_fields stringAtIndex:4] isEqualToString:@"1"];
}



- (void)setPostNews:(BOOL)value {
	[_fields replaceObjectAtIndex:5 withObject:value ? @"1" : @"0"];
}



- (BOOL)postNews {
	return [[_fields stringAtIndex:5] isEqualToString:@"1"];
}



- (void)setClearNews:(BOOL)value {
	[_fields replaceObjectAtIndex:6 withObject:value ? @"1" : @"0"];
}



- (BOOL)clearNews {
	return [[_fields stringAtIndex:6] isEqualToString:@"1"];
}



- (void)setDownload:(BOOL)value {
	[_fields replaceObjectAtIndex:7 withObject:value ? @"1" : @"0"];
}



- (BOOL)download {
	return [[_fields stringAtIndex:7] isEqualToString:@"1"];
}



- (void)setUpload:(BOOL)value {
	[_fields replaceObjectAtIndex:8 withObject:value ? @"1" : @"0"];
}



- (BOOL)upload {
	return [[_fields stringAtIndex:8] isEqualToString:@"1"];
}



- (void)setUploadAnywhere:(BOOL)value {
	[_fields replaceObjectAtIndex:9 withObject:value ? @"1" : @"0"];
}



- (BOOL)uploadAnywhere {
	return [[_fields stringAtIndex:9] isEqualToString:@"1"];
}



- (void)setCreateFolders:(BOOL)value {
	[_fields replaceObjectAtIndex:10 withObject:value ? @"1" : @"0"];
}



- (BOOL)createFolders {
	return [[_fields stringAtIndex:10] isEqualToString:@"1"];
}



- (void)setMoveFiles:(BOOL)value {
	[_fields replaceObjectAtIndex:11 withObject:value ? @"1" : @"0"];
}



- (BOOL)moveFiles {
	return [[_fields stringAtIndex:11] isEqualToString:@"1"];
}



- (void)setDeleteFiles:(BOOL)value {
	[_fields replaceObjectAtIndex:12 withObject:value ? @"1" : @"0"];
}



- (BOOL)deleteFiles {
	return [[_fields stringAtIndex:12] isEqualToString:@"1"];
}



- (void)setViewDropBoxes:(BOOL)value {
	[_fields replaceObjectAtIndex:13 withObject:value ? @"1" : @"0"];
}



- (BOOL)viewDropBoxes {
	return [[_fields stringAtIndex:13] isEqualToString:@"1"];
}



- (void)setCreateAccounts:(BOOL)value {
	[_fields replaceObjectAtIndex:14 withObject:value ? @"1" : @"0"];
}



- (BOOL)createAccounts {
	return [[_fields stringAtIndex:14] isEqualToString:@"1"];
}



- (void)setEditAccounts:(BOOL)value {
	[_fields replaceObjectAtIndex:15 withObject:value ? @"1" : @"0"];
}



- (BOOL)editAccounts {
	return [[_fields stringAtIndex:15] isEqualToString:@"1"];
}



- (void)setDeleteAccounts:(BOOL)value {
	[_fields replaceObjectAtIndex:16 withObject:value ? @"1" : @"0"];
}



- (BOOL)deleteAccounts {
	return [[_fields stringAtIndex:16] isEqualToString:@"1"];
}



- (void)setElevatePrivileges:(BOOL)value {
	[_fields replaceObjectAtIndex:17 withObject:value ? @"1" : @"0"];
}



- (BOOL)elevatePrivileges {
	return [[_fields stringAtIndex:17] isEqualToString:@"1"];
}



- (void)setKickUsers:(BOOL)value {
	[_fields replaceObjectAtIndex:18 withObject:value ? @"1" : @"0"];
}



- (BOOL)kickUsers {
	return [[_fields stringAtIndex:18] isEqualToString:@"1"];
}



- (void)setBanUsers:(BOOL)value {
	[_fields replaceObjectAtIndex:19 withObject:value ? @"1" : @"0"];
}



- (BOOL)banUsers {
	return [[_fields stringAtIndex:19] isEqualToString:@"1"];
}



- (void)setCannotBeKicked:(BOOL)value {
	[_fields replaceObjectAtIndex:20 withObject:value ? @"1" : @"0"];
}



- (BOOL)cannotBeKicked {
	return [[_fields stringAtIndex:20] isEqualToString:@"1"];
}



- (void)setDownloadSpeed:(int)value {
	[_fields replaceObjectAtIndex:21 withObject:[NSSWF:@"%d", value]];
}



- (int)downloadSpeed {
	return [[_fields stringAtIndex:21] intValue];
}



- (void)setUploadSpeed:(int)value {
	[_fields replaceObjectAtIndex:22 withObject:[NSSWF:@"%d", value]];
}



- (int)uploadSpeed {
	return [[_fields stringAtIndex:22] intValue];
}



- (void)setDownloads:(int)value {
	[_fields replaceObjectAtIndex:23 withObject:[NSSWF:@"%d", value]];
}



- (int)downloads {
	return [[_fields stringAtIndex:23] intValue];
}



- (void)setUploads:(int)value {
	[_fields replaceObjectAtIndex:24 withObject:[NSSWF:@"%d", value]];
}



- (int)uploads {
	return [[_fields stringAtIndex:24] intValue];
}



- (void)setSetTopic:(BOOL)value {
	[_fields replaceObjectAtIndex:25 withObject:value ? @"1" : @"0"];
}



- (BOOL)setTopic {
	return [[_fields stringAtIndex:25] isEqualToString:@"1"];
}



#pragma mark -

- (NSComparisonResult)compareName:(WCAccount *)other {
	return [[self name] compare:[other name] options:NSCaseInsensitiveSearch | NSNumericSearch];
}

@end



@implementation WCAccounts

- (id)init {
	self = [super init];
	
	_accounts = [[NSMutableArray alloc] init];
	_lock = [[NSRecursiveLock alloc] init];
	
	return self;
}



- (id)initWithString:(NSString *)string type:(WCAccountType)type {
	NSEnumerator	*enumerator;
	NSString		*line;
	WCAccount		*account;
	
	self = [self init];
	
	enumerator = [[string componentsSeparatedByString:@"\n"] objectEnumerator];
	
	while((line = [enumerator nextObject])) {
		if([line hasPrefix:@"#"] || [line length] == 0)
			continue;
		
		account = [[WCAccount alloc] initWithRecord:line type:type];
		
		if(account) {
			[_accounts addObject:account];
			[account release];
		}
	}
	
	return self;
}



- (id)initWithData:(NSData *)data type:(WCAccountType)type {
	return [self initWithString:[NSString stringWithData:data encoding:NSUTF8StringEncoding] type:type];
}



- (id)initWithContentsOfFile:(NSString *)file type:(WCAccountType)type {
	return [self initWithData:[NSData dataWithContentsOfFile:file] type:type];
}



- (id)initWithContentsOfURL:(NSURL *)url type:(WCAccountType)type {
	return [self initWithData:[NSData dataWithContentsOfURL:url] type:type];
}



- (void)dealloc {
	[_accounts release];
	[_lock release];
	
	[super dealloc];
}



#pragma mark -

- (void)addAccount:(WCAccount *)account {
	[_lock lock];
	[_accounts addObject:account];
	[_lock unlock];
}



- (void)deleteAccount:(WCAccount *)account {
	[_lock lock];
	[_accounts removeObject:account];
	[_lock unlock];
}



#pragma mark -

- (unsigned int)count {
	return [_accounts count];
}



- (NSArray *)accounts {
	return _accounts;
}



- (WCAccount *)accountWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCAccount		*account, *result = NULL;
	
	[_lock lock];
	
	enumerator = [[self accounts] objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([[account name] isEqualToString:name]) {
			result = account;
			
			break;
		}
	}
	
	[_lock unlock];
	
	return result;
}



#pragma mark -

- (BOOL)writeToFile:(NSString *)file {
	NSEnumerator		*enumerator;
	NSMutableString		*string;
	WCAccount			*account;
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:file]) {
		[[NSFileManager defaultManager] createFileAtPath:file
												contents:NULL
											  attributes:NULL];
	}
	
	string = [NSMutableString string];
	[string appendFormat:WCLS(@"# This file was generated by %@ at %@", @"File comment (application, date)"),
		[[self bundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
		[[NSDate date] fullDateStringWithSeconds:YES]];
	[string appendString:@"\n"];
	
	enumerator = [[_accounts sortedArrayUsingSelector:@selector(compareName:)] objectEnumerator];
	
	while((account = [enumerator nextObject]))
		[string appendFormat:@"%@\n", [account description]];
	
	return [[string dataUsingEncoding:NSUTF8StringEncoding] writeToFile:file atomically:YES];
}



- (BOOL)writeToURL:(NSURL *)url {
	if(![url isFileURL]) {
		NSLog(@"*** [%@ writeToURL:]: remote URLs not supported", self);
		
		return NO;
	}
	
	return [self writeToFile:[url path]];
}

@end
