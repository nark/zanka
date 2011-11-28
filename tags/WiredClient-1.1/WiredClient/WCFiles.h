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

#import "WCWindowController.h"

@class WCConnection, WCFile;

@protocol WCGetInfoValidation, WCTableViewInfoCopying, WCTableViewOptionsSelection;

@interface WCFiles : WCWindowController <WCGetInfoValidation, WCTableViewInfoCopying, WCTableViewOptionsSelection> {
	IBOutlet NSTableView			*_filesTableView;
	IBOutlet NSScrollView			*_filesScrollView;

	IBOutlet NSPanel				*_newFolderPanel;
	IBOutlet NSTextField			*_newFolderTextField;

	IBOutlet NSPanel				*_viewOptionsPanel;

	IBOutlet NSButton				*_backButton;
	IBOutlet NSButton				*_forwardButton;
	IBOutlet NSButton				*_downloadButton;
	IBOutlet NSButton				*_uploadButton;
	IBOutlet NSButton				*_infoButton;
	IBOutlet NSButton				*_previewButton;
	IBOutlet NSButton				*_newFolderButton;
	IBOutlet NSButton				*_reloadButton;
	IBOutlet NSButton				*_deleteButton;

	IBOutlet NSTextField			*_statusTextField;
	IBOutlet NSProgressIndicator	*_progressIndicator;
	
	IBOutlet NSMenuItem				*_downloadMenuItem;
	IBOutlet NSMenuItem				*_getInfoMenuItem;
	IBOutlet NSMenuItem				*_deleteMenuItem;
	
	NSMutableArray					*_allFiles, *_shownFiles;
	WCFile							*_path, *_selection;
	
	NSImage							*_folderIcon, *_uploadsIcon, *_dropBoxIcon;

	NSMutableArray					*_pathHistory;
	unsigned int					_currentPath;
	
	NSImage							*_sortUpImage, *_sortDownImage;
	NSTableColumn					*_lastTableColumn;
	BOOL							_sortDescending;
}


#define								WCFilesShouldAddFile			@"WCFilesShouldAddFile"
#define								WCFilesShouldCompleteFiles		@"WCFilesShouldCompleteFiles"
#define								WCFilesShouldReload				@"WCFilesShouldReload"

#define								WCDragFile						@"WCDragFile"


- (id)								initWithConnection:(WCConnection *)connection path:(WCFile *)path;
- (id)								initWithConnection:(WCConnection *)connection path:(WCFile *)path select:(WCFile *)select;

- (void)							updateFiles;
- (void)							changeDirectory:(WCFile *)path;
- (void)							updateButtons;

- (BOOL)							canMoveBack;
- (BOOL)							canMoveForward;
- (BOOL)							canUpload;
- (BOOL)							canDeleteFiles;
- (BOOL)							canCreateFolders;
	
- (IBAction)						back:(id)sender;
- (IBAction)						forward:(id)sender;
- (IBAction)						download:(id)sender;
- (IBAction)						upload:(id)sender;
- (IBAction)						info:(id)sender;
- (IBAction)						preview:(id)sender;
- (IBAction)						newFolder:(id)sender;
- (IBAction)						reload:(id)sender;
- (IBAction)						delete:(id)sender;

@end
