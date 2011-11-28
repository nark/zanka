/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "WCDragScrollView.h"

@implementation WCDragScrollView

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	// --- create cursor for URLs
	_dragCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"HandCursor"]
									hotSpot:NSMakePoint(8.0, 8.0)];
	
	return self;
}


- (void)dealloc {
	[_dragCursor release];
	
	[super dealloc];
}



#pragma mark -

- (void)tile {
	[super tile];

	if([[self documentView] frame].size.height > [self documentVisibleRect].size.height ||
	   [[self documentView] frame].size.width > [self documentVisibleRect].size.width)
		[self setDocumentCursor:_dragCursor];
    else
		[self setDocumentCursor:[NSCursor arrowCursor]];
}



- (void)dragDocumentWithEvent:(NSEvent *)event {
	NSPoint		initialPoint, newPoint;
	NSRect		initialRect, newRect;
	float		x, y;
	BOOL		loop;

	// --- get initial values
	initialPoint	= [event locationInWindow];
	initialRect		= [[self documentView] visibleRect];
	loop			= YES;

	while(loop) {
		event = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];

        switch([event type]) {
			case NSLeftMouseDragged:
				// --- get new delta
				newPoint	= [event locationInWindow];
                x			= initialPoint.x - newPoint.x;
                y			= initialPoint.y - newPoint.y;

				// --- scroll
				newRect = NSOffsetRect(initialRect, x, y);
                [[self documentView] scrollRectToVisible:newRect];
				break;

			case NSLeftMouseUp:
				loop = NO;
				break;

			default:
				break;
		}
	}
}

@end
