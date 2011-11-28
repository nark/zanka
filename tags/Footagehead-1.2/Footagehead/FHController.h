/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

@class FHImageView, FHFullscreenWindow;
@class FHHandler, FHFile;

@interface FHController : WIWindowController {
	IBOutlet NSMenuItem				*_openSpotlightMenuItem;
	
	IBOutlet WISplitView			*_splitView;
	IBOutlet NSView					*_leftView;
	IBOutlet WITableView			*_tableView;
	IBOutlet NSTableColumn			*_fileTableColumn;
	IBOutlet NSView					*_rightView;
	IBOutlet FHImageView			*_imageView;
	IBOutlet NSScrollView			*_scrollView;
	
	IBOutlet NSButton				*_zoomButton;
	IBOutlet NSButton				*_revealInFinderButton;
	IBOutlet NSButton				*_moveToTrashButton;
	IBOutlet NSProgressIndicator	*_progressIndicator;
	IBOutlet NSPopUpButton			*_menu;

	IBOutlet NSTextField            *_leftStatusTextField;
	IBOutlet NSTextField            *_rightStatusTextField;

	IBOutlet NSPanel				*_fullscreenPanel;
	IBOutlet FHImageView			*_fullscreenImageView;
	
	IBOutlet NSPanel				*_screenPanel;
	IBOutlet NSPopUpButton			*_screenPopUpButton;
	IBOutlet NSPopUpButton			*_screenBackgroundPopUpButton;
	IBOutlet NSButton				*_screenAutoSwitchButton;
	IBOutlet NSTextField			*_screenAutoSwitchTextField;

	IBOutlet NSPanel				*_openURLPanel;
	IBOutlet NSTextView				*_openURLTextView;

	IBOutlet NSPanel				*_openSpotlightPanel;
	IBOutlet NSTextView				*_openSpotlightTextView;

	FHFullscreenWindow				*_fullscreenWindow;
	FHHandler						*_handler;
	
	NSTimer							*_loadImageTimer;
	NSConditionLock					*_loadImageLock;
	NSConditionLock					*_loadThumbnailsLock;
	unsigned int					_selectedRow;
	unsigned int					_imageCounter;
	unsigned int					_thumbnailsCounter;
	
	WIEventQueue					*_queue;
	
	NSSize							_lastTableViewSize;
	
	BOOL							_openLastURL;
	BOOL							_switchingURL;
	unsigned int					_spinners;
	unsigned int					_menuItems;
}


+ (FHController *)controller;

- (IBAction)open:(id)sender;
- (IBAction)openURL:(id)sender;
- (IBAction)openSpotlight:(id)sender;
- (IBAction)openParent:(id)sender;
- (IBAction)openMenu:(id)sender;
- (IBAction)openFile:(id)sender;
- (IBAction)firstFile:(id)sender;
- (IBAction)lastFile:(id)sender;
- (IBAction)previousImage:(id)sender;
- (IBAction)nextImage:(id)sender;
- (IBAction)previousPage:(id)sender;
- (IBAction)nextPage:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)zoom:(id)sender;
- (IBAction)rotateRight:(id)sender;
- (IBAction)rotateLeft:(id)sender;
- (IBAction)slideshow:(id)sender;
- (IBAction)autoSwitch:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)setAsDesktopPicture:(id)sender;
- (IBAction)delete:(id)sender;

@end
