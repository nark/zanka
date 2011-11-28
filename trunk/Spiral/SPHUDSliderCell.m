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

#import "SPHUDSliderCell.h"

@implementation SPHUDSliderCell

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	_knobImage = [[NSImage imageNamed:@"HUDSliderKnob"] retain];
	[_knobImage setFlipped:YES];
	_knobSize = [_knobImage size];
	
	return self;
}



- (void)dealloc {
	[_knobImage release];
	
	[super dealloc];
}



#pragma mark -

- (BOOL)_usesCustomTrackImage {
	return YES;
}



#pragma mark -

- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
	NSBezierPath	*path;
	
	rect.size.height = 13.0;
	rect.origin.x += 3.0;
	rect.origin.y += 0.5;
	rect.size.width -= (3.0 * 2.0) - 1.0;
	
	[[NSColor whiteColor] set];
	
	rect = NSInsetRect(rect, 0.5, 0.5);
	path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];
	[path setLineWidth:1.0];
	[path stroke];

	[[NSColor colorWithCalibratedWhite:0.25 alpha:0.5] set];

	rect = NSInsetRect(rect, 0.5, 0.5);
	path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];
	[path fill];
}



- (void)drawKnob:(NSRect)rect {
	[_knobImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}



- (NSRect)knobRectFlipped:(BOOL)flipped {
	NSRect		rect;
	
	rect = [super knobRectFlipped:flipped];
	rect.size = _knobSize;
	rect.size.width += 1.0;
	rect.size.height += 1.0;
	rect.origin.x += 6.0;
	rect.origin.y += 2.0;
	
	return rect;
}

@end
