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

#import <ZankaAdditions/ZAWindowController.h>

static NSLock						*lock;
static NSMutableDictionary			*frames;
static NSMutableArray				*windows;

@interface ZAWindowController(Private)

- (void)_initWindowController;

- (void)_saveWindowFrame;
- (void)_loadWindowFrame;

@end


@implementation ZAWindowController

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



- (void)_initWindowController {
	if(!lock)
		lock = [[NSLock alloc] init];
	
	if(!frames)
		frames = [[NSMutableDictionary alloc] init];
	
	if(!windows)
		windows = [[NSMutableArray alloc] init];
	
	[super setShouldCascadeWindows:NO];
	[super setWindowFrameAutosaveName:@""];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_ZA_windowWillClose:)
			   name:NSWindowWillCloseNotification
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_ZA_windowDidMove:)
			   name:NSWindowDidMoveNotification
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_ZA_applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification
			 object:NULL];
}



#pragma mark -

- (void)_ZA_windowWillClose:(NSNotification *)notification {
	NSWindow		*window;
	
	window = [notification object];
	
	if(window == [self window]) {
		[self _saveWindowFrame];
		
		[windows removeObject:window];
	}
}



- (void)_ZA_windowDidMove:(NSNotification *)notification {
	NSWindow	*window;
	NSString	*key;
	
	if(_ZA_windowFrameAutosaveName) {
		window = [notification object];
	
		if(window == [windows lastObject]) {
			key = [NSSWF:@"%@ %@ Frame", NSStringFromClass([self class]), _ZA_windowFrameAutosaveName];
			
			[lock lock];
			[frames setObject:NSStringFromRect([window frame]) forKey:key];
			[lock unlock];
		}
	}
}



- (void)_ZA_applicationWillTerminate:(NSNotification *)notification {
	[self _saveWindowFrame];
}



#pragma mark -

- (void)_loadWindowFrame {
	NSString	*key, *frame, *previousFrame;
	NSRect		rect, previousRect;
	NSSize		size;
	
	if([_ZA_windowFrameAutosaveName length] > 0) {
		key = [NSSWF:@"%@ %@ Frame", NSStringFromClass([self class]), _ZA_windowFrameAutosaveName];
		frame = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		size = [[self window] frame].size;
		
		[lock lock];
		
		if([frame length] > 0) {
			rect = NSRectFromString(frame);
			
			if(_ZA_shouldCascadeWindows) {
				previousFrame = [frames objectForKey:key];
				
				if([previousFrame length] > 0) {
					previousRect = NSRectFromString(previousFrame);
					rect.origin = previousRect.origin;
				}

				rect.origin.x += 20;
				rect.origin.y -= 20;
			}
			
			if([self shouldSaveWindowSizeOnly])
				rect.size = size;

			[[self window] setFrame:rect display:NO];
			[windows addObject:[self window]];
			[frames setObject:NSStringFromRect(rect) forKey:key];
		}

		[lock unlock];
	}
}



- (void)_saveWindowFrame {
	NSString	*key, *value;
	NSRect		rect;
	
	if([_ZA_windowFrameAutosaveName length] > 0) {
		key = [NSSWF:@"%@ %@ Frame", NSStringFromClass([self class]), _ZA_windowFrameAutosaveName];
		rect = [[self window] frame];
		
		if(_ZA_shouldCascadeWindows) {
			rect.origin.x -= 20;
			rect.origin.y += 20;
		}
		
		value = NSStringFromRect(rect);
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		
		[lock lock];
		[frames setObject:value forKey:key];
		[lock unlock];
	}
}



#pragma mark -

- (void)setShouldCascadeWindows:(BOOL)value {
	_ZA_shouldCascadeWindows = value;
}



- (void)setWindowFrameAutosaveName:(NSString *)value {
	[value retain];
	[_ZA_windowFrameAutosaveName release];
	
	_ZA_windowFrameAutosaveName = value;
	
	[self _loadWindowFrame];
}



- (void)setShouldSaveWindowSizeOnly:(BOOL)value {
	_shouldSaveWindowSizeOnly = value;
}



- (BOOL)shouldSaveWindowSizeOnly {
	return _shouldSaveWindowSizeOnly;
}

@end
