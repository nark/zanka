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

#import "SPHUDSliderBackgroundView.h"

@interface SPHUDSliderBackgroundView(Private)

- (void)_initHUDSliderBackgroundView;

@end


@implementation SPHUDSliderBackgroundView(Private)

- (void)_initHUDSliderBackgroundView {
	_elapsedTimeImage		= [[NSImage imageNamed:@"HUDElapsedTimeBackground"] retain];
	_elapsedTimeSize		= [_elapsedTimeImage size];
	_remainingTimeImage		= [[NSImage imageNamed:@"HUDRemainingTimeBackground"] retain];
	_remainingTimeSize		= [_remainingTimeImage size];
}

@end



@implementation SPHUDSliderBackgroundView

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initHUDSliderBackgroundView];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initHUDSliderBackgroundView];
	
	return self;
}



- (void)dealloc {
	[_elapsedTimeImage release];
	[_remainingTimeImage release];

	[super dealloc];
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	NSRect		frame, imageRect;
	
	frame = [self frame];
	
	imageRect = NSMakeRect(0.0, 7.0, _elapsedTimeSize.width, _elapsedTimeSize.height);
	[_elapsedTimeImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	imageRect = NSMakeRect(frame.size.width - _remainingTimeSize.width, 7.0, _remainingTimeSize.width, _remainingTimeSize.height);
	[_remainingTimeImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
