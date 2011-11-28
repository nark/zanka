/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "FHImage.h"

@interface FHImage(Private)

- (BOOL)_initImageWithImageSource:(CGImageSourceRef)imageSource;
- (BOOL)_initThumbnailWithImageSource:(CGImageSourceRef)imageSource preferredSize:(NSSize)size;
- (void)_initProperties;

@end


@implementation FHImage(Private)

- (BOOL)_initImageWithImageSource:(CGImageSourceRef)imageSource {
	NSDictionary		*options;
	CGImageRef			image;
	NSUInteger			i, count;

	options = [NSDictionary dictionaryWithObjectsAndKeys:
		(id) kCFBooleanTrue,	(id) kCGImageSourceShouldCache,
		(id) kCFBooleanTrue,	(id) kCGImageSourceShouldAllowFloat,
		NULL];
	
	count = CGImageSourceGetCount(imageSource);
	
	_CGImages = [[NSMutableArray alloc] initWithCapacity:count];
	
	for(i = 0; i < count; i++) {
		image = CGImageSourceCreateImageAtIndex(imageSource, i, (CFDictionaryRef) options);
		
		if(image)
			[_CGImages addObject:[NSValue valueWithPointer:image]];
	}
	
	_frames = [_CGImages count];
	
	if(_frames == 0)
		return NO;
	
	_CGImage = CGImageRetain([[_CGImages objectAtIndex:0] pointerValue]);
	
	_size = NSMakeSize(CGImageGetWidth(_CGImage), CGImageGetHeight(_CGImage));

	_properties = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef) options);

	[self _initProperties];
	
	return YES;
}



- (BOOL)_initThumbnailWithImageSource:(CGImageSourceRef)imageSource preferredSize:(NSSize)size {
	NSDictionary		*options;
	CFNumberRef			number;
	
	number = CFNumberCreate(NULL, kCFNumberFloatType, &size.width);
	options = [NSDictionary dictionaryWithObjectsAndKeys:
		(id) kCFBooleanTrue,	(id) kCGImageSourceShouldCache,
		(id) kCFBooleanTrue,	(id) kCGImageSourceCreateThumbnailFromImageIfAbsent,
		(id) number,			(id) kCGImageSourceThumbnailMaxPixelSize,
		NULL];
	
	_CGImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (CFDictionaryRef) options);
	
	if(!_CGImage)
		return NO;
	
	_size = NSMakeSize(CGImageGetWidth(_CGImage), CGImageGetHeight(_CGImage));
	
	_properties = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef) options);
	
	return YES;
}



- (void)_initProperties {
	switch([[_properties objectForKey:(id) kCGImagePropertyOrientation] intValue]) {
		case 3:
			_orientation = 180.0;
			break;
			
		case 6:
			_orientation = 90.0;
			break;
			
		case 8:
			_orientation = 270.0;
			break;
			
		default:
			_orientation = 0.0;
			break;
	}
	
	_delayTime = [[[_properties objectForKey:(id) kCGImagePropertyGIFDictionary] objectForKey:(id) kCGImagePropertyGIFDelayTime] doubleValue];
}

@end



@implementation FHImage

+ (NSArray *)imageFileTypes {
	static NSMutableArray		*types;
	
	if(!types) {
		types = [[NSMutableArray alloc] initWithArray:[NSImage imageFileTypes]];
		[types removeObject:@"pdf"];
		[types removeObject:@"PDF"];
		[types removeObject:NSFileTypeForHFSTypeCode('PDF ')];
		[types addObject:@"jpe"];
	}
	
	return types;
}



#pragma mark -

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
	
	[self _initProperties];

	return self;
}



- (id)initImageWithData:(NSData *)data {
	CGImageSourceRef	imageSource;
	
	self = [super init];
	
	imageSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
	
	if(!imageSource) {
		[self release];
		
		return NULL;
	}
	
	if(![self _initImageWithImageSource:imageSource]) {
		CFRelease(imageSource);
		
		[self release];
		
		return NULL;
	}
	
	_dataLength = [data length];
	
	CFRelease(imageSource);
	
	return self;
}



- (id)initThumbnailWithURL:(WIURL *)url preferredSize:(NSSize)size {
	CGImageSourceRef	imageSource;
	
	self = [super init];
	
	imageSource = CGImageSourceCreateWithURL((CFURLRef) [url URL], NULL);
	
	if(!imageSource) {
		[self release];
		
		return NULL;
	}

	if(![self _initThumbnailWithImageSource:imageSource preferredSize:size]) {
		CFRelease(imageSource);
		
		[self release];
		
		return NULL;
	}
	
	CFRelease(imageSource);
		
	return self;
}



- (id)initThumbnailWithData:(NSData *)data preferredSize:(NSSize)size {
	CGImageSourceRef	imageSource;
	
	self = [super init];
	
	imageSource = CGImageSourceCreateWithData((CFDataRef) data, NULL);
	
	if(!imageSource) {
		[self release];
		
		return NULL;
	}

	if(![self _initThumbnailWithImageSource:imageSource preferredSize:size]) {
		CFRelease(imageSource);
		
		[self release];
		
		return NULL;
	}
	
	CFRelease(imageSource);
		
	return self;
}



#pragma mark -

- (void)dealloc {
	NSUInteger		i, count;
	
	count = [_CGImages count];
	
	for(i = 0; i < count; i++)
		CGImageRelease([[_CGImages objectAtIndex:i] pointerValue]);
	
	[_CGImages release];
	
	CGImageRelease(_CGImage);
	
	[_NSImage release];
	
	[_properties release];

	[super dealloc];
}



#pragma mark -

- (void)setFlipped:(BOOL)flipped {
	_flipped = flipped;
}



- (BOOL)flipped {
	return _flipped;
}



- (NSDictionary *)properties {
	return _properties;
}



- (NSSize)size {
	return _size;
}



- (NSUInteger)pixels {
	return _size.width * _size.height;
}



- (unsigned long long)dataLength {
	return _dataLength;
}



- (CGFloat)orientation {
	return _orientation;
}



- (NSTimeInterval)delayTime {
	return _delayTime;
}



- (NSUInteger)frames {
	return _frames;
}



#pragma mark -

- (void)drawInRect:(NSRect)rect {
	[self drawFrame:0 inRect:rect];
}



- (void)drawFrame:(NSUInteger)frame inRect:(NSRect)rect {
	NSImageRep		*imageRep;
	CGImageRef		image;
	CGContextRef	context;
	
	context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	
	if(_CGImage) {
		if(frame == 0)
			image = _CGImage;
		else
			image = [[_CGImages objectAtIndex:frame] pointerValue];
		
		CGContextDrawImage(context, CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height), image);
	} else {
		imageRep = [_NSImage bestRepresentationForDevice:NULL];
		
		if(imageRep) {
			if([imageRep hasAlpha] || _flipped)
				[_NSImage drawInRect:rect fromRect:NSMakeRect(0.0, 0.0, _size.width, _size.height) operation:NSCompositeSourceOver fraction:1.0];
			else
				[imageRep drawInRect:rect];
		}
	}
}

@end
