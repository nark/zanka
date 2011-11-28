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

- (void)_adjustImageSize;
- (void)_adjustFrameSize;
- (CGFloat)_scaleFactorUsingScaling:(FHImageScaling)imageScaling bounds:(NSSize)bounds;
- (NSSize)_scaledSizeForSize:(NSSize)size usingScaling:(FHImageScaling)imageScaling bounds:(NSSize)bounds;

@end


@implementation FHImageView(Private)

- (void)_initImageView {
	_imageScaling = FHScaleProportionally;
	_backgroundColor = [[NSColor whiteColor] retain];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(_FH_viewFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:self];
}



#pragma mark -

- (void)_FH_viewFrameDidChange:(NSNotification *)notification {
	[self _adjustFrameSize];
		
	if([_scrollView hasHorizontalScroller] || [_scrollView hasVerticalScroller])
		[_scrollView setDocumentCursor:[NSCursor openHandCursor]];
	else
		[_scrollView setDocumentCursor:[NSCursor arrowCursor]];
}



#pragma mark -

- (void)_adjustImageSize {
	NSSize		orientedLeftSize, orientedRightSize;
	
	if(_image) {
		_imageAngle = _imageRotation + _imageOrientation;
		
		if(_imageAngle >= 360.0)
			_imageAngle -= 360.0;
		
		if(_imageAngle == 0.0 || _imageAngle == 180.0)
			_rotatedImageSize = _imageSize;
		else
			_rotatedImageSize = WISwapSize(_imageSize);
	} else {
		_leftImageAngle = _imageRotation + _leftImageOrientation;
		
		if(_leftImageAngle >= 360.0)
			_leftImageAngle -= 360.0;
		
		if(_leftImageAngle == 0.0 || _leftImageAngle == 180.0)
			_rotatedLeftImageSize = _leftImageSize;
		else
			_rotatedLeftImageSize = WISwapSize(_leftImageSize);

		if(_leftImageOrientation == 0.0 || _leftImageOrientation == 180.0)
			orientedLeftSize = _leftImageSize;
		else
			orientedLeftSize = WISwapSize(_leftImageSize);
		
		_rightImageAngle = _imageRotation + _rightImageOrientation;
		
		if(_rightImageAngle >= 360.0)
			_rightImageAngle -= 360.0;
		
		if(_rightImageAngle == 0.0 || _rightImageAngle == 180.0)
			_rotatedRightImageSize = _rightImageSize;
		else
			_rotatedRightImageSize = WISwapSize(_rightImageSize);
		
		if(_rightImageOrientation == 0.0 || _rightImageOrientation == 180.0)
			orientedRightSize = _rightImageSize;
		else
			orientedRightSize = WISwapSize(_rightImageSize);

		_imageSize.width = orientedLeftSize.width + orientedRightSize.width;
		_imageSize.height = MAX(orientedLeftSize.height, orientedRightSize.height);
		
		if(_imageRotation == 0.0 || _imageRotation == 180.0)
			_rotatedImageSize = _imageSize;
		else
			_rotatedImageSize = WISwapSize(_imageSize);
	}
}



- (void)_adjustFrameSize {
	NSRect		frame;
	NSSize		visibleSize, imageSize, frameSize;
	CGFloat		diff, scrollerWidth, widthAdjustment, heightAdjustment;
	BOOL		horizontalScroller, verticalScroller;
	
	if(_adjustingFrameSize)
		return;
	
	_adjustingFrameSize = YES;
	
	if(_scrollView) {
		[_scrollView setHasHorizontalScroller:NO];
		[_scrollView setHasVerticalScroller:NO];
		
		visibleSize = [_scrollView documentVisibleRect].size;
		
		_adjustedImageScaling = _imageScaling;
		
		if(_imageScaling == FHScaleNone ||
		   _imageScaling == FHScaleWidthProportionally ||
		   _imageScaling == FHScaleHeightProportionally) {
			scrollerWidth = [NSScroller scrollerWidth];
			widthAdjustment = heightAdjustment = 0.0;
			horizontalScroller = verticalScroller = NO;
			
			imageSize = [self _scaledSizeForSize:_rotatedImageSize usingScaling:_imageScaling bounds:visibleSize];

			if(_imageScaling == FHScaleNone) {
				if(imageSize.height > visibleSize.height && imageSize.width > visibleSize.width)
					horizontalScroller = verticalScroller = YES;
				else if(imageSize.height > visibleSize.height)
					verticalScroller = YES;
				else if(imageSize.width > visibleSize.width)
					horizontalScroller = YES;
			}
			else if(_imageScaling == FHScaleWidthProportionally) {
				if(imageSize.height - visibleSize.height > scrollerWidth) {
					diff = scrollerWidth - (visibleSize.width - imageSize.width);

					if(diff > 0.0)
						heightAdjustment = ceil((imageSize.height / imageSize.width) * diff);
					
					verticalScroller = YES;
				} else {
					_adjustedImageScaling = FHScaleProportionally;
				}
			}
			else if(_imageScaling == FHScaleHeightProportionally) {
				if(imageSize.width - visibleSize.width > scrollerWidth) {
					diff = scrollerWidth - (visibleSize.height - imageSize.height);
					
					if(diff > 0.0)
						widthAdjustment = ceil((imageSize.width / imageSize.height) * diff);

					horizontalScroller = YES;
				} else {
					_adjustedImageScaling = FHScaleProportionally;
				}
			}
			
			if(_imageScaling != _adjustedImageScaling)
				imageSize = [self _scaledSizeForSize:_rotatedImageSize usingScaling:_adjustedImageScaling bounds:visibleSize];
			
			frameSize = NSMakeSize(MAX(visibleSize.width, imageSize.width), MAX(visibleSize.height, imageSize.height));
			frameSize.width -= widthAdjustment;
			frameSize.height -= heightAdjustment;
			
			[self setFrameSize:frameSize];
			
			[_scrollView setHasHorizontalScroller:horizontalScroller];
			[_scrollView setHasVerticalScroller:verticalScroller];

			[self scrollPoint:NSMakePoint(0.0, frameSize.height)];
		} else {
			[self setFrameSize:visibleSize];
		}
	} else {
		visibleSize = [[self window] frame].size;
		frameSize = [self _scaledSizeForSize:_rotatedImageSize usingScaling:_imageScaling bounds:visibleSize];
		frame.size = frameSize;
		frame.origin.x = floor((visibleSize.width  - frameSize.width)  / 2.0);
		frame.origin.y = floor((visibleSize.height - frameSize.height) / 2.0);
		WILogSize(frameSize);
		[self setFrame:frame];
		_adjustedImageScaling = _imageScaling;
	}

	_adjustingFrameSize = NO;
}



- (CGFloat)_scaleFactorUsingScaling:(FHImageScaling)imageScaling bounds:(NSSize)bounds {
	CGFloat		dx, dy;
	
	dx = bounds.width  / _rotatedImageSize.width;
	dy = bounds.height / _rotatedImageSize.height;
	
	if(imageScaling == FHScaleProportionally || imageScaling == FHScaleStretchedProportionally)
		return dx < dy ? dx : dy;
	else if(imageScaling == FHScaleWidthProportionally)
		return dx;
	else if(imageScaling == FHScaleHeightProportionally)
		return dy;
	
	return 1.0;
}



- (NSSize)_scaledSizeForSize:(NSSize)size usingScaling:(FHImageScaling)imageScaling bounds:(NSSize)bounds {
	CGFloat		factor;
	
	if(imageScaling == FHScaleNone)
		return size;
	
	if(imageScaling == FHScaleStretched)
		return bounds;
	
	factor = [self _scaleFactorUsingScaling:imageScaling bounds:bounds];
	
	if(factor < 1.0 || imageScaling == FHScaleStretchedProportionally) {
		size.width		= floorf(size.width  * factor);
		size.height		= floorf(size.height * factor);
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
		_imageSize			= [_image size];
		_imageOrientation	= [_image orientation];
	} else {
		_imageSize.width	= 0.0;
		_imageSize.height	= 0.0;
		_imageOrientation	= 0.0;
	}
	
	[self _adjustImageSize];
	[self _adjustFrameSize];
	
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
		_leftImageSize			= [_leftImage size];
		_leftImageOrientation	= [_leftImage orientation];
	} else {
		_leftImageSize.width	= 0.0;
		_leftImageSize.height	= 0.0;
		_leftImageOrientation	= 0.0;
	}
	
	[rightImage retain];
	[_rightImage release];
	
	_rightImage = rightImage;
	
	if(_rightImage) {
		_rightImageSize			= [_rightImage size];
		_rightImageOrientation	= [_rightImage orientation];
	} else {
		_rightImageSize.width	= 0.0;
		_rightImageSize.height	= 0.0;
		_rightImageOrientation	= 0.0;
	}
	
	[self _adjustImageSize];
	[self _adjustFrameSize];
	
	if(display)
		[self setNeedsDisplay:YES];
}



- (FHImage *)leftImage {
	return _leftImage;
}



- (FHImage *)rightImage {
	return _rightImage;
}



- (NSSize)imageSize {
	return _imageSize;
}



- (CGFloat)zoom {
	CGFloat		zoom;
	
	zoom = 100.0 * [self _scaleFactorUsingScaling:_adjustedImageScaling bounds:[self bounds].size];
	
	if(zoom > 100.0 && _adjustedImageScaling != FHScaleStretched && _adjustedImageScaling != FHScaleStretchedProportionally)
		zoom = 100.0;
	
	return zoom;
}



- (void)setImageScaling:(FHImageScaling)imageScaling {
	_imageScaling = imageScaling;
	
	[self _adjustFrameSize];
	
	[self setNeedsDisplay:YES];
}



- (FHImageScaling)imageScaling {
	return _imageScaling;
}



- (void)setImageRotation:(CGFloat)imageRotation {
	_imageRotation = imageRotation;

	[self _adjustImageSize];
	[self _adjustFrameSize];
	
	[self setNeedsDisplay:YES];
}



- (CGFloat)imageRotation {
	return _imageRotation;
}



- (void)setBackgroundColor:(NSColor *)color {
	[color retain];
	[_backgroundColor release];
	
	_backgroundColor = color;
	
	[self setNeedsDisplay:YES];
}



- (NSColor *)backgroundColor {
	return _backgroundColor;
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
	
	scroller = [_scrollView verticalScroller];
	
	if(_scrollingOffset < 50.0 || _scrollingOffset > 75.0) {
		[_scrollView scrollWheel:event];
		
		if(_scrollingOffset > 75.0) {
			_scrollingOffset = 0.0;
			_switchedImage = NO;
		}
	}
	
	if([scroller doubleValue] > 0.0 && [scroller doubleValue] < 1.0)
		_scrollingOffset = 0.0;
	else
		_scrollingOffset += fabs([event deltaY]);
	
	if(!_switchedImage && _scrollingOffset > 50.0) {
		if([scroller doubleValue] < 1.0) {
			if([_delegate previousImage:self])
				[self scrollPoint:NSZeroPoint];
		} else {
			[_delegate nextImage:self];
		}
		
		_switchedImage = YES;
	}
}



#pragma mark -

- (BOOL)isOpaque {
	return YES;
}



- (void)drawRect:(NSRect)frame {
	FHImage			*image;
	CGContextRef	context;
	NSRect			bounds, rect, leftRect, rightRect;
	NSSize			size, rotatedLeftSize, rotatedRightSize;
	
	bounds = [self bounds];
	
	[_backgroundColor set];
	NSRectFill(bounds);
	
	if(_image || _leftImage || _rightImage) {
		context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

		if(_leftImage && _rightImage) {
			size				= [self _scaledSizeForSize:_imageSize usingScaling:_adjustedImageScaling bounds:bounds.size];
			leftRect.size		= [self _scaledSizeForSize:_leftImageSize usingScaling:_adjustedImageScaling bounds:bounds.size];
			rightRect.size		= [self _scaledSizeForSize:_rightImageSize usingScaling:_adjustedImageScaling bounds:bounds.size];
			rotatedLeftSize		= [self _scaledSizeForSize:_rotatedLeftImageSize usingScaling:_adjustedImageScaling bounds:bounds.size];
			rotatedRightSize	= [self _scaledSizeForSize:_rotatedRightImageSize usingScaling:_adjustedImageScaling bounds:bounds.size];
			
			if(_imageRotation == 0.0 || _imageRotation == 180.0) {
				leftRect.origin.x = rightRect.origin.x = floorf((bounds.size.width  - size.width)  / 2.0);
				leftRect.origin.y = rightRect.origin.y = floorf((bounds.size.height - size.height) / 2.0);
			} else {
				leftRect.origin.x = rightRect.origin.x = floorf((bounds.size.width  - size.height) / 2.0);
				leftRect.origin.y = rightRect.origin.y = floorf((bounds.size.height - size.width)  / 2.0);
			}
			
			if(_imageRotation == 0.0) {
				if(_leftImageOrientation == 90.0) {
					leftRect.origin.y += rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 180.0) {
					leftRect.origin.x += rotatedLeftSize.width;
					leftRect.origin.y += rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 270.0) {
					leftRect.origin.x += rotatedLeftSize.width;
				}
			}
			else if(_imageRotation == 90.0) {
				if(_leftImageOrientation == 0.0) {
					leftRect.origin.y += rotatedRightSize.height + rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 90.0) {
					leftRect.origin.x += rotatedLeftSize.width;
					leftRect.origin.y += rotatedRightSize.height + rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 180.0) {
					leftRect.origin.x += rotatedLeftSize.width;
					leftRect.origin.y += rotatedRightSize.height;
				}
				else if(_leftImageOrientation == 270.0) {
					leftRect.origin.y += rotatedRightSize.height;
				}
			}
			else if(_imageRotation == 180.0) {
				if(_leftImageOrientation == 0.0) {
					leftRect.origin.x += rotatedRightSize.width + rotatedLeftSize.width;
					leftRect.origin.y += rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 90.0) {
					leftRect.origin.x += rotatedRightSize.width + rotatedLeftSize.width;
				}
				else if(_leftImageOrientation == 180.0) {
					leftRect.origin.x += rotatedRightSize.width;
				}
				else if(_leftImageOrientation == 270.0) {
					leftRect.origin.x += rotatedRightSize.width;
					leftRect.origin.y += rotatedLeftSize.height;
				}
			}
			else if(_imageRotation == 270.0) {
				if(_leftImageOrientation == 0.0) {
					leftRect.origin.x += rotatedLeftSize.width;
				}
				else if(_leftImageOrientation == 180.0) {
					leftRect.origin.y += rotatedLeftSize.height;
				}
				else if(_leftImageOrientation == 270.0) {
					leftRect.origin.x += rotatedLeftSize.width;
					leftRect.origin.y += rotatedLeftSize.height;
				}
			}
			
			if(_leftImageAngle != 0.0) {
				CGContextSaveGState(context);
				CGContextTranslateCTM(context, leftRect.origin.x, leftRect.origin.y);
				CGContextRotateCTM(context, -_leftImageAngle * M_PI / 180.0);
				CGContextTranslateCTM(context, -leftRect.origin.x, -leftRect.origin.y);
			}
			
			[_leftImage drawInRect:leftRect];

			if(_leftImageAngle != 0.0)
				CGContextRestoreGState(context);
			
			if(_imageRotation == 0.0) {
				if(_rightImageOrientation == 0.0) {
					rightRect.origin.x += rotatedLeftSize.width;
				}
				else if(_rightImageOrientation == 90.0) {
					rightRect.origin.x += rotatedLeftSize.width;
					rightRect.origin.y += rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 180.0) {
					rightRect.origin.x += rotatedLeftSize.width + rotatedRightSize.width;
					rightRect.origin.y += rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 270.0) {
					rightRect.origin.x += rotatedLeftSize.width + rotatedRightSize.width;
				}
			}
			else if(_imageRotation == 90.0) {
				if(_rightImageOrientation == 0.0) {
					rightRect.origin.y += rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 90.0) {
					rightRect.origin.x += rotatedRightSize.width;
					rightRect.origin.y += rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 180.0) {
					rightRect.origin.x += rotatedRightSize.width;
				}
			}
			else if(_imageRotation == 180.0) {
				if(_rightImageOrientation == 0.0) {
					rightRect.origin.x += rotatedRightSize.width;
					rightRect.origin.y += rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 90.0) {
					rightRect.origin.x += rotatedRightSize.width;
				}
				else if(_rightImageOrientation == 270.0) {
					rightRect.origin.y += rotatedRightSize.height;
				}
			}
			else if(_imageRotation == 270.0) {
				if(_rightImageOrientation == 0.0) {
					rightRect.origin.x += rotatedRightSize.width;
					rightRect.origin.y += rotatedLeftSize.height;
				}
				else if(_rightImageOrientation == 90.0) {
					rightRect.origin.y += rotatedLeftSize.height;
				}
				else if(_rightImageOrientation == 180.0) {
					rightRect.origin.y += rotatedLeftSize.height + rotatedRightSize.height;
				}
				else if(_rightImageOrientation == 270.0) {
					rightRect.origin.x += rotatedRightSize.width;
					rightRect.origin.y += rotatedLeftSize.height + rotatedRightSize.height;
				}
			}

			if(_rightImageAngle != 0.0) {
				CGContextSaveGState(context);
				CGContextTranslateCTM(context, rightRect.origin.x, rightRect.origin.y);
				CGContextRotateCTM(context, -_rightImageAngle * M_PI / 180.0);
				CGContextTranslateCTM(context, -rightRect.origin.x, -rightRect.origin.y);
			}
			
			[_rightImage drawInRect:rightRect];
			
			if(_rightImageAngle != 0.0)
				CGContextRestoreGState(context);
		} else {
			if(_image) {
				image = _image;
				size = _imageSize;
			} else {
				image = _leftImage ? _leftImage : _rightImage;
				size = _leftImage ? _leftImageSize : _rightImageSize;
			}
			
			rect.size = size = [self _scaledSizeForSize:size usingScaling:_adjustedImageScaling bounds:bounds.size];
			
			if(_imageAngle == 0.0 || _imageAngle == 180.0) {
				rect.origin.x = floorf((bounds.size.width  - size.width)  / 2.0);
				rect.origin.y = floorf((bounds.size.height - size.height) / 2.0);
			} else {
				rect.origin.x = floorf((bounds.size.width  - size.height) / 2.0);
				rect.origin.y = floorf((bounds.size.height - size.width)  / 2.0);
			}
			
			if(_imageAngle == 90.0) {
				rect.origin.y += rect.size.width;
			}
			else if(_imageAngle == 180.0) {
				rect.origin.x += rect.size.width;
				rect.origin.y += rect.size.height;
			}
			else if(_imageAngle == 270.0) {
				rect.origin.x += rect.size.height;
			}
			
			if(_imageAngle != 0.0) {
				CGContextSaveGState(context);
				CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
				CGContextRotateCTM(context, -_imageAngle * M_PI / 180.0);
				CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
			}
			
			[image drawInRect:rect];
			
			if(_imageAngle != 0.0)
				CGContextRestoreGState(context);
		}
	}
}

@end
