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

#import "FHFileCell.h"
#import "FHImage.h"

@implementation FHFileCell

- (id)copyWithZone:(NSZone *)zone {
    FHFileCell		*cell;
	
	cell = [super copyWithZone:zone];
    cell->_image = [_image retain];
	
	return cell;
}



- (void)dealloc {
	[_image release];

	[super dealloc];
}



#pragma mark -

- (void)setImage:(FHImage *)image {
	[image retain];
	[_image release];
	
	_image = image;
}



- (FHImage *)image {
	return _image;
}



#pragma mark -

- (void)editWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)object event:(NSEvent *)event {
	NSRect		textFrame, imageFrame;
	
	NSDivideRect(frame, &textFrame, &imageFrame, 26.0, NSMaxYEdge);

	[super editWithFrame:textFrame inView:view editor:editor delegate:object event:event];
}



- (void)selectWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate start:(NSInteger)start length:(NSInteger)length {
	NSRect		textFrame, imageFrame;
	
	NSDivideRect(frame, &textFrame, &imageFrame, 26.0, NSMaxYEdge);

	[super selectWithFrame:textFrame inView:view editor:editor delegate:delegate start:start length:length];
}



- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	CGContextRef		context;
	NSSize				size;
	NSRect				imageFrame, rect;
	CGFloat				dx, dy, d, angle;
	
	if(_image) {
		NSDivideRect(frame, &frame, &rect, 34.0, NSMaxYEdge);

		size				= [_image size];
		angle				= [_image orientation];
		imageFrame.origin	= rect.origin;
		imageFrame.size		= size;
		
		if(angle == 0.0 || angle == 180.0) {
			dx = rect.size.width  / imageFrame.size.width;
			dy = rect.size.height / imageFrame.size.height;
		} else {
			dx = rect.size.width  / imageFrame.size.height;
			dy = rect.size.height / imageFrame.size.width;
		}
		
		d = dx < dy ? dx : dy;
		
		if(d < 1.0) {
			imageFrame.size.width	= floorf(imageFrame.size.width  * d);
			imageFrame.size.height	= floorf(imageFrame.size.height * d);
		}
		
		if(angle == 0.0 || angle == 180.0) {
			imageFrame.origin.x += floorf((rect.size.width  - imageFrame.size.width)  / 2.0);
			imageFrame.origin.y += floorf((rect.size.height - imageFrame.size.height) / 2.0);
		} else {
			imageFrame.origin.x += floorf((rect.size.width  - imageFrame.size.height) / 2.0);
			imageFrame.origin.y += floorf((rect.size.height - imageFrame.size.width)  / 2.0);
		}
		
		if(angle == 90.0) {
			imageFrame.origin.y -= imageFrame.size.height;
		}
		else if(angle == 180.0) {
			imageFrame.origin.x += imageFrame.size.width;
			imageFrame.origin.y += imageFrame.size.height;
		}
		else if(angle == 270.0) {
			imageFrame.origin.x += imageFrame.size.height;
		}
		
		context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
		CGContextSaveGState(context);
		
		if(angle == 90.0) {
			CGContextTranslateCTM(context, 0.0, imageFrame.origin.y + imageFrame.origin.y + imageFrame.size.height);
			CGContextScaleCTM(context, 1.0, -1.0);
		}
		
		if(angle == 90.0 || angle == 180.0 || angle == 270.0) {
			CGContextTranslateCTM(context, imageFrame.origin.x, imageFrame.origin.y);
			CGContextRotateCTM(context, -angle * M_PI / 180.0);
			CGContextTranslateCTM(context, -imageFrame.origin.x, -imageFrame.origin.y);
		}
		
		if(angle == 0.0 || angle == 180.0 || angle == 270.0) {
			CGContextTranslateCTM(context, 0.0, imageFrame.origin.y + imageFrame.origin.y + imageFrame.size.height);
			CGContextScaleCTM(context, 1.0, -1.0);
		}
		
		[_image drawInRect:imageFrame];
		
		CGContextRestoreGState(context);
	}

	[super drawWithFrame:frame inView:view];
}

@end
