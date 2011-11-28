/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

#import "CPUDataSource.h"
#import "CPUFloatingView.h"
#import "CPUSettings.h"

#define CPUFloatingViewLength			141.0
#define CPUFloatingViewThickness		14.0
#define CPUFloatingViewLines			19
#define CPUFloatingViewLineInterval		7.0


@implementation CPUFloatingView

- (id)initWithFrame:(NSRect)frame isHorizontal:(BOOL)horizontal {
	self = [super initWithFrame:frame];
	
	[self setIsHorizontal:horizontal];

	return self;
}



- (void)dealloc {
	[_backgroundImage release];
	[_color release];
	
	[super dealloc];
}



#pragma mark -

- (void)setIsHorizontal:(BOOL)horizontal {
	NSRect			frame;
	unsigned int	numberOfCPUs;

	frame			= [self frame];
	numberOfCPUs	= [CPUDataSource dataSource]->_numberOfCPUs;
	
	if(horizontal) {
		frame.size.width = CPUFloatingViewLength;
		frame.size.height = (numberOfCPUs * CPUFloatingViewThickness) - (numberOfCPUs - 1);
	} else {
		frame.size.width = (numberOfCPUs * CPUFloatingViewThickness) - (numberOfCPUs - 1);
		frame.size.height = CPUFloatingViewLength;
	}
	
	_horizontal = horizontal;
	
	[self invalidate];
	[self setFrame:frame];
}



- (BOOL)isHorizontal {
	return _horizontal;
}



#pragma mark -

- (void)invalidate {
	[_backgroundImage release];
	_backgroundImage = NULL;
	
	[_foregroundImage release];
	_foregroundImage = NULL;

	[_color release];
	_color = NULL;
}



#pragma mark -

- (void)drawRect:(NSRect)frame {
	CPUDataSource   *dataSource;
	CPUData			*data;
	NSBezierPath	*path;
	NSPoint			start, stop;
	CGFloat			x, y, width, height;
	NSUInteger		i, numberOfCPUs;
	
	dataSource		= [CPUDataSource dataSource];
	numberOfCPUs	= dataSource->_numberOfCPUs;
	
	// --- draw background image
	if(!_backgroundImage) {
		_backgroundImage = [[NSImage alloc] initWithSize:frame.size];
		[_backgroundImage lockFocus];

		[[NSColor colorWithCalibratedWhite:0.67 alpha:1.0] set];
		NSRectFill(frame);

		[[NSColor blackColor] set];

		for(i = 0; i < numberOfCPUs; i++) {
			if(_horizontal) {
				x		= frame.origin.x;
				y		= frame.origin.y + (i * CPUFloatingViewThickness) - (i > 0 ? i : 0);
				width	= CPUFloatingViewLength;
				height	= CPUFloatingViewThickness;
			} else {
				x		= frame.origin.y + (i * CPUFloatingViewThickness) - (i > 0 ? i : 0);
				y		= frame.origin.x;
				width	= CPUFloatingViewThickness;
				height	= CPUFloatingViewLength;
			}

			NSFrameRect(NSMakeRect(x, y, width, height));
		}
		
		[_backgroundImage unlockFocus];
	}
	
	[_backgroundImage drawAtPoint:frame.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

	// --- cache color
	if(!_color)
		_color = [[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUFloatingViewColor]] retain];
	
	// --- draw CPU bar
	[_color set];
	
	for(i = 0; i < numberOfCPUs; i++) {
		data = dataSource->_data[i];
		
		if(_horizontal) {
			width	= (data->_user + data->_system + data->_nice) * (CPUFloatingViewLength - 2.0f);
			height	= CPUFloatingViewThickness - 2.0f;
			x		= frame.origin.x + 1.0f;
			y		= frame.origin.y + 1.0f + (i * height) + i;
		} else {
			width	= CPUFloatingViewThickness - 2.0f;
			height	= (data->_user + data->_system + data->_nice) * (CPUFloatingViewLength - 2.0f);
			x		= frame.origin.y + 1.0f + (i * width) + i;
			y		= frame.origin.x + 1.0f;
		}
		
		NSRectFill(NSMakeRect(x, y, width, height));
	}

	// --- draw foreground image
	if(!_foregroundImage) {
		_foregroundImage = [[NSImage alloc] initWithSize:frame.size];
		[_foregroundImage lockFocus];
		path = [[NSBezierPath alloc] init];
		
		[[NSColor blackColor] set];

		for(i = 0; i < CPUFloatingViewLines; i++) {
			if(_horizontal) {
				x		= frame.origin.x + 0.5f + ((i + 1) * CPUFloatingViewLineInterval);
				start	= NSMakePoint(x, frame.origin.y + frame.size.height);
				stop	= NSMakePoint(x, frame.origin.y);
			} else {
				y		= frame.origin.y + 0.5f + ((i + 1) * CPUFloatingViewLineInterval);
				start	= NSMakePoint(frame.origin.x + frame.size.height, y);
				stop	= NSMakePoint(frame.origin.x, y);
			}

			[path moveToPoint:start];
			[path lineToPoint:stop];
			[path stroke];
			[path removeAllPoints];
		}
		
		[path release];
		[_foregroundImage unlockFocus];
	}
	
	[_foregroundImage drawAtPoint:frame.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

@end
