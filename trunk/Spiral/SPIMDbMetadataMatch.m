/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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

#import "SPIMDbMetadataMatch.h"

@implementation SPIMDbMetadataMatch

+ (NSInteger)version {
	return 1;
}



#pragma mark -

+ (SPIMDbMetadataMatch *)nullMatch {
	return [[[self alloc] initWithTitle:NULL URL:NULL] autorelease];
}



+ (SPIMDbMetadataMatch *)matchWithTitle:(NSString *)title URL:(WIURL *)url {
	return [[[self alloc] initWithTitle:title URL:url] autorelease];
}



+ (SPIMDbMetadataMatch *)matchWithTitle:(NSString *)title URLString:(NSString *)string {
	return [[[self alloc] initWithTitle:title URL:[WIURL URLWithString:string]] autorelease];
}



- (id)initWithTitle:(NSString *)title URL:(WIURL *)url {
	self = [self init];
	
	_title		= [title retain];
	_url		= [url retain];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	NSInteger		version;
	
	self = [super init];
	
	version		= [coder decodeIntegerForKey:@"SPIMDbMetadataMatchVersion"];
	_title		= [[coder decodeObjectForKey:@"SPIMDbMetadataMatchTitle"] retain];
	_url		= [[coder decodeObjectForKey:@"SPIMDbMetadataMatchURL"] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeInteger:[[self class] version] forKey:@"SPIMDbMetadataMatchVersion"];
	[coder encodeObject:_title forKey:@"SPIMDbMetadataMatchTitle"];
	[coder encodeObject:_url forKey:@"SPIMDbMetadataMatchURL"];
}



- (void)dealloc {
	[_title release];
	[_url release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	return [NSSWF:@"%@ - %@", [self title], [self URL]];
}



- (NSUInteger)hash {
	return [[self title] hash] + [[self URL] hash];
}



- (BOOL)isEqual:(id)other {
	return ([[self title] isEqualToString:[other title]] && [[self URL] isEqual:[other URL]]);
}



#pragma mark -

- (void)setTitle:(NSString *)title {
	[title retain];
	[_title release];
	
	_title = title;
}



- (NSString *)title {
	return _title;
}



- (void)setURL:(WIURL *)url {
	[url retain];
	[_url release];
	
	_url = url;
}



- (WIURL *)URL {
	return _url;
}



#pragma mark -

- (BOOL)isNullMatch {
	return (![self title] && ![self URL]);
}

@end
