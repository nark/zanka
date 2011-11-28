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

enum WCTransferType {
	WCTransferTypeDownload			= 0,
	WCTransferTypeUpload
};
typedef enum WCTransferType			WCTransferType;

enum WCTransferState {
	WCTransferStateWaiting			= 0,
	WCTransferStateLocallyQueued,
	WCTransferStateQueued,
	WCTransferStateRunning,
	WCTransferStateStopping,
	WCTransferStateStopped,
	WCTransferStateRemoving,
	WCTransferStateFinished
};
typedef enum WCTransferState		WCTransferState;


@class WCFile;

@interface WCTransfer : NSObject <NSCoding> {
	WCTransferType					_type;
	WCTransferState					_state;

	unsigned int					_queue;
	unsigned int					_speed;
	unsigned long long				_size;
	unsigned long long				_offset;
	unsigned long long				_initialOffset;
	unsigned long long				_transferred;

	BOOL							_folder;
	BOOL							_preview;
	BOOL							_secure;

	NSProgressIndicator				*_progressIndicator;

	NSURL							*_url;
	NSString						*_name;
	NSString						*_root;
	NSString						*_destination;
	NSString						*_hash;

	NSDate							*_startDate;
	NSTimeInterval					_accumulatedTimeInterval;

	NSMutableArray					*_paths;
	NSMutableArray					*_files;
	NSMutableArray					*_folders;
}


- (id)								initWithType:(WCTransferType)type;

- (NSString *)						status;

- (void)							setType:(WCTransferType)value;
- (WCTransferType)					type;

- (void)							setState:(WCTransferState)value;
- (WCTransferState)					state;

- (void)							setQueue:(unsigned int)value;
- (unsigned int)					queue;

- (void)							setSpeed:(unsigned int)value;
- (unsigned int)					speed;

- (void)							setSize:(unsigned long long)value;
- (unsigned long long)				size;

- (void)							setOffset:(unsigned long long)value;
- (unsigned long long)				offset;

- (void)							setTransferred:(unsigned long long)value;
- (unsigned long long)				transferred;

- (void)							setIsFolder:(BOOL)value;
- (BOOL)							isFolder;

- (void)							setIsPreview:(BOOL)value;
- (BOOL)							isPreview;

- (void)							setIsSecure:(BOOL)value;
- (BOOL)							isSecure;

- (void)							setURL:(NSURL *)value;
- (NSURL *)							URL;

- (void)							setName:(NSString *)value;
- (NSString *)						name;

- (void)							setRoot:(NSString *)value;
- (NSString *)						root;

- (void)							setDestination:(NSString *)value;
- (NSString *)						destination;

- (void)							setHash:(NSString *)value;
- (NSString *)						hash;

- (BOOL)							containsPairWithPath:(NSString *)value;
- (void)							removePairWithPath:(NSString *)value;

- (void)							addPath:(NSString *)value;
- (void)							shiftPaths;
- (NSString *)						path;

- (void)							addFile:(WCFile *)value;
- (void)							shiftFiles;
- (WCFile *)						file;
- (unsigned int)					fileCount;

- (void)							addFolder:(NSString *)path;
- (void)							shiftFolders;
- (NSString *)						folder;
- (unsigned int)					folderCount;

- (void)							setProgressIndicator:(NSProgressIndicator *)value;
- (NSProgressIndicator *)			progressIndicator;

@end
