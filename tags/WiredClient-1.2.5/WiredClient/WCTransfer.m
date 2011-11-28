/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "NSThreadAdditions.h"
#import "WCFile.h"
#import "WCTransfer.h"

@implementation WCTransfer

- (id)initWithType:(WCTransferType)type {
	self = [self init];
	
	// --- get parameters
	_type = type;
	
	// --- set initial offset
	_initialOffset = ULLONG_MAX;
	
	// --- init our array of paths and files contained within
	_paths = [[NSMutableArray alloc] init];
	_files = [[NSMutableArray alloc] init];
	_folders = [[NSMutableArray alloc] init];

	// --- init a progress indicator
	_progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
	[_progressIndicator setUsesThreadedAnimation:YES];
	[_progressIndicator setMinValue:0.0];
	[_progressIndicator setMaxValue:1.0];
	
	return self;
}



- (void)dealloc {
	[_progressIndicator performSelectorOnMainThread:@selector(removeFromSuperview)];

	[_url release];
	[_name release];
	[_root release];
	[_destination release];
	[_hash release];
	[_startDate release];
	[_paths release];
	[_files release];
	[_folders release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(WCTransferType) at:&_type];
	[coder decodeValueOfObjCType:@encode(WCTransferState) at:&_state];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_queue];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_size];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_offset];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_initialOffset];
	[coder decodeValueOfObjCType:@encode(unsigned long long) at:&_transferred];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_folder];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_preview];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_secure];
	[coder decodeValueOfObjCType:@encode(NSTimeInterval) at:&_accumulatedTimeInterval];

 	_progressIndicator	= [[coder decodeObject] retain];
	_url				= [[coder decodeObject] retain];
	_name				= [[coder decodeObject] retain];
	_root				= [[coder decodeObject] retain];
	_destination		= [[coder decodeObject] retain];
	_hash				= [[coder decodeObject] retain];
	_startDate			= [[coder decodeObject] retain];
	_paths				= [[coder decodeObject] retain];
	_files				= [[coder decodeObject] retain];
	_folders			= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(WCTransferType) at:&_type];
	[coder encodeValueOfObjCType:@encode(WCTransferState) at:&_state];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_queue];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_size];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_offset];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_initialOffset];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_transferred];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_folder];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_preview];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_secure];
	[coder encodeValueOfObjCType:@encode(NSTimeInterval) at:&_accumulatedTimeInterval];
	
	[coder encodeObject:_progressIndicator];
	[coder encodeObject:_url];
	[coder encodeObject:_name];
	[coder encodeObject:_root];
	[coder encodeObject:_destination];
	[coder encodeObject:_hash];
	[coder encodeObject:_startDate];
	[coder encodeObject:_paths];
	[coder encodeObject:_files];
	[coder encodeObject:_folders];
}



#pragma mark -

- (NSString *)status {
	NSTimeInterval		interval;
	unsigned long long	bytes;
	unsigned int		speed;

	switch([self state]) {
		case WCTransferStateLocallyQueued:
			return NSLocalizedString(@"Queued", @"Transfer locally queued");
			break;
		
		case WCTransferStateWaiting:
			return NSLocalizedString(@"Waiting", @"Transfer waiting");
			break;
		
		case WCTransferStateQueued:
			return [NSString stringWithFormat:
				NSLocalizedString(@"Queued at position %u", @"Transfer queued (position)"),
				_queue];
			break;
		
		case WCTransferStateRunning:
			bytes = _size - _transferred;
			interval = _speed > 0 ? (double) bytes / (double) _speed : 0;
			
			return [NSString stringWithFormat:
				NSLocalizedString(@"%@ of %@, %@/s, %@", @"Transfer status (transferred, size, speed, time)"),
				[NSString humanReadableStringForSize:_transferred],
				[NSString humanReadableStringForSize:_size],
				[NSString humanReadableStringForSize:_speed],
				[NSString humanReadableStringForTimeInterval:interval]];
			break;
		
		case WCTransferStateStopping:
		case WCTransferStateRemoving:
			return [NSString stringWithFormat:
				@"%@%C", NSLocalizedString(@"Stopping", @"Transfer stopping"), 0x2026];
			break;
		
		case WCTransferStateStopped:
			return [NSString stringWithFormat:
				NSLocalizedString(@"Stopped at %@ of %@", @"Transfer stopped (transferred, size)"),
				[NSString humanReadableStringForSize:_transferred],
				[NSString humanReadableStringForSize:_size]];
			break;
			
		case WCTransferStateFinished:
			bytes = _transferred - _initialOffset;
			speed = _accumulatedTimeInterval > 0.0
				? (double) bytes / _accumulatedTimeInterval
				: 0;
			
			return [NSString stringWithFormat:
				NSLocalizedString(@"Finished %@, average %@/s, took %@", @"Transfer finished (transferred, speed, time)"),
				[NSString humanReadableStringForSize:_transferred],
				[NSString humanReadableStringForSize:speed],
				[NSString humanReadableStringForTimeInterval:_accumulatedTimeInterval]];
			break;
	}
	
	return @"";
}



#pragma mark -

- (void)setType:(WCTransferType)value {
	_type = value;
}



- (WCTransferType)type {
	return _type;
}



#pragma mark -

- (void)setState:(WCTransferState)value {
	_state = value;
	
	if(_state < WCTransferStateRunning) 
		[_progressIndicator setIndeterminate:YES];
	else
		[_progressIndicator setIndeterminate:NO];
	
	if(_state == WCTransferStateRunning) {
		if(!_startDate)
			_startDate = [[NSDate date] retain];
	}
	else if(_startDate) {
		_accumulatedTimeInterval += [[NSDate date] timeIntervalSinceDate:_startDate];
		
		[_startDate release];
		_startDate = NULL;
	}
}



- (WCTransferState)state {
	return _state;
}



#pragma mark -

- (void)setQueue:(unsigned int)value {
	_queue = value;
}



- (unsigned int)queue {
	return _queue;
}



#pragma mark -

- (void)setSpeed:(unsigned int)value {
	_speed = value;
}



- (unsigned int)speed {
	return _speed;
}



#pragma mark -

- (void)setSize:(unsigned long long)value {
	_size = value;
}



- (unsigned long long)size {
	return _size;
}



#pragma mark -

- (void)setOffset:(unsigned long long)value {
	_offset = value;
	
	if(_initialOffset == ULLONG_MAX)
		_initialOffset = value;
}



- (unsigned long long)offset {
	return _offset;
}



#pragma mark -

- (void)setTransferred:(unsigned long long)value {
	double  percent;
	
	_transferred = value;
	
	percent = (double) _transferred / _size;
	
	if(percent == 1.00 || percent - [_progressIndicator doubleValue] >= 0.001)
		[_progressIndicator setDoubleValue:percent];
}



- (unsigned long long)transferred {
	return _transferred;
}



#pragma mark -

- (void)setIsFolder:(BOOL)value {
	_folder = value;
}



- (BOOL)isFolder {
	return _folder;
}



#pragma mark -

- (void)setIsPreview:(BOOL)value {
	_preview = value;
}



- (BOOL)isPreview {
	return _preview;
}



#pragma mark -

- (void)setIsSecure:(BOOL)value {
	_secure = value;
}



- (BOOL)isSecure {
	return _secure;
}



#pragma mark -

- (void)setURL:(NSURL *)value {
	[value retain];
	[_url release];

	_url = value;
}



- (NSURL *)URL {
	return _url;
}



#pragma mark -

- (void)setName:(NSString *)value {
	[value retain];
	[_name release];

	_name = value;
}



- (NSString *)name {
	return _name;
}



#pragma mark -

- (void)setRoot:(NSString *)value {
	[value retain];
	[_root release];

	_root = value;
}



- (NSString *)root {
	return _root;
}



#pragma mark -

- (void)setDestination:(NSString *)value {
	[value retain];
	[_destination release];

	_destination = value;
}



- (NSString *)destination {
	return _destination;
}



#pragma mark -

- (void)setHash:(NSString *)value {
	[value retain];
	[_hash release];

	_hash = value;
}



- (NSString *)hash {
	return _hash;
}



#pragma mark -

- (BOOL)containsPairWithPath:(NSString *)value {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	enumerator = [_files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([[file path] isEqualToString:value])
			return YES;
	}
	
	return NO;
}



- (void)removePairWithPath:(NSString *)value {
	NSEnumerator	*enumerator;
	WCFile			*file;
	int				i = 0;
	
	enumerator = [_files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([[file path] isEqualToString:value]) {
			[_files removeObjectAtIndex:i];
			[_paths removeObjectAtIndex:i];
		}
		
		i++;
	}
}



#pragma mark -

- (void)addPath:(NSString *)value {
	[_paths addObject:value];
}




- (void)shiftPaths {
	[_paths removeObjectAtIndex:0];
}



- (NSString *)path {
	return [_paths objectAtIndex:0];
}



#pragma mark -

- (void)addFile:(WCFile *)value {
	[_files addObject:value];
}



- (void)shiftFiles {
	[_files removeObjectAtIndex:0];
}



- (WCFile *)file {
	return [_files objectAtIndex:0];
}



- (unsigned int)fileCount {
	return [_files count];
}



#pragma mark -

- (void)addFolder:(NSString *)path {
	[_folders addObject:path];
}



- (void)shiftFolders {
	[_folders removeObjectAtIndex:0];
}



- (NSString *)folder {
	return [_folders objectAtIndex:0];
}



- (unsigned int)folderCount {
	return [_folders count];
}



#pragma mark -

- (void)setProgressIndicator:(NSProgressIndicator *)value {
	[value retain];
	[_progressIndicator release];

	_progressIndicator = value;
}



- (NSProgressIndicator *)progressIndicator {
	return _progressIndicator;
}

@end
