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
#import "WCFile.h"
#import "WCTransfer.h"

@implementation WCTransfer

- (id)initWithType:(unsigned int)type {
	self = [self init];
	
	// --- get parameters
	_type = type;
	
	// --- init our array of paths and files contained within
	_paths = [[NSMutableArray alloc] init];
	_files = [[NSMutableArray alloc] init];
	
	return self;
}



- (void)dealloc {
	[_url release];
	[_name release];
	[_root release];
	[_destination release];
	[_hash release];
	[_paths release];
	[_files release];
	
	[_progressIndicator performSelectorOnMainThread:@selector(removeFromSuperview)
						withObject:NULL
						waitUntilDone:NO];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_folder];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_state];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_queue];
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder decodeValueOfObjCType:@encode(off_t) at:&_offset];
	[coder decodeValueOfObjCType:@encode(off_t) at:&_size];
	[coder decodeValueOfObjCType:@encode(off_t) at:&_transferred];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_preview];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_progressInited];
	[coder decodeValueOfObjCType:@encode(BOOL) at:&_secure];

 	_progressIndicator	= [[coder decodeObject] retain];
	_url				= [[coder decodeObject] retain];
	_name				= [[coder decodeObject] retain];
	_root				= [[coder decodeObject] retain];
	_destination		= [[coder decodeObject] retain];
	_hash				= [[coder decodeObject] retain];
	_paths				= [[coder decodeObject] retain];
	_files				= [[coder decodeObject] retain];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_folder];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_state];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_queue];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_speed];
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_offset];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_size];
	[coder encodeValueOfObjCType:@encode(unsigned long long) at:&_transferred];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_preview];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_progressInited];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&_secure];
	
	[coder encodeObject:_progressIndicator];
	[coder encodeObject:_url];
	[coder encodeObject:_name];
	[coder encodeObject:_root];
	[coder encodeObject:_destination];
	[coder encodeObject:_hash];
	[coder encodeObject:_paths];
	[coder encodeObject:_files];
}



#pragma mark -

- (NSString *)status {
	off_t		remaining;
	int			time;

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
			remaining = _size - _transferred;
			time = (int) ceil((double) remaining / (double) _speed);
			return [NSString stringWithFormat:
						NSLocalizedString(@"%@ of %@, %@/s, %@", @"Transfer status (transferred, size, speed, time)"),
						[[NSNumber numberWithUnsignedLongLong:_transferred] humanReadableSize],
						[[NSNumber numberWithUnsignedLongLong:_size] humanReadableSize],
						[[NSNumber numberWithUnsignedInt:_speed] humanReadableSize],
						[[NSNumber numberWithUnsignedInt:time] humanReadableTime]];
			break;

		default:
			return @"";
			break;
	}
}



#pragma mark -

- (void)setType:(unsigned int)value {
	_type = value;
}



- (unsigned int)type {
	return _type;
}



#pragma mark -

- (void)setFolder:(BOOL)value {
	_folder = value;
}



- (BOOL)folder {
	return _folder;
}



#pragma mark -

- (void)setState:(unsigned int)value {
	_state = value;
	
	switch(_state) {
		case WCTransferStateLocallyQueued:
		case WCTransferStateWaiting:
		case WCTransferStateQueued:
			[_progressIndicator setIndeterminate:YES];
			break;
		
		default:
			[_progressIndicator setIndeterminate:NO];
			break;
	}
}



- (unsigned int)state {
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

- (void)setSize:(off_t)value {
	_size = value;
}



- (off_t)size {
	return _size;
}



#pragma mark -

- (void)setOffset:(off_t)value {
	_offset = value;
}



- (off_t)offset {
	return _offset;
}



#pragma mark -

- (void)setTransferred:(off_t)value {
	_transferred = value;
}



- (off_t)transferred {
	return _transferred;
}



#pragma mark -

- (void)setPreview:(BOOL)value {
	_preview = value;
}



- (BOOL)preview {
	return _preview;
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

- (void)setSecure:(BOOL)value {
	_secure = value;
}



- (BOOL)secure {
	return _secure;
}



#pragma mark -

- (void)addPath:(NSString *)value {
	[_paths addObject:value];
}




- (unsigned int)shiftPaths {
	[_paths removeObjectAtIndex:0];
	
	return [_paths count];
}



- (NSString *)path {
	return [_paths objectAtIndex:0];
}



#pragma mark -

- (void)addFile:(WCFile *)value {
	[_files addObject:value];
}



- (unsigned int)shiftFiles {
	[_files removeObjectAtIndex:0];
	
	return [_files count];
}



- (WCFile *)file {
	return [_files objectAtIndex:0];
}



- (unsigned int)fileCount {
	return [_files count];
}



- (BOOL)containsFileWithPath:(NSString *)value {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	enumerator = [_files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([[file path] isEqualToString:value])
			return YES;
	}
	
	return NO;
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



#pragma mark -

- (void)setProgress:(double)value {
	[_progressIndicator setDoubleValue:value];
}



- (double)progress {
	return [_progressIndicator doubleValue];
}



#pragma mark -

- (void)setProgressInited:(BOOL)value {
	_progressInited = value;
}



- (BOOL)progressInited {
	return _progressInited;
}

@end
