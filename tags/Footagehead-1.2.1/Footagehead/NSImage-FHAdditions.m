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

#import "NSBitmapImageRep-FHAdditions.h"
#import "NSImage-FHAdditions.h"

@implementation NSImage(FHAdditions)

+ (NSArray *)FHImageFileTypes {
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

+ (id)imageWithJPEGFile:(NSString *)path preferredSize:(NSSize)size {
	return [[[self alloc] initWithJPEGFile:path preferredSize:size] autorelease];
}



- (id)initWithJPEGFile:(NSString *)path preferredSize:(NSSize)size {
	NSBitmapImageRep		*imageRep;
	
	imageRep = [[NSBitmapImageRep alloc] initWithJPEGFile:path preferredSize:size];
	
	if(!imageRep) {
		[self release];
		
		return NULL;
	}
	
	self = [self initWithSize:NSMakeSize([imageRep pixelsWide], [imageRep pixelsHigh])];
	[self addRepresentation:imageRep];
	
	return self;
}

@end
