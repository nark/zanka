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

#import "NSFileManagerAdditions.h"

@implementation NSFileManager(WCTemporaryPathGenerating)

+ (NSString *)temporaryPathWithPrefix:(NSString *)prefix suffix:(NSString *)suffix {
	NSString	*string;
	char		*path;
	
	path = tempnam([NSTemporaryDirectory() UTF8String],
				   [[NSString stringWithFormat:@"WiredClient_%@_", prefix] UTF8String]);
	string = [NSString stringWithCString:path];
	free(path);
	
	return [NSString stringWithFormat:@"%@.%@", string, suffix];
}

@end


@implementation NSFileManager(WCFileManagerShortcuts)

+ (void)movePath:(NSString *)fromPath toPath:(NSString *)toPath {
	[[NSFileManager defaultManager] movePath:fromPath toPath:toPath handler:NULL];
}



+ (void)createDirectoryAtPath:(NSString *)path {
	[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:NULL];
}



+ (void)createFileAtPath:(NSString *)path {
	[[NSFileManager defaultManager] createFileAtPath:path contents:NULL attributes:NULL];
}



+ (BOOL)fileExistsAtPath:(NSString *)path {
	return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL];
}



+ (BOOL)directoryExistsAtPath:(NSString *)path {
	BOOL		isDirectory;
	
	return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
}



+ (unsigned long long)fileSizeAtPath:(NSString *)path {
	return [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] fileSize];
}



+ (id)enumeratorWithFileAtPath:(NSString *)path {
	if(![NSFileManager directoryExistsAtPath:path]) {
		NSArray		*array;
		
		array = [NSArray arrayWithObject:path];
		
		return [array objectEnumerator];
	}
	
	return [[NSFileManager defaultManager] enumeratorAtPath:path];
}

@end