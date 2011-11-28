/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

#import "NSFileManagerAdditions.h"
#import "NSStringAdditions.h"
#import "FHFile.h"
#import "FHHandler.h"

static NSMutableArray			*handlers;
static NSMutableArray			*hints;

@implementation FHHandler

+ (void)load {
	handlers = [[NSMutableArray alloc] init];
	hints = [[NSMutableArray alloc] init];
}


- (id)initWithURL:(NSURL *)url {
	return [self initWithURL:url hint:FHHandlerHintNone];
}



- (id)initWithURL:(NSURL *)url hint:(int)hint {
	Class		class;
	int			i, count;
	
	self = [super init];
	
	if([self class] == [FHHandler class]) {
		[self release];
		
		if(hint != FHHandlerHintNone) {
			class = [handlers objectAtIndex:[hints indexOfObject:[NSNumber numberWithInt:hint]]];
			
			return [[class alloc] initWithURL:url hint:hint];
		}
		
		count = [handlers count];
		
		for(i = 0; i < count; i++) {
			class = [handlers objectAtIndex:i];
			
			if([class _isHandlerForURL:url primary:YES])
				return [[class alloc] initWithURL:url hint:hint];
		}

		for(i = 0; i < count; i++) {
			class = [handlers objectAtIndex:i];
			
			if([class _isHandlerForURL:url primary:NO])
				return [[class alloc] initWithURL:url hint:hint];
		}
		
		return NULL;
	}

	_url = [url retain];
	_hint = hint;

	return self;
}



- (void)dealloc {
	[_url release];
	[_files release];
	[_images release];
	
	[super dealloc];
}



#pragma mark -

+ (void)_addHandler:(Class)class {
	[self _addHandler:class withHint:FHHandlerHintNone];
}



+ (void)_addHandler:(Class)class withHint:(int)hint {
	NSNumber		*number;
	
	[handlers addObject:class];
	
	number = [[NSNumber alloc] initWithInt:hint];
	[hints addObject:number];
	[number release];
}



+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	return NO;
}



+ (BOOL)_handlesURLAsDirectory:(NSURL *)url {
	return NO;
}



- (BOOL)_URLIsDirectory:(NSURL *)url {
	Class		class;
	int			i, count;
	
	count = [handlers count];
	
	for(i = 0; i < count; i++) {
		class = [handlers objectAtIndex:i];
		
		if([class _handlesURLAsDirectory:url]) {
			if([class _isHandlerForURL:url primary:YES])
				return YES;
		}
	}
	
	return NO;
}



#pragma mark -

- (NSArray *)files {
	return [NSArray array];
}



- (NSArray *)images {
	NSEnumerator	*enumerator;
	NSArray			*files;
	FHFile			*file;
	
	// --- check for existing
	if(_images)
		return _images;
	
	// --- get images
	_images		= [[NSMutableArray alloc] initWithCapacity:20];
	files		= [self files];
	enumerator  = [files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if(![file isDirectory])
			[_images addObject:file];
	}

	return _images;
}



- (BOOL)isLocal {
	return [[self URL] isFileURL];
}



- (unsigned int)numberOfImages {
	return _numberOfImages;
}



- (unsigned int)hint {
	return _hint;
}



#pragma mark -

- (NSURL *)URL {
	return _url;
}



- (NSURL *)parentURL {
	return [self URL];
}



- (NSURL *)relativeURL {
	return [self URL];
}



- (NSArray *)displayURLComponents {
	return [NSArray arrayWithObject:[[[self URL] absoluteString] stringByReplacingURLPercentEscapes]];
}



- (NSArray *)fullURLComponents {
	return [NSArray arrayWithObject:[self URL]];
}

@end
