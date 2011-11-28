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
#import "WCCache.h"
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
#import "WCTableView.h"
#import "WCTextCell.h"
#import "WCTransfers.h"

@implementation WCFiles

- (id)initWithConnection:(WCConnection *)connection path:(WCFile *)path {
	return [self initWithConnection:connection path:path selectPath:NULL];
}



- (id)initWithConnection:(WCConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath {
	self = [super initWithWindowNibName:@"Files"];
	
	// --- get parameters
	_connection		= [connection retain];
	_path			= [path retain];
	_selectPath		= [selectPath retain];

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
	WCTextCell		*textCell;

	// --- set up our custom cell types
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[iconCell setControlSize:NSSmallControlSize];
	[[_filesTableView tableColumnWithIdentifier:@"Name"] setDataCell:iconCell];
	[iconCell release];

	textCell = [[WCTextCell alloc] init];
	[[_filesTableView tableColumnWithIdentifier:@"Kind"] setDataCell:textCell];
	[textCell release];
	
	// --- we're doing drag'n'drop
	[_filesTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:WCFilePboardType, NSFilenamesPboardType, NULL]];

	// --- double-click
	[_filesTableView setDoubleAction:@selector(open:)];
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_path path], 0x2014, [_connection name]]];
	
	// --- window position
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Files"];
	
	// --- table view position
	[_filesTableView setAutosaveName:@"Files"];
	[_filesTableView setAutosaveTableColumns:YES];
	
	// --- set up window
	[self updateButtons];
	
	// --- start off in the table view
	[[self window] makeFirstResponder:_filesTableView];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_filesTableView setDataSource:NULL];
	
	[super windowWillClose:notification];

	[self release];
}


- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_path path], 0x2014, [_connection name]]];
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
	NSString			*argument, *size, *type, *path, *created = NULL, *modified = NULL;
	NSArray				*fields;
	WCFile				*file;
	WCConnection		*connection;
	
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
	
	if(![[path stringByDeletingLastPathComponent] isEqualToString:[_path path]])
		return;
		
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

	// --- add it to our array of files
	if(![_allFiles containsObject:file])
		[_allFiles addObject:file];

	[file release];
}



- (void)filesShouldCompleteFiles:(NSNotification *)notification {
	NSString		*argument, *path, *free;
	NSArray			*fields;
	WCConnection	*connection;
	
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
	
	// --- set fields
	[_path setFree:[free unsignedLongLongValue]];

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
	NSString		*path, *selectPath;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	path		= [[notification object] objectAtIndex:1];
	selectPath	= [[notification object] objectAtIndex:2];
	
	if(connection != _connection)
		return;
	
	if([path isEqualToString:[_path path]]) {
		// --- remove as observer until we've received all the files
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:WCFilesShouldReload
			object:NULL];
		
		// --- save selection
		if([selectPath length] > 0)
			_selectPath = [selectPath retain];

		// --- drop cache
		[[_connection cache] dropFilesForPath:[_path path]];
		
		// --- change directory
		[self changeDirectory:_path];
	}
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		WCFile		*file;
	
		// --- get the file in question
		file = (WCFile *) contextInfo;

		// --- send the delete command
		[_connection sendCommand:WCDeleteCommand withArgument:[file path] withSender:self];

		// --- reload all files affected
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection, [_path path], [file path], NULL]];
	}
}



- (void)newFolderSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if(returnCode == NSRunStoppedResponse) {
		NSString		*path;
		
		// --- get path to new folder
		path = [[_path path] stringByAppendingPathComponent:[_newFolderTextField stringValue]];

		// --- send the new folder command
		[_connection sendCommand:WCFolderCommand withArgument:path withSender:self];
		
		// --- reload all files affected
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection, [_path path], path, NULL]];
	}
	
	// --- close sheet
	[_newFolderPanel close];
	
	// --- clear for next round
	[_newFolderTextField setStringValue:@""];
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
	NSString			*identifier;
	WCFile				*file;
	unsigned long long	size = 0;
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
			[NSString humanReadableStringForSize:size],
			[NSString humanReadableStringForSize:[_path free]]]];
	} else {
		[_statusTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"%d %@, %@ total", @"Files info (count, 'item(s)', size)"),
			[_shownFiles count],
			[_shownFiles count] == 1
				? NSLocalizedString(@"item", @"Item singular")
				: NSLocalizedString(@"items", @"Item plural"),
			[NSString humanReadableStringForSize:size]]];
	}
	
	// --- get identifier
	identifier = [[_filesTableView highlightedTableColumn] identifier];

	// --- sort the list
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
	
	// --- and reload the table
	[_filesTableView reloadData];
	
	// --- select parent
	if(_selectPath) {
		enumerator = [_filesTableView sortDescending]
			? [_shownFiles objectEnumerator]
			: [_shownFiles objectEnumerator];
	
		while((file = [enumerator nextObject])) {
			if([[file path] compare:_selectPath options:NSCaseInsensitiveSearch] <= 0)
				row = i;

			i++;
		}
		
		i = [_filesTableView sortDescending]
			? [_shownFiles count] - (unsigned int) row - 1
			: (unsigned int) row;
		[_filesTableView selectRow:i >= 0 ? i : 0 byExtendingSelection:NO];
		[_filesTableView scrollRowToVisible:row >= 0 ? i : 0];
		
		[_selectPath release];
		_selectPath = NULL;
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
	NSArray				*cache;
	unsigned long long	free;

	// --- copy path
	[path retain];
	[_path release];
	_path = path;

	// --- drop all files
	[_allFiles removeAllObjects];
	[_shownFiles removeAllObjects];
	[_filesTableView reloadData];

	// --- change the window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_path path],
		0x2014,
		[_connection name]]];
	
	// --- update buttons
	[self updateButtons];
	
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
		[_connection sendCommand:WCListCommand withArgument:[_path path] withSender:self];
	}
}



- (void)updateButtons {
	NSString	*extension;
	WCFile		*file;
	int			i, row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0) {
		[_downloadButton setEnabled:NO];
		[_previewButton setEnabled:NO];
		[_infoButton setEnabled:NO];
		[_deleteButton setEnabled:NO];
	} else {
		// --- get file
		i = [_filesTableView sortDescending]
			? [_shownFiles count] - (unsigned int) row - 1
			: (unsigned int) row;
		file = [_shownFiles objectAtIndex:i];
		extension = [[[file path] pathExtension] lowercaseString];
	
		[_downloadButton setEnabled:[[_connection account] download]];
		
		[_deleteButton setEnabled:[[_connection account] deleteFiles]];

		if([[_connection account] download] && [file type] == WCFileTypeFile &&
		   ([extension isEqualToString:@""] ||
		    [[WCPreviewAllExtensions componentsSeparatedByString:@" "] containsObject:extension]))
			[_previewButton setEnabled:YES];
		else
			[_previewButton setEnabled:NO];

		[_infoButton setEnabled:YES];
	}
	
	[_uploadButton setEnabled:[self canUpload]];
	[_newFolderButton setEnabled:[self canCreateFolders]];
}



- (BOOL)validateMenuItem:(id <NSMenuItem>)item {
	if(item == _downloadMenuItem)
		return [[_connection account] download];
	else if(item == _deleteMenuItem)
		return [[_connection account] deleteFiles];
	
	return YES;
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

- (NSPanel *)viewOptionsPanel {
	return _viewOptionsPanel;
}




- (NSTableView *)tableView {
	return _filesTableView;
}



#pragma mark -

- (IBAction)open:(id)sender {
	WCFile		*file;
	BOOL		optionKey, newWindows;
	int			i, row;
	
	// --- ignore header clicks
	if([_filesTableView clickedHeaderView])
		return;
	
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	switch([file type]) {
		case WCFileTypeDirectory:
		case WCFileTypeUploads:
		case WCFileTypeDropBox:
			// --- determine settings
			optionKey	= (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
			newWindows	= [WCSettings boolForKey:WCOpenFoldersInNewWindows];
	
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
		
			// --- queue a transfer
			[[_connection transfers] download:file preview:NO];
			break;
	}
}



- (IBAction)back:(id)sender {
	if([self canMoveBack]) {
		// --- save the current directory
		_selectPath = [[_path path] retain];

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
	int			i, row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	i = [_filesTableView sortDescending] ?
		[_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
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
	int			i, row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- create an info window
	[[WCFileInfo alloc] initWithConnection:_connection file:file];
}



- (IBAction)preview:(id)sender {
	WCFile		*file;
	int			i, row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0)
		return;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- queue a transfer
	[[_connection transfers] download:file preview:YES];
}



- (IBAction)newFolder:(id)sender {
	[NSApp beginSheet:_newFolderPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newFolderSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (IBAction)reload:(id)sender {
	int		i, row;
	
	// --- get row number
	row	= [_filesTableView selectedRow];

	// --- save selection
	if(row >= 0) {
		i = [_filesTableView sortDescending]
			? [_shownFiles count] - (unsigned int) row - 1
			: (unsigned int) row;
		_selectPath = [[[_shownFiles objectAtIndex:i] path] retain];
	}
	
	// --- drop cache
	[[_connection cache] dropFilesForPath:[_path path]];
	
	// --- reload
	[self changeDirectory:_path];
}



- (IBAction)delete:(id)sender {
	NSString	*title, *description;
	WCFile		*file;
	int			i, row;
		
	// --- get row number
	row	= [_filesTableView selectedRow];

	if(row < 0 || ![[_connection account] deleteFiles])
		return;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];

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
					  NSLocalizedString(@"Cancel", @"Delete file button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  file,
					  description);
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
	[_filesTableView setHighlightedTableColumn:tableColumn];
	[_filesTableView reloadData];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSImage		*icon;
	NSString	*extension, *identifier;
	WCFile		*file;
	int			i;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	identifier = [tableColumn identifier];
	
	// --- populate columns
	if([identifier isEqualToString:@"Name"]) {
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



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(int)row {
	WCFile		*file;
	int			i;
	
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	return [file name];
}



- (NSString *)tableView:(NSTableView *)tableView toolTipForRow:(int)row {
	WCFile		*file;
	int			i;
	
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	return [file name];
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCFile		*file;
	int			i, row;
	
	// --- get row
	row = [[items objectAtIndex:0] intValue];
	
	if(row < 0)
		return NO;

	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- put path in pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObjects:
		WCFilePboardType, NSStringPboardType, NULL] owner:NULL];
	[pasteboard setData:[NSArchiver archivedDataWithRootObject:file] forType:WCFilePboardType];
	[pasteboard setString:[file path] forType:NSStringPboardType];

	return YES;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)proposedRow 
proposedDropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCFile			*destination;
	int				i;
	
	// --- get pasteboard
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
		
	// --- get destination
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) proposedRow - 1
		: (unsigned int) proposedRow;
	destination = i >= 0 && i < (int) [_shownFiles count]
		? [_shownFiles objectAtIndex:i]
		: _path;
	
	// --- check privilege for Finder drags
	if([types containsObject:NSFilenamesPboardType]) {
		if(![[_connection account] upload])
			return NSDragOperationNone;
		
		if([destination type] != WCFileTypeUploads && [destination type] != WCFileTypeDropBox) {
			if(![[_connection account] uploadAnywhere])
				return NSDragOperationNone;
		}
	}
	
	// --- turn drops between rows into drops to the window, if it's the last row
	if(operation == NSTableViewDropAbove) {
		if(destination == _path)
			[_filesTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
		else
			return NSDragOperationNone;
	}
	
	// --- turn drops on files into drops to the window
	if([destination type] == WCFileTypeFile)
		[_filesTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	
	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info 
row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCFile			*destination;
	int				i;
	BOOL			result = NO;

	// --- get pasteboard
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
		
	// --- get destination
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	destination = row >= 0 && row < (int) [_shownFiles count]
		? [_shownFiles objectAtIndex:i]
		: _path;
	[destination retain];
	
	if([types containsObject:WCFilePboardType]) {
		NSData			*data;
		WCFile			*source;
		
		// --- get file
		data	= [pasteboard dataForType:WCFilePboardType];
		source	= [NSUnarchiver unarchiveObjectWithData:data];

		if(![[[source path] stringByDeletingLastPathComponent] isEqualTo:[destination path]]) {
			// --- move file
			[_connection sendCommand:WCMoveCommand
						withArgument:[source path]
						withArgument:[[destination path] stringByAppendingPathComponent:[source name]]
						  withSender:self];
			
			// --- announce reloads on both this, the source and their parents
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[source path] stringByDeletingLastPathComponent],
					@"",
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[destination path],
					@"",
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[destination path] stringByDeletingLastPathComponent],
					@"",
					NULL]];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCFilesShouldReload
				object:[NSArray arrayWithObjects:
					_connection,
					[[[source path] stringByDeletingLastPathComponent] 
						stringByDeletingLastPathComponent],
					@"",
					NULL]];
			
			result = YES;
			goto end;
		}
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		NSEnumerator	*enumerator;
		NSArray			*files;
		NSString		*path;
		
		// --- get paths
		files = [pasteboard propertyListForType:NSFilenamesPboardType];
		enumerator = [files objectEnumerator];
		
		// --- reset enumerator
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
		
		// --- upload paths
		while((path = [enumerator nextObject]))
			[[_connection transfers] upload:path withDestination:destination];

		result = YES;
		goto end;
	}

end:
	[destination release];

	return result;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCFile			*file;
	int				i, row;
	
	// --- get row number
	row	= [_filesTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get file
	i = [_filesTableView sortDescending]
		? [_shownFiles count] - (unsigned int) row - 1
		: (unsigned int) row;
	file = [_shownFiles objectAtIndex:i];
	
	// --- put it on the pasteboard
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[file lastPathComponent] forType:NSStringPboardType];
}

@end
