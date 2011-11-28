/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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
#import "FHFileHandler.h"
#import "FHImageHandler.h"
#import "FHRangeHandler.h"
#import "FHRARHandler.h"
#import "FHSpotlightHandler.h"
#import "FHURLHandler.h"
#import "FHZipHandler.h"

static NSArray					*FHHandlerClasses;

@implementation FHHandler

+ (void)initialize {
	if([self isEqual:[FHHandler class]]) {
		FHHandlerClasses = [[NSArray alloc] initWithObjects:
			[FHFileHandler class],
			[FHRangeHandler class],
			[FHSpotlightHandler class],
			[FHURLHandler class],
			[FHRARHandler class],
			[FHZipHandler class],
			NULL];
	}
}



+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}



+ (BOOL)handlesURLAsDirectory:(WIURL *)url {
	return NO;
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



- (unsigned int)numberOfFiles {
	return _numberOfFiles;
}



- (unsigned int)numberOfImages {
	return _numberOfImages;
}



- (void)removeFile:(FHFile *)file {
	if(![file isDirectory])
		_numberOfImages--;
	
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
	NSImage		*icon;
	WIURL		*faviconURL;
	
	icon = [[FHCache cache] fileIconForURL:url];
	
	if(!icon) {
		if([url isFileURL]) {
			icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		} else {
			faviconURL = [[url copy] autorelease];
			[faviconURL setPath:@"/favicon.ico"];
			
			icon = [[[NSImage alloc] initWithContentsOfURL:[faviconURL URL]] autorelease];
			
			if(!icon)
				icon = [NSImage imageNamed:@"URL"];
		}
		
		[[FHCache cache] setFileIcon:icon forURL:url];
	}
		
	return icon;
}

@end



@implementation FHPlaceholderHandler

- (id)initHandlerWithURL:(WIURL *)url {
	NSZone		*zone;
	Class		class;
	int			i, count;
	
	zone = [self zone];
	[self release];
	
	count = [FHHandlerClasses count];
	
	for(i = 0; i < count; i++) {
		class = [FHHandlerClasses objectAtIndex:i];
		
		if([class handlesURL:url isPrimary:YES])
			return [[class allocWithZone:zone] initHandlerWithURL:url];
	}
	
	for(i = 0; i < count; i++) {
		class = [FHHandlerClasses objectAtIndex:i];
		
		if([class handlesURL:url isPrimary:NO])
			return [[class allocWithZone:zone] initHandlerWithURL:url];
	}
	
	return NULL;
}

@end
