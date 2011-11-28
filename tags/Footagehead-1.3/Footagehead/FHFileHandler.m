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

#import "NSImage-FHAdditions.h"
#import "FHArchiveHandler.h"
#import "FHFile.h"
#import "FHFileHandler.h"

@interface FHFileHandler(Private)

+ (NSArray *)_directoryHandledFileTypes;

@end


@implementation FHFileHandler(Private)

+ (NSArray *)_directoryHandledFileTypes {
	static NSMutableArray		*types;
	
	if(!types) {
		types = [[NSMutableArray alloc] init];
		[types addObjectsFromArray:[FHArchiveHandler handledFileTypes]];
	}
	
	return types;
}

@end


@implementation FHFileHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	if(primary && [url isFileURL]) {
		if([[NSFileManager defaultManager] directoryExistsAtPath:[url path]])
			return YES;
	}
	
	return NO;
}



+ (BOOL)handlesURLAsDirectory:(WIURL *)url {
	if(![url isFileURL])
		return NO;
	
	if([[NSFileManager defaultManager] directoryExistsAtPath:[url path]])
		return YES;

	return [[self _directoryHandledFileTypes] containsObject:[url pathExtension]];
}



+ (NSArray *)handledFileTypes {
	return [NSImage FHImageFileTypes];
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	return [self initHandlerWithURL:url rootPath:[url path]];
}



- (id)initHandlerWithURL:(WIURL *)url rootPath:(NSString *)rootPath {
	self = [super initHandlerWithURL:url];
	
	_rootPath = [rootPath retain];
	
	return self;
}



- (void)dealloc {
	[_rootPath release];
	
	[super dealloc];
}



#pragma mark -

static NSComparisonResult compareFile(id string1, id string2, void *context) {
	return [string1 compare:string2 options:NSCaseInsensitiveSearch | NSNumericSearch];
}



#pragma mark -

- (NSArray *)files {
	NSSet				*types;
	NSArray				*files;
	NSString			*name, *path, *extension;
	WIURL				*url;
	LSItemInfoRecord	itemInfoRecord;
	OSStatus			err;
	BOOL				isDirectory;
	NSUInteger			i, count;

	if(!_files) {
		files	= [[NSFileManager defaultManager] directoryContentsWithFileAtPath:_rootPath];
		files	= [files sortedArrayUsingFunction:compareFile context:NULL];
		count	= [files count];
		types	= [NSSet setWithArray:[FHFileHandler handledFileTypes]];
		_files	= [[NSMutableArray alloc] initWithCapacity:count];
		
		for(i = 0; i < count; i++) {
			name = [files objectAtIndex:i];
			path = [_rootPath stringByAppendingPathComponent:name];
			
			if([name hasPrefix:@"."])
				continue;
			
			url = [WIURL fileURLWithPath:path];
			err = LSCopyItemInfoForURL((CFURLRef) [url URL], kLSRequestBasicFlagsOnly, &itemInfoRecord);
			
			if(err != noErr)
				continue;
			
			if(itemInfoRecord.flags & kLSItemInfoIsInvisible)
				continue;
			
			isDirectory = (itemInfoRecord.flags & kLSItemInfoIsContainer || itemInfoRecord.flags & kLSItemInfoIsSymlink);

			if(!isDirectory) {
				extension = [path pathExtension];
				
				if(![types containsObject:extension]) {
					if([[[self class] _directoryHandledFileTypes] containsObject:extension])
						isDirectory = YES;
					else
						continue;
				}
			}

			[_files addObject:[FHFile fileWithURL:url isDirectory:isDirectory]];

			_numberOfFiles++;
			
			if(!isDirectory)
				_numberOfImages++;
		}
	}
	
	return _files;
}
	
@end

