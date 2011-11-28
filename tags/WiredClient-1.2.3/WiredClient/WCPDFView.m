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

#import "WCDragScrollView.h"
#import "WCPDFView.h"

@implementation WCPDFView

- (void)setPDF:(NSPDFImageRep *)pdf {
    NSImage			*image;

	// --- create image from PDF
    image = [[NSImage alloc] init];
    [image addRepresentation:pdf];
	
	// --- set image
	[self setImage:image];
	
	[image release];
}



- (void)drawRect:(NSRect)rect {
    NSPDFImageRep	*pdf;
    int				count, page;
    NSRect			frame;

	// --- flood with white
	[[NSColor whiteColor] set];
	NSRectFill(rect);
	
	// --- get the pdf
	pdf		= [[[self image] representations] objectAtIndex:0];
	count	= [pdf pageCount];

	for(page = 0; page < count; page++) {
		// --- get frame for page
		frame = [self rectForPage:page + 1];

		// --- skip offscreen
		if(!NSIntersectsRect(rect, frame))
			continue;

		// --- draw page
		[pdf setCurrentPage:page];
		[pdf drawInRect:frame];
    }
}



- (BOOL)knowsPageRange:(NSRangePointer)range {
	range->location = 1;
	range->length = [[[[self image] representations] objectAtIndex:0] pageCount];

	return YES;
}



- (NSRect)rectForPage:(int)page {
    NSPDFImageRep	*pdf;
    int				count;
    NSRect			frame;

	// --- get PDF
	pdf		= [[[self image] representations] objectAtIndex:0];
	count	= [pdf pageCount];
    frame	= [pdf bounds];

	// --- start at first page
	if(![self isFlipped])
		frame = NSOffsetRect(frame, 0.0, (count - 1) * frame.size.height);

	// --- move to the specified number
	if([self isFlipped])
		frame = NSOffsetRect(frame, 0.0, (page - 1) * frame.size.height);
	else
		frame = NSOffsetRect(frame, 0.0, -(page - 1) * frame.size.height);

	return frame;
}



- (void)mouseDown:(NSEvent *)event {
	[(WCDragScrollView *) [self enclosingScrollView] dragDocumentWithEvent:event];
}

@end
