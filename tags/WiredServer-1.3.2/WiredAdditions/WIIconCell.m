/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import <WiredAdditions/WIIconCell.h>

@implementation WIIconCell

- (id)init {
	self = [super init];
	
	[self setLineBreakMode:NSLineBreakByTruncatingTail];

	return self;
}



- (id)copyWithZone:(NSZone *)zone {
    WIIconCell		*cell;
	
	cell = [super copyWithZone:zone];
    cell->_image = [_image retain];
	
	return cell;
}



- (void)dealloc {
	[_image release];

	[super dealloc];
}



#pragma mark -

- (void)setImage:(NSImage *)image {
	[image retain];
	[_image release];
	
	_image = image;
}



- (NSImage *)image {
	return _image;
}



#pragma mark -

- (void)editWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)object event:(NSEvent *)event {
	NSRect		textFrame, imageFrame;
	
	NSDivideRect(frame, &imageFrame, &textFrame, 3.0 + [_image size].width, NSMinXEdge);

	[super editWithFrame:textFrame inView:view editor:editor delegate:object event:event];
}



- (void)selectWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate start:(NSInteger)start length:(NSInteger)length {
	NSRect		textFrame, imageFrame;
	
	NSDivideRect(frame, &imageFrame, &textFrame, 3.0 + [_image size].width, NSMinXEdge);

	[super selectWithFrame:textFrame inView:view editor:editor delegate:delegate start:start length:length];
}



- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSSize		imageSize;
	NSRect		imageFrame;
	
	if(_image) {
		imageSize = [_image size];

		NSDivideRect(frame, &imageFrame, &frame, 3.0 + imageSize.width, NSMinXEdge);

		if([self drawsBackground]) {
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		
		imageFrame.origin.x += 3.0;
		imageFrame.size = imageSize;
		
		if ([view isFlipped])
			imageFrame.origin.y += ceil((frame.size.height + imageFrame.size.height) / 2.0);
		else
			imageFrame.origin.y += ceil((frame.size.height - imageFrame.size.height) / 2.0);
		
		[_image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}

	[super drawWithFrame:frame inView:view];
}

@end
