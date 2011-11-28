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
#import "WCServer.h"

@implementation WCServer

- (id)init {
	self = [super init];
	
	// --- init account
	_account = [[WCAccount alloc] initWithType:WCAccountTypeUser];
	
	return self;
}



- (void)dealloc {
	[_name release];
	[_url release];
	[_account release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_files];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_size];

	_name			= [[coder decodeObject] retain];
	_description	= [[coder decodeObject] retain];
	_version		= [[coder decodeObject] retain];
	_url			= [[coder decodeObject] retain];
	_started		= [[coder decodeObject] retain];
	_account		= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_files];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_size];

	[coder encodeObject:_name];
	[coder encodeObject:_description];
	[coder encodeObject:_version];
	[coder encodeObject:_url];
	[coder encodeObject:_started];
	[coder encodeObject:_account];
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

- (void)setDescription:(NSString *)value {
	[value retain];
	[_description release];
	
	_description = value;
}



- (NSString *)description {
	return _description;
}



#pragma mark -

- (void)setVersion:(NSString *)value {
	[value retain];
	[_version release];
	
	_version = value;
}



- (NSString *)version {
	return _version;
}



#pragma mark -

- (void)setURL:(NSURL *)value {
	[value retain];
	[_url release];
	
	_url = value;
}



- (NSURL *)URL {
	return _url;
}



#pragma mark -

- (void)setStarted:(NSDate *)value {
	[value retain];
	[_started release];
	
	_started = value;
}



- (NSDate *)started {
	return _started;
}



#pragma mark -

- (void)setProtocol:(double)value {
	_protocol = value;
}



- (double)protocol {
	return _protocol;
}



#pragma mark -

- (void)setFiles:(unsigned int)value {
	_files = value;
}



- (unsigned int)files {
	return _files;
}



#pragma mark -

- (void)setSize:(unsigned long long)value {
	_size = value;
}



- (unsigned long long)size {
	return _size;
}



#pragma mark -

- (void)setAccount:(WCAccount *)value {
	[value retain];
	[_account release];
	
	_account = value;
}



- (WCAccount *)account {
	return _account;
}


@end
