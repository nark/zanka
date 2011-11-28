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

#import "WCCache.h"
#import "WCFile.h"

@interface WCFile(Private)

- (void)_setType:(WCFileType)type;
- (void)_setPath:(NSString *)path;
- (void)_setCreationDate:(NSDate *)creationDate;
- (void)_setModificationDate:(NSDate *)modificationDate;
- (void)_setChecksum:(NSString *)checksum;
- (void)_setComment:(NSString *)comment;

@end


@implementation WCFile(Private)

- (void)_setType:(WCFileType)type {
	_type = type;
}



- (void)_setPath:(NSString *)path {
	[path retain];
	[_path release];

	_path = path;
}



- (void)_setCreationDate:(NSDate *)creationDate {
	[creationDate retain];
	[_creationDate release];

	_creationDate = creationDate;
}



- (void)_setModificationDate:(NSDate *)modificationDate {
	[modificationDate retain];
	[_modificationDate release];

	_modificationDate = modificationDate;
}



- (void)_setChecksum:(NSString *)checksum {
	[checksum retain];
	[_checksum release];

	_checksum = checksum;
}



- (void)_setComment:(NSString *)comment {
	[comment retain];
	[_comment release];

	_comment = comment;
}

@end


@implementation WCFile

+ (NSImage *)iconForFolderType:(WCFileType)type width:(double)width {
	static NSImage		*folder, *folder16, *folder12;
	static NSImage		*uploads, *uploads16, *uploads12;
	static NSImage		*dropbox, *dropbox16, *dropbox12;
	
	switch(type) {
		case WCFileDirectory:
			if(!folder) {
				folder = [[NSImage imageNamed:@"Folder"] retain];
				folder16 = [[NSImage imageNamed:@"Folder16"] retain];
				folder12 = [[NSImage imageNamed:@"Folder12"] retain];
			}
			
			if(width == 32.0)
				return folder;
			else if(width == 16.0)
				return folder16;
			else if(width == 12.0)
				return folder12;
			break;
			
		case WCFileUploads:
			if(!uploads) {
				uploads = [[NSImage imageNamed:@"Uploads"] retain];
				uploads16 = [[NSImage imageNamed:@"Uploads16"] retain];
				uploads12 = [[NSImage imageNamed:@"Uploads12"] retain];
			}
			
			if(width == 32.0)
				return uploads;
			else if(width == 16.0)
				return uploads16;
			else if(width == 12.0)
				return uploads12;
			break;
			
		case WCFileDropBox:
			if(!dropbox) {
				dropbox = [[NSImage imageNamed:@"DropBox"] retain];
				dropbox16 = [[NSImage imageNamed:@"DropBox16"] retain];
				dropbox12 = [[NSImage imageNamed:@"DropBox12"] retain];
			}
			
			if(width == 32.0)
				return dropbox;
			else if(width == 16.0)
				return dropbox16;
			else if(width == 12.0)
				return dropbox12;
			break;
			
		case WCFileFile:
		default:
			return NULL;
			break;
	}

	return NULL;
}



+ (NSString *)kindForFolderType:(WCFileType)type {
	static NSString		*folder, *uploads, *dropbox;
	
	switch(type) {
		case WCFileDirectory:
			if(!folder)
				LSCopyKindStringForTypeInfo('fold', kLSUnknownCreator, NULL, (CFStringRef *) &folder);
			
			return folder;
			break;
			
		case WCFileUploads:
			if(!uploads)
				uploads = [NSLS(@"Uploads Folder", @"Uploads folder kind") retain];

			return uploads;
			break;
			
		case WCFileDropBox:
			if(!dropbox)
				dropbox = [NSLS(@"Drop Box Folder", @"Drop box folder kind") retain];

			return dropbox;
			break;

		case WCFileFile:
		default:
			return NULL;
			break;
	}
		
	return NULL;
}



+ (WCFileType)folderTypeForString:(NSString *)string {
	static NSString		*uploads, *dropbox;
	NSRange				range;
	
	if(!uploads) {
		uploads = [NSLS(@"upload", @"Short uploads folder kind") retain];
		dropbox = [NSLS(@"drop box", @"Short drop box folder kind") retain];
	}
	
	range = [string rangeOfString:uploads options:NSCaseInsensitiveSearch];

	if(range.location != NSNotFound)
		return WCFileUploads;

	range = [string rangeOfString:dropbox options:NSCaseInsensitiveSearch];

	if(range.location != NSNotFound)
		return WCFileDropBox;
		
	return WCFileDirectory;
}



#pragma mark -

+ (id)fileWithRootDirectory {
	return [self fileWithDirectory:@"/"];
}



+ (id)fileWithDirectory:(NSString *)path {
	return [self fileWithPath:path type:WCFileDirectory];
}



+ (id)fileWithPath:(NSString *)path {
	return [self fileWithPath:path type:WCFileFile];
}



+ (id)fileWithPath:(NSString *)path type:(WCFileType)type {
	WCFile		*file;
	
	file = [[self alloc] init];
	[file _setType:type];
	[file _setPath:path];
	
	return [file autorelease];
}



+ (id)fileWithListArguments:(NSArray *)arguments {
	WCFile		*file;

	file = [[self alloc] init];
	[file _setType:[[arguments safeObjectAtIndex:1] intValue]];
	[file _setPath:[arguments safeObjectAtIndex:0]];
	[file setSize:[[arguments safeObjectAtIndex:2] unsignedLongLongValue]];
	[file _setCreationDate:[NSDate dateWithISO8601String:[arguments safeObjectAtIndex:3]]];
	[file _setModificationDate:[NSDate dateWithISO8601String:[arguments safeObjectAtIndex:4]]];
	
	return [file autorelease];
}



+ (id)fileWithInfoArguments:(NSArray *)arguments {
	WCFile		*file;

	file = [[self alloc] init];
	[file _setType:[[arguments safeObjectAtIndex:1] intValue]];
	[file _setPath:[arguments safeObjectAtIndex:0]];
	[file setSize:[[arguments safeObjectAtIndex:2] unsignedLongLongValue]];
	[file _setCreationDate:[NSDate dateWithISO8601String:[arguments safeObjectAtIndex:3]]];
	[file _setModificationDate:[NSDate dateWithISO8601String:[arguments safeObjectAtIndex:4]]];
	[file _setChecksum:[arguments safeObjectAtIndex:5]];
	[file _setComment:[arguments safeObjectAtIndex:6]];
	
	return [file autorelease];
}



- (void)dealloc {
	[_path release];
	[_creationDate release];
	[_modificationDate release];
	[_checksum release];
	[_comment release];

	[_name release];
	[_extension release];
	[_kind release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super init];

	WIDecode(coder, _type);
	WIDecode(coder, _size);
	WIDecode(coder, _free);
	WIDecode(coder, _path);
	WIDecode(coder, _creationDate);
	WIDecode(coder, _modificationDate);
	WIDecode(coder, _checksum);
	WIDecode(coder, _comment);
	
	WIDecode(coder, _name);
	WIDecode(coder, _extension);
	WIDecode(coder, _kind);

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
	WIEncode(coder, _type);
	WIEncode(coder, _size);
	WIEncode(coder, _free);
	WIEncode(coder, _path);
	WIEncode(coder, _creationDate);
	WIEncode(coder, _modificationDate);
	WIEncode(coder, _checksum);
	WIEncode(coder, _comment);
	
	WIEncode(coder, _name);
	WIEncode(coder, _extension);
	WIEncode(coder, _kind);
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WCFile		*file;
	
	file = [[[self class] allocWithZone:zone] init];

	file->_type				= _type;
	file->_size				= _size;
	file->_free				= _free;
	file->_path				= [_path copy];
	file->_creationDate		= [_creationDate copy];
	file->_modificationDate	= [_modificationDate copy];
	file->_checksum			= [_checksum copy];
	file->_comment			= [_comment copy];

	file->_name				= [_name copy];
	file->_extension		= [_extension copy];
	file->_kind				= [_kind copy];
	
	return file;
}



- (BOOL)isEqual:(id)object {
	if(![self isKindOfClass:object])
		return NO;

	return [[self path] isEqualToString:[object path]];
}



- (unsigned int)hash {
	return [[self path] hash];
}



- (NSString *)description {
	return [NSSWF:@"<%@ %p>{path = %@, type = %d}",
		[self className],
		self,
		[self path],
		[self type]];
}



#pragma mark -

- (WCFileType)type {
	return _type;
}



- (NSString *)path {
	return _path;
}



- (NSDate *)creationDate {
	return _creationDate;
}



- (NSDate *)modificationDate {
	return _modificationDate;
}



- (NSString *)checksum {
	return _checksum;
}



- (NSString *)comment {
	return _comment;
}



#pragma mark -

- (NSString *)name {
	if(!_name)
		_name = [[[self path] lastPathComponent] retain];
	
	return _name;
}



- (NSString *)extension {
	if(!_extension)
		_extension = [[[self path] pathExtension] retain];
	
	return _extension;
}



- (NSString *)kind {
	if(!_kind) {
		if([self isFolder]) {
			_kind = [[[self class] kindForFolderType:[self type]] retain];
		} else {
			LSCopyKindStringForTypeInfo(kLSUnknownType,
									kLSUnknownCreator,
									(CFStringRef) [self extension],
									(CFStringRef *) &_kind);
		}
	}
		
	return _kind;
}



- (BOOL)isFolder {
	return ([self type] != WCFileFile);
}



- (BOOL)isUploadsFolder {
	return ([self type] == WCFileUploads || [self type] == WCFileDropBox);
}



- (NSImage *)iconWithWidth:(double)width {
	NSImage		*icon;
	NSString	*extension;
	
	if([self isFolder]) {
		icon = [[self class] iconForFolderType:[self type] width:width];
	} else {
		extension = [self extension];
		icon = [[WCCache cache] fileIconForExtension:extension];
		
		if(!icon) {
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
			[[WCCache cache] setFileIcon:icon forExtension:extension];
		}
		
		icon = [[icon copy] autorelease];
		[icon setSize:NSMakeSize(width, width)];
	}
	
	return icon;
}



#pragma mark -

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



- (void)setTransferred:(unsigned long long)transferred {
	_transferred = transferred;
}



- (unsigned long long)transferred {
	return _transferred;
}



- (void)setFree:(unsigned long long)free {
	_free = free;
}



- (unsigned long long)free {
	return _free;
}



#pragma mark -

- (NSComparisonResult)compareName:(WCFile *)file {
	return [[self name] compare:[file name] options:NSCaseInsensitiveSearch | NSNumericSearch];
}



- (NSComparisonResult)compareKind:(WCFile *)file {
	NSComparisonResult		result;

	result = [[self kind] compare:[file kind] options:NSCaseInsensitiveSearch];

	if(result == NSOrderedSame)
		result = [self compareName:file];

	return result;
}



- (NSComparisonResult)compareCreationDate:(WCFile *)file {
	NSComparisonResult		result;

	result = [[self creationDate] compare:[file creationDate]];

	if(result == NSOrderedSame)
		result = [self compareName:file];

	return result;
}



- (NSComparisonResult)compareModificationDate:(WCFile *)file {
	NSComparisonResult		result;

	result = [[self modificationDate] compare:[file modificationDate]];

	if(result == NSOrderedSame)
		result = [self compareName:file];

	return result;
}



- (NSComparisonResult)compareSize:(WCFile *)file {
	if([self type] == WCFileFile && [file type] != WCFileFile)
		return NSOrderedAscending;
	else if([self type] != WCFileFile && [file type] == WCFileFile)
		return NSOrderedDescending;

	if([self size] > [file size])
		return NSOrderedAscending;
	else if([self size] < [file size])
		return NSOrderedDescending;

	return [self compareName:file];
}

@end
