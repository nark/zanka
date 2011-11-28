/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "SPExportJob.h"
#import "SPPlaylistLoader.h"

extern NSString * const					SPPlaylistControllerSettingsChangedNotification;
extern NSString * const					SPPlaylistControllerSelectionDidChangeNotification;
extern NSString * const					SPPlaylistControllerLoadProgressChangedNotification;

enum _SPPlaylistRepeatMode {
	SPPlaylistRepeatOff					= 0,
	SPPlaylistRepeatAll,
	SPPlaylistRepeatOne
};
typedef enum _SPPlaylistRepeatMode		SPPlaylistRepeatMode;


@class SPFullscreenWindow, SPPlaylistGroup, SPPlaylistFile, SPPlaylistLoader;

@interface SPPlaylistController : WIWindowController <SPPlaylistLoaderDelegate, SPExportJobDelegate> {
	IBOutlet WIOutlineView				*_outlineView;
	IBOutlet NSTableColumn				*_filesTableColumn;
	IBOutlet NSTableColumn				*_IMDbTableColumn;
	IBOutlet NSTableColumn				*_viewCountTableColumn;
	IBOutlet NSTableColumn				*_sizeTableColumn;
	IBOutlet NSTableColumn				*_timeTableColumn;
	IBOutlet NSTableColumn				*_dimensionsTableColumn;
	
	IBOutlet NSPopUpButton				*_actionPopUpButton;
	IBOutlet NSButton					*_removeButton;
	IBOutlet NSButton					*_repeatButton;
	IBOutlet NSButton					*_shuffleButton;
	
	IBOutlet NSProgressIndicator		*_progressIndicator;
	
	IBOutlet NSTextField				*_statusTextField;
	
	IBOutlet NSSearchField				*_searchField;
	
	IBOutlet NSPanel					*_smartGroupPanel;
	IBOutlet NSTextField				*_smartGroupNameTextField;
	IBOutlet NSPredicateEditor			*_predicateEditor;
	
	IBOutlet NSPanel					*_exportGroupPanel;
	IBOutlet NSTextField				*_exportGroupNameTextField;
	IBOutlet NSPopUpButton				*_exportGroupFormatPopUpButton;
	IBOutlet NSPopUpButton				*_exportGroupDestinationPopUpButton;
	IBOutlet NSMenuItem					*_exportGroupSameAsOriginalMenuItem;
	IBOutlet NSMenuItem					*_exportGroupiTunesMenuItem;
	IBOutlet NSMenuItem					*_exportGroupDirectoryMenuItem;
	
	IBOutlet NSPanel					*_IMDbURLPanel;
	IBOutlet NSTextField				*_IMDbURLTextField;
	IBOutlet NSTextField				*_IMDbURLInvalidTextField;
	
	SPPlaylistGroup						*_playlist;
	NSMutableDictionary					*_representedFiles;
	NSLock								*_representedFilesLock;
	
	SPPlaylistLoader					*_loader;
	
	NSMutableArray						*_exports;
	NSMutableArray						*_exportQueue;

	SPPlaylistRepeatMode				_repeatMode;
	NSMutableDictionary					*_eventQueueItems;
	BOOL								_shuffle;
	BOOL								_simplifyFilenames;
	NSUInteger							_spinners;
	NSUInteger							_restoring;
}

+ (SPPlaylistController *)playlistController;

- (void)save;

- (SPPlaylistGroup *)playlist;

- (SPPlaylistFile *)fileForPath:(NSString *)path;
- (SPPlaylistRepresentedFile *)representedFileForPath:(NSString *)path;
- (void)addRepresentedFile:(SPPlaylistRepresentedFile *)file;

- (void)setRepeatMode:(SPPlaylistRepeatMode)repeatMode;
- (SPPlaylistRepeatMode)repeatMode;
- (void)setShuffle:(BOOL)shuffle;
- (BOOL)shuffle;

- (NSUInteger)numberOfExports;
- (void)stopAllExports;

- (void)openSelection;
- (void)closeSelection;
- (void)moveSelectionDown;
- (void)moveSelectionUp;

- (IBAction)open:(id)sender;
- (IBAction)addFile:(id)sender;
- (IBAction)newGroup:(id)sender;
- (IBAction)newSmartGroup:(id)sender;
- (IBAction)newExportGroup:(id)sender;
- (IBAction)format:(id)sender;
- (IBAction)destination:(id)sender;
- (IBAction)remove:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)repeat:(id)sender;
- (IBAction)shuffle:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)selectIMDbURL:(id)sender;
- (IBAction)fullscreen:(id)sender;
- (IBAction)browseInFullscreen:(id)sender;

- (SPPlaylistFile *)previousFileForFile:(SPPlaylistFile *)file;
- (SPPlaylistFile *)nextFileForFile:(SPPlaylistFile *)file;
- (SPPlaylistFile *)firstFileForFile:(SPPlaylistFile *)file;
- (SPPlaylistFile *)lastFileForFile:(SPPlaylistFile *)file;
- (SPPlaylistFile *)selectedFile;

@end
