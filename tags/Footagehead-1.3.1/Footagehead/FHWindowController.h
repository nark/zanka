/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

@class FHImageView;
@class FHImageLoader, FHFile, FHSpread;

@interface FHWindowController : WIWindowController {
	IBOutlet FHImageView						*_imageView;
	IBOutlet NSProgressIndicator				*_progressIndicator;

	FHImageLoader								*_imageLoader;
	
	NSMutableDictionary							*_spreads;
}


#define FHWindowControllerChangedScalingMode	@"FHWindowControllerChangedScalingMode"
#define FHWindowControllerChangedSpreadMode		@"FHWindowControllerChangedSpreadMode"


- (void)setImageLoader:(FHImageLoader *)imageLoader;
- (FHImageLoader *)imageLoader;

- (NSArray *)files;
- (FHFile *)fileAtIndex:(NSUInteger)index;
- (NSArray *)filesAtIndexes:(NSIndexSet *)indexes;
- (FHFile *)selectedFile;
- (NSUInteger)selectedIndex;
- (void)selectFileAtIndex:(NSUInteger)index;
- (void)startLoadingImageForFile:(FHFile *)file atIndex:(NSUInteger)index;
- (void)showFile:(FHFile *)file;
- (void)updateFileStatus;
- (FHSpread *)spreadForFile:(FHFile *)file;
- (FHSpread *)selectedSpread;
- (void)updateSpreads;

- (BOOL)firstFile:(id)sender;
- (BOOL)lastFile:(id)sender;
- (BOOL)previousFile:(id)sender;
- (BOOL)nextFile:(id)sender;
- (BOOL)previousImage:(id)sender;
- (BOOL)nextImage:(id)sender;
- (BOOL)previousPage:(id)sender;
- (BOOL)nextPage:(id)sender;

- (void)scalingMode:(id)sender;
- (void)spreadMode:(id)sender;
- (void)spreadRightToLeft:(id)sender;
- (void)rotateRight:(id)sender;
- (void)rotateLeft:(id)sender;

@end
