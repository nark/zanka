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

#define FHImageLoaderWillLoadImage					@"FHImageLoaderWillLoadImage"
#define FHImageLoaderWillLoadFile					@"FHImageLoaderWillLoadFile"

#define FHImageLoaderReceivedImageData				@"FHImageLoaderReceivedImageData"
#define FHImageLoaderReceivedFileData				@"FHImageLoaderReceivedFileData"

#define FHImageLoaderDidLoadImage					@"FHImageLoaderDidLoadImage"
#define FHImageLoaderDidLoadThumbnail				@"FHImageLoaderDidLoadThumbnail"
#define FHImageLoaderDidLoadFile					@"FHImageLoaderDidLoadFile"
#define FHImageLoaderDidLoadAllFiles				@"FHImageLoaderDidLoadAllFiles"


@class FHFile;

@interface FHImageLoader : WIObject {
	NSNotificationCenter							*_notificationCenter;
	
	NSConditionLock									*_imageLock;
	NSConditionLock									*_thumbnailLock;
	NSConditionLock									*_dataLock;

	NSUInteger										_imageCounter;
	NSUInteger										_thumbnailCounter;
	NSUInteger										_dataCounter;
	
	BOOL											_imagePause, _imageStop;
	BOOL											_thumbnailPause, _thumbnailStop;
	BOOL											_dataPause, _dataStop;
	
	NSLock											*_asynchronousLock;
	NSMutableData									*_asynchronousData;
	FHFile											*_asynchronousFile;
	NSMutableURLRequest								*_asynchronousRequest;
	long long										_asynchronousLength;
	NSInteger										_asynchronousHTTPStatusCode;
	NSMutableDictionary								*_asynchronousHTTPHeader;
	BOOL											_asynchronousImages;
	BOOL											_asynchronousDone;
	
	NSArray											*_files;
	NSUInteger										_index;
	
	unsigned long long								_pixels, _maxPixels;
}

- (NSNotificationCenter	*)notificationCenter;

- (void)setFiles:(NSArray *)files;
- (NSArray *)files;

- (void)startLoadingImageAtIndex:(NSUInteger)index;
- (void)startLoadingImages;
- (void)startLoadingThumbnails;
- (void)pauseLoadingImagesAndThumbnails;
- (void)stopLoadingImagesAndThumbnails;
- (void)startLoadingData;
- (void)pauseLoadingData;
- (void)stopLoadingData;

@end
