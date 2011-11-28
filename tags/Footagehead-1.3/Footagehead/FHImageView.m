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

#import "FHImage.h"
#import "FHImageView.h"
#import "FHWindowController.h"

@interface FHImageView(Private)

- (void)_initImageView;

- (void)_adjustScaling;
- (NSSize)_scaledImageSizeForSize:(NSSize)size bounds:(NSSize)bounds;

@end


@implementation FHImageView(Private)

- (void)_initImageView {
	_imageScaling = FHScaleProportionally;
	_backgroundColor = [[NSColor whiteColor] retain];

    _labelAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
        [NSFont boldSystemFont],	NSFontAttributeName,
        [NSColor blackColor],		NSForegroundColorAttributeName,
        NULL];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_FH_viewFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:self];
}



#pragma mark -

- (void)_FH_viewFrameDidChange:(NSNotification *)notification {
	[self _adjustScaling];
		
	if([_scrollView hasHorizontalScroller] || [_scrollView hasVerticalScroller])
		[_scrollView setDocumentCursor:[NSCursor openHandCursor]];
	else
		[_scrollView setDocumentCursor:[NSCursor arrowCursor]];
}



#pragma mark -

- (void)_adjustScaling {
	NSSize      contentSize, imageSize, combinedImageSize, frameSize;
	CGFloat		scrollerWidth;
	double		diff;
	
	if(_adjustingScaling)
		return;
	
	_adjustingScaling = YES;
	
	if(_scrollView) {
		[_scrollView setHasHorizontalScroller:NO];
		[_scrollView setHasVerticalScroller:NO];

		contentSize = [_scrollView documentVisibleRect].size;
		
		[self setFrameSize:contentSize];
		
		if(_combinedImageSize.width > 0.0 &&
		   (_imageScaling == FHScaleNone ||
			_imageScaling == FHScaleWidthProportionally ||
			_imageScaling == FHScaleHeightProportionally)) {
			
			if(ABS(_imageRotation) == 0.0 || ABS(_imageRotation) == 180.0) {
				imageSize = [self _scaledImageSizeForSize:_combinedImageSize bounds:contentSize];
			} else {
				if(_image) {
					combinedImageSize.width = _combinedImageSize.height;
					combinedImageSize.height = _combinedImageSize.width;
				} else {
					combinedImageSize.width = MAX(_leftSize.height, _rightSize.height);
					combinedImageSize.height = _leftSize.width + _rightSize.width;
				}

				imageSize = [self _scaledImageSizeForSize:combinedImageSize bounds:contentSize];
			}
			
			frameSize = NSMakeSize(MAX(contentSize.width, imageSize.width), MAX(contentSize.height, imageSize.height));
			
			scrollerWidth = [NSScroller scrollerWidth];
			
			diff = (contentSize.width / imageSize.width) * scrollerWidth;

			if(imageSize.width - diff > contentSize.width) {
				[_scrollView setHasHorizontalScroller:YES];
				
				frameSize.height -= scrollerWidth;
				
				if(imageSize.height > contentSize.height - scrollerWidth)
					frameSize.width -= diff;
			}
			
			diff = (contentSize.height / imageSize.height) * scrollerWidth;

			if(imageSize.height - diff > contentSize.height) {
				[_scrollView setHasVerticalScroller:YES];
				
				frameSize.width -= scrollerWidth;
				
				if(imageSize.width > contentSize.width - scrollerWidth)
					frameSize.height -= diff;
			}
			
			[self setFrameSize:frameSize];
			[self scrollPoint:NSMakePoint(0.0, frameSize.height)];
		}
	}
	
	_adjustingScaling = NO;
}



- (NSSize)_scaledImageSizeForSize:(NSSize)size bounds:(NSSize)bounds {
	float		dx, dy, d;
	
	if(_imageScaling == FHScaleNone)
		return size;
	
	if(_imageScaling == FHScaleStretched)
		return bounds;
	
	if(ABS(_imageRotation) == 90.0 || ABS(_imageRotation) == 270.0) {
		dx = bounds.width  / _combinedImageSize.height;
		dy = bounds.height / _combinedImageSize.width;
	} else {
		dx = bounds.width  / _combinedImageSize.width;
		dy = bounds.height / _combinedImageSize.height;
	}
	
	if(_imageScaling == FHScaleProportionally || _imageScaling == FHScaleStretchedProportionally)
		d = dx < dy ? dx : dy;
	else if(_imageScaling == FHScaleWidthProportionally)
		d = dx;
	else if(_imageScaling == FHScaleHeightProportionally)
		d = dy;
	
	if(d < 1.0 || _imageScaling == FHScaleStretchedProportionally) {
		size.width		= floorf(size.width  * d);
		size.height		= floorf(size.height * d);
	}
	
	return size;
}

@end


@implementation FHImageView

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];

	[self _initImageView];

	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];

	[self _initImageView];

	return self;
}



- (void)dealloc {
	[_image release];
	[_rightImage release];
	[_leftImage release];

	[_backgroundColor release];
	
	[_label release];
	[_labelAttributes release];

	[super dealloc];
}



#pragma mark -

- (void)setImage:(FHImage *)image {
	BOOL	display;

	display = (image != NULL || _image != NULL || _leftImage != NULL || _rightImage != NULL);
	
	[_leftImage release];
	_leftImage = NULL;
	
	[_rightImage release];
	_rightImage = NULL;
	
	[image retain];
	[_image release];
	
	_image = image;
	
	if(_image) {
		_combinedImageSize = [_image size];
	} else {
		_combinedImageSize.width = 0.0;
		_combinedImageSize.height = 0.0;
	}

	[self _adjustScaling];
	
	if(display)
		[self setNeedsDisplay:YES];
}



- (FHImage *)image {
	return _image;
}



- (void)setLeftImage:(FHImage *)leftImage rightImage:(FHImage *)rightImage {
	BOOL	display;

	display = (_image != NULL || leftImage != NULL || _leftImage != NULL || rightImage != NULL || _rightImage != NULL);
	
	[_image release];
	_image = NULL;
	
	[leftImage retain];
	[_leftImage release];
	
	_leftImage = leftImage;
	
	if(_leftImage) {
		_leftSize = [_leftImage size];
	} else {
		_leftSize.width = 0.0;
		_leftSize.height = 0.0;
	}
	
	[rightImage retain];
	[_rightImage release];
	
	_rightImage = rightImage;
	
	if(_rightImage) {
		_rightSize = [_rightImage size];
	} else {
		_rightSize.width = 0.0;
		_rightSize.height = 0.0;
	}
	
	_combinedImageSize.width = _leftSize.width + _rightSize.width;
	_combinedImageSize.height = MAX(_leftSize.height, _rightSize.height);

	[self _adjustScaling];
	
	if(display)
		[self setNeedsDisplay:YES];
}



- (FHImage *)leftImage {
	return _leftImage;
}



- (FHImage *)rightImage {
	return _rightImage;
}



- (NSSize)combinedImageSize {
	return _combinedImageSize;
}



- (void)setImageScaling:(FHImageScaling)imageScaling {
	_imageScaling = imageScaling;

	[self _adjustScaling];
	
	[self setNeedsDisplay:YES];
}



- (FHImageScaling)imageScaling {
	return _imageScaling;
}



- (void)setImageRotation:(float)imageRotation {
	_imageRotation = imageRotation;

	[self _adjustScaling];
	
	[self setNeedsDisplay:YES];
}



- (float)imageRotation {
	return _imageRotation;
}



- (void)setBackgroundColor:(NSColor *)color {
	NSColor		*textColor;
	
	[color retain];
	[_backgroundColor release];
	
	_backgroundColor = color;
	
	if([_backgroundColor whiteComponent] < 0.5)
		textColor = [NSColor whiteColor];
	else
		textColor = [NSColor blackColor];
	
	[_labelAttributes setObject:textColor forKey:NSForegroundColorAttributeName];

	[self setNeedsDisplay:YES];
}



- (NSColor *)backgroundColor {
	return _backgroundColor;
}



- (void)setLabel:(NSString *)label {
	[label retain];
	[_label release];
	
	_label = label;

	[self setNeedsDisplay:YES];
}



- (NSString *)label {
	return _label;
}



#pragma mark -

- (void)mouseDown:(NSEvent *)event {
	_dragging = NO;
}



- (void)mouseDragged:(NSEvent *)event {
	NSPoint		point, originalPoint;
	NSRect		originalRect;
	float		x, y;
	
	_dragging = YES;

	if([_scrollView hasHorizontalScroller] || [_scrollView hasVerticalScroller]) {
		originalPoint	= [event locationInWindow];
		originalRect	= [self visibleRect];
		
		[[NSCursor closedHandCursor] push];
		
		do {
			event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask];
			
			if([event type] == NSLeftMouseDragged) {
				point	= [event locationInWindow];
				x		= originalPoint.x - point.x;
				y		= originalPoint.y - point.y;
				
				[self scrollRectToVisible:NSOffsetRect(originalRect, x, y)];
			}
		} while([event type] != NSLeftMouseUp);
		
		[NSCursor pop];
	}
}



- (void)scrollWheel:(NSEvent *)event {
	NSScroller		*scroller;
	BOOL			up, handled = NO;
	
	scroller = [_scrollView verticalScroller];
	up = ([event deltaY] > 0.0f);
	
	if(![_scrollView hasVerticalScroller] || (up && [scroller floatValue] == 0.0f) || (!up && [scroller floatValue] == 1.0f)) {
		if(!up)
			[_delegate nextImage:self];
		else
			[_delegate previousImage:self];
		
		handled = YES;
	}
	
	if(!handled)
		[_scrollView scrollWheel:event];
}



#pragma mark -

- (BOOL)isOpaque {
	return YES;
}



- (void)drawRect:(NSRect)frame {
	FHImage		*image;
	NSRect		bounds, rect;
	NSSize		size;
	
	bounds = [self bounds];
	
	[_backgroundColor set];
	NSRectFill(bounds);
	
	if(_image || _leftImage || _rightImage) {
		if(_image) {
			rect.size = [self _scaledImageSizeForSize:_combinedImageSize bounds:bounds.size];
			rect.origin.x = floorf((bounds.size.width  - rect.size.width)  / 2.0);
			rect.origin.y = floorf((bounds.size.height - rect.size.height) / 2.0);
			
			[_image drawInRect:rect atAngle:_imageRotation];
		} else {
			if(_leftImage && _rightImage) {
				size = [self _scaledImageSizeForSize:_combinedImageSize bounds:bounds.size];
				
				rect.size = [self _scaledImageSizeForSize:_leftSize bounds:bounds.size];
				rect.origin.x = floorf((bounds.size.width  - size.width)  / 2.0);
				rect.origin.y = floorf((bounds.size.height - size.height) / 2.0);

				[_leftImage drawInRect:rect atAngle:_imageRotation];

				rect.origin.x += rect.size.width;
				rect.size = [self _scaledImageSizeForSize:_rightSize bounds:bounds.size];

				[_rightImage drawInRect:rect atAngle:_imageRotation];
			}
			else if(_leftImage || _rightImage) {
				image = _leftImage ? _leftImage : _rightImage;
				size = _leftImage ? _leftSize : _rightSize;
				
				rect.size = [self _scaledImageSizeForSize:size bounds:bounds.size];
				rect.origin.x = floorf((bounds.size.width  - rect.size.width)  / 2.0);
				rect.origin.y = floorf((bounds.size.height - rect.size.height) / 2.0);
				
				[image drawInRect:rect atAngle:_imageRotation];
			}
		}
			
		if(_label && [_label length] > 0)
			[_label drawAtPoint:NSMakePoint(10.0, 10.0) withAttributes:_labelAttributes];
	}
}

@end
