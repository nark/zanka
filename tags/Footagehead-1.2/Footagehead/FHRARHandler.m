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

#import "FHFile.h"
#import "FHRARHandler.h"

@implementation FHRARHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	if(primary && [url isFileURL])
		return [[self handledFileTypes] containsObject:[url pathExtension]];
		
	return NO;
}



+ (NSArray *)handledFileTypes {
	static NSArray		*types;
	
	if(!types) {
		types = [[NSArray alloc] initWithObjects:
			@"rar", @"RAR",
			@"cbr", @"CBR",
			NULL];
	}
	
	return types;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	NSString	*path;
	NSTask		*task;
	
	_archivePath = [[NSFileManager temporaryPathWithPrefix:[url lastPathComponent]] retain];
	[[NSFileManager defaultManager] createDirectoryAtPath:_archivePath];
	
	if([[NSFileManager defaultManager] changeCurrentDirectoryPath:_archivePath]) {
		path = [[self bundle] pathForResource:@"unrar" ofType:NULL];
		task = [[NSTask alloc] init];
		[task setLaunchPath:path];
		[task setArguments:[NSArray arrayWithObjects:
			@"e",
			@"-av-",
			@"-c-",
			@"-idp",
			@"-p-",
			@"-y",
			[url path],
			NULL]];
		[task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
		[task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
		[task launch];
		[task waitUntilExit];
		[task release];
	}

	return [super initHandlerWithURL:url rootPath:_archivePath];
}



- (void)dealloc {
	[[NSFileManager defaultManager] removeFileAtPath:_archivePath];

	[_archivePath release];
	
	[super dealloc];
}

@end
