/* $Id$ */

/*
 *  Copyright (c) 2003-2008 Axel Andersson
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

#import <WiredFoundation/NSFileManager-WIFoundation.h>

@implementation NSFileManager(WIFoundation)

+ (NSString *)temporaryPathWithPrefix:(NSString *)prefix {
	return [self temporaryPathWithPrefix:prefix suffix:NULL];
}



+ (NSString *)temporaryPathWithPrefix:(NSString *)prefix suffix:(NSString *)suffix {
	NSString	*string;
	char		*path;
	
	path = tempnam([NSTemporaryDirectory() UTF8String], [[NSSWF:@"%@_", prefix] UTF8String]);
	string = [NSString stringWithUTF8String:path];
	free(path);
	
	return suffix ? [NSSWF:@"%@.%@", string, suffix] : string;
}



#pragma mark -

- (BOOL)createDirectoryAtPath:(NSString *)path {
	return [self createDirectoryAtPath:path attributes:NULL];
}



- (BOOL)createFileAtPath:(NSString *)path {
	return [self createFileAtPath:path contents:NULL attributes:NULL];
}



- (BOOL)fileExistsAtPath:(NSString *)path {
	return [self fileExistsAtPath:path isDirectory:NULL];
}



- (BOOL)directoryExistsAtPath:(NSString *)path {
	BOOL	isDirectory;

	return ([self fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory);
}



- (WIFileOffset)fileSizeAtPath:(NSString *)path {
	NSDictionary	*attributes;
	
	attributes = [self fileAttributesAtPath:path traverseLink:YES];
	
	if(!attributes)
		return 0;
	
	return [attributes fileSize];
}



- (NSString *)ownerAtPath:(NSString *)path {
	return [[self fileAttributesAtPath:path traverseLink:YES] fileOwnerAccountName];
}



- (NSArray *)directoryContentsWithFileAtPath:(NSString *)path {
	if(![self directoryExistsAtPath:path])
		return [NSArray arrayWithObject:path];
	
	return [self directoryContentsAtPath:path];
}



- (id)enumeratorWithFileAtPath:(NSString *)path {
	if(![self directoryExistsAtPath:path])
		return [[NSArray arrayWithObject:path] objectEnumerator];

	return [self enumeratorAtPath:path];
}



- (NSArray *)libraryResourcesForTypes:(NSArray *)types inDirectory:(NSString *)directory {
	NSDirectoryEnumerator	*directoryEnumerator;
	NSEnumerator			*enumerator;
	NSMutableArray			*resources;
	NSArray					*paths;
	NSString				*path;
	
	resources = [NSMutableArray array];
	paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
	enumerator = [paths objectEnumerator];
	
	while((path = [enumerator nextObject])) {
		path = [path stringByAppendingPathComponent:directory];
		directoryEnumerator = [self enumeratorAtPath:path];
		
		while((path = [directoryEnumerator nextObject])) {
			if([types containsObject:[path pathExtension]])
				[resources addObject:path];
		}
	}

	return resources;
}

@end
