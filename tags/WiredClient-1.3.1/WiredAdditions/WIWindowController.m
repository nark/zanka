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

#import <WiredAdditions/WIWindowController.h>

static NSMutableDictionary			*_WIWindowController_frames;
static NSMutableArray				*_WIWindowController_windows;

@interface WIWindowController(Private)

- (void)_initWindowController;

- (void)_saveWindowFrame;
- (void)_loadWindowFrame;

@end


@implementation WIWindowController(Private)

- (void)_initWindowController {
	if(!_WIWindowController_frames)
		_WIWindowController_frames = [[NSMutableDictionary alloc] init];
	 
	if(!_WIWindowController_windows)
		_WIWindowController_windows = [[NSMutableArray alloc] init];
	
	[super setShouldCascadeWindows:NO];
	[super setWindowFrameAutosaveName:@""];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WI_applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification
			 object:NULL];
}



#pragma mark -

- (void)_WI_windowWillClose:(NSNotification *)notification {
	if([_WI_windowFrameAutosaveName length] > 0) {
		[self _saveWindowFrame];
		
		[_WIWindowController_windows removeObject:[self window]];
	}
}



- (void)_WI_windowDidMove:(NSNotification *)notification {
	if([_WI_windowFrameAutosaveName length] > 0) {
		if([self window] == [_WIWindowController_windows lastObject]) {
			[_WIWindowController_frames setObject:NSStringFromRect([[self window] frame])
										   forKey:[NSSWF:@"WIWindowController %@ Frame", _WI_windowFrameAutosaveName]];
		}
	}
}



- (void)_WI_applicationWillTerminate:(NSNotification *)notification {
	[self _saveWindowFrame];
}



#pragma mark -

- (void)_loadWindowFrame {
	NSScreen	*screen;
	NSString	*key, *frame, *previousFrame;
	NSRect		rect, previousRect;
	NSSize		size;
	
	if([_WI_windowFrameAutosaveName length] > 0) {
		key = [NSSWF:@"WIWindowController %@ Frame", _WI_windowFrameAutosaveName];
		frame = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		size = [[self window] frame].size;
		
		if([frame length] > 0)
			rect = NSRectFromString(frame);
		else
			rect = [[self window] frame];
			
		if(_WI_shouldCascadeWindows) {
			previousFrame = [_WIWindowController_frames objectForKey:key];
			
			if([previousFrame length] > 0) {
				previousRect = NSRectFromString(previousFrame);
				rect.origin = previousRect.origin;
			}
			
			rect.origin.x += 20.0;
			rect.origin.y -= 20.0;
			
			if(rect.origin.x < 0.0 || rect.origin.y < 0.0) {
				screen = [[self window] screen];
				
				rect.origin.x = 20.0;
				rect.origin.y = [screen frame].size.height - 20.0;
			}
		}
		
		if([self shouldSaveWindowFrameOriginOnly])
			rect.size = size;
		
		[[self window] setFrame:rect display:NO];
		
		[_WIWindowController_windows addObject:[self window]];
		[_WIWindowController_frames setObject:NSStringFromRect(rect) forKey:key];
	}
}



- (void)_saveWindowFrame {
	NSString	*key, *value;
	NSRect		rect;
	
	if([_WI_windowFrameAutosaveName length] > 0) {
		rect = [[self window] frame];
		
		if(_WI_shouldCascadeWindows) {
			rect.origin.x -= 20;
			rect.origin.y += 20;
		}
		
		key = [NSSWF:@"WIWindowController %@ Frame", _WI_windowFrameAutosaveName];
		value = NSStringFromRect(rect);

		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[[NSUserDefaults standardUserDefaults] synchronize];

		[_WIWindowController_frames setObject:value forKey:key];
	}
}

@end



@implementation WIWindowController

- (id)initWithWindow:(NSWindow *)window {
	if((self = [super initWithWindow:window]))
		[self _initWindowController];

	return self;
}



- (id)initWithWindowNibName:(NSString *)windowNibName {
	if((self = [super initWithWindowNibName:windowNibName]))
		[self _initWindowController];
	
	return self;
}



#pragma mark -

- (void)setWindow:(NSWindow *)window {
	if(window) {
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(_WI_windowWillClose:)
				   name:NSWindowWillCloseNotification
				 object:window];

		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(_WI_windowDidMove:)
				   name:NSWindowDidMoveNotification
				 object:window];
	}
	
	[super setWindow:window];
}



- (void)setShouldCascadeWindows:(BOOL)value {
	_WI_shouldCascadeWindows = value;
}



- (void)setWindowFrameAutosaveName:(NSString *)value {
	[value retain];
	[_WI_windowFrameAutosaveName release];
	
	_WI_windowFrameAutosaveName = value;
	
	[self _loadWindowFrame];
}



- (void)setShouldSaveWindowFrameOriginOnly:(BOOL)value {
	_shouldSaveWindowFrameOriginOnly = value;
}



- (BOOL)shouldSaveWindowFrameOriginOnly {
       return _shouldSaveWindowFrameOriginOnly;
}

@end
