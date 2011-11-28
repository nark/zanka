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
#import "FHZipHandler.h"

static NSMutableArray			*FHFileHandlerAsteriskTypes;

@implementation FHZipHandler

+ (void)initialize {
	NSEnumerator	*enumerator;
	NSString		*type;
	
	if([self isEqual:[FHZipHandler class]]) {
		FHFileHandlerAsteriskTypes = [[NSMutableArray alloc] init];
		
		enumerator = [[FHFileHandler handledFileTypes] objectEnumerator];
		
		while((type = [enumerator nextObject])) {
			if(![type hasPrefix:@"'"])
				[FHFileHandlerAsteriskTypes addObject:[NSSWF:@"*.%@", type]];
		}
	}
}



#pragma mark -

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	if(primary && [url isFileURL])
		return [[self handledFileTypes] containsObject:[url pathExtension]];
		
	return NO;
}



+ (NSArray *)handledFileTypes {
	static NSArray		*types;
	
	if(!types) {
		types = [[NSArray alloc] initWithObjects:
			@"zip", @"ZIP",
			@"cbz", @"CBZ",
			NULL];
	}
	
	return types;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	NSMutableArray	*arguments;
	NSTask			*task;
	
	_archivePath = [[NSFileManager temporaryPathWithPrefix:[url lastPathComponent]] retain];
	[[NSFileManager defaultManager] createDirectoryAtPath:_archivePath];
	
	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/unzip"];
	arguments = [NSMutableArray arrayWithObjects:
		@"-j",
		[url path],
		@"-d",
		_archivePath,
		NULL];
	[arguments addObjectsFromArray:FHFileHandlerAsteriskTypes];
	[task setArguments:arguments];
	[task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
	[task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	[task launch];
	[task waitUntilExit];
	[task release];

	return [super initHandlerWithURL:url rootPath:_archivePath];
}



- (void)dealloc {
	[[NSFileManager defaultManager] removeFileAtPath:_archivePath];

	[_archivePath release];
	
	[super dealloc];
}

@end
