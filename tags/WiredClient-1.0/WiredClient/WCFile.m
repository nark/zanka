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

#import "NSDateAdditions.h"
#import "NSNumberAdditions.h"
#import "WCFile.h"
#import "WCServer.h"

@implementation WCFile

- (id)initWithType:(unsigned int)type {
	self = [super init];
	
	// --- get parameters
	_type = type;
	
	return self;
}



- (void)dealloc {
	[_path release];
	[_name release];
	[_checksum release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];
	
	[coder decodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder decodeValueOfObjCType:@encode(off_t) at:&_size];
	[coder decodeValueOfObjCType:@encode(off_t) at:&_free];

	_path		= [[coder decodeObject] retain];
	_name		= [[coder decodeObject] retain];
	_checksum	= [[coder decodeObject] retain];
	
	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeValueOfObjCType:@encode(unsigned int) at:&_type];
	[coder encodeValueOfObjCType:@encode(off_t) at:&_size];
	[coder encodeValueOfObjCType:@encode(off_t) at:&_free];
	
	[coder encodeObject:_path];
	[coder encodeObject:_name];
	[coder encodeObject:_checksum];
}



#pragma mark -

- (void)setType:(unsigned int)value {
	_type = value;
}



- (unsigned int)type {
	return _type;
}



#pragma mark -

- (void)setSize:(off_t)value {
	_size = value;
}



- (off_t)size {
	return _size;
}



#pragma mark -

- (void)setFree:(off_t)value {
	_free = value;
}



- (off_t)free {
	return _free;
}



#pragma mark -

- (void)setPath:(NSString *)value {
	[value retain];
	[_path release];
	
	_path = value;
}



- (NSString *)path {
	return _path;
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

- (void)setChecksum:(NSString *)value {
	[value retain];
	[_checksum release];
	
	_checksum = value;
}



- (NSString *)checksum {
	return _checksum;
}



#pragma mark -

- (NSString *)kind {
	NSString	*kind;
	
	switch([self type]) {
		case WCFileTypeDirectory:
			LSCopyKindStringForTypeInfo('fold', kLSUnknownCreator, NULL, (CFStringRef *) &kind);
			break;

		case WCFileTypeUploads:
			kind = [[NSString alloc] initWithString:NSLocalizedString(@"Uploads Folder", @"Uploads folder kind")];
			break;

		case WCFileTypeDropBox:
			kind = [[NSString alloc] initWithString:NSLocalizedString(@"Drop Box Folder", @"Drop box folder kind")];
			break;
		
		case WCFileTypeFile:
			LSCopyKindStringForTypeInfo(kLSUnknownType,
										kLSUnknownCreator,
										(CFStringRef) [[self path] pathExtension],
										(CFStringRef *) &kind);
			break;
	}


	return [kind autorelease];
}



- (NSString *)humanReadableSize {
    NSNumber	*size;
    
    size = [NSNumber numberWithUnsignedLongLong:_size];
    
    return [size humanReadableSize];
}



- (NSString *)pathExtension {
	return [[self path] pathExtension];
}



- (NSString *)lastPathComponent {
	return [[self path] lastPathComponent];
}



#pragma mark -

- (NSComparisonResult)kindSort:(WCFile *)other {
	NSComparisonResult		result;
	
	result = [[self kind] compare:[other kind] options:NSCaseInsensitiveSearch];
	
	// --- ordered same - sort by name instead
	if(result == NSOrderedSame)
		result = [self nameSort:other];
		
	return result;
}



- (NSComparisonResult)nameSort:(WCFile *)other {
	unsigned int	options;
	
	options = NSCaseInsensitiveSearch | 64; // 64 = NSNumericSearch

	return [[_path lastPathComponent] compare:[[other path] lastPathComponent]
									  options:options];
}



- (NSComparisonResult)sizeSort:(WCFile *)other {
	// --- first sort by file/dir, file gets precedence over dirs, no matter size
	if(_type == WCFileTypeFile && [other type] != WCFileTypeFile)
		return NSOrderedAscending;
	else if(_type == WCFileTypeDirectory && [other type] != WCFileTypeDirectory)
		return NSOrderedDescending;

	// --- then sort by size
	if(_size > [other size])
		return NSOrderedAscending;
	else if(_size < [other size])
		return NSOrderedDescending;

	// --- ordered same - sort by name instead
	return [self nameSort:other];
}

@end
