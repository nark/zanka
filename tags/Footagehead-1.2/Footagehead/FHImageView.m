/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "FHController.h"
#import "FHImage.h"
#import "FHImageView.h"

@interface FHImageView(Private)

- (void)_initImageView;

- (void)_adjustScaling;

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
	static BOOL		recursive;
	
	if(!recursive) {
		recursive = YES;
		[self _adjustScaling];
		recursive = NO;
	}
		
	if([_scrollView hasHorizontalScroller] || [_scrollView hasVerticalScroller])
		[_scrollView setDocumentCursor:[NSCursor openHandCursor]];
	else
		[_scrollView setDocumentCursor:[NSCursor arrowCursor]];
}



#pragma mark -

- (void)_adjustScaling {
	NSSize		contentSize, imageSize, frameSize;
	float		size;
	
	if(_scrollView) {
		contentSize = [_scrollView contentSize];
		
		if(_image && _imageScaling == FHScaleNone) {
			imageSize = _image ? [_image size] : NSZeroSize;
			
			if(ABS(_imageRotation) == 90.0 || ABS(_imageRotation) == 270.0) {
				size = imageSize.width;
				imageSize.width = imageSize.height;
				imageSize.height = size;
			}
			
			frameSize = NSMakeSize(MAX(contentSize.width, imageSize.width), MAX(contentSize.height, imageSize.height));
			
			[_scrollView setHasHorizontalScroller:(imageSize.width > contentSize.width)];
			[_scrollView setHasVerticalScroller:(imageSize.height > contentSize.height)];
			
			[self setFrameSize:frameSize];
			[self scrollPoint:NSMakePoint(0.0, frameSize.height)];
		} else {
			[_scrollView setHasHorizontalScroller:NO];
			[_scrollView setHasVerticalScroller:NO];

			[self setFrameSize:contentSize];
		}
	}
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
	[_backgroundColor release];
	
	[_label release];
	[_labelAttributes release];

	[super dealloc];
}



#pragma mark -

- (void)setImage:(FHImage *)image {
	BOOL	display;

	display = (image != NULL || _image != NULL);
	
	[image retain];
	[_image release];
	
	_image = image;

	[self _adjustScaling];
	
	if(display)
		[self setNeedsDisplay:YES];
}



- (FHImage *)image {
	return _image;
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



- (void)mouseUp:(NSEvent *)event {
	if(!_dragging)
		[[FHController controller] zoom:self];
}



- (void)rightMouseUp:(NSEvent *)event {
	if([event shiftKeyModifier])
		[[FHController controller] rotateLeft:self];
	else
		[[FHController controller] rotateRight:self];
}



- (void)mouseDragged:(NSEvent *)event {
	NSPoint		point, originalPoint;
	NSRect		originalRect;
	float		x, y;
	
	_dragging = YES;

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



- (void)scrollWheel:(NSEvent *)event {
	NSScroller		*scroller;
	BOOL			up, handled = NO;
	
	scroller = [_scrollView verticalScroller];
	up = ([event deltaY] > 0.0f);
	
	if(![_scrollView hasVerticalScroller] || (up && [scroller floatValue] == 0.0f) || (!up && [scroller floatValue] == 1.0f)) {
		if(!up)
			[[FHController controller] nextImage:self];
		else
			[[FHController controller] previousImage:self];
		
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
	NSRect		bounds, rect;
	float		dx, dy, d;
	
	bounds = [self bounds];
	
	[_backgroundColor set];
	NSRectFill(bounds);
	
	if(_image) {
		rect.size = [_image size];

		switch (_imageScaling) {
			case FHScaleProportionally:
			case FHScaleStretched:
				if(ABS(_imageRotation) == 90.0 || ABS(_imageRotation) == 270.0) {
					dx = bounds.size.width  / rect.size.height;
					dy = bounds.size.height / rect.size.width;
				} else {
					dx = bounds.size.width  / rect.size.width;
					dy = bounds.size.height / rect.size.height;
				}
				
				d = dx < dy ? dx : dy;
				
				if(d < 1.0 || _imageScaling == FHScaleStretched) {
					rect.size.width		= floorf(rect.size.width  * d);
					rect.size.height	= floorf(rect.size.height * d);
				}
				break;
			
			case FHScaleToFit:
				rect.size = bounds.size;
				break;
			
			case FHScaleNone:
				break;
		}
		
		rect.origin.x = floorf((bounds.size.width  - rect.size.width)  / 2.0);
		rect.origin.y = floorf((bounds.size.height - rect.size.height) / 2.0);
		
		[_image drawInRect:rect atAngle:_imageRotation];
		
		if(_label && [_label length] > 0)
			[_label drawAtPoint:NSMakePoint(10.0, 10.0) withAttributes:_labelAttributes];
	}
}

@end
