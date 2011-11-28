/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "NSImage-SPAdditions.h"

@implementation NSImage(SPImageAddition)

- (NSImage *)imageBySuperImposingQuestionMark {
	NSDictionary			*attributes;
	NSImage					*image;
	NSPoint					point;
	NSSize					size;
	CGFloat					fontSize;

	size = [self size];
	
	if(size.width == 16.0) {
		point = NSMakePoint(4.0, 0.0);
		fontSize = 11.0;
	}
	else if(size.width == 128.0) {
		point = NSMakePoint(36.0, 2.0);
		fontSize = 88.0;
	} else {
		return NULL;
	}
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica-Bold" size:fontSize],
			NSFontAttributeName,
		[NSColor blackColor],
			NSForegroundColorAttributeName,
		NULL];

	image = [[NSImage alloc] initWithSize:size];
	[image lockFocus];

	[self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
			operation:NSCompositeSourceOver
			 fraction:1.0];

	[@"?" drawAtPoint:point withAttributes:attributes];
	[image unlockFocus];

	return [image autorelease];
}

@end
