/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

enum WCFileType {
	WCFileTypeFile			= 0,
	WCFileTypeDirectory,
	WCFileTypeUploads,
	WCFileTypeDropBox
};
typedef enum WCFileType		WCFileType;


@interface WCFile : NSObject <NSCoding> {
	WCFileType				_type;
	
	unsigned long long		_size;
	unsigned long long		_offset;
	unsigned long long		_transferred;
	unsigned long long		_free;

	NSString				*_path;
	NSString				*_name;
	NSString				*_kind;

	NSDate					*_created;
	NSDate					*_modified;

	NSString				*_checksum;
	NSString				*_comment;
}


- (id)						initWithType:(WCFileType)type;

- (void)					setType:(WCFileType)value;
- (WCFileType)				type;

- (void)					setSize:(unsigned long long)value;
- (unsigned long long)		size;

- (void)					setOffset:(unsigned long long)value;
- (unsigned long long)		offset;

- (void)					setTransferred:(unsigned long long)value;
- (unsigned long long)		transferred;

- (void)					setFree:(unsigned long long)value;
- (unsigned long long)		free;

- (void)					setPath:(NSString *)value;
- (NSString *)				path;

- (void)					setName:(NSString *)value;
- (NSString *)				name;

- (void)					setCreated:(NSDate *)value;
- (NSDate *)				created;

- (void)					setModified:(NSDate *)value;
- (NSDate *)				modified;

- (void)					setChecksum:(NSString *)value;
- (NSString *)				checksum;

- (void)					setComment:(NSString *)value;
- (NSString *)				comment;

- (NSString *)				kind;
- (NSString *)				humanReadableSize;
- (NSString *)				pathExtension;
- (NSString *)				lastPathComponent;

@end
