/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPDrillTextField.h"

@interface SPDrillTextField(Private)

- (void)_initDrillTextField;

- (void)_animate;

@end


@implementation SPDrillTextField(Private)

- (void)_initDrillTextField {
	NSMutableParagraphStyle		*style;
	
	style = [[NSMutableParagraphStyle alloc] init];
	[style setLineBreakMode:NSLineBreakByTruncatingTail];

	_attributes = [[NSMutableDictionary alloc] init];
	
	[_attributes setObject:[NSFont systemFontOfSize:72.0] forKey:NSFontAttributeName];
	[_attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[_attributes setObject:style forKey:NSParagraphStyleAttributeName];
	
	[style release];
}



#pragma mark -

- (void)_animate {
	[self display];
	
	if(_stringWidth - _animationOffset <= [self frame].size.width)
		_animationOffset = 0.0;
	else
		_animationOffset += 6.0;
	
	[self performSelector:@selector(_animate) afterDelay:(_animationOffset > 6.0) ? (1.0 / 30.0) : 1.0];
}

@end



@implementation SPDrillTextField

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initDrillTextField];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initDrillTextField];
	
	return self;
}



- (void)dealloc {
	[_string release];
	
	[super dealloc];
}



#pragma mark -

- (void)setStringValue:(NSString *)string {
	[string retain];
	[_string release];
	
	_string = string;

	_stringWidth = [_string sizeWithAttributes:_attributes].width;
}



- (NSString *)stringValue {
	return _string;
}



#pragma mark -

- (void)startAnimatingIfNeeded {
	_animationOffset = 0.0;
	
	if(_stringWidth > [self frame].size.width * 1.05) {
		[[_attributes objectForKey:NSParagraphStyleAttributeName] setLineBreakMode:NSLineBreakByClipping];

		[self _animate];
	}
}



- (void)stopAnimating {
	_animationOffset = 0.0;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_animate)];
	
	[[_attributes objectForKey:NSParagraphStyleAttributeName] setLineBreakMode:NSLineBreakByTruncatingTail];

	[self setNeedsDisplay:YES];
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	rect.origin.x -= _animationOffset;
	rect.size.width += _animationOffset;
	
	[_string drawInRect:rect withAttributes:_attributes];
}

@end
