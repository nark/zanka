/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCFile.h"
#import "WCTransfer.h"

@interface WCTransfer(Private)

- (id)_initWithType:(WCTransferType)type;

@end


@implementation WCTransfer(Private)

- (id)_initWithType:(WCTransferType)type {
	NSProgressIndicator		*progressIndicator;

	self = [self init];

	[self setType:type];
	[self setState:WCTransferWaiting];

	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
	[progressIndicator setUsesThreadedAnimation:YES];
	[progressIndicator setMinValue:0.0];
	[progressIndicator setMaxValue:1.0];
	[self setProgressIndicator:progressIndicator];
	[progressIndicator release];
	
	_paths = [[NSMutableArray alloc] init];
	_files = [[NSMutableArray alloc] init];
	
	return self;
}

@end


@implementation WCTransfer

+ (id)downloadTransfer {
	return [[[self alloc] _initWithType:WCTransferDownload] autorelease];
}



+ (id)uploadTransfer {
	return [[[self alloc] _initWithType:WCTransferUpload] autorelease];
}



- (void)dealloc {
	[_url release];
	[_name release];
	[_localPath release];
	[_folderPath release];
	[_virtualPath release];
	[_destinationPath release];
	[_hash release];
	[_startDate release];
	
	if([_progressIndicator superview])
		[_progressIndicator removeFromSuperview];
	else
		[_progressIndicator release];
	
	[_paths release];
	[_files release];

	[super dealloc];
}



#pragma mark -

- (void)setType:(WCTransferType)type {
	_type = type;
}



- (WCTransferType)type {
	return _type;
}



- (void)setState:(WCTransferState)state {
	_state = state;

	if(_state < WCTransferRunning)
		[[self progressIndicator] setIndeterminate:YES];
	else
		[[self progressIndicator] setIndeterminate:NO];

	if(_state == WCTransferRunning) {
		if(!_startDate)
			_startDate = [[NSDate date] retain];
	}
	else if(_startDate) {
		_accumulatedTime += [[NSDate date] timeIntervalSinceDate:_startDate];

		[_startDate release];
		_startDate = NULL;
	}
}



- (WCTransferState)state {
	return _state;
}



#pragma mark -

- (void)setQueuePosition:(unsigned int)queuePosition {
	_queuePosition = queuePosition;
}



- (unsigned int)queuePosition {
	return _queuePosition;
}



- (void)setSpeed:(double)speed {
	_speed = speed;
}



- (double)speed {
	return _speed;
}



- (void)setSize:(unsigned long long)size {
	_size = size;
}



- (unsigned long long)size {
	return _size;
}



- (void)setOffset:(unsigned long long)offset {
	_offset = offset;
}



- (unsigned long long)offset {
	return _offset;
}



- (void)setOffsetAtStart:(unsigned long long)offset {
	_offsetAtStart = offset;
}



- (unsigned long long)offsetAtStart {
	return _offsetAtStart;
}



- (void)setTransferred:(unsigned long long)transferred {
	_transferred = transferred;
}



- (unsigned long long)transferred {
	return _transferred;
}



- (void)setTotalFiles:(unsigned int)files {
	_totalFiles = files;
}



- (unsigned int)totalFiles {
	return _totalFiles;
}



- (void)setTransferredFiles:(unsigned int)files {
	_transferredFiles = files;
}



- (unsigned int)transferredFiles {
	return _transferredFiles;
}



- (void)setTransferredFilesAtStart:(unsigned int)files {
	_transferredFilesAtStart = files;
}



- (unsigned int)transferredFilesAtStart {
	return _transferredFilesAtStart;
}



#pragma mark -

- (void)setRequestTime:(NSTimeInterval)time {
	_requestTime = time;
}



- (NSTimeInterval)requestTime {
	return _requestTime;
}



- (void)setAverageRequestTime:(NSTimeInterval)time {
	_averageRequestTime = time;
}



- (NSTimeInterval)averageRequestTime {
	return _averageRequestTime;
}



#pragma mark -

- (void)setFolder:(BOOL)folder {
	_folder = folder;
}



- (BOOL)isFolder {
	return _folder;
}



- (void)setPreview:(BOOL)preview {
	_preview = preview;
}



- (BOOL)isPreview {
	return _preview;
}



- (void)setSecure:(BOOL)secure {
	_secure = secure;
}



- (BOOL)isSecure {
	return _secure;
}



#pragma mark -

- (void)setURL:(WIURL *)url {
	[url retain];
	[_url release];

	_url = url;
}



- (WIURL *)URL {
	return _url;
}



- (void)setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setLocalPath:(NSString *)path {
	[path retain];
	[_localPath release];

	_localPath = path;
}



- (NSString *)localPath {
	return _localPath;
}



- (void)setFolderPath:(NSString *)path {
	[path retain];
	[_folderPath release];

	_folderPath = path;
}



- (NSString *)folderPath {
	return _folderPath;
}



- (void)setVirtualPath:(NSString *)path {
	[path retain];
	[_virtualPath release];

	_virtualPath = path;
}



- (NSString *)virtualPath {
	return _virtualPath;
}



- (void)setDestinationPath:(NSString *)path {
	[path retain];
	[_destinationPath release];

	_destinationPath = path;
}



- (NSString *)destinationPath {
	return _destinationPath;
}



- (void)setHash:(NSString *)hash {
	[hash retain];
	[_hash release];

	_hash = hash;
}



- (NSString *)hash {
	return _hash;
}



- (void)setProgressIndicator:(NSProgressIndicator *)progressIndicator {
	[progressIndicator retain];
	[_progressIndicator release];

	_progressIndicator = progressIndicator;
}



- (NSProgressIndicator *)progressIndicator {
	return _progressIndicator;
}



#pragma mark -

- (NSString *)status {
	NSTimeInterval		interval;
	unsigned long long	bytes;
	double				speed;
	
	switch([self state]) {
		case WCTransferLocallyQueued:
			return NSLS(@"Queued", @"Transfer locally queued");
			break;
			
		case WCTransferWaiting:
			return NSLS(@"Waiting", @"Transfer waiting");
			break;
			
		case WCTransferQueued:
			return [NSSWF:NSLS(@"Queued at position %u", @"Transfer queued (position)"),
				[self queuePosition]];
			break;
		
		case WCTransferListing:
			return [NSSWF:NSLS(@"Listing directory... %u %@", @"Transfer listing (files, 'file(s)'"),
				[self totalFiles],
				[self totalFiles] == 1
					? NSLS(@"file", @"File singular")
					: NSLS(@"files", @"File plural")];
			break;
			
		case WCTransferRunning:
			bytes = [self size] - [self transferred];
			interval = [self speed] > 0 ? (double) bytes / (double) [self speed] : 0;
			
			if([self isFolder] && [self totalFiles] > 1) {
				interval += ([self totalFiles] - [self transferredFiles]) * [self averageRequestTime];
				
				return [NSSWF:NSLS(@"%u of %u files, %@ of %@, %@/s, %@", @"Transfer status (files, transferred, size, speed, time)"),
					[self transferredFiles],
					[self totalFiles],
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:[self size]],
					[NSString humanReadableStringForSize:[self speed]],
					[NSString humanReadableStringForTimeInterval:interval]];
			} else {
				return [NSSWF:NSLS(@"%@ of %@, %@/s, %@", @"Transfer status (transferred, size, speed, time)"),
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:[self size]],
					[NSString humanReadableStringForSize:[self speed]],
					[NSString humanReadableStringForTimeInterval:interval]];
			}
			break;
			
		case WCTransferStopping:
		case WCTransferRemoving:
			return [NSSWF:@"%@%C", NSLS(@"Stopping", @"Transfer stopping"), 0x2026];
			break;
			
		case WCTransferStopped:
			if([self isFolder] && [self totalFiles] > 1) {
				return [NSSWF:
					NSLS(@"Stopped at %u of %u files, %@ of %@", @"Transfer stopped (files, transferred, size)"),
					[self transferredFiles],
					[self totalFiles],
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:[self size]]];
			} else {
				return [NSSWF:
					NSLS(@"Stopped at %@ of %@", @"Transfer stopped (transferred, size)"),
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:[self size]]];
			}
			break;
			
		case WCTransferFinished:
			bytes = [self transferred] - [self offsetAtStart];
			interval = _accumulatedTime;
			speed = interval > 0.0 ? bytes / interval : 0.0;
			
			if([self isFolder] && [self totalFiles] > 1) {
				return [NSSWF:NSLS(@"Finished %u files, %@, average %@/s, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[self transferredFiles],
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:speed],
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			} else {
				return [NSSWF:NSLS(@"Finished %@, average %@/s, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[NSString humanReadableStringForSize:[self transferred]],
					[NSString humanReadableStringForSize:speed],
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			}
			break;
	}
	
	return @"";
}



#pragma mark -

- (BOOL)containsPairWithPath:(NSString *)path {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [_files objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([[file path] isEqualToString:path])
			return YES;
	}

	return NO;
}



- (void)removePairWithPath:(NSString *)path {
	NSEnumerator	*enumerator;
	WCFile			*file;
	int				i = 0;

	enumerator = [_files objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([[file path] isEqualToString:path]) {
			[_files removeObjectAtIndex:i];
			[_paths removeObjectAtIndex:i];
		}

		i++;
	}
}



- (unsigned int)numberOfPairs {
	return [_paths count];
}



#pragma mark -

- (void)addPath:(NSString *)path {
	[_paths addObject:path];
}




- (void)removeFirstPath {
	[_paths removeObjectAtIndex:0];
}



- (NSString *)firstPath {
	return [_paths objectAtIndex:0];
}



#pragma mark -

- (void)addFile:(WCFile *)file {
	[_files addObject:file];
}



- (void)removeFirstFile {
	[_files removeObjectAtIndex:0];
}



- (WCFile *)firstFile {
	return [_files objectAtIndex:0];
}

@end
