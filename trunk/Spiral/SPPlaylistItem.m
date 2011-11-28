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

#import "NSString-SPAdditions.h"
#import "NSImage-SPAdditions.h"
#import "SPPlaylistItem.h"

static NSMutableDictionary			*SPPlaylistItemItems;

@interface SPPlaylistItem(Private)

+ (void)_setItem:(id)item forIdentifier:(NSString *)identifier;
+ (id)_itemForIdentifier:(NSString *)identifier;

+ (AliasHandle)_aliasForPath:(NSString *)path;
+ (NSString *)_pathForAlias:(AliasHandle)alias;
+ (NSData *)_dataForAlias:(AliasHandle)alias;
+ (AliasHandle)_aliasForData:(NSData *)data;

+ (NSString *)_cleanNameFromPath:(NSString *)path;
+ (NSString *)_cleanNameFromName:(NSString *)name;

- (BOOL)_encodeItemsInContainers;
- (BOOL)_encodeInContainers;

@end


@implementation SPPlaylistItem(Private)

+ (void)_setItem:(id)item forIdentifier:(NSString *)identifier {
	if(!SPPlaylistItemItems)
		SPPlaylistItemItems = [[NSMutableDictionary alloc] init];
	
	[SPPlaylistItemItems setObject:item forKey:identifier];
}



+ (id)_itemForIdentifier:(NSString *)identifier {
	return [SPPlaylistItemItems objectForKey:identifier];
}



#pragma mark -

+ (AliasHandle)_aliasForPath:(NSString *)path {
	CFURLRef		url;
	FSRef			fs;
	AliasHandle		alias = NULL;
	
	url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef) path, kCFURLPOSIXPathStyle, true);
	
	if(url) {
		if(CFURLGetFSRef(url, &fs))
			FSNewAliasMinimal(&fs, &alias);

		CFRelease(url);
	}
	
	return alias;
}



+ (NSString *)_pathForAlias:(AliasHandle)alias {
	NSString		*path;
	CFURLRef		url;
	FSRef			fs;
	Boolean			needsUpdate;
	OSStatus		status;
	short			aliasCount;
	
	if(!alias)
		return NULL;
	
	aliasCount = 1;
	status = FSMatchAliasBulk(NULL, kARMSearch | kARMNoUI, alias, &aliasCount, &fs, &needsUpdate, NULL, NULL);
	
	if(status != noErr)
		return NULL;
	
	url = CFURLCreateFromFSRef(NULL, &fs);
	
	if(!url)
		return NULL;

	path = (NSString *) CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
	
	CFRelease(url);
	
	return [path autorelease];
}



+ (NSData *)_dataForAlias:(AliasHandle)alias {
	NSData		*data;
	Handle		handle;
	
	if(!alias)
		return NULL;
	
	handle = (Handle) alias;
	
	HLock(handle);
	data = [NSData dataWithBytes:*alias length:GetHandleSize(handle)];
	HUnlock(handle);
	
	return data;
}



+ (AliasHandle)_aliasForData:(NSData *)data {
	Handle		handle;
	NSUInteger	length;
	
	if(!data)
		return NULL;
	
	length = [data length];
	handle = NewHandle(length);
	
	if(handle && length > 0) {
		HLock(handle);
		memmove(*handle, [data bytes], length);
		HUnlock(handle);
	}
	
	return (AliasHandle) handle;
}



#pragma mark -

+ (NSString *)_cleanNameFromPath:(NSString *)path {
	NSString		*name, *directory, *string, *unique;
	
	name = [self _cleanNameFromName:[path lastPathComponent]];
	
	// Completely useless release name
	string = [name stringByMatching:@"^(\\p{Ll}+?)-[\\p{Ll}\\p{Pd}\\p{Nd}]+? ?((cd)?\\d?)$" capture:2];
	
	if(string) {
		unique		= [string uppercaseString];
		directory	= [[path stringByDeletingLastPathComponent] lastPathComponent];
		string		= [directory stringByMatching:@"^cd\\.*\\d$" options:RKLCaseless capture:0];
		
		if(!string)
			string		= [directory stringByMatching:@"^(\\p{Ll}+?)-[\\p{Ll}\\p{Pd}\\p{Nd}]+?((cd)?\\d?)$" options:RKLCaseless capture:2];
		
		if(string) {
			unique		= string;
			directory	= [[[path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] lastPathComponent];
		}
		
		return [NSSWF:@"%@ %@", [self _cleanNameFromName:directory], unique];
	}
	
	return name;
}



+ (NSString *)_cleanNameFromName:(NSString *)name {
	NSMutableString		*cleanName;
	
	cleanName = [name mutableCopy];
	
	// File extension
	[cleanName replaceOccurrencesOfRegex:@"\\.(\\w|\\d)+$" withString:@""];
	
	// Common strings, case insensitive
	[cleanName replaceOccurrencesOfRegex:@"("
										 @"pdvdrip|blu720p|blu1080p|dts-es|"
										 @")"
							  withString:@""
								 options:RKLCaseless];
	
	// Common strings, case insensitive
	[cleanName replaceOccurrencesOfRegex:@"("
										 @"dvdrip|dvd-rip|dvdscr|divx|hddvd|x264|h264|bluray|blu-ray|720p|1080p|xvid|ac3|"
										 @"dts|5\\.1|aac|rdq|hdtv|pdtv|r5.line|multisubs|swesub|telesync|cinedub|dsr|disc\\d"
										 @")"
							  withString:@""
								 options:RKLCaseless];
	
	// Common strings, case sensitive
	[cleanName replaceOccurrencesOfRegex:@"("
										 @"L(i|I)M(i|I)TED|R5|TS|MD|LD|CAM|PROPER|REPACK|HQ|(i|I)TAL(i|I)AN?|S(i|I)LENT|2CD|DVD|"
										 @"CN|FRENCH"
										 @")"
							  withString:@""];
	
	// Resolution
	[cleanName replaceOccurrencesOfRegex:@"\\d{3,}+x\\d{3,}+" withString:@""];

	// Year
	[cleanName replaceOccurrencesOfRegex:@"(19\\d{2}|200\\d||201\\d)" withString:@""];
	
	// Episode numbers within [], () and {}
	[cleanName replaceOccurrencesOfRegex:@"\\(" @"(\\d+x\\d+|S\\d+E\\d+)" @"\\)" withString:@"$1" options:RKLCaseless];
	[cleanName replaceOccurrencesOfRegex:@"\\[" @"(\\d+x\\d+|S\\d+E\\d+)" @"\\]" withString:@"$1" options:RKLCaseless];
	[cleanName replaceOccurrencesOfRegex:@"\\{" @"(\\d+x\\d+|S\\d+E\\d+)" @"\\}" withString:@"$1" options:RKLCaseless];

	// Everything within [], () and {}
	[cleanName replaceOccurrencesOfRegex:@"\\(.*?\\)" withString:@" "];
	[cleanName replaceOccurrencesOfRegex:@"\\[.*?\\]" withString:@" "];
	[cleanName replaceOccurrencesOfRegex:@"\\{.*?\\}" withString:@" "];
	
	// Web site
	[cleanName replaceOccurrencesOfRegex:@"www\\.(\\w|\\d|\\.|_)+\\.(\\w){2,3}" withString:@"" options:RKLCaseless];
	
	// Punctuation
	[cleanName replaceOccurrencesOfString:@" - " withString:@" "];
	[cleanName replaceOccurrencesOfString:@"_" withString:@" "];
	[cleanName replaceOccurrencesOfString:@"." withString:@" "];

	// Duplicates
	[cleanName replaceOccurrencesOfRegex:@"(\\.|-|\\s){2,}" withString:@"$1"];

	// Whitespace and punctuation at beginning/end of string
	[cleanName replaceOccurrencesOfRegex:@"^(\\s|\\.|\\-)*" @"(.+?)" @"(\\s|\\.|\\-)*$" withString:@"$2"];
	
	// Release group
	[cleanName replaceOccurrencesOfRegex:@"-"
										 @"[\\p{Lu}\\p{Ll}\\p{So}\\p{Nd}]*?"
										 @"\\p{Lu}"
										 @"[\\p{Lu}\\p{Ll}\\p{So}\\p{Nd}]*?"
										 @"[\\p{Lu}\\p{Ll}\\p{So}]+?$"
							  withString:@""];
	
	if([cleanName length] == 0)
		[cleanName setString:[name stringByReplacingOccurrencesOfRegex:@"\\.(\\w|\\d)+$" withString:@""]];
	
	return [cleanName autorelease];
}



- (BOOL)_encodeItemsInContainers {
	return YES;
}



- (BOOL)_encodeInContainers {
	return YES;
}

@end



NSString * SPPlaylistItemMetadataNameKey			= @"SPPlaylistItemMetadataNameKey";
NSString * SPPlaylistItemMetadataMediaKindKey		= @"SPPlaylistItemMetadataMediaKindKey";
NSString * SPPlaylistItemMetadataYearKey			= @"SPPlaylistItemMetadataYearKey";
NSString * SPPlaylistItemMetadataTVShowNameKey		= @"SPPlaylistItemMetadataTVShowNameKey";
NSString * SPPlaylistItemMetadataTVShowSeasonKey	= @"SPPlaylistItemMetadataTVShowSeasonKey";
NSString * SPPlaylistItemMetadataTVShowEpisodeKey	= @"SPPlaylistItemMetadataTVShowEpisodeKey";
NSString * SPPlaylistItemMetadataEncodingToolKey	= @"SPPlaylistItemMetadataEncodingToolKey";

@implementation SPPlaylistItem

+ (NSInteger)version {
	return 2;
}



#pragma mark -

+ (id)itemWithName:(NSString *)name {
	return [[[self alloc] initWithName:name] autorelease];
}



- (id)initWithName:(NSString *)name {
	self = [super init];
	
	_name			= [name retain];
	_identifier		= [[NSString UUIDString] retain];
	
	[[self class] _setItem:[NSValue valueWithNonretainedObject:self] forIdentifier:_identifier];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	_name				= [[coder decodeObjectForKey:@"SPPlaylistItemName"] retain];
	_identifier			= [[coder decodeObjectForKey:@"SPPlaylistItemIdentifier"] retain];
	_expanded			= [coder decodeBoolForKey:@"SPPlaylistItemExpanded"];
	_recent				= [coder decodeBoolForKey:@"SPPlaylistItemRecent"];
	
	_parentItem			= [[[self class] _itemForIdentifier:[coder decodeObjectForKey:@"SPPlaylistItemParentIdentifier"]] nonretainedObjectValue];
	
	[[self class] _setItem:[NSValue valueWithNonretainedObject:self] forIdentifier:_identifier];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeInteger:[[self class] version] forKey:@"SPPlaylistItemVersion"];

	[coder encodeObject:_name forKey:@"SPPlaylistItemName"];
	[coder encodeObject:_identifier forKey:@"SPPlaylistItemIdentifier"];
	[coder encodeBool:_expanded forKey:@"SPPlaylistItemExpanded"];
	[coder encodeBool:_recent forKey:@"SPPlaylistItemRecent"];

	[coder encodeObject:[_parentItem identifier] forKey:@"SPPlaylistItemParentIdentifier"];
}



- (BOOL)isEqual:(id)other {
	SPPlaylistItem	*item = other;
	
	return (item && [_identifier isEqualToString:item->_identifier]);
}



- (NSString *)description {
	return [NSSWF:@"<%@: %p>{name = %@, parent = %p}",
		[self class], self, [self name], [self parentItem]];
}



- (void)dealloc {
	[_name release];
	[_identifier release];
	[_icons release];
	
	[super dealloc];
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];
	
	_name = name;
}



- (NSString *)name {
	return _name;
}



- (NSString *)cleanName {
	return [self name];
}



- (NSDictionary *)metadata {
	return NULL;
}



- (NSImage *)icon {
	return NULL;
}



- (NSImage *)iconWithSize:(NSSize)size {
	NSImage		*icon;
	NSNumber	*width;
	
	if(!_icons)
		_icons = [[NSMutableDictionary alloc] init];
	
	width = [NSNumber numberWithDouble:size.width];
	icon = [_icons objectForKey:width];
	
	if(!icon) {
		icon = [[self icon] copy];
		[icon setSize:size];
		[_icons setObject:icon forKey:width];
		[icon release];
	}
	
	if([self isInFileSystem] && ![[NSFileManager defaultManager] fileExistsAtPath:[(SPPlaylistFile *) self resolvedPath]])
		icon = [icon imageBySuperImposingQuestionMark];
	
	return icon;
}



- (NSString *)identifier {
	return _identifier;
}



- (id)parentItem {
	return _parentItem;
}



- (void)clearParent {
	_parentItem = NULL;
}



- (BOOL)isInFileSystem {
	return ([self isKindOfClass:[SPPlaylistFile class]] || [self isKindOfClass:[SPPlaylistFolder class]]);
}



- (BOOL)isRepresented {
	return ([self isKindOfClass:[SPPlaylistRepresentedFile class]] || [self isKindOfClass:[SPPlaylistRepresentedFolder class]]);
}



- (NSString *)playlistPath {
	NSMutableArray		*components;
	id					item;
	
	components = [NSMutableArray array];
	
	item = self;
	
	do {
		[components addObject:[item name]];
		
		item = [item parentItem];
	} while(item != NULL);
	
	[components reverse];
	[components replaceObjectAtIndex:0 withObject:@"/"];
	
	return [NSString pathWithComponents:components];
}



- (void)setExpanded:(BOOL)expanded {
	_expanded = expanded;
}



- (BOOL)isExpanded {
	return _expanded;
}



- (void)setRecent:(BOOL)recent {
	_recent = recent;
}



- (BOOL)isRecent {
	return _recent;
}



#pragma mark -

- (NSComparisonResult)compareName:(id)object {
	return [[self name] compare:[object name] options:NSCaseInsensitiveSearch | NSNumericSearch];
}



- (NSComparisonResult)compareCleanName:(id)object {
	return [[self cleanName] compare:[object cleanName] options:NSCaseInsensitiveSearch | NSNumericSearch];
}

@end



@implementation SPPlaylistFile

+ (id)fileWithPath:(NSString *)path {
	return [[[self alloc] initWithPath:path] autorelease];
}



- (id)initWithPath:(NSString *)path {
	self = [super initWithName:[[NSFileManager defaultManager] displayNameAtPath:path]];
	
	[self setPath:path];

	_alias			= [[self class] _aliasForPath:[self path]];
	_metadataLock	= [[NSLock alloc] init];
	
	[self setSize:[self sizeOnDisk]];

	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	NSInteger		version;
	
	self = [super initWithCoder:coder];
	
	if(self) {
		version = [coder decodeIntegerForKey:@"SPPlaylistItemVersion"];
		
		[self setPath:[coder decodeObjectForKey:@"SPPlaylistFilePath"]];
		
		if(version == 1)
			[self setViewCount:[coder decodeInt32ForKey:@"SPPlaylistFileViewCount"]];
		else
			[self setViewCount:[coder decodeDoubleForKey:@"SPPlaylistFileViewCount"]];
		
		[self setLocation:[coder decodeDoubleForKey:@"SPPlaylistFileLocation"]];
		[self setSize:[coder decodeInt64ForKey:@"SPPlaylistFileSize"]];
		[self setDuration:[coder decodeDoubleForKey:@"SPPlaylistFileDuration"]];
		[self setDimensions:[coder decodeSizeForKey:@"SPPlaylistFileDimensions"]];
		
		[self setMetadata:[coder decodeObjectForKey:@"SPPlaylistFileMetadata"]];
		[self setIMDbMatches:[coder decodeObjectForKey:@"SPPlaylistFileIMDbMatches"]];
		[self setIMDbMatch:[coder decodeObjectForKey:@"SPPlaylistFileIMDbMatch"]];
		[self setPosterImage:[coder decodeObjectForKey:@"SPPlaylistFilePosterImage"]];
		
		_metadataLock	= [[NSLock alloc] init];
		_alias			= [[self class] _aliasForData:[coder decodeObjectForKey:@"SPPlaylistFileAlias"]];
	}

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self path] forKey:@"SPPlaylistFilePath"];
	[coder encodeObject:[[self class] _dataForAlias:_alias] forKey:@"SPPlaylistFileAlias"];
	[coder encodeDouble:[self viewCount] forKey:@"SPPlaylistFileViewCount"];
	[coder encodeInt64:[self size] forKey:@"SPPlaylistFileSize"];
	[coder encodeDouble:[self location] forKey:@"SPPlaylistFileLocation"];
	[coder encodeDouble:[self duration] forKey:@"SPPlaylistFileDuration"];
	[coder encodeSize:[self dimensions] forKey:@"SPPlaylistFileDimensions"];
	[coder encodeObject:[self metadata] forKey:@"SPPlaylistFileMetadata"];
	[coder encodeObject:[self IMDbMatches] forKey:@"SPPlaylistFileIMDbMatches"];
	[coder encodeObject:[self IMDbMatch] forKey:@"SPPlaylistFileIMDbMatch"];
	[coder encodeObject:[self posterImage] forKey:@"SPPlaylistFilePosterImage"];
}



- (void)dealloc {
	[_path release];
	[_icon release];

	[_metadataLock release];
	[_metadata release];
	[_matches release];
	[_match release];
	[_image release];
	
	[_cleanName release];
	
	if(_alias)
		DisposeHandle((Handle) _alias);
	
	[super dealloc];
}



#pragma mark -

- (void)copyAttributesFromFile:(SPPlaylistFile *)file {
	[self setDuration:[file duration]];
	[self setDimensions:[file dimensions]];
	[self setViewCount:[file viewCount]];
	[self setLocation:[file location]];
}



#pragma mark -

- (NSString *)cleanName {
	if(!_cleanName) {
		if([self path])
			_cleanName = [[[self class] _cleanNameFromPath:[self path]] retain];
		else
			_cleanName = [[[self class] _cleanNameFromName:[self name]] retain];
	}
	
	return _cleanName;
}



- (void)setPath:(NSString *)path {
	[path retain];
	[_path release];
	
	_path = path;
	
	[_icon release];
	_icon = [[[NSWorkspace sharedWorkspace] iconForFile:_path] retain];
	
	[_name release];
	_name = [[[NSFileManager defaultManager] displayNameAtPath:path] retain];
	
	[_cleanName release];
	_cleanName = NULL;
}



- (NSString *)path {
	return _path;
}



- (NSString *)resolvedPath {
	NSString		*path;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:[self path]])
		return [self path];
	
	path = [[self class] _pathForAlias:_alias];
	
	if(path)
		return path;
	
	return [self path];
}



- (NSImage *)icon {
	return _icon;
}



- (void)setSize:(unsigned long long)size {
	_size = size;
}



- (unsigned long long)size {
	return _size;
}



- (unsigned long long)sizeOnDisk {
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:[self resolvedPath] error:NULL] fileSize];
}



- (void)setViewCount:(double)count {
	_viewCount = count;
}



- (double)viewCount {
	return _viewCount;
}



- (SPPlaylistViewStatus)viewStatus {
	if(_viewCount > 0.05) {
		if(_viewCount < 0.95)
			return SPPlaylistHalfViewed;
		else
			return SPPlaylistViewed;
	}
	
	return SPPlaylistUnviewed;
}



- (void)setLocation:(NSTimeInterval)location {
	_location = location;
}



- (NSTimeInterval)location {
	return _location;
}



- (void)setDuration:(NSTimeInterval)duration {
	_duration = duration;
}



- (NSTimeInterval)duration {
	return _duration;
}



- (void)setDimensions:(NSSize)dimensions {
	_dimensions = dimensions;
}



- (NSSize)dimensions {
	return _dimensions;
}



- (void)setMetadata:(NSDictionary *)metadata {
	[_metadataLock lock];
	
	[metadata retain];
	[_metadata release];
	
	_metadata = metadata;

	[_metadataLock unlock];
}



- (NSDictionary *)metadata {
	NSDictionary	*metadata;
	
	[_metadataLock lock];
	metadata = [[_metadata retain] autorelease];
	[_metadataLock unlock];
	
	return metadata;
}



- (void)setIMDbMatches:(NSArray *)matches {
	[_metadataLock lock];

	[matches retain];
	[_matches release];
	
	_matches = matches;

	[_metadataLock unlock];
}



- (NSArray *)IMDbMatches {
	NSArray			*matches;
	
	[_metadataLock lock];
	matches = [[_matches retain] autorelease];
	[_metadataLock unlock];
	
	return matches;
}



- (void)setIMDbMatch:(SPIMDbMetadataMatch *)match {
	[_metadataLock lock];
	
	[match retain];
	[_match release];
	
	_match = match;

	[_metadataLock unlock];
}



- (SPIMDbMetadataMatch *)IMDbMatch {
	SPIMDbMetadataMatch		*match;
	
	[_metadataLock lock];
	match = [[_match retain] autorelease];
	[_metadataLock unlock];
	
	return match;
}



- (void)setPosterImage:(NSImage *)image {
	[_metadataLock lock];

	[image retain];
	[_image release];
	
	_image = image;

	[_metadataLock unlock];
}



- (NSImage *)posterImage {
	NSImage		*image;
	
	[_metadataLock lock];
	image = [[_image retain] autorelease];
	[_metadataLock unlock];
	
	return image;
}

@end



@implementation SPPlaylistRepresentedFile

@end



@interface SPPlaylistContainer(Private)

- (id)_itemWithName:(NSString *)name;

- (void)_addItem:(id)item;
- (void)_insertItem:(id)item atIndex:(NSUInteger)index;
- (void)_removeItem:(id)item;
- (void)_removeItemAtIndex:(NSUInteger)index;
- (void)_removeAllItems;

@end


@implementation SPPlaylistContainer(Private)

- (id)_itemWithName:(NSString *)name {
	id		item;
	
	for(item in _sortedItems) {
		if([[item name] isEqualToString:name])
			return item;
	}
	
	return NULL;
}



#pragma mark -

- (void)_addItem:(id)item {
	((SPPlaylistItem *) item)->_parentItem = self;
	
	[_sortedItems addObject:item];
	
	if([item isInFileSystem])
		[_allItems setObject:item forKey:[item path]];
	
	if(_shuffledItems) {
		if([_shuffledItems count] == 0)
			[_shuffledItems addObject:item];
		else
			[_shuffledItems insertObject:item atIndex:random() % [_shuffledItems count]];
	}
}



- (void)_insertItem:(id)item atIndex:(NSUInteger)index {
	((SPPlaylistItem *) item)->_parentItem = self;
	
	[_sortedItems insertObject:item atIndex:index];

	if([item isInFileSystem])
		[_allItems setObject:item forKey:[item path]];
	
	if(_shuffledItems) {
		if([_shuffledItems count] == 0)
			[_shuffledItems addObject:item];
		else
			[_shuffledItems insertObject:item atIndex:random() % [_shuffledItems count]];
	}
}



- (void)_removeItem:(id)item {
	[item retain];
	
	((SPPlaylistItem *) item)->_parentItem = NULL;
	
	[_sortedItems removeObject:item];

	if([item isInFileSystem])
		[_allItems removeObjectForKey:[item path]];
	
	if(_shuffledItems)
		[_shuffledItems removeObject:item];
	
	[item release];
}



- (void)_removeItemAtIndex:(NSUInteger)index {
	id		item;
	
	item = [_sortedItems objectAtIndex:index];
	
	[item retain];
	
	((SPPlaylistItem *) item)->_parentItem = NULL;
	
	[_sortedItems removeObjectAtIndex:index];

	if([item isInFileSystem])
		[_allItems removeObjectForKey:[item path]];
	
	if(_shuffledItems)
		[_shuffledItems removeObject:item];
	
	[item release];
}



- (void)_removeAllItems {
	[_sortedItems removeAllObjects];
	[_allItems removeAllObjects];
	[_shuffledItems removeAllObjects];
}

@end


@implementation SPPlaylistContainer

- (id)initWithName:(NSString *)name {
	self = [super initWithName:name];
	
	_sortedItems = [[NSMutableArray alloc] init];
	_allItems = [[NSMutableDictionary alloc] init];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if(self) {
		_sortedItems = [[coder decodeObjectForKey:@"SPPlaylistContainerSortedItems"] retain];
		_allItems = [[coder decodeObjectForKey:@"SPPlaylistContainerAllItems"] retain];
	}
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	NSMutableArray			*sortedItems;
	NSMutableDictionary		*allItems;
	id						item;
	
	[super encodeWithCoder:coder];
	
	sortedItems		= [NSMutableArray array];
	allItems		= [NSMutableDictionary dictionary];

	if([self _encodeItemsInContainers]) {
		for(item in _sortedItems) {
			if([item _encodeInContainers]) {
				[sortedItems addObject:item];
				
				if([item isInFileSystem])
					[allItems setObject:item forKey:[item path]];
			}
		}
	}

	[coder encodeObject:sortedItems forKey:@"SPPlaylistContainerSortedItems"];
	[coder encodeObject:allItems forKey:@"SPPlaylistContainerAllItems"];
}



- (void)dealloc {
	[_sortedItems release];
	[_allItems release];
	[_shuffledItems release];
	
	[super dealloc];
}



#pragma mark -

- (id)itemForPath:(NSString *)path {
	return [_allItems objectForKey:path];
}



- (id)itemForPlaylistPath:(NSString *)path {
	NSArray			*components;
	NSString		*component;
	id				item, child;
	NSUInteger		i;
	
	components = [path pathComponents];
	
	if([components count] == 0)
		return self;
	
	components = [components subarrayFromIndex:1];
	
	if([components count] == 0)
		return self;

	item = self;
	i = 0;
	
	for(component in components) {
		child = [item _itemWithName:component];
		
		if(!child)
			break;
		
		if(i == [components count] - 1)
			return child;
		
		if(![child isKindOfClass:[SPPlaylistContainer class]])
			break;
		
		item = child;
		i++;
	}
	
	return NULL;
}



- (void)setItems:(NSArray *)items {
	id		item;
	
	[_allItems removeAllObjects];
	
	for(item in items) {
		((SPPlaylistItem *) item)->_parentItem = self;

		if([item isInFileSystem])
			[_allItems setObject:item forKey:[item path]];
	}
	
	[_sortedItems setArray:items];
	
	if(_shuffledItems)
		[_shuffledItems setArray:[items shuffledArray]];
}



- (void)addItem:(id)item {
	[self _addItem:item];
}



- (NSUInteger)numberOfItems {
	return [_sortedItems count];
}



- (NSArray *)items {
	return _sortedItems;
}



- (NSArray *)shuffledItems {
	if(!_shuffledItems)
		_shuffledItems = [[_sortedItems shuffledArray] retain];
	
	return _shuffledItems;
}



- (void)startShufflingFromItem:(id)item {
	NSUInteger		index;
	
	[self shuffledItems];
	
	index = [_shuffledItems indexOfObject:item];
	
	[_shuffledItems moveObjectAtIndex:index toIndex:0];
}



- (void)sortUsingSelector:(SEL)selector {
	[_sortedItems sortUsingSelector:selector];
	
	[self sortItemsUsingSelector:selector];
}



- (void)sortItemsUsingSelector:(SEL)selector {
	id		item;
	
	for(item in _sortedItems) {
		if([item respondsToSelector:@selector(sortUsingSelector:)])
			[item sortUsingSelector:selector];
	}
}

- (void)setLoading:(BOOL)loading {
	_loading = loading;
}



- (BOOL)isLoading {
	return _loading;
}

@end



@implementation SPPlaylistGroup

+ (id)groupWithName:(NSString *)name {
	return [[[self alloc] initWithName:name] autorelease];
}



#pragma mark -

- (NSImage *)icon {
	return [NSImage imageNamed:@"PlaylistGroup"];
}



#pragma mark -

- (void)insertItem:(id)item atIndex:(NSUInteger)index {
	[self _insertItem:item atIndex:index];
}



- (void)removeItem:(id)item {
	[self _removeItem:item];
}



- (void)removeItemAtIndex:(NSUInteger)index {
	[self _removeItemAtIndex:index];
}

@end



@implementation SPPlaylistFolder

+ (id)folderWithPath:(NSString *)path {
	return [[[self alloc] initWithPath:path] autorelease];
}



- (id)initWithPath:(NSString *)path {
	self = [super initWithName:[[NSFileManager defaultManager] displayNameAtPath:path]];
	
	[self setPath:path];
	
	_alias = [[self class] _aliasForPath:[self path]];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if(self) {
		[self setPath:[coder decodeObjectForKey:@"SPPlaylistFolderPath"]];
		
		_alias = [[self class] _aliasForData:[coder decodeObjectForKey:@"SPPlaylistFolderAlias"]];
	}
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self path] forKey:@"SPPlaylistFolderPath"];
	[coder encodeObject:[[self class] _dataForAlias:_alias] forKey:@"SPPlaylistFolderAlias"];
}



- (void)dealloc {
	[_path release];
	
	if(_alias)
		DisposeHandle((Handle) _alias);
	
	[super dealloc];
}



#pragma mark -

- (NSString *)cleanName {
	if(!_cleanName) {
		if([self path])
			_cleanName = [[[self class] _cleanNameFromPath:[self path]] retain];
		else
			_cleanName = [[[self class] _cleanNameFromName:[self name]] retain];
	}
	
	return _cleanName;
}



- (void)setPath:(NSString *)path {
	[path retain];
	[_path release];
	
	_path = path;
}



- (NSString *)path {
	return _path;
}



- (NSString *)resolvedPath {
	NSString		*path;
	
	if([[NSFileManager defaultManager] directoryExistsAtPath:[self path]])
		return [self path];
	
	path = [[self class] _pathForAlias:_alias];
	
	if(path)
		return path;
	
	return [self path];
}



#pragma mark -

- (NSImage *)icon {
	return [NSImage imageNamed:@"PlaylistFolder"];
}

@end



@implementation SPPlaylistRepresentedFolder

@end



@implementation SPPlaylistSmartGroup(Private)

- (BOOL)_encodeItemsInContainers {
	return NO;
}

@end



@implementation SPPlaylistSmartGroup

+ (NSPredicate *)metadataQueryPredicateForPredicate:(id)predicate {
	NSMutableArray				*compatibleSubpredicates;
	NSPredicate					*subpredicate, *compatibleSubpredicate;
	NSString					*keyPath;
	NSCompoundPredicateType		type;
	id							constantValue;
	
	if([predicate isEqual:[NSPredicate predicateWithValue:YES]] || [predicate isEqual:[NSPredicate predicateWithValue:NO]])
		return NULL;
	
	if([predicate isKindOfClass:[NSCompoundPredicate class]]) {
		compatibleSubpredicates = [NSMutableArray array];
		
		for(subpredicate in [predicate subpredicates]) {
			compatibleSubpredicate = [self metadataQueryPredicateForPredicate:subpredicate];
			
			if(compatibleSubpredicate)
				[compatibleSubpredicates addObject:compatibleSubpredicate];
		}
		
		if([compatibleSubpredicates count] == 0)
			return NULL;
		
		type = [(NSCompoundPredicate *) predicate compoundPredicateType];
		
		if([compatibleSubpredicates count] == 1 && type != NSNotPredicateType)
			return [compatibleSubpredicates objectAtIndex:0];
		else
			return [[[NSCompoundPredicate alloc] initWithType:type subpredicates:compatibleSubpredicates] autorelease];
	}
	else if([predicate isKindOfClass:[NSComparisonPredicate class]]) {
		if([[predicate leftExpression] expressionType] == NSKeyPathExpressionType ||
		   [[predicate leftExpression] expressionType] == NSConstantValueExpressionType) {
			keyPath = [[predicate leftExpression] keyPath];
			
			if([keyPath isEqualToString:@"kMDItemLastUsedDate"] ||
			   [keyPath isEqualToString:@"kMDItemContentModificationDate"] ||
			   [keyPath isEqualToString:@"kMDItemContentCreationDate"]) {
				constantValue = [[predicate rightExpression] constantValue];
				
				if([constantValue isEqual:@"today"])
					constantValue = [NSDate dateAtStartOfCurrentDay];
				else if([constantValue isEqual:@"yesterday"])
					constantValue = [[NSDate dateAtStartOfCurrentDay] dateByAddingDays:-1];
				else if([constantValue isEqual:@"this week"])
					constantValue = [NSDate dateAtStartOfCurrentWeek];
				else if([constantValue isEqual:@"this month"])
					constantValue = [NSDate dateAtStartOfCurrentMonth];
				else if([constantValue isEqual:@"this year"])
					constantValue = [NSDate dateAtStartOfCurrentYear];
				
				if(![constantValue isEqual:[[predicate rightExpression] constantValue]]) {
					return [NSComparisonPredicate predicateWithLeftExpression:[predicate leftExpression]
															  rightExpression:[NSExpression expressionForConstantValue:constantValue]
																	 modifier:[predicate comparisonPredicateModifier]
																		 type:[predicate predicateOperatorType]
																	  options:[predicate options]];
				}
			}
		}
	}
	
	return predicate;
}



#pragma mark -

+ (id)smartGroupWithName:(NSString *)name {
	return [[[self alloc] initWithName:name] autorelease];
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if(self)
		[self setPredicate:[coder decodeObjectForKey:@"SPPlaylistSmartGroupPredicate"]];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self predicate] forKey:@"SPPlaylistSmartGroupPredicate"];
}



- (void)dealloc {
	[_predicate release];
	[_query release];
	
	[super dealloc];
}



#pragma mark -

- (NSImage *)icon {
	return [NSImage imageNamed:@"PlaylistSmartGroup"];
}



- (void)setPredicate:(NSPredicate *)predicate {
	[predicate retain];
	[_predicate release];
	
	_predicate = predicate;
}



- (NSPredicate *)predicate {
	return _predicate;
}



- (void)setQuery:(NSMetadataQuery *)query {
	[query retain];
	[_query release];
	
	_query = query;
}



- (NSMetadataQuery *)query {
	return _query;
}



- (void)setQueryIndex:(NSUInteger)queryIndex {
	_queryIndex = queryIndex;
}



- (NSUInteger)queryIndex {
	return _queryIndex;
}



#pragma mark -

- (void)removeAllFiles {
	[_sortedItems removeAllObjects];
	
	[_shuffledItems release];
	_shuffledItems = NULL;
	
	_queryIndex = 0;
}

@end



@implementation SPPlaylistExportGroup

+ (id)exportGroupWithName:(NSString *)name {
	return [[[self alloc] initWithName:name] autorelease];
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	if(self) {
		[self setFormat:[coder decodeObjectForKey:@"SPPlaylistExportGroupFormat2"]];
		[self setDestination:[coder decodeIntegerForKey:@"SPPlaylistExportGroupDestination"]];
		[self setDestinationPath:[coder decodeObjectForKey:@"SPPlaylistExportGroupDestinationPath"]];
	}
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self format] forKey:@"SPPlaylistExportGroupFormat2"];
	[coder encodeInteger:[self destination] forKey:@"SPPlaylistExportGroupDestination"];
	[coder encodeObject:[self destinationPath] forKey:@"SPPlaylistExportGroupDestinationPath"];
}



- (void)dealloc {
	[_destinationPath release];
	
	[super dealloc];
}



#pragma mark -

- (NSImage *)icon {
	return [NSImage imageNamed:@"PlaylistExportGroup"];
}



- (void)setFormat:(NSString *)format {
	[format retain];
	[_format release];
	
	_format = format;
}



- (NSString *)format {
	return _format;
}



- (void)setDestination:(SPPlaylistExportDestination)destination {
	_destination = destination;
}



- (SPPlaylistExportDestination)destination {
	return _destination;
}



- (void)setDestinationPath:(NSString *)destinationPath {
	[destinationPath retain];
	[_destinationPath release];
	
	_destinationPath = destinationPath;
}



- (NSString *)destinationPath {
	return _destinationPath;
}

@end



@implementation SPPlaylistExportItem(Private)

- (BOOL)_encodeInContainers {
	return NO;
}

@end



@implementation SPPlaylistExportItem

+ (id)exportItemWithPath:(NSString *)path {
	return [[[self alloc] initWithPath:path] autorelease];
}



- (id)initWithPath:(NSString *)path {
	self = [super initWithName:[[NSFileManager defaultManager] displayNameAtPath:path]];
	
	[self setPath:path];

	return self;
}



- (void)dealloc {
	[_path release];
	[_destinationPath release];
	[_icon release];
	[_job release];
	[_metadata release];
	
	[_cleanName release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)cleanName {
	if(!_cleanName) {
		if([self path])
			_cleanName = [[SPPlaylistFile _cleanNameFromPath:[self path]] retain];
		else
			_cleanName = [[SPPlaylistFile _cleanNameFromName:[self name]] retain];
	}
	
	return _cleanName;
}



- (void)setPath:(NSString *)path {
	[path retain];
	[_path release];
	
	_path = path;
	
	[_icon release];
	_icon = [[[NSWorkspace sharedWorkspace] iconForFile:_path] retain];
}



- (NSString *)path {
	return _path;
}



- (void)setDestinationPath:(NSString *)destinationPath {
	[destinationPath retain];
	[_destinationPath release];
	
	_destinationPath = destinationPath;
}



- (NSString *)destinationPath {
	return _destinationPath;
}



- (void)setMetadata:(NSDictionary *)metadata {
	[metadata retain];
	[_metadata release];
	
	_metadata = metadata;
}



- (NSDictionary *)metadata {
	return _metadata;
}



- (void)setJob:(SPExportJob *)job {
	[job retain];
	[_job release];
	
	_job = job;
}



- (SPExportJob *)job {
	return _job;
}



- (NSImage *)icon {
	return _icon;
}

@end
