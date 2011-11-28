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

#import "FHCache.h"
#import "FHFile.h"
#import "FHHandler.h"
#import "FHArchiveHandler.h"
#import "FHFileHandler.h"
#import "FHImageHandler.h"
#import "FHRangeHandler.h"
#import "FHSpotlightHandler.h"
#import "FHURLHandler.h"

@implementation FHHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}



+ (BOOL)handlesURLAsDirectory:(WIURL *)url {
	return NO;
}



+ (NSArray *)handlerClasses {
	static NSArray		*classes;
	
	if(!classes) {
		classes = [[NSArray alloc] initWithObjects:
			[FHFileHandler class],
			[FHRangeHandler class],
			[FHSpotlightHandler class],
			[FHURLHandler class],
			[FHArchiveHandler class],
			NULL];
	}

	return classes;
}



+ (Class)handlerForURL:(WIURL *)url {
	NSArray			*classes;
	Class			class;
	NSUInteger		i, count;
	
	classes = [self handlerClasses];
	count = [classes count];
	
	for(i = 0; i < count; i++) {
		class = [classes objectAtIndex:i];
		
		if([class handlesURL:url isPrimary:YES])
			return class;
	}
	
	for(i = 0; i < count; i++) {
		class = [classes objectAtIndex:i];
		
		if([class handlesURL:url isPrimary:NO])
			return class;
	}
	
	return NULL;
}



#pragma mark -

+ (id)alloc {
	if([self isEqual:[FHHandler class]])
		return [FHPlaceholderHandler alloc];

	return [super alloc];
}



+ (id)allocWithZone:(NSZone *)zone {
	if([self isEqual:[FHHandler class]])
		return [FHPlaceholderHandler allocWithZone:zone];
	
	return [super allocWithZone:zone];
}



- (id)initHandlerWithURL:(WIURL *)url {
	self = [super init];
	
	_url = [url retain];

	return self;
}



- (void)dealloc {
	[_url release];
	[_files release];
	[_icon release];
	
	[super dealloc];
}



#pragma mark -

- (void)setDelegate:(id)delegate {
	_delegate = delegate;
}



- (id)delegate {
	return _delegate;
}



#pragma mark -

- (NSArray *)files {
	return _files;
}



- (NSUInteger)numberOfFiles {
	return _numberOfFiles;
}



- (NSUInteger)numberOfImages {
	return _numberOfImages;
}



- (void)removeFile:(FHFile *)file {
	if(![file isDirectory])
		_numberOfImages--;

	_numberOfFiles--;
	
	[_files removeObject:file];
}



- (BOOL)isLocal {
	return [[self URL] isFileURL];
}



- (BOOL)isSynchronous {
	return YES;
}



- (BOOL)isFinished {
	return YES;
}



- (BOOL)hasParent {
	return YES;
}



- (WIURL *)URL {
	return _url;
}



- (WIURL *)parentURL {
	WIURL		*url;
	
	url = [[self URL] copy];
	[url setPath:[[[self URL] path] stringByDeletingLastPathComponent]];
	
	return [url autorelease];
}



- (NSArray *)stringComponents {
	NSEnumerator		*enumerator;
	NSMutableArray		*components;
	NSString			*path, *component;
	WIURL				*url;
	
	url = [self URL];
	
	if(![self hasParent])
		return [NSArray arrayWithObject:[url humanReadableString]];
	
	path = [[url path] retain];
	[url setPath:@"/"];
	
	enumerator = [[path pathComponents] objectEnumerator];
	components = [NSMutableArray arrayWithCapacity:10];
	
	while((component = [enumerator nextObject])) {
		if([component isEqualToString:@"/"] && [components count] > 0)
			continue;
		
		[url setPath:[[url path] stringByAppendingPathComponent:component]];
		[components addObject:[url humanReadableString]];
	}
	
	[url setPath:path];
	[path release];
	
	return components;
}



- (NSArray *)URLComponents {
	NSEnumerator		*enumerator;
	NSMutableArray		*components;
	NSString			*path, *component;
	WIURL				*url;
	
	url = [self URL];
	
	if(![self hasParent])
		return [NSArray arrayWithObject:[[url copy] autorelease]];
	
	path = [[url path] retain];
	[url setPath:@"/"];
	
	enumerator = [[path pathComponents] objectEnumerator];
	components = [NSMutableArray arrayWithCapacity:10];
	
	while((component = [enumerator nextObject])) {
		if([component isEqualToString:@"/"] && [components count] > 0)
			continue;
		
		[url setPath:[[url path] stringByAppendingPathComponent:component]];
		[components addObject:[[url copy] autorelease]];
	}
	
	[url setPath:path];
	[path release];
	
	return components;
}



- (NSImage *)iconForURL:(WIURL *)url {
	return [[FHCache cache] fileIconForURL:url];
}

@end



@implementation FHPlaceholderHandler

+ (Class)handler {
	return [FHHandler class];
}



- (id)initHandlerWithURL:(WIURL *)url {
	NSZone		*zone;
	Class		class;
	
	zone = [self zone];
	class = [self class];
	
	[self release];
	
	return [[[[class handler] handlerForURL:url] allocWithZone:zone] initHandlerWithURL:url];
}

@end
