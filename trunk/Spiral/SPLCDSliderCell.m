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

#import "SPLCDSliderCell.h"

@implementation SPLCDSliderCell

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	_knobImage = [[NSImage imageNamed:@"LCDSliderKnob"] retain];
	[_knobImage setFlipped:YES];
	_knobSize = [_knobImage size];
	
	return self;
}



- (void)dealloc {
	[_knobImage release];
	
	[super dealloc];
}



#pragma mark -

- (void)setProgressDoubleValue:(double)value {
	_progress = value;
}



- (double)progressDoubleValue {
	return _progress;
}



#pragma mark -

- (BOOL)_usesCustomTrackImage {
	return YES;
}



#pragma mark -

- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
	rect.size.height = 8.0;
	rect.origin.y += 6.0;
	rect.origin.x += 10.0;
	rect.size.width -= 10.0 * 2.0;
	
	[[NSColor colorWithCalibratedRed:142.0 / 256.0
							   green:146.0 / 256.0
								blue:121.0 / 256.0
							   alpha:1.0] set];
	
	rect = NSInsetRect(rect, 0.5, 0.5);
	
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:rect];
	
	[[NSColor colorWithCalibratedRed:172.0 / 256.0
							   green:178.0 / 256.0
								blue:146.0 / 256.0
							   alpha:1.0] set];

	rect = NSInsetRect(rect, 0.5, 0.5);
	rect.size.width *= [self progressDoubleValue];
	
	NSRectFill(rect);
}



- (void)drawKnob:(NSRect)rect {
	[_knobImage drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}



- (NSRect)knobRectFlipped:(BOOL)flipped {
	NSRect		rect;
	
	rect = [super knobRectFlipped:flipped];
	rect.size = _knobSize;
	rect.origin.y += 2.0;
	rect.origin.x += 4.0;
	
	return rect;
}

@end
