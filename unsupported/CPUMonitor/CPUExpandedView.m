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
#import "CPUExpandedView.h"
#import "CPUSettings.h"

#define CPUExpandedViewDividerHeight	5.0
#define CPUExpandedViewLineWidth		4.0
#define CPUExpandedViewLineHeight		3.0
#define CPUExpandedViewBarWidth			3.0

#define CPUExpandedViewIconBarWidth		4.0


@implementation CPUExpandedView

- (void)dealloc {
	if(_userRects)
		free(_userRects);
	
	if(_systemRects)
		free(_systemRects);
	
	if(_niceRects)
		free(_niceRects);
	
	if(_userIconRects)
		free(_userIconRects);
	
	if(_systemIconRects)
		free(_systemIconRects);
	
	if(_niceIconRects)
		free(_niceIconRects);
	
	[super dealloc];
}




#pragma mark -

- (void)invalidate {
	if(_userRects) {
		free(_userRects);
		_userRects = NULL;
	}
	
	if(_systemRects) {
		free(_systemRects);
		_systemRects = NULL;
	}
	
	if(_niceRects) {
		free(_niceRects);
		_niceRects = NULL;
	}
	
	_drawn = NO;
}



#pragma mark -

- (void)resizeWithOldSuperviewSize:(NSSize)oldSize {
	[self invalidate];
	
	[super resizeWithOldSuperviewSize:oldSize];
}



- (void)refresh {
	NSRect		bounds, rect;
	
	if(_drawn) {
		bounds = [self bounds];
		
		[self scrollRect:bounds by:NSMakeSize(-CPUExpandedViewLineWidth, 0.0)];

		rect = NSMakeRect(bounds.origin.x + bounds.size.width - CPUExpandedViewLineWidth,
						  bounds.origin.y,
						  CPUExpandedViewLineWidth,
						  bounds.size.height);
		
		[self setNeedsDisplayInRect:rect];
	} else {
		[self setNeedsDisplay:YES];

		_drawn = YES;
	}
}



- (void)drawRect:(NSRect)frame {
	CPUDataSource   *dataSource;
	CPUData			*data;
	NSBezierPath	*path;
	NSPoint			start, stop;
	NSRect			rect;
	CGFloat			x, y, height, offset;
	NSUInteger		i, j, count, vlines, hlines, cells, numberOfCPUs;
	NSUInteger		userRects, systemRects, niceRects;
	
	dataSource		= [CPUDataSource dataSource];
	numberOfCPUs	= dataSource->_numberOfCPUs;
	
	height = floor((frame.size.height - ((numberOfCPUs - 1) * CPUExpandedViewDividerHeight)) / numberOfCPUs);
	vlines = frame.size.width / CPUExpandedViewLineWidth;
	hlines = height / CPUExpandedViewLineHeight;
	
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	// --- draw background
	[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewBackgroundColor]] set];
	
	for(i = 0; i < numberOfCPUs; i++) {
		x = frame.origin.x;
		y = frame.origin.y + (i * height) + (i * CPUExpandedViewDividerHeight);
		
		NSRectFill(NSMakeRect(x, y, frame.size.width, height));
	}
	
	// --- cache rects
	if(!_userRects) {
		_userRects		= (NSRect *) malloc(sizeof(NSRect) * vlines * numberOfCPUs);
		_systemRects	= (NSRect *) malloc(sizeof(NSRect) * vlines * numberOfCPUs);
		_niceRects		= (NSRect *) malloc(sizeof(NSRect) * vlines * numberOfCPUs);
	}
	
	// --- draw CPU graph
	userRects = systemRects = niceRects = 0;
	
	for(i = 0; i < numberOfCPUs; i++) {
		data	= dataSource->_data[i];
		offset	= (i * height) + (i * CPUExpandedViewDividerHeight);
		
		for(j = data->_historyPosition - 1, count = 0; count < vlines; j--, count++) {
			if(j > CPUDataHistorySize)
				j = CPUDataHistorySize - 1;
			
			x = frame.origin.x + frame.size.width - (CPUExpandedViewBarWidth * (count + 1)) - count - 1.0;
			y = frame.origin.y + offset;
			
			if(data->_niceHistory[j] > 0) {
				cells = data->_niceHistory[j] * hlines;
				rect = NSMakeRect(x, y, CPUExpandedViewBarWidth, cells * CPUExpandedViewLineHeight);
				y += rect.size.height;
				_niceRects[niceRects++] = rect;
			}
			
			if(data->_systemHistory[j] > 0) {
				cells = data->_systemHistory[j] * hlines;
				rect = NSMakeRect(x, y, CPUExpandedViewBarWidth, cells * CPUExpandedViewLineHeight);
				y += rect.size.height;
				_systemRects[systemRects++] = rect;
			}
			
			if(data->_userHistory[j] > 0) {
				cells = data->_userHistory[j] * hlines;
				rect = NSMakeRect(x, y, CPUExpandedViewBarWidth, cells * CPUExpandedViewLineHeight);
				_userRects[userRects++] = rect;
			}
		}
	}
	
	if(userRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewUserColor]] set];
		NSRectFillList(_userRects, userRects);
	}
	
	if(systemRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewSystemColor]] set];
		NSRectFillList(_systemRects, systemRects);
	}
	
	if(niceRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewNiceColor]] set];
		NSRectFillList(_niceRects, niceRects);
	}
	
	// --- draw horizontal grid image
	path = [[NSBezierPath alloc] init];
	
	[[NSColor blackColor] set];
	
	for(i = 0; i < numberOfCPUs; i++) {
		offset = (i * height) + (i * CPUExpandedViewDividerHeight);
		
		for(j = 0; j < hlines + 1; j++) {
			y		= frame.origin.y + (CPUExpandedViewLineHeight * j) + offset + 0.5;
			start   = NSMakePoint(frame.origin.x + frame.size.width, y);
			stop	= NSMakePoint(frame.origin.x, y);
			
			[path moveToPoint:start];
			[path lineToPoint:stop];
			[path stroke];
			[path removeAllPoints];
		}
		
		for(j = 0; j < vlines + 1; j++) {
			x		= frame.origin.x + frame.size.width - (CPUExpandedViewLineWidth * j) - 0.5;
			start   = NSMakePoint(x, frame.origin.y + offset + height);
			stop	= NSMakePoint(x, frame.origin.y + offset);
			
			[path moveToPoint:start];
			[path lineToPoint:stop];
			[path stroke];
			[path removeAllPoints];
		}
	}
	
	[path release];
}



- (void)drawIconInRect:(NSRect)frame {
	CPUDataSource   *dataSource;
	CPUData			*data;
	NSRect			rect;
	CGFloat			x, y, height, user, system, nice;
	NSUInteger		i, j, count, bars, numberOfCPUs;
	NSUInteger		userRects, systemRects, niceRects;
	
	dataSource		= [CPUDataSource dataSource];
	numberOfCPUs	= dataSource->_numberOfCPUs;
	bars			= (frame.size.width - 2.0f) / CPUExpandedViewIconBarWidth;
	height			= frame.size.height - 4.0f;
	
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	// --- draw background
	[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewBackgroundColor]] set];
	NSRectFill(frame);
	
	[[NSColor blackColor] set];
	NSFrameRect(frame);

	// --- cache rects
	if(!_userIconRects) {
		_userIconRects		= (NSRect *) malloc(sizeof(NSRect) * bars * numberOfCPUs);
		_systemIconRects	= (NSRect *) malloc(sizeof(NSRect) * bars * numberOfCPUs);
		_niceIconRects		= (NSRect *) malloc(sizeof(NSRect) * bars * numberOfCPUs);
	}
	
	// --- draw CPU graph
	userRects = systemRects = niceRects = 0;
	
	for(j = dataSource->_data[0]->_historyPosition - 1, count = 0; count < bars; j--, count++) {
		if(j > CPUDataHistorySize)
			j = CPUDataHistorySize - 1;
			
		user = system = nice = 0.0;
		
		for(i = 0; i < numberOfCPUs; i++) {
			data	= dataSource->_data[i];
			user	+= data->_userHistory[j];
			system	+= data->_systemHistory[j];
			nice	+= data->_niceHistory[j];
		}
		
		user	/= numberOfCPUs;
		system	/= numberOfCPUs;
		nice	/= numberOfCPUs;
		
		x = frame.origin.x + frame.size.width - 1.0 - (CPUExpandedViewIconBarWidth * (count + 1));
		y = frame.origin.y + 1.0;
		
		if(nice > 0.0) {
			rect = NSMakeRect(x, y, CPUExpandedViewIconBarWidth, nice * height);
			y += rect.size.height;
			_niceIconRects[niceRects++] = rect;
		}
		
		if(system > 0.0) {
			rect = NSMakeRect(x, y, CPUExpandedViewIconBarWidth, system * height);
			y += rect.size.height;
			_systemIconRects[systemRects++] = rect;
		}
		
		if(user > 0.0) {
			rect = NSMakeRect(x, y, CPUExpandedViewIconBarWidth, user * height);
			_userIconRects[userRects++] = rect;
		}
	}
	
	if(userRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewUserColor]] set];
		NSRectFillList(_userIconRects, userRects);
	}
	
	if(systemRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewSystemColor]] set];
		NSRectFillList(_systemIconRects, systemRects);
	}
	
	if(niceRects > 0) {
		[[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewNiceColor]] set];
		NSRectFillList(_niceIconRects, niceRects);
	}
}

@end
