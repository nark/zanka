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

#import "SPFullscreenWindow.h"

@interface SPFullscreenWindow(Private)

- (void)_hideHUD;

@end


@implementation SPFullscreenWindow(Private)

- (void)_hideHUD {
	[NSCursor setHiddenUntilMouseMoves:YES];
	
	[[_hudWindow animator] setAlphaValue:0.0];
	
	[_timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:[_timer timeInterval]]];
}

@end



@implementation SPFullscreenWindow

- (id)initWithScreen:(NSScreen *)screen {
	NSRect		frame;
	
	frame = [screen frame];
	frame.origin.x = frame.origin.y = 0.0;

#if 0
	frame.size.width = 1280;
	frame.size.height = 800;

	self = [self initWithContentRect:frame
						   styleMask:NSTitledWindowMask | NSClosableWindowMask
							 backing:NSBackingStoreBuffered
							   defer:YES
							  screen:screen];

	[self center];
#else
	self = [self initWithContentRect:frame
						   styleMask:NSBorderlessWindowMask
							 backing:NSBackingStoreBuffered
							   defer:YES
							  screen:screen];

	[self setLevel:NSStatusWindowLevel];
#endif

	[self setBackgroundColor:[NSColor blackColor]];
	[self setAcceptsMouseMovedEvents:YES];
	
	[NSCursor setHiddenUntilMouseMoves:YES];
	
	_timer = [[NSTimer scheduledTimerWithTimeInterval:10.0
											   target:self
											 selector:@selector(timer:)
											 userInfo:NULL
											  repeats:YES] retain];
	
	return self;
}



- (void)dealloc {
	[_hudWindow release];
	[_timer release];
	
	[super dealloc];
}



#pragma mark -

- (void)timer:(NSTimer *)timer {
	[NSCursor setHiddenUntilMouseMoves:YES];
}



#pragma mark -

- (void)setHUDWindow:(NSWindow *)window {
	[window retain];
	[_hudWindow release];
	
	_hudWindow = window;
}



- (NSWindow *)HUDWindow {
	return _hudWindow;
}



- (void)orderFrontHUDWindow {
	if(![_hudWindow isVisible]) {
		[_hudWindow setAlphaValue:0.0];
		[_hudWindow orderFront:self];
	}

	[[_hudWindow animator] setAlphaValue:1.0];

	if(NSPointInRect([NSEvent mouseLocation], [_hudWindow frame]))
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideHUD) object:NULL];
	else
		[self performSelectorOnce:@selector(_hideHUD) afterDelay:2.0];
}



#pragma mark -

- (void)setAnimates:(BOOL)animates {
	_animates = animates;
}



- (BOOL)animates {
	return _animates;
}



#pragma mark -

- (void)close {
	[_timer invalidate];
	
	[super close];
}



- (void)makeKeyAndOrderFront:(id)sender {
	if(_animates) {
		[self setAlphaValue:0.0];
		[super makeKeyAndOrderFront:sender];
		[[self animator] setAlphaValue:1.0];
	} else {
		[super makeKeyAndOrderFront:sender];
	}
}



- (void)performClose:(id)sender {
	if(_animates) {
		[[self animator] setAlphaValue:0.0];

		[self performSelector:@selector(close) afterDelay:[[NSAnimationContext currentContext] duration]];
	} else {
		[self close];
	}
}



- (void)sendEvent:(NSEvent *)event {
	BOOL			handled = NO;
	
	switch([event type]) {
		case NSMouseMoved:
			if(_hudWindow)
				[self orderFrontHUDWindow];
			else
				[self performSelectorOnce:@selector(_hideHUD) afterDelay:2.0];
			
			[_timer setFireDate:[NSDate distantFuture]];
			break;
			
		case NSKeyDown:
			if([event character] == NSEscapeFunctionKey) {
				if([[self delegate] windowShouldClose:self])
					[self performClose:self];
				
				handled = YES;
			}
			break;
		
		default:
			break;
	}
	
	if(!handled)
		[super sendEvent:event];
}



- (BOOL)canBecomeKeyWindow {
	return YES;
}

@end
