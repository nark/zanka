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
#import "FHImage.h"

@implementation FHFile

- (id)initWithURL:(WIURL *)url isDirectory:(BOOL)isDirectory index:(unsigned int)index {
	return [self initWithURL:url name:NULL isDirectory:isDirectory index:index];
}



- (id)initWithURL:(WIURL *)url name:(NSString *)name isDirectory:(BOOL)isDirectory index:(unsigned int)index {
	NSImage		*icon;
	
	self = [super init];
	
	_url = [url retain];
	_path = [[_url path] retain];
	_name = name ? [name retain] : [[_path lastPathComponent] retain];
	_extension = [[[self path] pathExtension] retain];
	_directory = isDirectory;
	_index = index;
	
	if(!_directory) {
		// --- get icon for extension
		icon = [[FHCache cache] largeFileIconForExtension:_extension];
		
		if(!icon) {
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:_extension];
			[icon setSize:NSMakeSize(128.0, 128.0)];
			
			[[FHCache cache] setLargeFileIcon:icon forExtension:_extension];
		}
		
		_icon = [[FHImage alloc] initImageWithImage:icon];
	} else {
		if(![_url isFileURL]) {
			// --- get icon for generic remote directory
			icon = [[FHCache cache] directoryIcon];
		} else {
			// --- get icon for local directory path
			icon = [[FHCache cache] largeFileIconForURL:url];
			
			if(!icon) {
				icon = [[NSWorkspace sharedWorkspace] iconForFile:_path];
				[icon setSize:NSMakeSize(128.0, 128.0)];
				
				[[FHCache cache] setLargeFileIcon:icon forURL:_url];
			}
		}
		
		_icon = [[FHImage alloc] initImageWithImage:icon];
	}

	return self;
}



- (void)dealloc {
	[_url release];
	[_path release];
	[_extension release];
	[_name release];
	[_image release];
	[_icon release];
	
	[super dealloc];
}



#pragma mark -

- (void)setImage:(FHImage *)image {
	[image retain];
	[_image release];
	
	_image = image;
}



- (FHImage *)image {
	return _image;
}



- (void)setThumbnail:(FHImage *)thumbnail {
	[thumbnail retain];
	[_thumbnail release];
	
	_thumbnail = thumbnail;
}



- (FHImage *)thumbnail {
	return _thumbnail;
}



- (void)setLoaded:(BOOL)loaded {
	_loaded = loaded;
}



- (BOOL)isLoaded {
	return _loaded;
}



#pragma mark -

- (NSString *)name {
    return _name;
}



- (WIURL *)URL {
	return _url;
}



- (NSString *)path {
	return _path;
}



- (NSString *)extension {
	return _extension;
}



- (FHImage *)icon {
	return _icon;
}



- (BOOL)isDirectory {
	return _directory;
}



- (unsigned int)index {
	return _index;
}

@end