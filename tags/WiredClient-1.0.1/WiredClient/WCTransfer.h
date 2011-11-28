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

#import <Cocoa/Cocoa.h>

@class WCFile;

@interface WCTransfer : NSObject <NSCoding> {
	unsigned int			_type;
	BOOL					_folder;
	unsigned int			_state;
	unsigned int			_queue;
	unsigned int			_speed;
	off_t					_offset;
	off_t					_size;
	off_t					_transferred;
	BOOL					_preview;
	BOOL					_progressInited;
	NSProgressIndicator		*_progressIndicator;
	NSURL					*_url;
	NSString				*_name;
	NSString				*_root;
	NSString				*_destination;
	NSString				*_hash;
	BOOL					_secure;
	NSMutableArray			*_paths;
	NSMutableArray			*_files;
}


#define						WCTransferTypeDownload			0
#define						WCTransferTypeUpload			1

#define						WCTransferStateLocallyQueued	0
#define						WCTransferStateWaiting			1
#define						WCTransferStateQueued			2
#define						WCTransferStateRunning			3
#define						WCTransferStateStopped			4


- (id)						initWithType:(unsigned int)type;

- (NSString *)				status;

- (void)					setType:(unsigned int)value;
- (unsigned int)			type;

- (void)					setFolder:(BOOL)value;
- (BOOL)					folder;

- (void)					setState:(unsigned int)value;
- (unsigned int)			state;

- (void)					setQueue:(unsigned int)value;
- (unsigned int)			queue;

- (void)					setSpeed:(unsigned int)value;
- (unsigned int)			speed;

- (void)					setOffset:(off_t)value;
- (off_t)					offset;

- (void)					setSize:(off_t)value;
- (off_t)					size;

- (void)					setTransferred:(off_t)value;
- (off_t)					transferred;

- (void)					setPreview:(BOOL)value;
- (BOOL)					preview;

- (void)					setURL:(NSURL *)value;
- (NSURL *)					URL;

- (void)					setName:(NSString *)value;
- (NSString *)				name;

- (void)					setRoot:(NSString *)value;
- (NSString *)				root;

- (void)					setDestination:(NSString *)value;
- (NSString *)				destination;

- (void)					setSecure:(BOOL)value;
- (BOOL)					secure;

- (void)					setHash:(NSString *)value;
- (NSString *)				hash;

- (void)					addPath:(NSString *)value;
- (unsigned int)			shiftPaths;
- (NSString *)				path;

- (void)					addFile:(WCFile *)value;
- (unsigned int)			shiftFiles;
- (WCFile *)				file;
- (unsigned int)			fileCount;
- (BOOL)					containsFileWithPath:(NSString *)value;

- (void)					setProgressIndicator:(NSProgressIndicator *)value;
- (NSProgressIndicator *)	progressIndicator;

- (void)					setProgress:(double)value;
- (double)					progress;

- (void)					setProgressInited:(BOOL)value;
- (BOOL)					progressInited;

@end
