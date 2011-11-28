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
#import "SPApplicationController.h"
#import "SPDrillController.h"
#import "SPExportController.h"
#import "SPFullscreenWindow.h"
#import "SPIMDbMetadataMatch.h"
#import "SPMovieController.h"
#import "SPPlayerController.h"
#import "SPPlaylistCell.h"
#import "SPPlaylistController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistLoader.h"
#import "SPPreferencesController.h"
#import "SPSettings.h"

#define SPPlaylistMaximumNumberOfRecentItems							50


NSString * const SPPlaylistControllerSettingsChangedNotification		= @"SPPlaylistControllerSettingsChangedNotification";
NSString * const SPPlaylistControllerSelectionDidChangeNotification		= @"SPPlaylistControllerSelectionDidChangeNotification";
NSString * const SPPlaylistControllerLoadProgressChangedNotification	= @"SPPlaylistControllerLoadProgressChangedNotification";


static NSString * const SPPlaylistItemPboardType						= @"SPPlaylistItemPboardType";

static NSLock															*SPPlaylistControllerLock;


@interface SPPlaylistController(Private)

+ (SPPlaylistGroup *)_defaultPlaylist;

+ (NSArray *)_uniqueFilesystemIdentifiersForPath:(NSString *)path;

- (id)_selectedItem;
- (NSArray *)_selectedItems;
- (void)_savePlaylist;
- (void)_saveRepresentedFiles;
- (void)_reloadItem:(id)item;
- (void)_restoreExpansionStateForItems:(NSArray *)array;

- (NSArray *)_filteredItemsForItems:(NSArray *)items;
- (NSArray *)_filteredAndShuffledItemsForItem:(id)item;
- (NSArray *)_filteredAndShuffledItemsFromCDFolderForFile:(SPPlaylistFile *)file;

- (id)_fileForPath:(NSString *)path ofClass:(Class)class;

- (void)_setRepeatMode:(SPPlaylistRepeatMode)repeatMode;
- (void)_setShuffle:(BOOL)shuffle;

- (void)_setExportGroupDirectory:(NSString *)path;
- (void)_startNextExportJob;

- (void)_validate;

@end


@implementation SPPlaylistController(Private)

+ (SPPlaylistGroup *)_defaultPlaylist {
	SPPlaylistGroup			*playlist, *group;
	SPPlaylistExportGroup	*exportGroup;
	
	playlist = [[SPPlaylistGroup alloc] initWithName:@"<SPPlaylist>"];
	
	group = [SPPlaylistGroup groupWithName:NSLS(@"Spiral Movies", @"Default playlist group")];
	[group setExpanded:YES];
	
	[playlist addItem:group];
	
	exportGroup = [SPPlaylistExportGroup exportGroupWithName:NSLS(@"Export for iPhone", @"Playlist export group name")];
	[exportGroup setFormat:@"iPhone"];
	
	[playlist addItem:exportGroup];
	
	return [playlist autorelease];
}



#pragma mark -

+ (NSArray *)_uniqueFilesystemIdentifiersForPath:(NSString *)path {
	NSString		*mountPath;
	struct statfs	sfb;
	struct stat		sb;
	
	if(stat([path fileSystemRepresentation], &sb) < 0)
		return NULL;
	
	if(statfs([path fileSystemRepresentation], &sfb) < 0)
		return NULL;
	
	mountPath = [[NSFileManager defaultManager]
		stringWithFileSystemRepresentation:sfb.f_mntonname
									length:strlen(sfb.f_mntonname)];
	
	return [NSArray arrayWithObjects:
		[NSSWF:@"%llu %llu", (int64_t) sb.st_dev, (int64_t) sb.st_ino],
		[NSSWF:@"%@ %llu", [mountPath lastPathComponent], (int64_t) sb.st_ino],
		NULL];
}



#pragma mark -

- (void)_saveLater {
	[self performSelectorOnce:@selector(save) afterDelay:1.0];
}



#pragma mark -

- (id)_selectedItem {
	NSInteger		row;
	
	row = [_outlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_outlineView itemAtRow:row];
}



- (NSArray *)_selectedItems {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;
	
	array = [NSMutableArray array];
	indexes = [_outlineView selectedRowIndexes];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		[array addObject:[_outlineView itemAtRow:index]];
		
		index = [indexes indexGreaterThanIndex:index];
	}
	
	return array;
}



- (void)_savePlaylist {
	[[SPSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:_playlist] forKey:SPPlaylist];
}



- (void)_saveRepresentedFiles {
	NSArray						*identifiers;
	NSString					*identifier;
	SPPlaylistRepresentedFile	*file;
	
	[_representedFilesLock lock];
	
	identifiers = [_representedFiles allKeys];
	
	if([_representedFiles count] % 10 == 0) {
		for(identifier in identifiers) {
			file = [_representedFiles objectForKey:identifier];
			
			if(![[NSFileManager defaultManager] fileExistsAtPath:[file resolvedPath]])
				[_representedFiles removeObjectForKey:identifier];
		}
	}
	
	[[SPSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:_representedFiles] forKey:SPRepresentedFiles];
	
	[_representedFilesLock unlock];
}



- (void)_reloadItem:(id)item {
	NSString		*name, *path, *destinationPath;
	SPExportJob		*job;
	id				exportItem;
	NSUInteger		counter;
	
	if([item isKindOfClass:[SPPlaylistFolder class]]) {
		if(![item isLoading]) {
			_spinners++;
			[_progressIndicator startAnimation:self];
			[_loader loadContentsOfFolder:item synchronously:NO];
		}
	}
	else if([item isKindOfClass:[SPPlaylistSmartGroup class]]) {
		if(![item isLoading]) {
			_spinners++;
			[_progressIndicator startAnimation:self];
			[_loader loadSmartGroup:item synchronously:YES];
		}
	}
	else if([item isKindOfClass:[SPPlaylistExportGroup class]]) {
		for(exportItem in [item items]) {
			if([exportItem isKindOfClass:[SPPlaylistExportItem class]]) {
				if(![exportItem job]) {
					name = [[[exportItem path] lastPathComponent] stringByDeletingPathExtension];

					if([(SPPlaylistExportGroup *) item destination] == SPPlaylistExportToiTunes) {
						destinationPath = [NSFileManager temporaryPathWithPrefix:name];
						
						[[NSFileManager defaultManager] createDirectoryAtPath:destinationPath];
						
						path = [destinationPath stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"mp4"]];
					} else {
						if([item destination] == SPPlaylistExportToOriginalPath)
							destinationPath = [[exportItem path] stringByDeletingLastPathComponent];
						else
							destinationPath = [item destinationPath];
						
						path = [destinationPath stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"mp4"]];
						counter = 2;
						
						while([[NSFileManager defaultManager] fileExistsAtPath:path]) {
							path = [destinationPath stringByAppendingPathComponent:
								[[NSSWF:@"%@ %u", name, counter++] stringByAppendingPathExtension:@"mp4"]];
						}
					}
					
					job = [SPExportJob exportJobWithPath:[exportItem path]
													file:path
												  format:[[SPExportController exportController] exportFormatWithName:[(SPPlaylistExportGroup *) item format]]];
					[job setDelegate:self];
					[job setPlaylistItem:exportItem];
					[job setMetadata:[exportItem metadata]];
					
					[exportItem setDestinationPath:path];
					[exportItem setJob:job];
				
					if([_exports count] >= [[NSProcessInfo processInfo] processorCount]) {
						[_exportQueue addObject:job];
					} else {
						[_exports addObject:job];
						[job start];
					}
				}
			}
		}
		
		if(![item isLoading]) {
			_spinners++;
			
			[_progressIndicator startAnimation:self];

			[_loader loadMovieDataOfItemsInContainer:item synchronously:NO];
		}
	}
	else if([item isKindOfClass:[SPPlaylistGroup class]]) {
		if(![item isLoading]) {
			_spinners += 2;

			[_progressIndicator startAnimation:self];
			
			[_loader loadMovieDataOfItemsInContainer:item synchronously:NO];
			[_loader loadMetadataOfItemsInContainer:item synchronously:NO];
		}
	}
}



- (void)_restoreExpansionStateForItems:(NSArray *)items {
	id		item;
	
	_restoring++;
	
	for(item in items) {
		if([item isExpanded]) {
			[_outlineView expandItem:item];
			
			if([item isKindOfClass:[SPPlaylistContainer class]])
				[self _restoreExpansionStateForItems:[item items]];
		}
	}
	
	_restoring--;
}



#pragma mark -

- (NSArray *)_filteredItemsForItems:(NSArray *)array {
	NSMutableArray		*items;
	NSString			*string;
	id					item;
	
	string = [_searchField stringValue];
	
	if([string length] == 0)
		return array;
	
	items = [NSMutableArray array];
	
	for(item in array) {
		if([item isKindOfClass:[SPPlaylistFile class]] || [item isKindOfClass:[SPPlaylistExportItem class]]) {
			if(![[item name] containsSubstring:string options:NSCaseInsensitiveSearch])
				continue;
		}
		
		[items addObject:item];
	}
	
	return items;
}



- (NSArray *)_filteredAndShuffledItemsForItem:(id)item {
	return [self _filteredItemsForItems:_shuffle ? [item shuffledItems] : [item items]];
}



- (NSArray *)_filteredAndShuffledItemsFromCDFolderForFile:(SPPlaylistFile *)file {
	NSMutableArray		*files;
	NSArray				*items;
	id					item;
	NSUInteger			number;

	files = [NSMutableArray array];

	if([[file parentItem] isKindOfClass:[SPPlaylistRepresentedFolder class]]) {
		number = [[[[file parentItem] name] stringByMatching:@"^cd ?(\\d)$" options:RKLCaseless capture:1] unsignedIntegerValue];
		
		if(number != 0) {
			items = [self _filteredAndShuffledItemsForItem:[[file parentItem] parentItem]];

			for(item in items)
				[files addObjectsFromArray:[self _filteredAndShuffledItemsForItem:item]];
		}
	}
	
	return files;
}



#pragma mark -

- (id)_fileForPath:(NSString *)path ofClass:(Class)class {
	NSArray						*identifiers;
	NSString					*identifier;
	SPPlaylistRepresentedFile	*file, *representedFile;
	
	identifiers = [[self class] _uniqueFilesystemIdentifiersForPath:path];
	
	if(!identifiers)
		return NULL;
	
	[_representedFilesLock lock];
	
	for(identifier in identifiers) {
		representedFile = [[[_representedFiles objectForKey:identifier] retain] autorelease];
		
		if(representedFile)
			break;
	}
	
	[_representedFilesLock unlock];
	
	if(representedFile) {
		file = [class fileWithPath:path];
		
		[file copyAttributesFromFile:representedFile];
		
		return file;
	}
	
	return NULL;
}



#pragma mark -

- (void)_setRepeatMode:(SPPlaylistRepeatMode)repeatMode {
	NSString		*image = @"";
	
	_repeatMode = repeatMode;
	
	switch(_repeatMode) {
		case SPPlaylistRepeatOff:	image = @"RepeatOff";	break;
		case SPPlaylistRepeatAll:	image = @"RepeatAll";	break;
		case SPPlaylistRepeatOne:	image = @"RepeatOne";	break;
	}
	
	[_repeatButton setImage:[NSImage imageNamed:image]];
}



- (void)_setShuffle:(BOOL)shuffle {
	_shuffle = shuffle;
	
	if(_shuffle)
		[_shuffleButton setImage:[NSImage imageNamed:@"ShuffleOn"]];
	else
		[_shuffleButton setImage:[NSImage imageNamed:@"ShuffleOff"]];
}



#pragma mark -

- (void)_setExportGroupDirectory:(NSString *)path {
	NSImage		*image;
	
	image = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[image setSize:NSMakeSize(16.0, 16.0)];
	
	[_exportGroupDirectoryMenuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[_exportGroupDirectoryMenuItem setImage:image];
	[_exportGroupDirectoryMenuItem setRepresentedObject:path];
}



- (void)_startNextExportJob {
	SPExportJob		*job;
	
	if([_exportQueue count] > 0) {
		job = [[[_exportQueue objectAtIndex:0] retain] autorelease];
		[_exportQueue removeObjectAtIndex:0];
		[_exports addObject:job];
		[job start];
		
		[_outlineView reloadData];
	}
}



- (BOOL)_launchiTunesAndImportFile:(NSString *)path error:(NSError **)error {
	NSDictionary		*application;
	FSRef				fsRef;
	AliasHandle			alias;
	AppleEvent			request, reply;
	AEBuildError		buildError;
	OSType				iTunesSignature = 'hook';
	OSStatus			status;
	BOOL				running = NO;
	const char			*event =
		"'insh':'obj '{form: indx, want: type(cLiP), seld: long(1), from:'null'()}, '----':alis (@@)";
	
	for(application in [[NSWorkspace sharedWorkspace] launchedApplications]) {
		if([[application objectForKey:@"NSApplicationName"] isEqualToString:@"iTunes"]) {
			running = YES;
			
			break;
		}
	}
	
	[[NSWorkspace sharedWorkspace] launchApplication:@"iTunes"];

	if(!running)
		[NSThread sleepForTimeInterval:10.0];
	
	status = FSPathMakeRef((UInt8 *) [path fileSystemRepresentation], &fsRef, NULL);
	
	if(status != noErr) {
		if(error)
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status];
		
		return NO;
	}
	
	status = FSNewAlias(NULL, &fsRef, &alias);
	
	if(status != noErr) {
		if(error)
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status];
		
		return NO;
	}

	status = AEBuildAppleEvent('hook',
							   'Add ',
							   typeApplSignature,
							   &iTunesSignature,
							   sizeof(iTunesSignature),
							   kAutoGenerateReturnID,
							   kAnyTransactionID,
							   &request,
							   &buildError,
							   event,
							   alias);
	
	if(status == noErr) {
		status = AESendMessage(&request, &reply, kAEWaitReply, kAEDefaultTimeout);
		
		if(status == noErr)
			AEDisposeDesc(&reply);
		else if(error)
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status];
	} else {
		if(error)
			*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status];
	}
	
	AEDisposeDesc(&request);
	DisposeHandle((Handle) alias);
	
	return (status == noErr);
}



#pragma mark -

- (void)_validate {
	[_removeButton setEnabled:([self _selectedItem] != NULL)];
}

@end



@implementation SPPlaylistController

+ (void)initialize {
	if(self == [SPPlaylistController class])
		SPPlaylistControllerLock = [[NSLock alloc] init];
}



#pragma mark -

+ (SPPlaylistController *)playlistController {
	static SPPlaylistController		*playlistController;
	
	[SPPlaylistControllerLock lock];
	
	if(!playlistController)
		playlistController = [[self alloc] init];
	
	[SPPlaylistControllerLock unlock];
	
	return playlistController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Playlist"];
	
	_eventQueueItems = [[NSMutableDictionary alloc] init];
	
	_loader = [[SPPlaylistLoader alloc] init];
	[_loader setDelegate:self];
	
	_exports		= [[NSMutableArray alloc] init];
	_exportQueue	= [[NSMutableArray alloc] init];
	
	_simplifyFilenames = [[SPSettings settings] boolForKey:SPSimplifyFilenames];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[[[WIEventQueue sharedQueue] notificationCenter]
		addObserver:self
		   selector:@selector(eventFileWrite:)
			   name:WIEventFileWriteNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:SPPreferencesDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerViewCountChanged:)
			   name:SPMovieControllerViewCountChangedNotification];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_playlist release];
	[_representedFiles release];

	[_eventQueueItems release];
	
	[_exports release];
	[_exportQueue release];
	
	[_loader release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSImage				*icon;
	NSData				*data;
	NSDictionary		*format;
	SPPlaylistCell		*cell;
	
	[self setWindowFrameAutosaveName:@"Playlist"];
	
	data = [[SPSettings settings] objectForKey:SPPlaylist];
	
	if(data)
		_playlist = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	
	if(!_playlist)
		_playlist = [[[self class] _defaultPlaylist] retain];
	
	data = [[SPSettings settings] objectForKey:SPRepresentedFiles];
	
	if(data)
		_representedFiles = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	
	if(!_representedFiles)
		_representedFiles = [[NSMutableDictionary alloc] init];
	
	cell = [[SPPlaylistCell	alloc] init];
	[cell setEditable:YES];
	[_filesTableColumn setDataCell:cell];
	[cell release];
	
	[_outlineView setAllowsUserCustomization:YES];
	[_outlineView setAutosaveName:@"Playlist"];
	[_outlineView setAutosaveTableColumns:YES];
	[_outlineView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"IMDb", @"ViewCount", @"Size", @"Dimensions", @"Time", NULL]];
	[_outlineView registerForDraggedTypes:
		[NSArray arrayWithObjects:SPPlaylistItemPboardType, NSFilenamesPboardType, NULL]];
	[_outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	[_outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[_outlineView setTarget:self];
	[_outlineView setDoubleAction:@selector(open:)];
	[_outlineView setDeleteAction:@selector(remove:)];
	[_outlineView setAutoresizesOutlineColumn:NO];
	
	[_outlineView reloadData];

	[self _restoreExpansionStateForItems:[_playlist items]];
	
	for(format in [[SPExportController exportController] exportFormats]) {
		[_exportGroupFormatPopUpButton addItem:[NSMenuItem itemWithTitle:[format objectForKey:@"Name"]
																   image:[NSImage imageNamed:[format objectForKey:@"Image"]]]];
	}

	icon = [[NSWorkspace sharedWorkspace] iconForFile:[[NSWorkspace sharedWorkspace] fullPathForApplication:@"iTunes"]];
	[icon setSize:NSMakeSize(16.0, 16.0)];
	[_exportGroupiTunesMenuItem setImage:icon];
	
	[self _setRepeatMode:[[SPSettings settings] intForKey:SPPlaylistRepeat]];
	[self _setShuffle:[[SPSettings settings] boolForKey:SPPlaylistShuffle]];
	[self _validate];
}



- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)defaultFrame {
	NSScrollView	*scrollView;
	NSRect			frame, previousFrame;
	CGFloat			contentHeight, height, extraHeight;
	
	previousFrame = frame = [window frame];
	scrollView = [_outlineView enclosingScrollView];
	contentHeight = [[scrollView contentView] bounds].size.height;
	height = [[scrollView documentView] bounds].size.height - contentHeight;

	if(height >= 0.0 && height <= 1.0)
		height = (([_outlineView rowHeight] + [_outlineView intercellSpacing].height) * [_outlineView numberOfRows]) - contentHeight;

	frame.size.height += height;

	if((extraHeight = [window minSize].height - frame.size.height) > 1.0 ||
	   (extraHeight = [window maxSize].height - frame.size.height) < 1.0)
		frame.size.height += extraHeight;

	frame.origin.y -= frame.size.height - previousFrame.size.height;

	return frame;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[self save];
}



- (void)eventFileWrite:(NSNotification *)notification {
	[self _reloadItem:[_eventQueueItems objectForKey:[notification object]]];
	
	[_outlineView reloadData];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader isProcessingWithStatus:(NSString *)status {
	[_statusTextField setStringValue:status];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadFile:(SPPlaylistRepresentedFile *)file {
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadContentsOfFolder:(SPPlaylistFolder *)folder {
	[_outlineView reloadData];
	
	_spinners--;
	_spinners += 2;
	
	[_loader loadMovieDataOfItemsInContainer:folder synchronously:NO];
	[_loader loadMetadataOfItemsInContainer:folder synchronously:NO];
	
	[self _saveLater];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMovieDataOfFile:(SPPlaylistFile *)file {
	[_outlineView setNeedsDisplay:YES];
	
	[self _saveLater];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMovieDataOfItemsInContainer:(SPPlaylistContainer *)container {
	if(--_spinners == 0) {
		[_progressIndicator stopAnimation:self];
		
		[_statusTextField setStringValue:@""];
	}
	
	[self _saveLater];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaylistControllerLoadProgressChangedNotification object:self];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMetadataOfFile:(SPPlaylistFile *)file {
	[_outlineView setNeedsDisplay:YES];

	[self _saveLater];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMetadataOfItemsInContainer:(SPPlaylistContainer *)container {
	if(--_spinners == 0) {
		[_progressIndicator stopAnimation:self];
		
		[_statusTextField setStringValue:@""];
	}
	
	[self _saveLater];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaylistControllerLoadProgressChangedNotification object:self];
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadItemsForSmartGroup:(SPPlaylistSmartGroup *)smartGroup {
}



- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadSmartGroup:(SPPlaylistSmartGroup *)smartGroup {
	[_outlineView reloadData];

	_spinners += 2;
	
	[_loader loadMovieDataOfItemsInContainer:smartGroup synchronously:NO];
	[_loader loadMetadataOfItemsInContainer:smartGroup synchronously:NO];
	
	[self _saveLater];
}



- (void)exportJobProgressed:(SPExportJob *)job {
	[_outlineView display];
}



- (void)exportJobCompleted:(SPExportJob *)job {
	NSString					*path;
	NSError						*error;
	SPPlaylistExportGroup		*group;
	SPPlaylistExportItem		*item;
	SPPlaylistFile				*newItem;
	NSUInteger					index;
	
	item	= [[[job playlistItem] retain] autorelease];
	group	= [item parentItem];
	path	= [item destinationPath];
	index	= [[group items] indexOfObject:item];
	
	[group removeItem:item];
	
	if([group destination] == SPPlaylistExportToiTunes) {
		if(![self _launchiTunesAndImportFile:path error:&error])
			[[error alert] beginSheetModalForWindow:[self window] modalDelegate:NULL didEndSelector:NULL contextInfo:NULL];
		
		[[NSFileManager defaultManager] removeItemAtPath:[path stringByDeletingLastPathComponent] error:NULL];
	} else {
		newItem = [SPPlaylistFile fileWithPath:path];
		
		if(index >= 0 && (NSUInteger) index < [group numberOfItems])
			[group insertItem:newItem atIndex:index];
		else
			[group addItem:newItem];
	}

	[_outlineView reloadData];
	
	[self _reloadItem:group];
	
	[_exports removeObject:job];
	
	[self _startNextExportJob];
}



- (void)exportJobStopped:(SPExportJob *)job {
	[_exports removeObject:job];
	
	[self _startNextExportJob];
}



- (void)exportJob:(SPExportJob *)job failedWithError:(NSError *)error {
	SPPlaylistExportGroup		*group;
	SPPlaylistExportItem		*item;

	[[error alert] runNonModal];
	
	item	= [job playlistItem];
	group	= [item parentItem];
	
	[group removeItem:item];
	
	[_outlineView reloadData];

	[_exports removeObject:job];

	[self _startNextExportJob];
}



- (void)menuNeedsUpdate:(NSMenu *)menu {
	NSMenuItem				*item;
	SPIMDbMetadataMatch		*match;
	SPPlaylistFile			*file;
	BOOL					nullMatch = NO;
	
	while([menu numberOfItems] > 1)
		[menu removeItemAtIndex:1];
	
	file = [self _selectedItem];
	
	if([file isKindOfClass:[SPPlaylistFile class]]) {
		for(match in [file IMDbMatches]) {
			if([match title] && [match URL]) {
				item = [NSMenuItem itemWithTitle:[match title]];
				[item setRepresentedObject:match];
				
				if([match isEqual:[file IMDbMatch]])
					[item setState:NSOnState];
				
				[menu addItem:item];
			}
		}
		
			nullMatch = [[file IMDbMatch] isNullMatch];
	}
	
	if([menu numberOfItems] > 1)
		[menu addItem:[NSMenuItem separatorItem]];
	
	item = [NSMenuItem itemWithTitle:NSLS(@"None", @"IMDb popup menu action") action:@selector(selectNoIMDbMatch:)];
	
	if(nullMatch)
		[item setState:NSOnState];
	
	[menu addItem:item];
	[menu addItem:[NSMenuItem itemWithTitle:NSLS(@"Other...", @"IMDb popup menu action") action:@selector(selectIMDbURL:)]];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	_simplifyFilenames = [[SPSettings settings] boolForKey:SPSimplifyFilenames];
	
	[_playlist sortItemsUsingSelector:_simplifyFilenames
		? @selector(compareCleanName:)
		: @selector(compareName:)];

	[_outlineView reloadData];
}



- (void)movieControllerViewCountChanged:(NSNotification *)notification {
	[_outlineView setNeedsDisplay:YES];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	id		item;
	SEL		selector;
	
	item = [self _selectedItem];
	selector = [menuItem action];
	
	if(selector == @selector(revealInFinder:))
		return (item != NULL && [item isInFileSystem]);
	else if(selector == @selector(remove:))
		return (item != NULL);
	
	return YES;
}



#pragma mark -

- (void)submitSheet:(id)sender {
	BOOL	valid = YES;
	
	if([sender window] == _IMDbURLPanel) {
		valid = [[_IMDbURLTextField stringValue] isMatchedByRegex:@"title/tt\\d+"];
		
		if(!valid)
			[_IMDbURLInvalidTextField setHidden:NO];
	}
	
	if(valid)
		[super submitSheet:sender];
}



#pragma mark -

- (void)save {
	NSUInteger		i, count;
	id				item;
	
	count = [_outlineView numberOfRows];
	
	for(i = 0; i < count; i++) {
		item = [_outlineView itemAtRow:i];
		
		[item setExpanded:[_outlineView isItemExpanded:item]];
	}
	
	[self _savePlaylist];
	[self _saveRepresentedFiles];
	
	[[SPSettings settings] setBool:[self shuffle] forKey:SPPlaylistShuffle];
	[[SPSettings settings] setInt:[self repeatMode] forKey:SPPlaylistRepeat];
}



#pragma mark -

- (SPPlaylistGroup *)playlist {
	return _playlist;
}



#pragma mark -

- (SPPlaylistFile *)fileForPath:(NSString *)path {
	return [self _fileForPath:path ofClass:[SPPlaylistFile class]];
}



- (SPPlaylistRepresentedFile *)representedFileForPath:(NSString *)path {
	return [self _fileForPath:path ofClass:[SPPlaylistRepresentedFile class]];
}



- (void)addRepresentedFile:(SPPlaylistRepresentedFile *)file {
	NSArray						*identifiers;
	NSString					*identifier;
	SPPlaylistRepresentedFile	*representedFile;
	
	identifiers = [[self class] _uniqueFilesystemIdentifiersForPath:[file path]];
	
	if(!identifiers)
		return;
	
	representedFile = [SPPlaylistRepresentedFile fileWithPath:[file path]];
	
	[representedFile copyAttributesFromFile:file];

	[_representedFilesLock lock];
	
	for(identifier in identifiers)
		[_representedFiles setObject:representedFile forKey:identifier];

	[_representedFilesLock unlock];
}



#pragma mark -

- (void)setRepeatMode:(SPPlaylistRepeatMode)repeatMode {
	[self _setRepeatMode:repeatMode];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaylistControllerSettingsChangedNotification object:self];
}



- (SPPlaylistRepeatMode)repeatMode {
	return _repeatMode;
}



- (void)setShuffle:(BOOL)shuffle {
	[self _setShuffle:shuffle];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaylistControllerSettingsChangedNotification object:self];
}



- (BOOL)shuffle {
	return _shuffle;
}



#pragma mark -

- (NSUInteger)numberOfExports {
	return [_exports count] + [_exportQueue count];
}



- (void)stopAllExports {
	[_exports makeObjectsPerformSelector:@selector(stop)];
}



#pragma mark -

- (void)openSelection {
	id		item;
	
	item = [self _selectedItem];
	
	if([item isKindOfClass:[SPPlaylistFile class]]) {
		if([[SPApplicationController applicationController] openFile:[item resolvedPath] withPlaylistFile:item])
			[[item parentItem] startShufflingFromItem:item];
	}
	else if([item isKindOfClass:[SPPlaylistFolder class]]) {
		[_outlineView expandItem:item];
	}
}



- (void)closeSelection {
	id		item;
	
	item = [self _selectedItem];
	
	if(item)
		[_outlineView collapseItem:item];
}



- (void)moveSelectionDown {
	NSInteger		row, rows;
	
	rows = [_outlineView numberOfRows];
	
	if(rows == 0)
		return;
	
	row = [_outlineView selectedRow];
	
	if(row + 1 == rows)
		return;

	row++;

	[_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_outlineView scrollRowToVisible:row];
}



- (void)moveSelectionUp {
	NSInteger		row, rows;
	
	rows = [_outlineView numberOfRows];
	
	if(rows == 0)
		return;
	
	row = [_outlineView selectedRow];
	
	if(row == -1)
		row = rows;
	
	if(row == 0)
		return;

	row--;

	[_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_outlineView scrollRowToVisible:row];
}



#pragma mark -

- (IBAction)open:(id)sender {
	id		item;
	
	item = [self _selectedItem];
	
	if([item isKindOfClass:[SPPlaylistFile class]]) {
		if([[SPApplicationController applicationController] openFile:[item resolvedPath] withPlaylistFile:item])
			[[item parentItem] startShufflingFromItem:item];
	}
	else if([item isKindOfClass:[SPPlaylistFolder class]]) {
		[_outlineView expandItem:item];
	}
	else if([item isKindOfClass:[SPPlaylistSmartGroup class]]) {
		[_smartGroupNameTextField setStringValue:[item name]];
		[_predicateEditor setObjectValue:[item predicate]];

		[NSApp beginSheet:_smartGroupPanel
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:@selector(editSmartGroupSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:[item retain]];
	}
	else if([item isKindOfClass:[SPPlaylistExportGroup class]]) {
		[_exportGroupNameTextField setStringValue:[item name]];
		[_exportGroupFormatPopUpButton selectItemWithTitle:[(SPPlaylistExportGroup *) item format]];

		if([_exportGroupFormatPopUpButton indexOfSelectedItem] == -1)
			[_exportGroupFormatPopUpButton selectItemAtIndex:0];
		
		[_exportGroupDestinationPopUpButton selectItemWithTag:[(SPPlaylistExportGroup *) item destination]];
		
		if([_exportGroupDestinationPopUpButton indexOfSelectedItem] == -1)
			[_exportGroupDestinationPopUpButton selectItemAtIndex:0];
		
		if([item destinationPath])
			[self _setExportGroupDirectory:[item destinationPath]];
		else
			[self _setExportGroupDirectory:[@"~/Desktop" stringByExpandingTildeInPath]];
		
		[NSApp beginSheet:_exportGroupPanel
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:@selector(editExportGroupSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:[item retain]];
	}
}



- (void)editSmartGroupSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	SPPlaylistSmartGroup	*smartGroup = contextInfo;
	
	if(returnCode == NSAlertDefaultReturn) {
		[smartGroup setName:[_smartGroupNameTextField stringValue]];
		[smartGroup setPredicate:[_predicateEditor predicate]];
		
		if([_outlineView isItemExpanded:smartGroup])
			[self _reloadItem:smartGroup];

		[self save];
	}
	
	[smartGroup release];
	[_smartGroupPanel close];
}



- (void)editExportGroupSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	SPPlaylistExportGroup	*exportGroup = contextInfo;
	
	if(returnCode == NSAlertDefaultReturn) {
		[exportGroup setName:[_exportGroupNameTextField stringValue]];
		[exportGroup setFormat:[_exportGroupFormatPopUpButton titleOfSelectedItem]];
		[exportGroup setDestination:[_exportGroupDestinationPopUpButton tagOfSelectedItem]];
		[exportGroup setDestinationPath:[_exportGroupDestinationPopUpButton representedObjectOfSelectedItem]];

		[self save];
	}
	
	[exportGroup release];
	[_exportGroupPanel close];
}



- (IBAction)addFile:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setPrompt:NSLS(@"Add", @"Playlist open panel button title")];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(addFilePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)addFilePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSMutableIndexSet	*indexSet;
	NSMutableArray		*items;
	NSString			*path;
	id					item, newItem;
	BOOL				exportGroup;
	
	if(returnCode == NSOKButton) {
		item = [self _selectedItem];
		
		while(item && ![item isKindOfClass:[SPPlaylistGroup class]])
			item = [item parentItem];
		
		if(!item)
			item = _playlist;
		
		exportGroup = [item isKindOfClass:[SPPlaylistExportGroup class]];
		
		items = [NSMutableArray array];
		
		for(path in [openPanel filenames]) {
			if([[NSFileManager defaultManager] directoryExistsAtPath:path])
				newItem = [SPPlaylistFolder folderWithPath:path];
			else if(exportGroup)
				newItem = [SPPlaylistExportItem exportItemWithPath:path];
			else
				newItem = [SPPlaylistFile fileWithPath:path];
			
			[(SPPlaylistGroup *) item addItem:newItem];
			[items addObject:newItem];
		}
		
		[self _reloadItem:item];

		[_outlineView expandItem:item];
		[_outlineView reloadData];

		indexSet = [NSMutableIndexSet indexSet];
		
		for(newItem in items)
			[indexSet addIndex:[_outlineView rowForItem:newItem]];
		
		[_outlineView selectRowIndexes:indexSet byExtendingSelection:NO];

		[self save];
	}
}



- (IBAction)newGroup:(id)sender {
	SPPlaylistGroup			*group;
	id						item;
	NSInteger				row;
	
	group = [SPPlaylistGroup groupWithName:NSLS(@"Untitled", @"Playlist group name")];
	item = [self _selectedItem];
	
	while(item && ![item isKindOfClass:[SPPlaylistGroup class]])
		item = [item parentItem];

	if(!item)
		item = _playlist;

	[(SPPlaylistGroup *) item addItem:group];

	[self save];

	[_outlineView expandItem:item];
	[_outlineView reloadData];
	
	row = [_outlineView rowForItem:group];
	
	if(row >= 0) {
		[_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[_outlineView editColumn:0 row:row withEvent:NULL select:YES];
	}
}



- (IBAction)newSmartGroup:(id)sender {
	[_smartGroupNameTextField setStringValue:NSLS(@"Untitled", @"Playlist smart group name")];
	[_predicateEditor setObjectValue:NULL];
	[_predicateEditor addRow:self];

	[NSApp beginSheet:_smartGroupPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newSmartGroupSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)newSmartGroupSheetDidEnd:(NSWindow *)window returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	SPPlaylistSmartGroup	*smartGroup;
	id						item;
	NSInteger				row;
	
	if(returnCode == NSAlertDefaultReturn) {
		smartGroup = [SPPlaylistSmartGroup smartGroupWithName:[_smartGroupNameTextField stringValue]];
		[smartGroup setPredicate:[_predicateEditor predicate]];
		
		item = [self _selectedItem];
		
		while(item && ![item isKindOfClass:[SPPlaylistGroup class]])
			item = [item parentItem];
		
		if(!item)
			item = _playlist;
		
		[(SPPlaylistGroup *) item addItem:smartGroup];
		
		[_outlineView expandItem:item];
		[_outlineView reloadData];
		
		row = [_outlineView rowForItem:smartGroup];
		
		if(row >= 0)
			[_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[self save];
	}
	
	[_smartGroupPanel close];
}



- (IBAction)newExportGroup:(id)sender {
	[_exportGroupNameTextField setStringValue:NSLS(@"Export for iPhone", @"Playlist export group name")];
	[_exportGroupFormatPopUpButton selectItemWithTitle:@"iPhone"];

	[self _setExportGroupDirectory:[@"~/Desktop" stringByExpandingTildeInPath]];
	
	[_exportGroupDestinationPopUpButton selectItem:_exportGroupSameAsOriginalMenuItem];

	[NSApp beginSheet:_exportGroupPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newExportGroupSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)newExportGroupSheetDidEnd:(NSWindow *)window returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	SPPlaylistExportGroup	*exportGroup;
	id						item;
	NSInteger				row;
	
	if(returnCode == NSAlertDefaultReturn) {
		exportGroup = [SPPlaylistExportGroup exportGroupWithName:[_exportGroupNameTextField stringValue]];
		[exportGroup setFormat:[_exportGroupFormatPopUpButton titleOfSelectedItem]];
		[exportGroup setDestination:[_exportGroupDestinationPopUpButton tagOfSelectedItem]];
		[exportGroup setDestinationPath:[_exportGroupDestinationPopUpButton representedObjectOfSelectedItem]];
		
		item = [self _selectedItem];
		
		while(item && ![item isKindOfClass:[SPPlaylistGroup class]])
			item = [item parentItem];
		
		if(!item)
			item = _playlist;
		
		[(SPPlaylistGroup *) item addItem:exportGroup];
		
		[_outlineView expandItem:item];
		[_outlineView reloadData];
		
		row = [_outlineView rowForItem:exportGroup];
		
		if(row >= 0)
			[_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[self save];
	}
	
	[_exportGroupPanel close];
}



- (IBAction)format:(id)sender {
	NSMutableString			*string;
	NSMenuItem				*item;
	
	string = [[_exportGroupNameTextField stringValue] mutableCopy];
	
	for(item in [_exportGroupFormatPopUpButton itemArray])
		[string replaceOccurrencesOfString:[item title] withString:[_exportGroupFormatPopUpButton titleOfSelectedItem]];
	
	[_exportGroupNameTextField setStringValue:string];
	[string release];
}



- (IBAction)destination:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	[openPanel setPrompt:NSLS(@"Select", @"Export destination open panel button")];
	
	if([openPanel runModalForDirectory:NULL file:NULL types:NULL] == NSOKButton) {
		[self _setExportGroupDirectory:[openPanel filename]];
		
		[_exportGroupDestinationPopUpButton selectItem:_exportGroupDirectoryMenuItem];
	}
}



- (IBAction)remove:(id)sender {
	NSMutableDictionary		*paths;
	NSMutableArray			*files, *names;
	NSAlert					*alert;
	NSString				*path, *title;
	id						item, exportItem;
	
	files = [NSMutableArray array];
	
	for(item in [[self _selectedItems] reversedArray]) {
		if([item isRepresented]) {
			[files addObject:item];
		} else {
			if([item isKindOfClass:[SPPlaylistFolder class]]) {
				path = [item resolvedPath];
				
				[[WIEventQueue sharedQueue] removePath:path];
				
				[_eventQueueItems removeObjectForKey:path];
			}
			else if([item isKindOfClass:[SPPlaylistExportGroup class]]) {
				for(exportItem in [item items]) {
					if([exportItem isKindOfClass:[SPPlaylistExportItem class]])
						[[exportItem job] stop];
				}
			}
			else if([item isKindOfClass:[SPPlaylistExportItem class]]) {
				[[item job] stop];
			}
			
			[(SPPlaylistGroup *) [item parentItem] removeItem:item];
		}
	}
	
	if([files count] > 0) {
		if([files count] == 1) {
			title = [NSSWF:NSLS(@"Are you sure you want to move \u201c%@\u201d to Trash?", @"Remove file dialog title (filename)"),
				[[files objectAtIndex:0] name]];
		} else {
			title = [NSSWF:NSLS(@"Are you sure you want to move %lu items to Trash?", @"Remove file dialog title (count)"),
				[files count]];
		}
		
		alert = [NSAlert alertWithMessageText:title
								defaultButton:NSLS(@"OK", @"Remove file dialog button")
							  alternateButton:NSLS(@"Cancel", @"Remove file dialog button")
								  otherButton:NULL informativeTextWithFormat:@""];
		
		if([alert runModal] == NSAlertDefaultReturn) {
			paths = [NSMutableDictionary dictionary];
			
			for(item in files) {
				path = [[item resolvedPath] stringByDeletingLastPathComponent];
				names = [paths objectForKey:path];
				
				if(!names) {
					names = [NSMutableArray array];
					[paths setObject:names forKey:path];
				}
				
				[names addObject:[item name]];
			}
			
			for(path in paths) {
				[[NSWorkspace sharedWorkspace]
					performFileOperation:NSWorkspaceRecycleOperation 
								  source:path
							 destination:@""
								   files:[paths objectForKey:path]
									 tag:NULL];
			}
		}
	}

	[_outlineView reloadData];
	
	[self save];
}



- (IBAction)revealInFinder:(id)sender {
	id		item;
	
	item = [self _selectedItem];
	
	if(![item isInFileSystem])
		return;
	
	[[NSWorkspace sharedWorkspace] selectFile:[item resolvedPath] inFileViewerRootedAtPath:NULL];
}



- (IBAction)repeat:(id)sender {
	SPPlaylistRepeatMode	repeatMode;
	
	repeatMode = [self repeatMode];
	
	if(repeatMode == SPPlaylistRepeatOne)
		repeatMode = SPPlaylistRepeatOff;
	else
		repeatMode++;

	[self setRepeatMode:repeatMode];
}



- (IBAction)shuffle:(id)sender {
	[self setShuffle:![self shuffle]];
}



- (IBAction)search:(id)sender {
	[_outlineView reloadData];
}



- (IBAction)selectNoIMDbMatch:(id)sender {
	SPPlaylistFile		*file;
	
	file = [self _selectedItem];
	
	if([file isKindOfClass:[SPPlaylistFile class]]) {
		[file setMetadata:NULL];
		[file setPosterImage:NULL];
		[file setIMDbMatch:[SPIMDbMetadataMatch nullMatch]];
			
		[self _reloadItem:[file parentItem]];
	}
}



- (IBAction)selectIMDbURL:(id)sender {
	[_IMDbURLTextField setStringValue:@""];
	[_IMDbURLInvalidTextField setHidden:YES];
	
	[NSApp beginSheet:_IMDbURLPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(IMDbURLSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)IMDbURLSheetDidEnd:(NSWindow *)window returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSMutableArray			*matches;
	NSString				*string;
	WIURL					*url;
	SPPlaylistFile			*file;
	SPIMDbMetadataMatch		*match;
	
	if(returnCode == NSAlertDefaultReturn) {
		file = [self _selectedItem];
		
		if([file isKindOfClass:[SPPlaylistFile class]]) {
			string = [[_IMDbURLTextField stringValue] stringByMatching:@"title/tt(\\d+)" capture:1];
			
			if(string) {
				url			= [WIURL URLWithString:[NSSWF:@"http://www.imdb.com/title/tt%@/", string]];
				match		= [SPIMDbMetadataMatch matchWithTitle:NSLS(@"Loading...", @"Temparary IMDb match name") URL:url];
				matches		= [[[file IMDbMatches] mutableCopy] autorelease];
				
				if(!matches)
					matches = [NSMutableArray array];
				
				if([matches count] > 0)
					[matches insertObject:match atIndex:0];
				else
					[matches addObject:match];
				
				[file setMetadata:NULL];
				[file setPosterImage:NULL];
				[file setIMDbMatch:NULL];
				[file setIMDbMatches:matches];
				
				[self _reloadItem:[file parentItem]];
			}
		}
	}

	[_IMDbURLPanel close];
}



- (IBAction)fullscreen:(id)sender {
	[self browseInFullscreen:sender];
}



- (IBAction)browseInFullscreen:(id)sender {
	[[SPDrillController drillController] showWindow:self];
}



#pragma mark -

- (SPPlaylistFile *)previousFileForFile:(SPPlaylistFile *)file {
	NSArray			*items;
	id				item;
	NSUInteger		i, index;
	
	items = [self _filteredAndShuffledItemsFromCDFolderForFile:file];

	if([items count] == 0)
		items = [self _filteredAndShuffledItemsForItem:[file parentItem]];

	index = [items indexOfObject:file];
	
	if(index != NSNotFound && index != 0) {
		for(i = index - 1; (NSInteger) i >= 0; i--) {
			item = [items objectAtIndex:i];
			
			if([item isKindOfClass:[SPPlaylistFile class]])
				return item;
		}
	}
	
	return NULL;
}



- (SPPlaylistFile *)nextFileForFile:(SPPlaylistFile *)file {
	NSArray			*items;
	id				item;
	NSUInteger		i, index;
	
	items = [self _filteredAndShuffledItemsFromCDFolderForFile:file];
	
	if([items count] == 0)
		items = [self _filteredAndShuffledItemsForItem:[file parentItem]];
	
	index = [items indexOfObject:file];
	
	if(index != NSNotFound && index < [items count]) {
		for(i = index + 1; i < [items count]; i++) {
			item = [items objectAtIndex:i];
			
			if([item isKindOfClass:[SPPlaylistFile class]])
				return item;
		}
	}
	
	return NULL;
}



- (SPPlaylistFile *)lastFileForFile:(SPPlaylistFile *)file {
	NSArray			*items;
	id				item;
	NSUInteger		i;
	
	items = [self _filteredAndShuffledItemsFromCDFolderForFile:file];
	
	if([items count] == 0)
		items = [self _filteredAndShuffledItemsForItem:[file parentItem]];

	for(i = [items count] - 1; (NSInteger) i >= 0; i--) {
		item = [items objectAtIndex:i];
		
		if([item isKindOfClass:[SPPlaylistFile class]])
			return item;
	}
	
	return NULL;
}



- (SPPlaylistFile *)firstFileForFile:(SPPlaylistFile *)file {
	NSArray			*items;
	id				item;
	
	items = [self _filteredAndShuffledItemsFromCDFolderForFile:file];
	
	if([items count] == 0)
		items = [self _filteredAndShuffledItemsForItem:[file parentItem]];

	for(item in items) {
		if([item isKindOfClass:[SPPlaylistFile class]])
			return item;
	}
	
	return NULL;
}



- (SPPlaylistFile *)selectedFile {
	id		item;
	
	item = [self _selectedItem];
	
	if([item isKindOfClass:[SPPlaylistFile class]])
		return item;
	
	return NULL;
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		item = _playlist;
	
	if([item isKindOfClass:[SPPlaylistContainer class]])
		return [[self _filteredItemsForItems:[item items]] count];
	
	return 0;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isKindOfClass:[SPPlaylistContainer class]];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		item = _playlist;
	
	if([item isKindOfClass:[SPPlaylistContainer class]])
		return [[self _filteredItemsForItems:[item items]] objectAtIndex:index];
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSMutableAttributedString	*string;
	NSMutableDictionary			*attributes;
	NSString					*name, *status;
	
	if(tableColumn == _filesTableColumn) {
		name = _simplifyFilenames ? [item cleanName] : [item name];
		
		if([item isKindOfClass:[SPPlaylistExportItem class]]) {
			if([_exportQueue containsObject:[item job]])
				status = NSLS(@"Queued", @"Export status");
			else
				status = [[item job] status];
			
			attributes = [NSMutableDictionary dictionary];
			
			if([[_outlineView selectedRowIndexes] containsIndex:[_outlineView rowForItem:item]])
				[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
			else
				[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
			
			string = [NSMutableAttributedString attributedStringWithString:name attributes:attributes];
			
			[attributes setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];

			[string appendAttributedString:
				[NSAttributedString attributedStringWithString:[NSSWF:@" (%@)", status] attributes:attributes]];
			
			return string;
		} else {
			return name;
		}
	}
	else if(tableColumn == _viewCountTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]])
			return [NSNumber numberWithUnsignedInteger:[item viewCount]];
	}
	else if(tableColumn == _sizeTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]])
			return [NSString humanReadableStringForSizeInBytes:[(SPPlaylistFile *) item size]];
	}
	else if(tableColumn == _timeTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]] && [(SPPlaylistFile *) item duration] > 0.0)
			return [SPMovieController shortStringForTimeInterval:[(SPPlaylistFile *) item duration]];
	}
	else if(tableColumn == _dimensionsTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]] && [(SPPlaylistFile *) item dimensions].width > 0.0)
			return [SPMovieController shortStringForSize:[(SPPlaylistFile *) item dimensions]];
	}
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView stringValueForRow:(NSInteger)row {
	id		item;
	
	item = [_outlineView itemAtRow:row];
	
	return _simplifyFilenames ? [item cleanName] : [item name];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _filesTableColumn) {
		[cell setImage:[item iconWithSize:NSMakeSize(16.0, 16.0)]];
	
		if([item isKindOfClass:[SPPlaylistFile class]]) {
			[cell setShowsViewStatus:YES];
			[cell setViewStatus:[item viewStatus]];
		}
		else if([item isKindOfClass:[SPPlaylistExportItem class]]) {
			[cell setShowsViewStatus:YES];
			[cell setViewStatus:SPPlaylistUnviewed];
		}
		else {
			[cell setShowsViewStatus:NO];
		}
	}
	else if(tableColumn == _IMDbTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]]) {
			[cell setEnabled:YES];
			[cell setTransparent:NO];
		} else {
			[cell setEnabled:NO];
			[cell setTransparent:YES];
		}
		
		[[cell menu] setDelegate:self];
	}
}




- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _filesTableColumn)
		return ([item class] == [SPPlaylistGroup class]);
	
	return NO;
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSUInteger		index;
	
	if(tableColumn == _filesTableColumn) {
		[(SPPlaylistItem *) item setName:object];
	}
	else if(tableColumn == _IMDbTableColumn) {
		if([item isKindOfClass:[SPPlaylistFile class]]) {
			index = [object unsignedIntegerValue] - 1;
			
			if(index < [[item IMDbMatches] count]) {
				[item setMetadata:NULL];
				[item setPosterImage:NULL];
				[item setIMDbMatch:[[item IMDbMatches] objectAtIndex:index]];
				
				[self _reloadItem:[item parentItem]];
			}
		}
	}
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlaylistControllerSelectionDidChangeNotification object:self];
}



- (void)outlineViewItemDidExpand:(NSNotification *)notification {
	NSString	*path;
	id			item;
	
	item = [[notification userInfo] objectForKey:@"NSObject"];
	
	[self _reloadItem:item];

	if([item isKindOfClass:[SPPlaylistFolder class]]) {
		path = [item resolvedPath];
		
		if([[NSFileManager defaultManager] directoryExistsAtPath:path]) {
			[[WIEventQueue sharedQueue] addPath:path forMode:WIEventFileWrite];
			
			[_eventQueueItems setObject:item forKey:path];
		}
	}
	
	if(_restoring == 0)
		[self _saveLater];
}



- (void)outlineViewItemDidCollapse:(NSNotification *)notification {
	NSString	*path;
	id			item;
	
	item = [[notification userInfo] objectForKey:@"NSObject"];
	
	if([item isKindOfClass:[SPPlaylistFolder class]]) {
		path = [item resolvedPath];

		[[WIEventQueue sharedQueue] removePath:path];
		
		[_eventQueueItems removeObjectForKey:path];
	}
	else if([item isKindOfClass:[SPPlaylistSmartGroup class]]) {
		[item removeAllFiles];
	}
	
	if(_restoring == 0)
		[self _saveLater];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableArray		*types, *paths;
	id					item;
	
	types = [[[pasteboard types] mutableCopy] autorelease];
	[types addObject:SPPlaylistItemPboardType];
	[types addObject:NSFilenamesPboardType];
	[pasteboard declareTypes:types owner:NULL];
	
	paths = [NSMutableArray array];
	
	for(item in items) {
		if([item isInFileSystem])
			[paths addObject:[item resolvedPath]];
	}
	
	[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:SPPlaylistItemPboardType];
	[pasteboard setPropertyList:paths forType:NSFilenamesPboardType];
	
	return YES;
}



- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)childItem proposedChildIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSArray				*types;
	NSString			*path;
	id					item, parentItem;
	NSDragOperation		operation;
	BOOL				exportGroup;

	if(childItem && ![childItem isKindOfClass:[SPPlaylistGroup class]])
		return NSDragOperationNone;
	
	pasteboard		= [info draggingPasteboard];
	types			= [pasteboard types];
	exportGroup		= [childItem isKindOfClass:[SPPlaylistExportGroup class]];

	if([types containsObject:SPPlaylistItemPboardType]) {
		if(exportGroup)
			operation = NSDragOperationCopy;
		else
			operation = [[NSApp currentEvent] alternateKeyModifier] ? NSDragOperationCopy : NSDragOperationMove;
		
		for(item in [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:SPPlaylistItemPboardType]]) {
			parentItem = childItem;
			
			do {
				if([parentItem isEqual:item])
					return NSDragOperationNone;
			} while((parentItem = [parentItem parentItem]));
			
			if([item isKindOfClass:[SPPlaylistRepresentedFile class]])
				operation = NSDragOperationCopy;
			
			if(exportGroup) {
				if(![item isKindOfClass:[SPPlaylistFile class]])
					return NSDragOperationNone;
			}
		}

		return operation;
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		for(path in [pasteboard propertyListForType:NSFilenamesPboardType]) {
			if([[NSFileManager defaultManager] directoryExistsAtPath:path]) {
				if(exportGroup)
					return NSDragOperationNone;
			} else {
				if(![[SPMovieController movieFileTypes] containsObject:[[path pathExtension] lowercaseString]])
					return NSDragOperationNone;
			}
		}

		return NSDragOperationCopy;
	}

	return NSDragOperationNone;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)childItem childIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSArray				*types;
	NSString			*path;
	SPPlaylistGroup		*group;
	id					item, newItem;
	BOOL				exportGroup;
	
	pasteboard		= [info draggingPasteboard];
	types			= [pasteboard types];
	group			= childItem ? childItem : _playlist;
	exportGroup		= [group isKindOfClass:[SPPlaylistExportGroup class]];
	
	if([types containsObject:SPPlaylistItemPboardType] || [types containsObject:NSFilenamesPboardType]) {
		if([types containsObject:SPPlaylistItemPboardType]) {
			for(item in [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:SPPlaylistItemPboardType]]) {
				[item retain];
				
				if(exportGroup)
					newItem = [SPPlaylistExportItem exportItemWithPath:[item resolvedPath]];
				else if([item class] == [SPPlaylistRepresentedFile class])
					newItem = [SPPlaylistFile fileWithPath:[item resolvedPath]];
				else if([item class] == [SPPlaylistRepresentedFolder class])
					newItem = [SPPlaylistFolder folderWithPath:[item resolvedPath]];
				else
					newItem = item;
				
				if(!exportGroup && [[newItem parentItem] isKindOfClass:[SPPlaylistGroup class]] &&
				   ![[NSApp currentEvent] alternateKeyModifier]) {
					[(SPPlaylistGroup *) [newItem parentItem] removeItem:newItem];
				}
				
				if(exportGroup)
					[newItem setMetadata:[item metadata]];
				
				if(index >= 0 && (NSUInteger) index < [group numberOfItems])
					[group insertItem:newItem atIndex:index];
				else
					[group addItem:newItem];
				
				[item release];
			}
		}
		else if([types containsObject:NSFilenamesPboardType]) {
			for(path in [[pasteboard propertyListForType:NSFilenamesPboardType] sortedArrayUsingSelector:@selector(compare:)]) {
				if(exportGroup) {
					item = [SPPlaylistExportItem exportItemWithPath:path];
				} else {
					item = [self fileForPath:path];
					
					if(!item) {
						if([[NSFileManager defaultManager] directoryExistsAtPath:path])
							item = [SPPlaylistFolder folderWithPath:path];
						else
							item = [SPPlaylistFile fileWithPath:path];
					}
				}
				
				if(index >= 0 && (NSUInteger) index < [group numberOfItems])
					[group insertItem:item atIndex:index];
				else
					[group addItem:item];
			}
		}
		
		[self _reloadItem:group];
		
		[_outlineView reloadData];
		
		[self save];
		
		return YES;
	}
		
	return NO;
}

@end
