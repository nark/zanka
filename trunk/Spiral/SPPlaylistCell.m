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

#import "SPPlaylistCell.h"
#import "SPPlaylistItem.h"

@implementation SPPlaylistCell

- (id)init {
	self = [super init];
	
	_unviewedImage = [[NSImage imageNamed:@"Unviewed.tiff"] retain];
	_halfViewedImage = [[NSImage imageNamed:@"HalfViewed.tiff"] retain];

	return self;
}



- (id)copyWithZone:(NSZone *)zone {
    SPPlaylistCell		*cell;
	
	cell = [super copyWithZone:zone];
    cell->_unviewedImage = [_unviewedImage retain];
    cell->_halfViewedImage = [_halfViewedImage retain];
	cell->_showsViewStatus = _showsViewStatus;
	cell->_viewStatus = _viewStatus;
	
	return cell;
}



- (void)dealloc {
	[_unviewedImage release];
	[_halfViewedImage release];

	[super dealloc];
}



#pragma mark -

- (void)setShowsViewStatus:(BOOL)showsViewStatus {
	_showsViewStatus = showsViewStatus;
	
	[self setHorizontalTextOffset:_showsViewStatus ? 18.0 : 0.0];
}



- (BOOL)showsViewStatus {
	return _showsViewStatus;
}



- (void)setViewStatus:(SPPlaylistViewStatus)viewStatus {
	_viewStatus = viewStatus;
}



- (SPPlaylistViewStatus)viewStatus {
	return _viewStatus;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSImage		*image;
	NSRect		imageFrame;
	
	if(_showsViewStatus && _viewStatus != SPPlaylistViewed) {
		if(_viewStatus == SPPlaylistHalfViewed)
			image = _halfViewedImage;
		else
			image = _unviewedImage;
		
		imageFrame.origin = frame.origin;
		imageFrame.origin.x += [[super image] size].width + 8.0;
		imageFrame.size = [image size];
		
		if ([view isFlipped])
			imageFrame.origin.y += ceil((frame.size.height + imageFrame.size.height) / 2.0);
		else
			imageFrame.origin.y += ceil((frame.size.height - imageFrame.size.height) / 2.0);
		
		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	
	[super drawWithFrame:frame inView:view];
}

@end
