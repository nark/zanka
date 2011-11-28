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

#import "SPHUDBackgroundView.h"

@interface SPHUDBackgroundView(Private)

- (void)_initHUDBackgroundView;

@end


@implementation SPHUDBackgroundView(Private)

- (void)_initHUDBackgroundView {
	_backgroundImage = [[NSImage imageNamed:@"HUDBackground"] retain];
}

@end



@implementation SPHUDBackgroundView

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initHUDBackgroundView];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initHUDBackgroundView];
	
	return self;
}



- (void)dealloc {
	[_backgroundImage release];

	[super dealloc];
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	[_backgroundImage drawInRect:[self frame] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.5];
}

@end
