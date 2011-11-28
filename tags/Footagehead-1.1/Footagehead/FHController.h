/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

@class FHSplitView, FHBrowserView, FHImageView, FHFullscreenWindow;
@class FHSettings, FHCache, FHHandler, FHFile;

@interface FHController : NSWindowController {
	IBOutlet FHSplitView			*_splitView;
	IBOutlet NSScrollView			*_browserScrollView;
	IBOutlet FHBrowserView			*_browserView;
	IBOutlet NSScrollView			*_imageScrollView;
	IBOutlet NSImageView			*_imageView;
	
	IBOutlet NSPopUpButton			*_menu;
	IBOutlet NSButton				*_revealInFinderButton;
	IBOutlet NSButton				*_moveToTrashButton;
	IBOutlet NSProgressIndicator	*_progressIndicator;

	IBOutlet NSTextField            *_leftStatusTextField;
	IBOutlet NSTextField            *_rightStatusTextField;

	IBOutlet NSPanel				*_fullscreenPanel;
	IBOutlet FHImageView			*_fullscreenImageView;
	
	IBOutlet NSPanel				*_screenPanel;
	IBOutlet NSPopUpButton			*_screenPopUpButton;
	IBOutlet NSButton				*_screenAutoSwitchButton;
	IBOutlet NSTextField			*_screenAutoSwitchTextField;

	IBOutlet NSPanel				*_openURLPanel;
	IBOutlet NSTextView				*_openURLTextView;
	IBOutlet NSMatrix				*_openURLExtractMatrix;

	FHSettings						*_settings;
	FHCache							*_cache;

	FHFullscreenWindow				*_fullscreenWindow;
	FHHandler						*_handler;
	FHFile							*_file;
	
	BOOL							_openLast;
	int								_items;
	int								_spinners;
}


#define								FHFileKey				@"FHFileKey"
#define								FHImageKey				@"FHImageKey"


- (IBAction)						open:(id)sender;
- (IBAction)						openURL:(id)sender;
- (void)							openFile:(FHFile *)file;
- (IBAction)						openParent:(id)sender;
- (IBAction)						openMenu:(id)sender;

- (IBAction)						reload:(id)sender;
- (IBAction)						slideshow:(id)sender;
- (IBAction)						slideshowButtons:(id)sender;
- (IBAction)						revealInFinder:(id)sender;
- (IBAction)						delete:(id)sender;

- (IBAction)						submitSheet:(id)sender;
- (IBAction)						cancelSheet:(id)sender;

- (FHBrowserView *)					browserView;
- (FHHandler *)						handler;
- (FHImageView *)					fullscreenImageView;

- (void)							startSlideshow;
- (void)							selectRow:(int)row;
- (void)							loadImage:(FHFile *)file;

- (void)							startSpinning;
- (void)							stopSpinning;
- (void)							update;
- (void)							updateButtons;
- (void)							updateVolumes;
- (void)							updateMenu;
- (void)							updateStatus;

@end
