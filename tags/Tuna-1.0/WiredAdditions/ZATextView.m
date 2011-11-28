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

#import <ZankaAdditions/NSString-ZAAdditions.h>
#import <ZankaAdditions/ZATextFilter.h>
#import <ZankaAdditions/ZATextView.h>

@interface ZATextView(Private)

- (void)_initTextView;

- (NSAttributedString *)_filteredString:(NSString *)string withFilter:(ZATextFilter *)filter;

@end


@implementation ZATextView

- (id)initWithFrame:(NSRect)frame {
	if((self = [super initWithFrame:frame]))	
		[self _initTextView];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	if((self = [super initWithCoder:coder]))	
		[self _initTextView];
	
	return self;
}



- (void)_initTextView {
	[self setEditable:NO];
}



- (void)dealloc {
	[_textColor release];
	
	[super dealloc];
}



#pragma mark -

- (void)insertText:(NSString *)string {
	if([self forwardsTextToNextKeyView]) {
		[[self window] selectNextKeyView:self];
		
		[NSApp sendAction:@selector(insertText:) to:NULL from:string];
	}
	else if([self forwardsTextToDelegate])
		[[self delegate] insertText:string];
	else
		[super insertText:string];
}



- (void)setTextColor:(NSColor *)textColor {
	[textColor retain];
	[_textColor release];
	
	_textColor = textColor;
}



- (NSColor *)textColor {
	return _textColor;
}



#pragma mark -

- (void)setForwardsTextToNextKeyView:(BOOL)value {
	_forwardsTextToNextKeyView = value;
}



- (BOOL)forwardsTextToNextKeyView {
	return _forwardsTextToNextKeyView;
}



- (void)setForwardsTextToDelegate:(BOOL)value {
	_forwardsTextToDelegate = value;
}



- (BOOL)forwardsTextToDelegate {
	return _forwardsTextToDelegate;
}



#pragma mark -

- (NSAttributedString *)_filteredString:(NSString *)string withFilter:(ZATextFilter *)filter {
	NSMutableAttributedString   *attributedString;
	NSDictionary				*attributes;
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[self textColor],		NSForegroundColorAttributeName,
		[self font],			NSFontAttributeName,
		NULL];
	attributedString = [NSMutableAttributedString attributedStringWithString:string attributes:attributes];
	
	[filter filter:attributedString];
	
	return attributedString;
}



- (void)setString:(NSString *)string withFilter:(ZATextFilter *)filter {
	[[self textStorage] setAttributedString:[self _filteredString:string withFilter:filter]];
}




- (void)appendString:(NSString *)string withFilter:(ZATextFilter *)filter {
	[[self textStorage] appendAttributedString:[self _filteredString:string withFilter:filter]];
}

@end
