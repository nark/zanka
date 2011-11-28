/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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
	[_remotePath release];
	[_folderPath release];
	[_virtualPath release];
	[_destinationPath release];
	[_hash release];
	[_startDate release];
	[_icon release];
	
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

- (void)setQueuePosition:(NSUInteger)queuePosition {
	_queuePosition = queuePosition;
}



- (NSUInteger)queuePosition {
	return _queuePosition;
}



- (void)setSpeed:(double)speed {
	_speed = speed;
}



- (double)speed {
	return _speed;
}



- (void)setSize:(WIFileOffset)size {
	_size = size;
}



- (WIFileOffset)size {
	return _size;
}



- (void)setOffset:(WIFileOffset)offset {
	_offset = offset;
}



- (WIFileOffset)offset {
	return _offset;
}



- (void)setOffsetAtStart:(WIFileOffset)offset {
	_offsetAtStart = offset;
}



- (WIFileOffset)offsetAtStart {
	return _offsetAtStart;
}



- (void)setTransferred:(WIFileOffset)transferred {
	_transferred = transferred;
}



- (WIFileOffset)transferred {
	return _transferred;
}



- (void)setTotalFiles:(NSUInteger)files {
	_totalFiles = files;
}



- (NSUInteger)totalFiles {
	return _totalFiles;
}



- (void)setTransferredFiles:(NSUInteger)files {
	_transferredFiles = files;
}



- (NSUInteger)transferredFiles {
	return _transferredFiles;
}



- (void)setTransferredFilesAtStart:(NSUInteger)files {
	_transferredFilesAtStart = files;
}



- (NSUInteger)transferredFilesAtStart {
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



- (void)setRemotePath:(NSString *)path {
	[path retain];
	[_remotePath release];

	_remotePath = path;
}



- (NSString *)remotePath {
	return _remotePath;
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

- (BOOL)isWorking {
	return (_state == WCTransferWaiting || _state == WCTransferListing ||
			_state == WCTransferRunning || _state == WCTransferPausing ||
			_state == WCTransferStopping || _state == WCTransferRemoving);
}



- (NSString *)status {
	NSString			*format;
	NSTimeInterval		interval;
	WIFileOffset		bytes;
	double				speed;
	
	switch([self state]) {
		case WCTransferLocallyQueued:
			return NSLS(@"Queued", @"Transfer locally queued");
			break;
			
		case WCTransferWaiting:
			return NSLS(@"Waiting", @"Transfer waiting");
			break;
			
		case WCTransferQueued:
			return [NSSWF:NSLS(@"Queued at position %lu", @"Transfer queued (position)"),
				[self queuePosition]];
			break;
		
		case WCTransferListing:
			return [NSSWF:NSLS(@"Listing directory... %lu %@", @"Transfer listing (files, 'file(s)'"),
				[self totalFiles],
				[self totalFiles] == 1
					? NSLS(@"file", @"File singular")
					: NSLS(@"files", @"File plural")];
			break;
			
		case WCTransferRunning:
			bytes = ([self transferred] < [self size]) ? [self size] - [self transferred] : 0;
			interval = ([self speed] > 0) ? (double) bytes / (double) [self speed] : 0;
			
			if([self isFolder] && [self totalFiles] > 1) {
				interval += ([self totalFiles] - [self transferredFiles]) * [self averageRequestTime];
				
				return [NSSWF:NSLS(@"%lu of %lu files, %@ of %@, %@/s, %@", @"Transfer status (files, transferred, size, speed, time)"),
					[self transferredFiles],
					[self totalFiles],
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:[self size]],
					[NSString humanReadableStringForSizeInBytes:[self speed]],
					[NSString humanReadableStringForTimeInterval:interval]];
			} else {
				return [NSSWF:NSLS(@"%@ of %@, %@/s, %@", @"Transfer status (transferred, size, speed, time)"),
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:[self size]],
					[NSString humanReadableStringForSizeInBytes:[self speed]],
					[NSString humanReadableStringForTimeInterval:interval]];
			}
			break;
			
		case WCTransferStopping:
		case WCTransferRemoving:
			return [NSSWF:@"%@%C", NSLS(@"Stopping", @"Transfer stopping"), 0x2026];
			break;
			
		case WCTransferPausing:
			return [NSSWF:@"%@%C", NSLS(@"Pausing", @"Transfer pausing"), 0x2026];
			break;
			
		case WCTransferPaused:
		case WCTransferStopped:
		case WCTransferDisconnected:
			if([self isFolder] && [self totalFiles] > 1) {
				if([self state] == WCTransferPaused)
					format = NSLS(@"Paused at %lu of %lu files, %@ of %@", @"Transfer paused (files, transferred, size)");
				else
					format = NSLS(@"Stopped at %lu of %lu files, %@ of %@", @"Transfer stopped (files, transferred, size)");

				return [NSSWF:format,
					[self transferredFiles],
					[self totalFiles],
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:[self size]]];
			} else {
				if([self state] == WCTransferPaused)
					format = NSLS(@"Paused at %@ of %@", @"Transfer stopped (transferred, size)");
				else
					format = NSLS(@"Stopped at %@ of %@", @"Transfer stopped (transferred, size)");

				return [NSSWF:format,
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:[self size]]];
			}
			break;
			
		case WCTransferFinished:
			bytes = [self transferred] - [self offsetAtStart];
			interval = _accumulatedTime;
			speed = interval > 0.0 ? bytes / interval : 0.0;
			
			if([self isFolder] && [self totalFiles] > 1) {
				return [NSSWF:NSLS(@"Finished %lu files, %@, average %@/s, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[self transferredFiles],
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:speed],
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			} else {
				return [NSSWF:NSLS(@"Finished %@, average %@/s, took %@", @"Transfer finished (files, transferred, speed, time)"),
					[NSString humanReadableStringForSizeInBytes:[self transferred]],
					[NSString humanReadableStringForSizeInBytes:speed],
					[NSString humanReadableStringForTimeInterval:_accumulatedTime]];
			}
			break;
	}
	
	return @"";
}



- (NSImage *)icon {
	if(!_icon) {
		if([self isFolder]) {
			_icon = [[NSImage imageNamed:@"Folder"] retain];
		} else {
			_icon = [[[NSWorkspace sharedWorkspace] iconForFileType:[[self name] pathExtension]] retain];
			[_icon setSize:NSMakeSize(32.0, 32.0)];
		}
	}
	
	return _icon;
}



#pragma mark -

- (BOOL)containsPath:(NSString *)path {
	return [_paths containsObject:path];
}



- (BOOL)containsFile:(WCFile *)file {
	return [_files containsObject:file];
}



- (void)removeFile:(WCFile *)file {
	NSUInteger		index;
	
	index = [_files indexOfObject:file];
	
	if(index != NSNotFound) {
		[_files removeObjectAtIndex:index];
		[_paths removeObjectAtIndex:index];
	}
}



- (NSUInteger)numberOfFiles {
	return [_files count];
}



#pragma mark -

- (void)addPath:(NSString *)path {
	[_paths addObject:path];
}




- (void)removeFirstPath {
	if([_paths count] > 0)
		[_paths removeObjectAtIndex:0];
}



- (NSString *)firstPath {
	if([_paths count] == 0)
		return NULL;
	
	return [_paths objectAtIndex:0];
}



#pragma mark -

- (void)addFile:(WCFile *)file {
	[_files addObject:file];
}



- (void)removeFirstFile {
	if([_files count] > 0)
		[_files removeObjectAtIndex:0];
}



- (WCFile *)firstFile {
	if([_files count] == 0)
		return NULL;
	
	return [_files objectAtIndex:0];
}

@end
