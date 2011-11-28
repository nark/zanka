/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "FHZipHandler.h"

@interface FHZipHandler(Private)

+ (NSArray *)_globbedHandledFileTypes;

@end


@implementation FHZipHandler(Private)

+ (NSArray *)_globbedHandledFileTypes {
	static NSMutableArray	*types;
	NSEnumerator			*enumerator;
	NSString				*type;
	
	if(!types) {
		types = [[NSMutableArray alloc] init];
			
		enumerator = [[FHFileHandler handledFileTypes] objectEnumerator];
			
		while((type = [enumerator nextObject])) {
			if(![type hasPrefix:@"'"])
				[types addObject:[NSSWF:@"*.%@", type]];
		}
	}
	
	return types;
}

@end


@implementation FHZipHandler

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
	
	self = [super initHandlerWithURL:url];
	
	task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/unzip"];
	arguments = [NSMutableArray arrayWithObjects:
		@"-o",
		@"-j",
		[url path],
		@"-d",
		[self archivePath],
		NULL];
	[arguments addObjectsFromArray:[[self class] _globbedHandledFileTypes]];
	[task setArguments:arguments];
	[task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
	[task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
	[task launch];
	[task waitUntilExit];
	[task release];

	return self;
}

@end
