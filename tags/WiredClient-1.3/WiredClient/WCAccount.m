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

#import "WCAccount.h"

@interface WCAccount(Private)

- (id)_initWithType:(WCAccountType)type;

- (void)_setPrivileges:(NSArray *)privileges;
- (void)_setName:(NSString *)name;
- (void)_setPassword:(NSString *)password;
- (void)_setGroup:(NSString *)group;

@end


@implementation WCAccount(Private)

- (id)_initWithType:(WCAccountType)type {
	self = [super init];

	_type = type;

	return self;
}



#pragma mark -

- (void)_setPrivileges:(NSArray *)privileges {
	[privileges retain];
	[_privileges release];

	_privileges = privileges;
}



- (void)_setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (void)_setPassword:(NSString *)password {
	[password retain];
	[_password release];

	_password = password;
}



- (void)_setGroup:(NSString *)group {
	[group retain];
	[_group release];

	_group = group;
}

@end


@implementation WCAccount

+ (id)userAccountWithPrivilegesArguments:(NSArray *)arguments {
	WCAccount	*account;
	
	account = [[self alloc] _initWithType:WCAccountUser];
	[account _setPrivileges:arguments];
	
	return [account autorelease];
}



+ (id)userAccountWithAccountsArguments:(NSArray *)arguments {
	WCAccount	*account;
	
	account = [[self alloc] _initWithType:WCAccountUser];
	[account _setName:[arguments safeObjectAtIndex:0]];
	
	return [account autorelease];
}



+ (id)groupAccountWithAccountsArguments:(NSArray *)arguments {
	WCAccount	*account;
	
	account = [[self alloc] _initWithType:WCAccountGroup];
	[account _setName:[arguments safeObjectAtIndex:0]];
	
	return [account autorelease];
}



+ (id)userAccountWithAccountArguments:(NSArray *)arguments {
	WCAccount	*account;
	
	account = [[self alloc] _initWithType:WCAccountUser];
	[account _setName:[arguments safeObjectAtIndex:0]];
	[account _setPassword:[arguments safeObjectAtIndex:1]];
	[account _setGroup:[arguments safeObjectAtIndex:2]];
	[account _setPrivileges:[arguments subarrayWithRange:NSMakeRange(3, [arguments count] - 3)]];
	
	return [account autorelease];
}



+ (id)groupAccountWithAccountArguments:(NSArray *)arguments {
	WCAccount	*account;
	
	account = [[self alloc] _initWithType:WCAccountGroup];
	[account _setName:[arguments safeObjectAtIndex:0]];
	[account _setPrivileges:[arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)]];
	
	return [account autorelease];
}



- (void)dealloc {
	[_name release];
	[_password release];
	[_group release];
	[_privileges release];

	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];

	WIDecode(coder, _type);
	WIDecode(coder, _name);
	WIDecode(coder, _privileges);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _type);
	WIEncode(coder, _name);
	WIEncode(coder, _privileges);
}



#pragma mark -

- (NSString *)description {
	return [NSSWF:@"<%@ %p>{name = %@}",
		[self className],
		self,
		[self name]];
}



#pragma mark -


- (WCAccountType)type {
	return _type;
}



#pragma mark -

- (NSString *)name {
	return _name;
}



- (NSString *)group {
	return _group;
}



- (NSString *)password {
	return _password;
}



- (BOOL)getUserInfo {
	return [[_privileges safeObjectAtIndex:0] isEqualToString:@"1"];
}



- (BOOL)broadcast {
	return [[_privileges safeObjectAtIndex:1] isEqualToString:@"1"];
}



- (BOOL)postNews {
	return [[_privileges safeObjectAtIndex:2] isEqualToString:@"1"];
}



- (BOOL)clearNews {
	return [[_privileges safeObjectAtIndex:3] isEqualToString:@"1"];
}



- (BOOL)download {
	return [[_privileges safeObjectAtIndex:4] isEqualToString:@"1"];
}



- (BOOL)upload {
	return [[_privileges safeObjectAtIndex:5] isEqualToString:@"1"];
}



- (BOOL)uploadAnywhere {
	return [[_privileges safeObjectAtIndex:6] isEqualToString:@"1"];
}



- (BOOL)createFolders {
	return [[_privileges safeObjectAtIndex:7] isEqualToString:@"1"];
}



- (BOOL)alterFiles {
	return [[_privileges safeObjectAtIndex:8] isEqualToString:@"1"];
}



- (BOOL)deleteFiles {
	return [[_privileges safeObjectAtIndex:9] isEqualToString:@"1"];
}



- (BOOL)viewDropBoxes {
	return [[_privileges safeObjectAtIndex:10] isEqualToString:@"1"];
}



- (BOOL)createAccounts {
	return [[_privileges safeObjectAtIndex:11] isEqualToString:@"1"];
}



- (BOOL)editAccounts {
	return [[_privileges safeObjectAtIndex:12] isEqualToString:@"1"];
}



- (BOOL)deleteAccounts {
	return [[_privileges safeObjectAtIndex:13] isEqualToString:@"1"];
}



- (BOOL)elevatePrivileges {
	return [[_privileges safeObjectAtIndex:14] isEqualToString:@"1"];
}



- (BOOL)kickUsers {
	return [[_privileges safeObjectAtIndex:15] isEqualToString:@"1"];
}



- (BOOL)banUsers {
	return [[_privileges safeObjectAtIndex:16] isEqualToString:@"1"];
}



- (BOOL)cannotBeKicked {
	return [[_privileges safeObjectAtIndex:17] isEqualToString:@"1"];
}



- (unsigned int)downloadSpeedLimit {
	return [[_privileges safeObjectAtIndex:18] unsignedIntValue];
}



- (unsigned int)uploadSpeedLimit {
	return [[_privileges safeObjectAtIndex:19] unsignedIntValue];
}



- (unsigned int)downloadLimit {
	return [[_privileges safeObjectAtIndex:20] unsignedIntValue];
}



- (unsigned int)uploadLimit {
	return [[_privileges safeObjectAtIndex:21] unsignedIntValue];
}



- (BOOL)setTopic {
	return [[_privileges safeObjectAtIndex:22] isEqualToString:@"1"];
}



#pragma mark -

- (NSComparisonResult)compareName:(WCAccount *)account {
	return [[self name] compare:[account name] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareType:(WCAccount *)account {
	if([self type] == WCAccountUser && [account type] == WCAccountGroup)
		return NSOrderedAscending;
	else if([self type] == WCAccountGroup && [account type] == WCAccountUser)
		return NSOrderedDescending;

	return [self compareName:account];
}

@end
