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
	
	[super dealloc];
}



#pragma mark -

- (void)setObjectValue:(id)value {
	_transfer = value;
}



- (id)objectValue {
	return _transfer;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSSize		size;

	// --- draw file name
	[_nameTextFieldCell setHighlighted:[self isHighlighted]];
	[_nameTextFieldCell setStringValue:[_transfer name]];
	size = [[_nameTextFieldCell attributedStringValue] size];
	[_nameTextFieldCell
		drawWithFrame:NSMakeRect(frame.origin.x - 2, frame.origin.y, size.width + 10, size.height)
		inView:view];

	// ---- draw lock image
	if([_transfer state] == WCTransferStateRunning) {
		if([_transfer secure])
			[_imageCell setImage:[NSImage imageNamed:@"Locked"]];
		else
			[_imageCell setImage:[NSImage imageNamed:@"Unlocked"]];
		
		[_imageCell drawWithFrame:NSMakeRect(frame.origin.x + size.width + 5, frame.origin.y + 2, 13, 13)
						   inView:view];
	}

	// --- add the progress indicator once
	if(![_transfer progressInited]) {
		[view addSubview:[_transfer progressIndicator]];
		[_transfer setProgressInited:YES];
	}
	
	// --- update progress indicator
	[[_transfer progressIndicator] setFrame:
		NSMakeRect(frame.origin.x - 1, frame.origin.y + 18, frame.size.width - 5, 10)];

	// --- draw status
	[_statusTextFieldCell setHighlighted:[self isHighlighted]];
	[_statusTextFieldCell setStringValue:[_transfer status]];
	[_statusTextFieldCell drawWithFrame:
		NSMakeRect(frame.origin.x - 2, frame.origin.y + 30, frame.size.width, frame.size.height - 30)
		inView:view];
}

@end
