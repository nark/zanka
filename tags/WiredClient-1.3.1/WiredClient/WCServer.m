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
#import "WCServer.h"

@implementation WCServer

- (void)dealloc {
	[_name release];
	[_serverDescription release];
	[_serverVersion release];
	[_url release];
	[_startupDate release];
	[_banner release];

	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];

	WIDecode(coder, _name);
	WIDecode(coder, _serverDescription);
	WIDecode(coder, _serverVersion);
	WIDecode(coder, _url);
	WIDecode(coder, _startupDate);
	WIDecode(coder, _protocol);
	WIDecode(coder, _banner);
	WIDecode(coder, _files);
	WIDecode(coder, _size);
	WIDecode(coder, _account);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _name);
	WIEncode(coder, _serverDescription);
	WIEncode(coder, _serverVersion);
	WIEncode(coder, _url);
	WIEncode(coder, _startupDate);
	WIEncode(coder, _protocol);
	WIEncode(coder, _banner);
	WIEncode(coder, _files);
	WIEncode(coder, _size);
	WIEncode(coder, _account);
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setServerDescription:(NSString *)serverDescription {
	[serverDescription retain];
	[_serverDescription release];

	_serverDescription = serverDescription;
}



- (NSString *)serverDescription {
	return _serverDescription;
}



- (void)setServerVersion:(NSString *)value {
	[value retain];
	[_serverVersion release];

	_serverVersion = value;
}



- (NSString *)serverVersion {
	return _serverVersion;
}



- (void)setURL:(WIURL *)url {
	[url retain];
	[_url release];

	_url = url;
}



- (WIURL *)URL {
	return _url;
}



- (void)setStartupDate:(NSDate *)startupDate {
	[startupDate retain];
	[_startupDate release];

	_startupDate = startupDate;
}



- (NSDate *)startupDate {
	return _startupDate;
}



- (void)setProtocol:(double)value {
	_protocol = value;
}



- (double)protocol {
	return _protocol;
}



- (void)setBanner:(NSImage *)banner {
	[banner retain];
	[_banner release];

	_banner = banner;
}



- (NSImage *)banner {
	return _banner;
}



- (void)setFiles:(unsigned int)files {
	_files = files;
}



- (unsigned int)files {
	return _files;
}



- (void)setSize:(unsigned long long)size {
	_size = size;
}



- (unsigned long long)size {
	return _size;
}



- (void)setAccount:(WCAccount *)account {
	[account retain];
	[_account release];

	_account = account;
}



- (WCAccount *)account {
	return _account;
}

@end
