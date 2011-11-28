/* $Id$ */

/*
 *  Copyright (c) 2003-2008 Axel Andersson
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

#import <WiredFoundation/NSObject-WIFoundation.h>
#import <WiredAppKit/NSImage-WIAppKit.h>

@implementation NSImage(WIAppKit)

+ (NSImage *)imageWithData:(NSData *)data {
	return [[[self alloc] initWithData:data] autorelease];
}



#pragma mark -

- (NSImage *)smoothedImage {
	NSImageRep  *imageRep;
	NSImage		*image;
	NSSize		size;
	NSInteger	width, height;

	imageRep = [self bestRepresentationForDevice:NULL];
	
	if(!imageRep)
		return NULL;
	
	size	= [self size];
	width	= [imageRep pixelsWide];
	height	= [imageRep pixelsHigh];
	
	if(size.width != width || size.height != height) {
		[self setSize:NSMakeSize(width, height)];
		
		image = [[NSImage alloc] initWithSize:[self size]];
		[image lockFocus];
		
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[[NSGraphicsContext currentContext] setShouldAntialias:YES];
		
		[imageRep drawInRect:NSMakeRect(0.0, 0.0, width, height)];
		[image unlockFocus];
		[self setSize:size];

		return [image autorelease];
	}
	
	return self;
}



- (NSImage *)tintedImageWithColor:(NSColor *)color {
	NSImage		*image;
	NSSize		size;

	size = [self size];
	image = [[NSImage alloc] initWithSize:size];
	[image lockFocus];

	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	[self compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];

	[color set];
	NSRectFillUsingOperation(NSMakeRect(0, 0, size.width, size.height), NSCompositeSourceAtop);
	[image unlockFocus];

	return [image autorelease];
}



- (NSImage *)badgedImageWithInt:(NSUInteger)unread {
	static NSImage			*baaadgeImage, *baadgeImage, *badgeImage;
	static NSDictionary		*attributes;
	NSImage					*image, *badge;
	NSPoint					badgePosition, stringPosition;
	NSSize					size, badgeSize;

	if(unread == 0)
		return self;
	
	if(!baaadgeImage) {
		baaadgeImage = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle bundleWithIdentifier:WIAppKitBundleIdentifier] pathForResource:@"NSImage-Baaadge" ofType:@"tiff"]];
		baadgeImage = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle bundleWithIdentifier:WIAppKitBundleIdentifier] pathForResource:@"NSImage-Baadge" ofType:@"tiff"]];
		badgeImage = [[NSImage alloc] initWithContentsOfFile:
			[[NSBundle bundleWithIdentifier:WIAppKitBundleIdentifier] pathForResource:@"NSImage-Badge" ofType:@"tiff"]];
		
		attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSFont fontWithName:@"Helvetica-Bold" size:24.0],
				NSFontAttributeName,
			[NSColor whiteColor],
				NSForegroundColorAttributeName,
			NULL];
	}

	if(unread >= 100) {
		badge			= baadgeImage;
		badgePosition	= NSMakePoint(60.0, 77.0);
		stringPosition	= NSMakePoint(74.0, 90.0);
	}
	else if(unread >= 10) {
		badge			= badgeImage;
		badgePosition	= NSMakePoint(72.0, 77.0);
		stringPosition	= NSMakePoint(84.0, 90.0);
	}
	else if(unread < 10) {
		badge			= badgeImage;
		badgePosition	= NSMakePoint(72.0, 77.0);
		stringPosition	= NSMakePoint(91.0, 90.0);
	}

	size = [self size];
	badgeSize = [badge size];

	image = [[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)];
	[image setScalesWhenResized:YES];
	[image lockFocus];

	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[NSGraphicsContext currentContext] setShouldAntialias:YES];

	[self setSize:[image size]];
	[self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0.0, 0.0, 128.0, 128.0)
			operation:NSCompositeSourceOver
			 fraction:1.0];
	[badge drawAtPoint:badgePosition
			  fromRect:NSMakeRect(0.0, 0.0, badgeSize.width, badgeSize.height)
			 operation:NSCompositeSourceOver
			  fraction:1.0];

	[[NSSWF:@"%lu", unread] drawAtPoint:stringPosition withAttributes:attributes];
	[image unlockFocus];

	[image setSize:size];
	[self setSize:size];

	return [image autorelease];
}



- (NSImage *)scaledImageWithSize:(NSSize)size {
	NSAffineTransform   *transform;
	NSImage				*image;
	NSImageRep			*imageRep;
	NSSize				imageSize, scaledSize;
	CGFloat				scale, height, width;
	
	imageRep = [[self representations] objectAtIndex:0];
	imageSize = [self size];
	height = size.height / imageSize.height;
	width = size.width / imageSize.width;
	scale = height > width ? width : height;
	
	if(scale >= 1.0)
		return self;
	
	transform = [NSAffineTransform transform];
	[transform scaleBy:scale];
	scaledSize = [transform transformSize:imageSize];
	
	image = [[NSImage alloc] initWithSize:size];
	[image lockFocus];
	[imageRep drawInRect:NSMakeRect((size.width - scaledSize.width) / 2.0, (size.height - scaledSize.height) / 2.0, scaledSize.width, scaledSize.height)];
	[image unlockFocus];

	return [image autorelease];
}



- (NSImage *)mirroredImage {
	NSAffineTransform			*transform;
	NSAffineTransformStruct		flip = { -1.0, 0.0, 0.0, 1.0, [self size].width, 0.0 };

	transform = [NSAffineTransform transform];
	[transform setTransformStruct:flip];

	return [self imageWithAffineTransform:transform action:@selector(concat)];
}



- (NSImage *)imageBySuperimposingImage:(NSImage *)image {
	NSImage			*newImage;
	NSSize			size;

	size = [self size];
	[image setSize:size];
	
	newImage = [[NSImage alloc] initWithSize:size];
	[newImage lockFocus];

	[self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
			operation:NSCompositeSourceOver
			 fraction:1.0];

	[image drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
			operation:NSCompositeSourceOver
			 fraction:1.0];

	[newImage unlockFocus];

	return [newImage autorelease];
}



#pragma mark -

- (NSImage *)imageWithAffineTransform:(NSAffineTransform *)transform action:(SEL)action {
	NSImage		*image;
	NSSize		size;

	size = [self size];
	image = [[NSImage alloc] initWithSize:size];

	[image lockFocus];
	[transform performSelector:action];
	[self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
			operation:NSCompositeCopy
			 fraction:1.0];
	[image unlockFocus];

	return [image autorelease];
}

@end
