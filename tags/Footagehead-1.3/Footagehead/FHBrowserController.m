/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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
#import "FHSettings.h"
#import "FHSlideshowController.h"

@interface FHBrowserController(Private)

- (NSToolbar *)_toolbar;
- (void)_resizeTableView;
- (void)_reloadScreens;
- (void)_updateZoomModeToolbarItems;
- (void)_toggleStatusBar:(BOOL)show;

- (void)_loadURL:(WIURL *)url;
- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row;
- (void)_loadURL:(WIURL *)url selectName:(NSString *)name;
- (void)_loadURL:(WIURL *)url selectRow:(NSInteger)row name:(NSString *)name;

- (void)_reload;
- (void)_updateLeftStatus;
- (void)_updateRightStatus;

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
											 action:@selector(zoomMode:)];
	[item setTag:FHScaleNone];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"ZoomToFit"
											   name:NSLS(@"Zoom To Fit", @"Zoom to fit toolbar item")
											content:[NSImage imageNamed:@"ZoomToFit"]
											 target:self
											 action:@selector(zoomMode:)];
	[item setTag:FHScaleProportionally];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	item = [NSToolbarItem toolbarItemWithIdentifier:@"StretchToFit"
											   name:NSLS(@"Stretch To Fit", @"Stretch to fit toolbar item")
											content:[NSImage imageNamed:@"StretchToFit"]
											 target:self
											 action:@selector(zoomMode:)];
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

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Footagehead"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];

	return [toolbar autorelease];
}



- (void)_resizeTableView {
	NSSize		size;
	
	size = [_tableView rectOfColumn:0].size;
	size.width += 28.0;
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



- (void)_updateZoomModeToolbarItems {
	switch([_imageView imageScaling]) {
		case FHScaleNone:
			[[[self window] toolbar] setSelectedItemIdentifier:@"ActualSize"];
			break;
			
		case FHScaleProportionally:
			[[[self window] toolbar] setSelectedItemIdentifier:@"ZoomToFit"];
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
	BOOL			select;
	
	_switchingURL = YES;
	
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
	
	if([[_handler URL] isFileURL])
		[[WIEventQueue sharedQueue] addPath:[[_handler URL] path] forMode:WIEventFileWrite];
	
	[[self window] setTitle:@"Footagehead" withSubtitle:[[_handler stringComponents] lastObject]];
	
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
	
	select = (row != [_tableView selectedRow]);

	[_tableView reloadData];
	
	if(select) {
		[_tableView selectRow:row byExtendingSelection:NO];
	} else {
		file = [self selectedFile];
		
		[self startLoadingImageForFile:file atIndex:row];
		[self showFile:file];
	}

	[_tableView scrollRowToVisible:row];

	if([_handler isLocal])
		[_imageLoader startLoadingThumbnails];
	
	_switchingURL = NO;
}



#pragma mark -

- (void)_reload {
	NSString	*name;
	WIURL		*url;
	
	url = [[_handler URL] retain];
	name = [[[self selectedFile] name] retain];

	[[FHCache cache] dropThumbnailsForURL:url];

	[self _loadURL:url selectName:name];
	
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
	NSSize				imageSize, frameSize;
	CGFloat				zoom, size;
	
	imageSize = [_imageView combinedImageSize];
	
	if(imageSize.width < 1.0 || imageSize.height <= 1.0) {
		[_rightStatusTextField setStringValue:@""];
		
		return;
	}
	
	if(ABS([_imageView imageRotation]) == 90 || ABS([_imageView imageRotation]) == 270) {
		size = imageSize.width;
		imageSize.width = imageSize.height;
		imageSize.height = size;
	}

	frameSize = [NSScrollView frameSizeForContentSize:[_imageView frame].size
								hasHorizontalScroller:[_scrollView hasHorizontalScroller]
								  hasVerticalScroller:[_scrollView hasVerticalScroller]
										   borderType:[_scrollView borderType]];
	
	if(imageSize.height > frameSize.height && imageSize.width <= frameSize.width)
		frameSize.width = frameSize.height * (imageSize.width / imageSize.height);
	
	if(imageSize.width > frameSize.width && imageSize.height <= frameSize.height)
		frameSize.height = frameSize.width * (imageSize.height / imageSize.width);
	
	zoom = 100.0 * ((frameSize.width * frameSize.height) / (imageSize.width * imageSize.height));
	
	if(zoom > 100.0)
		zoom = 100.0;
	
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone)
		name = [[self selectedFile] name];
	else
		name = [[self selectedSpread] name];
	
	string = [NSMutableString stringWithFormat:NSLS(@"%@, %.0fx%.0f", @"'image.jpg, 640x480'"),
		name,
		imageSize.width,
		imageSize.height];

	if(zoom != 100.0) {
		[string appendFormat:NSLS(@", scaled to %.0f%%", @"', scaled to 50%'"),
			zoom];
	}

	if([_imageView imageRotation] != 0.0) {
		[string appendFormat:NSLS(@", rotated by %.0f", @"', rotated by 90'"),
			ABS([_imageView imageRotation])];
	}
	
	[_rightStatusTextField setStringValue:string];
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
		   selector:@selector(imageLoaderDidLoadThumbnail:)
			   name:FHImageLoaderDidLoadThumbnail];

	[imageLoader release];

	[self window];
	
	return self;
}



- (void)dealloc {
	[_handler release];
	
	[_imageLoader stopLoading];
	
	[_toolbarItems release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setToolbar:[self _toolbar]];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Footagehead"];
	
	[_fileTableColumn setDataCell:[[[FHFileCell alloc] init] autorelease]];
	[_tableView setDoubleAction:@selector(openFile:)];
	[_tableView setForwardAction:@selector(openDirectory:)];
	[_tableView setBackAction:@selector(openParent:)];
	[_tableView setDeleteAction:@selector(openParent:)];
	
	[_splitView setAutosaveName:@"Browser"];
	
	[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	[_imageView setImageRotation:[FHSettings floatForKey:FHImageRotation]];
	
	[self _updateZoomModeToolbarItems];

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

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(eventFileWrite:)
			   name:WIEventFileWriteNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedZoomMode:)
			   name:FHWindowControllerChangedZoomMode];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedSpreadMode:)
			   name:FHWindowControllerChangedSpreadMode];
}



- (void)windowDidResize:(NSNotification *)notification {
	[self _updateRightStatus];
}



- (void)windowControllerChangedZoomMode:(NSNotification *)notification {
	if([notification object] != _imageView) {
		[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	
		[self _updateZoomModeToolbarItems];

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



- (void)imageLoaderDidLoadThumbnail:(NSNotification *)notification {
	[_tableView reloadData];
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
		@"ZoomToFit",
		@"StretchToFit",
		NSToolbarSeparatorItemIdentifier,
		@"RotateLeft",
		@"RotateRight",
		NSToolbarSeparatorItemIdentifier,
		@"Slideshow",
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
		@"ZoomToFit",
		@"StretchToFit",
		@"RotateLeft",
		@"RotateRight",
		@"Slideshow",
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
		@"ZoomToFit",
		@"StretchToFit",
		NULL];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	return 49.0;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	return 145.0;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)offset {
	CGFloat		position;

	if([[NSApp currentEvent] alternateKeyModifier]) {
		position = proposedPosition - 17.0;
		
		if(position >= 128.0)
			return 145.0;
		else if(position >= 64.0)
			return 81.0;
		else if(position >= 48.0)
			return 65.0;

		return 49.0;
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
	
	return (row < 0) ? NSNotFound : row;
}



- (void)selectFileAtIndex:(NSUInteger)index {
	[_tableView selectRow:index byExtendingSelection:NO];
	[_tableView scrollRowToVisible:index];
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
			selector == @selector(revealInFinder:) ||
			selector == @selector(setAsDesktopBackground:)) {
		return ([_handler isLocal] && [self selectedFile]);
	}
	else if(selector == @selector(slideshow:)) {
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



- (IBAction)openURL:(id)sender {
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



#pragma mark -

- (IBAction)openParent:(id)sender {
	NSString	*name;
	WIURL		*url;
	
	if([_handler hasParent]) {
		url = [_handler parentURL];
		
		if(![url isEqual:[_handler URL]]) {
			name = [[[_handler URL] path] lastPathComponent];
			
			[self _loadURL:url selectName:name];
		}
	}
}



- (IBAction)openFile:(id)sender {
	FHFile	*file;
	
	file = [self selectedFile];
	
	if([file isDirectory])
		[self _loadURL:[file URL]];
	else
		[[NSWorkspace sharedWorkspace] openURL:[[file URL] URL]];
}



- (IBAction)openDirectory:(id)sender {
	FHFile	*file;
	
	file = [self selectedFile];
	
	if([file isDirectory])
		[self _loadURL:[file URL]];
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

	row = [_tableView selectedRow];
	file = [self selectedFile];
	
	result = [[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation 
					  source:[[file path] stringByDeletingLastPathComponent]
				 destination:@""
					   files:[NSArray arrayWithObject:[file name]]
						 tag:NULL];
	
	if(!result) {
		alert = [NSAlert alertWithMessageText:NSLS(@"Could not move to trash", @"Move to trash dialog message")
								defaultButton:NSLS(@"Delete", @"Move to trash dialog button title")
							  alternateButton:NSLS(@"Cancel", @"Move to trash dialog button title")
								  otherButton:NULL
					informativeTextWithFormat:NSLS(@"Do you want to delete \"%@\" immediately?", @"Move to trash dialog description"), [file name]];
		
		
		if([alert runModal] == NSAlertDefaultReturn)
			result = [[NSFileManager defaultManager] removeFileAtPath:[file path]];
	}
	
	if(result) {
		[_handler removeFile:file];

		count = [_handler numberOfFiles];

		if(count > 1 && (NSUInteger) row == count - 1)
			[_tableView selectRow:row - 1 byExtendingSelection:NO];

		[_tableView reloadData];

		[self showFile:[self selectedFile]];
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



- (void)toggleStatusBar:(id)sender {
	BOOL	show;
	
	show = [FHSettings boolForKey:FHShowStatusBar];
	
	[self _toggleStatusBar:!show];
	
	[FHSettings setBool:!show forKey:FHShowStatusBar];
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
	FHFile		*file;
	FHImage		*icon;
	
	file = [self fileAtIndex:row];
	icon = [file thumbnail];
	
	if(!icon)
		icon = [file icon];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[file name],	FHFileCellNameKey,
		icon,			FHFileCellIconKey,
		NULL];
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self fileAtIndex:row] name];
}



- (void)tableViewFrameDidChange:(NSNotification *)notification {
	NSSize		size;
	
	size = [_tableView frame].size;
	
	if(size.width != _tableViewSize.width) {
		[self _resizeTableView];

		[_tableView displayIfNeeded];
		
		_tableViewSize = size;
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	FHFile			*file;
	NSInteger		row;

	row = [_tableView selectedRow];
	file = [self fileAtIndex:row];
	
	[self startLoadingImageForFile:file atIndex:row];
	[self showFile:file];
	
	if(!_switchingURL && row == _previousRow - 1) {
		if([_scrollView hasVerticalScroller])
			[_imageView scrollPoint:NSZeroPoint];
	}
	
	_previousRow = row;
}

@end
