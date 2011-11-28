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

#import "FHSlideshowController.h"
#import "FHSlideshowWindow.h"

@implementation FHSlideshowWindow

- (void)sendEvent:(NSEvent *)event {
	unichar		c;
	BOOL		handled = NO;
	
	switch([event type]) {
		case NSKeyDown:
			c = [event character];
			
			if(c == NSEscapeFunctionKey || ([event commandKeyModifier] && c == 'f') || ([event commandKeyModifier] && c == '.')) {
				[self close];
					
				handled = YES;
			}
			else if(c == ' ') {
				if([event modifierFlags] & NSShiftKeyMask)
					[[self delegate] previousImage:self];
				else
					[[self delegate] nextImage:self];
				
				handled = YES;
			}
			else if(c == NSPageUpFunctionKey) {
				[[self delegate] previousPage:self];
				
				handled = YES;
			}
			else if(c == NSPageDownFunctionKey) {
				[[self delegate] nextPage:self];
				
				handled = YES;
			}
			else if(c == NSHomeFunctionKey) {
				[[self delegate] firstFile:self];
				
				handled = YES;
			}
			else if(c == NSEndFunctionKey) {
				[[self delegate] lastFile:self];
				
				handled = YES;
			}
			else if(c == NSUpArrowFunctionKey || c == NSLeftArrowFunctionKey) {
				[[self delegate] previousImage:self];
				
				handled = YES;
			}
			else {
				[[self delegate] nextImage:self];
				
				handled = YES;
			}
			break;
		
		case NSLeftMouseDown:
			[[self delegate] nextImage:self];
			
			handled = YES;
			break;
		
		case NSRightMouseDown:
			[[self delegate] previousImage:self];
			
			handled = YES;
			break;
		
		case NSScrollWheel:
			if([event deltaY] < 0.0f)
				[[self delegate] nextImage:self];
			else
				[[self delegate] previousImage:self];
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
