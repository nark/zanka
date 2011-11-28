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

#import "FHFile.h"
#import "FHSpotlightHandler.h"

@interface FHSpotlightHandler(Private)

- (void)_addFilesFromQuery;

@end


@implementation FHSpotlightHandler(Private)

- (void)_addFilesFromQuery {
	NSMetadataItem	*item;
	NSString		*path;
	NSUInteger		count;
	
	count = [_query resultCount];
	
	for(; _index < count; _index++) {
		item = [_query resultAtIndex:_index];
		path = [item valueForAttribute:@"kMDItemPath"];
		
		if(path) {
			[_files addObject:[FHFile fileWithURL:[WIURL fileURLWithPath:path] isDirectory:NO]];
			
			_numberOfFiles++;
			_numberOfImages++;
			
			[_delegate handlerDidAddFiles:self];
		}
	}
}

@end



@implementation FHSpotlightHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	return (primary && [[url scheme] isEqualToString:@"spotlight"]);
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	NSString	*string;
	
	self = [super initHandlerWithURL:url];

	string = [[url path] substringFromIndex:1];
	
	_query = [[NSMetadataQuery alloc] init];
	[_query setPredicate:[NSPredicate predicateWithFormat:
		[NSSWF:@"(kMDItemDisplayName IN[cd] '%@' || kMDItemAuthors IN[cd] '%@' || kMDItemCity IN[cd] '%@' || kMDItemContributors IN[cd] '%@' || kMDItemDescription IN[cd] '%@' || kMDItemHeadline IN[cd] '%@' || kMDItemInstructions IN[cd] '%@' || kMDItemKeywords IN[cd] '%@' || kMDItemStateOrProvince IN[cd] '%@' || kMDItemTitle IN[cd] '%@') && (kMDItemContentTypeTree == 'public.image')",
			string, string, string, string, string, string, string, string, string, string]]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryGatheringProgress:)
			   name:NSMetadataQueryGatheringProgressNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryDidUpdate:)
			   name:NSMetadataQueryDidUpdateNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryDidFinishGathering:)
			   name:NSMetadataQueryDidFinishGatheringNotification];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_query release];
	
	[super dealloc];
}



#pragma mark -

- (void)metadataQueryGatheringProgress:(NSNotification *)notification {
	[self _addFilesFromQuery];
}



- (void)metadataQueryDidUpdate:(NSNotification *)notification {
	[self _addFilesFromQuery];
}
	


- (void)metadataQueryDidFinishGathering:(NSNotification *)notification {
	[_delegate handlerDidFinishLoading:self];
	
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
