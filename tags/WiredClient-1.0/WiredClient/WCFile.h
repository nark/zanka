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

@interface WCFile : NSObject <NSCoding> {
	unsigned int			_type;
	off_t					_size;
	off_t					_free;
	NSString				*_path;
	NSString				*_name;
	NSString				*_checksum;
}


#define						WCFileTypeFile				0
#define						WCFileTypeDirectory			1
#define						WCFileTypeUploads			2
#define						WCFileTypeDropBox			3


- (id)						initWithType:(unsigned int)type;

- (void)					setType:(unsigned int)value;
- (unsigned int)			type;

- (void)					setSize:(off_t)value;
- (off_t)					size;

- (void)					setFree:(off_t)value;
- (off_t)					free;

- (void)					setPath:(NSString *)value;
- (NSString *)				path;

- (void)					setName:(NSString *)value;
- (NSString *)				name;

- (void)					setChecksum:(NSString *)value;
- (NSString *)				checksum;

- (NSString *)				kind;
- (NSString *)				humanReadableSize;
- (NSString *)				pathExtension;
- (NSString *)				lastPathComponent;

- (NSComparisonResult)		kindSort:(WCFile *)other;
- (NSComparisonResult)		nameSort:(WCFile *)other;
- (NSComparisonResult)		sizeSort:(WCFile *)other;

@end
