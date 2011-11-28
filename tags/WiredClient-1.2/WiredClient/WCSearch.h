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
#import "WCTableView.h"

@class WCTableView, WCConnection;

@protocol WCGetInfoValidatio;

@interface WCSearch : WCWindowController <WCGetInfoValidation, WCTableViewSelectOptions> {
	IBOutlet WCTableView				*_searchTableView;
	
	IBOutlet NSPanel					*_viewOptionsPanel;
	
	IBOutlet NSTextField				*_searchTextField;
	IBOutlet NSPopUpButton				*_kindPopUpButton;

	IBOutlet NSTextField				*_statusTextField;
	IBOutlet NSProgressIndicator		*_progressIndicator;

	IBOutlet NSMenuItem					*_openMenuItem;
	IBOutlet NSMenuItem					*_downloadMenuItem;
	IBOutlet NSMenuItem					*_getInfoMenuItem;
	IBOutlet NSMenuItem					*_revealInFilesMenuItem;

	NSMutableArray						*_allFiles, *_shownFiles;
	NSMutableDictionary					*_iconPool;

	NSImage								*_folderImage, *_uploadsImage, *_dropBoxImage;
	
	NSArray								*_audioExtensions, *_imageExtensions, *_movieExtensions;
	
	NSImage								*_sortUpImage, *_sortDownImage;
	NSTableColumn						*_lastTableColumn;
	BOOL								_sortDescending;
}


enum WCSearchType {
	WCSearchTypeAny					= 0,
	WCSearchTypeFolder,
	WCSearchTypeDocument,
	WCSearchTypeAudio,
	WCSearchTypeImage,
	WCSearchTypeMovie
};


#define WCSearchShouldAddFile			@"WCSearchShouldAddFile"
#define WCSearchShouldCompleteFiles		@"WCSearchShouldCompleteFiles"

#define WCSearchTypeAudioExtensions		@"aif aiff au mid midi mp3 mp4 wav"
#define WCSearchTypeImageExtensions		@"bmp ico eps jpg jpeg tif tiff gif pict pct png psd sgi tga"
#define WCSearchTypeMovieExtensions		@"avi dv flash mp4 mpg mpg4 mpeg mov rm swf wvm"


- (id)									initWithConnection:(WCConnection *)connection;

- (void)								update;

- (IBAction)							search:(id)sender;
- (IBAction)							open:(id)sender;
- (IBAction)							download:(id)sender;
- (IBAction)							info:(id)sender;
- (IBAction)							revealInFiles:(id)sender;

@end
