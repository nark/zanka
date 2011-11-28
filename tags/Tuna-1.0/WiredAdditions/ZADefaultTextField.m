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

#import <ZankaAdditions/ZADefaultTextField.h>

@implementation ZADefaultTextFieldCell

- (void)setStringValue:(NSString *)value {
	if([value length] == 0 && [self defaultStringValue])
		[super setStringValue:[self defaultStringValue]];
	else
		[super setStringValue:value];
}



- (NSString *)stringValue {
	if([[self defaultStringValue] isEqualToString:[super stringValue]])
		return @"";
	
	return [super stringValue];
}



#pragma mark -

- (void)setDefaultStringValue:(NSString *)value {
	[value retain];
	[_defaultStringValue release];
	
	_defaultStringValue = value;
	
	[super setStringValue:value];
}



- (NSString *)defaultStringValue {
	return _defaultStringValue;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView {
	if([[super stringValue] isEqualToString:[self defaultStringValue]])
		[self setTextColor:[NSColor grayColor]];
	else
		[self setTextColor:[NSColor blackColor]];
	
	[super drawWithFrame:frame inView:controlView];
}

@end



@implementation ZADefaultTextField

+ (Class)cellClass {
	return [ZADefaultTextFieldCell class];
}



#pragma mark -

- (void)setDefaultStringValue:(NSString *)value {
	[[self cell] setDefaultStringValue:value];
}



- (NSString *)defaultStringValue {
	return [[self cell] defaultStringValue];
}

@end
