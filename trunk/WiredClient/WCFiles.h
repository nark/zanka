/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "WCFilesController.h"

@class WCFile;

@interface WCFiles : WCFilesController {
	IBOutlet NSTabView				*_filesTabView;

	IBOutlet NSBrowser				*_filesBrowser;

	IBOutlet NSPanel				*_createFolderPanel;
	IBOutlet NSTextField			*_createFolderTextField;
	IBOutlet NSPopUpButton			*_createFolderPopUpButton;

	IBOutlet NSMenu					*_titleBarMenu;

	IBOutlet NSButton				*_backButton;
	IBOutlet NSButton				*_forwardButton;
	IBOutlet NSMatrix				*_styleMatrix;
	IBOutlet NSButton				*_downloadButton;
	IBOutlet NSButton				*_uploadButton;
	IBOutlet NSButton				*_infoButton;
	IBOutlet NSButton				*_previewButton;
	IBOutlet NSButton				*_createFolderButton;
	IBOutlet NSButton				*_reloadButton;
	IBOutlet NSButton				*_deleteButton;

	NSUInteger						_type;
	
	NSMutableDictionary				*_allFiles;
	NSMutableArray					*_listFiles;
	NSMutableDictionary				*_browserFiles;
	
	WCFile							*_rootPath, *_listPath, *_browserPath;
	NSString						*_selectPath;

	NSMutableArray					*_history;
	NSUInteger						_historyPosition;
}


#define WCFilesShouldReload			@"WCFilesShouldReload"

#define WCFilePathKey				@"WCFilePathKey"
#define WCFileSelectPathKey			@"WCFileSelectPathKey"


+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path;
+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath;

- (IBAction)up:(id)sender;
- (IBAction)down:(id)sender;
- (IBAction)back:(id)sender;
- (IBAction)forward:(id)sender;
- (IBAction)list:(id)sender;
- (IBAction)browser:(id)sender;
- (IBAction)upload:(id)sender;
- (IBAction)preview:(id)sender;
- (IBAction)createFolder:(id)sender;
- (IBAction)reloadFiles:(id)sender;
- (IBAction)deleteFiles:(id)sender;

@end
