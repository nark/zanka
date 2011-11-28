/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPDrillViewStatusView.h"

@implementation SPDrillViewStatusView

- (void)setViewStatus:(SPPlaylistViewStatus)viewStatus {
	_viewStatus = viewStatus;
}



- (SPPlaylistViewStatus)viewStatus {
	return _viewStatus;
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	NSBezierPath	*path;
	NSPoint			center;
	
	[[NSColor whiteColor] set];
	
	rect = NSInsetRect(rect, 8.0, 8.0);
	
	if(_viewStatus == SPPlaylistHalfViewed) {
		path = [NSBezierPath bezierPathWithOvalInRect:rect];
		[path setLineWidth:8.0];
		[path stroke];
		
		center = NSMakePoint(rect.origin.x + (rect.size.width / 2.0), rect.origin.y + (rect.size.height / 2.0));
		
		path = [NSBezierPath bezierPath];
		[path appendBezierPathWithArcWithCenter:center
										 radius:(rect.size.height / 2.0)
									 startAngle:90.0
									   endAngle:270.0];
		[path closePath];
		[path fill];
	}
	else if(_viewStatus == SPPlaylistUnviewed) {
		path = [NSBezierPath bezierPathWithOvalInRect:rect];
		[path fill];
	}
}

@end
