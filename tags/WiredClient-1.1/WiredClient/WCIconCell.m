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

#import "NSTextFieldCellAdditions.h"
#import "WCIconCell.h"

@implementation WCIconCell

- (id)initWithImageWidth:(unsigned int)width whitespace:(BOOL)whitespace {
	self = [super init];
	
	_nameTextFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
	[_nameTextFieldCell setFont:[NSFont systemFontOfSize:12.0]];
	
	_imageCell = [[NSImageCell alloc] initImageCell:NULL];
	_imageWidth = width;
	_whitespace = whitespace;
	
	return self;
}



- (id)copyWithZone:(NSZone *)zone {
	WCIconCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_nameTextFieldCell = [_nameTextFieldCell retain];
	cell->_imageCell = [_imageCell retain];
	cell->_attributes = [_attributes retain];
	
	return cell;
}



- (void)dealloc {
	[_nameTextFieldCell release];
	[_imageCell release];
	
	[_attributes release];
	
	[super dealloc];
}



#pragma mark -

- (void)setAttributes:(NSDictionary *)attributes {
	[attributes retain];
	[_attributes release];
	
	_attributes = attributes;
}



- (void)setObjectValue:(id)value {
	_string = [value objectAtIndex:0];
	
	if([value count] > 1)
		_image = [value objectAtIndex:1];
	else
		_image = NULL;
}



- (id)objectValue {
	return [NSArray arrayWithObjects:_string, _image, NULL];
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	// --- get highlighting
	[_nameTextFieldCell setHighlighted:[self isHighlighted]];
	
	// --- draw image
	if(_image) {
		[_imageCell setImage:_image];
		[_imageCell drawWithFrame:NSMakeRect(frame.origin.x + 2,
											 frame.origin.y,
											 _imageWidth,
											 frame.size.height)
						   inView:view];
	}
	
	// --- draw text
	if(_image || _whitespace) {
		[_nameTextFieldCell setConstrainedStringValue:_string withAttributes:_attributes];
		
		[_nameTextFieldCell drawWithFrame:NSMakeRect(frame.origin.x + _imageWidth + 4,
													 frame.origin.y,
													 frame.size.width - _imageWidth - 4,
													 frame.size.height)
								   inView:view];
	} else {
		[_nameTextFieldCell setConstrainedStringValue:_string];
		
		[_nameTextFieldCell drawWithFrame:NSMakeRect(frame.origin.x + 2,
													 frame.origin.y,
													 frame.size.width - 4,
													 frame.size.height)
								   inView:view];
	}
}

@end
