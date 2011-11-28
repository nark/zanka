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

#import "FHCache.h"

static NSImage						*directoryIcon;
static NSMutableDictionary			*fileIcons;
static NSMutableDictionary			*images;
static NSMutableArray				*temporaryPaths;


@implementation FHCache

- (id)init {
	self = [super init];
	
	// --- init directory icon
	directoryIcon = [[[NSWorkspace sharedWorkspace] iconForFile:@"/tmp"] retain];
	[directoryIcon setSize:NSMakeSize(128, 128)];
	
	// --- init dictionaries to hold our caches
	fileIcons = [[NSMutableDictionary alloc] initWithCapacity:100];
	images = [[NSMutableDictionary alloc] initWithCapacity:5];
	temporaryPaths = [[NSMutableArray alloc] initWithCapacity:10];
	
	return self;
}



- (void)dealloc {
	[directoryIcon release];
	[fileIcons release];
	[images release];
	[temporaryPaths release];
	
	[super dealloc];
}



#pragma mark -

+ (NSImage *)directoryIcon {
	return directoryIcon;
}



#pragma mark -

+ (void)setFileIcon:(NSImage *)icon forExtension:(NSString *)extension {
	if([fileIcons count] > 100)
		[fileIcons removeObjectForKey:[[fileIcons allKeys] objectAtIndex:0]];
	
	[fileIcons setObject:icon forKey:extension];
}



+ (NSImage *)fileIconForExtension:(NSString *)extension {
	return [fileIcons objectForKey:extension];
}



#pragma mark -

+ (void)setFileIcon:(NSImage *)icon forPath:(NSString *)path {
	if([fileIcons count] > 100)
		[fileIcons removeObjectForKey:[[fileIcons allKeys] objectAtIndex:0]];
	
	[fileIcons setObject:icon forKey:path];
}



+ (NSImage *)fileIconForPath:(NSString *)path {
	return [fileIcons objectForKey:path];
}



#pragma mark -

+ (void)setImage:(NSImage *)image forURL:(NSURL *)url {
	if(!image) {
		[images removeObjectForKey:url];
	} else {
		if([images count] > 5)
			[images removeObjectForKey:[[images allKeys] objectAtIndex:0]];
		
		[images setObject:image forKey:[url absoluteString]];
	}
}



+ (NSImage *)imageForURL:(NSURL *)url {
	return [images objectForKey:[url absoluteString]];
}



#pragma mark -

+ (void)addTemporaryPath:(NSString *)path {
	[temporaryPaths addObject:path];
}



+ (void)purgeTemporaryPaths {
	int			i, count;
	
	count = [temporaryPaths count];
	
	for(i = 0; i < count; i++) {
		[[NSFileManager defaultManager] removeFileAtPath:[temporaryPaths objectAtIndex:i]
												 handler:NULL];
	}
}

@end
