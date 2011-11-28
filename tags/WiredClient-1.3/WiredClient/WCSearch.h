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

enum WCSearchType {
	WCSearchTypeAny,
	WCSearchTypeFolder,
	WCSearchTypeDocument,
	WCSearchTypeAudio,
	WCSearchTypeImage,
	WCSearchTypeMovie
};
typedef enum WCSearchType				WCSearchType;


@class WCFile;

@interface WCSearch : WCConnectionController {
	IBOutlet WITableView				*_searchTableView;
	IBOutlet NSTableColumn				*_nameTableColumn;
	IBOutlet NSTableColumn				*_kindTableColumn;
	IBOutlet NSTableColumn				*_createdTableColumn;
	IBOutlet NSTableColumn				*_modifiedTableColumn;
	IBOutlet NSTableColumn				*_sizeTableColumn;
	
	IBOutlet NSTextField				*_searchTextField;
	IBOutlet NSPopUpButton				*_kindPopUpButton;
	IBOutlet NSButton					*_searchButton;

	IBOutlet NSTextField				*_statusTextField;
	IBOutlet NSProgressIndicator		*_progressIndicator;

	IBOutlet NSMenuItem					*_openMenuItem;
	IBOutlet NSMenuItem					*_downloadMenuItem;
	IBOutlet NSMenuItem					*_getInfoMenuItem;
	IBOutlet NSMenuItem					*_revealInFilesMenuItem;

	NSMutableArray						*_allFiles, *_shownFiles;

	NSImage								*_folderImage, *_uploadsImage, *_dropBoxImage;
}


+ (id)searchWithConnection:(WCServerConnection *)connection;

- (IBAction)search:(id)sender;
- (IBAction)open:(id)sender;
- (IBAction)download:(id)sender;
- (IBAction)getInfo:(id)sender;
- (IBAction)revealInFiles:(id)sender;

@end
