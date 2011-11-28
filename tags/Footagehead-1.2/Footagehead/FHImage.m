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

#import "NSData-FHAdditions.h"
#import "NSImage-FHAdditions.h"
#import "FHImage.h"

static BOOL				FHImageUseCGImage = YES;


@interface FHImage(Private)

- (BOOL)_initImageWithData:(NSData *)data;

@end


@implementation FHImage(Private)

- (BOOL)_initImageWithData:(NSData *)data {
	if(FHImageUseCGImage && CGImageSourceCreateWithData != NULL) {
		NSDictionary		*options;
		CGImageSourceRef	imageSource;
		
		imageSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
		
		if(!imageSource)
			return NO;

		options = [NSDictionary dictionaryWithObjectsAndKeys:
			(id) kCFBooleanTrue,	(id) kCGImageSourceShouldCache,
			(id) kCFBooleanTrue,	(id) kCGImageSourceShouldAllowFloat,
			NULL];
		
		_CGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, (CFDictionaryRef) options);
		
		if(!_CGImage) {
			CFRelease(imageSource);
			
			return NO;
		}
		
		_size = NSMakeSize(CGImageGetWidth(_CGImage), CGImageGetHeight(_CGImage));

		CFRelease(imageSource);
	} else {
		_NSImage = [[NSImage alloc] initWithData:data];
		
		if(!_NSImage)
			return NO;
		
		_size = [_NSImage size];
	}
	
	return YES;
}

@end


@implementation FHImage

+ (id)imageNamed:(NSString *)name {
	NSImage		*image;

	image = [NSImage imageNamed:name];

	if(!image)
		return NULL;
	
	return [[[self alloc] initImageWithImage:image] autorelease];
}



#pragma mark -

- (id)initImageWithImage:(NSImage *)image {
	self = [super init];
	
	_NSImage	= [image retain];
	_size		= [_NSImage size];
	
	return self;
}



- (id)initImageWithURL:(WIURL *)url {
	NSData		*data;
	
	self = [super init];
	
	data = [NSData dataWithContentsOfURL:url returningResponse:NULL];
	
	if(!data) {
		[self release];
		
		return NULL;
	}
	
	if(![self _initImageWithData:data]) {
		[self release];
		
		return NULL;
	}
	
	return self;
}



- (id)initImageWithData:(NSData *)data {
	self = [super init];
	
	if(![self _initImageWithData:data]) {
		[self release];
		
		return NULL;
	}
	
	return self;
}



- (id)initThumbnailWithURL:(WIURL *)url preferredSize:(NSSize)size {
	self = [super init];
	
	if(FHImageUseCGImage && CGImageSourceCreateWithURL != NULL) {
		NSDictionary		*options;
		CGImageSourceRef	imageSource;
		CFNumberRef			number;
		
		imageSource = CGImageSourceCreateWithURL((CFURLRef) [url URL], NULL);
		
		if(!imageSource) {
			[self release];
			
			return NULL;
		}
		
		number = CFNumberCreate(NULL, kCFNumberFloatType, &size.width);
		options = [NSDictionary dictionaryWithObjectsAndKeys:
			(id) kCFBooleanTrue,	(id) kCGImageSourceShouldCache,
			(id) kCFBooleanTrue,	(id) kCGImageSourceCreateThumbnailFromImageIfAbsent,
			(id) number,			(id) kCGImageSourceThumbnailMaxPixelSize,
			NULL];
		
		_CGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef) options);
		
		if(!_CGImage) {
			[self release];
			CFRelease(imageSource);
			
			return NULL;
		}
		
		_size = NSMakeSize(CGImageGetWidth(_CGImage), CGImageGetHeight(_CGImage));
		
		CFRelease(imageSource);
	} else {
		_NSImage = [[NSImage alloc] initWithJPEGFile:[url path] preferredSize:size];
		
		if(!_NSImage) {
			[self release];
			
			return NULL;
		}
		
		_size = [_NSImage size];
	}
	
	return self;
}



#pragma mark -

- (void)dealloc {
	CGImageRelease(_CGImage);
	
	[_NSImage release];
	
	[super dealloc];
}



#pragma mark -

- (void)setFlipped:(BOOL)flipped {
	_flipped = flipped;
}



- (BOOL)flipped {
	return _flipped;
}



- (NSSize)size {
	return _size;
}



#pragma mark -

- (void)drawInRect:(NSRect)rect atAngle:(float)angle {
	NSImageRep		*imageRep;
	CGContextRef	cgContext;
	CGRect			cgRect;
	CGPoint			cgPoint;
	BOOL			restore = NO;
	
	cgContext	= (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	cgRect		= CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);

	if(_flipped || angle != 0.0f) {
		CGContextSaveGState(cgContext);
		
		if(_flipped) {
			CGContextTranslateCTM(cgContext, 0.0f, rect.origin.y + rect.origin.y + rect.size.height);
			CGContextScaleCTM(cgContext, 1.0f, -1.0f);
		} else {
			cgPoint.x = rect.origin.x + (rect.size.width / 2.0f);
			cgPoint.y = rect.origin.y + (rect.size.height / 2.0f);

			CGContextTranslateCTM(cgContext, cgPoint.x, cgPoint.y);
			CGContextRotateCTM(cgContext, angle * M_PI / 180.0f);
			CGContextTranslateCTM(cgContext, -cgPoint.x, -cgPoint.y);
		}
		
		restore = YES;
	}

	if(_CGImage) {
		CGContextDrawImage(cgContext, cgRect, _CGImage);
	} else {
		imageRep = [_NSImage bestRepresentationForDevice:NULL];
		
		if(imageRep) {
			if([imageRep hasAlpha] || _flipped)
				[_NSImage drawInRect:rect fromRect:NSMakeRect(0.0, 0.0, _size.width, _size.height) operation:NSCompositeSourceOver fraction:1.0];
			else
				[imageRep drawInRect:rect];
		}
	}
	
	if(restore)
		CGContextRestoreGState(cgContext);
}

@end
