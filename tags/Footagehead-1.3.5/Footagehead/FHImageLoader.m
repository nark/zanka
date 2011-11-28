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

#import "FHCache.h"
#import "FHFile.h"
#import "FHImage.h"
#import "FHImageLoader.h"

#define FHImagesToKeepBehind			2

@interface FHImageLoader(Private)

- (void)_asynchronouslyLoadDataForFile:(FHFile *)file;
- (void)_loadDataForFile:(FHFile *)file;
- (void)_loadImageForFile:(FHFile *)file;

@end


@implementation FHImageLoader(Private)

- (void)_asynchronouslyLoadDataForFile:(FHFile *)file {
	NSURLConnection	*connection;
	WIURL			*url;
	
	url = [file URL];
	
	[_asynchronousRequest setURL:[url URL]];
	[_asynchronousRequest setValue:[[url URLByDeletingLastPathComponent] string] forHTTPHeaderField:@"Referer"];
	
	connection = [NSURLConnection connectionWithRequest:_asynchronousRequest delegate:self];

	_asynchronousLength = 0;
	_asynchronousHTTPStatusCode = 0;
	_asynchronousDone = NO;
	_asynchronousFile = file;
	[_asynchronousData setLength:0];
	
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
								 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	} while(!_asynchronousDone);
}



- (void)_loadDataForFile:(FHFile *)file {
	NSData		*data;
	WIURL		*url;
	
	[_notificationCenter mainThreadPostNotificationName:FHImageLoaderWillLoadFile object:file];

	url = [file URL];

	if([url isFileURL]) {
		data = [[NSData alloc] initWithContentsOfFile:[url path]];
		[file setData:data];
		[data release];
	} else {
		[_asynchronousLock lock];
		
		_asynchronousImages = NO;

		[self _asynchronouslyLoadDataForFile:file];
		
		if(_asynchronousHTTPStatusCode < 400) {
			data = [_asynchronousData copy];
			[file setData:data];
			[data release];
		}
		
		[_asynchronousData setLength:0];
		
		[_asynchronousLock unlock];
	}
	
	[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadFile object:file waitUntilDone:YES];
}



- (void)_loadImageForFile:(FHFile *)file {
	NSData		*data;
	WIURL		*url;
	FHImage		*image, *thumbnail;
	
	[_notificationCenter mainThreadPostNotificationName:FHImageLoaderWillLoadImage object:file];

	url = [file URL];

	if([url isFileURL]) {
		data		= [[NSData alloc] initWithContentsOfFile:[url path]];
		image		= [[FHImage alloc] initImageWithData:data];
		thumbnail	= NULL;
		
		[data release];
	} else {
		[_asynchronousLock lock];
		
		_asynchronousImages = YES;
		
		[self _asynchronouslyLoadDataForFile:file];
		
		data		= [_asynchronousData copy];
		image		= [[FHImage alloc] initImageWithData:data];
		thumbnail	= [[FHCache cache] thumbnailForURL:url withData:data];
		
		[data release];

		[_asynchronousData setLength:0];
		
		[_asynchronousLock unlock];
	}
	
	[file setImage:image];
	[file setLoaded:YES];
	_pixels += [image pixels];
	[image release];
	
	[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadImage object:file];
	
	if(thumbnail) {
		[file setThumbnail:thumbnail];

		[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadThumbnail object:file];
	}
}

@end



@implementation FHImageLoader

- (id)init {
	self = [super init];
	
	_notificationCenter		= [[NSNotificationCenter alloc] init];
	
	_imageLock				= [[NSConditionLock alloc] initWithCondition:0];
	_thumbnailLock			= [[NSConditionLock alloc] initWithCondition:0];
	_dataLock				= [[NSConditionLock alloc] initWithCondition:0];

	_asynchronousLock		= [[NSLock alloc] init];
	_asynchronousData		= [[NSMutableData alloc] init];
	
	_asynchronousRequest	= [[NSMutableURLRequest alloc] init];

#ifdef FHConfigurationDebug
	[_asynchronousRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
#endif

	_maxPixels				= ((double) [[NSProcessInfo processInfo] amountOfMemory] / 10) / 5;
	
	[NSThread detachNewThreadSelector:@selector(imageThread:) toTarget:self withObject:NULL];
	[NSThread detachNewThreadSelector:@selector(thumbnailsThread:) toTarget:self withObject:NULL];
	[NSThread detachNewThreadSelector:@selector(dataThread:) toTarget:self withObject:NULL];

	[NSThread setThreadPriority:0.75];
	
	return self;
}



- (void)dealloc {
	[_notificationCenter release];
	
	[_imageLock release];
	[_thumbnailLock release];
	[_dataLock release];
	
	[_asynchronousData release];
	[_asynchronousLock release];
	
	[super dealloc];
}



#pragma mark -

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_asynchronousLength = [response expectedContentLength];
	
	if([response isKindOfClass:[NSHTTPURLResponse class]])
		_asynchronousHTTPStatusCode = [(NSHTTPURLResponse *) response statusCode];
	else
		_asynchronousHTTPStatusCode = 200;
}



- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSString	*notification;
	double		percent;
	
	[_asynchronousData appendData:data];

	if(_asynchronousLength > 0) {
		percent = (double) [_asynchronousData length] / (double) _asynchronousLength;
		
		if(percent > [_asynchronousFile percentReceived] + 0.05 || [_asynchronousFile percentReceived] == 0.0) {
			[_asynchronousFile setPercentReceived:percent];
	
			notification = _asynchronousImages ? FHImageLoaderReceivedImageData : FHImageLoaderReceivedFileData;
			
			[_notificationCenter mainThreadPostNotificationName:notification object:_asynchronousFile];
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
	NSAutoreleasePool		*pool, *loopPool;
	NSArray					*files;
	FHFile					*file;
	NSUInteger				i, count, index;
	NSUInteger				counter, lastCounter;
	BOOL					pause, stop;
	
	[NSThread setThreadPriority:0.5];
	
	pool		= [[NSAutoreleasePool alloc] init];
	loopPool	= NULL;
	lastCounter	= 0;
	pause		= NO;
	stop		= NO;

	while(YES) {
		[loopPool release];
		
		if(stop)
			break;
		
		loopPool = [[NSAutoreleasePool alloc] init];

		[_imageLock lockWhenCondition:1];
		
		index		= _index;
		files		= [[_files copy] autorelease];
		counter		= _imageCounter;
		stop		= _imageStop;
		
		[_imageLock unlockWithCondition:0];
		
		if(stop)
			continue;
		
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
				
				if(![file isDirectory] && ![file image]) {
					if(i > index + 1 && _pixels >= _maxPixels)
						break;
					
					[self _loadImageForFile:file];
				}

				[_imageLock lock];
				
				if(counter != _imageCounter)
					i = count;
				
				pause			= _imagePause;
				_imagePause		= NO;
				stop			= _imageStop;
				
				[_imageLock unlockWithCondition:(counter == _imageCounter || pause || stop) ? 0 : 1];
				
				if(pause || stop)
					break;
			}
			
			lastCounter = counter;
		}
	}
	
	[pool release];
}



- (void)thumbnailsThread:(id)object {
	NSAutoreleasePool	*pool, *loopPool;
	NSArray				*files;
	FHImage				*image;
	FHFile				*file;
	WIURL				*url;
	NSUInteger			i, count, counter, images;
	BOOL				pause, stop;
	
	[NSThread setThreadPriority:0.25];

	pool		= [[NSAutoreleasePool alloc] init];
	loopPool	= NULL;
	pause		= NO;
	stop		= NO;
	
	while(YES) {
		[loopPool release];
		
		if(stop)
			break;
		
		loopPool = [[NSAutoreleasePool alloc] init];
		
		[_thumbnailLock lockWhenCondition:1];
		
		files		= [[_files copy] autorelease];
		counter		= _thumbnailCounter;
		stop		= _thumbnailStop;

		[_thumbnailLock unlockWithCondition:0];
		
		if(stop)
			continue;
		
		count = [files count];
		
		for(i = images = 0; i < count; i++) {
			file = [files objectAtIndex:i];
			url = [file URL];
			
			if(![file isDirectory] && ![file thumbnail] && [url isFileURL]) {
				image = [[FHCache cache] thumbnailForURL:url];
				
				if(image) {
					[file setThumbnail:image];
					
					[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadThumbnail object:file];
				}
			}
				
			if(++images % 5 == 0) {
				[_thumbnailLock lock];
				
				if(counter != _thumbnailCounter)
					i = count;
				
				pause	= _thumbnailPause;
				stop	= _thumbnailStop;
				
				[_thumbnailLock unlockWithCondition:(counter == _thumbnailCounter || pause || stop) ? 0 : 1];
				
				if(pause || stop)
					break;
			}
		}
	}
	
	[pool release];
}



- (void)dataThread:(id)sender {
	NSAutoreleasePool		*pool, *loopPool;
	NSArray					*files;
	FHFile					*file;
	NSUInteger				i, count;
	NSUInteger				counter, lastCounter = 0;
	BOOL					pause, stop;
	
	[NSThread setThreadPriority:0.5];
	
	pool		= [[NSAutoreleasePool alloc] init];
	loopPool	= NULL;
	pause		= NO;
	stop		= NO;
	
	while(YES) {
		[loopPool release];
		
		if(stop)
			break;
		
		loopPool = [[NSAutoreleasePool alloc] init];

		[_dataLock lockWhenCondition:1];
		files = [[_files retain] autorelease];
		counter = _dataCounter;
		stop = _dataStop;
		[_dataLock unlockWithCondition:0];
		
		if(stop)
			continue;
		
		if(counter != lastCounter) {
			count = [files count];
			
			for(i = 0; i < count; i++) {
				file = [files objectAtIndex:i];
				
				if(![file isDirectory] && ![file data])
					[self _loadDataForFile:file];
				
				[_dataLock lock];
				if(counter != _dataCounter)
					i = count;
				pause = _dataPause;
				_dataPause = NO;
				stop = _dataStop;
				[_dataLock unlockWithCondition:counter == _dataCounter ? 0 : 1];
				
				if(pause || stop)
					break;
			}
			
			lastCounter = counter;

			if(!pause && !stop)
				[_notificationCenter mainThreadPostNotificationName:FHImageLoaderDidLoadAllFiles];
		}
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



- (void)pauseLoadingImagesAndThumbnails {
	[_imageLock lock];
	_imagePause = YES;
	[_imageLock unlockWithCondition:0];

	[_thumbnailLock lock];
	_thumbnailPause = YES;
	[_thumbnailLock unlockWithCondition:0];
}



- (void)stopLoadingImagesAndThumbnails {
	[_imageLock lock];
	_imageStop = YES;
	[_imageLock unlockWithCondition:0];

	[_thumbnailLock lock];
	_thumbnailStop = YES;
	[_thumbnailLock unlockWithCondition:0];
}



- (void)startLoadingData {
	[_dataLock lock];
	_dataCounter++;
	[_dataLock unlockWithCondition:1];
}



- (void)pauseLoadingData {
	[_dataLock lock];
	_dataPause = YES;
	[_dataLock unlockWithCondition:0];
}



- (void)stopLoadingData {
	[_dataLock lock];
	_dataStop = YES;
	[_dataLock unlockWithCondition:0];
}

@end
