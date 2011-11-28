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
	
	[super dealloc];
}



#pragma mark -

- (NSImage *)directoryIcon {
	return _directoryIcon;
}



#pragma mark -

- (void)setFileIcon:(NSImage *)icon forURL:(WIURL *)url {
	if([_fileIcons count] > 1000)
		[_fileIcons removeObjectForKey:[[_fileIcons allKeys] objectAtIndex:0]];
	
	[_fileIcons setObject:icon forKey:[url string]];
}



- (NSImage *)fileIconForURL:(WIURL *)url {
	return [_fileIcons objectForKey:[url string]];
}



#pragma mark -

- (void)setLargeFileIcon:(NSImage *)icon forExtension:(NSString *)extension {
	if([_largeFileIcons count] > 1000)
		[_largeFileIcons removeObjectForKey:[[_largeFileIcons allKeys] objectAtIndex:0]];
	
	[_largeFileIcons setObject:icon forKey:extension];
}



- (NSImage *)largeFileIconForExtension:(NSString *)extension {
	return [_largeFileIcons objectForKey:extension];
}



#pragma mark -

- (void)setLargeFileIcon:(NSImage *)icon forURL:(WIURL *)url {
	if([_largeFileIcons count] > 1000)
		[_largeFileIcons removeObjectForKey:[[_largeFileIcons allKeys] objectAtIndex:0]];
	
	[_largeFileIcons setObject:icon forKey:[url string]];
}



- (NSImage *)largeFileIconForURL:(WIURL *)url {
	return [_largeFileIcons objectForKey:[url string]];
}



#pragma mark -

- (void)setThumbnail:(FHImage *)image forURL:(WIURL *)url {
	if([_thumbnails count] > 500)
		[_thumbnails removeObjectForKey:[[_thumbnails allKeys] objectAtIndex:0]];
	
	[_thumbnails setObject:image forKey:[url string]];
}



- (FHImage *)thumbnailForURL:(WIURL *)url {
	return [_thumbnails objectForKey:[url string]];
}



- (void)dropThumbnailsForURL:(WIURL *)url {
	NSArray			*keys;
	NSString		*key, *string;
	unsigned int	i, count;
	
	keys = [_thumbnails allKeys];
	string = [url string];
	
	for(i = 0, count = [keys count]; i < count; i++) {
		key = [keys objectAtIndex:i];
		
		if([key hasPrefix:string])
			[_thumbnails removeObjectForKey:key];
	}
}

@end
