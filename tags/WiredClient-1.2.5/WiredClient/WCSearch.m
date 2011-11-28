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

#import "NSDateAdditions.h"
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "NSWindowControllerAdditions.h"
#import "WCAccount.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSearch.h"
#import "WCServer.h"
#import "WCTableView.h"
#import "WCTextCell.h"
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
	
	// --- get arrays of file extensions
	_audioExtensions = [[WCSearchTypeAudioExtensions componentsSeparatedByString:@" "] retain];
	_imageExtensions = [[WCSearchTypeImageExtensions componentsSeparatedByString:@" "] retain];
	_movieExtensions = [[WCSearchTypeMovieExtensions componentsSeparatedByString:@" "] retain];

	// --- load the window
	[self window];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionServerInfoDidChange:)
			   name:WCConnectionServerInfoDidChange
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
	WCTextCell		*textCell;
	
	// --- set up our custom cell types
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[iconCell setControlSize:NSSmallControlSize];
	[[_searchTableView tableColumnWithIdentifier:@"Name"] setDataCell:iconCell];
	[iconCell release];
	
	textCell = [[WCTextCell alloc] init];
	[[_searchTableView tableColumnWithIdentifier:@"Kind"] setDataCell:textCell];
	[textCell release];

	// --- double-click
	[_searchTableView setDoubleAction:@selector(open:)];

	// --- window position
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Search"];
	
	// --- table view position
	[_searchTableView setAutosaveName:@"Search"];
	[_searchTableView setAutosaveTableColumns:YES];
	
	// --- set up window
	[self update];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Search", @"Search window title")]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	[_searchTableView setDataSource:NULL];

	[self close];
	[self release];
}



- (void)searchShouldAddFile:(NSNotification *)notification {
	NSString			*argument, *size, *type, *path, *created = NULL, *modified = NULL;
	NSArray				*fields;
	NSString			*extension;
	WCFile				*file;
	WCConnection		*connection;
	BOOL				add = NO;
	
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
	
	// --- protocol 1.1
	if([_connection protocol] >= 1.1) {
		created		= [fields objectAtIndex:3];
		modified	= [fields objectAtIndex:4];
	}

	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:[size unsignedLongLongValue]];
	[file setPath:path];
	[file setName:[path lastPathComponent]];

	// --- protocol 1.1
	if([_connection protocol] >= 1.1) {
		[file setCreated:[NSDate dateWithISO8601String:created]];
		[file setModified:[NSDate dateWithISO8601String:modified]];
	}
	
	if(![_allFiles containsObject:file]) {
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
		if(add) {
			[_allFiles addObject:file];
			
			if([_allFiles count] == 10) {
				[_shownFiles addObjectsFromArray:_allFiles];
				[_allFiles removeAllObjects];
				
				[_searchTableView reloadData];
			}
		}
	}
	
	[file release];
}



- (void)searchShouldCompleteFiles:(NSNotification *)notification {
	NSString				*argument, *identifier;
	NSEnumerator			*enumerator;
	WCFile					*file;
	WCConnection			*connection;
	unsigned long long		size = 0;
	
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
		[NSString humanReadableStringForSize:size]]];
	
	// --- get identifier
	identifier = [[_searchTableView highlightedTableColumn] identifier];

	// --- sort the list
	if([identifier isEqualToString:@"Name"])
		[_shownFiles sortUsingSelector:@selector(nameSort:)];
	else if([identifier isEqualToString:@"Kind"])
		[_shownFiles sortUsingSelector:@selector(kindSort:)];
	else if([identifier isEqualToString:@"Size"])
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



- (BOOL)validateMenuItem:(id <NSMenuItem>)item {
	WCFile		*file;
	int			i, row;
	
	// --- get row number
	row	= [_searchTableView selectedRow];
	
	if(row < 0)
		return NO;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	if(item == _openMenuItem)
		return [file type] != WCFileTypeFile;
	else if(item == _downloadMenuItem)
		return [[_connection account] download];
	
	return YES;
}



#pragma mark -

- (BOOL)canGetInfo {
	return ([_searchTableView selectedRow] >= 0);
}



#pragma mark -

- (NSPanel *)viewOptionsPanel {
	return _viewOptionsPanel;
}




- (NSTableView *)tableView {
	return _searchTableView;
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
	[_connection sendCommand:WCSearchCommand
				withArgument:[_searchTextField stringValue]
				  withSender:self];
}



- (IBAction)open:(id)sender {
	WCFile		*file;
	int			i, row;
		
	// --- ignore header clicks
	if([_searchTableView clickedHeaderView])
		return;
	
	// --- get row number
	row	= [_searchTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
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
		
			// --- queue a transfer
			[[_connection transfers] download:file preview:NO];
			break;
	}
}



- (IBAction)download:(id)sender {
	WCFile		*file;
	int			i, row;
	
	// --- get row number
	row	= [_searchTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- queue a transfer
	[[_connection transfers] download:file preview:NO];
}



- (IBAction)info:(id)sender {
	WCFile		*file;
	int			i, row;
	
	// --- get row number
	row	= [_searchTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- create an info window
	[[WCFileInfo alloc] initWithConnection:_connection file:file];
}



- (IBAction)revealInFiles:(id)sender {
	WCFile		*file, *parent;
	int			i, row;
	
	// --- get row number
	row	= [_searchTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- create parent
	parent = [[WCFile alloc] initWithType:WCFileTypeDirectory];
	[parent setPath:[[file path] stringByDeletingLastPathComponent]];

	// --- open new file window with path
	[[WCFiles alloc] initWithConnection:_connection path:parent selectPath:[file path]];

	[parent release];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownFiles count];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	NSString	*identifier;
	
	// --- get identifier
	identifier = [tableColumn identifier];
		
	// --- re-sort
	if([identifier isEqualToString:@"Name"])
		[_shownFiles sortUsingSelector:@selector(nameSort:)];
	else if([identifier isEqualToString:@"Kind"])
		[_shownFiles sortUsingSelector:@selector(kindSort:)];
	else if([identifier isEqualToString:@"Created"])
		[_shownFiles sortUsingSelector:@selector(createdSort:)];
	else if([identifier isEqualToString:@"Modified"])
		[_shownFiles sortUsingSelector:@selector(modifiedSort:)];
	else if([identifier isEqualToString:@"Size"])
		[_shownFiles sortUsingSelector:@selector(sizeSort:)];
	
	// --- select new column header
	[_searchTableView setHighlightedTableColumn:tableColumn];
	[_searchTableView reloadData];
}


	
- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSImage		*icon = NULL;
	NSString	*extension, *identifier;
	WCFile		*file;
	int			i;

	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file		= [_shownFiles objectAtIndex:i];
	identifier  = [tableColumn identifier];
	
	// --- populate columns
	if([identifier isEqualToString:@"Name"]) {
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
		
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[file name],		WCIconCellNameKey,
			icon,				WCIconCellImageKey,
			NULL];
	}
	else if([identifier isEqualToString:@"Kind"]) {
		return [file kind];
	}
	else if([identifier isEqualToString:@"Created"]) {
		return [[file created] commonDateStringWithRelative:YES seconds:NO];
	}
	else if([identifier isEqualToString:@"Modified"]) {
		return [[file modified] commonDateStringWithRelative:YES seconds:NO];
	}
	else if([identifier isEqualToString:@"Size"]) {
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



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(int)row {
	WCFile		*file;
	int			i;
	
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	return [file name];
}



- (NSString *)tableView:(NSTableView *)tableView toolTipForRow:(int)row {
	WCFile		*file;
	int			i;
	
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	return [file name];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCFile			*file;
	int				i, row;
	
	// --- get row number
	row	= [_searchTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	i = [_searchTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- put it on the pasteboard
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[file lastPathComponent] forType:NSStringPboardType];
}

@end
