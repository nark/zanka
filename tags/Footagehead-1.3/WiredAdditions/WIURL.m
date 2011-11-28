/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import <WiredAdditions/NSString-WIAdditions.h>
#import <WiredAdditions/WIMacros.h>
#import <WiredAdditions/WIURL.h>

@interface WIURL(Private)

+ (NSDictionary *)_portmap;

@end


@implementation WIURL(Private)

+ (NSDictionary *)_portmap {
	static NSDictionary	*portmap;

	if(!portmap) {
		portmap = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSNumber numberWithInt:2000],		@"wired",
			[NSNumber numberWithInt:2002],		@"wiredtracker",
			NULL];
	}

	return portmap;
}

@end



@implementation WIURL

+ (id)URLWithString:(NSString *)string {
	return [self URLWithString:string scheme:NULL];
}



+ (id)URLWithString:(NSString *)string scheme:(NSString *)defaultScheme {
	NSString	*scheme, *auth, *user, *password, *path;
	WIURL		*url;
	NSRange		range;
	
	string = [string stringByRemovingSurroundingWhitespace];
	string = [string stringByReplacingURLPercentEscapes];

	// --- find SCHEME://host/
	range = [string rangeOfString:@"://"];

	if(range.location == NSNotFound) {
		scheme = NULL;
	} else {
		scheme = [string substringToIndex:range.location];
		string = [string substringFromIndex:range.location + 3];
	}

	// --- find scheme://host/PATH
	range = [string rangeOfString:@"/"];

	if(range.location == NSNotFound) {
		path = NULL;
	} else {
		path = [string substringFromIndex:range.location];
		string = [string substringToIndex:range.location];
	}

	// --- find scheme://USER@host/
	range = [string rangeOfString:@"@"];

	if(range.location == NSNotFound) {
		user = NULL;
		password = NULL;
	} else {
		auth = [string substringToIndex:range.location];
		string = [string substringFromIndex:range.location + 1];

		// --- find scheme://user:PASSWORD@host/
		range = [auth rangeOfString:@":"];

		if(range.location == NSNotFound) {
			user = auth;
			password = NULL;
		} else {
			user = [auth substringToIndex:range.location];
			password = [auth substringFromIndex:range.location + 1];
		}
	}

	if(!scheme)
		scheme = defaultScheme;

	if(!scheme) {
		if([string hasPrefix:@"www."])
			scheme = @"http";
		else if([string hasPrefix:@"wired."])
			scheme = @"wired";
	}

	if(!scheme)
		return NULL;

	url = [self URLWithScheme:scheme hostpair:string];
	[url setUser:user];
	[url setPassword:password];
	[url setPath:path];

	return url;
}



+ (id)URLWithScheme:(NSString *)scheme hostpair:(NSString *)hostpair {
	NSString		*host;
	NSRange			range;
	NSUInteger		port;

	if([[hostpair componentsSeparatedByString:@":"] count] == 2) {
		range = [hostpair rangeOfString:@":" options:NSBackwardsSearch];

		if(range.location == NSNotFound ||
		   range.location == 0 ||
		   range.location == [hostpair length] - 1) {
			host = hostpair;
			port = 0;
		} else {
			host = [hostpair substringToIndex:range.location];
			port = [[hostpair substringFromIndex:range.location + 1] unsignedIntValue];
		}
	} else {
		host = hostpair;
		port = 0;
	}

	if(port == 0)
		port = [[[WIURL _portmap] objectForKey:scheme] unsignedIntValue];

	return [[[self alloc] initWithScheme:scheme host:host port:port] autorelease];
}



+ (id)URLWithScheme:(NSString *)scheme host:(NSString *)host port:(NSUInteger)port {
	return [[[self alloc] initWithScheme:scheme host:host port:port] autorelease];
}



+ (id)fileURLWithPath:(NSString *)path {
	WIURL	*url;

	url = [self URLWithScheme:@"file" host:NULL port:0];
	[url setPath:path];

	return url;
}



- (id)initWithScheme:(NSString *)scheme host:(NSString *)host port:(NSUInteger)port {
	self = [super init];

	_scheme = [scheme retain];
	_host = [host retain];
	_port = port;

	return self;
}



- (NSString *)description {
	return [self humanReadableString];
}



- (void)dealloc {
	[_scheme release];
	[_host release];
	[_user release];
	[_password release];
	[_path release];

	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WIURL	*url;
	
	url = [[[self class] allocWithZone:zone] initWithScheme:[self scheme] host:[self host] port:[self port]];
	[url setUser:[self user]];
	[url setPassword:[self password]];
	[url setPath:[self path]];
		
	return url;
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];

	WIDecode(coder, _scheme);
	WIDecode(coder, _host);
	WIDecode(coder, _port);
	WIDecode(coder, _user);
	WIDecode(coder, _password);
	WIDecode(coder, _path);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _scheme);
	WIEncode(coder, _host);
	WIEncode(coder, _port);
	WIEncode(coder, _user);
	WIEncode(coder, _password);
	WIEncode(coder, _path);
}



#pragma mark -

- (NSUInteger)hash {
	return [[self string] hash];
}



- (BOOL)isEqual:(WIURL *)url {
	return [[self string] isEqualToString:[url string]];
}



#pragma mark -

- (NSString *)string {
	NSMutableString		*string;
	NSString			*path;
	
	string = [[NSMutableString alloc] init];
	[string appendString:[[self scheme] stringByAddingURLPercentEscapesToAllCharacters]];
	[string appendString:@"://"];
	
	if([[self host] length] > 0) {
		if([[self user] length] > 0) {
			[string appendString:[[self user] stringByAddingURLPercentEscapesToAllCharacters]];
			
			if([[self password] length] > 0) {
				[string appendString:@":"];
				[string appendString:[[self password] stringByAddingURLPercentEscapesToAllCharacters]];
			}

			[string appendString:@"@"];
		}
		
		[string appendString:[[self host] stringByAddingURLPercentEscapesToAllCharacters]];
		
		if([self port] != 0)
			[string appendFormat:@":%lu", [self port]];
	}
	
	path = [self path];
	
	if([path length] > 0)
		[string appendString:[path stringByAddingURLPercentEscapes]];
	else
		[string appendString:@"/"];
	
	return [string autorelease];
}



- (NSString *)humanReadableString {
	NSMutableString		*string;
	
	if([self isFileURL])
		return [self path];

	string = [[NSMutableString alloc] init];
	[string appendFormat:@"%@://", [self scheme]];

	if([[self host] length] > 0) {
		if([[self user] length] > 0 && ![[self user] isEqualToString:@"guest"])
			[string appendFormat:@"%@:@", [self user]];

		[string appendString:[self hostpair]];
	}

	[string appendString:[[self path] length] > 0 ? [self path] : @"/"];

	return [string autorelease];
}



- (WIURL *)URLByDeletingLastPathComponent {
	WIURL	*url;

	url = [self copy];
	[url setPath:[[url path] stringByDeletingLastPathComponent]];

	return [url autorelease];
}



- (NSURL *)URL {
	if([self isFileURL])
		return [NSURL fileURLWithPath:[self path]];

	return [NSURL URLWithString:[self string]];
}



- (BOOL)isFileURL {
	return [[self scheme] isEqualToString:@"file"];
}



#pragma mark -

- (void)setScheme:(NSString *)value {
	[value retain];
	[_scheme release];

	_scheme = value;
}



- (NSString *)scheme {
	return _scheme;
}



- (void)setHost:(NSString *)value {
	[value retain];
	[_host release];

	_host = value;
}



- (NSString *)host {
	return _host;
}



- (NSString *)hostpair {
	if([[[WIURL _portmap] objectForKey:[self scheme]] unsignedIntValue] == [self port])
		return [self host];

	return [NSSWF:@"%@:%lu", [self host], [self port]];
}



- (void)setPort:(NSUInteger)value {
	_port = value;
}



- (NSUInteger)port {
	return _port;
}



- (void)setUser:(NSString *)value {
	[value retain];
	[_user release];

	_user = value;
}



- (NSString *)user {
	return _user;
}



- (void)setPassword:(NSString *)value {
	[value retain];
	[_password release];

	_password = value;
}



- (NSString *)password {
	return _password;
}



- (void)setPath:(NSString *)value {
	[value retain];
	[_path release];

	_path = value;
}



- (NSString *)path {
	return _path;
}



- (NSString *)pathExtension {
	return [_path pathExtension];
}



- (NSString *)lastPathComponent {
	return [_path lastPathComponent];
}

@end
