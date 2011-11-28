/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "FHArchiveHandler.h"
#import "FHLHAHandler.h"
#import "FHRARHandler.h"
#import "FHZipHandler.h"

@implementation FHArchiveHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	if(primary && [url isFileURL])
		return [[self handledFileTypes] containsObject:[url pathExtension]];
		
	return NO;
}



+ (NSArray *)handledFileTypes {
	static NSMutableArray	*types;
	NSArray					*classes;
	NSUInteger				i, count;
	
	if(!types) {
		types = [[NSMutableArray alloc] init];
		
		classes = [self handlerClasses];
		count = [classes count];
		
		for(i = 0; i < count; i++)
			[types addObjectsFromArray:[[classes objectAtIndex:i] handledFileTypes]];
	}
	
	return types;
}



+ (NSArray *)handlerClasses {
	static NSArray		*classes;
	
	if(!classes) {
		classes = [[NSArray alloc] initWithObjects:
			[FHLHAHandler class],
			[FHRARHandler class],
			[FHZipHandler class],
			NULL];
	}
	
	return classes;
}



#pragma mark -

+ (id)alloc {
	if([self isEqual:[FHArchiveHandler class]])
		return [FHArchivePlaceholderHandler alloc];

	return [super alloc];
}



+ (id)allocWithZone:(NSZone *)zone {
	if([self isEqual:[FHArchiveHandler class]])
		return [FHArchivePlaceholderHandler allocWithZone:zone];
	
	return [super allocWithZone:zone];
}



- (id)initHandlerWithURL:(WIURL *)url {
	_archivePath = [[NSFileManager temporaryPathWithPrefix:[url lastPathComponent]] retain];
	
	[[NSFileManager defaultManager] createDirectoryAtPath:_archivePath];

	return [super initHandlerWithURL:url rootPath:_archivePath];
}



- (void)dealloc {
	[[NSFileManager defaultManager] removeFileAtPath:_archivePath handler:NULL];

	[_archivePath release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)archivePath {
	return _archivePath;
}

@end



@implementation FHArchivePlaceholderHandler

+ (Class)handler {
	return [FHArchiveHandler class];
}

@end
