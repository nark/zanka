/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

#import "NSFileManagerAdditions.h"
#import "NSImageAdditions.h"
#import "NSStringAdditions.h"
#import "FHCache.h"
#import "FHController.h"
#import "FHBrowserCell.h"
#import "FHBrowserView.h"
#import "FHFile.h"
#import "FHFullscreenWindow.h"
#import "FHImageView.h"
#import "FHHandler.h"
#import "FHSettings.h"
#import "FHSplitView.h"

@implementation FHController

- (void)awakeFromNib {
	NSArray			*screens;
	NSMenuItem		*item;
	NSImage			*icon;
	NSString		*path;
	int				i;
	
	// --- create static classes
	_settings = [[FHSettings alloc] init];
	_cache = [[FHCache alloc] init];
	
	// --- splitview position
	[_splitView setAutosaveName:@"FHBrowser"];
	
	// --- window position
	[self setWindowFrameAutosaveName:@"FHFootagehead"];
	[self setShouldCascadeWindows:NO];
	
	// --- URL settings
	[_openURLExtractMatrix selectCellWithTag:[FHSettings intForKey:FHExtract]];

	// --- screen settings
	[_screenPopUpButton removeAllItems];
	screens = [NSScreen screens];
	
	for(i = 0; i < [screens count]; i++) {
		[_screenPopUpButton addItemWithTitle:[NSString stringWithFormat:
			NSLocalizedString(@"Screen %u, %.0fx%.0f", @""),
			i + 1,
			[[screens objectAtIndex:i] frame].size.width,
			[[screens objectAtIndex:i] frame].size.height]];
	}
	
	[_screenPopUpButton selectItemAtIndex:[FHSettings intForKey:FHScreen]];

	[_screenAutoSwitchButton setState:[FHSettings boolForKey:FHAutoSwitch]];
	[_screenAutoSwitchTextField setEnabled:[FHSettings boolForKey:FHAutoSwitch]];
	[_screenAutoSwitchTextField setIntValue:[FHSettings intForKey:FHAutoSwitchTime]];

	// --- thread spinner
	[_progressIndicator setUsesThreadedAnimation:YES];
	
	// --- open last directory by default (unset if started by opening a file)
	_openLast = YES;

	// --- clear menu
	[_menu removeAllItems];
	
	// --- load disks to menu
	[self updateVolumes];
	
	// --- add home directory to menu
	path = NSHomeDirectory();
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
									  action:@selector(openMenu:)
							   keyEquivalent:@"H"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	_items++;
	[item release];
	
	// --- add desktop directory to menu
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
									  action:@selector(openMenu:)
							   keyEquivalent:@"d"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	_items++;
	[item release];
	
	// --- add pictures directory to menu
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
									  action:@selector(openMenu:)
							   keyEquivalent:@"P"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	_items++;
	[item release];
	
	// --- add spacer to menu
	[[_menu menu] addItem:[NSMenuItem separatorItem]];
	_items++;
	
	// --- register with these
	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidMountNotification:)
			   name:NSWorkspaceDidMountNotification
			 object:NULL];

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidUnmountNotification:)
			   name:NSWorkspaceDidUnmountNotification
			 object:NULL];
}



#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	int		hint;
	
	// --- get hint
	hint = [FHSettings intForKey:FHOpenHint];
	
	// --- if option redirect to home
	if((GetCurrentKeyModifiers() & optionKey) != 0) {
		[FHSettings setObject:[[NSURL fileURLWithPath:NSHomeDirectory()] absoluteString]
					   forKey:FHOpenURL];
		
		hint = FHHandlerHintNone;
	}
		
	// --- go to last open directory
	if(_openLast) {
		NSURL		*url;
		
		// --- start spinning
		[self startSpinning];

		// --- get url
		url = [NSURL URLWithString:[FHSettings objectForKey:FHOpenURL]];

		if([url isFileURL] && ![NSFileManager directoryExistsAtPath:[url path]]) {
			url = [NSURL fileURLWithPath:NSHomeDirectory()];
			hint = FHHandlerHintNone;
		}

		// --- create handler
		_handler = [[FHHandler alloc] initWithURL:url hint:hint];
		
		// --- set files
		[_browserView insertFiles:[_handler files]];
		[_browserView selectCellAtRow:0 column:0];
		
		// --- adjust interface
		[self selectRow:[_browserView selectedRow]];
		[self update];

		// --- stop spinning
		[self stopSpinning];
	}
	
	// --- show window
	[[self window] makeFirstResponder:_browserView];
	[self showWindow:self];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[FHSettings setObject:[[_handler URL] absoluteString] forKey:FHOpenURL];
	[FHSettings setObject:[NSNumber numberWithInt:[_handler hint]] forKey:FHOpenHint];
	
	[FHCache purgeTemporaryPaths];
}



- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
	return YES;
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	NSString		*folderPath, *filename = NULL;
	
	// --- get path to the folder
	if([NSFileManager directoryExistsAtPath:path]) {
		folderPath = path;
	} else {
		filename = [path lastPathComponent];
		folderPath = [path stringByDeletingLastPathComponent];
	}

	// --- start spinning
	[self startSpinning];
	
	// --- kill old handler
	[_handler release];
	
	// --- create handler
	_handler = [[FHHandler alloc] initWithURL:[NSURL fileURLWithPath:folderPath]];
	
	// --- set files
	[_browserView insertFiles:[_handler files]];
	
	// --- select file
	if(filename)
		[_browserView selectCellAtRow:[_browserView indexOfCellWithName:filename] column:0];
	else
		[_browserView selectCellAtRow:0 column:0];
	
	// --- adjust interface
	[self selectRow:[_browserView selectedRow]];
	[self update];
	
	// --- stop spinning
	[self stopSpinning];

	// --- don't open the last open directory
	_openLast = NO;
		
	return YES;
}



- (void)workspaceDidMountNotification:(NSNotification *)notification {
	[self updateVolumes];
}



- (void)workspaceDidUnmountNotification:(NSNotification *)notification {
	[self updateVolumes];
}



- (void)windowDidResize:(NSNotification *)notification {
	[self updateStatus];
}



- (void)windowWillClose:(NSNotification *)notification {
	if([notification object] == _fullscreenWindow) {
		FHBrowserCell	*cell;
		int				row;
		
		// --- get file
		row = [_fullscreenWindow position];
		row = [[_handler files] indexOfObject:[[_handler images] objectAtIndex:row]];
		
		// --- select where fullscreen exited
		if(row >= 0) {
			cell = [_browserView cellAtRow:row column:0];
			[_browserView selectCell:cell];
		}
		
		// --- clear self
		[[_fullscreenWindow timer] invalidate];
		_fullscreenWindow = NULL;
		
		// --- open image
		[self selectRow:[_browserView selectedRow]];
		
		// --- raise self
		[[self window] makeKeyAndOrderFront:self];
	}
}



- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	return 49;
}



- (float)splitView:(NSSplitView *)splitView constrainSplitPosition:(float)proposedPosition ofSubviewAt:(int)offset {
	int			position;

	if(([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0) {
		position = proposedPosition - 17;
		
		if(position >= 128)
			return 145;
		else if(position >= 64)
			return 81;
		else if(position >= 48)
			return 65;
		else
			return 49;
	}
	
	return proposedPosition;
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _splitView) {
		NSSize		size, leftSize, rightSize;
		
		// --- get split view size
		size = [_splitView frame].size;
		
		// --- set static left part size
		leftSize = [_browserScrollView frame].size;
		leftSize.height = size.height;
		
		// --- set dynamic right part size
		rightSize.height = size.height;
		rightSize.width = size.width - [_splitView dividerThickness] - leftSize.width;
		
		// --- set new frames
		[_browserScrollView setFrameSize:leftSize];
		[_imageScrollView setFrameSize:rightSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		handled = NO;
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:)) {
		if([[[NSApp currentEvent] characters] characterAtIndex:0] == NSEnterCharacter) {
            [self submitSheet:sender];
            
            handled = YES;
        }
    }
    
    return handled;
}



- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton) {
		NSURL		*url;
		
		// --- start spinning
		[self startSpinning];

		// --- get URL
		url = [[sheet URLs] objectAtIndex:0];
		
		// --- kill old handler
		[_handler release];

		// --- create handler
		_handler = [[FHHandler alloc] initWithURL:url];

		// --- set files
		[_browserView insertFiles:[_handler files]];
		[_browserView selectCellAtRow:0 column:0];
			
		// --- adjust interface
		[self selectRow:[_browserView selectedRow]];
		[self update];

		// --- stop spinning
		[self stopSpinning];
	}
}



- (void)openURLPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	// --- close sheet
	[_openURLPanel close];
	
	if(returnCode == NSRunStoppedResponse) {
		NSURL		*url;
		NSString	*string;
		NSRange		range;
		
		// --- start spinning
		[self startSpinning];
		
		// --- set setting
		[FHSettings setObject:[NSNumber numberWithInt:[[_openURLExtractMatrix selectedCell] tag]]
					   forKey:FHExtract];
		
		// --- fix schemeless
		string = [_openURLTextView string];
		range = [string rangeOfString:@"://"];
		
		if(range.location == NSNotFound)
			string = [NSString stringWithFormat:@"http://%@", string];
		
		// --- get URL
		url = [NSURL URLWithString:string];

		// --- kill old handler
		[_handler release];
		
		// --- create handler
		_handler = [[FHHandler alloc] initWithURL:url];
		
		// --- set files
		[_browserView insertFiles:[_handler files]];
		[_browserView selectCellAtRow:0 column:0];
		
		// --- adjust interface
		[self selectRow:[_browserView selectedRow]];
		[self update];
		
		// --- stop spinning
		[self stopSpinning];
	}
}



- (void)screenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	// --- close sheet
	[_screenPanel close];
	
	if(returnCode == NSRunStoppedResponse) {
		// --- save in prefs
		[FHSettings setObject:[NSNumber numberWithInt:[_screenPopUpButton indexOfSelectedItem]]
					   forKey:FHScreen];
		[FHSettings setObject:[NSNumber numberWithBool:([_screenAutoSwitchButton state] == NSOnState)]
					   forKey:FHAutoSwitch];
		[FHSettings setObject:[NSNumber numberWithInt:[_screenAutoSwitchTextField intValue]]
					   forKey:FHAutoSwitchTime];

		// --- start
		[self startSlideshow];
	}
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSOpenPanel		*openPanel;

	// --- get open panel
	openPanel = [NSOpenPanel openPanel];
	
	// --- set options
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	
	// --- run sheet
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (IBAction)openURL:(id)sender {
	// --- select
	[_openURLTextView setSelectedRange:NSMakeRange(0, [[_openURLTextView string] length])];

	// --- show sheet
	[NSApp beginSheet:_openURLPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(openURLPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)openFile:(FHFile *)file {
	// --- start spinning
	[self startSpinning];

	// --- kill old handler
	[_handler release];
	
	// --- create handler
	_handler = [[FHHandler alloc] initWithURL:[file URL] hint:[file hint]];
	
	// --- set files
	[_browserView insertFiles:[_handler files]];
	[_browserView selectCellAtRow:0 column:0];
	
	// --- adjust interface
	[self selectRow:[_browserView selectedRow]];
	[self update];
	
	// --- stop spinning
	[self stopSpinning];
}



- (IBAction)openParent:(id)sender {
	NSURL		*parentURL, *selectedURL;
	int			row;
	
	// --- get parent URL
	parentURL = [_handler parentURL];
	
	if(![parentURL isEqual:[_handler relativeURL]]) {
		// --- start spinning
		[self startSpinning];

		// --- save URL
		selectedURL = [[_handler relativeURL] retain];
		
		// --- kill old handler
		[_handler release];
		
		// --- create handler
		_handler = [[FHHandler alloc] initWithURL:parentURL];
		
		// --- set files
		[_browserView insertFiles:[_handler files]];
		
		// --- select row
		row = [_browserView indexOfCellWithName:
			[[[selectedURL path] lastPathComponent] stringByReplacingURLPercentEscapes]];
		[_browserView selectCellAtRow:row >= 0 ? row : 0 column:0];

		// --- release URL
		[selectedURL release];
		
		// --- adjust interface
		[self selectRow:[_browserView selectedRow]];
		[self update];
		
		// --- stop spinning
		[self stopSpinning];
	}
}



- (IBAction)openMenu:(id)sender {
	NSURL		*url;
	
	// --- start spinning
	[self startSpinning];

	// --- get url
	url = [sender representedObject];

	// --- kill old handler
	[_handler release];
	
	// --- create handler
	_handler = [[FHHandler alloc] initWithURL:url];
	
	// --- set files
	[_browserView insertFiles:[_handler files]];
	[_browserView selectCellAtRow:0 column:0];
	
	// --- adjust interface
	[self selectRow:[_browserView selectedRow]];
	[self update];
	
	// --- stop spinning
	[self stopSpinning];
}



#pragma mark -

- (IBAction)submitSheet:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSRunStoppedResponse];
}



- (IBAction)cancelSheet:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSRunAbortedResponse];
}



#pragma mark -

- (IBAction)reload:(id)sender {
	NSURL		*url, *selectedURL;
	int			row;
	
	// --- start spinning
	[self startSpinning];
	
	// --- save URLs
	url = [[_handler URL] retain];
	selectedURL = [[[[_browserView selectedCell] file] URL] retain];
	
	// --- kill old handler
	[_handler release];
	
	// --- create handler
	_handler = [[FHHandler alloc] initWithURL:url];
	
	// --- set files
	[_browserView insertFiles:[_handler files]];
	
	// --- select row
	row = [_browserView indexOfCellWithName:
		[[[selectedURL path] lastPathComponent] stringByReplacingURLPercentEscapes]];
	[_browserView selectCellAtRow:row >= 0 ? row : 0 column:0];
	
	// --- release URLs
	[url release];
	[selectedURL release];
	
	// --- adjust interface
	[self selectRow:[_browserView selectedRow]];
	[self update];
	
	// --- stop spinning
	[self stopSpinning];
}



- (IBAction)slideshow:(id)sender {
	[NSApp beginSheet:_screenPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(screenPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (IBAction)slideshowButtons:(id)sender {
	[_screenAutoSwitchTextField setEnabled:
		([_screenAutoSwitchButton state] == NSOnState)];
}



- (IBAction)revealInFinder:(id)sender {
	// --- might be disabled
	if(![_revealInFinderButton isEnabled])
		return;
	
	// --- select in finder
	[[NSWorkspace sharedWorkspace] selectFile:[[[_browserView selectedCell] file] path]
					 inFileViewerRootedAtPath:NULL];
}



- (IBAction)delete:(id)sender {
	NSURL			*url;
	FHBrowserCell	*cell;
	int				row;
	
	// --- might be disabled
	if(![_moveToTrashButton isEnabled])
		return;
	
	// --- start spinning
	[self startSpinning];

	// --- move to trash
	cell = [_browserView selectedCell];

	[[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation 
		source:[[[cell file] path] stringByDeletingLastPathComponent]
		destination:@"/"
		files:[NSArray arrayWithObject:[[[cell file] path] lastPathComponent]]
		tag:NULL];

	// --- get cell above deleted
	row = [_browserView selectedRow];
	
	if(row > 0)
		row--;

	// --- get url
	url = [[_handler URL] retain];
	
	// --- kill old handler
	[_handler release];
	
	// --- create handler
	_handler = [[FHHandler alloc] initWithURL:url];
	
	// --- release url
	[url release];
	
	// --- set files
	[_browserView insertFiles:[_handler files]];
	[_browserView selectCellAtRow:row column:0];
	
	// --- adjust interface
	[self selectRow:[_browserView selectedRow]];
	[self update];

	// --- stop spinning
	[self stopSpinning];
}



#pragma mark -

- (FHBrowserView *)browserView {
	return _browserView;
}



- (FHHandler *)handler {
	return _handler;
}



- (FHImageView *)fullscreenImageView {
	return _fullscreenImageView;
}



#pragma mark -

- (void)startSlideshow {
	NSScreen		*screen;
	NSArray			*files;
	NSRect			screenRect;
	int				screenNumber;
	
	// --- get images
	files = [_handler files];
	
	if([files count] == 0)
		return;
	
	// --- get screen
	screenNumber = [[FHSettings objectForKey:FHScreen] intValue];
	
	if(screenNumber > [[NSScreen screens] count])
		screenNumber = 0;
	
	screen = [[NSScreen screens] objectAtIndex:screenNumber];
	
	// --- get rect of screen
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
	[_fullscreenWindow setBackgroundColor:[NSColor blackColor]];
	[_fullscreenWindow setTitle:[[self window] title]];
	
	// --- add content view from fullscreen panel
	[_fullscreenPanel setFrame:screenRect display:NO];
	[_fullscreenWindow setContentView:[[_fullscreenPanel contentView] retain]];
	
	// --- show window
	[_fullscreenWindow makeKeyAndOrderFront:self];
}



- (void)selectRow:(int)row {
	NSArray		*files;
	FHFile		*file;
	
	// --- ignore
	if(row < 0)
		return;

	// --- clear previous
	[_file release];
	_file = NULL;
	
	// --- get files
	files = [_handler files];
	
	if([files count] == 0)
		return;
	
	// --- get this file
	file = [[_handler files] objectAtIndex:row];
	
	// --- check for directory
	if([file isDirectory]) {
		// --- clear image
		[_imageView setImage:NULL];
		[_rightStatusTextField setStringValue:@""];
	} else {
		// --- save file
		_file = [file retain];

		// --- open image
		[self loadImage:file];
	}
	
	// --- set responder
	[[self window] makeFirstResponder:_browserView];
}



- (void)imageDidLoad:(NSDictionary *)dictionary {
	NSArray		*files;
	NSImage		*image;
	FHFile		*file, *nextFile;
	BOOL		next = NO;
	int			row;
	
	file = [dictionary objectForKey:FHFileKey];
	image = [dictionary objectForKey:FHImageKey];
	
	if(image) {
		if(!NSEqualSizes([image size], NSZeroSize)) {
			// --- hide cursor
			[NSCursor setHiddenUntilMouseMoves:YES];
			
			if(_fullscreenWindow) {
				if([[_handler images] indexOfObject:file] == [_fullscreenWindow position]) {
					// --- display image
					[_fullscreenImageView setImage:[image smoothedImage]];
					
					// --- reset timer
					if([_fullscreenWindow timer]) {
						[[_fullscreenWindow timer] setFireDate:[NSDate dateWithTimeIntervalSinceNow:
							[FHSettings intForKey:FHAutoSwitchTime]]];
					}
					
					// --- continue
					next = YES;
				}
			} else {
				if([[_handler files] indexOfObject:file] == [_browserView selectedRow]) {
					// --- display image
					[_imageView setImage:[image smoothedImage]];
					
					// --- adjust interface
					[self updateStatus];
					
					// --- continue
					next = YES;
				}
			}
			
			if(next) {
				// --- load next?
				files = [_handler files];
				row = [files indexOfObject:file];
				
				if([files count] > row + 1) {
					nextFile = [files objectAtIndex:row + 1];
					
					if(![nextFile isDirectory])
						[self loadImage:nextFile];
				}
			}
		}
	
		[image release];
	} else {
		// --- couldn't open image, clear image view
		[_imageView setImage:[NSImage imageNamed:@"Error"]];
		
		// --- display status
		[_rightStatusTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"error opening image", @"")]];
	}

	[self stopSpinning];
}



- (void)loadImage:(FHFile *)file {
	NSImage		*image;
	
	[self startSpinning];

	image = [FHCache imageForURL:[file URL]];
	
	if(image) {
		[image retain];

		[self performSelector:@selector(imageDidLoad:)
				   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
					   file,		FHFileKey,
					   image,		FHImageKey,
					   NULL]];
	} else {
		[NSThread detachNewThreadSelector:@selector(loadImageThread:)
								 toTarget:self
							   withObject:file];
	}
}



- (void)loadImageThread:(id)arg {
	NSAutoreleasePool   *pool;
	NSImage				*image;
	FHFile				*file = arg;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	image = [[NSImage alloc] initWithSize:NSMakeSize(0, 0)];
	[FHCache setImage:image forURL:[file URL]];
	[image release];
	
	image = [[NSImage alloc] initWithContentsOfURL:[file URL]];

	[FHCache setImage:image forURL:[file URL]];
	
	[self performSelectorOnMainThread:@selector(imageDidLoad:)
						   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
										file,		FHFileKey,
										image,		FHImageKey,
										NULL]
						waitUntilDone:NO];
	
	[pool release];
}



#pragma mark -

- (void)startSpinning {
	if(_spinners == 0)
		[_progressIndicator startAnimation:self];
	
	_spinners++;
}



- (void)stopSpinning {
	_spinners--;
	
	if(_spinners == 0)
		[_progressIndicator stopAnimation:self];
}



#pragma mark -

- (void)update {
	[self updateButtons];
	[self updateMenu];
	[self updateStatus];
}



- (void)updateButtons {
	if([_handler isLocal]) {
		[_revealInFinderButton setEnabled:YES];
		[_moveToTrashButton setEnabled:YES];
	} else {
		[_revealInFinderButton setEnabled:NO];
		[_moveToTrashButton setEnabled:NO];
	}
}



- (void)updateVolumes {
	NSEnumerator	*enumerator;
	NSMutableArray  *volumes;
	NSMenuItem		*item;
	NSString		*volume, *path;
	NSImage			*icon;
	BOOL			loop = YES;
	int				i = 0;
	
	// --- delete all items up to and including the first separator
	if([_menu numberOfItems] > 0) {
		while(loop) {
			if([[_menu itemAtIndex:0] isSeparatorItem])
				loop = NO;

			[_menu removeItemAtIndex:0];
			
			_items--;
		}
	}
				
			
	// --- get volumes
	volumes = [NSMutableArray arrayWithArray:
		[[NSFileManager defaultManager] directoryContentsAtPath:@"/Volumes/"]];
	
	// --- loop over volumes
	enumerator = [volumes objectEnumerator];
	
	while((volume = [enumerator nextObject])) {
		path = [NSString stringWithFormat:@"/Volumes/%@", volume];
		item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:volume]
										  action:@selector(openMenu:)
								   keyEquivalent:@""];
		icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		[icon setSize:NSMakeSize(16, 16)];
		[item setRepresentedObject:[NSURL fileURLWithPath:path]];
		[item setImage:icon];
		[[_menu menu] insertItem:item atIndex:i];
		_items++;
		[item release];
		
		i++;
	}
	
	// --- add spacer
	[[_menu menu] insertItem:[NSMenuItem separatorItem] atIndex:i];
	_items++;
}



- (void)updateMenu {
	NSArray			*displayURLComponents, *fullURLComponents;
	NSMenuItem		*item;
	NSImage			*icon;
	NSString		*name;
	int				i, count, items;

	// --- get components
	displayURLComponents = [_handler displayURLComponents];
	fullURLComponents = [_handler fullURLComponents];
	count = [displayURLComponents count];
	items = [_menu numberOfItems];
	
	for(i = 0; i < count; i++) {
		if(_items + i < items) {
			// --- get item occupying this slot
			name = [[_menu itemAtIndex:i + _items] title];
			
			// --- skip if we equal
			if([name isEqualToString:[displayURLComponents objectAtIndex:i]])
				continue;

			// ---- remove if not equal
			[_menu removeItemAtIndex:_items + i];
			items--;
		}
		
		// --- insert new item if not equal, or no item in slot
		item = [[NSMenuItem alloc] initWithTitle:[displayURLComponents objectAtIndex:i]
										  action:@selector(openMenu:)
								   keyEquivalent:@""];
		[item setRepresentedObject:[fullURLComponents objectAtIndex:i]];
		
		if(![[fullURLComponents objectAtIndex:i] isFileURL]) {
			icon = [NSImage imageNamed:@"URL"];
			[item setImage:icon];
		} else {
			icon = [FHCache fileIconForPath:[displayURLComponents objectAtIndex:i]];
			
			if(!icon) {
				icon = [[NSWorkspace sharedWorkspace] iconForFile:[displayURLComponents objectAtIndex:i]];
				[icon setSize:NSMakeSize(16, 16)];
				
				[FHCache setFileIcon:icon forPath:[displayURLComponents objectAtIndex:i]];
			}
			
			[item setImage:icon];
		}
		
		// --- add item
		[[_menu menu] insertItem:item atIndex:_items + i];
		items++;
		[item release];
	}
	
	// --- remove excess items
	while(items > _items + count) {
		[_menu removeItemAtIndex:_items + count];

		items--;
	}
	
	// --- select last
	[_menu selectItem:[_menu lastItem]];
}



- (void)updateStatus {
	double		imageWidth, imageHeight, zoom = 100;
	double		frameWidth, frameHeight;
	
	// --- set left side
	[_leftStatusTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%u %@", @""),
		[_handler numberOfImages],
		[_handler numberOfImages] == 1
			? NSLocalizedString(@"image", @"")
			: NSLocalizedString(@"images", @"")]];

	// --- set right side
	if(_file) {
		// --- get image size
		imageWidth = [[_imageView image] size].width;
		imageHeight = [[_imageView image] size].height;
		
		if(imageWidth <= 0.0 || imageHeight <= 0.0)
			return;
		
		// --- get frame size
		frameWidth = [_imageView frame].size.width;
		frameHeight = [_imageView frame].size.height;

		// --- scale
		if(imageHeight > frameHeight && imageWidth <= frameWidth)
			frameWidth = frameHeight * (imageWidth / imageHeight);

		if(imageWidth > frameWidth && imageHeight <= frameHeight)
			frameHeight = frameWidth * (imageHeight / imageWidth);
		
		// --- get zoom level
		zoom = 100.0 * ((frameWidth * frameHeight) / (imageWidth * imageHeight));
		
		if(zoom > 100.0)
			zoom = 100.0;
		
		// --- display status
		[_rightStatusTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"%@, %.0fx%.0f, zoomed at %.0f%%", @""),
			[_file name],
			[[_imageView image] size].width,
			[[_imageView image] size].height,
			zoom]];
	}
}

@end
