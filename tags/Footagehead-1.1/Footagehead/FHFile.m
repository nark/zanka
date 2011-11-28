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
#import "FHFile.h"
#import "FHHandler.h"

@implementation FHFile

- (id)initWithURL:(NSURL *)url isDirectory:(BOOL)isDirectory {
	return [self initWithURL:url isDirectory:isDirectory hint:FHHandlerHintNone];
}



- (id)initWithURL:(NSURL *)url isDirectory:(BOOL)isDirectory hint:(int)hint {
	self = [super init];
	
	_url			= [url retain];
	_path			= [[_url path] retain];
	_pathExtension  = [[_path pathExtension] retain];
	_isDirectory	= isDirectory;
	_hint			= hint;
	
	if([_url isFileURL]) {
		_name = [[[NSFileManager defaultManager] displayNameAtPath:_path] retain];
		_icon = [FHCache fileIconForPath:_path];
		
		if(!_icon) {
			_icon = [[NSWorkspace sharedWorkspace] iconForFile:_path];
			[_icon setSize:NSMakeSize(128, 128)];
			
			[FHCache setFileIcon:_icon forPath:_path];
		}

		[_icon retain];
	} else {
		_name = [[_path lastPathComponent] retain];
		
		if(_isDirectory) {
			_icon = [FHCache directoryIcon];
		} else {
			_icon = [FHCache fileIconForExtension:_pathExtension];
			
			if(!_icon) {
				_icon = [[NSWorkspace sharedWorkspace] iconForFileType:_pathExtension];
				[_icon setSize:NSMakeSize(128, 128)];

				[FHCache setFileIcon:_icon forExtension:_pathExtension];
			}
		}
		
		[_icon retain];
	}

	return self;
}



- (void)dealloc {
	[_url release];
	[_path release];
	[_pathExtension release];
	[_name release];
	[_icon release];
	
	[super dealloc];
}



#pragma mark -

- (NSURL *)URL {
	return _url;
}



- (NSString *)path {
	return _path;
}



- (NSString *)pathExtension {
	return _pathExtension;
}



- (NSString *)name {
    return _name;
}



- (NSImage *)icon {
	return _icon;
}



- (BOOL)isDirectory {
	return _isDirectory;
}



- (int)hint {
	return _hint;
}

@end
