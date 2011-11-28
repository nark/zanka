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

#import "FHBrowserController.h"
#import "FHCache.h"
#import "FHFile.h"
#import "FHFileCell.h"
#import "FHHandler.h"
#import "FHImage.h"
#import "FHImageLoader.h"
#import "FHImageView.h"
#import "FHInspectorController.h"
#import "FHPreferencesController.h"
#import "FHSettings.h"
#import "FHSlideshowController.h"
#import "FHSpread.h"

@interface FHBrowserController(Private)

- (NSToolbar *)_toolbar;
- (void)_resizeTableView;
- (void)_reloadScreens;
- (void)_updateScalingModeToolbarItems;
- (void)_toggleStatusBar:(BOOL)show;

- (void)_loadURL:(WIURL *)url;
- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row;
- (void)_loadURL:(WIURL *)url selectName:(NSString *)name;
- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row name:(NSString *)name;

- (void)_reload;
- (void)_updateLeftStatus;
- (void)_updateRightStatus;

- (NSString *)_nameOfRootVolume;

@end


@implementation FHBrowserController(Private)

- (NSToolbar *)_toolbar {
	NSToolbar		*toolbar;
	NSToolbarItem	*item;

	_toolbarItems = [[NSMutableDictionary alloc] init];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"Parent"
											   name:NSLS(@"Parent", @"Parent toolbar item")
											content:[NSImage imageNamed:@"Parent"]
											 target:self
											 action:@selector(openParent:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"Reload"
											   name:NSLS(@"Reload", @"Reload toolbar item")
											content:[NSImage imageNamed:@"Reload"]
											 target:self
											 action:@selector(reload:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"ActualSize"
											   name:NSLS(@"Actual Size", @"Actual size toolbar item")
											content:[NSImage imageNamed:@"ActualSize"]
											 target:self
											 action:@selector(scalingMode:)];
	[item setTag:FHScaleNone];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"ScaleToFit"
											   name:NSLS(@"Scale To Fit", @"Scale to fit toolbar item")
											content:[NSImage imageNamed:@"ScaleToFit"]
											 target:self
											 action:@selector(scalingMode:)];
	[item setTag:FHScaleProportionally];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"StretchToFit"
											   name:NSLS(@"Stretch To Fit", @"Stretch to fit toolbar item")
											content:[NSImage imageNamed:@"StretchToFit"]
											 target:self
											 action:@selector(scalingMode:)];
	[item setTag:FHScaleStretchedProportionally];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"RotateLeft"
											   name:NSLS(@"Rotate Left", @"Rotate left toolbar item")
											content:[NSImage imageNamed:@"RotateLeft"]
											 target:self
											 action:@selector(rotateLeft:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"RotateRight"
											   name:NSLS(@"Rotate Right", @"Rotate right toolbar item")
											content:[NSImage imageNamed:@"RotateRight"]
											 target:self
											 action:@selector(rotateRight:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"RevealInFinder"
											   name:NSLS(@"Reveal In Finder", @"Reveal in Finder toolbar item")
											content:[NSImage imageNamed:@"RevealInFinder"]
											 target:self
											 action:@selector(revealInFinder:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"MoveToTrash"
											   name:NSLS(@"Move To Trash", @"Move to trash toolbar item")
											content:[NSImage imageNamed:@"MoveToTrash"]
											 target:self
											 action:@selector(moveToTrash:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"Slideshow"
											   name:NSLS(@"Slideshow", @"Slideshow toolbar item")
											content:[NSImage imageNamed:@"Slideshow"]
											 target:self
											 action:@selector(slideshow:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];
	
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Inspector"
											   name:NSLS(@"Inspector", @"Inspector toolbar item")
											content:[NSImage imageNamed:@"Inspector"]
											 target:self
											 action:@selector(inspector:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Footagehead"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];

	return [toolbar autorelease];
}



- (void)_resizeTableView {
	NSSize		size;
	
	size = [_tableView rectOfColumn:0].size;
	size.width += 34.0;
	[_tableView setRowHeight:size.width];
	[_tableView sizeToFitFromContent];
}



- (void)_reloadScreens {
	NSArray			*screens;
	NSRect			frame;
	NSUInteger		i, index, count;
	
	index = [_screenPopUpButton indexOfSelectedItem];
	
	[_screenPopUpButton removeAllItems];
	
	screens = [NSScreen screens];
	count = [screens count];
	
	for(i = 0; i < count; i++) {
		frame = [[screens objectAtIndex:i] frame];
		
		[_screenPopUpButton addItemWithTitle:[NSSWF:NSLS(@"Screen %u, %.0fx%.0f", @"'Screen 1, 1024x768'"),
			i + 1,
			frame.size.width,
			frame.size.height]];
	}
	
	if(index != NSNotFound && index < count)
		[_screenPopUpButton selectItemAtIndex:index];
}



- (void)_updatePreferences {
	[_imageView setBackgroundColor:WIColorFromString([FHSettings objectForKey:FHBackgroundColor])];
}



- (void)_updateScalingModeToolbarItems {
	switch([_imageView imageScaling]) {
		case FHScaleNone:
			[[[self window] toolbar] setSelectedItemIdentifier:@"ActualSize"];
			break;
			
		case FHScaleProportionally:
			[[[self window] toolbar] setSelectedItemIdentifier:@"ScaleToFit"];
			break;
			
		case FHScaleStretchedProportionally:
			[[[self window] toolbar] setSelectedItemIdentifier:@"StretchToFit"];
			break;
		
		default:
			[[[self window] toolbar] setSelectedItemIdentifier:NULL];
			break;
	}
}



- (void)_toggleStatusBar:(BOOL)show {
	NSRect		frame;
	CGFloat		height;
	
	frame		= [_contentBox frame];
	height		= [_statusBox frame].size.height;

	if(show) {
		frame.origin.y		+= height;
		frame.size.height	-= height;
	} else {
		frame.origin.y		-= height;
		frame.size.height	+= height;
	}
	
	[_statusBox setHidden:!show];
	[_contentBox setFrame:frame];
	
	[[self window] display];
}



#pragma mark -

- (void)_loadURL:(WIURL *)url {
	[self _loadURL:url selectRow:0 name:NULL];
}



- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row {
	[self _loadURL:url selectRow:row name:NULL];
}



- (void)_loadURL:(WIURL *)url selectName:(NSString *)name {
	[self _loadURL:url selectRow:0 name:name];
}



- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row name:(NSString *)name {
	NSArray			*files;
	FHHandler		*handler;
	FHFile			*file;
	NSUInteger		i, count;
	NSInteger		selectedRow;
	
	_switchingURL = YES;
	
	[_directoryProgressIndicator setHidden:NO];
	[_directoryProgressIndicator startAnimation:self];
	
	handler = [[FHHandler alloc] initHandlerWithURL:url];
	
	if(!handler)
		return;

	if(_handler) {
		if([[_handler URL] isFileURL])
			[[WIEventQueue sharedQueue] removePath:[[_handler URL] path]];
		
		[_handler release];
	}
	
	_handler = handler;
	[_handler setDelegate:self];
	files = [_handler files];
	[_imageLoader setFiles:files];
	
	if([[_handler URL] isFileURL] && [[[_handler URL] path] length] > 0)
		[[WIEventQueue sharedQueue] addPath:[[_handler URL] path] forMode:WIEventFileWrite];
	
	[[self window] setTitle:[NSApp name] withSubtitle:[[_handler stringComponents] lastObject]];
	
	[self updateSpreads];
	
	[self _updateLeftStatus];
	
	[[NSNotificationCenter defaultCenter]
		postNotificationName:FHBrowserControllerDidLoadHandler
		object:_handler];
	
	if(name) {
		for(i = 0, count = [files count]; i < count; i++) {
			if([[[files objectAtIndex:i] name] isEqualToString:name]) {
				row = i;
				
				break;
			}
		}
	}
	
	selectedRow = [_tableView selectedRow];

	[_tableView reloadData];
	
	[_directoryProgressIndicator stopAnimation:self];
	[_directoryProgressIndicator setHidden:YES];

	if(row != selectedRow) {
		[_tableView selectRow:row byExtendingSelection:NO];
	}
	else if(row >= 0) {
		file = [self selectedFile];
	
		[self startLoadingImageForFile:file atIndex:row];
		[self showFile:file];
	}

	[_tableView scrollRowToVisible:row];

	if([_handler isLocal])
		[_imageLoader startLoadingThumbnails];
	
	if(![url isFileURL])
		[_openURLTextView setString:[url humanReadableString]];

	_switchingURL = NO;
}



#pragma mark -

- (void)_reload {
	NSString	*name;
	WIURL		*url;
	NSInteger	row;
	
	url = [[_handler URL] retain];
	name = [[[self selectedFile] name] retain];
	row = [_tableView selectedRow];

	[[FHCache cache] dropThumbnailsForURL:url];

	[self _loadURL:url selectRow:row name:name];
	
	[url release];
	[name release];
}



- (void)_updateLeftStatus {
	[_leftStatusTextField setStringValue:[NSSWF:NSLS(@"%u %@, %u %@", @"'20 items, 10 images'"),
		[_handler numberOfFiles],
		[_handler numberOfFiles] == 1
			? NSLS(@"item", @"'item' singular")
			: NSLS(@"items", @"'item' plural"),
		[_handler numberOfImages],
		[_handler numberOfImages] == 1
			? NSLS(@"image", @"'image' singular")
			: NSLS(@"images", @"'image' plural")]];
}



- (void)_updateRightStatus {
	NSMutableString		*string;
	NSString			*name;
	FHSpread			*spread;
	FHFile				*leftFile, *rightFile;
	NSSize				imageSize;
	CGFloat				zoom;
	
	imageSize = [_imageView imageSize];
	
	if(imageSize.width < 1.0 || imageSize.height <= 1.0) {
		[_rightStatusTextField setStringValue:@""];
		
		return;
	}
	
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone) {
		name = [[self selectedFile] name];
	} else {
		spread		= [self selectedSpread];
		leftFile	= [spread leftFile];
		rightFile	= [spread rightFile];
		
		if([leftFile isDirectory] || [[_handler class] handlesURLAsDirectory:[leftFile URL]])
			leftFile = nil;

		if([rightFile isDirectory] || [[_handler class] handlesURLAsDirectory:[rightFile URL]])
			rightFile = nil;
		
		if(leftFile && rightFile) {
			name = [NSSWF:NSLS(@"%@ & %@", @"'image1.jpg' & 'image2.jpg'"),
				[leftFile name], [rightFile name]];
		} else {
			name = leftFile ? [leftFile name] : [rightFile name];
		}
	}
	
	zoom = [_imageView zoom];
	
	string = [[name mutableCopy] autorelease];
	[string appendString:@", "];
	[string appendFormat:NSLS(@"%.0fx%.0f", @"'640x480'"),
		imageSize.width,
		imageSize.height];

	if(zoom != 100.0) {
		[string appendString:@", "];
		[string appendFormat:NSLS(@"scaled to %.0f%%", @"'scaled to 50%'"),
			zoom];
	}

	if([_imageView imageRotation] != 0.0) {
		[string appendString:@", "];
		[string appendFormat:NSLS(@"rotated by %.0f\u00b0", @"'rotated by 90deg'"),
			WIAbs([_imageView imageRotation])];
	}
	
	[_rightStatusTextField setStringValue:string];
}



#pragma mark -

- (NSString *)_nameOfRootVolume {
	NSFileManager	*fileManager;
	NSEnumerator	*enumerator;
	NSString		*volume, *path;
	
	fileManager = [NSFileManager defaultManager];
	enumerator = [[fileManager directoryContentsAtPath:@"/Volumes/"] objectEnumerator];
	
	while((volume = [enumerator nextObject])) {
		path = [fileManager pathContentOfSymbolicLinkAtPath:[NSSWF:@"/Volumes/%@", volume]];
		
		if([path isEqualToString:@"/"])
			return volume;
	}
	
	return @"/";
}

@end



@implementation FHBrowserController

- (id)init {
	FHImageLoader	*imageLoader;
	
	self = [super initWithWindowNibName:@"Browser"];
	
	imageLoader = [[FHImageLoader alloc] init];
	[self setImageLoader:imageLoader];

	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderWillLoadFile:)
			   name:FHImageLoaderWillLoadFile];
	
	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderReceivedFileData:)
			   name:FHImageLoaderReceivedFileData];

	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderDidLoadThumbnail:)
			   name:FHImageLoaderDidLoadThumbnail];
	
	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderDidLoadFile:)
			   name:FHImageLoaderDidLoadFile];
	
	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderDidLoadAllFiles:)
			   name:FHImageLoaderDidLoadAllFiles];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:FHPreferencesDidChangeNotification];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidChangeMounts:)
			   name:NSWorkspaceDidMountNotification];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidChangeMounts:)
			   name:NSWorkspaceDidUnmountNotification];
	
	[imageLoader release];

	[self window];
	
	return self;
}



- (void)dealloc {
	[_handler release];
	
	[_imageLoader stopLoadingImagesAndThumbnails];
	[_imageLoader stopLoadingData];
	
	[_toolbarItems release];

	[_savedPath release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	FHFileCell		*cell;
	
	[[self window] setToolbar:[self _toolbar]];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Footagehead"];

	[[self window] registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	
	cell = [[FHFileCell alloc] init];
	[cell setAlignment:NSCenterTextAlignment];
	[cell setFont:[NSFont systemFontOfSize:9.0]];
	[_fileTableColumn setDataCell:cell];
	[cell release];
	
	[_tableView setTarget:self];
	[_tableView setDoubleAction:@selector(openFile:)];
	[_tableView setForwardAction:@selector(openDirectory:)];
	[_tableView setBackAction:@selector(openParent:)];
	[_tableView setDeleteAction:@selector(openParent:)];
	[_tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	
	[_splitView setAutosaveName:@"Browser"];
	
	[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	[_imageView setImageRotation:[FHSettings floatForKey:FHImageRotation]];
	
	[self _updatePreferences];
	[self _updateScalingModeToolbarItems];

	if(![FHSettings boolForKey:FHShowStatusBar])
		[self _toggleStatusBar:NO];

	[self _resizeTableView];
	
	[_openURLPopUpButton selectItemWithTag:[FHSettings intForKey:FHHTMLImageType]];

	[self _reloadScreens];
	
	if([FHSettings intForKey:FHFullscreenScreen] < [_screenPopUpButton numberOfItems])
		[_screenPopUpButton selectItemAtIndex:[FHSettings intForKey:FHFullscreenScreen]];

	[_screenBackgroundBlackMenuItem setTag:FHFullscreenBackgroundBlack];
	[_screenBackgroundBlackMenuItem setImage:[NSImage imageNamed:@"Black"]];
	[_screenBackgroundGrayMenuItem setTag:FHFullscreenBackgroundGray];
	[_screenBackgroundGrayMenuItem setImage:[NSImage imageNamed:@"Gray"]];
	[_screenBackgroundWhiteMenuItem setTag:FHFullscreenBackgroundWhite];
	[_screenBackgroundWhiteMenuItem setImage:[NSImage imageNamed:@"White"]];
	
	[_screenBackgroundPopUpButton selectItemWithTag:[FHSettings intForKey:FHFullscreenBackground]];
	
	[_screenAutoSwitchButton setState:[FHSettings boolForKey:FHFullscreenAutoSwitch]];
	[_screenAutoSwitchTextField setEnabled:[FHSettings boolForKey:FHFullscreenAutoSwitch]];
	[_screenAutoSwitchTextField setIntValue:[FHSettings intForKey:FHFullscreenAutoSwitchTime]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationDidChangeScreenParameters:)
			   name:NSApplicationDidChangeScreenParametersNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(tableViewFrameDidChange:)
			   name:NSViewFrameDidChangeNotification
			 object:_tableView];

	[[[WIEventQueue sharedQueue] notificationCenter]
		addObserver:self
		   selector:@selector(eventFileWrite:)
			   name:WIEventFileWriteNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedScalingMode:)
			   name:FHWindowControllerChangedScalingMode];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedSpreadMode:)
			   name:FHWindowControllerChangedSpreadMode];
}



- (void)windowDidResize:(NSNotification *)notification {
	[self _updateRightStatus];
}



- (void)windowControllerChangedScalingMode:(NSNotification *)notification {
	if([notification object] == _imageView) {
		[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	
		[self _updateScalingModeToolbarItems];

		[self _updateRightStatus];
	}
}



- (void)windowControllerChangedSpreadMode:(NSNotification *)notification {
	if([notification object] != _imageView) {
		[self updateSpreads];
	
		[self showFile:[self selectedFile]];
	}
}



- (void)applicationDidChangeScreenParameters:(NSNotification *)notification {
	[self _reloadScreens];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[_handler release];
	_handler = NULL;
}



- (void)workspaceDidChangeMounts:(NSNotification *)notification {
	WIURL	*url;
	
	url = [_handler URL];
	
	if([url isFileURL] && [[url path] isEqualToString:@""])
		[self _reload];
}



- (void)eventFileWrite:(NSNotification *)notification {
	if(_deletingFile)
		_deletingFile = NO;
	else
		[self _reload];
}



- (void)handlerDidAddFiles:(FHHandler *)handler {
	[_tableView reloadData];

	[self _updateLeftStatus];
	
	[_imageLoader startLoadingImages];
	
	if([_handler isLocal])
		[_imageLoader startLoadingThumbnails];
}



- (void)handlerDidFinishLoading:(FHHandler *)handler {
}



- (void)imageLoaderWillLoadFile:(NSNotification *)notification {
	FHFile	*file;
	
	file = [notification object];
	
	_savedFiles++;
	
	[_saveProgressIndicator setIndeterminate:YES];
	[_saveProgressTextField setStringValue:[NSSWF:NSLS(@"%@, %u/%u%C", @"Save status (name, this file, remaining files, '...')"),
		[file name], _savedFiles, [_handler numberOfFiles], 0x2026]];
}



- (void)imageLoaderReceivedFileData:(NSNotification *)notification {
	FHFile	*file;
	
	file = [notification object];
	
	[_saveProgressIndicator setIndeterminate:NO];
	[_saveProgressIndicator setDoubleValue:[file percentReceived]];
	[_saveProgressIndicator animate:self];
}



- (void)imageLoaderDidLoadThumbnail:(NSNotification *)notification {
	[_tableView reloadData];
}



- (void)imageLoaderDidLoadFile:(NSNotification *)notification {
	NSAlert			*alert;
	NSString		*path;
	FHFile			*file;
	int				result;
	BOOL			write = YES;
	
	file = [notification object];
	path = [_savedPath stringByAppendingPathComponent:[[file path] lastPathComponent]];
	
	if(!_overwriteAllExisting && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
		alert = [NSAlert alertWithMessageText:NSLS(@"File Exists", @"File exists dialog title")
								defaultButton:NSLS(@"Cancel", @"File exists dialog button title")
							  alternateButton:NSLS(@"Overwrite All", @"File exists dialog button title")
								  otherButton:NSLS(@"Overwrite", @"File exists dialog button title")
					informativeTextWithFormat:NSLS(@"The file \u201c%@\u201d already exists. Overwrite?", @"File exists dialog description"), [file name]];
		
		result = [alert runModal];
		
		if(result == NSAlertDefaultReturn)
			write = NO;
		else if(result == NSAlertAlternateReturn)
			_overwriteAllExisting = YES;
	}
	
	if(write)
		[[file data] writeToFile:path atomically:YES];
		
	[file setData:NULL];
}



- (void)imageLoaderDidLoadAllFiles:(NSNotification *)notification {
	[NSApp endSheet:_saveProgressPanel returnCode:NSAlertDefaultReturn];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _updatePreferences];
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	if(selector == @selector(insertNewline:)) {
		[self submitSheet:textView];

		return YES;
	}
	else if(selector == @selector(cancelOperation:)) {
		[self cancelSheet:textView];

		return YES;
	}

	return NO;
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	return [_toolbarItems objectForKey:identifier];
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Parent",
		@"Reload",
		NSToolbarSeparatorItemIdentifier,
		@"ActualSize",
		@"ScaleToFit",
		@"StretchToFit",
		NSToolbarSeparatorItemIdentifier,
		@"RotateLeft",
		@"RotateRight",
		NSToolbarSeparatorItemIdentifier,
		@"Slideshow",
		@"Inspector",
		@"RevealInFinder",
		@"MoveToTrash",
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Parent",
		@"Reload",
		@"ActualSize",
		@"ScaleToFit",
		@"StretchToFit",
		@"RotateLeft",
		@"RotateRight",
		@"Slideshow",
		@"Inspector",
		@"RevealInFinder",
		@"MoveToTrash",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"ActualSize",
		@"ScaleToFit",
		@"StretchToFit",
		NULL];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	return 32.0 + 17.0;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	return 128.0 + 17.0;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)offset {
	CGFloat		position;

	if([[NSApp currentEvent] alternateKeyModifier]) {
		position = proposedPosition - 17.0;
		
		if(position >= 128.0)
			position = 128.0;
		else if(position >= 64.0)
			position = 64.0;
		else if(position >= 48.0)
			position = 48.0;
		else
			position = 32.0;

		return position + 17.0;
	}
	
	return proposedPosition;
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _splitView) {
		NSSize		size, leftSize, rightSize;
		
		size = [_splitView frame].size;
		leftSize = [_leftView frame].size;
		leftSize.height = size.height;
		rightSize.height = size.height;
		rightSize.width = size.width - [_splitView dividerThickness] - leftSize.width;
		
		[_leftView setFrameSize:leftSize];
		[_rightView setFrameSize:rightSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return (subview != _scrollView);
}



#pragma mark -

- (NSArray *)files {
	return [_handler files];
}



- (NSUInteger)selectedIndex {
	NSInteger	row;
	
	row = [_tableView selectedRow];
	
	return (row < 0) ? NSNotFound : (NSUInteger) row;
}



- (void)selectFileAtIndex:(NSUInteger)index {
	[_tableView selectRow:index byExtendingSelection:NO];
	[_tableView scrollRowToVisible:index];
}



- (void)showFile:(FHFile *)file {
	[super showFile:file];
	
	[[NSNotificationCenter defaultCenter]
		postNotificationName:FHBrowserControllerDidShowFile
		object:file];
}



- (void)updateFileStatus {
	[NSCursor setHiddenUntilMouseMoves:YES];

	[self _updateRightStatus];
}



#pragma mark -

- (BOOL)validateSelector:(SEL)selector {
	if(selector == @selector(openParent:)) {
		return [_handler hasParent];
	}
	else if(selector == @selector(moveToTrash:) ||
			selector == @selector(revealInFinder:)) {
		return ([_handler isLocal] && [self selectedFile]);
	}
	else if(selector == @selector(setAsDesktopBackground:)) {
		return ([_handler isLocal] && [self selectedFile] && ![[self selectedFile] isDirectory]);
	}
	else if(selector == @selector(slideshow:) ||
			selector == @selector(saveDocument:)) {
		return ([_handler numberOfImages] > 0);
	}
	
	return YES;
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WIURL	*url;
	SEL		selector;

	selector = [item action];
	
	if(selector == @selector(go:)) {
		url = [item representedObject];
		
		if([url isFileURL])
			return [[NSFileManager defaultManager] directoryExistsAtPath:[url path]];
	}
	
	return [self validateSelector:selector];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	return [self validateSelector:selector];
}



#pragma mark -

- (void)open:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[self _loadURL:[WIURL fileURLWithPath:[sheet filename]]];
}



- (void)openURL:(id)sender {
	[_openURLTextView setSelectedRange:NSMakeRange(0, [[_openURLTextView string] length])];

	[NSApp beginSheet:_openURLPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(openURLPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)openURLPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	[_openURLPanel close];
	
	if(returnCode == NSAlertDefaultReturn) {
		[FHSettings setInt:[_openURLPopUpButton tagOfSelectedItem] forKey:FHHTMLImageType];

		[self _loadURL:[WIURL URLWithString:[_openURLTextView string] scheme:@"http"]];
	}
}



- (void)openSpotlight:(id)sender {
	[_openSpotlightTextView setSelectedRange:NSMakeRange(0, [[_openSpotlightTextView string] length])];

	[NSApp beginSheet:_openSpotlightPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(openSpotlightPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)openSpotlightPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIURL		*url;
	
	[_openSpotlightPanel close];
	
	if(returnCode == NSAlertDefaultReturn) {
		url = [WIURL URLWithScheme:@"spotlight" host:@"localhost" port:0];
		[url setPath:[NSSWF:@"/%@", [_openSpotlightTextView string]]];

		[self _loadURL:url];
	}
}



- (void)saveDocument:(id)sender {
	NSOpenPanel		*openPanel;
	NSString		*path;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setTitle:NSLS(@"Select Directory", @"Save panel title")];
	[openPanel setPrompt:NSLS(@"Select", @"Save panel button")];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	
	if([openPanel runModalForTypes:nil] == NSFileHandlingPanelOKButton) {
		path = [openPanel filename];
		
		[_imageLoader pauseLoadingImagesAndThumbnails];
		[_imageLoader startLoadingData];

		[_saveProgressIndicator setDoubleValue:0.0];
		[_saveProgressTextField setStringValue:@""];
		
		[_savedPath release];
		_savedPath = [path retain];

		_savedFiles = 0;
		_overwriteAllExisting = NO;
		
		[NSApp beginSheet:_saveProgressPanel
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:@selector(saveProgressPanelDidEnd:returnCode:contextInfo:)
			  contextInfo:NULL];
	}
}



- (void)saveProgressPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	[_saveProgressPanel close];
	
	if(returnCode != NSAlertDefaultReturn)
		[_imageLoader pauseLoadingData];

	[_imageLoader startLoadingImageAtIndex:[self selectedIndex]];
	[_imageLoader startLoadingThumbnails];
}



#pragma mark -

- (void)revealInFinder:(id)sender {
	[[NSWorkspace sharedWorkspace] selectFile:[[self selectedFile] path] inFileViewerRootedAtPath:NULL];
}



- (void)setAsDesktopBackground:(id)sender {
	[[NSWorkspace sharedWorkspace] changeDesktopPicture:[[self selectedFile] path]];
}



- (void)moveToTrash:(id)sender {
	NSAlert			*alert;
	FHFile			*file;
	NSInteger		row;
	NSUInteger		count;
	BOOL			result;
	
	_deletingFile = YES;

	file = [self selectedFile];
	
	result = [[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation 
					  source:[[file path] stringByDeletingLastPathComponent]
				 destination:@""
					   files:[NSArray arrayWithObject:[file name]]
						 tag:NULL];
	
	if(!result) {
		alert = [NSAlert alertWithMessageText:NSLS(@"Could Not Move To Trash", @"Move to trash dialog message")
								defaultButton:NSLS(@"Delete", @"Move to trash dialog button title")
							  alternateButton:NSLS(@"Cancel", @"Move to trash dialog button title")
								  otherButton:NULL
					informativeTextWithFormat:NSLS(@"Do you want to delete \u201c%@\u201d immediately?", @"Move to trash dialog description"), [file name]];
		
		
		if([alert runModal] == NSAlertDefaultReturn)
			result = [[NSFileManager defaultManager] removeFileAtPath:[file path] handler:NULL];
	}
	
	if(result) {
		[_handler removeFile:file];

		count = [_handler numberOfFiles];
		row = [_tableView selectedRow];
		
		[_tableView reloadData];
		
		if(count > 1 && (NSUInteger) row == count) {
			[_tableView selectRow:row - 1 byExtendingSelection:NO];
		} else {
			file = [self selectedFile];
			
			[self startLoadingImageForFile:file atIndex:row];
			[self showFile:file];
		}
	}
}



#pragma mark -

- (void)reload:(id)sender {
	[self _reload];
}



- (void)go:(id)sender {
	[self _loadURL:[sender representedObject]];
}



#pragma mark -

- (void)rotateRight:(id)sender {
	[super rotateRight:sender];
	
	[self _updateRightStatus];
}



- (void)rotateLeft:(id)sender {
	[super rotateLeft:sender];
	
	[self _updateRightStatus];
}



- (void)slideshow:(id)sender {
	[NSApp beginSheet:_screenPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(slideshowPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)slideshowPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	FHSlideshowController	*controller;
	NSUInteger				index;
	
	[_screenPanel close];

	if(returnCode == NSAlertDefaultReturn) {
		[FHSettings setInt:[_screenPopUpButton indexOfSelectedItem] forKey:FHFullscreenScreen];
		[FHSettings setInt:[_screenBackgroundPopUpButton tagOfSelectedItem] forKey:FHFullscreenBackground];
		[FHSettings setBool:[_screenAutoSwitchButton state] forKey:FHFullscreenAutoSwitch];
		[FHSettings setInt:[_screenAutoSwitchTextField intValue] forKey:FHFullscreenAutoSwitchTime];
		
		index = [self selectedIndex];
		
		while([[self fileAtIndex:index] isDirectory] && index < [[self files] count])
			index++;
		
		controller = [[FHSlideshowController alloc] initWithImageLoader:_imageLoader
																  index:index
																 images:[_handler numberOfImages]];
		[controller showSlideshowWindow:self];
		[controller release];
	}
}



- (IBAction)autoSwitch:(id)sender {
	[_screenAutoSwitchTextField setEnabled:[_screenAutoSwitchButton state]];
}



- (void)inspector:(id)sender {
	if(![[[FHInspectorController inspectorController] window] isVisible])
		[[FHInspectorController inspectorController] showWindow:self];
	else
		[[FHInspectorController inspectorController] close];
}



- (void)toggleStatusBar:(id)sender {
	BOOL	show;
	
	show = [FHSettings boolForKey:FHShowStatusBar];
	
	[self _toggleStatusBar:!show];
	
	[FHSettings setBool:!show forKey:FHShowStatusBar];
}



#pragma mark -

- (void)openParent:(id)sender {
	NSString	*name;
	WIURL		*url;
	
	if([_handler hasParent]) {
		url = [_handler parentURL];
		
		if(![url isEqual:[_handler URL]]) {
			name = [[[_handler URL] path] lastPathComponent];
			
			if([url isFileURL] && [name isEqualToString:@"/"])
				name = [self _nameOfRootVolume];
			
			[self _loadURL:url selectName:name];
		}
	}
}



- (void)openFile:(id)sender {
	NSString		*externalEditor;
	FHFile			*file;
	
	file = [self selectedFile];
	
	if([file isDirectory]) {
		[self _loadURL:[file URL]];
	} else {
		externalEditor = [FHSettings objectForKey:FHExternalEditor];
		
		if(externalEditor)
			[[NSWorkspace sharedWorkspace] openFile:[[file URL] path] withApplication:externalEditor];
		else
			[[NSWorkspace sharedWorkspace] openURL:[[file URL] URL]];
	}
}



- (void)openDirectory:(id)sender {
	FHFile	*file;
	
	file = [self selectedFile];
	
	if([file isDirectory])
		[self _loadURL:[file URL]];
}



#pragma mark -

- (void)loadURL:(WIURL *)url {
	NSString	*name;
	Class		class;
	
	class = [FHHandler handlerForURL:url];
	
	if([url isFileURL] && ![class handlesURLAsDirectory:url]) {
		name	= [[url path] lastPathComponent];
		url		= [WIURL fileURLWithPath:[[url path] stringByDeletingLastPathComponent]];
		
		if(![FHHandler handlerForURL:url])
			return;

		[self _loadURL:url selectName:name];
	} else {
		[self _loadURL:url];
	}
}



- (void)loadURL:(WIURL *)url selectItem:(NSString *)item {
	[self _loadURL:url selectName:item];
}



- (WIURL *)URL {
	return [_handler URL];
}



- (FHHandler *)handler {
	return _handler;
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [[_handler files] count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	return [[self fileAtIndex:row] name];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	FHFile		*file;
	FHImage		*icon;

	file = [self fileAtIndex:row];
	icon = [file thumbnail];
	
	if(!icon)
		icon = [file icon];

	[(FHFileCell *) cell setImage:icon];
}


- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self fileAtIndex:row] name];
}



- (void)tableViewFrameDidChange:(NSNotification *)notification {
	NSSize		size;
	
	size = [_tableView frame].size;
	
	if(size.width != _tableViewSize.width) {
		[self _resizeTableView];

		[_tableView setNeedsDisplay:YES];
		
		_tableViewSize = size;
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	FHFile			*file;
	NSInteger		row;

	row = [_tableView selectedRow];
	
	if(row < 0) {
		[self showFile:NULL];
		
		return;
	}
	
	file = [self fileAtIndex:row];
	
	[self startLoadingImageForFile:file atIndex:row];
	[self showFile:file];
}




- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	NSEnumerator		*enumerator;
	NSMutableArray		*paths;
	FHFile				*file;
	
	if(![_handler isLocal])
		return NO;
	
	paths = [NSMutableArray array];
	enumerator = [[self filesAtIndexes:indexes] objectEnumerator];
	
	while((file = [enumerator nextObject]))
		[paths addObject:[file path]];

	[pasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:NULL];
	[pasteboard setPropertyList:paths forType:NSFilenamesPboardType];
	
	return YES;
}



#pragma mark -

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)info {
	return NSDragOperationGeneric;
}



- (BOOL)performDragOperation:(id <NSDraggingInfo>)info {
	NSPasteboard	*pasteboard;
	NSString		*path;
	
	pasteboard = [info draggingPasteboard];
	path = [[pasteboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
	
	[self loadURL:[WIURL fileURLWithPath:path]];
	
	return YES;
}

@end
