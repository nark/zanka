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

#import "FHController.h"
#import "FHBrowserCell.h"
#import "FHBrowserView.h"
#import "FHFullscreenWindow.h"
#import "FHImageView.h"
#import "FHSettings.h"
#import "FHSplitView.h"
#import "NSImageAdditions.h"
#import "NSStringAdditions.h"

@implementation FHController

- (void)awakeFromNib {
	NSMenuItem		*item;
	NSImage			*icon;
	NSString		*path;
	
	// --- create static classes
	[FHSettings create];
	
	// --- splitview position
	[_splitView setAutosaveName:@"Browser"];
	
	// --- window position
	[self setWindowFrameAutosaveName:@"Footagehead"];
	[self setShouldCascadeWindows:NO];
	
	// --- thread spinner
	[_progressIndicator setUsesThreadedAnimation:YES];
	
	// --- open last directory by default (unset if started by opening a file)
	_openLast = YES;	

	// --- clear menu
	[_menu removeAllItems];
	
	// --- add home directory to menu
	path = NSHomeDirectory();
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
							   action:@selector(menu:)
							   keyEquivalent:@"H"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	[item release];
	
	// --- add desktop directory to menu
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
							   action:@selector(menu:)
							   keyEquivalent:@"d"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	[item release];
	
	// --- add pictures directory to menu
	path = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
	item = [[NSMenuItem alloc] initWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
							   action:@selector(menu:)
							   keyEquivalent:@"P"];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16, 16)];
	[item setRepresentedObject:[NSURL fileURLWithPath:path]];
	[item setImage:icon];
	[[_menu menu] addItem:item];
	[item release];
	
	// --- add spacer to menu
	[_menu addItemWithTitle:@""];
}



#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	// --- if option redirect to home
	if((GetCurrentKeyModifiers() & optionKey) != 0)
		[FHSettings setObject:[[NSURL fileURLWithPath:NSHomeDirectory()] absoluteString] forKey:FHOpenURL];
		
	// --- go to last open directory
	if(_openLast)
		[_browserView openFolder:[NSURL URLWithString:[FHSettings objectForKey:FHOpenURL]] select:NULL];
	
	// --- show window
	[[self window] makeFirstResponder:_browserView];
	[self showWindow:self];
}



- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
	return YES;
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	BOOL	isDir;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
		if(isDir) {
			// --- open directory
			[_browserView openFolder:[NSURL fileURLWithPath:path] select:NULL];
		} else {
			// --- open directory and select this
			[_browserView openFolder:[NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]]
						  select:[NSURL fileURLWithPath:path]];
		}
		
		_openLast = NO;
		
		return YES;
	}

	return NO;
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



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		handled = NO;
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:)) {
		if([[[NSApp currentEvent] characters] characterAtIndex:0] == NSEnterCharacter) {
            [self okOpenURL:self];
            
            handled = YES;
        }
    }
    
    return handled;
}



- (void)windowDidResize:(NSNotification *)notification {
	[self updateStatus:NULL];
}



- (void)windowWillClose:(NSNotification *)notification {
	if([notification object] == _fullscreenWindow) {
		// --- select where fullscreen exited
		[_browserView selectCellAtRow:[_fullscreenWindow position] column:0];
		[_browserView openImage:[[_browserView cellAtRow:[_fullscreenWindow position] column:0] url]];
		
		// --- raise self
		[[self window] makeKeyAndOrderFront:self];
	}
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSOpenPanel		*openPanel;
	NSString		*path;
	BOOL			isDir;

	// --- get open panel
	openPanel = [NSOpenPanel openPanel];
	
	// --- set options
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	
	// --- run panel
	if([openPanel runModalForDirectory:NULL file:NULL types:NULL] == NSOKButton) {
		// --- get path
		path = [[openPanel filenames] objectAtIndex:0];

		if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
			if(isDir) {
				// --- open directory
				[_browserView openFolder:[NSURL fileURLWithPath:path] select:NULL];
			} else {
				// --- open directory and select this
				[_browserView openFolder:[NSURL fileURLWithPath:[path stringByDeletingLastPathComponent]]
							  select:[NSURL fileURLWithPath:path]];
			}
		}
	}
}



- (IBAction)openURL:(id)sender {
	// --- clear text
	[_openURLTextView setString:@""];

	// --- show sheet
	[NSApp beginSheet:_openURLPanel
		   modalForWindow:[self window]
		   modalDelegate:NULL
		   didEndSelector:NULL
		   contextInfo:NULL];
}



- (IBAction)okOpenURL:(id)sender {
	NSURL		*url;
	NSString	*string;
	NSRange		range;

	// --- close sheet
	[self cancelOpenURL:self];
	
	// --- fix schemeless
	string = [_openURLTextView string];
	range = [string rangeOfString:@"://"];
	
	if(range.length == 0)
		string = [NSString stringWithFormat:@"http://%@", string];
	
	// --- get URL
	url = [NSURL URLWithString:string];
	
	// --- deselect cell
	[_browserView deselectSelectedCell];
	
	if([[NSImage imageUnfilteredFileTypes] containsObject:[[url path] pathExtension]])
		[_browserView openImage:url];
	else
		[_browserView openFolder:url select:NULL];
}



- (IBAction)cancelOpenURL:(id)sender {
	// --- close sheet
	[NSApp endSheet:_openURLPanel];
	[_openURLPanel close];
}



#pragma mark -

- (IBAction)openParent:(id)sender {
	if([_menu numberOfItems] > 5) {
		// --- open parent in the browser
		[_browserView openFolder:[[[_menu itemArray] objectAtIndex:[_menu numberOfItems] - 2] representedObject]
					  select:[[_menu lastItem] representedObject]];
	}
}



- (IBAction)slideshow:(id)sender {
	NSScreen	*screen;
	NSRect		screenRect;
	int			screenNumber;
	
	// --- need some images
	if(![[_browserView images] count] > 0)
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
	[_fullscreenWindow setPosition:[_browserView selectedRow]];

	// --- add content view from fullscreen panel
	[_fullscreenPanel setFrame:screenRect display:NO];
	[_fullscreenWindow setContentView:[[_fullscreenPanel contentView] retain]];
	
	// --- show window
	[_fullscreenWindow makeKeyAndOrderFront:self];
}



- (IBAction)revealInFinder:(id)sender {
	FHBrowserCell	*cell;
	
	// --- might be disabled
	if(![_revealInFinderButton isEnabled])
		return;
	
	// --- select in finder
	cell = [_browserView selectedCell];
	[[NSWorkspace sharedWorkspace] selectFile:[cell path] inFileViewerRootedAtPath:NULL];
}



- (IBAction)delete:(id)sender {
	FHBrowserCell	*cell;
	int				row;
	
	// --- might be disabled
	if(![_moveToTrashButton isEnabled])
		return;
	
	// --- move to trash
	cell = [_browserView selectedCell];

	[[NSWorkspace sharedWorkspace]
		performFileOperation:NSWorkspaceRecycleOperation 
		source:[[cell path] stringByDeletingLastPathComponent]
		destination:@"/"
		files:[NSArray arrayWithObjects:[[cell path] lastPathComponent], NULL]
		tag:NULL];

	// --- get cell above deleted
	row = [_browserView selectedRow];
	cell = [_browserView cellAtRow:row == 0 ? 1 : row - 1 column:0];

	// --- reload
	[_browserView openFolder:[[_menu lastItem] representedObject] select:[cell url]];
}



- (IBAction)menu:(id)sender {
	[_browserView openFolder:[sender representedObject] select:NULL];
}



#pragma mark -

- (void)setImage:(NSImage *)image {
	[_imageView setImage:image];
}



- (void)setFullscreenImage:(NSImage *)image {
	[_fullscreenImageView setImage:image];
}



- (void)setStatus:(NSString *)status {
	[_statusTextField setStringValue:status];
}



- (void)setFullscreenStatus:(NSString *)status {
	[_fullscreenImageView setText:status];
}



- (void)setImages:(NSMutableArray *)images {
	[_browserView setImages:images];
}



- (NSArray *)images {
	return [_browserView images];
}



#pragma mark -

- (void)startSpinning {
	[_progressIndicator startAnimation:self];
}



- (void)stopSpinning {
	[_progressIndicator stopAnimation:self];
}



- (void)updateMenu:(NSURL *)url {
	NSEnumerator		*enumerator;
	NSString			*host, *component, *label;
	NSMenuItem			*item;
	NSImage				*icon;
	int					i, count;
	
	// --- empty menu
	count = [_menu numberOfItems];
	
	for(i = count - 1; i >= 4; i--)
		[_menu removeItemAtIndex:i];
	
	// --- get scheme/host part
	host = [NSString stringWithFormat:@"%@://%@", [url scheme], [url host]];
	label = [NSString string];
	
	// --- loop over path components
	enumerator = [[[url path] pathComponents] objectEnumerator];
	
	while((component = [enumerator nextObject])) {
		// --- get full path
		label = [label stringByAppendingString:component];
		
		if(![label hasSuffix:@"/"])
			label = [label stringByAppendingString:@"/"];
		
		// --- create new item
		if([url isFileURL]) {
			item = [[NSMenuItem alloc] initWithTitle:label
									   action:@selector(menu:)
									   keyEquivalent:@""];
			[item setRepresentedObject:[NSURL URLWithString:
				[[host stringByAppendingString:label] stringByAddingPercentEscapes]]];
			icon = [[NSWorkspace sharedWorkspace] iconForFile:label];
		} else {
			item = [[NSMenuItem alloc] initWithTitle:[host stringByAppendingString:label]
									   action:@selector(menu:)
									   keyEquivalent:@""];
			[item setRepresentedObject:[NSURL URLWithString:
				[[host stringByAppendingString:label] stringByAddingPercentEscapes]]];
			icon = [NSImage imageNamed:@"URL"];
		}
		
		// --- set icon
		[icon setSize:NSMakeSize(16, 16)];
		[item setImage:icon];

		// --- add item
		[[_menu menu] addItem:item];

		[item release];
	}
	
	// --- select last
	[_menu selectItem:[_menu lastItem]];
}



- (void)updateFirstResponder {
	if([_browserView files] > 0)
		[[self window] makeFirstResponder:_browserView];
	else
		[[self window] makeFirstResponder:_splitView];
}



- (void)updateButtons:(BOOL)online {
	if(online) {
		[_revealInFinderButton setEnabled:NO];
		[_moveToTrashButton setEnabled:NO];
	} else {
		[_revealInFinderButton setEnabled:YES];
		[_moveToTrashButton setEnabled:YES];
	}
}



- (void)updateStatus:(NSString *)name {
	NSImage			*image;
	NSString		*status;
	double          zoom = 100;
	int             width, height;
	
	// --- get name
	if(name) {
		[name retain];
		[_name release];
		
		_name = name;
	}

	// --- get image
	image = [_imageView image];

	if(image) {
		// --- get zoom level
		width = [image size].width;
		height = [image size].height;
	
		if(width > [_imageView frame].size.width || height > [_imageView frame].size.height) {
			if(width > height)
				zoom = 100 * (1 / (width / [_imageView frame].size.width));
			else
				zoom = 100 * (1 / (height / [_imageView frame].size.height));
		}
		
		// --- display status
		status = [NSString stringWithFormat:NSLocalizedString(@"%@, %.0fx%.0f, zoomed at %.0f%%", @""),
			_name,
			[image size].width,
			[image size].height,
			zoom];
		[_statusTextField setStringValue:status];
	}
}

@end
