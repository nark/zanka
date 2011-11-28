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

#import "NSImageAdditions.h"

@implementation NSImage(WCImageMirroring)

- (void)mirror {
	NSAffineTransform *transform;
	NSAffineTransformStruct flip = { -1.0, 0.0, 0.0, 1.0, [self size].width, 0.0 };

	transform = [NSAffineTransform transform];
	[transform setTransformStruct:flip];

	[self applyAffineTransform:transform];
}



- (void)applyAffineTransform:(NSAffineTransform *)transform {
	NSImage		*image;
	NSSize		size;

	// --- apply transformation to temp image
	size = [self size];
	image = [[NSImage alloc] initWithSize:size];

	[image lockFocus];
	[transform concat];
	[self drawAtPoint:NSMakePoint(0, 0)
			 fromRect:NSMakeRect(0, 0, size.width, size.height)
			operation:NSCompositeCopy
			 fraction:1.0];
	[image unlockFocus];

	// --- copy back
	[self lockFocus];
	[image drawAtPoint:NSMakePoint(0, 0)
			  fromRect:NSMakeRect(0, 0, size.width, size.height)
			 operation:NSCompositeCopy
			  fraction:1.0];
	[self unlockFocus];

	[image release];
}

@end
