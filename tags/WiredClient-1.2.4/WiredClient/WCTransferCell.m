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

#import "NSNumberAdditions.h"
#import "NSTextFieldCellAdditions.h"
#import "WCFile.h"
#import "WCSettings.h"
#import "WCTransfer.h"
#import "WCTransferCell.h"

@implementation WCTransferCell

- (id)init {
	self = [super init];
	
	_nameTextFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
	[_nameTextFieldCell setFont:[NSFont systemFontOfSize:12.0]];

	_statusTextFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
	[_statusTextFieldCell setFont:[NSFont systemFontOfSize:10.0]];
	
	_imageCell = [[NSImageCell alloc] initImageCell:NULL];
	
	return self;
}



- (id)copyWithZone:(NSZone *)zone {
	WCTransferCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_nameTextFieldCell = [_nameTextFieldCell retain];
	cell->_statusTextFieldCell = [_statusTextFieldCell retain];
	cell->_imageCell = [_imageCell retain];
	
	return cell;
}



- (void)dealloc {
	[_nameTextFieldCell release];
	[_statusTextFieldCell release];
	[_imageCell release];
	
	[super dealloc];
}



#pragma mark -

- (void)setObjectValue:(id)value {
	if([value count] >= 1)
		_transfer = [value objectAtIndex:0];

	if([value count] >= 2)
		_image = [value objectAtIndex:1];
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSSize		size;
	int			offset = 0;

	// --- draw file name
	[_nameTextFieldCell setStringValue:[_transfer name]];
	size = [[_nameTextFieldCell attributedStringValue] size];
	[_nameTextFieldCell setHighlighted:[self isHighlighted]];
	[_nameTextFieldCell
		drawWithFrame:NSMakeRect(frame.origin.x - 2, frame.origin.y + offset,
								 size.width + 10, size.height)
		inView:view];
	offset += 19;
	
	// ---- draw lock image
	[_imageCell setImage:_image];
	[_imageCell
		drawWithFrame:NSMakeRect(frame.origin.x + size.width + 5, frame.origin.y + 2,
								 13, 13)
		inView:view];

	// --- add progress indicator to control view once
	if(![[_transfer progressIndicator] superview])
		[view addSubview:[_transfer progressIndicator]];
	
	// --- draw progress indicator
	[[_transfer progressIndicator] setFrame:
		NSMakeRect(frame.origin.x - 1, frame.origin.y + offset,
				   frame.size.width - 5, 10)];
	offset += 13;
	
	// --- draw status
	[_statusTextFieldCell setStringValue:[_transfer status]];
	[_statusTextFieldCell setHighlighted:[self isHighlighted]];
	[_statusTextFieldCell drawWithFrame:
		NSMakeRect(frame.origin.x - 2, frame.origin.y + offset,
				   frame.size.width, 14)
		inView:view];
}

@end
