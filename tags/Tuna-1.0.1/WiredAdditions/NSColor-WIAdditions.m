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

#import <WiredAdditions/NSColor-WIAdditions.h>

@implementation NSColor(WIColorAdditions)

+ (id)colorWithCalibratedHTMLValue:(unsigned int)value alpha:(float)alpha {
	unsigned int	red, green, blue;
	
	red		= (value & 0xFF0000) >> 16;
	green	= (value & 0x00FF00) >> 8;
	blue	= (value & 0x0000FF);
	
	return [self colorWithCalibratedRed:(float) red / 256.0f
								  green:(float) green / 256.0f
								   blue:(float) blue / 256.0f
								  alpha:alpha];
}



#pragma mark -

+ (id)stripeColor {
	static id		stripeColor;
	
	if(!stripeColor) {
		stripeColor = [[self colorWithCalibratedRed:(237.0 / 255.0)
												 green:(243.0 / 255.0)
												  blue:(254.0 / 255.0)
												 alpha:1.0] retain];
	}
	
	return stripeColor;
}



#pragma mark -

NSString * NSStringFromColor(NSColor *color) {
	return [NSSWF:@"NSColor %f %f %f %f",
		[color hueComponent],
		[color saturationComponent],
		[color brightnessComponent],
		[color alphaComponent]];
}



NSColor * NSColorFromString(NSString *string) {
	NSArray		*array;
	
	array = [string componentsSeparatedByString:@" "];
	
	if([array count] != 5 || ![[array objectAtIndex:0] isEqualToString:@"NSColor"])
		return NULL;
	
	return [NSColor colorWithCalibratedHue:[[array objectAtIndex:1] floatValue]
								saturation:[[array objectAtIndex:2] floatValue]
								brightness:[[array objectAtIndex:3] floatValue]
									 alpha:[[array objectAtIndex:4] floatValue]];
}

@end
