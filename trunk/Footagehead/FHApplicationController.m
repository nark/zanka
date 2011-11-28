/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "FHApplicationController.h"
#import "FHBrowserController.h"
#import "FHHandler.h"
#import "FHFileHandler.h"
#import "FHImageView.h"
#import "FHPreferencesController.h"
#import "FHSettings.h"

@interface FHApplicationController(Private)

- (void)_buildGoMenu;
- (void)_reloadVolumesInGoMenu;
- (void)_addGoMenuItemWithPath:(NSString *)path keyEquivalent:(NSString *)keyEquivalent;
- (void)_reloadPathsInGoMenuForHandler:(FHHandler *)handler;
- (void)_updateViewMenu;

@end


@implementation FHApplicationController(Private)

- (void)_buildGoMenu {
	_initialMenuItems = [_goMenu numberOfItems];
	
	[self _reloadVolumesInGoMenu];

	[self _addGoMenuItemWithPath:@"~" keyEquivalent:@"H"];
	[self _addGoMenuItemWithPath:@"~/Desktop" keyEquivalent:@"d"];
	[self _addGoMenuItemWithPath:@"~/Downloads" keyEquivalent:@"D"];
	[self _addGoMenuItemWithPath:@"~/Pictures" keyEquivalent:@"P"];
	
	[_goMenu addItem:[NSMenuItem separatorItem]];
	_menuItems++;
}



- (void)_reloadVolumesInGoMenu {
	NSEnumerator	*enumerator;
	NSMenuItem		*item;
	NSString		*volume, *path;
	NSImage			*icon;
	NSUInteger		i = _initialMenuItems;
	
	if((NSUInteger) [_goMenu numberOfItems] > _initialMenuItems) {
		while(![[_goMenu itemAtIndex:_initialMenuItems] isSeparatorItem]) {
			[_goMenu removeItemAtIndex:_initialMenuItems];
			_menuItems--;
		}
	}
	
	enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:@"/Volumes/"] objectEnumerator];
	
	while((volume = [enumerator nextObject])) {
		if([volume hasPrefix:@"."])
			continue;
		
		path = [NSSWF:@"/Volumes/%@", volume];
		icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
		[icon setSize:NSMakeSize(16.0, 16.0)];

		item = [NSMenuItem itemWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
								  action:@selector(go:)];
		[item setImage:icon];
		[item setRepresentedObject:[WIURL fileURLWithPath:path]];
		[_goMenu insertItem:item atIndex:i];
		_menuItems++;
		i++;
	}
	
	if(i == (NSUInteger) [_goMenu numberOfItems] || ![[_goMenu itemAtIndex:i] isSeparatorItem]) {
		[_goMenu insertItem:[NSMenuItem separatorItem] atIndex:i];
		_menuItems++;
	}
}



- (void)_addGoMenuItemWithPath:(NSString *)path keyEquivalent:(NSString *)keyEquivalent {
	NSMenuItem	*item;
	NSImage		*icon;
	
	path = [path stringByStandardizingPath];
	icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[icon setSize:NSMakeSize(16.0, 16.0)];

	item = [NSMenuItem itemWithTitle:[[NSFileManager defaultManager] displayNameAtPath:path]
							  action:@selector(go:)
					   keyEquivalent:keyEquivalent];

	[item setImage:icon];
	[item setRepresentedObject:[WIURL fileURLWithPath:path]];
	[_goMenu addItem:item];

	_menuItems++;
}



- (void)_reloadPathsInGoMenuForHandler:(FHHandler *)handler {
	NSArray			*stringComponents, *urlComponents;
	NSMenuItem		*item;
	NSImage			*icon;
	NSString		*name;
	WIURL			*url;
	NSUInteger		i, count, items;
	
	stringComponents	= [handler stringComponents];
	urlComponents		= [handler URLComponents];
	count				= [stringComponents count];
	items				= [_goMenu numberOfItems];
	
	for(i = 0; i < count; i++) {
		if(_menuItems + i + _initialMenuItems < items) {
			name = [[_goMenu itemAtIndex:i + _menuItems + _initialMenuItems] title];
			
			if([name isEqualToString:[stringComponents objectAtIndex:i]])
				continue;
			
			[_goMenu removeItemAtIndex:_menuItems + i + _initialMenuItems];
			items--;
		}
		
		url = [urlComponents objectAtIndex:i];

		item = [NSMenuItem itemWithTitle:[stringComponents objectAtIndex:i]
								  action:@selector(go:)];
		[item setRepresentedObject:url];
		
		icon = [handler iconForURL:url];
		
		if(icon) {
			[icon setSize:NSMakeSize(16.0, 16.0)];
			[item setImage:icon];
		}
			
		[_goMenu insertItem:item atIndex:_menuItems + i + _initialMenuItems];
		items++;
	}
	
	while(items > _menuItems + count + _initialMenuItems) {
		[_goMenu removeItemAtIndex:_menuItems + count + _initialMenuItems];
		
		items--;
	}
	
	if(count == 0) {
		i = _initialMenuItems + _menuItems - 1;
		
		if([[_goMenu itemAtIndex:i] isSeparatorItem]) {
			[_goMenu removeItemAtIndex:i];
			
			_menuItems--;
		}
	} else {
		i = items - count - 1;
		
		if(![[_goMenu itemAtIndex:i] isSeparatorItem]) {
			[_goMenu insertItem:[NSMenuItem separatorItem] atIndex:i + 1];
			
			_menuItems++;
		}
	}
}



- (void)_updateViewMenu {
	NSEnumerator	*enumerator;
	NSMenuItem		*item;
	FHImageScaling	scaling;
	int				spread;
	
	scaling = [[FHSettings settings] intForKey:FHImageScalingMethod];
	enumerator = [[[_viewMenu itemArray] subarrayWithRange:NSMakeRange(0, 6)] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[item setState:((FHImageScaling) [item tag] == scaling) ? NSOnState : NSOffState];

	spread = [[FHSettings settings] intForKey:FHSpreadMode];
	enumerator = [[[_viewMenu itemArray] subarrayWithRange:NSMakeRange(10, 3)] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[item setState:([item tag] == spread) ? NSOnState : NSOffState];
	
	[_spreadRightToLeftMenuItem setState:[[FHSettings settings] boolForKey:FHSpreadRightToLeft] ? NSOnState : NSOffState];
}

@end


@implementation FHApplicationController

- (id)init {
	self = [super init];
	
	_browserControllers = [[NSMutableArray alloc] init];
	
	return self;
}




- (void)dealloc {
	[_browserControllers release];
	
	[super dealloc];
}




#pragma mark -

- (void)awakeFromNib {
	FHBrowserController		*browserController;
	
	_openLastURL = YES;
	
	[self _buildGoMenu];
	[self _updateViewMenu];

	[_updater setAutomaticallyChecksForUpdates:YES];
	[_updater setSendsSystemProfile:YES];

#ifdef FHConfigurationRelease
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/sparkle.pl?file=footagehead.xml"]];
#else
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/sparkle.pl?file=footagehead-nightly.xml"]];
#endif

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowWillClose:)
			   name:NSWindowWillCloseNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerDidLoadHandler:)
			   name:FHBrowserControllerDidLoadHandler];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedScalingMode:)
			   name:FHWindowControllerChangedScalingMode];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedSpreadMode:)
			   name:FHWindowControllerChangedSpreadMode];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidChangeMounts:)
			   name:NSWorkspaceDidMountNotification];

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceDidChangeMounts:)
			   name:NSWorkspaceDidUnmountNotification];
	
	browserController = [[FHBrowserController alloc] init];
	[_browserControllers addObject:browserController];
	[browserController release];
}



#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSString	*item;
	WIURL		*url;
	
	if((GetCurrentKeyModifiers() & optionKey) != 0)
		[[FHSettings settings] setObject:[[WIURL fileURLWithPath:NSHomeDirectory()] string] forKey:FHOpenURL];
		
	if(_openLastURL) {
		url = [WIURL URLWithString:[[FHSettings settings] objectForKey:FHOpenURL]];
		item = [[FHSettings settings] objectForKey:FHSelectedItem];
		
		if([url isFileURL] && ![FHFileHandler handlesURL:url isPrimary:YES]) {
			url = [WIURL fileURLWithPath:NSHomeDirectory()];
			item = NULL;
		}
		
		[[_browserControllers objectAtIndex:0] loadURL:url selectItem:item];
	}
	
	[[_browserControllers objectAtIndex:0] showWindow:self];
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	[[_browserControllers objectAtIndex:0] loadURL:[WIURL fileURLWithPath:path]];
	
	_openLastURL = NO;

	return YES;
}



- (void)workspaceDidChangeMounts:(NSNotification *)notification {
	[self _reloadVolumesInGoMenu];
}



- (void)windowWillClose:(NSNotification *)notification {
	WIURL		*url;
	FHFile		*file;
	id			delegate;
	
	delegate = [[notification object] delegate];
	
	if([delegate isKindOfClass:[FHBrowserController class]]) {
		url = [(FHBrowserController *) delegate URL];
		
		if(url)
			[[FHSettings settings] setObject:[url string] forKey:FHOpenURL];
		
		file = [[_browserControllers objectAtIndex:0] selectedFile];
		
		if(file)
			[[FHSettings settings] setObject:[file name] forKey:FHSelectedItem];
		
		[_browserControllers removeObject:delegate];
	}
}



- (void)windowControllerDidLoadHandler:(NSNotification *)notification {
	[self _reloadPathsInGoMenuForHandler:[notification object]];
}



- (void)windowControllerChangedScalingMode:(NSNotification *)notification {
	[self _updateViewMenu];
}



- (void)windowControllerChangedSpreadMode:(NSNotification *)notification {
	[self _updateViewMenu];
}



- (void)menuNeedsUpdate:(NSMenu *)menu {
	if(menu == _viewMenu) {
		[_toggleStatusBarMenuItem setTitle:![[FHSettings settings] boolForKey:FHShowStatusBar]
			? NSLS(@"Show Status Bar", @"Menu item title")
			: NSLS(@"Hide Status Bar", @"Menu item title")];
	}
}


#pragma mark -

- (IBAction)preferences:(id)sender {
	[[FHPreferencesController preferencesController] showWindow:self];
}



#pragma mark -

- (IBAction)newDocument:(id)sender {
	FHBrowserController		*browserController;
	
	browserController = [[FHBrowserController alloc] init];
	[browserController loadURL:[WIURL fileURLWithPath:NSHomeDirectory()] selectItem:NULL];
	[browserController showWindow:self];
	[_browserControllers addObject:browserController];
	[browserController release];
}



#pragma mark -

- (IBAction)releaseNotes:(id)sender {
	NSString		*path;
	
	path = [[self bundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
	
	[[WIReleaseNotesController releaseNotesController]
		setReleaseNotesWithRTF:[NSData dataWithContentsOfFile:path]];
	[[WIReleaseNotesController releaseNotesController] showWindow:self];
}



#pragma mark -

- (FHBrowserController *)selectedBrowserController {
	return [[NSApp keyWindow] delegate];
}

@end
