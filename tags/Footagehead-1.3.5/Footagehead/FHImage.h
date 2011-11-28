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

@interface FHImage : WIObject {
	NSImage						*_NSImage;
	NSMutableArray				*_CGImages;
	CGImageRef					_CGImage;
	
	NSDictionary				*_properties;

	WIURL						*_url;
	
	NSSize						_size;
	unsigned long long			_dataLength;
	BOOL						_flipped;
	CGFloat						_orientation;
	NSTimeInterval				_delayTime;
	NSUInteger					_frames;
}

+ (NSArray *)imageFileTypes;

+ (id)imageNamed:(NSString *)name;

- (id)initImageWithImage:(NSImage *)image;
- (id)initImageWithData:(NSData *)data;
- (id)initThumbnailWithURL:(WIURL *)url preferredSize:(NSSize)size;
- (id)initThumbnailWithData:(NSData *)data preferredSize:(NSSize)size;

- (void)setFlipped:(BOOL)flipped;
- (BOOL)flipped;

- (NSDictionary *)properties;
- (NSSize)size;
- (NSUInteger)pixels;
- (unsigned long long)dataLength;
- (CGFloat)orientation;
- (NSTimeInterval)delayTime;
- (NSUInteger)frames;

- (void)drawInRect:(NSRect)rect;
- (void)drawFrame:(NSUInteger)frame inRect:(NSRect)rect;

@end
