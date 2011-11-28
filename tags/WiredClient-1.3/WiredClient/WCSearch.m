/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCAccount.h"
#import "WCCache.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCPreferences.h"
#import "WCSearch.h"
#import "WCTransfers.h"

#define WCSearchTypeAudioExtensions		@"aif aiff au mid midi mp3 mp4 wav"
#define WCSearchTypeImageExtensions		@"bmp ico eps jpg jpeg tif tiff gif pict pct png psd sgi tga"
#define WCSearchTypeMovieExtensions		@"avi dv flash mp4 mpg mpg4 mpeg mov rm swf wvm"


@interface WCSearch(Private)

+ (NSArray *)_audioFileTypes;
+ (NSArray *)_imageFileTypes;
+ (NSArray *)_movieFileTypes;

- (id)_initSearchWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_validate;

- (WCFile *)_fileAtIndex:(unsigned int)index;
- (WCFile *)_selectedFile;
- (NSArray *)_selectedFiles;
- (void)_sortFiles;

@end


@implementation WCSearch(Private)

+ (NSArray *)_audioFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)_imageFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)_movieFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



#pragma mark -

- (id)_initSearchWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Search"
								   name:NSLS(@"Search", @"Search window title")
							 connection:connection];

	_allFiles		= [[NSMutableArray alloc] init];
	_shownFiles		= [[NSMutableArray alloc] init];
	_folderImage	= [[NSImage imageNamed:@"Folder16"] retain];
	_uploadsImage	= [[NSImage imageNamed:@"Uploads16"] retain];
	_dropBoxImage	= [[NSImage imageNamed:@"DropBox16"] retain];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[self connection] addObserver:self
						  selector:@selector(searchReceivedFile:)
							  name:WCSearchReceivedFile];

	[[self connection] addObserver:self
						  selector:@selector(searchCompletedFiles:)
							  name:WCSearchCompletedFiles];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_update {
	[_searchTableView setUsesAlternatingRowBackgroundColors:[WCSettings boolForKey:WCFilesAlternateRows]];
	[_searchTableView setNeedsDisplay:YES];
}



- (void)_validate {
	[_searchButton setEnabled:[[self connection] isConnected]];
}



#pragma mark -

- (WCFile *)_fileAtIndex:(unsigned int)index {
	unsigned int		i;
	
	i = ([_searchTableView sortOrder] == WISortDescending)
		? [_shownFiles count] - index - 1
		: index;
	
	return [_shownFiles objectAtIndex:i];
}



- (WCFile *)_selectedFile {
	int		row;

	row = [_searchTableView selectedRow];

	if(row < 0)
		return NULL;

	return [self _fileAtIndex:row];
}



- (NSArray *)_selectedFiles {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSNumber			*row;

	array = [NSMutableArray array];
	enumerator = [_searchTableView selectedRowEnumerator];

	while((row = [enumerator nextObject]))
		[array addObject:[self _fileAtIndex:[row intValue]]];

	return array;
}



- (void)_sortFiles {
	NSTableColumn	*tableColumn;

	tableColumn = [_searchTableView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		[_shownFiles sortUsingSelector:@selector(compareName:)];
	else if(tableColumn == _kindTableColumn)
		[_shownFiles sortUsingSelector:@selector(compareKind:)];
	else if(tableColumn == _createdTableColumn)
		[_shownFiles sortUsingSelector:@selector(compareCreationDate:)];
	else if(tableColumn == _modifiedTableColumn)
		[_shownFiles sortUsingSelector:@selector(compareModificationDate:)];
	else if(tableColumn == _sizeTableColumn)
		[_shownFiles sortUsingSelector:@selector(compareSize:)];
}

@end


@implementation WCSearch

+ (id)searchWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initSearchWithConnection:connection] autorelease];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_folderImage release];
	[_uploadsImage release];
	[_dropBoxImage release];

	[_allFiles release];
	[_shownFiles release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WIIconCell		*iconCell;

	iconCell = [[WIIconCell alloc] init];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	[_searchTableView setDoubleAction:@selector(open:)];
	[_searchTableView setAllowsUserCustomization:YES];
	[_searchTableView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[_searchTableView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Name", @"Size", NULL]];
	
	[self _update];
	
	[super windowDidLoad];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCSearchWindow"] restoreSize:YES visibility:![self isHidden]];
	[_searchTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCSearchTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCSearchWindow"];
	[windowTemplate setObject:[_searchTableView propertiesDictionary] forKey:@"WCSearchTableView"];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[_searchTableView setDataSource:NULL];

	[self close];
	[self autorelease];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[self _validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)searchReceivedFile:(NSNotification *)notification {
	WCFile		*file;
	BOOL		add = NO;

	file = [WCFile fileWithListArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];

	if(![_allFiles containsObject:file]) {
		switch([[_kindPopUpButton selectedItem] tag]) {
			case WCSearchTypeAny:
				add = YES;
				break;

			case WCSearchTypeFolder:
				if([file type] != WCFileFile)
					add = YES;
				break;

			case WCSearchTypeDocument:
				if([file type] == WCFileFile)
					add = YES;
				break;

			case WCSearchTypeAudio:
				if([[[self class] _audioFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeImage:
				if([[[self class] _imageFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeMovie:
				if([[[self class] _movieFileTypes] containsObject:[file extension]])
					add = YES;
				break;
		}

		if(add) {
			[_allFiles addObject:file];

			if([_allFiles count] == 10) {
				[_shownFiles addObjectsFromArray:_allFiles];
				[_allFiles removeAllObjects];

				[_searchTableView reloadData];
			}
		}
	}
}



- (void)searchCompletedFiles:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	WCFile				*file;
	unsigned long long	size = 0;

	[_progressIndicator stopAnimation:self];
	[_shownFiles addObjectsFromArray:_allFiles];

	enumerator = [_shownFiles objectEnumerator];

	while((file = [enumerator nextObject]))
		if([file type] == WCFileFile)
			size += [file size];

	[_statusTextField setStringValue:[NSSWF:
		NSLS(@"%d %@, %@ total", @"Search info (items, 'item(s)', total)"),
		[_shownFiles count],
		[_shownFiles count] == 1
			? NSLS(@"item", @"Item singular")
			: NSLS(@"items", @"Item plural"),
		[NSString humanReadableStringForSize:size]]];

	[self _sortFiles];
	[_searchTableView reloadData];
	[_searchTableView setNeedsDisplay:YES];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	BOOL		connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(open:))
		return ([[self _selectedFile] isFolder] && connected);
	if(selector == @selector(download:))
		return ([[[self connection] account] download] && connected);
	else if(selector == @selector(getInfo:))
		return ([self _selectedFile] != NULL && connected);
	else if(selector == @selector(revealInFiles:))
		return ([self _selectedFile] != NULL && connected);
	else if(selector == @selector(delete:))
		return ([self _selectedFile] != NULL && connected);
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (IBAction)search:(id)sender {
	if([[_searchTextField stringValue] length] == 0)
		return;

	[_allFiles removeAllObjects];
	[_shownFiles removeAllObjects];
	[_searchTableView reloadData];

	[_statusTextField setStringValue:@""];
	[_progressIndicator startAnimation:self];

	[[self connection] sendCommand:WCSearchCommand withArgument:[_searchTextField stringValue]];
}



- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	if(![[self connection] isConnected])
		return;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([file isFolder])
			[WCFiles filesWithConnection:[self connection] path:file];
		else
			[[[self connection] transfers] downloadFile:file];
	}
}



- (IBAction)download:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[[[self connection] transfers] downloadFile:file];
}



- (IBAction)getInfo:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[WCFileInfo fileInfoWithConnection:[self connection] file:file];
}



- (IBAction)revealInFiles:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file, *parentFile;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		parentFile = [WCFile fileWithDirectory:[[file path] stringByDeletingLastPathComponent]];
		
		[WCFiles filesWithConnection:[self connection] path:parentFile selectPath:[file path]];
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownFiles count];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_searchTableView setHighlightedTableColumn:tableColumn];
	[self _sortFiles];
	[_searchTableView reloadData];
}



- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	WCFile		*file;

	file = [self _fileAtIndex:row];

	if(tableColumn == _nameTableColumn) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[file name],				WIIconCellTitleKey,
			[file iconWithWidth:16.0],	WIIconCellIconKey,
			NULL];
	}
	else if(tableColumn == _kindTableColumn)
		return [file kind];
	else if(tableColumn == _createdTableColumn)
		return [[file creationDate] commonDateStringWithSeconds:NO];
	else if(tableColumn == _modifiedTableColumn)
		return [[file modificationDate] commonDateStringWithSeconds:NO];
	else if(tableColumn == _sizeTableColumn) {
		if([file type] == WCFileFile) {
			return [NSString humanReadableStringForSize:[file size]];
		} else {
			return [NSSWF:NSLS(@"%llu %@", @"Files folder size (count, 'item(s)'"),
				[file size],
				[file size] == 1
				? NSLS(@"item", @"Item singular")
				: NSLS(@"items", @"Item plural")];
		}
	}
	
	return NULL;
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(int)row {
	return [[self _fileAtIndex:row] name];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCFile			*file;

	file = [self _selectedFile];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
	[pasteboard setString:[file name] forType:NSStringPboardType];
}

@end
