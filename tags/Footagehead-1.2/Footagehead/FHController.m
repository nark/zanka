/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "NSImage-FHAdditions.h"
#import "FHCache.h"
#import "FHController.h"
#import "FHFile.h"
#import "FHFileCell.h"
#import "FHFullscreenWindow.h"
#import "FHHandler.h"
#import "FHImage.h"
#import "FHImageView.h"
#import "FHSettings.h"

#define FHUnloadImageCount			5
#define FHPreloadImageCount			10

static FHController					*sharedController;


@interface FHController(Private)

- (void)_selectFileAtIndex:(unsigned int)index;
- (FHFile *)_selectedFile;
- (FHFile *)_fileAtIndex:(unsigned int)index;

- (void)_loadURL:(WIURL *)url;
- (void)_loadURL:(WIURL *)url selectRow:(int)row;
- (void)_loadURL:(WIURL *)url selectFile:(NSString *)file;
- (void)_loadURL:(WIURL *)url selectRow:(int)row file:(NSString *)file;
- (void)_reloadURL:(WIURL *)url;
- (void)_loadFile:(FHFile *)file;

- (void)_addMenuItemWithPath:(NSString *)path keyEquivalent:(NSString *)keyEquivalent;
- (void)_reloadVolumesMenu;
- (void)_reloadPathMenu;
- (void)_reloadScreens;
- (void)_reloadScreenBackgrounds;

- (void)_startSpinning;
- (void)_stopSpinning;
- (void)_updateImage;
- (void)_updateButtons;
- (void)_updateStatus;
- (void)_updateLeftStatus;
- (void)_updateRightStatus;
- (void)_updateFullscreenStatus;
- (void)_updateTableView;

@end


@implementation FHController(Private)

- (void)_selectFileAtIndex:(unsigned int)index {
	[_loadImageTimer setFireDate:[NSDate distantFuture]];
	[_tableView selectRow:index byExtendingSelection:NO];
	[_tableView scrollRowToVisible:index];
}



- (FHFile *)_selectedFile {
	int		row;
	
	row = [_tableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _fileAtIndex:row];
}



- (FHFile *)_fileAtIndex:(unsigned int)index {
	return [[_handler files] objectAtIndex:index];
}



#pragma mark -

- (void)_loadURL:(WIURL *)url {
	[self _loadURL:url selectRow:0 file:NULL];
}



- (void)_loadURL:(WIURL *)url selectRow:(int)row {
	[self _loadURL:url selectRow:row file:NULL];
}



- (void)_loadURL:(WIURL *)url selectFile:(NSString *)file {
	[self _loadURL:url selectRow:0 file:file];
}



- (void)_loadURL:(WIURL *)url selectRow:(int)row file:(NSString *)file {
	NSArray			*files;
	FHHandler		*handler;
	unsigned int	i, count;
	BOOL			select;
	
	[self _startSpinning];
	
	_switchingURL = YES;

	handler = [[FHHandler alloc] initHandlerWithURL:url];
	
	if(!handler) {
		[self _stopSpinning];
		
		return;
	}

	if(_handler) {
		if(![_handler isSynchronous] && ![_handler isFinished])
			[self _stopSpinning];
		
		if([_handler isLocal])
			[_queue removePath:[[_handler URL] path]];
		
		[_handler release];
	}
	
	_handler = handler;
	[_handler setDelegate:self];
	files = [_handler files];
	
	if([_handler isLocal])
		[_queue addPath:[[_handler URL] path] forMode:WIEventFileWrite];
	
	[self _updateLeftStatus];
	[self _updateButtons];
	[self _reloadPathMenu];
	
	if(file) {
		for(i = 0, count = [files count]; i < count; i++) {
			if([[[files objectAtIndex:i] name] isEqualToString:file]) {
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
		[_loadImageLock lock];
		_selectedRow = row;
		_imageCounter++;
		[_loadImageLock unlockWithCondition:1];
	}

	[_tableView scrollRowToVisible:row];

	if([_handler isLocal]) {
		[_loadThumbnailsLock lock];
		_thumbnailsCounter++;
		[_loadThumbnailsLock unlockWithCondition:1];
	}

	_switchingURL = NO;

	if([_handler isSynchronous])
		[self _stopSpinning];
}



- (void)_reloadURL:(WIURL *)url {
	NSString	*file;
	
	file = [[[self _selectedFile] name] retain];
	[[FHCache cache] dropThumbnailsForURL:url];
	[self _loadURL:url selectFile:file];
	[file release];
}



- (void)_loadFile:(FHFile *)file {
	if([file isLoaded]) {
		[self performSelector:@selector(_fileDidLoadImage:) withObject:file];
	} else {
		[_imageView setImage:NULL];
		[self _updateRightStatus];
	}
}



- (void)_loadFileTimer:(NSTimer *)timer {
	NSArray		*files;
	int			i, count;
	BOOL		next = NO;

	[self nextImage:self];
	
	i = [_tableView selectedRow];
	files = [_handler files];
	count = [files count];
	
	while(i < count - 1) {
		if(![[files objectAtIndex:i] isDirectory]) {
			next = YES;
			
			break;
		}
	}
	
	if(!next)
		[timer invalidate];
}



- (void)_loadImageThread:(id)arg {
	NSAutoreleasePool   *pool;
	NSArray				*files;
	FHImage				*image;
	FHFile				*file;
	unsigned int		i, count, counter, images, row, lastRow, lastCounter;
	
	lastRow = lastCounter = 0;
	
	while(YES) {
		pool = [[NSAutoreleasePool alloc] init];

		[_loadImageLock lockWhenCondition:1];
		row = _selectedRow;
		files = [[_handler files] copy];
		counter = _imageCounter;
		[_loadImageLock unlockWithCondition:0];
		
		if(counter != lastCounter) {
			count = [files count];
			
			// --- purge all but the last couple of images
			if(row > FHUnloadImageCount) {
				for(i = 0; i < count && i < row - FHUnloadImageCount; i++) {
					file = [files objectAtIndex:i];
					
					if([file isDirectory])
						continue;
					
					if(![file isLoaded])
						continue;
					
					[file setImage:NULL];
					[file setLoaded:NO];
				}
			}
			
			// --- load the next couple of images
			for(i = row, images = 0; i < count; i++) {
				file = [files objectAtIndex:i];
				
				if([file isDirectory])
					goto next;
				
				if(++images > FHPreloadImageCount)
					break;
				
				if([file image])
					goto next;
				
				image = [[FHImage alloc] initImageWithURL:[file URL]];
				[file setImage:image];
				[file setLoaded:YES];
				[image release];
				
				[self performSelectorOnMainThread:@selector(_fileDidLoadImage:) withObject:file waitUntilDone:YES];

next:
				[_loadImageLock lock];
				if(counter != _imageCounter)
					i = count;
				[_loadImageLock unlockWithCondition:counter == _imageCounter ? 0 : 1];
			}
			
			lastRow = row;
			lastCounter = counter;
		}

		[files release];
		[pool release];
	}
}



- (void)_loadThumbnailsThread:(id)arg {
	NSAutoreleasePool	*pool;
	NSArray				*files;
	FHImage				*image;
	FHFile				*file;
	WIURL				*url;
	unsigned int		i, count, counter, images;
	
	[NSThread setThreadPriority:0.25];

	while(YES) {
		pool = [[NSAutoreleasePool alloc] init];

		[_loadThumbnailsLock lockWhenCondition:1];
		files = [[_handler files] copy];
		counter = _thumbnailsCounter;
		[_loadThumbnailsLock unlockWithCondition:0];
		
		count = [files count];

		for(i = images = 0; i < count; i++) {
			file = [files objectAtIndex:i];
			
			if([file isDirectory] || [file thumbnail])
				goto next;
			
			url = [file URL];
			image = [[FHCache cache] thumbnailForURL:url];
			
			if(!image) {
				image = [[FHImage alloc] initThumbnailWithURL:url preferredSize:NSMakeSize(128.0, 128.0)];
				
				if(image)
					[[FHCache cache] setThumbnail:image forURL:url];
			}
			
			if(image) {
				[file setThumbnail:image];
				[image release];
			
				[self performSelectorOnMainThread:@selector(_fileDidLoadThumbnail:) withObject:file waitUntilDone:YES];
			}
			
next:
			if(++images % 5 == 0) {
				[_loadThumbnailsLock lock];
				if(counter != _thumbnailsCounter)
					i = count;
				[_loadThumbnailsLock unlockWithCondition:counter == _thumbnailsCounter ? 0 : 1];
			}
		}
			
		[files release];
		[pool release];
	}
}



- (void)_fileDidLoadImage:(FHFile *)file {
	FHImage		*image;
	BOOL		success;
	
	image = [file image];
	success = (image && [image size].width > 0.0);
	
	if([file isEqual:[self _selectedFile]]) {
		if(_fullscreenWindow) {
			if(success) {
				// --- display image in fullscreen
				[_fullscreenImageView setImage:image];
				[self _updateFullscreenStatus];
				[_loadImageTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:
					[FHSettings intForKey:FHFullscreenAutoSwitchTime]]];
			} else {
				// --- display error in fullscreen
				[_fullscreenImageView setImage:[FHImage imageNamed:@"Error"]];
				[self _updateFullscreenStatus];
			}
		} else {
			if(success) {
				// --- display image in window mode
				[NSCursor setHiddenUntilMouseMoves:YES];
				[_imageView setImage:image];
				[self _updateRightStatus];
			} else {
				// --- display error in window mode
				[_imageView setImage:[FHImage imageNamed:@"Error"]];
				[_rightStatusTextField setStringValue:[NSSWF:NSLS(@"error opening image", @"Error message")]];
			}
		}
	}
}



- (void)_fileDidLoadThumbnail:(FHFile *)file {
	[_tableView reloadData];
}



- (void)_handlerDidAddFiles:(FHHandler *)handler {
	[_tableView reloadData];
	[self _updateLeftStatus];

	[_loadImageLock lock];
	_imageCounter++;
	[_loadImageLock unlockWithCondition:1];

	if([_handler isLocal]) {
		[_loadThumbnailsLock lock];
		_thumbnailsCounter++;
		[_loadThumbnailsLock unlockWithCondition:1];
	}
}



- (void)_handlerDidFinishLoading:(FHHandler *)handler {
	[self _stopSpinning];
}



#pragma mark -

- (void)_addMenuItemWithPath:(NSString *)path keyEquivalent:(NSString *)keyEquivalent {
	NSMenuItem	*item;
	NSString	*name;
	NSImage		*icon;
	
	path = [path stringByStandardizingPath];
	name = [[NSFileManager defaultManager] displayNameAtPath:path];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16.0, 16.0)];

	item = [[NSMenuItem alloc] initWithTitle:name action:@selector(openMenu:) keyEquivalent:keyEquivalent];
	[item setImage:icon];
	[item setRepresentedObject:[WIURL fileURLWithPath:path]];
	[[_menu menu] addItem:item];
	_menuItems++;
	[item release];
}



- (void)_reloadPathMenu {
	NSArray			*stringComponents, *urlComponents;
	NSMenuItem		*item;
	NSImage			*icon;
	NSString		*name;
	WIURL			*url;
	unsigned int	i, count, items;
	
	stringComponents = [_handler stringComponents];
	urlComponents = [_handler URLComponents];
	count = [stringComponents count];
	items = [_menu numberOfItems];
	
	for(i = 0; i < count; i++) {
		// --- check if we have the item already, and skip if so
		if(_menuItems + i < items) {
			name = [[_menu itemAtIndex:i + _menuItems] title];
			
			if([name isEqualToString:[stringComponents objectAtIndex:i]])
				continue;
			
			[_menu removeItemAtIndex:_menuItems + i];
			items--;
		}
		
		// --- insert new or changed item
		url = [urlComponents objectAtIndex:i];
		item = [[NSMenuItem alloc] initWithTitle:[stringComponents objectAtIndex:i]
										  action:@selector(openMenu:)
								   keyEquivalent:@""];
		[item setRepresentedObject:url];
		
		// --- get icon
		icon = [_handler iconForURL:url];
		
		if(icon) {
			[icon setSize:NSMakeSize(16.0, 16.0)];
			[item setImage:icon];
		}
			
		[_menu insertItem:item atIndex:_menuItems + i];
		items++;
		[item release];
	}
	
	// --- remove excess items
	while(items > _menuItems + count) {
		[_menu removeItemAtIndex:_menuItems + count];
		
		items--;
	}
	
	[_menu selectItem:[_menu lastItem]];
}



- (void)_reloadVolumesMenu {
	NSEnumerator	*enumerator;
	NSMenuItem		*item;
	NSString		*volume, *name, *path;
	NSImage			*icon;
	BOOL			loop = YES;
	int				i = 0;
	
	// --- delete all items up to and including the first separator
	if([_menu numberOfItems] > 0) {
		while(loop) {
			if([[_menu itemAtIndex:0] isSeparatorItem])
				loop = NO;
			
			[_menu removeItemAtIndex:0];
			
			_menuItems--;
		}
	}
	
	// --- loop over volumes
	enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:@"/Volumes/"] objectEnumerator];
	
	while((volume = [enumerator nextObject])) {
		if([volume hasPrefix:@"."])
			continue;
		
		path = [NSSWF:@"/Volumes/%@", volume];
		name = [[NSFileManager defaultManager] displayNameAtPath:path];
		icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		[icon setSize:NSMakeSize(16.0, 16.0)];
		item = [[NSMenuItem alloc] initWithTitle:name action:@selector(openMenu:) keyEquivalent:@""];
		[item setImage:icon];
		[item setRepresentedObject:[WIURL fileURLWithPath:path]];
		[_menu insertItem:item atIndex:i];
		_menuItems++;
		[item release];
		
		i++;
	}
	
	// --- add spacer
	[_menu insertItem:(NSMenuItem *) [NSMenuItem separatorItem] atIndex:i];
	_menuItems++;
}



- (void)_reloadScreens {
	NSArray			*screens;
	NSRect			frame;
	unsigned int	i, index, count;
	
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



- (void)_reloadScreenBackgrounds {
	NSMenuItem		*item;
	
	[_screenBackgroundPopUpButton removeAllItems];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLS(@"Black", @"Color black") action:NULL keyEquivalent:@""];
	[item setImage:[NSImage imageNamed:@"Black"]];
	[item setRepresentedObject:[NSColor blackColor]];
	[item setTag:FHFullscreenBackgroundBlack];
	[[_screenBackgroundPopUpButton menu] addItem:item];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLS(@"Gray", @"Color gray") action:NULL keyEquivalent:@""];
	[item setImage:[NSImage imageNamed:@"Gray"]];
	[item setRepresentedObject:[NSColor grayColor]];
	[item setTag:FHFullscreenBackgroundGray];
	[[_screenBackgroundPopUpButton menu] addItem:item];
	[item release];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLS(@"White", @"Color white") action:NULL keyEquivalent:@""];
	[item setImage:[NSImage imageNamed:@"White"]];
	[item setRepresentedObject:[NSColor whiteColor]];
	[item setTag:FHFullscreenBackgroundWhite];
	[[_screenBackgroundPopUpButton menu] addItem:item];
	[item release];
}



#pragma mark -

- (void)_startSpinning {
	if(_spinners == 0)
		[_progressIndicator startAnimation:self];
	
	_spinners++;
}



- (void)_stopSpinning {
	_spinners--;
	
	if(_spinners == 0)
		[_progressIndicator stopAnimation:self];
}



- (void)_updateImage {
	[self _loadFile:[self _selectedFile]];
}



- (void)_updateButtons {
	[_revealInFinderButton setEnabled:[_handler isLocal]];
	[_moveToTrashButton setEnabled:[_handler isLocal]];
}



- (void)_updateStatus {
	[self _updateLeftStatus];
	[self _updateRightStatus];
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
	NSSize				imageSize, frameSize;
	double				zoom;
	float				size;
	
	if(![_imageView image]) {
		[_rightStatusTextField setStringValue:@""];
		
		return;
	}
	
	imageSize = [[_imageView image] size];
	
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
	
	string = [[NSMutableString alloc] initWithFormat:NSLS(@"%@, %.0fx%.0f", @"'image.jpg, 640x480'"),
		[[self _selectedFile] name],
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
	
	[string release];
}



- (void)_updateFullscreenStatus {
	NSArray			*files;
	FHFile			*file;
	unsigned int	i, count, index;
	
	file = [self _selectedFile];
	files = [_handler files];
	count = [files count];

	for(i = index = 0; i < count; i++) {
		if(![[files objectAtIndex:i] isDirectory])
			index++;
		
		if([files objectAtIndex:i] == file)
			break;
	}
	
	[_fullscreenImageView setLabel:[NSSWF:NSLS(@"%@ %C %u/%u", @"'image.jpg - 1/10'"),
		[file name],
		0x2014,
		index,
		[_handler numberOfImages]]];
}



- (void)_updateTableView {
	NSSize		size;
	
	size = [_tableView rectOfColumn:0].size;
	size.width += 28.0;
	[_tableView setRowHeight:size.width];
	[_tableView sizeToFitFromContent];
}

@end


@implementation FHController

+ (FHController *)controller {
	return sharedController;
}



- (void)awakeFromNib {
	FHFileCell		*fileCell;
	
	sharedController = self;
	
	/// --- set custom cell type
	fileCell = [[FHFileCell alloc] init];
	[_fileTableColumn setDataCell:fileCell];
	[fileCell release];
	
	// --- set up table view
	[_tableView setDoubleAction:@selector(openFile:)];
	[_tableView setForwardAction:@selector(openDirectory:)];
	[_tableView setBackAction:@selector(openParent:)];
	[_tableView setDeleteAction:@selector(openParent:)];
	
	// --- set up split view
	[_splitView setAutosaveName:@"Browser"];
	
	// --- thread spinner
	[_progressIndicator setUsesThreadedAnimation:YES];
	
	// --- set up window
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Footagehead"];
	
	if([FHSettings intForKey:FHImageScalingMethod] != FHScaleProportionally)
		[_zoomButton setState:NSOnState];
	
	// --- set up fullscreen panel
	[self _reloadScreens];
	
	if([FHSettings intForKey:FHFullscreenScreen] < [_screenPopUpButton numberOfItems])
		[_screenPopUpButton selectItemAtIndex:[FHSettings intForKey:FHFullscreenScreen]];
	
	[self _reloadScreenBackgrounds];

	[_screenBackgroundPopUpButton selectItemWithTag:[FHSettings intForKey:FHFullscreenBackground]];

	[_screenAutoSwitchButton setState:[FHSettings boolForKey:FHFullscreenAutoSwitch]];
	[_screenAutoSwitchTextField setEnabled:[FHSettings boolForKey:FHFullscreenAutoSwitch]];
	[_screenAutoSwitchTextField setIntValue:[FHSettings intForKey:FHFullscreenAutoSwitchTime]];
	
	[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	[_imageView setImageRotation:[FHSettings floatForKey:FHImageRotation]];

	// --- create locks
	_loadImageLock		= [[NSConditionLock alloc] initWithCondition:0];
	_loadThumbnailsLock	= [[NSConditionLock alloc] initWithCondition:0];
	
	// --- create queue
	_queue = [[WIEventQueue alloc] init];
	
	// --- unlink spotlight item if not available
	if(!NSClassFromString(@"NSMetadataQuery"))
		[[_openSpotlightMenuItem menu] removeItem:_openSpotlightMenuItem];
	
	// --- open last directory by default (unset if started by opening a file)
	_openLastURL = YES;
	
	// --- build menu
	[_menu removeAllItems];
	[self _reloadVolumesMenu];
	[self _addMenuItemWithPath:@"~" keyEquivalent:@"H"];
	[self _addMenuItemWithPath:@"~/Desktop" keyEquivalent:@"d"];
	
	if([[NSFileManager defaultManager] directoryExistsAtPath:[@"~/Pictures" stringByExpandingTildeInPath]])
		[self _addMenuItemWithPath:@"~/Pictures" keyEquivalent:@"P"];
	
	[_menu addItem:(NSMenuItem *) [NSMenuItem separatorItem]];
	_menuItems++;
	
	// --- subscribe to these
	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidMount:)
			   name:NSWorkspaceDidMountNotification
			 object:NULL];

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidUnmount:)
			   name:NSWorkspaceDidUnmountNotification
			 object:NULL];

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(eventFileWrite:)
			   name:WIEventFileWriteNotification
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(viewFrameDidChange:)
			   name:NSViewFrameDidChangeNotification
			 object:_tableView];

	// --- set from prefs
	[self _updateTableView];
	
	// --- detach loader threads
	[NSThread detachNewThreadSelector:@selector(_loadImageThread:) toTarget:self withObject:NULL];
	[NSThread detachNewThreadSelector:@selector(_loadThumbnailsThread:) toTarget:self withObject:NULL];
	[NSThread setThreadPriority:0.75];
}



#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	WIURL		*url;
	
	// --- if option redirect to home
	if((GetCurrentKeyModifiers() & optionKey) != 0)
		[FHSettings setObject:[[WIURL fileURLWithPath:NSHomeDirectory()] string] forKey:FHOpenURL];
		
	if(_openLastURL) {
		// --- get url of last open directory
		url = [WIURL URLWithString:[FHSettings objectForKey:FHOpenURL]];

		if([url isFileURL] && ![[NSFileManager defaultManager] fileExistsAtPath:[url path]])
			url = [WIURL fileURLWithPath:NSHomeDirectory()];

		// --- load files
		[self _loadURL:url];
	}
	
	[self showWindow:self];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	WIURL	*url;
	
	url = [_handler URL];
	
	if(url)
		[FHSettings setObject:[url string] forKey:FHOpenURL];
	
	[_handler release];
	_handler = NULL;
}



- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
	return YES;
}



- (void)applicationDidChangeScreenParameters:(NSNotification *)notification {
	[self _reloadScreens];
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	NSString	*file;
	WIURL		*url;
	
	url = [WIURL fileURLWithPath:path];
	
	if([FHHandler handlesURLAsDirectory:url]) {
		[self _loadURL:url];
	} else {
		file = [path lastPathComponent];
		path = [path stringByDeletingLastPathComponent];
		
		[self _loadURL:url selectFile:file];
	}
	
	_openLastURL = NO;

	return YES;
}



- (void)workspaceDidMount:(NSNotification *)notification {
	[self _reloadVolumesMenu];
}



- (void)workspaceDidUnmount:(NSNotification *)notification {
	[self _reloadVolumesMenu];
}



- (void)eventFileWrite:(NSNotification *)notification {
	[self _reloadURL:[_handler URL]];
}



- (void)windowDidResize:(NSNotification *)notification {
	[self _updateRightStatus];
}



- (void)windowWillClose:(NSNotification *)notification {
	if([notification object] == _fullscreenWindow) {
		[_loadImageTimer invalidate];
		[_loadImageTimer release];
		_loadImageTimer = NULL;

		[self showWindow:self];
		
		_fullscreenWindow = NULL;

		[self _updateImage];
	}
}



- (void)viewFrameDidChange:(NSNotification *)notification {
	NSSize		size;
	
	size = [_tableView frame].size;
	
	if(size.width != _lastTableViewSize.width) {
		[self _updateTableView];
		[_tableView displayIfNeeded];
		
		_lastTableViewSize = size;
	}
}



- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset {
	return 49.0;
}



- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	return 145.0;
}



- (float)splitView:(NSSplitView *)splitView constrainSplitPosition:(float)proposedPosition ofSubviewAt:(int)offset {
	int			position;

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



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		handled = NO;
	
	if(selector == @selector(insertNewline:)) {
		[self submitSheet:sender];

		handled = YES;
	}

	return handled;
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	FHFile	*file;
	SEL		selector;
	
	selector = [menuItem action];
	file = [self _selectedFile];
	
	if(selector == @selector(zoom:))
		return (file && ![file isDirectory]);
	else if(selector == @selector(delete:))
		return [_moveToTrashButton isEnabled];
	else if(selector == @selector(revealInFinder:))
		return [_revealInFinderButton isEnabled];
	else if(selector == @selector(setAsDesktopPicture:))
		return (file && ![file isDirectory] && [[file URL] isFileURL]);
	
	return YES;
}



#pragma mark -

- (IBAction)open:(id)sender {
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



- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
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



- (void)openURLPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[_openURLPanel close];
	
	if(returnCode == NSRunStoppedResponse)
		[self _loadURL:[WIURL URLWithString:[_openURLTextView string] scheme:@"http"]];
}



- (IBAction)openSpotlight:(id)sender {
	[_openSpotlightTextView setSelectedRange:NSMakeRange(0, [[_openSpotlightTextView string] length])];

	[NSApp beginSheet:_openSpotlightPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(openSpotlightPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)openSpotlightPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WIURL		*url;
	
	[_openSpotlightPanel close];
	
	if(returnCode == NSRunStoppedResponse) {
		url = [[WIURL alloc] initWithScheme:@"spotlight" host:@"localhost" port:0];
		[url setPath:[NSSWF:@"/%@", [_openSpotlightTextView string]]];
		[self _loadURL:url];
		[url release];
	}
}



- (IBAction)openParent:(id)sender {
	NSString	*name;
	WIURL		*url;
	
	if([_handler hasParent]) {
		url = [_handler parentURL];
		
		if(![url isEqual:[_handler URL]]) {
			name = [[[_handler URL] path] lastPathComponent];
			[self _loadURL:url];
			[self _updateImage];
			[_tableView selectRowWithStringValue:name];
		}
	}
}



- (IBAction)openMenu:(id)sender {
	[self _loadURL:[sender representedObject]];
	[self _updateImage];
}



- (void)openFile:(id)sender {
	FHFile	*file;
	
	file = [self _selectedFile];
	
	if([file isDirectory])
		[self _loadURL:[file URL]];
	else
		[[NSWorkspace sharedWorkspace] openURL:[[file URL] URL]];
}



- (void)openDirectory:(id)sender {
	FHFile	*file;
	
	file = [self _selectedFile];
	
	if([file isDirectory])
		[self _loadURL:[file URL]];
}



- (IBAction)firstFile:(id)sender {
	if([[_handler files] count] == 0)
		return;
	
	[self _selectFileAtIndex:0];
}




- (IBAction)lastFile:(id)sender {
	unsigned int	count;

	count = [[_handler files] count];
	
	if(count == 0)
		return;
	
	[self _selectFileAtIndex:count - 1];
}




- (IBAction)previousImage:(id)sender {
	NSArray			*files;
	int				row;
	unsigned int	i, count, index;
	
	row = [_tableView selectedRow];
	
	if(row < 0)
		return;
	
	files = [_handler files];
	count = [files count];
	index = NSNotFound;
	
	if(row > 0) {
		for(i = row - 1; i >= 0; i--) {
			if(![[files objectAtIndex:i] isDirectory]) {
				index = i;
				
				break;
			}
		}
	}
		
	if(index != NSNotFound)
		[self _selectFileAtIndex:index];
}



- (IBAction)nextImage:(id)sender {
	NSArray			*files;
	int				row;
	unsigned int	i, count, index;

	row = [_tableView selectedRow];
	files = [_handler files];
	count = [files count];
	
	if(row < 0 || (unsigned int) row == count - 1)
		return;
	
	index = NSNotFound;
	
	if((unsigned int) row + 1 < count) {
		for(i = row + 1; i < count; i++) {
			if(![[files objectAtIndex:i] isDirectory]) {
				index = i;
				
				break;
			}
		}
	}
	
	if(index != NSNotFound)
		[self _selectFileAtIndex:index];
}



- (IBAction)previousPage:(id)sender {
	NSArray			*files;
	int				row;
	unsigned int	i, count, step, index;
	
	row = [_tableView selectedRow];
	
	if(row <= 0)
		return;
	
	files = [_handler files];
	count = [files count];
	index = 0;
	step = (double) count / 10.0;
	step = WI_CLAMP(step, 2, 10);

	if((unsigned int) row > step) {
		for(i = row - step; i > 0; i--) {
			if(![[files objectAtIndex:i] isDirectory]) {
				index = i;
				
				break;
			}
		}
		
		index = row - step;
	}
	
	[self _selectFileAtIndex:index];
}



- (IBAction)nextPage:(id)sender {
	NSArray			*files;
	int				row;
	unsigned int	i, count, step, index;
	
	row = [_tableView selectedRow];
	files = [_handler files];
	count = [files count];
	
	if(row < 0 || (unsigned int) row == count - 1)
		return;
	
	index = count - 1;
	step = (double) count / 10.0;
	step = WI_CLAMP(step, 2, 10);
	
	if((unsigned int) row + step < count) {
		for(i = row + step; i < count; i++) {
			if(![[files objectAtIndex:i] isDirectory]) {
				index = i;
				
				break;
			}
		}
		
		index = row + step;
	}
	
	[self _selectFileAtIndex:index];
}



- (IBAction)reload:(id)sender {
	[self _reloadURL:[_handler URL]];
}



- (IBAction)zoom:(id)sender {
	FHImageScaling		scaling;
	
	if(_fullscreenWindow) {
		scaling = [_fullscreenImageView imageScaling];
		
		if(scaling != FHScaleProportionally)
			scaling = FHScaleProportionally;
		else
			scaling = FHScaleStretched;

		[_fullscreenImageView setImageScaling:scaling];

		[FHSettings setInt:scaling forKey:FHFullscreenImageScalingMethod];
	} else {
		scaling = [_imageView imageScaling];
		
		if(scaling != FHScaleProportionally)
			scaling = FHScaleProportionally;
		else
			scaling = FHScaleNone;

		[_imageView setImageScaling:scaling];

		[self _updateRightStatus];
		
		[FHSettings setInt:scaling forKey:FHImageScalingMethod];
	}
}



- (IBAction)rotateRight:(id)sender {
	float		rotation;
	
	rotation = [_imageView imageRotation];
	
	if(rotation == -270.0f)
		rotation = 0.0f;
	else
		rotation -= 90.0f;
	
	[_imageView setImageRotation:rotation];
	[_fullscreenImageView setImageRotation:rotation];
	
	[self _updateRightStatus];

	[FHSettings setFloat:rotation forKey:FHImageRotation];
}



- (IBAction)rotateLeft:(id)sender {
	float		rotation;
	
	rotation = [_imageView imageRotation];
	
	if(rotation == 270.0f)
		rotation = 0.0f;
	else
		rotation += 90.0f;
	
	[_imageView setImageRotation:rotation];
	[_fullscreenImageView setImageRotation:rotation];
	
	[self _updateRightStatus];

	[FHSettings setFloat:rotation forKey:FHImageRotation];
}



- (IBAction)slideshow:(id)sender {
	[NSApp beginSheet:_screenPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(slideshowPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)slideshowPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSScreen		*screen;
	NSRect			screenRect;
	int				screenNumber;

	[_screenPanel close];
	
	if(returnCode == NSRunStoppedResponse) {
		// --- save in prefs
		[FHSettings setInt:[_screenPopUpButton indexOfSelectedItem] forKey:FHFullscreenScreen];
		[FHSettings setInt:[_screenBackgroundPopUpButton tagOfSelectedItem] forKey:FHFullscreenBackground];
		[FHSettings setBool:[_screenAutoSwitchButton state] forKey:FHFullscreenAutoSwitch];
		[FHSettings setInt:[_screenAutoSwitchTextField intValue] forKey:FHFullscreenAutoSwitchTime];
		
		// --- get screen
		screenNumber = [FHSettings intForKey:FHFullscreenScreen];
		
		if((unsigned int) screenNumber > [[NSScreen screens] count])
			screenNumber = 0;
		
		screen = [[NSScreen screens] objectAtIndex:screenNumber];
		screenRect = [screen frame];
		screenRect.origin.x = screenRect.origin.y = 0;
		
		// --- create fullscreen window
		_fullscreenWindow = [[FHFullscreenWindow alloc]
			initWithContentRect:screenRect
					  styleMask:NSBorderlessWindowMask
						backing:NSBackingStoreBuffered
						  defer:YES
						 screen:screen];
		
		[_fullscreenWindow setLevel:NSScreenSaverWindowLevel];
		[_fullscreenWindow setDelegate:self];
		[_fullscreenWindow setReleasedWhenClosed:YES];
		[_fullscreenWindow setTitle:[[self window] title]];
		[_fullscreenImageView setBackgroundColor:[_screenBackgroundPopUpButton representedObjectOfSelectedItem]];
		[_fullscreenImageView setImageScaling:[FHSettings intForKey:FHFullscreenImageScalingMethod]];
		[_fullscreenImageView setImageRotation:[_imageView imageRotation]];
		[_fullscreenPanel setFrame:screenRect display:NO];
		[_fullscreenWindow setContentView:[[_fullscreenPanel contentView] retain]];
		[[self window] orderOut:self];
		[_fullscreenWindow makeKeyAndOrderFront:self];
		[self _updateImage];

		if([FHSettings boolForKey:FHFullscreenAutoSwitch]) {
			_loadImageTimer = [[NSTimer scheduledTimerWithTimeInterval:[FHSettings intForKey:FHFullscreenAutoSwitchTime]
																target:self
															  selector:@selector(loadFileTimer:)
															  userInfo:NULL
															   repeats:YES] retain];
		}
	}
}



- (IBAction)autoSwitch:(id)sender {
	[_screenAutoSwitchTextField setEnabled:[_screenAutoSwitchButton state]];
}



- (IBAction)revealInFinder:(id)sender {
	if(![_revealInFinderButton isEnabled])
		return;
	
	[[NSWorkspace sharedWorkspace] selectFile:[[self _selectedFile] path] inFileViewerRootedAtPath:NULL];
}



- (IBAction)setAsDesktopPicture:(id)sender {
	[[NSWorkspace sharedWorkspace] changeDesktopPicture:[[self _selectedFile] path]];
}



- (IBAction)delete:(id)sender {
	FHFile			*file;
	unsigned int	row, count;
	
	if(![_moveToTrashButton isEnabled])
		return;
	
	row = [_tableView selectedRow];
	file = [self _fileAtIndex:row];

	[[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation 
					  source:[[file path] stringByDeletingLastPathComponent]
				 destination:@"/"
					   files:[NSArray arrayWithObject:[file name]]
						 tag:NULL];
		
	[_handler removeFile:file];
	count = [_handler numberOfFiles];

	if(count > 1 && row == count - 1)
		[_tableView selectRow:row - 1 byExtendingSelection:NO];

	[_tableView reloadData];
	[self _loadFile:[self _selectedFile]];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
	return [[_handler files] count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	FHFile		*file;
	FHImage		*icon;
	
	file = [self _fileAtIndex:row];
	icon = [file thumbnail];
	
	if(!icon)
		icon = [file icon];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[file name],	FHFileCellNameKey,
		icon,			FHFileCellIconKey,
		NULL];
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(int)row {
	return [[self _fileAtIndex:row] name];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	int		selectedRow;
	
	[self _updateImage];
	
	selectedRow = [_tableView selectedRow];
	
	if(!_switchingURL && selectedRow < (int) _selectedRow) {
		if([_scrollView hasVerticalScroller])
			[_imageView scrollPoint:NSZeroPoint];
	}
	
	[_loadImageLock lock];
	_selectedRow = selectedRow;
	_imageCounter++;
	[_loadImageLock unlockWithCondition:1];
}

@end
