/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPFilenameMetadataGatherer.h"
#import "SPIMDbMetadataGatherer.h"
#import "SPIMDbMetadataMatch.h"
#import "SPMovieController.h"
#import "SPPlaylistController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistLoader.h"
#import "SPSettings.h"

@interface SPPlaylistLoader(Private)

- (void)_loadFolder:(SPPlaylistFolder *)folder;
- (void)_loadedFolder:(SPPlaylistFolder *)folder items:(NSArray *)items;
- (void)_loadMovieData:(SPPlaylistContainer *)container;
- (void)_loadMetadata:(SPPlaylistContainer *)container;
- (void)_loadedQuery:(NSMetadataQuery *)query forSmartGroup:(SPPlaylistSmartGroup *)smartGroup;

@end


@implementation SPPlaylistLoader(Private)

- (void)_loadFolder:(SPPlaylistFolder *)folder {
	NSMutableArray				*items;
	NSString					*name, *path, *filePath;
	SPPlaylistRepresentedFile	*representedFile;
	id							item;
	
	items = [NSMutableArray array];
	path = [folder resolvedPath];
	
	for(name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL]) {
		if(_delegatePlaylistLoaderIsProcessingWithStatus) {
			[(id) delegate performSelectorOnMainThread:@selector(playlistLoader:isProcessingWithStatus:)
											withObject:self
											withObject:NSLS(@"Loading folder...", @"Playlist status")
										 waitUntilDone:NO];
		}
		
		if(![name hasPrefix:@"."]) {
			filePath = [path stringByAppendingPathComponent:name];
			item = [folder itemForPath:filePath];
			
			if(!item) {
				representedFile = [[SPPlaylistController playlistController] representedFileForPath:filePath];
				
				if(representedFile) {
					item = [SPPlaylistRepresentedFile fileWithPath:filePath];
					
					[item copyAttributesFromFile:representedFile];
				}
			}
			
			if(!item) {
				if([[NSFileManager defaultManager] directoryExistsAtPath:filePath]) {
					item = [SPPlaylistRepresentedFolder folderWithPath:filePath];
				} else {
					if(![[SPMovieController movieFileTypes] containsObject:[[filePath pathExtension] lowercaseString]])
						continue;
					
					item = [SPPlaylistRepresentedFile fileWithPath:filePath];
				
					if(_delegatePlaylistLoaderDidLoadContentsOfFolder) {
						[(id) delegate performSelectorOnMainThread:@selector(playlistLoader:didLoadFile:)
														withObject:self
														withObject:item
													 waitUntilDone:YES];
					}
					
					[[SPPlaylistController playlistController] addRepresentedFile:item];
				 }
			}
			
			[items addObject:item];
		}
	}

	[self performSelectorOnMainThread:@selector(_loadedFolder:items:) withObject:folder withObject:items waitUntilDone:YES];
}



- (void)_loadedFolder:(SPPlaylistFolder *)folder items:(NSArray *)items {
	[folder setItems:items];
	[folder sortUsingSelector:[[SPSettings settings] boolForKey:SPSimplifyFilenames]
		? @selector(compareCleanName:)
		: @selector(compareName:)];
	[folder setLoading:NO];

	if(_delegatePlaylistLoaderDidLoadContentsOfFolder)
		[delegate playlistLoader:self didLoadContentsOfFolder:folder];
}




- (void)_loadMovieData:(SPPlaylistContainer *)container {
	NSArray				*items;
	NSDictionary		*attributes;
	NSString			*path;
	NSError				*error;
	QTMovie				*movie;
	SPPlaylistFile		*file;
	id					item;
	
	items = [[[container items] copy] autorelease];
	
	for(item in items) {
		if(_delegatePlaylistLoaderIsProcessingWithStatus) {
			[(id) delegate performSelectorOnMainThread:@selector(playlistLoader:isProcessingWithStatus:)
											withObject:self
											withObject:NSLS(@"Loading movie data...", @"Playlist status")
										 waitUntilDone:NO];
		}
		
		if([item isKindOfClass:[SPPlaylistFile class]]) {
			file = item;
			
			if([file duration] == 0.0 || [file sizeOnDisk] != [file size]) {
				path = [file resolvedPath];
				
				if(![[[path pathExtension] lowercaseString] isEqualToString:@"wmv"]) {
					attributes = [NSDictionary dictionaryWithObjectsAndKeys:
						path,							QTMovieFileNameAttribute,
						[NSNumber numberWithBool:YES],	QTMovieDontInteractWithUserAttribute,
						[NSNumber numberWithBool:YES],	QTMovieOpenAsyncOKAttribute,
//						[NSNumber numberWithBool:YES],	@"QTMovieOpenAsyncRequiredAttribute",
//						[NSNumber numberWithBool:YES],	@"QTMovieOpenForPlaybackAttribute",
						NULL];
					movie = [[QTMovie alloc] initWithAttributes:attributes error:&error];
					
					if(movie) {
						while([[movie attributeForKey:QTMovieLoadStateAttribute] longValue] < QTMovieLoadStateLoaded)
							usleep(100000);
							
						[self performSelectorOnMainThread:@selector(_loadedMovieDataOfFile:duration:dimensions:)
											   withObject:file
											   withObject:[movie attributeForKey:QTMovieDurationAttribute]
											   withObject:[movie attributeForKey:QTMovieNaturalSizeAttribute]
											waitUntilDone:YES];
					
						[movie release];
					}
				}
			}
		}
	}

	[self performSelectorOnMainThread:@selector(_loadedMovieDataOfItemsInContainer:) withObject:container];
}



- (void)_loadedMovieDataOfFile:(SPPlaylistFile *)file duration:(NSValue *)duration dimensions:(NSValue *)dimensions {
	NSTimeInterval		interval;
	
	if(QTGetTimeInterval([duration QTTimeValue], &interval))
		[file setDuration:interval];
	
	[file setDimensions:[dimensions sizeValue]];
	[file setSize:[file sizeOnDisk]];
	
	if(_delegatePlaylistLoaderDidLoadMovieDataOfFile)
		[delegate playlistLoader:self didLoadMovieDataOfFile:file];
}



- (void)_loadedMovieDataOfItemsInContainer:(SPPlaylistContainer *)container {
	if(_delegatePlaylistLoaderDidLoadMovieDataOfItemsInContainer)
		[delegate playlistLoader:self didLoadMovieDataOfItemsInContainer:container];
}



- (void)_loadMetadata:(SPPlaylistContainer *)container {
	NSArray					*items, *matches;
	NSMutableDictionary		*metadata;
	NSDictionary			*dictionary;
	NSImage					*image;
	NSError					*error;
	NSString				*title;
	NSNumber				*season, *episode;
	SPPlaylistFile			*file;
	id						item;
	
	items = [[[container items] copy] autorelease];
	
	for(item in items) {
		if(_delegatePlaylistLoaderIsProcessingWithStatus) {
			[(id) delegate performSelectorOnMainThread:@selector(playlistLoader:isProcessingWithStatus:)
											withObject:self
											withObject:NSLS(@"Loading IMDb metadata...", @"Playlist status")
										 waitUntilDone:NO];
		}
		
		if([item isKindOfClass:[SPPlaylistFile class]]) {
			file		= item;
			dictionary	= [[SPFilenameMetadataGatherer sharedGatherer] metadataForName:[file cleanName]];
			title		= [dictionary objectForKey:SPFilenameMetadataTitleKey];
			
			if(![file metadata] || ![file IMDbMatch] ||
			   ![title isEqualToString:[[file metadata] objectForKey:SPFilenameMetadataTitleKey]]) {
				metadata = [dictionary mutableCopy];
				
				if([[file IMDbMatches] count] == 0) {
					matches = [[SPIMDbMetadataGatherer sharedGatherer] matchesForName:
						[metadata objectForKey:SPFilenameMetadataTitleKey] error:&error];
					
					[file setIMDbMatches:matches];
				}
				
				if(![file IMDbMatch] && [[file IMDbMatches] count] > 0)
					[file setIMDbMatch:[[file IMDbMatches] objectAtIndex:0]];
				
				if([file IMDbMatch] && ![[file IMDbMatch] isNullMatch]) {
					dictionary = [[SPIMDbMetadataGatherer sharedGatherer] metadataForMatch:[file IMDbMatch] error:&error];
					
					if(dictionary)
						[metadata addEntriesFromDictionary:dictionary];
					
					season = [metadata objectForKey:SPFilenameMetadataTVShowSeasonKey];
					episode = [metadata objectForKey:SPFilenameMetadataTVShowEpisodeKey];
					
					if(season && episode) {
						dictionary = [[SPIMDbMetadataGatherer sharedGatherer]
							TVMetadataForMatch:[file IMDbMatch]
										season:[season unsignedIntegerValue]
									   episode:[episode unsignedIntegerValue]
										 error:&error];
						
						if(dictionary)
							[metadata addEntriesFromDictionary:dictionary];
					}
					
					image = [[SPIMDbMetadataGatherer sharedGatherer] posterImageForMatch:[file IMDbMatch] error:&error];
					
					if(image)
						[file setPosterImage:image];
				}
				
				if([metadata count] > 0)
					[file setMetadata:metadata];
				
				[self performSelectorOnMainThread:@selector(_loadedMetadataOfFile:)
									   withObject:file
									waitUntilDone:YES];
			
				[metadata release];
			}
		}
	}

	[self performSelectorOnMainThread:@selector(_loadedMetadataOfItemsInContainer:) withObject:container];
}



- (void)_loadedMetadataOfFile:(SPPlaylistFile *)file {
	if(_delegatePlaylistLoaderDidLoadMetadataOfFile)
		[delegate playlistLoader:self didLoadMetadataOfFile:file];
}



- (void)_loadedMetadataOfItemsInContainer:(SPPlaylistContainer *)container {
	if(_delegatePlaylistLoaderDidLoadMetadataOfItemsInContainer)
		[delegate playlistLoader:self didLoadMetadataOfItemsInContainer:container];
}



- (void)_loadedQuery:(NSMetadataQuery *)query forSmartGroup:(SPPlaylistSmartGroup *)smartGroup {
	NSString			*path;
	id					item;
	NSUInteger			i, count;
	
	if([smartGroup isLoading]) {
		[smartGroup removeAllFiles];
		[smartGroup setLoading:NO];
	}
	
	count = [query resultCount];
	
	for(i = [smartGroup queryIndex]; i < count; i++) {
		path = [[query resultAtIndex:i] valueForAttribute:@"kMDItemPath"];
		item = [smartGroup itemForPath:path];
		
		if(!item) {
			if(![[SPMovieController movieFileTypes] containsObject:[[path pathExtension] lowercaseString]])
				continue;
			
			item = [SPPlaylistRepresentedFile fileWithPath:path];
		}
		
		[smartGroup addItem:item];
	}
	
	[smartGroup sortUsingSelector:[[SPSettings settings] boolForKey:SPSimplifyFilenames]
		? @selector(compareCleanName:)
		: @selector(compareName:)];

	[smartGroup setQueryIndex:i];
}

@end


@implementation SPPlaylistLoader

+ (void)setMovieDataForFile:(SPPlaylistFile *)file movie:(QTMovie *)movie {
	NSTimeInterval		interval;
	
	if(QTGetTimeInterval([[movie attributeForKey:QTMovieDurationAttribute] QTTimeValue], &interval))
		[file setDuration:interval];
	
	[file setDimensions:[[movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue]];
	[file setSize:[file sizeOnDisk]];
}



#pragma mark -

- (id)init {
	self = [super init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryGatheringProgress:)
			   name:NSMetadataQueryGatheringProgressNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(metadataQueryDidFinishGathering:)
			   name:NSMetadataQueryDidFinishGatheringNotification];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (void)metadataQueryGatheringProgress:(NSNotification *)notification {
	if(_delegatePlaylistLoaderIsProcessingWithStatus) {
		[(id) delegate performSelectorOnMainThread:@selector(playlistLoader:isProcessingWithStatus:)
										withObject:self
										withObject:NSLS(@"Loading Spotlight query...", @"Playlist status")
									 waitUntilDone:NO];
	}
		
	[self _loadedQuery:[notification object] forSmartGroup:[[notification object] delegate]];

	if(_delegatePlaylistLoaderDidLoadItemsForSmartGroup)
		[delegate playlistLoader:self didLoadItemsForSmartGroup:[[notification object] delegate]];
}



- (void)metadataQueryDidFinishGathering:(NSNotification *)notification {
	[[[notification object] delegate] setLoading:NO];

	if(_delegatePlaylistLoaderDidLoadSmartGroup)
		[delegate playlistLoader:self didLoadSmartGroup:[[notification object] delegate]];
}



#pragma mark -

- (void)loadFolderThread:(id)object {
	NSAutoreleasePool		*pool;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	[self _loadFolder:object];
	
	[pool release];
}



- (void)loadMovieDataThread:(id)object {
	NSAutoreleasePool		*pool;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	[QTMovie enterQTKitOnThreadDisablingThreadSafetyProtection];

	[self _loadMovieData:object];
	
	[QTMovie exitQTKitOnThread];
	
	[pool release];
}



- (void)loadMetadataThread:(id)object {
	NSAutoreleasePool		*pool;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	[self _loadMetadata:object];
	
	[pool release];
}



#pragma mark -

- (void)setDelegate:(id <SPPlaylistLoaderDelegate>)aDelegate {
	delegate = aDelegate;

	_delegatePlaylistLoaderIsProcessingWithStatus =
		[delegate respondsToSelector:@selector(playlistLoader:isProcessingWithStatus:)];
	
	_delegatePlaylistLoaderDidLoadFile =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadFile:)];
	
	_delegatePlaylistLoaderDidLoadContentsOfFolder =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadContentsOfFolder:)];
	
	_delegatePlaylistLoaderDidLoadMovieDataOfFile =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadMovieDataOfFile:)];
	
	_delegatePlaylistLoaderDidLoadMovieDataOfItemsInContainer =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadMovieDataOfItemsInContainer:)];
	
	_delegatePlaylistLoaderDidLoadMetadataOfFile =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadMetadataOfFile:)];
	
	_delegatePlaylistLoaderDidLoadMetadataOfItemsInContainer =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadMetadataOfItemsInContainer:)];
	
	_delegatePlaylistLoaderDidLoadItemsForSmartGroup =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadItemsForSmartGroup:)];
	
	_delegatePlaylistLoaderDidLoadSmartGroup =
		[delegate respondsToSelector:@selector(playlistLoader:didLoadSmartGroup:)];
}



- (id <SPPlaylistLoaderDelegate>)delegate {
	return delegate;
}



#pragma mark -

- (void)loadContentsOfFolder:(SPPlaylistFolder *)folder synchronously:(BOOL)synchronously {
	if(![folder isLoading]) {
		[folder setLoading:YES];
		
		if(synchronously)
			[self _loadFolder:folder];
		else
			[NSThread detachNewThreadSelector:@selector(loadFolderThread:) toTarget:self withObject:folder];
	}
}



- (void)loadMovieDataOfItemsInContainer:(SPPlaylistContainer *)container synchronously:(BOOL)synchronously {
	if(synchronously)
		[self _loadMovieData:container];
	else
		[NSThread detachNewThreadSelector:@selector(loadMovieDataThread:) toTarget:self withObject:container];
}



- (void)loadMetadataOfItemsInContainer:(SPPlaylistContainer *)container synchronously:(BOOL)synchronously {
	if(synchronously)
		[self _loadMetadata:container];
	else
		[NSThread detachNewThreadSelector:@selector(loadMetadataThread:) toTarget:self withObject:container];
}



- (void)loadSmartGroup:(SPPlaylistSmartGroup *)smartGroup synchronously:(BOOL)synchronously {
	NSPredicate			*predicate;
	NSMetadataQuery		*query;
	
	predicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:
		[NSPredicate predicateWithFormat:@"kMDItemContentTypeTree == 'public.movie'"],
		[[smartGroup class] metadataQueryPredicateForPredicate:[smartGroup predicate]],
		NULL]];
	
	query = [[NSMetadataQuery alloc] init];
	[query setPredicate:predicate];
	[query setDelegate:smartGroup];
	[smartGroup setLoading:YES];
	[smartGroup setQuery:query];
	[query startQuery];
	[query release];
	
	if(synchronously) {
		while([smartGroup isLoading])
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
}

@end
