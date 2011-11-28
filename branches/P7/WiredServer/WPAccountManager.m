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

#import "WPAccountManager.h"
#import "WPError.h"

@implementation WPAccountManager

- (id)initWithUsersPath:(NSString *)usersPath groupsPath:(NSString *)groupsPath {
	self = [super init];
	
	_usersPath			= [usersPath retain];
	_usersDistPath		= [[usersPath stringByAppendingPathExtension:@"dist"] retain];
	_groupsPath			= [groupsPath retain];
	_groupsDistPath		= [[groupsPath stringByAppendingPathExtension:@"dist"] retain];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterShortStyle];

	return self;
}



- (void)dealloc {
	[_usersPath release];
	[_usersDistPath release];
	[_groupsPath release];
	[_groupsDistPath release];
	
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (WPAccountStatus)hasUserAccountWithName:(NSString *)name password:(NSString **)password {
	NSDictionary		*accounts, *account;
	NSString			*string;
	
	string = [NSString stringWithContentsOfFile:_usersPath];
	
	if(!string)
		return WPAccountFailed;
	
	if(![string hasPrefix:@"<?xml"])
		return WPAccountOldStyle;

	accounts = [NSDictionary dictionaryWithContentsOfFile:_usersPath];
	
	if(!accounts)
		return WPAccountFailed;
	
	account = [accounts objectForKey:name];
	
	if(!account)
		return WPAccountNotFound;
	
	*password = [account objectForKey:@"wired.account.password"];
	
	return WPAccountOK;
}



#pragma mark -

- (BOOL)setPassword:(NSString *)password forUserAccountWithName:(NSString *)name andWriteWithError:(WPError **)error {
	NSMutableDictionary		*accounts;
	
	accounts = [NSMutableDictionary dictionaryWithContentsOfFile:_usersPath];
	
	if(!accounts) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersReadFailed];
		
		return NO;
	}
	
	[[accounts objectForKey:name] setObject:[password SHA1] forKey:@"wired.account.password"];
	
	if(![accounts writeToFile:_usersPath atomically:YES]) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersWriteFailed];
		
		return NO;
	}
	
	return YES;
}



- (BOOL)createNewAdminUserAccountWithName:(NSString *)name password:(NSString *)password andWriteWithError:(WPError **)error {
	NSMutableDictionary		*accounts, *distAccounts, *account;
	
	accounts = [NSMutableDictionary dictionaryWithContentsOfFile:_usersPath];
	
	if(!accounts) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersReadFailed];
		
		return NO;
	}

	distAccounts = [NSMutableDictionary dictionaryWithContentsOfFile:_usersDistPath];
	
	if(!distAccounts) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersReadFailed];
		
		return NO;
	}
	
	account = [distAccounts objectForKey:@"admin"];
	
	if(!account) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersReadFailed];
		
		return NO;
	}
	
	[account setObject:[password SHA1] forKey:@"wired.account.password"];
	[accounts setObject:account forKey:name];
	
	if(![accounts writeToFile:_usersPath atomically:YES]) {
		*error = [WPError errorWithDomain:WPPreferencePaneErrorDomain code:WPPreferencePaneUsersWriteFailed];
		
		return NO;
	}
	
	return YES;
}

@end
