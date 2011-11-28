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

#import "FHCache.h"
#import "FHImage.h"

@implementation FHCache

+ (FHCache *)cache {
	static FHCache		*sharedCache;
	
	if(!sharedCache)
		sharedCache = [[self alloc] init];
	
	return sharedCache;
}



- (id)init {
	self = [super init];
	
	_directoryIcon	= [[[NSWorkspace sharedWorkspace] iconForFile:@"/tmp"] retain];
	[_directoryIcon setSize:NSMakeSize(128.0, 128.0)];
	
	_fileIcons		= [[NSMutableDictionary alloc] initWithCapacity:1000];
	_largeFileIcons	= [[NSMutableDictionary alloc] initWithCapacity:1000];
	_thumbnails		= [[NSMutableDictionary alloc] initWithCapacity:500];
	
	return self;
}



- (void)dealloc {
	[_directoryIcon release];
	[_fileIcons release];
	[_largeFileIcons release];
	[_thumbnails release];
	
	[super dealloc];
}



#pragma mark -

- (NSImage *)directoryIcon {
	return _directoryIcon;
}



#pragma mark -

- (NSImage *)fileIconForURL:(WIURL *)url {
	NSImage		*image;
	WIURL		*faviconURL;
	
	image = [_fileIcons objectForKey:[url string]];
	
	if(!image) {
		if([url isFileURL]) {
			image = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		} else {
			faviconURL = [[url copy] autorelease];
			[faviconURL setPath:@"/favicon.ico"];
			
			image = [[[NSImage alloc] initWithContentsOfURL:[faviconURL URL]] autorelease];
			
			if(!image)
				image = [NSImage imageNamed:@"URL"];
		}
		
		if(image) {
			if([_fileIcons count] > 1000)
				[_fileIcons removeObjectForKey:[[_fileIcons allKeys] objectAtIndex:0]];
			
			[_fileIcons setObject:image forKey:[url string]];
		}
	}
		
	return image;
}



- (NSImage *)largeFileIconForExtension:(NSString *)extension {
	NSImage		*image;
	
	image = [_largeFileIcons objectForKey:extension];
		
	if(!image) {
		image = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
		
		if(image) {
			[image setSize:NSMakeSize(128.0, 128.0)];
		
			if([_largeFileIcons count] > 1000)
				[_largeFileIcons removeObjectForKey:[[_largeFileIcons allKeys] objectAtIndex:0]];
			
			[_largeFileIcons setObject:image forKey:extension];
		}
	}
	
	return image;
}



- (NSImage *)largeFileIconForURL:(WIURL *)url {
	NSImage		*image;
	
	image = [_largeFileIcons objectForKey:[url string]];
			
	if(!image) {
		image = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
		
		if(image) {
			[image setSize:NSMakeSize(128.0, 128.0)];
		
			if([_largeFileIcons count] > 1000)
				[_largeFileIcons removeObjectForKey:[[_largeFileIcons allKeys] objectAtIndex:0]];
			
			[_largeFileIcons setObject:image forKey:[url string]];
		}
	}
	
	return image;
}



#pragma mark -

- (FHImage *)thumbnailForURL:(WIURL *)url {
	return [self thumbnailForURL:url withData:NULL];
}



- (FHImage *)thumbnailForURL:(WIURL *)url withData:(NSData *)data {
	FHImage		*image;
	
	image = [_thumbnails objectForKey:[url string]];

	if(!image) {
		if(data)
			image = [[[FHImage alloc] initThumbnailWithData:data preferredSize:NSMakeSize(128.0, 128.0)] autorelease];
		else
			image = [[[FHImage alloc] initThumbnailWithURL:url preferredSize:NSMakeSize(128.0, 128.0)] autorelease];
			
		if(image) {
			if([_thumbnails count] > 500)
				[_thumbnails removeObjectForKey:[[_thumbnails allKeys] objectAtIndex:0]];
			
			[_thumbnails setObject:image forKey:[url string]];
		}
	}
	
	return image;
}



- (void)dropThumbnailsForURL:(WIURL *)url {
	NSArray			*keys;
	NSString		*key, *string;
	NSUInteger		i, count;
	
	keys = [_thumbnails allKeys];
	string = [url string];
	
	for(i = 0, count = [keys count]; i < count; i++) {
		key = [keys objectAtIndex:i];
		
		if([key hasPrefix:string])
			[_thumbnails removeObjectForKey:key];
	}
}

@end
