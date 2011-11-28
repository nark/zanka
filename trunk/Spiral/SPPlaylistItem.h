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

#import "SPExportJob.h"

@interface SPPlaylistItem : WIObject <NSCoding> {
	NSString								*_name;
	NSString								*_identifier;
	id										_parentItem;
	BOOL									_expanded;
	BOOL									_recent;
	NSMutableDictionary						*_icons;
}

+ (id)itemWithName:(NSString *)name;
- (id)initWithName:(NSString *)name;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (NSString *)cleanName;
- (NSImage *)icon;
- (NSImage *)iconWithSize:(NSSize)size;
- (NSString *)identifier;
- (id)parentItem;
- (BOOL)isInFileSystem;
- (BOOL)isRepresented;
- (NSString *)playlistPath;
- (void)setExpanded:(BOOL)expanded;
- (BOOL)isExpanded;
- (void)setRecent:(BOOL)recent;
- (BOOL)isRecent;

- (NSComparisonResult)compareName:(id)object;
- (NSComparisonResult)compareCleanName:(id)object;

@end


enum _SPPlaylistViewStatus {
	SPPlaylistViewed						= 0,
	SPPlaylistHalfViewed,
	SPPlaylistUnviewed
};
typedef enum _SPPlaylistViewStatus	SPPlaylistViewStatus;

@class SPIMDbMetadataMatch;

@interface SPPlaylistFile : SPPlaylistItem {
	NSString								*_path;
	AliasHandle								_alias;
	NSImage									*_icon;
	unsigned long long						_size;
	double									_viewCount;
	NSTimeInterval							_location;
	NSTimeInterval							_duration;
	NSSize									_dimensions;
	
	NSLock									*_metadataLock;
	NSDictionary							*_metadata;
	NSArray									*_matches;
	SPIMDbMetadataMatch						*_match;
	NSImage									*_image;
	
	NSString								*_cleanName;
}

+ (id)fileWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;

- (void)copyAttributesFromFile:(SPPlaylistFile *)file;

- (void)setPath:(NSString *)path;
- (NSString *)path;
- (NSString *)resolvedPath;
- (void)setSize:(unsigned long long)size;
- (unsigned long long)size;
- (unsigned long long)sizeOnDisk;
- (void)setViewCount:(double)count;
- (double)viewCount;
- (SPPlaylistViewStatus)viewStatus;
- (void)setLocation:(NSTimeInterval)location;
- (NSTimeInterval)location;
- (void)setDuration:(NSTimeInterval)duration;
- (NSTimeInterval)duration;
- (void)setDimensions:(NSSize)dimensions;
- (NSSize)dimensions;
- (void)setMetadata:(NSDictionary *)metadata;
- (NSDictionary *)metadata;
- (void)setIMDbMatches:(NSArray *)matches;
- (NSArray *)IMDbMatches;
- (void)setIMDbMatch:(SPIMDbMetadataMatch *)match;
- (SPIMDbMetadataMatch *)IMDbMatch;
- (void)setPosterImage:(NSImage *)image;
- (NSImage *)posterImage;

@end


@interface SPPlaylistRepresentedFile : SPPlaylistFile

@end


@interface SPPlaylistContainer : SPPlaylistItem {
	NSMutableArray							*_sortedItems;
	NSMutableDictionary						*_allItems;
	NSMutableArray							*_shuffledItems;
	BOOL									_loading;
}

- (id)itemForPath:(NSString *)path;
- (id)itemForPlaylistPath:(NSString *)path;
- (void)setItems:(NSArray *)items;
- (void)addItem:(id)item;
- (NSUInteger)numberOfItems;
- (NSArray *)items;
- (NSArray *)shuffledItems;
- (void)startShufflingFromItem:(id)item;
- (void)sortUsingSelector:(SEL)selector;
- (void)sortItemsUsingSelector:(SEL)selector;
- (void)setLoading:(BOOL)loading;
- (BOOL)isLoading;

@end


@interface SPPlaylistGroup : SPPlaylistContainer

+ (id)groupWithName:(NSString *)name;

- (void)insertItem:(id)item atIndex:(NSUInteger)index;
- (void)removeItem:(id)item;
- (void)removeItemAtIndex:(NSUInteger)index;

@end


@interface SPPlaylistFolder : SPPlaylistContainer {
	NSString								*_path;
	AliasHandle								_alias;

	NSString								*_cleanName;
}

+ (id)folderWithPath:(NSString *)path;
+ (id)folderWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;

- (void)setPath:(NSString *)path;
- (NSString *)path;
- (NSString *)resolvedPath;

@end


@interface SPPlaylistRepresentedFolder : SPPlaylistFolder

@end


@interface SPPlaylistSmartGroup : SPPlaylistContainer {
	NSPredicate								*_predicate;
	NSMetadataQuery							*_query;
	NSUInteger								_queryIndex;
}

+ (NSPredicate *)metadataQueryPredicateForPredicate:(id)predicate;

+ (id)smartGroupWithName:(NSString *)name;

- (void)setPredicate:(NSPredicate *)predicate;
- (NSPredicate *)predicate;
- (void)setQuery:(NSMetadataQuery *)query;
- (NSMetadataQuery *)query;
- (void)setQueryIndex:(NSUInteger)queryIndex;
- (NSUInteger)queryIndex;

- (void)removeAllFiles;

@end


enum _SPPlaylistExportDestination {
	SPPlaylistExportToOriginalPath			= 0,
	SPPlaylistExportToiTunes,
	SPPlaylistExportToPath
};
typedef enum _SPPlaylistExportDestination	SPPlaylistExportDestination;

@interface SPPlaylistExportGroup : SPPlaylistGroup {
	NSString								*_format;
	SPPlaylistExportDestination				_destination;
	NSString								*_destinationPath;
}

+ (id)exportGroupWithName:(NSString *)name;

- (void)setFormat:(NSString *)format;
- (NSString *)format;
- (void)setDestination:(SPPlaylistExportDestination)destination;
- (SPPlaylistExportDestination)destination;
- (void)setDestinationPath:(NSString *)destinationPath;
- (NSString *)destinationPath;

@end


@class SPExportJob;

@interface SPPlaylistExportItem : SPPlaylistItem {
	NSString								*_path;
	NSString								*_destinationPath;
	NSImage									*_icon;
	SPExportJob								*_job;
	NSDictionary							*_metadata;

	NSString								*_cleanName;
}

+ (id)exportItemWithPath:(NSString *)path;

- (void)setPath:(NSString *)path;
- (NSString *)path;
- (void)setDestinationPath:(NSString *)destinationPath;
- (NSString *)destinationPath;
- (void)setMetadata:(NSDictionary *)metadata;
- (NSDictionary *)metadata;
- (void)setJob:(SPExportJob *)job;
- (SPExportJob *)job;

@end
