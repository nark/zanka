/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
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

#import "TNFunction.h"
#import "TNNode.h"
#import "TNParser.h"
#import "TNTree.h"

@interface NSColor(TNColorAdditions)

+ (id)colorWithCalibratedHTMLValue:(NSUInteger)value alpha:(float)alpha;

@end


@implementation NSColor(TNColorAdditions)

+ (id)colorWithCalibratedHTMLValue:(NSUInteger)value alpha:(float)alpha {
	NSUInteger		red, green, blue;
	
	red		= (value & 0xFF0000) >> 16;
	green	= (value & 0x00FF00) >> 8;
	blue	= (value & 0x0000FF);
	
	return [self colorWithCalibratedRed:(float) red / 256.0f
								  green:(float) green / 256.0f
								   blue:(float) blue / 256.0f
								  alpha:alpha];
}

@end



@implementation TNParser

+ (BOOL)handlesString:(NSString *)string {
	return NO;
}



#pragma mark -

- (id)initWithString:(NSString *)string {
	self = [super init];
	
	_string		= [string retain];
	_usedColors	= [[NSMutableDictionary alloc] initWithCapacity:50];
	_colors		= [[NSArray alloc] initWithObjects:
		[NSColor blackColor],
		[NSColor colorWithCalibratedHTMLValue:0x5C0808 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x716940 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x1335FE alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xFD54FD alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x056767 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x332738 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xA64379 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x154F15 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x942A93 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x0C0C6D alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xFD3B12 alpha:1.0],
	NULL];

	_functions	= CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
	
	return self;
}



- (void)dealloc {
	[_string release];
	[_usedColors release];
	[_colors release];
	
	CFRelease(_functions);

	[super dealloc];
}



#pragma mark -

- (id)parsedTree {
	return NULL;
}



- (NSColor *)colorForLibrary:(NSString *)library {
	NSColor		*color;
	
	color = [_usedColors objectForKey:library];
	
	if(!color) {
		if(_colorIndex >= [_colors count])
			_colorIndex = 0;
		
		color = [_colors objectAtIndex:_colorIndex++];
		
		[_usedColors setObject:color forKey:library];
	}
	
	return color;
}

@end
