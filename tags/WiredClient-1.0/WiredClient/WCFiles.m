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

#import <unistd.h>
#import "NSNumberAdditions.h"
#import "WCAccount.h"
#import "WCCache.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreview.h"
#import "WCServer.h"
#import "WCSettings.h"
#import "WCTransfers.h"

@implementation WCFiles

- (id)initWithConnection:(WCConnection *)connection path:(WCFile *)path {
	self = [super initWithWindowNibName:@"Files"];
	
	// --- get parameters
	_connection = [connection retain];
	_path = [path retain];

	// --- load the window
	[self window];
	
	// --- arrays of the files and the history
	_pathHistory	= [[NSMutableArray alloc] init];
	_allFiles		= [[NSMutableArray alloc] init];
	_shownFiles		= [[NSMutableArray alloc] init];

	// --- get the folder icons
	_folderIcon		= [[NSImage imageNamed:@"Folder16"] retain];
	_uploadsIcon	= [[NSImage imageNamed:@"Uploads16"] retain];
	_dropBoxIcon	= [[NSImage imageNamed:@"DropBox16"] retain];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionPrivilegesDidChange:)
		name:WCConnectionPrivilegesDidChange
		object:NULL];

	// --- add path to the history
	[_pathHistory addObject:_path];
	_currentPath = [_pathHistory count] - 1;

	// --- show the window
	[self showWindow:self];

	// --- go to path
	[self changeDirectory:_path];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_sortUpImage release];
	[_sortDownImage release];
	
	[_folderIcon release];
	[_uploadsIcon release];
	[_dropBoxIcon release];
	
	[_pathHistory release];
	[_allFiles release];
	[_shownFiles release];
	[_path release];
	[_connection release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WCIconCell		*iconCell;

	// --- set up our custom cell type
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	// --- we're doing drag'n'drop
	[_filesTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:WCDragFile, NSFilenamesPboardType, NULL]];

	// --- double-click
	[_filesTableView setDoubleAction:@selector(open:)];
	
	// --- get the sort images
	_sortUpImage	= [[NSImage imageNamed:@"SortUp"] retain];
	_sortDownImage	= [[NSImage imageNamed:@"SortDown"] retain];
	
	// --- window position
	[self setWindowFrameAutosaveName:@"Files"];
	[self setShouldCascadeWindows:YES];
	
	// --- set up window
	[self updateButtons];

	// --- simulate a click on the name column to sort by name
	[self tableView:_filesTableView didClickTableColumn:_nameTableColumn];
	
	// --- start off in the table view
	[[self window] makeFirstResponder:_filesTableView];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_filesTableView setDataSource:NULL];
	
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)connectionPrivilegesDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- update buttons
	[self updateButtons];
}



- (void)filesShouldAddFile:(NSNotification *)notification {
	NSString		*argument, *size, *type, *path;
	NSArray			*fields;
	NSScanner		*scanner;
	WCFile			*file;
	WCConnection	*connection;
	off_t			size_l;
	
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
	
	if(![[path stringByDeletingLastPathComponent] isEqualToString:[_path path]])
		return;
		
	// --- scan size
	scanner = [NSScanner scannerWithString:size];
	[scanner scanLongLong:&size_l];
	
	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:size_l];
	[file setPath:path];
	[file setName:[path lastPathComponent]];

	// --- add it to our array of files
	[_allFiles addObject:file];

	[file release];
}



- (void)filesShouldCompleteFiles:(NSNotification *)notification {
	NSString		*argument, *path, *free;
	NSArray			*fields;
	NSScanner		*scanner;
	WCConnection	*connection;
	off_t			free_l;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	path	= [fields objectAtIndex:0];
	free	= [fields objectAtIndex:1];

	if(![path isEqualToString:[_path path]])
		return;
	
	// --- scan size
	scanner = [NSScanner scannerWithString:free];
	[scanner scanLongLong:&free_l];
	[_path setFree:free_l];

	// --- stop receiving these notifications
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCFilesShouldAddFile
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCFilesShouldCompleteFiles
		object:NULL];
	
	// --- enter the accumulated files
	[_shownFiles addObjectsFromArray:_allFiles];
	
	// --- save this in the cache
	[[_connection cache] setFiles:[NSArray arrayWithArray:_shownFiles]
							 free:[_path free] 
						  forPath:[_path path]];
	
	// --- update the files display
	[self updateFiles];
}



- (void)filesShouldReload:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;
	int				row;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	if([argument isEqualToString:[_path path]]) {
		// --- remove as observer until we've received all the files
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:WCFilesShouldReload
			object:NULL];
		
		// --- get row number
		row	= [_filesTableView selectedRow];
	
		// --- save selection
		if(row >= 0)
			_selection = [[_shownFiles objectAtIndex:row] retain];

		// --- drop cache
		[[_connection cache] dropFilesForPath:[_path path]];
		
		// --- this notification may come from a transfer thread
		[self performSelectorOnMainThread:@selector(changeDirectory:) withObject:_path waitUntilDone:NO];
	}
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		WCFile		*file;
	
		// --- get the file in question
		file = (WCFile *) contextInfo;

		// --- send the delete command
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@", WCDeleteCommand, [file path]]];

		// --- reload all files affected
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection, [_path path], NULL]];
	}
}



- (void)openPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if(returnCode == NSOKButton) {
		NSEnumerator	*enumerator;
		NSArray			*files;
		NSString		*path;
		
		// --- get paths
		files = [openPanel filenames];
		enumerator = [files objectEnumerator];

		// --- reset enumerator
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];

		// --- upload paths
		while((path = [enumerator nextObject]))
			[[_connection transfers] upload:path withDestination:_path];
	}
}



#pragma mark -

- (void)updateFiles {
	NSEnumerator		*enumerator;
	WCFile				*file;
	off_t				size = 0;
	int					i = 0, row = -1;

	// --- count the total size
	enumerator	= [_shownFiles objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([file type] == WCFileTypeFile)
			size += [file size];
	}
	
	// --- set the status field
	if([self canUpload]) {
		[_statusTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"%d %@, %@ total, %@ available", @"Files info (count, 'item(s)', size, available)"),
			[_shownFiles count],
			[_shownFiles count] == 1
				? NSLocalizedString(@"item", @"Item singular")
				: NSLocalizedString(@"items", @"Item plural"),
			[[NSNumber numberWithUnsignedLongLong:size] humanReadableSize],
			[[NSNumber numberWithUnsignedLongLong:[_path free]] humanReadableSize]]];
	} else {
		[_statusTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"%d %@, %@ total", @"Files info (count, 'item(s)', size)"),
			[_shownFiles count],
			[_shownFiles count] == 1
				? NSLocalizedString(@"item", @"Item singular")
				: NSLocalizedString(@"items", @"Item plural"),
			[[NSNumber numberWithUnsignedLongLong:size] humanReadableSize]]];
	}

	
	// --- sort the list
	if(_lastTableColumn == _nameTableColumn)
		[_shownFiles sortUsingSelector:@selector(nameSort:)];
	else if(_lastTableColumn == _sizeTableColumn)
		[_shownFiles sortUsingSelector:@selector(sizeSort:)];
	
	// --- and reload the table
	[_filesTableView reloadData];
	
	// --- select parent
	if(_selection) {
		enumerator = [_shownFiles objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			if([file nameSort:_selection] <= 0)
				row = i;

			i++;
		}
		
		[_filesTableView selectRow:row >= 0 ? row : 0 byExtendingSelection:NO];
		[_filesTableView scrollRowToVisible:row >= 0 ? row : 0];
		
		[_selection release];
		_selection = NULL;
	}
	
	
	// --- start receiving reload notifications again
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(filesShouldReload:)
			   name:WCFilesShouldReload
			 object:NULL];
	
	// --- we're no longer loading the files
	[_progressIndicator stopAnimation:self];
}



- (void)changeDirectory:(WCFile *)path {
	NSArray		*cache;
	off_t		free;

	// --- copy path
	[path retain];
	[_path release];
	_path = path;

	// --- drop all files
	[_allFiles removeAllObjects];
	[_shownFiles removeAllObjects];
	[_filesTableView reloadData];

	// --- change the path
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"Files", @"Files window title"),
		0x2014,
		[_path path]]];
	
	// --- update buttons
	[self updateButtons];
	
	// --- update menus
	[WCSharedMain updateMenus];
	
	// --- we are now loading
	[_statusTextField setStringValue:@""];
	[_progressIndicator startAnimation:self];
	
	// --- check for cache
	if((cache = [[_connection cache] filesForPath:[_path path] free:&free])) {
		// --- enter the cached files
		[_shownFiles addObjectsFromArray:cache];
		
		// --- set free count
		[_path setFree:free];
		
		// --- update the files display
		[self updateFiles];
	} else {
		// --- re-subscribe to these
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(filesShouldAddFile:)
				   name:WCFilesShouldAddFile
				 object:NULL];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(filesShouldCompleteFiles:)
				   name:WCFilesShouldCompleteFiles
				 object:NULL];
		
		// --- send the list command
		[[_connection client] sendCommand:WCListCommand withArgument:[_path path]];
	}
}



- (void)updateButtons {
	NSString	*extension;
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0) {
		[_downloadButton setEnabled:NO];
		[_previewButton setEnabled:NO];
		[_infoButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
	} else {
		// --- get file
		file = [_shownFiles objectAtIndex:row];
		extension = [[[file path] pathExtension] lowercaseString];
	
		if([[_connection account] download])
			[_downloadButton setEnabled:YES];
		else
			[_downloadButton setEnabled:NO];
		
		if([[_connection account] deleteFiles])
			[_deleteButton setEnabled:YES];
		else
			[_deleteButton setEnabled:NO];

		if([[_connection account] download] && [file type] == WCFileTypeFile &&
		   ([extension isEqualToString:@""] ||
		    [[WCPreviewAllExtensions componentsSeparatedByString:@" "] containsObject:extension]))
			[_previewButton setEnabled:YES];
		else
			[_previewButton setEnabled:NO];

		[_infoButton setEnabled:YES];
	}
	
	if([self canUpload])
		[_uploadButton setEnabled:YES];
	else
		[_uploadButton setEnabled:NO];

	if([self canCreateFolders])
		[_newFolderButton setEnabled:YES];
	else
		[_newFolderButton setEnabled:NO];
}



#pragma mark -

- (BOOL)canMoveBack {
	return (_currentPath > 0);
}



- (BOOL)canMoveForward {
	return (_currentPath + 1 < [_pathHistory count]);
}



- (BOOL)canGetInfo {
	return ([_filesTableView selectedRow] >= 0);
}



- (BOOL)canUpload {
	return ([[_connection account] uploadAnywhere] ||
		   ([[_connection account] upload] &&
		   ([_path type] == WCFileTypeUploads || [_path type] == WCFileTypeDropBox)));
}




- (BOOL)canDeleteFiles {
	return ([_filesTableView selectedRow] >= 0) && [[_connection account] deleteFiles];
}



- (BOOL)canCreateFolders {
	return ([[_connection account] createFolders] || [[_connection account] uploadAnywhere] ||
		   ([[_connection account] upload] &&
			([_path type] == WCFileTypeUploads || [_path type] == WCFileTypeDropBox)));
}



#pragma mark -

- (IBAction)open:(id)sender {
	WCFile		*file;
	BOOL		optionKey, newWindows;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	switch([file type]) {
		case WCFileTypeDirectory:
		case WCFileTypeUploads:
		case WCFileTypeDropBox:
			// --- determine settings
			optionKey	= (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
			newWindows	= [[WCSettings objectForKey:WCOpenFoldersInNewWindows] boolValue];
	
			if((newWindows && !optionKey) || (!newWindows && optionKey)) {
				// --- open new file window with path
				[[WCFiles alloc] initWithConnection:_connection path:file];
			} else {
				// --- clear existing files
				[_shownFiles removeAllObjects];
				[_filesTableView reloadData];
					
				// --- remove all paths in history beyond this
				[_pathHistory removeObjectsInRange:
					NSMakeRange(_currentPath + 1, [_pathHistory count] - _currentPath - 1)];
		
				// --- add it to the history
				[_pathHistory addObject:file];
				_currentPath = [_pathHistory count] - 1;
				[_backButton setEnabled:YES];
				if(_currentPath + 1 == [_pathHistory count])
					[_forwardButton setEnabled:NO];
		
				// --- go to a new directory
				[self changeDirectory:file];
			}
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



- (IBAction)back:(id)sender {
	if([self canMoveBack]) {
		// --- save the current directory
		_selection = [_path retain];

		// --- change the directory
		[self changeDirectory:[_pathHistory objectAtIndex:--_currentPath]];
		
		// --- update buttons
		if(_currentPath == 0)
			[_backButton setEnabled:NO];

		[_forwardButton setEnabled:YES];
	}
}



- (IBAction)forward:(id)sender {
	if([self canMoveForward]) {
		[self changeDirectory:[_pathHistory objectAtIndex:++_currentPath]];
	
		if(_currentPath + 1 == [_pathHistory count])
			[_forwardButton setEnabled:NO];
		
		[_backButton setEnabled:YES];
	}
}



- (IBAction)download:(id)sender {
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	// --- queue a transfer
	[[_connection transfers] download:file preview:NO];
}



- (IBAction)upload:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];
	
	// --- set options
	[openPanel setCanChooseDirectories:[self canCreateFolders]];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	
	// --- run panel
	[openPanel beginSheetForDirectory:NULL
			   file:NULL
			   types:NULL
			   modalForWindow:[self window]
			   modalDelegate:self
			   didEndSelector:@selector(openPanelDidEnd: returnCode: contextInfo:)
			   contextInfo:NULL];
}



- (IBAction)info:(id)sender {
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	// --- create an info window
	[[WCFileInfo alloc] initWithConnection:_connection file:file];
}



- (IBAction)preview:(id)sender {
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	// --- queue a transfer
	[[_connection transfers] download:file preview:YES];
}



- (IBAction)newFolder:(id)sender {
	[NSApp beginSheet:_newFolderPanel
		   modalForWindow:[self window]
		   modalDelegate:self
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)reload:(id)sender {
	int		row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	// --- save selection
	if(row >= 0)
		_selection = [[_shownFiles objectAtIndex:row] retain];

	// --- drop cache
	[[_connection cache] dropFilesForPath:[_path path]];
	
	// --- reload
	[self changeDirectory:_path];
}



- (IBAction)delete:(id)sender {
	NSString	*title, *description;
	WCFile		*file;
	int			row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0 || ![[_connection account] deleteFiles])
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];

	// --- check if we can delete
	if(![[_connection account] deleteFiles]) {
		[[_connection error] setError:[file type] == WCFileTypeFile
			? WCApplicationErrorCannotDeleteFiles
			: WCApplicationErrorCannotDeleteFolders];
		[[_connection error] raiseErrorInWindow:[self shownWindow]];
		
		return;
	}
	
	// --- setup dialog texts
	title = [NSString stringWithFormat:
		NSLocalizedString(@"Are you sure you want to delete \"%@\"?", @"Delete file dialog title (filename)"),
		[file name]];
	description = NSLocalizedString(@"This cannot be undone.", @"Delete file dialog description");

	// --- bring up an alert
	NSBeginAlertSheet(title,
					  NSLocalizedString(@"Delete", @"Delete file button title"),
					  @"Cancel",
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  file,
					  description,
					  NULL);
}



#pragma mark -

- (IBAction)createFolder:(id)sender {
	NSString		*folder;
	
	folder = [_newFolderTextField stringValue];

	// --- send the new folder command
	[[_connection client] sendCommand:[NSString stringWithFormat:
		@"%@ %@", WCFolderCommand, [[_path path] stringByAppendingPathComponent:folder]]];

	// --- close sheet
	[self cancelFolder:self];

	// --- reload all files affected
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCFilesShouldReload
		object:[NSArray arrayWithObjects:_connection, [_path path], NULL]];
}



- (IBAction)cancelFolder:(id)sender {
	// --- close sheet
	[NSApp endSheet:_newFolderPanel];
	[_newFolderPanel close];
		
	// --- clear for next round
	[_newFolderTextField setStringValue:@""];
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



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
	[WCSharedMain updateMenus];
}



- (id)tableView:(NSTableView *)sender objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	NSImage		*icon;
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
				icon = _folderIcon;
				break;
				
			case WCFileTypeUploads:
				icon = _uploadsIcon;
				break;

			case WCFileTypeDropBox:
				icon = _dropBoxIcon;
				break;

			case WCFileTypeFile:
			default:
				extension = [file pathExtension];
				icon = [[_connection cache] fileIconForExtension:extension];
				
				if(!icon) {
					icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
					[icon setSize:NSMakeSize(16.0, 16.0)];
					[[_connection cache] setFileIcon:icon forExtension:extension];
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
					NSLocalizedString(@"%llu %@", @"Files folder size (count, 'item(s)'"),
					[file size],
					[file size] == 1
						? NSLocalizedString(@"item", @"Item singular")
						: NSLocalizedString(@"items", @"Item plural")];
				break;
			
			case WCFileTypeFile:
			default:
				// --- human readable size string
				return [file humanReadableSize];
				break;
		}
	}
	
	return NULL;
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCFile		*file;
	int			row;
	
	// --- get row
	row = [[items objectAtIndex:0] intValue];
	
	if(row < 0)
		return NO;

	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	// --- put path in pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObjects:
		WCDragFile, NSStringPboardType, NULL] owner:NULL];
	[pasteboard setData:[NSArchiver archivedDataWithRootObject:file] forType:WCDragFile];
	[pasteboard setString:[file path] forType:NSStringPboardType];

	return YES;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)proposedRow 
proposedDropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCFile			*destination;
	
	// --- get pasteboard
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
		
	// --- get destination
	destination = proposedRow >= 0 && proposedRow < (int) [_shownFiles count]
		? [_shownFiles objectAtIndex:proposedRow]
		: _path;
	
	// --- check privilege
	if(![[_connection account] moveFiles])
		return NSDragOperationNone;
	
	// --- turn drops between rows into drops to the window, if it's the last row
	if(operation == NSTableViewDropAbove) {
		if(destination == _path)
			[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
		else
			return NSDragOperationNone;
	}

	// --- turn drops on files into drops to the window
	if([destination type] == WCFileTypeFile)
		[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	
	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info 
row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCFile			*destination;

	// --- get pasteboard
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
		
	// --- get destination
	destination = row >= 0 && row < (int) [_shownFiles count]
		? [_shownFiles objectAtIndex:row]
		: _path;
	
	if([types containsObject:WCDragFile]) {
		NSData			*data;
		WCFile			*source;
		
		// --- get file
		data	= [pasteboard dataForType:WCDragFile];
		source	= [NSUnarchiver unarchiveObjectWithData:data];

		if(![[[source path] stringByDeletingLastPathComponent] isEqualTo:[destination path]]) {
			// --- move file
			[[_connection client] sendCommand:[NSString stringWithFormat:
				@"%@ %@%@%@",
				WCMoveCommand,
				[source path],
				WCFieldSeparator,
				[[destination path] stringByAppendingPathComponent:[source name]]]];
			
			// --- announce reloads on both this, the source and their parents
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[source path] stringByDeletingLastPathComponent],
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[destination path],
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[destination path] stringByDeletingLastPathComponent],
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[[source path] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent],
					NULL]];
			
			return YES;
		}
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		NSEnumerator	*enumerator;
		NSArray			*files;
		NSString		*path;
		
		// --- check if we can upload here
		if(![self canUpload]) {
			[[_connection error] setError:WCApplicationErrorCannotUpload];
			[[_connection error] raiseErrorInWindow:[self shownWindow]];
		
			return NO;
		}

		// --- get paths
		files = [pasteboard propertyListForType:NSFilenamesPboardType];
		enumerator = [files objectEnumerator];
		
		// --- reset enumerator
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
		
		// --- upload paths
		while((path = [enumerator nextObject]))
			[[_connection transfers] upload:path withDestination:destination];
		
		return YES;
	}
	
	return NO;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCFile			*file;
	int				row;
	
	// --- get row number
	row	= [_filesTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	file = [_shownFiles objectAtIndex:row];
	
	// --- put it on the pasteboard
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[file lastPathComponent] forType:NSStringPboardType];
}

@end
