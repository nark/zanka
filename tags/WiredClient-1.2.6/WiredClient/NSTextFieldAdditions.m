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

#import "NSFontAdditions.h"
#import "NSTextFieldAdditions.h"

@implementation NSTextField(WCTextFieldResizing)

- (void)setFrameWithControl:(id)control atOffset:(int *)offset {
	NSRect		rect, controlRect;
	NSSize		size;
	int			width = 1, height = 1, factor = 1;
	
	// --- default offset
	if(*offset == 0)
		*offset = 18;
	
	// --- get string bounding box
	rect = [self frame];
	size = [[self font] sizeOfString:[self stringValue]];
	
	// --- has to exceed current height by at least 50% if we are to make a new line
	if(size.height >= 1.5 * rect.size.height)
		height = (int) (size.height / rect.size.height) + 1;
		
	width = (int) (size.width / rect.size.width) + 1;
	factor = width + (height - 1);
	
	// --- set frame of self
	rect.origin.y = *offset + 2;
	rect.size.height = 14 * factor;
	*offset = rect.origin.y + rect.size.height;
	[self setFrame:rect];
	
	// --- set y of related control
	controlRect = [control frame];

	if(factor > 1)
		controlRect.origin.y = rect.origin.y + ((factor - 1) * controlRect.size.height);
	else
		controlRect.origin.y = rect.origin.y;

	[control setFrame:controlRect];
}

@end
