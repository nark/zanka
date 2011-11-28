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

#import "FHImageView.h"
#import "FHTableView.h"
#import "FHBrowserController.h"

@implementation FHTableView

- (void)keyDown:(NSEvent *)event {
	NSScroller	*scroller;
	NSRect		rect;
	unichar		c;
	float		delta, proportion;
	BOOL		up, handled = NO;
	
	c = [event character];
	
	if(c == ' ') {
		up = ([event modifierFlags] & NSShiftKeyMask) ? YES : NO;
		
		if([_imageScrollView hasVerticalScroller]) {
			scroller = [_imageScrollView verticalScroller];
			proportion = [scroller knobProportion] / 30.0;
			
			if((up &&  [scroller floatValue] > proportion) ||
			   (!up && [scroller floatValue] < 1.0 - proportion)) {
				rect = [_imageScrollView documentVisibleRect];
				delta = 0.75 * rect.size.height; 
				rect.origin.y += up ? delta : -delta;
				[_imageView scrollPoint:rect.origin];

				handled = YES;
			}
		}

		if(!handled) {
			if(up) {
				if([[self delegate] previousImage:self])
					[_imageView scrollPoint:NSZeroPoint];
			} else {
				[[self delegate] nextImage:self];
			}
			
			handled = YES;
		}
	}
	else if(c == NSPageUpFunctionKey || c == NSPageDownFunctionKey) {
		if([_imageScrollView hasVerticalScroller]) {
			scroller = [_imageScrollView verticalScroller];
			proportion = [scroller knobProportion] / 30.0;
			
			if((c == NSPageUpFunctionKey   && [scroller floatValue] > proportion) ||
			   (c == NSPageDownFunctionKey && [scroller floatValue] < 1.0 - proportion)) {
				rect = [_imageScrollView documentVisibleRect];
				delta = rect.size.height;
				rect.origin.y += (c == NSPageUpFunctionKey) ? delta : -delta;
				[_imageView scrollPoint:rect.origin];

				handled = YES;
			}
		}

		if(!handled) {
			if(c == NSPageUpFunctionKey)
				[[self delegate] previousPage:self];
			else
				[[self delegate] nextPage:self];
		
			handled = YES;
		}
	}
	else if(c == NSHomeFunctionKey || c == NSEndFunctionKey) {
		if([_imageScrollView hasVerticalScroller]) {
			scroller = [_imageScrollView verticalScroller];
			proportion = [scroller knobProportion] / 30.0;
			
			if((c == NSHomeFunctionKey && [scroller floatValue] > proportion) ||
			   (c == NSEndFunctionKey  && [scroller floatValue] < 1.0 - proportion)) {
				rect = [_imageView frame];
				rect.origin.y = (c == NSHomeFunctionKey) ? rect.size.height : 0;
				[_imageView scrollPoint:rect.origin];

				handled = YES;
			}
		}
		
		if(!handled) {
			if(c == NSHomeFunctionKey)
				[[self delegate] firstFile:self];
			else
				[[self delegate] lastFile:self];
		
			handled = YES;
		}
	}
	else if(c == NSUpArrowFunctionKey || c == NSDownArrowFunctionKey) {
		if([_imageScrollView hasVerticalScroller]) {
			scroller = [_imageScrollView verticalScroller];
			proportion = [scroller knobProportion] / 30.0;
			
			if((c == NSUpArrowFunctionKey   && [scroller floatValue] > proportion) ||
			   (c == NSDownArrowFunctionKey && [scroller floatValue] < 1.0 - proportion)) {
				rect = [_imageScrollView documentVisibleRect];
				delta = 0.75 * rect.size.height; 
				rect.origin.y += (c == NSUpArrowFunctionKey) ? delta : -delta;
				[_imageView scrollPoint:rect.origin];

				handled = YES;
			}
		}
		
		if(!handled) {
			if(c == NSUpArrowFunctionKey) {
				if([[self delegate] previousFile:self])
					[_imageView scrollPoint:NSZeroPoint];
			} else {
				[[self delegate] nextFile:self];
			}
		
			handled = YES;
		}
	}
	else if(c == NSRightArrowFunctionKey || c == NSLeftArrowFunctionKey) {
		if([_imageScrollView hasHorizontalScroller]) {
			scroller = [_imageScrollView horizontalScroller];
			proportion = [scroller knobProportion] / 30.0;
			
			if((c == NSRightArrowFunctionKey && [scroller floatValue] < 1.0 - proportion) ||
			   (c == NSLeftArrowFunctionKey  && [scroller floatValue] > proportion)) {
				rect = [_imageScrollView documentVisibleRect];
				delta = 0.75 * rect.size.height; 
				rect.origin.x += (c == NSRightArrowFunctionKey) ? delta : -delta;
				[_imageView scrollPoint:rect.origin];

				handled = YES;
			}
		}
	}
	
	if(!handled)
		[super keyDown:event];
}



- (void)paste:(id)sender {
	WIURL		*url;
	
	url = [WIURL URLWithString:[[NSPasteboard generalPasteboard] stringForType:NSStringPboardType]];
	
	if(url)
		[[self delegate] loadURL:url];
}

@end
