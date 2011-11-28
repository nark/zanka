/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSTextFieldAdditions.h"

@implementation NSTextField(WCResizable)

- (void)setFrameForString:(NSString *)string withControl:(id)control offset:(int *)offset {
	NSTextStorage		*textStorage;
	NSTextContainer		*textContainer;
	NSLayoutManager		*layoutManager;
	NSRect				rect;
	int					height, factor;
	
	// --- get height of string drawn in box
	rect			= [self frame];
	textStorage		= [[NSTextStorage alloc] initWithString:string];
	textContainer	= [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(rect.size.width, 255)];
	layoutManager	= [[NSLayoutManager alloc] init];

	[textStorage addAttribute:NSFontAttributeName
				 value:[self font]
				 range:NSMakeRange(0, [textStorage length])];
	[textContainer setLineFragmentPadding:0.0];
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[layoutManager glyphRangeForTextContainer:textContainer];

	// --- get factor of difference
	height = [layoutManager usedRectForTextContainer:textContainer].size.height;
	factor = ceil(height / rect.size.height);
	
	// --- offset frame
	rect.origin.y = *offset + 2 + rect.size.height;
	*offset = rect.origin.y + ((factor - 1) * rect.size.height);
	rect.size.height = height + factor;
	
	// --- set new size
	[self setFrame:rect];
	
	// --- set y of related control
	rect = [control frame];
	rect.origin.y = *offset;
	[control setFrame:rect];
}

@end