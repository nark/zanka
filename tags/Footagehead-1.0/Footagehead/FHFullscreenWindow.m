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
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
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
#import "FHFullscreenWindow.h"
#import "FHImageView.h"
#import "NSImageAdditions.h"

@implementation FHFullscreenWindow

- (void)makeKeyAndOrderFront:(id)sender {
	NSImage		*image;

	// --- get controller
	_controller = sender;

	// --- set first image
	image = [[NSImage alloc] initSmoothWithContentsOfURL:[[_controller images] objectAtIndex:_position]];
	[_controller setFullscreenImage:image];
	[_controller setFullscreenStatus:[NSString stringWithFormat:
		@"%@ - %d/%d",
		[[[[_controller images] objectAtIndex:_position] path] lastPathComponent],
		_position + 1,
		[[_controller images] count]]];
	[image release];
	
	// --- show window
	[super makeKeyAndOrderFront:sender];
}



- (void)sendEvent:(NSEvent *)event {
	NSImage		*image;
	BOOL		handled = NO;
	
	if([event type] == NSKeyDown && [[event characters] length] > 0) {
		if([[event characters] characterAtIndex:0] == 27 ||
		   ([[event characters] characterAtIndex:0] == 'f' && [event modifierFlags] & NSCommandKeyMask) ||
		   ([[event characters] characterAtIndex:0] == '.' && [event modifierFlags] & NSCommandKeyMask)) {
			[self close];
				
			handled = YES;
		}
		else if ([[event characters] characterAtIndex:0] == 'r' && [event modifierFlags] & NSCommandKeyMask) {
			[self close];
			[_controller revealInFinder:self];
				
			handled = YES;
		}
		else if ([[event characters] characterAtIndex:0] == 127 && [event modifierFlags] & NSCommandKeyMask) {
			[self close];
			[_controller delete:self];
				
			handled = YES;
		}
		else if([[event characters] characterAtIndex:0] == NSUpArrowFunctionKey ||
		        [[event characters] characterAtIndex:0] == NSLeftArrowFunctionKey ||
		        [[event characters] characterAtIndex:0] == NSPageUpFunctionKey ||
				[[event characters] characterAtIndex:0] == 127) {
			if(_position > 0) {
				image = [[NSImage alloc] initSmoothWithContentsOfURL:[[_controller images] objectAtIndex:--_position]];

				if(!image) {
					[_controller setFullscreenImage:[NSImage imageNamed:@"Error"]];
				} else {
					[_controller setFullscreenImage:image];
					[image release];
				}

				[_controller setFullscreenStatus:[NSString stringWithFormat:
					@"%@ - %d/%d",
					[[[[_controller images] objectAtIndex:_position] path] lastPathComponent],
					_position + 1,
					[[_controller images] count]]];
				
				handled = YES;
			}
		}
		else if(_position + 1 < [[_controller images] count]) {
			image = [[NSImage alloc] initSmoothWithContentsOfURL:[[_controller images] objectAtIndex:++_position]];
			
			if(!image) {
				[_controller setFullscreenImage:[NSImage imageNamed:@"Error"]];
			} else {
				[_controller setFullscreenImage:image];
				[image release];
			}

			[_controller setFullscreenStatus:[NSString stringWithFormat:
				@"%@ - %d/%d",
				[[[[_controller images] objectAtIndex:_position] path] lastPathComponent],
				_position + 1,
				[[_controller images] count]]];
			
			handled = YES;
		}
	}
	else if([event type] == NSLeftMouseDown) {
		if(_position + 1 < [[_controller images] count]) {
			image = [[NSImage alloc] initSmoothWithContentsOfURL:[[_controller images] objectAtIndex:++_position]];
			
			if(!image) {
				[_controller setFullscreenImage:[NSImage imageNamed:@"Error"]];
			} else {
				[_controller setFullscreenImage:image];
				[image release];
			}

			[_controller setFullscreenStatus:[NSString stringWithFormat:
				@"%@ - %d/%d",
				[[[[_controller images] objectAtIndex:_position] path] lastPathComponent],
				_position + 1,
				[[_controller images] count]]];
				
			handled = YES;
		}
	}
	else if([event type] == NSRightMouseDown) {
		if(_position > 0) {
			image = [[NSImage alloc] initSmoothWithContentsOfURL:[[_controller images] objectAtIndex:--_position]];
			
			if(!image) {
				[_controller setFullscreenImage:[NSImage imageNamed:@"Error"]];
			} else {
				[_controller setFullscreenImage:image];
				[image release];
			}

			[_controller setFullscreenStatus:[NSString stringWithFormat:
				@"%@ - %d/%d",
				[[[[_controller images] objectAtIndex:_position] path] lastPathComponent],
				_position + 1,
				[[_controller images] count]]];
				
			handled = YES;
		}
	}
	
	// --- throw it down to NSWindow
	if(!handled)
		[super sendEvent:event];
}



- (BOOL)canBecomeKeyWindow {
	return YES;
}



#pragma mark -

- (void)setPosition:(int)position {
	_position = position;
}



- (int)position {
	return _position;
}

@end
