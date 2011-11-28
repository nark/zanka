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

#import "FHCache.h"
#import "FHFile.h"
#import "FHImage.h"
#import "FHImageLoader.h"

#define FHImagesToKeepBehind			2

@implementation FHImageLoader

- (id)init {
	self = [super init];
	
	_notificationCenter	= [[NSNotificationCenter alloc] init];
	
	_imageLock			= [[NSConditionLock alloc] initWithCondition:0];
	_thumbnailLock		= [[NSConditionLock alloc] initWithCondition:0];

	_asynchronousData	= [[NSMutableData alloc] init];

	_maxPixels			= ((double) [[NSProcessInfo processInfo] amountOfMemory] / 10) / 5;
	
	[NSThread detachNewThreadSelector:@selector(imageThread:) toTarget:self withObject:NULL];
	[NSThread detachNewThreadSelector:@selector(thumbnailsThread:) toTarget:self withObject:NULL];

	[NSThread setThreadPriority:0.75];
	
	return self;
}



- (void)dealloc {
	[_notificationCenter release];
	
	[_imageLock release];
	[_thumbnailLock release];
	
	[_asynchronousData release];
	
	[super dealloc];
}



#pragma mark -

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_asynchronousLength = [response expectedContentLength];
}



- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	double		percent;
	
	[_asynchronousData appendData:data];

	if(_asynchronousLength > 0) {
		percent = (double) [_asynchronousData length] / (double) _asynchronousLength;
		
		if(percent > [_asynchronousFile percentReceived] + 0.05 || [_asynchronousFile percentReceived] == 0.0) {
			[_asynchronousFile setPercentReceived:percent];
	
			[_notificationCenter mainThreadPostNotificationName:FHImageLoaderReceivedImageData
														 object:_asynchronousFile];
		}
	}
}



- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	_asynchronousDone = YES;
}



- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	_asynchronousDone = YES;
}



#pragma mark -

- (void)imageThread:(id)object {
	NSAutoreleasePool		*pool;
	NSArray					*files;
	NSData					*data;
	NSURLConnection			*connection;
	NSMutableURLRequest		*request;
	WIURL					*url;
	FHImage					*image;
	FHFile					*file;
	NSUInteger				i, count, index;
	NSUInteger				counter, lastCounter = 0;
	BOOL					stop;
	
	[NSThread setThreadPriority:0.5];
	
	pool = [[NSAutoreleasePool alloc] init];
	request = [[NSMutableURLRequest alloc] init];

	while(YES) {
		if(!pool)
			pool = [[NSAutoreleasePool alloc] init];

		[_imageLock lockWhenCondition:1];
		index = _index;
		files = [[_files retain] autorelease];
		counter = _imageCounter;
		stop = _imageStop;
		[_imageLock unlockWithCondition:0];
		
		if(stop)
			break;
		
		if(counter != lastCounter) {
			count = [files count];
			
			if(_pixels >= _maxPixels && index > FHImagesToKeepBehind) {
				for(i = 0; i < count && i < index - FHImagesToKeepBehind; i++) {
					file = [files objectAtIndex:i];
					
					if([file isDirectory])
						continue;
					
					if(![file isLoaded])
						continue;
					
					_pixels -= [[file image] pixels];
					
					[file setImage:NULL];
					[file setLoaded:NO];
					
					if(_pixels < _maxPixels)
						break;
				}
			}
			
			for(i = index; i < count; i++) {
				file = [files objectAtIndex:i];
				
				if([file isDirectory])
					goto next;
				
				if([file image])
					goto next;
			
				if(i > index + 1 && _pixels >= _maxPixels)
					break;
				
				url = [file URL];
				
				if([url isFileURL]) {
					data = [NSData dataWithContentsOfFile:[url path]];
				} else {
					[request setURL:[url URL]];
					[request setValue:[[url URLByDeletingLastPathComponent] string] forHTTPHeaderField:@"Referer"];

					connection = [NSURLConnection connectionWithRequest:request delegate:self];
					
					_asynchronousDone = NO;
					_asynchronousFile = file;
					[_asynchronousData setLength:0];

					do {
						[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
												 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
					} while(!_asynchronousDone);
					
					data = _asynchronousData;
				}
				
				image = [[FHImage alloc] initImageWithData:data];
				[file setImage:image];
				[file setLoaded:YES];
				_pixels += [image pixels];
				[image release];

				[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadImage object:file];
				
				if([_asynchronousData length] > 0) {
					image = [[FHCache cache] thumbnailForURL:url withData:data];
					
					if(image) {
						[file setThumbnail:image];
						
						[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadThumbnail object:file];
					}

					[_asynchronousData setLength:0];
				}

next:
				[_imageLock lock];
				if(counter != _imageCounter)
					i = count;
				stop = _imageStop;
				[_imageLock unlockWithCondition:counter == _imageCounter ? 0 : 1];
				
				if(stop)
					break;
			}
			
			lastCounter = counter;
		}

		[pool release];
		pool = NULL;
		
		if(stop)
			break;
	}
	
	[request release];
	[pool release];
}



- (void)thumbnailsThread:(id)object {
	NSAutoreleasePool	*pool;
	NSArray				*files;
	FHImage				*image;
	FHFile				*file;
	WIURL				*url;
	NSUInteger			i, count, counter, images;
	BOOL				stop;
	
	[NSThread setThreadPriority:0.25];

	while(YES) {
		pool = [[NSAutoreleasePool alloc] init];

		[_thumbnailLock lockWhenCondition:1];
		files = [[_files retain] autorelease];
		counter = _thumbnailCounter;
		stop = _thumbnailStop;
		[_thumbnailLock unlockWithCondition:0];
		
		if(stop)
			break;
		
		count = [files count];

		for(i = images = 0; i < count; i++) {
			file = [files objectAtIndex:i];
			
			if([file isDirectory] || [file thumbnail])
				goto next;
			
			url = [file URL];
			
			if(![url isFileURL])
				goto next;
			
			image = [[FHCache cache] thumbnailForURL:url];
			
			if(image) {
				[file setThumbnail:image];
			
				[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadThumbnail object:file];
			}
			
next:
			if(++images % 5 == 0) {
				[_thumbnailLock lock];
				if(counter != _thumbnailCounter)
					i = count;
				stop = _thumbnailStop;
				[_thumbnailLock unlockWithCondition:counter == _thumbnailCounter ? 0 : 1];
				
				if(stop)
					break;
			}
		}
		
		[pool release];
		pool = NULL;
		
		if(stop)
			break;
	}
	
	[pool release];
}



#pragma mark -

- (NSNotificationCenter	*)notificationCenter {
	return _notificationCenter;
}



- (void)setFiles:(NSArray *)files {
	[_imageLock lock];
	
	_pixels = 0;
	
	[files retain];
	[_files release];
	
	_files = files;
	
	[_imageLock unlockWithCondition:0];
}



- (NSArray *)files {
	return _files;
}



#pragma mark -

- (void)startLoadingImageAtIndex:(NSUInteger)index {
	[_imageLock lock];
	_index = index;
	_imageCounter++;
	[_imageLock unlockWithCondition:1];
}



- (void)startLoadingImages {
	[_imageLock lock];
	_imageCounter++;
	[_imageLock unlockWithCondition:1];
}



- (void)startLoadingThumbnails {
	[_thumbnailLock lock];
	_thumbnailCounter++;
	[_thumbnailLock unlockWithCondition:1];
}



- (void)stopLoading {
	[_imageLock lock];
	_imageStop = YES;
	[_imageLock unlockWithCondition:1];

	[_thumbnailLock lock];
	_thumbnailStop = YES;
	[_thumbnailLock unlockWithCondition:1];
}

@end
