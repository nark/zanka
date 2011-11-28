/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCUserCell.h"

@implementation WCUserCell

- (id)init {
	NSMutableParagraphStyle		*style;
	
	self = [super init];

	_nickCell = [[NSCell alloc] init];
	_statusCell = [[NSCell alloc] init];
	
	style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];

	_nickAttributes = [[NSMutableDictionary alloc] init];
	[_nickAttributes setObject:style forKey:NSParagraphStyleAttributeName];

	_statusAttributes = [[NSMutableDictionary alloc] init];
	[_statusAttributes setObject:style forKey:NSParagraphStyleAttributeName];
	[_statusAttributes setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
	
	_filter = [[WITextFilter alloc] initWithSelectors:@selector(filterWiredSmallSmilies:), 0];

	return self;
}



- (void)dealloc {
	[_nickCell release];
	[_statusCell release];

	[_nickAttributes release];
	[_statusAttributes release];
	
	[_filter release];

	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WCUserCell		*cell;

	cell					= [super copyWithZone:zone];
	cell->_nickCell			= [_nickCell retain];
	cell->_statusCell		= [_statusCell retain];
	cell->_nickAttributes	= [_nickAttributes retain];
	cell->_statusAttributes	= [_statusAttributes retain];
	cell->_filter			= [_filter retain];
	
	return cell;
}



#pragma mark -

- (void)setIgnored:(BOOL)value {
	[_nickAttributes setObject:[NSNumber numberWithInt:value] forKey:NSStrikethroughStyleAttributeName];
}



- (BOOL)ignored {
	return [_nickAttributes boolForKey:NSStrikethroughStyleAttributeName];
}



- (void)setTextColor:(NSColor *)color {
	[_nickAttributes setObject:color forKey:NSForegroundColorAttributeName];
}



- (NSColor *)textColor {
	return [_nickAttributes objectForKey:NSForegroundColorAttributeName];
}



#pragma mark -

- (void)setFont:(NSFont *)font {
	NSFont		*statusFont;
	
	if(font) {
		statusFont = [[NSFontManager sharedFontManager] convertFont:font toSize:[font pointSize] - 2.0];
	
		[_nickAttributes setObject:font forKey:NSFontAttributeName];
		[_statusAttributes setObject:statusFont forKey:NSFontAttributeName];
	}
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSAttributedString		*string;
	NSString				*nick, *status;
	NSRect					rect;
	
	nick	= [(NSDictionary *) [self objectValue] objectForKey:WCUserCellNickKey];
	status	= [(NSDictionary *) [self objectValue] objectForKey:WCUserCellStatusKey];

	if([self controlSize] == NSRegularControlSize) {
		if([status length] > 0)
			rect = NSMakeRect(frame.origin.x, frame.origin.y + 1.0, frame.size.width, 17.0);
		else
			rect = NSMakeRect(frame.origin.x, frame.origin.y + 8.0, frame.size.width, 17.0);
	} else {
		rect = NSMakeRect(frame.origin.x, frame.origin.y - 1.0, frame.size.width, 17.0);
	}
	
	string = [NSAttributedString attributedStringWithString:nick attributes:_nickAttributes];

	[_nickCell setAttributedStringValue:[string attributedStringByApplyingFilter:_filter]];
	[_nickCell setHighlighted:[self isHighlighted]];
	[_nickCell drawWithFrame:rect inView:view];
	
	if([self controlSize] == NSRegularControlSize && [status length] > 0) {
		rect	= NSMakeRect(frame.origin.x, frame.origin.y + 19.0, frame.size.width, 14.0);
		string	= [NSAttributedString attributedStringWithString:status attributes:_statusAttributes];
		
		[_statusCell setAttributedStringValue:[string attributedStringByApplyingFilter:_filter]];
		[_statusCell setHighlighted:[self isHighlighted]];
		[_statusCell drawWithFrame:rect inView:view];
	}
}

@end
