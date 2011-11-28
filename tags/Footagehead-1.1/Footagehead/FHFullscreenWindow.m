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

#import "NSImageAdditions.h"
#import "FHController.h"
#import "FHBrowserView.h"
#import "FHFullscreenWindow.h"
#import "FHHandler.h"
#import "FHImageView.h"
#import "FHSettings.h"

@implementation FHFullscreenWindow

- (void)makeKeyAndOrderFront:(id)sender {
	int		row;
	
	// --- set position
	row = [[[self delegate] browserView] selectedRow];
	_position = [[[[self delegate] handler] images] indexOfObject:
		 [[[[self delegate] handler] files] objectAtIndex:row]];
	
	if(_position < 0)
		_position = 0;
	
	[[[self delegate] fullscreenImageView] setText:[NSString stringWithFormat:
		@"%@ - %u/%u",
		[[[[[self delegate] handler] images] objectAtIndex:_position] name],
		_position + 1,
		[[[[self delegate] handler] images] count]]];
	
	// --- load image
	[[self delegate] loadImage:[[[[self delegate] handler] images] objectAtIndex:_position]];

	// --- show window
	[super makeKeyAndOrderFront:sender];
	
	// --- start timer
	if([FHSettings boolForKey:FHAutoSwitch]) {
		_timer = [[NSTimer scheduledTimerWithTimeInterval:[FHSettings intForKey:FHAutoSwitchTime]
												   target:self
												 selector:@selector(autoSwitchTimer:)
												 userInfo:NULL
												  repeats:YES] retain];
	}
}



- (void)dealloc {
	[_timer release];
	
	[super dealloc];
}



- (void)sendEvent:(NSEvent *)event {
	BOOL		handled = NO, load = NO;
	
	if([event type] == NSKeyDown && [[event characters] length] > 0) {
		if([[event characters] characterAtIndex:0] == 27 ||
		   ([[event characters] characterAtIndex:0] == 'f' &&
			[event modifierFlags] & NSCommandKeyMask) ||
		   ([[event characters] characterAtIndex:0] == '.' &&
			[event modifierFlags] & NSCommandKeyMask)) {
			[self close];
				
			handled = YES;
		}
		else if ([[event characters] characterAtIndex:0] == 'r' &&
				 [event modifierFlags] & NSCommandKeyMask) {
			[self close];
			[[self delegate] revealInFinder:self];
				
			handled = YES;
		}
		else if ([[event characters] characterAtIndex:0] == 127 &&
				 [event modifierFlags] & NSCommandKeyMask) {
			[self close];
			[[self delegate] delete:self];
				
			handled = YES;
		}
		else if([[event characters] characterAtIndex:0] == NSUpArrowFunctionKey ||
		        [[event characters] characterAtIndex:0] == NSLeftArrowFunctionKey ||
		        [[event characters] characterAtIndex:0] == NSPageUpFunctionKey ||
				[[event characters] characterAtIndex:0] == 127) {
			if(_position > 0) {
				_position--;
				
				load = YES;
				handled = YES;
			}
		}
		else if(_position + 1 < [[[[self delegate] handler] images] count]) {
			_position++;
			
			load = YES;
			handled = YES;
		}
	}
	else if([event type] == NSLeftMouseDown) {
		if(_position + 1 < [[[[self delegate] handler] images] count]) {
			_position++;

			load = YES;
			handled = YES;
		}
	}
	else if([event type] == NSRightMouseDown) {
		if(_position > 0) {
			_position--;

			load = YES;
			handled = YES;
		}
	}
	
	// --- load image
	if(load) {
		if(_timer)
			[_timer setFireDate:[NSDate distantFuture]];
		
		[[[self delegate] fullscreenImageView] setText:[NSString stringWithFormat:
			@"%@ - %u/%u",
			[[[[[self delegate] handler] images] objectAtIndex:_position] name],
			_position + 1,
			[[[[self delegate] handler] images] count]]];
		
		[[self delegate] loadImage:[[[[self delegate] handler] images] objectAtIndex:_position]];
	}
	
	// --- throw it down to NSWindow
	if(!handled)
		[super sendEvent:event];
}



- (BOOL)canBecomeKeyWindow {
	return YES;
}



#pragma mark -

- (void)autoSwitchTimer:(NSTimer *)timer {
	if(_position + 1 == [[[[self delegate] handler] images] count]) {
		[_timer invalidate];
		_timer = NULL;
		
		return;
	}
	
	_position++;

	[[[self delegate] fullscreenImageView] setText:[NSString stringWithFormat:
		@"%@ - %u/%u",
		[[[[[self delegate] handler] images] objectAtIndex:_position] name],
		_position + 1,
		[[[[self delegate] handler] images] count]]];
	
	[[self delegate] loadImage:[[[[self delegate] handler] images] objectAtIndex:_position]];
}



#pragma mark -

- (FHFile *)file {
	return [[[[self delegate] handler] images] objectAtIndex:_position];
}



- (int)position {
	return _position;
}



- (NSTimer *)timer {
	return _timer;
}

@end
