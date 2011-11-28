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
#import "FHCache.h"
#import "FHFile.h"
#import "FHFileHandler.h"
#import "FHSettings.h"
#import "FHRARHandler.h"

@implementation FHRARHandler

- (id)initWithURL:(NSURL *)url hint:(int)hint {
	NSEnumerator	*enumerator;
	NSString		*package, *root, *path, *file;
	NSTask			*task;
	
	// --- retrieve package file
	if([url isFileURL]) {
		package = [url path];
	} else {
		package = [NSFileManager temporaryPathWithPrefix:[url host] suffix:@"rar"];

		[FHCache addTemporaryPath:package];

		[[NSData dataWithContentsOfURL:url] writeToFile:package atomically:YES];
	}

	// --- create temporary destination
	root = [[NSString alloc] initWithFormat:@"%@/Footagehead_%@.rar",
		NSTemporaryDirectory(),
		[[url path] SHA1]];
	[FHCache addTemporaryPath:root];
	[NSFileManager createDirectoryAtPath:root];
	[[NSFileManager defaultManager] changeCurrentDirectoryPath:root];
	
	// --- unpack
	task = [NSTask launchedTaskWithLaunchPath:[FHSettings objectForKey:FHUnRarPath]
									arguments:[NSArray arrayWithObjects:
										@"e",
										@"-r",
										@"-p-",
										@"-o-",
										@"-y",
										package,
										NULL]];
	[task waitUntilExit];
	
	// --- write relative path in root destination directory
	[[url absoluteString]
		writeToFile:[root stringByAppendingPathComponent:@".FootageheadPath"]
		 atomically:YES];
	
	// --- write root in the root destination directory
	if(![url isFileURL]) {
		[@"1" writeToFile:[root stringByAppendingPathComponent:@".FootageheadRoot"]
			   atomically:YES];
	}

	// --- write relative path in each destination directory
	enumerator = [NSFileManager enumeratorWithFileAtPath:root];
	
	while((file = [enumerator nextObject])) {
		path = [root stringByAppendingPathComponent:file];

		if([NSFileManager directoryExistsAtPath:path]) {
			[[[url absoluteString] stringByAppendingFormat:@"/%@", file]
				writeToFile:[path stringByAppendingPathComponent:@".FootageheadPath"]
				 atomically:YES];
		}
	}
	
	return [[FHFileHandler alloc] initWithURL:[NSURL fileURLWithPath:root]];
}



#pragma mark -

+ (void)load {
	[FHHandler _addHandler:self];
}



+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	NSString		*extension;
	
	extension = [[url path] pathExtension];
	
	if([extension isEqualToString:@"rar"] || [extension isEqualToString:@"cbr"]) {
		if([[NSFileManager defaultManager] fileExistsAtPath:[FHSettings objectForKey:FHUnRarPath]])
			return YES;
	}

	return NO;
}



+ (BOOL)_handlesURLAsDirectory:(NSURL *)url {
	return YES;
}

@end
