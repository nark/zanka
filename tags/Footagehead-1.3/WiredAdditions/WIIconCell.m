/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import <WiredAdditions/NSString-WIAdditions.h>
#import <WiredAdditions/WIIconCell.h>

@implementation WIIconCell

- (id)init {
	NSMutableParagraphStyle		*style;
	
	self = [super init];
	
	_titleCell = [[NSCell alloc] init];
	_iconCell = [[NSCell alloc] init];
	
	_titleAttributes = [[NSMutableDictionary alloc] init];
	style = [[NSMutableParagraphStyle alloc] init];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[_titleAttributes setObject:style forKey:NSParagraphStyleAttributeName];
	[style release];
	
	return self;
}



- (void)dealloc {
	[_titleCell release];
	[_iconCell release];
	
	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WIIconCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_titleCell = [_titleCell retain];
	cell->_iconCell = [_iconCell retain];
	cell->_titleAttributes = [_titleAttributes retain];
	
	return cell;
}



#pragma mark -

- (void)setDrawsWhitespace:(BOOL)value {
	_drawsWhitespace = value;
}



- (BOOL)drawsWhitespace {
	return _drawsWhitespace;
}



- (void)setImageWidth:(float)imageWidth {
	_imageWidth = imageWidth;
}



- (float)imageWidth {
	return _imageWidth;
}



- (void)setTextColor:(NSColor *)color {
	[_titleAttributes setObject:color forKey:NSForegroundColorAttributeName];
}



- (NSColor *)textColor {
	return [_titleAttributes objectForKey:NSForegroundColorAttributeName];
}



- (void)setFont:(NSFont *)font {
	[_titleCell setFont:font];
}



- (NSFont *)font {
	return [_titleCell font];
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSMutableAttributedString	*string;
	NSAttributedString			*attributedTitle;
	NSString					*title;
	NSImage						*icon;
	NSRect						rect;
	
	title			= [(NSDictionary *) [self objectValue] objectForKey:WIIconCellTitleKey];
	attributedTitle	= [(NSDictionary *) [self objectValue] objectForKey:WIIconCellAttributedTitleKey];
	icon			= [(NSDictionary *) [self objectValue] objectForKey:WIIconCellIconKey];
	
	rect = NSMakeRect(frame.origin.x + 2.0, frame.origin.y, [icon size].width, frame.size.height);
	[_iconCell setImage:icon];
	[_iconCell setHighlighted:[self isHighlighted]];
	[_iconCell drawWithFrame:rect inView:view];

	rect = NSMakeRect(frame.origin.x + 4.0, frame.origin.y, frame.size.width - 4.0, 17.0);

	if(icon) {
		if([self imageWidth] > 0) {
			rect.origin.x += [self imageWidth];
			rect.size.width -= [self imageWidth];
		} else {
			rect.origin.x += [icon size].width;
			rect.size.width -= [icon size].width;
		}
	}
	else if([self drawsWhitespace]) {
		rect.origin.x += [self imageWidth];
		rect.size.width -= [self imageWidth];
	}

	if(attributedTitle) {
		string = [attributedTitle mutableCopy];
		[string addAttributes:_titleAttributes range:NSMakeRange(0, [string length])];
	} else {
		string = [NSMutableAttributedString attributedStringWithString:title attributes:_titleAttributes];
	}

	[_titleCell setAttributedStringValue:string];
	[_titleCell setHighlighted:[self isHighlighted]];
	[_titleCell drawWithFrame:rect inView:view];
}

@end
