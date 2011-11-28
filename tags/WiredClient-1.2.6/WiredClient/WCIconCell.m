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

- (id)initWithImageWidth:(unsigned int)imageWidth whitespace:(BOOL)whitespace {
	self = [super init];
	
	_nameTextFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
	[_nameTextFieldCell setFont:[NSFont systemFontOfSize:12.0]];
	
	_statusTextFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
	[_statusTextFieldCell setFont:[NSFont systemFontOfSize:10.0]];
	[_statusTextFieldCell setTextColor:[NSColor grayColor]];

	_imageCell = [[NSImageCell alloc] initImageCell:NULL];
	[_imageCell setImageAlignment:NSImageAlignTop];
	
	_imageWidth = imageWidth;
	_whitespace = whitespace;
	
	return self;
}



- (id)copyWithZone:(NSZone *)zone {
	WCIconCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_nameTextFieldCell = [_nameTextFieldCell retain];
	cell->_statusTextFieldCell = [_statusTextFieldCell retain];
	cell->_imageCell = [_imageCell retain];
	cell->_attributes = [_attributes retain];
	
	return cell;
}



- (void)dealloc {
	[_nameTextFieldCell release];
	[_statusTextFieldCell release];
	[_imageCell release];
	[_attributes release];
	
	[super dealloc];
}



#pragma mark -

- (void)setObjectValue:(id)value {
	[self setName:[value objectForKey:WCIconCellNameKey]];
	[self setStatus:[value objectForKey:WCIconCellStatusKey]];
	[self setImage:[value objectForKey:WCIconCellImageKey]];
}



- (void)setAttributes:(NSDictionary *)attributes {
	[attributes retain];
	[_attributes release];
	
	_attributes = attributes;
}



- (void)setName:(NSString *)value {
	_name = value;
}



- (void)setStatus:(NSString *)value {
	_status = value;
}



- (void)setImage:(NSImage *)value {
	_image = value;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSRect		nameFrame, statusFrame;

	// --- draw image
	if(_image) {
		[_imageCell setImage:_image];
		[_imageCell drawWithFrame:NSMakeRect(frame.origin.x + 2,
											 frame.origin.y,
											 _imageWidth,
											 frame.size.height)
						   inView:view];
	}
	
	// --- set name
	[_nameTextFieldCell setConstrainedStringValue:_name withAttributes:_attributes];
	[_nameTextFieldCell setHighlighted:[self isHighlighted]];
	
	// --- set status
	[_statusTextFieldCell setConstrainedStringValue:_status withAttributes:NULL];
	[_statusTextFieldCell setHighlighted:[self isHighlighted]];
	
	// --- set sizes
	if([self controlSize] == NSRegularControlSize) {
		if(_image || _whitespace) {
			nameFrame = NSMakeRect(frame.origin.x + _imageWidth + 4, frame.origin.y + 1,
								   frame.size.width - _imageWidth - 4, 17);
			statusFrame = NSMakeRect(frame.origin.x + _imageWidth + 4, frame.origin.y + 18,
									 frame.size.width - _imageWidth - 4, 12);
		} else {
			nameFrame = NSMakeRect(frame.origin.x + 2, frame.origin.y + 1,
								   frame.size.width - 4, 17);
			statusFrame = NSMakeRect(frame.origin.x + _imageWidth + 4, frame.origin.y + 18,
									 frame.size.width - _imageWidth - 4, 12);
		}
	}
	else if([self controlSize] == NSSmallControlSize) {
		if(_image || _whitespace) {
			nameFrame = NSMakeRect(frame.origin.x + _imageWidth + 4, frame.origin.y,
								   frame.size.width - _imageWidth - 4, 17);
		} else {
			nameFrame = NSMakeRect(frame.origin.x + 2, frame.origin.y,
								   frame.size.width - 4, 17);
		}
	}
	
	// --- draw name
	[_nameTextFieldCell drawWithFrame:nameFrame inView:view];
	
	// --- draw status
	if([self controlSize] == NSRegularControlSize)
		[_statusTextFieldCell drawWithFrame:statusFrame inView:view];
}

@end
