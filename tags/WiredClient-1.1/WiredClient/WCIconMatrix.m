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

#import "WCIcons.h"
#import "WCIconMatrix.h"

@implementation WCIconMatrix

- (id)initWithFrame:(NSRect)frame {
	NSActionCell	*cell;
	NSImage			*image;
	
	// --- create cell prototype
	image	= [[NSImage alloc] initWithSize:NSMakeSize(32, 32)];
	cell	= [[NSActionCell alloc] initImageCell:image];

	// --- create view with rows
	[self initWithFrame:frame
				   mode:NSListModeMatrix
			  prototype:cell
		   numberOfRows:5
		numberOfColumns:10];
	
	// --- set some flags
	[self setIntercellSpacing:NSZeroSize];
	[self setSelectionByRect:NO];
	[self setAllowsEmptySelection:NO];
	[self setDrawsBackground:YES];
	[self setBackgroundColor:[NSColor whiteColor]];
	
	[cell release];
	[image release];

	return self;
}



#pragma mark -

- (void)updateIcons {
	NSDictionary	*icons;
	NSArray			*keys;
	NSString		*key;
	NSRect			frame;
	int				rows, i, row, column;
	
	// --- get icons
	icons = [WCIcons icons];
	
	// --- sort keys
	keys = [[icons allKeys] sortedArrayUsingSelector:@selector(compare:)];
	
	// --- figure out number of rows
	rows = ([icons count] / 10) + 1;
	
	if(rows < 5)
		rows = 5;
	
	[self renewRows:rows columns:10];

	// --- loop over all images and spread them across the matrix
	for(i = 0, column = 0; i < (int) [icons count]; i++, column++) {
		if(column == 10)
			column = 0;
	
		row = i / 10;
		key = [keys objectAtIndex:i];
	
		// --- set image and tag
		if((key = [keys objectAtIndex:i])) {
			[[self cellAtRow:row column:column] setImage:[icons objectForKey:key]];
			[[self cellAtRow:row column:column] setTag:[key intValue]];
		}
	}
	
	// --- change frame
	frame = [self frame];
	frame.size.height = rows * 32;
	[self setFrame:frame];
	
	// --- re-display
	[self setNeedsDisplay:YES];
}

@end
