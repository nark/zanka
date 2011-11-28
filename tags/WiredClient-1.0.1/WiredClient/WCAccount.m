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

#import "WCAccount.h"

@implementation WCAccount

- (id)initWithType:(unsigned int)type {
	self = [super init];
	
	// --- get parameters
	_type = type;
	
	return self;
}



- (void)dealloc {
	[_name release];
	[_privileges release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_type];

	_name		= [[coder decodeObject] retain];
	_privileges	= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_type];
	
	[coder encodeObject:_name];
	[coder encodeObject:_privileges];
}



#pragma mark -


- (void)setType:(unsigned int)value {
	_type = value;
}



- (unsigned int)type {
	return _type;
}



#pragma mark -

- (void)setName:(NSString *)value {
	[value retain];
	[_name release];
	
	_name = value;
}



- (NSString *)name {
	return _name;
}



#pragma mark -

- (void)setPrivileges:(NSArray *)value {
	[value retain];
	[_privileges release];
	
	_privileges = value;
}



- (NSArray *)privileges {
	return _privileges;
}



#pragma mark -

- (BOOL)getUserInfo {
	return [[_privileges objectAtIndex:0] isEqualToString:@"1"];
}



- (BOOL)broadcast {
	return [[_privileges objectAtIndex:1] isEqualToString:@"1"];
}



- (BOOL)postNews {
	return [[_privileges objectAtIndex:2] isEqualToString:@"1"];
}



- (BOOL)clearNews {
	return [[_privileges objectAtIndex:3] isEqualToString:@"1"];
}



- (BOOL)download {
	return [[_privileges objectAtIndex:4] isEqualToString:@"1"];
}



- (BOOL)upload {
	return [[_privileges objectAtIndex:5] isEqualToString:@"1"];
}



- (BOOL)uploadAnywhere {
	return [[_privileges objectAtIndex:6] isEqualToString:@"1"];
}



- (BOOL)createFolders {
	return [[_privileges objectAtIndex:7] isEqualToString:@"1"];
}



- (BOOL)moveFiles {
	return [[_privileges objectAtIndex:8] isEqualToString:@"1"];
}



- (BOOL)deleteFiles {
	return [[_privileges objectAtIndex:9] isEqualToString:@"1"];
}



- (BOOL)viewDropBoxes {
	return [[_privileges objectAtIndex:10] isEqualToString:@"1"];
}



- (BOOL)createAccounts {
	return [[_privileges objectAtIndex:11] isEqualToString:@"1"];
}



- (BOOL)editAccounts {
	return [[_privileges objectAtIndex:12] isEqualToString:@"1"];
}



- (BOOL)deleteAccounts {
	return [[_privileges objectAtIndex:13] isEqualToString:@"1"];
}



- (BOOL)elevatePrivileges {
	return [[_privileges objectAtIndex:14] isEqualToString:@"1"];
}



- (BOOL)kickUsers {
	return [[_privileges objectAtIndex:15] isEqualToString:@"1"];
}



- (BOOL)banUsers {
	return [[_privileges objectAtIndex:16] isEqualToString:@"1"];
}



- (BOOL)cannotBeKicked {
	return [[_privileges objectAtIndex:17] isEqualToString:@"1"];
}



#pragma mark -

- (NSComparisonResult)nameSort:(WCAccount *)other {
	return [_name compare:[other name] options:NSCaseInsensitiveSearch];
}

@end
