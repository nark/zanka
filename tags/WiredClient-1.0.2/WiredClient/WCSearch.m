/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSNumberAdditions.h"
#import "WCAccount.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSearch.h"
#import "WCServer.h"
#import "WCTableView.h"
#import "WCTransfers.h"

@implementation WCSearch

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Search"];
	
	// --- get parameters
	_connection		= [connection retain];

	// --- array of the files
	_allFiles		= [[NSMutableArray alloc] init];
	_shownFiles		= [[NSMutableArray alloc] init];
	
	// --- cache pool for icon images
	_iconPool		= [[NSMutableDictionary alloc] init];
	
	// --- get the folder icons
	_folderImage	= [[NSImage imageNamed:@"Folder16"] retain];
	_uploadsImage	= [[NSImage imageNamed:@"Uploads16"] retain];
	_dropBoxImage	= [[NSImage imageNamed:@"DropBox16"] retain];
	
	// --- get the sort images
	_sortUpImage	= [[NSImage imageNamed:@"SortUp"] retain];
	_sortDownImage	= [[NSImage imageNamed:@"SortDown"] retain];
	
	// --- get arrays of file extensions
	_audioExtensions = [[WCSearchTypeAudioExtensions componentsSeparatedByString:@" "] retain];
	_imageExtensions = [[WCSearchTypeImageExtensions componentsSeparatedByString:@" "] retain];
	_movieExtensions = [[WCSearchTypeMovieExtensions componentsSeparatedByString:@" "] retain];

	// --- load the window
	[self window];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionHasAttached:)
		name:WCConnectionHasAttached
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection release];

	[_sortUpImage release];
	[_sortDownImage release];
	
	[_iconPool release];
	[_folderImage release];
	[_uploadsImage release];
	[_dropBoxImage release];
	
	[_audioExtensions release];
	[_imageExtensions release];
	[_movieExtensions release];
	
	[_allFiles release];
	[_shownFiles release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WCIconCell		*iconCell;

	// --- set up our custom cell type
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	// --- double-click
	[_searchTableView setDoubleAction:@selector(open:)];
	
	// --- simulate a click on the name column to sort by name
	[self tableView:_searchTableView didClickTableColumn:_nameTableColumn];

	// --- window position
	[self setWindowFrameAutosaveName:@"Search"];
	[self setShouldCascadeWindows:NO];

	// --- set up window
	[self update];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"Search", @"Search window title"), 0x2014, [_connection name]]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	[_searchTableView setDataSource:NULL];

	[self close];
	[self release];
}



- (void)searchShouldAddFile:(NSNotification *)notification {
	NSString		*argument, *size, *type, *path;
	NSArray			*fields;
	NSString		*extension;
	NSScanner		*scanner;
	WCFile			*file;
	WCConnection	*connection;
	off_t			size_l;
	BOOL			add = NO;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	path	= [fields objectAtIndex:0];
	type	= [fields objectAtIndex:1];
	size	= [fields objectAtIndex:2];
	
	// --- get size
	scanner = [NSScanner scannerWithString:size];
	[scanner scanLongLong:&size_l];
	
	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:size_l];
	[file setPath:path];
	[file setName:[path lastPathComponent]];

	// --- get extension
	extension = [file pathExtension];
	
	switch([[_kindPopUpButton selectedItem] tag]) {
		case WCSearchTypeAny:
			add = YES;
			break;

		case WCSearchTypeFolder:
			if([file type] != WCFileTypeFile)
				add = YES;
			break;

		case WCSearchTypeDocument:
			if([file type] == WCFileTypeFile)
				add = YES;
			break;
		
		case WCSearchTypeAudio:
			if([_audioExtensions containsObject:extension])
				add = YES;
			break;
		
		case WCSearchTypeImage:
			if([_imageExtensions containsObject:extension])
				add = YES;
			break;
		
		case WCSearchTypeMovie:
			if([_movieExtensions containsObject:extension])
				add = YES;
			break;
	}
	
	// --- add it to our array of files
	if(add)
		[_allFiles addObject:file];
	
	[file release];
}



- (void)searchShouldCompleteFiles:(NSNotification *)notification {
	NSString				*argument;
	NSEnumerator			*enumerator;
	WCFile					*file;
	WCConnection			*connection;
	off_t					size = 0;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- stop receiving these notifications
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCSearchShouldAddFile
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCSearchShouldCompleteFiles
		object:NULL];

	// --- we're no longer loading the files
	[_progressIndicator stopAnimation:self];

	// --- enter the accumulated files
	[_shownFiles addObjectsFromArray:_allFiles];
	
	// --- count the total size
	enumerator	= [_shownFiles objectEnumerator];

	while((file = [enumerator nextObject]))
		if([file type] == WCFileTypeFile)
			size += [file size];

	// --- set the status field
	[_statusTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%d %@, %@ total", @"Search info (items, 'item(s)', total)"),
		[_shownFiles count],
		[_shownFiles count] == 1
			? NSLocalizedString(@"item", @"Item singular")
			: NSLocalizedString(@"items", @"Item plural"),
		[[NSNumber numberWithUnsignedLongLong:size] humanReadableSize]]];

	// --- sort the list
	if(_lastTableColumn == _nameTableColumn)
		[_shownFiles sortUsingSelector:@selector(nameSort:)];
	else if(_lastTableColumn == _sizeTableColumn)
		[_shownFiles sortUsingSelector:@selector(sizeSort:)];

	// --- and reload the table
	[_searchTableView reloadData];
	[_searchTableView setNeedsDisplay:YES];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}



#pragma mark -

- (void)update {
}



#pragma mark -

- (IBAction)search:(id)sender {
	if([[_searchTextField stringValue] length] == 0)
		return;
		
	// --- drop all files
	[_allFiles removeAllObjects];
	[_shownFiles removeAllObjects];
	[_searchTableView reloadData];
	
	// --- we are now loading
	[_statusTextField setStringValue:@""];
	[_progressIndicator startAnimation:self];

	// --- stop receiving to avoid double calls
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCSearchShouldAddFile
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCSearchShouldCompleteFiles
		object:NULL];

	// --- restart receiving notifications
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(searchShouldAddFile:)
		name:WCSearchShouldAddFile
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(searchShouldCompleteFiles:)
		name:WCSearchShouldCompleteFiles
		object:NULL];
	
	// --- send search command
	[[_connection client] sendCommand:WCSearchCommand withArgument:[_searchTextField stringValue]];
}



- (IBAction)open:(id)sender {
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_searchTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	switch([file type]) {
		case WCFileTypeDirectory:
		case WCFileTypeUploads:
		case WCFileTypeDropBox:
			// --- open new file window with path
			[[WCFiles alloc] initWithConnection:_connection path:file];
			break;
		
		case WCFileTypeFile:
			// --- check if we can download
			if(![[_connection account] download]) {
				[[_connection error] setError:WCApplicationErrorCannotDownload];
				[[_connection error] raiseErrorInWindow:[self shownWindow]];
				
				return;
			}
		
			[[_connection transfers] download:file preview:NO];
			break;
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownFiles count];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	NSImage		*sortImage;
	
	if(_lastTableColumn == tableColumn) {
		// --- invert sorting
		_sortDescending = !_sortDescending;
	} else {
		_sortDescending = NO;
		
		if(_lastTableColumn)
			[tableView setIndicatorImage:NULL inTableColumn:_lastTableColumn];
		
		// --- set the new sorting selector
		_lastTableColumn = tableColumn;

		if(tableColumn == _nameTableColumn)
			[_shownFiles sortUsingSelector:@selector(nameSort:)];
		else if(tableColumn == _sizeTableColumn)
			[_shownFiles sortUsingSelector:@selector(sizeSort:)];
		
		[tableView setHighlightedTableColumn:tableColumn];
	}
	
	// --- set the image for the new column header
	sortImage = _sortDescending ? _sortDownImage : _sortUpImage;
	[tableView setIndicatorImage:sortImage inTableColumn:tableColumn];
	[tableView reloadData];
}


	
- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	NSImage		*icon = NULL;
	NSString	*extension;
	WCFile		*file;
	int			i;

	// --- get file
	i		= _sortDescending ? [_shownFiles count] - (unsigned int) row - 1 : (unsigned int) row;
	file	= [_shownFiles objectAtIndex:i];
	
	// --- populate columns
	if(column == _nameTableColumn) {
		switch([file type]) {
			case WCFileTypeDirectory:
				icon = _folderImage;
				break;
				
			case WCFileTypeUploads:
				icon = _uploadsImage;
				break;

			case WCFileTypeDropBox:
				icon = _dropBoxImage;
				break;
			
			case WCFileTypeFile:
				extension = [file pathExtension];
				icon = [_iconPool objectForKey:extension];
				
				if(!icon) {
					icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
					[icon setSize:NSMakeSize(16.0, 16.0)];
					[_iconPool setObject:icon forKey:extension];
				}
				break;
		}

		return [NSArray arrayWithObjects:[file name], icon, NULL];
	}
	else if(column == _sizeTableColumn) {
		switch([file type]) {
			case WCFileTypeDirectory:
			case WCFileTypeUploads:
			case WCFileTypeDropBox:
				// --- number of items in folder
				return [NSString stringWithFormat:
					NSLocalizedString(@"%llu %@", @"Search folder size (count, 'item(s)')"),
					[file size],
					[file size] == 1
						? NSLocalizedString(@"item", @"Item singular")
						: NSLocalizedString(@"items", @"Item plural")];
				break;
			
			case WCFileTypeFile:
				// --- human readable size string
				return [file humanReadableSize];
				break;
		}
	}
	
	return NULL;
}

@end
