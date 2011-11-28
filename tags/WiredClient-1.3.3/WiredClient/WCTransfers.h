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

@class WCFile, WCTransfer;

@interface WCTransfers : WCConnectionController {
	IBOutlet WITableView					*_transfersTableView;
	IBOutlet NSTableColumn					*_iconTableColumn;
	IBOutlet NSTableColumn					*_infoTableColumn;

	IBOutlet NSButton						*_startButton;
	IBOutlet NSButton						*_stopButton;
	IBOutlet NSButton						*_removeButton;
	IBOutlet NSButton						*_revealInFinderButton;
	IBOutlet NSButton						*_revealInFilesButton;

	NSMutableArray							*_transfers;

	NSImage									*_folderImage, *_lockedImage, *_unlockedImage;
	NSTimer									*_timer;
	NSLock									*_lock;
	
	NSUInteger								_receivingFileLists;
	NSUInteger								_receivingFileInfo;
}


#define WCTransfersChecksumLength			1048576

#define WCTransfersFileExtension			@"WiredTransfer"

#define WCTransferPboardType				@"WCTransferPboardType"


+ (id)transfersWithConnection:(WCServerConnection *)connection;

- (BOOL)downloadFile:(WCFile *)file;
- (BOOL)downloadFile:(WCFile *)file toFolder:(NSString *)destination;
- (BOOL)previewFile:(WCFile *)file;
- (BOOL)uploadPath:(NSString *)path toFolder:(WCFile *)destination;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)remove:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)revealInFiles:(id)sender;

@end
