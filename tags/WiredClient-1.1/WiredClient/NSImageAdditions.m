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

@implementation NSImage(WCSmoothing)

- (NSImage *)initSmoothWithContentsOfFile:(NSString *)filename {
	NSImage		*image, *smoothImage;
	
	// --- load image
	image = [[NSImage alloc] initWithContentsOfFile:filename];
	
	if(!image)
		return NULL;
	
	// --- get smooth image
	smoothImage = [[NSImage alloc] initSmoothWithImage:image];
	
	// --- release original
	[image release];
	
	return smoothImage;
}



- (NSImage *)initSmoothWithImage:(NSImage *)image {
	NSImageRep		*imageRep;
	NSImage			*smoothImage;
	NSSize			size;
	
	// --- get image rep
	imageRep = [image bestRepresentationForDevice:NULL];
	
	if(!imageRep)
		return NULL;
	
	// --- adjust resolution
	[image setSize:NSMakeSize([imageRep pixelsWide], [imageRep pixelsHigh])];
	
	// --- smooth image
	size = [image size];
	smoothImage = [[NSImage alloc] initWithSize:size];
	[smoothImage lockFocus];
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[NSGraphicsContext currentContext] setShouldAntialias:YES];
	
	[imageRep drawInRect:NSMakeRect(0, 0, size.width, size.height)];
	[smoothImage unlockFocus];
	
	return smoothImage;
}

@end



@implementation NSImage(WCImageUnreadBadge)

- (void)applyBadgeWithInt:(unsigned int)unread {
	NSImage		*image, *badge;
	NSPoint		badgePosition, stringPosition;
	
	// --- set new name
	if([[self name] length] > 0)
		[self setName:[NSString stringWithFormat:@"%@ Badge %u", [self name], unread]];
	
	// --- ignore when zero
	if(unread == 0)
		return;
	
	// --- select a badge image to use
	if(unread >= 100) {
		badge			= [NSImage imageNamed:@"Baadge"];
		badgePosition	= NSMakePoint(60, 77);
		stringPosition	= NSMakePoint(74, 90);
	}
	else if(unread >= 10) {
		badge			= [NSImage imageNamed:@"Badge"];
		badgePosition	= NSMakePoint(72, 77);
		stringPosition	= NSMakePoint(84, 90);
	} 
	else if(unread < 10) {
		badge			= [NSImage imageNamed:@"Badge"];
		badgePosition	= NSMakePoint(72, 77);
		stringPosition	= NSMakePoint(91, 90);
	}
	
	// --- create temporary image
	image = [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
	[image setScalesWhenResized:YES];
	
	// --- draw badge image
	[image lockFocus];
	[badge compositeToPoint:badgePosition operation:NSCompositeSourceOver];

	// --- draw unread string
	[[NSString stringWithFormat:@"%u", unread]
		drawAtPoint:stringPosition
		withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"Helvetica-Bold" size:24.0], NSFontAttributeName,
			[NSColor whiteColor], NSForegroundColorAttributeName,
			NULL]];
	[image unlockFocus];
	
	// --- resize to fit source image
	[image setSize:[self size]];
	
	// --- draw everything on top of source
	[self lockFocus];
	[image compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeSourceOver];
	[self unlockFocus];
	
	[image release];
}

@end
	


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
