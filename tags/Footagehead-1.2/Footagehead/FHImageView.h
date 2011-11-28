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

enum _FHImageScaling {
	FHScaleProportionally		= 0,
	FHScaleToFit,
	FHScaleStretched,
	FHScaleNone,
};
typedef enum _FHImageScaling	FHImageScaling;


@class FHImage;

@interface FHImageView : NSView {
	IBOutlet NSScrollView		*_scrollView;
	
	FHImage						*_image;
	FHImageScaling				_imageScaling;
	float						_imageRotation;
	
	NSColor						*_backgroundColor;
	
	NSString					*_label;
	NSMutableDictionary			*_labelAttributes;
	
	BOOL						_dragging;
}


- (void)setImage:(FHImage *)image;
- (FHImage *)image;
- (void)setImageScaling:(FHImageScaling)newScaling;
- (FHImageScaling)imageScaling;
- (void)setImageRotation:(float)rotation;
- (float)imageRotation;
- (void)setBackgroundColor:(NSColor *)color;
- (NSColor *)backgroundColor;
- (void)setLabel:(NSString *)label;
- (NSString *)label;

@end
