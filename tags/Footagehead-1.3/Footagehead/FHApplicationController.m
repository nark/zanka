/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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
#import "FHImageView.h"
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
}



- (void)_updateViewMenu {
	NSEnumerator	*enumerator;
	NSMenuItem		*item;
	FHImageScaling	scaling;
	int				spread;
	
	scaling = [FHSettings intForKey:FHImageScalingMethod];
	enumerator = [[[_viewMenu itemArray] subarrayWithRange:NSMakeRange(0, 6)] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[item setState:((FHImageScaling) [item tag] == scaling) ? NSOnState : NSOffState];

	spread = [FHSettings intForKey:FHSpreadMode];
	enumerator = [[[_viewMenu itemArray] subarrayWithRange:NSMakeRange(7, 3)] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[item setState:([item tag] == spread) ? NSOnState : NSOffState];
	
	[_spreadRightToLeftMenuItem setState:[FHSettings boolForKey:FHSpreadRightToLeft] ? NSOnState : NSOffState];
}

@end


@implementation FHApplicationController

- (void)dealloc {
	[_browserController release];
	
	[super dealloc];
}



- (void)awakeFromNib {
	_openLastURL = YES;
	
	[self _buildGoMenu];
	[self _updateViewMenu];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerDidLoadHandler:)
			   name:FHBrowserControllerDidLoadHandler];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowControllerChangedZoomMode:)
			   name:FHWindowControllerChangedZoomMode];
	
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
	
	_browserController = [[FHBrowserController alloc] init];
}



#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	WIURL		*url;
	
	if((GetCurrentKeyModifiers() & optionKey) != 0)
		[FHSettings setObject:[[WIURL fileURLWithPath:NSHomeDirectory()] string] forKey:FHOpenURL];
		
	if(_openLastURL) {
		url = [WIURL URLWithString:[FHSettings objectForKey:FHOpenURL]];
		
		if([url isFileURL] && ![[NSFileManager defaultManager] fileExistsAtPath:[url path]])
			url = [WIURL fileURLWithPath:NSHomeDirectory()];

		[_browserController loadURL:url];
	}
	
	[_browserController showWindow:self];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	WIURL	*url;
	
	url = [_browserController URL];
	
	if(url)
		[FHSettings setObject:[url string] forKey:FHOpenURL];
}



- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
	return YES;
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	[_browserController loadURL:[WIURL fileURLWithPath:path]];
	
	_openLastURL = NO;

	return YES;
}



- (void)workspaceDidChangeMounts:(NSNotification *)notification {
	[self _reloadVolumesInGoMenu];
}



- (void)windowControllerDidLoadHandler:(NSNotification *)notification {
	[self _reloadPathsInGoMenuForHandler:[notification object]];
}



- (void)windowControllerChangedZoomMode:(NSNotification *)notification {
	[self _updateViewMenu];
}



- (void)windowControllerChangedSpreadMode:(NSNotification *)notification {
	[self _updateViewMenu];
}



- (void)menuNeedsUpdate:(NSMenu *)menu {
	if(menu == _viewMenu) {
		[_toggleStatusBarMenuItem setTitle:![FHSettings boolForKey:FHShowStatusBar]
			? NSLS(@"Show Status Bar", @"Menu item title")
			: NSLS(@"Hide Status Bar", @"Menu item title")];
	}
}

@end
