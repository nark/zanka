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
#import "WCFilesBrowserCell.h"
#import "WCPreview.h"
#import "WCTransfers.h"

@interface WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath;

- (void)_setCurrentPath:(WCFile *)path;
- (WCFile *)_currentPath;

- (void)_updateMenu;
- (void)_updateFiles;
- (void)_showList;
- (void)_showBrowser;
- (void)_makeFirstResponder;
- (void)_setDirectory:(WCFile *)path;
- (void)_changeDirectory:(WCFile *)path;
- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override;

- (BOOL)_validateUpload;
- (BOOL)_validateCreateFolder;

@end


@implementation WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath {
	self = [super initWithWindowNibName:@"Files" connection:connection];

	_type			= [WCSettings intForKey:WCFilesStyle];
	_rootPath		= [path retain];
	_listPath		= [path retain];
	_browserPath	= [path retain];
	_selectPath		= [selectPath retain];

	_history		= [[NSMutableArray alloc] init];
	_allFiles		= [[NSMutableDictionary alloc] init];
	_browserFiles	= [[NSMutableDictionary alloc] init];
	
	[_history addObject:_listPath];
	
	[self window];
	[self windowTemplate];
	
	[self _changeDirectory:[self _currentPath]];
	
	[self validate];
	[self setReleasedWhenClosed:YES];
	[self showWindow:self];
	
	[[self connection] addObserver:self
						  selector:@selector(filesShouldReload:)
							  name:WCFilesShouldReload];
	
	[self retain];
	
	return self;
}



#pragma mark -

- (void)_setCurrentPath:(WCFile *)path {
	[path retain];
	
	if(_type == WCFilesStyleList) {
		[_listPath release];
		_listPath = path;
	}
	else if(_type == WCFilesStyleBrowser) {
		[_browserPath release];
		_browserPath = path;
	}
}



- (WCFile *)_currentPath {
	if(_type == WCFilesStyleList)
		return _listPath;
	else if(_type == WCFilesStyleBrowser)
		return _browserPath;
	
	return NULL;
}



#pragma mark -

- (void)_updateMenu {
	NSMutableArray	*components;
	NSString		*path;
	NSMenuItem		*item;
	int				i, count, items;

	components = [NSMutableArray array];
	path = [[self _currentPath] path];

	while([path length] > 0) {
		[components addObject:path];

		if([path isEqualToString:@"/"])
			break;

		path = [path stringByDeletingLastPathComponent];
	}

	count = [components count];
	items = [_titleBarMenu numberOfItems];

	for(i = 0; i < count; i++) {
		if(i < items) {
			if([[[_titleBarMenu itemAtIndex:i] title] isEqualToString:[components objectAtIndex:i]]) {
				continue;
			} else {
				[_titleBarMenu removeItemAtIndex:i];
				items--;
			}
		}

		item = [[NSMenuItem alloc] initWithTitle:[[components objectAtIndex:i] lastPathComponent]
										  action:@selector(openMenuItem:)
								   keyEquivalent:@""];
		[item setRepresentedObject:[components objectAtIndex:i]];
		[item setImage:[NSImage imageNamed:@"Folder16"]];

		[_titleBarMenu insertItem:item atIndex:i];
		items++;
		[item release];
	}

	while(items > count) {
		[_titleBarMenu removeItemAtIndex:count];

		items--;
	}
}



- (void)_updateFiles {
	[self updateStatus];
	[self sortFiles];

	[_filesTableView reloadData];
	[_filesBrowser reloadColumn:[_filesBrowser lastColumn]];
	[[_filesBrowser matrixInColumn:[_filesBrowser lastColumn]] setMenu:[_filesBrowser menu]];

	if(_selectPath) {
		[_filesTableView selectRowWithStringValue:[_selectPath lastPathComponent]];
		
		[_selectPath release];
		_selectPath = NULL;
	}
	
	[[self connection] addObserver:self
						  selector:@selector(filesShouldReload:)
							  name:WCFilesShouldReload];

	[_progressIndicator stopAnimation:self];
	
	[self _makeFirstResponder];
}



- (void)_showList {
	_type = WCFilesStyleList;

	[_filesTableView sizeToFit];
	[_filesTabView selectTabViewItemWithIdentifier:@"List"];
	
	[self _changeDirectory:_listPath];
	[self validate];

	[WCSettings setInt:_type forKey:WCFilesStyle];

	[self _makeFirstResponder];
}



- (void)_showBrowser {
	_type = WCFilesStyleBrowser;

	[_filesTabView selectTabViewItemWithIdentifier:@"Browser"];
	
	[self _changeDirectory:_browserPath];
	[self validate];

	[WCSettings setInt:_type forKey:WCFilesStyle];

	[self _makeFirstResponder];
}



- (void)_makeFirstResponder {
	int			column;
	
	switch(_type) {
		case WCFilesStyleList:
			[[self window] makeFirstResponder:_filesTableView];
			break;
			
		case WCFilesStyleBrowser:
			column = [_filesBrowser selectedColumn];
			
			if(column < 0)
				column = [_filesBrowser lastColumn];
				
			[[self window] makeFirstResponder:[_filesBrowser matrixInColumn:column]];
			break;
	}
}



- (void)_setDirectory:(WCFile *)path {
	[self _setCurrentPath:path];

	[self validate];
	[self updateStatus];

	[self _updateMenu];
	
	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];
}



- (void)_changeDirectory:(WCFile *)path {
	NSArray				*files;
	unsigned long long	free;
	
	[_allFiles removeAllObjects];
	[_files removeAllObjects];
	[_browserFiles removeObjectForKey:[path path]];
	
	[_filesTableView reloadData];
	[_filesBrowser reloadColumn:[_filesBrowser lastColumn]];
	
	[_statusTextField setStringValue:@""];
	[_progressIndicator startAnimation:self];

	[self _setDirectory:path];

	if((files = [[[self connection] cache] filesForPath:[path path] free:&free])) {
		[_files addObjectsFromArray:files];
		[_browserFiles setObject:[[files mutableCopy] autorelease] forKey:[path path]];
		
		[path setFree:free];
		
		[self _updateFiles];
	} else {
		[[self connection] addObserver:self
							  selector:@selector(filesReceivedFile:)
								  name:WCFilesReceivedFile];
		
		[[self connection] addObserver:self
							  selector:@selector(filesCompletedFiles:)
								  name:WCFilesCompletedFiles];
		
		[[self connection] sendCommand:WCListCommand withArgument:[path path]];
	}
}



- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override {
	BOOL	optionKey, newWindows;

	optionKey = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	newWindows = [WCSettings boolForKey:WCOpenFoldersInNewWindows];

	switch([file type]) {
		case WCFileDirectory:
		case WCFileUploads:
		case WCFileDropBox:
			if(override || (newWindows && !optionKey) || (!newWindows && optionKey)) {
				[WCFiles filesWithConnection:[self connection] path:file];
			} else {
				if(![[self _currentPath] isEqual:file]) {
					[_history removeObjectsInRange:
						NSMakeRange(_historyPosition + 1, [_history count] - _historyPosition - 1)];

					[_history addObject:file];
					_historyPosition = [_history count] - 1;
					
					[self _changeDirectory:file];
					[self validate];
				}
			}
			break;

		case WCFileFile:
			[[[self connection] transfers] downloadFile:file];
			break;
	}
}



#pragma mark -

- (BOOL)_validateUpload {
	WCAccount		*account;
	WCFileType		type;
	
	account = [[self connection] account];
	type = [[self _currentPath] type];

	return ([account uploadAnywhere] ||
		   ([account upload] && (type == WCFileUploads || type == WCFileDropBox)));
}



- (BOOL)_validateCreateFolder {
	WCAccount		*account;
	WCFileType		type;

	account = [[self connection] account];
	type = [[self _currentPath] type];

	return ([account createFolders] ||
			[account uploadAnywhere] ||
			([account upload] && (type == WCFileUploads || type == WCFileDropBox)));
}

@end


@implementation WCFiles

+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path {
	return [[[self alloc] _initFilesWithConnection:connection path:path selectPath:NULL] autorelease];
}



+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath {
	return [[[self alloc] _initFilesWithConnection:connection path:path selectPath:selectPath] autorelease];
}



- (void)dealloc {
	[_history release];
	[_allFiles release];
	[_browserFiles release];
	
	[_listPath release];
	[_browserPath release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_filesBrowser setCellClass:[WCFilesBrowserCell class]];
	[_filesBrowser setMatrixClass:[WIMatrix class]];

	[_filesBrowser setTarget:self];
	[_filesBrowser setAction:@selector(browserDidSingleClick:)];
	[_filesBrowser setDoubleAction:@selector(open:)];
	[_filesBrowser setColumnsAutosaveName:@"Files"];
	[_filesBrowser loadColumnZero];

	[_filesTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:WCFilePboardType, NSFilenamesPboardType, NULL]];

	[_filesTableView setDoubleAction:@selector(open:)];
	[_filesTableView setDeleteAction:@selector(deleteFiles:)];
	[_filesTableView setBackAction:@selector(back:)];
	[_filesTableView setForwardAction:@selector(forward:)];
	
	[_titleBarMenu removeAllItems];

	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Files"];

	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];

	if(_type == WCFilesStyleList) 
		[self _showList];
	else if(_type == WCFilesStyleBrowser) 
		[self _showBrowser];
	
	[_styleMatrix selectCellWithTag:_type];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_filesTableView setDataSource:NULL];
}



- (NSMenu *)windowTitleBarMenu:(WIWindow *)window {
	return _titleBarMenu;
}



- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)defaultFrame {
	NSRect		frame;
	
	frame = [[self window] frame];
	frame.origin.y = defaultFrame.origin.y;
	frame.size.height = defaultFrame.size.height;
	
	return frame;
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[_filesTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCFilesTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[_filesTableView propertiesDictionary] forKey:@"WCFilesTableView"];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[self close];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self validate];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];
}



- (void)filesReceivedFile:(NSNotification *)notification {
	WCFile		*file;

	file = [WCFile fileWithListArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if(![[[file path] stringByDeletingLastPathComponent] isEqualToString:[[self _currentPath] path]])
		return;

	if(![_allFiles objectForKey:[file name]])
		[_allFiles setObject:file forKey:[file name]];
}



- (void)filesCompletedFiles:(NSNotification *)notification {
	NSString	*path, *free;
	NSArray		*fields;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	path	= [fields safeObjectAtIndex:0];
	free	= [fields safeObjectAtIndex:1];

	if(![path isEqualToString:[[self _currentPath] path]])
		return;

	[[self _currentPath] setFree:[free unsignedLongLongValue]];

	[_files setArray:[_allFiles allValues]];
	
	[_browserFiles setObject:[[[_allFiles allValues] mutableCopy] autorelease]
					  forKey:path];

	[[[self connection] cache] setFiles:[[[_allFiles allValues] mutableCopy] autorelease]
								   free:[[self _currentPath] free]
								forPath:[[self _currentPath] path]];
	
	[self _updateFiles];

	[[self connection] removeObserver:self name:WCFilesReceivedFile];
	[[self connection] removeObserver:self name:WCFilesCompletedFiles];
}



- (void)filesShouldReload:(NSNotification *)notification {
	NSString	*path, *selectPath;

	path = [[notification userInfo] objectForKey:WCFilePathKey];
	selectPath = [[notification userInfo] objectForKey:WCFileSelectPathKey];

	if([path isEqualToString:[[self _currentPath] path]]) {
		_selectPath = [selectPath retain];

		[[[self connection] cache] removeFilesForPath:[[self _currentPath] path]];
		
		[self _changeDirectory:[self _currentPath]];
		[self validate];

		[[self connection] removeObserver:self name:WCFilesShouldReload];
	}
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSControl		*control;
	
	control = [notification object];
	
	if(control == _createFolderTextField) {
		[_createFolderPopUpButton selectItemWithTag:
			[WCFile folderTypeForString:[_createFolderTextField stringValue]]];
	}
}



#pragma mark -

- (WCFile *)selectedFile {
	if(_type == WCFilesStyleList)
		return [super selectedFile];
	else if(_type == WCFilesStyleBrowser)
		return [[_filesBrowser selectedCell] representedObject];
	
	return NULL;
}



- (NSArray *)selectedFiles {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	id					cell;

	if(_type == WCFilesStyleList) {
		return [super selectedFiles];
	}
	else if(_type == WCFilesStyleBrowser) {
		array = [NSMutableArray array];
		enumerator = [[_filesBrowser selectedCells] objectEnumerator];
		
		while((cell = [enumerator nextObject]))
			[array addObject:[cell representedObject]];
		
		return array;
	}
	
	return NULL;
}


- (NSArray *)shownFiles {
	if(_type == WCFilesStyleList)
		return [super shownFiles];
	else if(_type == WCFilesStyleBrowser)
		return [_browserFiles objectForKey:[[self _currentPath] path]];
	
	return NULL;
}



- (void)sortFiles {
	[super sortFiles];
	
	[[_browserFiles objectForKey:[[self _currentPath] path]] sortUsingSelector:@selector(compareName:)];
}



#pragma mark -

- (void)update {
	[_filesBrowser setNeedsDisplay:YES];
	
	[super update];
}



- (void)updateStatus {
	if([self _validateUpload])
		[super updateStatusWithFree:[[self _currentPath] free]];
	else
		[super updateStatus];
}



- (void)validate {
	NSArray			*files;
	WCAccount		*account;
	WCFile			*file;
	BOOL			connected;
	
	connected	= [[self connection] isConnected];
	account		= [[self connection] account];
	files		= [self selectedFiles];

	switch([files count]) {
		case 0:
			[_downloadButton setEnabled:NO];
			[_previewButton setEnabled:NO];
			[_infoButton setEnabled:NO];
			[_deleteButton setEnabled:NO];
			break;

		case 1:
			file = [files objectAtIndex:0];

			[_downloadButton setEnabled:([account download] && connected)];
			[_deleteButton setEnabled:([account deleteFiles] && connected)];
			[_infoButton setEnabled:connected];

			if([account download] && ![file isFolder])
				[_previewButton setEnabled:([WCPreview canInitWithExtension:[file extension]] && connected)];
			else
				[_previewButton setEnabled:NO];
			break;

		default:
			[_downloadButton setEnabled:([account download] && connected)];
			[_previewButton setEnabled:NO];
			[_deleteButton setEnabled:([account deleteFiles] && connected)];
			[_infoButton setEnabled:connected];
			break;
	}

	[_backButton setEnabled:(_type == WCFilesStyleList && _historyPosition > 0 && connected)];
	[_forwardButton setEnabled:(_type == WCFilesStyleList && _historyPosition + 1 < [_history count] && connected)];
	[_uploadButton setEnabled:([self _validateUpload] && connected)];
	[_createFolderButton setEnabled:([self _validateCreateFolder] && connected)];
	[_reloadButton setEnabled:connected];
	
	[super validate];
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	BOOL	connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(newFolder:))
		return ([self _validateCreateFolder] && connected);
	else if(selector == @selector(deleteFiles:))
		return ([[[self connection] account] deleteFiles] && connected);

	return [super validateMenuItem:item];
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	NSArray			*files;
	WCFile			*file;
	
	if(![[self connection] isConnected])
		return;

	files = [self selectedFiles];
	enumerator = [files objectEnumerator];

	while((file = [enumerator nextObject]))
		[self _openFile:file overrideNewWindow:(_type == WCFilesStyleBrowser || [files count]> 1)];
}



- (IBAction)openMenuItem:(id)sender {
	if(![[self connection] isConnected])
		return;

	[self _openFile:[WCFile fileWithDirectory:[sender representedObject]] overrideNewWindow:NO];
}



- (IBAction)up:(id)sender {
	if([[[self _currentPath] path] isEqualToString:@"/"])
		return;

	[self _openFile:[WCFile fileWithDirectory:[[[self _currentPath] path] stringByDeletingLastPathComponent]] overrideNewWindow:NO];
}



- (IBAction)down:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;
	int				count;

	count = [_filesTableView numberOfSelectedRows];
	enumerator = [[self selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[self _openFile:file overrideNewWindow:(count > 1)];
}



- (IBAction)back:(id)sender {
	if([_backButton isEnabled]) {
		_selectPath = [[[self _currentPath] path] retain];

		[self _changeDirectory:[_history objectAtIndex:--_historyPosition]];
		[self validate];
	}
}



- (IBAction)list:(id)sender {
	[self _showList];
}



- (IBAction)browser:(id)sender {
	[self _showBrowser];
}



- (IBAction)forward:(id)sender {
	if([_forwardButton isEnabled]) {
		[self _changeDirectory:[_history objectAtIndex:++_historyPosition]];
		[self validate];
	}
}



- (IBAction)upload:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];

	[openPanel setCanChooseDirectories:[self _validateCreateFolder]];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];

	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(uploadOpenPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)uploadOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSEnumerator	*enumerator;
	NSArray			*files;
	NSString		*path;

	if(returnCode == NSOKButton) {
		files = [openPanel filenames];
		enumerator = [files objectEnumerator];
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];

		while((path = [enumerator nextObject]))
			[[[self connection] transfers] uploadPath:path toFolder:[self _currentPath]];
	}
}



- (IBAction)preview:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[self selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[[[self connection] transfers] previewFile:file];
}



- (IBAction)createFolder:(id)sender {
	NSEnumerator		*enumerator;
	NSMenuItem			*item;
	
	if(![[_createFolderPopUpButton lastItem] image]) {
		enumerator = [[_createFolderPopUpButton itemArray] objectEnumerator];
		
		while((item = [enumerator nextObject]))
			[item setImage:[WCFile iconForFolderType:[item tag] width:16.0]];
	}
	
	[_createFolderTextField setStringValue:NSLS(@"Untitled", @"New folder name")];
	[_createFolderTextField selectText:self];
	[_createFolderPopUpButton selectItemWithTag:WCFileDirectory];
	
	[NSApp beginSheet:_createFolderPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(createFolderSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)createFolderSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSString		*path;
	NSDictionary	*dictionary;
	WCFileType		type;

	[_createFolderPanel close];

	if(returnCode == NSRunStoppedResponse) {
		path = [[[self _currentPath] path] stringByAppendingPathComponent:[_createFolderTextField stringValue]];
		
		[[self connection] sendCommand:WCFolderCommand withArgument:path];
		
		type = [_createFolderPopUpButton tagOfSelectedItem];
		
		if(type != WCFileDirectory) {
			[[self connection] sendCommand:WCTypeCommand
							  withArgument:path
							  withArgument:[NSSWF:@"%u", type]];
		}

		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			[[self _currentPath] path],	WCFilePathKey,
			path,						WCFileSelectPathKey,
			NULL];

		[[self connection] postNotificationName:WCFilesShouldReload
										 object:[self connection]
									   userInfo:dictionary];
	}
}



- (IBAction)reloadFiles:(id)sender {
	_selectPath = [[[self selectedFile] path] retain];

	[[[self connection] cache] removeFilesForPath:[[self _currentPath] path]];

	[self _changeDirectory:[self _currentPath]];
	[self validate];
}



- (IBAction)deleteFiles:(id)sender {
	NSString	*title;
	int			count;

	if(![[self connection] isConnected])
		return;

	count = [[self selectedFiles] count];

	if(count == 0)
		return;

	if(count == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete file dialog title (filename)"),
			[[self selectedFile] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %u items?", @"Delete file dialog title (count)"),
			count];
	}

	NSBeginAlertSheet(title,
					  NSLS(@"Delete", @"Delete file button title"),
					  NSLS(@"Cancel", @"Delete file button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete file dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	NSDictionary	*dictionary;
	WCFile			*file;
	NSString		*path;

	if(returnCode == NSAlertDefaultReturn) {
		enumerator = [[self selectedFiles] objectEnumerator];

		while((file = [enumerator nextObject]))
			[[self connection] sendCommand:WCDeleteCommand withArgument:[file path]];

		if(_type == WCFilesStyleBrowser) {
			path = [[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser path]] stringByDeletingLastPathComponent];
			
			[self _setDirectory:[WCFile fileWithDirectory:path]];
			
			[_filesBrowser setPath:path];
		}
		
		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			[[self _currentPath] path],		WCFilePathKey,
			NULL];

		[[self connection] postNotificationName:WCFilesShouldReload
										 object:[self connection]
									   userInfo:dictionary];
	}
}



#pragma mark -

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)proposedRow proposedDropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCFile			*file, *path, *destination;

	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];

	file = (proposedRow >= 0) ? [self fileAtIndex:proposedRow] : NULL;
	path = [self _currentPath];
	destination = file ? file : path;
	
	if([types containsObject:NSFilenamesPboardType]) {
		if(![[[self connection] account] upload])
			return NSDragOperationNone;

		if((file && [file isFolder] && ![file isUploadsFolder]) || (!file && ![path isUploadsFolder])) {
			if(![[[self connection] account] uploadAnywhere])
				return NSDragOperationNone;
		}
		
		if(file && [file isUploadsFolder] && operation == NSTableViewDropAbove) {
			if(![path isUploadsFolder]) {
				if(![[[self connection] account] uploadAnywhere])
					return NSDragOperationNone;
			}
		}
	}
	else if([types containsObject:WCFilePboardType]) {
		if(![[[self connection] account] alterFiles])
			return NSDragOperationNone;
	}

	if([destination type] == WCFileFile || operation == NSTableViewDropAbove)
		[_filesTableView setDropRow:-1 dropOperation:NSTableViewDropOn];

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSDictionary	*dictionary;
	NSArray			*types;
	WCFile			*destination;
	BOOL			result = NO;

	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];

	destination = row >= 0
		? [self fileAtIndex:row]
		: [self _currentPath];
	[destination retain];

	if([types containsObject:WCFilePboardType]) {
		NSEnumerator	*enumerator;
		NSArray			*sources;
		WCFile			*source;
		BOOL			reload = NO;

		sources = [NSUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
		enumerator = [sources objectEnumerator];
		
		while((source = [enumerator nextObject])) {
			if(![[[source path] stringByDeletingLastPathComponent] isEqualTo:[destination path]]) {
				[[self connection] sendCommand:WCMoveCommand
								  withArgument:[source path]
								  withArgument:[[destination path] stringByAppendingPathComponent:[source name]]];
				
				reload = YES;
			}
		}

		if(reload) {
			dictionary = [NSDictionary dictionaryWithObject:[[[sources objectAtIndex:0] path] stringByDeletingLastPathComponent]
													 forKey:WCFilePathKey];
			
			[[self connection] postNotificationName:WCFilesShouldReload
											 object:[self connection]
										   userInfo:dictionary];

			dictionary = [NSDictionary dictionaryWithObject:[destination path]
													 forKey:WCFilePathKey];
			
			[[self connection] postNotificationName:WCFilesShouldReload
											 object:[self connection]
										   userInfo:dictionary];
			
			result = YES;
		}
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		NSEnumerator	*enumerator;
		NSArray			*files;
		NSString		*path;

		files = [pasteboard propertyListForType:NSFilenamesPboardType];
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];

		while((path = [enumerator nextObject]))
			[[[self connection] transfers] uploadPath:path toFolder:destination];

		result = YES;
	}

	[destination release];

	return result;
}



#pragma mark -

- (int)browser:(NSBrowser *)browser numberOfRowsInColumn:(int)column {
	return [[_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]] count];
}



- (void)browser:(NSBrowser *)browser willDisplayCell:(id)cell atRow:(int)row column:(int)column {
	WCFile		*file;
	
	file = [[_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]] objectAtIndex:row];
	[cell setLeaf:![file isFolder]];
	[cell setStringValue:[file name]];
	[cell setImage:[file iconWithWidth:16.0]];
	[cell setRepresentedObject:file];
	[cell setFont:[WCSettings objectForKey:WCFilesFont]];
}



- (void)browserDidSingleClick:(id)sender {
	WCFile		*file;
	
	if(![[self connection] isConnected])
		return;

	[self validate];
	
	file = [[_filesBrowser selectedCell] representedObject];

	if(![file isFolder]) {
		file = [WCFile fileWithPath:[[file path] stringByDeletingLastPathComponent] type:[file type]];
		
		if(![[file path] isEqualToString:[[self _currentPath] path]]) {
			[self _setDirectory:file];
			[self updateStatus];
		}
	} else {
		if(![[file path] isEqualToString:[[self _currentPath] path]])
			[self _changeDirectory:file];
	}
}

@end
