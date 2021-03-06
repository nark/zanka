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
#import "FHSpotlightHandler.h"

@implementation FHSpotlightHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	return (primary && [[url scheme] isEqualToString:@"spotlight"]);
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	self = [super initHandlerWithURL:url];

	_query = [[NSMetadataQuery alloc] init];
	[_query setPredicate:[NSPredicate predicateWithFormat:
		@"(kMDItemFSName LIKE[cd] %@) && (kMDItemContentTypeTree == \"public.image\")",
		[[url path] substringFromIndex:1]]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryGatheringProgress:)
			   name:NSMetadataQueryGatheringProgressNotification
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryDidFinishGathering:)
			   name:NSMetadataQueryDidFinishGatheringNotification
			 object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_query release];
	
	[super dealloc];
}



#pragma mark -

- (void)metadataQueryGatheringProgress:(NSNotification *)notification {
	NSMetadataItem	*item;
	NSString		*path;
	FHFile			*file;
	unsigned int	count;
	
	count = [_query resultCount];
	
	for(; _index < count; _index++) {
		item = [_query resultAtIndex:_index];
		path = [item valueForAttribute:@"kMDItemPath"];
		
		if(path) {
			file = [[FHFile alloc] initWithURL:[WIURL fileURLWithPath:path] isDirectory:NO index:_index];
			[_files addObject:file];
			[file release];
			
			_numberOfFiles++;
			_numberOfImages++;
			
			[_delegate performSelector:@selector(handlerDidAddFiles:) withObject:self];
		}
	}
}



- (void)metadataQueryDidFinishGathering:(NSNotification *)notification {
	[_delegate performSelector:@selector(handlerDidFinishLoading:) withObject:self];
	
	_finished = YES;
}



#pragma mark -

- (NSArray *)files {
	if(!_files) {
		_files = [[NSMutableArray alloc] initWithCapacity:50];
		
		[_query startQuery];
	}
	
	return _files;
}



- (BOOL)isLocal {
	return YES;
}



- (BOOL)isSynchronous {
	return NO;
}



- (BOOL)isFinished {
	return _finished;
}



- (BOOL)hasParent {
	return NO;
}



- (NSArray *)stringComponents {
	return [NSArray arrayWithObject:[NSSWF:NSLS(@"\"%@\"", @"Spotlight query (query)"), [[[self URL] path] substringFromIndex:1]]];
}



- (NSImage *)iconForURL:(WIURL *)url {
	return [NSImage imageNamed:@"Spotlight"];
}

@end
