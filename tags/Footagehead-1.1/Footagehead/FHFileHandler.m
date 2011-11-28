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
#import "NSImageAdditions.h"
#import "NSStringAdditions.h"
#import "FHFile.h"
#import "FHFileHandler.h"

@implementation FHFileHandler

- (void)dealloc {
	[_relativeURL release];
	
	[super dealloc];
}



#pragma mark -

+ (void)load {
	[FHHandler _addHandler:self];
}



+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	if([url isFileURL]) {
		if([NSFileManager directoryExistsAtPath:[url path]])
			return YES;
	}
	
	return NO;
}



+ (BOOL)_handlesURLAsDirectory:(NSURL *)url {
	return YES;
}



#pragma mark -

- (NSArray *)files {
	NSEnumerator		*enumerator;
	NSURL				*url;
	NSArray				*types, *contents;
	NSString			*name, *path;
	FHFile				*file;
	LSItemInfoRecord	itemInfoRecord;
	BOOL				isDirectory;
	
	// --- check for existing
	if(_files)
		return _files;

	// --- get files
	_files		= [[NSMutableArray alloc] initWithCapacity:20];
	types		= [NSImage pureImageFileTypes];
	contents	= [NSFileManager directoryContentsWithFileAtPath:[[self URL] path]];
	enumerator  = [contents objectEnumerator];

	while((name = [enumerator nextObject])) {
		// --- get full path
		path = [[[self URL] path] stringByAppendingPathComponent:name];
		
		// --- check for file indicating relative path
		if([name isEqualToString:@".FootageheadPath"]) {
			_relativeURL = [[NSURL alloc] initWithString:
				[[NSString stringWithContentsOfFile:path] stringByAddingURLPercentEscapes]];
		}				  

		// --- get URL
		url = [NSURL fileURLWithPath:path];
		
		// --- is it a folder?
		isDirectory = [self _URLIsDirectory:url];

		if(!isDirectory) {
			// --- skip non-images
			if(![types containsObject:[path pathExtension]])
				continue;
			
			// --- bump number of images
			_numberOfImages++;
		}
		
		// --- get info struct
		LSCopyItemInfoForURL((CFURLRef) url, kLSRequestBasicFlagsOnly, &itemInfoRecord);

		// --- is it an OS9 invisible?
		if(itemInfoRecord.flags & kLSItemInfoIsInvisible)
			continue;

		// --- add file
		file = [[FHFile alloc] initWithURL:url isDirectory:isDirectory];
		[_files addObject:file];
		[file release];
	}
	
	return _files;
}



- (BOOL)isLocal {
	if(_relativeURL)
		return [_relativeURL isFileURL];

	return [super isLocal];
}



#pragma mark -

- (NSURL *)parentURL {
	NSString		*path, *root;
	
	path = [[[self relativeURL] path] stringByReplacingURLPercentEscapes];
	root = [[[self URL] path] stringByAppendingPathComponent:@".FootageheadRoot"];
	
	if([NSString stringWithContentsOfFile:root])
		return [NSURL fileURLWithPath:path];

	return [NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]];
}



- (NSURL *)relativeURL {
	NSString		*filePath, *path;
	
	filePath = [[[[self URL] path] stringByDeletingLastPathComponent]
		stringByAppendingPathComponent:@".FootageheadPath"];
	path = [NSString stringWithContentsOfFile:filePath];
	
	path = path || !_relativeURL ? [[self URL] path] : [_relativeURL path];
	
	return [NSURL fileURLWithPath:path];
}



- (NSArray *)displayURLComponents {
	NSEnumerator		*enumerator;
	NSMutableArray		*components;
	NSString			*path, *component, *label;
	
	// --- just the URL
	if(_relativeURL && ![_relativeURL isFileURL])
		return [NSArray arrayWithObject:[_relativeURL absoluteString]];

	// --- loop over path components
	components = [NSMutableArray arrayWithCapacity:10];
	path = _relativeURL ? [_relativeURL path] : [[self URL] path];
	enumerator = [[[path stringByReplacingURLPercentEscapes] pathComponents] objectEnumerator];
	label = [NSString string];
	
	while((component = [enumerator nextObject])) {
		// --- get full path
		label = [label stringByAppendingString:component];
		
		if(![label hasSuffix:@"/"])
			label = [label stringByAppendingString:@"/"];
		
		// --- add item
		[components addObject:label];
	}
	
	return components;
}



- (NSArray *)fullURLComponents {
	NSEnumerator		*enumerator;
	NSMutableArray		*components;
	NSString			*path, *component, *label;
	
	// --- just the URL
	if(_relativeURL && ![_relativeURL isFileURL])
		return [NSArray arrayWithObject:_relativeURL];
	
	// --- loop over path components
	components = [NSMutableArray arrayWithCapacity:10];
	path = _relativeURL ? [_relativeURL path] : [[self URL] path];
	enumerator = [[path pathComponents] objectEnumerator];
	label = [NSString string];
	
	while((component = [enumerator nextObject])) {
		// --- get full path
		label = [label stringByAppendingString:component];
		
		if(![label hasSuffix:@"/"])
			label = [label stringByAppendingString:@"/"];
		
		// --- add item
		[components addObject:[NSURL fileURLWithPath:label]];
	}
	
	return components;
}
	
@end
