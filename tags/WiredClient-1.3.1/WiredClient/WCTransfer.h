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

enum _WCTransferType {
	WCTransferDownload,
	WCTransferUpload
};
typedef enum _WCTransferType		WCTransferType;


enum _WCTransferState {
	WCTransferWaiting,
	WCTransferLocallyQueued,
	WCTransferQueued,
	WCTransferListing,
	WCTransferRunning,
	WCTransferStopping,
	WCTransferStopped,
	WCTransferRemoving,
	WCTransferFinished
};
typedef enum _WCTransferState		WCTransferState;


@class WCFile;

@interface WCTransfer : WIObject {
	WCTransferType					_type;
	WCTransferState					_state;
	unsigned int					_queuePosition;
	NSTimeInterval					_requestTime;
	NSTimeInterval					_averageRequestTime;
	BOOL							_folder;
	BOOL							_preview;
	BOOL							_secure;
	WIURL							*_url;
	NSString						*_name;
	NSString						*_localPath;
	NSString						*_folderPath;
	NSString						*_virtualPath;
	NSString						*_destinationPath;
	NSString						*_hash;
	NSProgressIndicator				*_progressIndicator;

	NSDate							*_startDate;
	NSTimeInterval					_accumulatedTime;
	
	NSMutableArray					*_paths;
	NSMutableArray					*_files;
	
@public
	double							_speed;
	unsigned long long				_offset;
	unsigned long long				_offsetAtStart;
	unsigned long long				_transferred;
	unsigned long long				_size;
	unsigned int					_totalFiles;
	unsigned int					_transferredFiles;
	unsigned int					_transferredFilesAtStart;
}


+ (id)downloadTransfer;
+ (id)uploadTransfer;

- (void)setType:(WCTransferType)type;
- (WCTransferType)type;
- (void)setState:(WCTransferState)state;
- (WCTransferState)state;

- (void)setQueuePosition:(unsigned int)queuePosition;
- (unsigned int)queuePosition;
- (void)setSpeed:(double)speed;
- (double)speed;
- (void)setSize:(unsigned long long)size;
- (unsigned long long)size;
- (void)setOffset:(unsigned long long)offset;
- (unsigned long long)offset;
- (void)setOffsetAtStart:(unsigned long long)offset;
- (unsigned long long)offsetAtStart;
- (void)setTransferred:(unsigned long long)transferred;
- (unsigned long long)transferred;
- (void)setTotalFiles:(unsigned int)files;
- (unsigned int)totalFiles;
- (void)setTransferredFiles:(unsigned int)files;
- (unsigned int)transferredFiles;
- (void)setTransferredFilesAtStart:(unsigned int)files;
- (unsigned int)transferredFilesAtStart;

- (void)setRequestTime:(NSTimeInterval)time;
- (NSTimeInterval)requestTime;
- (void)setAverageRequestTime:(NSTimeInterval)time;
- (NSTimeInterval)averageRequestTime;

- (void)setFolder:(BOOL)value;
- (BOOL)isFolder;
- (void)setPreview:(BOOL)value;
- (BOOL)isPreview;
- (void)setSecure:(BOOL)value;
- (BOOL)isSecure;

- (void)setURL:(WIURL *)url;
- (WIURL *)URL;
- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setLocalPath:(NSString *)path;
- (NSString *)localPath;
- (void)setFolderPath:(NSString *)path;
- (NSString *)folderPath;
- (void)setVirtualPath:(NSString *)path;
- (NSString *)virtualPath;
- (void)setDestinationPath:(NSString *)path;
- (NSString *)destinationPath;
- (void)setHash:(NSString *)hash;
- (NSString *)hash;
- (void)setProgressIndicator:(NSProgressIndicator *)progressIndicator;
- (NSProgressIndicator *)progressIndicator;

- (BOOL)isWorking;
- (NSString *)status;

- (BOOL)containsPath:(NSString *)path;
- (BOOL)containsFile:(WCFile *)file;
- (void)removeFile:(WCFile *)file;
- (unsigned int)numberOfFiles;

- (void)addPath:(NSString *)path;
- (void)removeFirstPath;
- (NSString *)firstPath;

- (void)addFile:(WCFile *)file;
- (void)removeFirstFile;
- (WCFile *)firstFile;

@end
