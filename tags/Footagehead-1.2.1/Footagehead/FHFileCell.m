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

#import "FHFileCell.h"
#import "FHImage.h"

@implementation FHFileCell

- (id)init {
	NSMutableParagraphStyle		*style;
	
	self = [super init];
	
	_nameCell = [[NSCell alloc] init];

	style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	
	_attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
		[NSFont systemFontOfSize:9.0],		NSFontAttributeName,
		style,								NSParagraphStyleAttributeName,
		NULL];
	
	return self;
}



- (void)dealloc {
	[_nameCell release];
	
	[_attributes release];
	
	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	FHFileCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_nameCell = [_nameCell retain];
	cell->_attributes = [_attributes retain];
	
	return cell;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSAttributedString	*string;
	NSString			*name;
	FHImage				*icon;
	NSRect				rect, imageRect;
	NSSize				size;
	float				dx, dy, d;
	
	name = [(NSDictionary *) [self objectValue] objectForKey:FHFileCellNameKey];
	icon = [(NSDictionary *) [self objectValue] objectForKey:FHFileCellIconKey];
	
	rect = NSMakeRect(frame.origin.x, frame.origin.y + frame.size.height - 26.0, frame.size.width, 24.0);
	string = [[NSAttributedString alloc] initWithString:name attributes:_attributes];
	[_nameCell setAttributedStringValue:string];
	[_nameCell setHighlighted:[self isHighlighted]];
	[_nameCell drawWithFrame:rect inView:view];
	[string release];
	
	rect				= NSMakeRect(frame.origin.x, frame.origin.y + 2.0, frame.size.width, frame.size.height - 28.0);
	size				= [icon size];
	imageRect.origin	= rect.origin;
	imageRect.size		= size;
	dx					= rect.size.width  / imageRect.size.width;
	dy					= rect.size.height / imageRect.size.height;
	d					= dx < dy ? dx : dy;
				
	if(d < 1.0) {
		imageRect.size.width	= floorf(imageRect.size.width  * d);
		imageRect.size.height	= floorf(imageRect.size.height * d);
	}

	imageRect.origin.x += floorf((rect.size.width  - imageRect.size.width) / 2.0);
	imageRect.origin.y += floorf((rect.size.height - imageRect.size.height) / 2.0);
	
	[icon setFlipped:YES];
	[icon drawInRect:imageRect atAngle:0.0];
}

@end
