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

#import "SPLCDBackgroundView.h"

@interface SPLCDBackgroundView(Private)

- (void)_initLCDBackgroundView;

@end


@implementation SPLCDBackgroundView(Private)

- (void)_initLCDBackgroundView {
	_leftImage		= [[NSImage imageNamed:@"LCDBackgroundLeft"] retain];
	_leftSize		= [_leftImage size];
	_centerImage	= [[NSImage imageNamed:@"LCDBackgroundCenter"] retain];
	_centerSize		= [_centerImage size];
	_rightImage		= [[NSImage imageNamed:@"LCDBackgroundRight"] retain];
	_rightSize		= [_rightImage size];
}

@end



@implementation SPLCDBackgroundView

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initLCDBackgroundView];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initLCDBackgroundView];
	
	return self;
}



- (void)dealloc {
	[_leftImage release];
	[_centerImage release];
	[_rightImage release];

	[super dealloc];
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	NSRect		frame, imageRect;
	CGFloat		centerWidth;
	
	frame = [self frame];
	
	imageRect = NSMakeRect(0.0, 0.0, _leftSize.width, _leftSize.height);
	[_leftImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	centerWidth = frame.size.width - _leftSize.width - _rightSize.width;
	
	if(centerWidth > 0.0) {
		imageRect = NSMakeRect(_leftSize.width, 0.0, centerWidth, _centerSize.height);
		[_centerImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	imageRect = NSMakeRect(frame.size.width - _rightSize.width, 0.0, _rightSize.width, _rightSize.height);
	[_rightImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
