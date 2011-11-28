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
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
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

@class FHBrowserView, FHFullscreenWindow, FHImageView, FHSplitView;

@interface FHController : NSWindowController {
	IBOutlet FHSplitView			*_splitView;
	IBOutlet FHBrowserView			*_browserView;
	IBOutlet NSImageView			*_imageView;
	IBOutlet NSPopUpButton			*_menu;
    IBOutlet NSTextField            *_statusTextField;
	IBOutlet NSButton				*_revealInFinderButton;
	IBOutlet NSButton				*_moveToTrashButton;
	IBOutlet NSProgressIndicator	*_progressIndicator;

	IBOutlet NSPanel				*_fullscreenPanel;
	IBOutlet FHImageView			*_fullscreenImageView;
	
	IBOutlet NSPanel				*_openURLPanel;
	IBOutlet NSTextView				*_openURLTextView;

	FHFullscreenWindow				*_fullscreenWindow;
	NSString						*_name;
	BOOL							_openLast;
}



- (IBAction)						open:(id)sender;
- (IBAction)						openURL:(id)sender;
- (IBAction)						okOpenURL:(id)sender;
- (IBAction)						cancelOpenURL:(id)sender;

- (IBAction)						openParent:(id)sender;
- (IBAction)						slideshow:(id)sender;
- (IBAction)						revealInFinder:(id)sender;
- (IBAction)						delete:(id)sender;
- (IBAction)						menu:(id)sender;

- (void)							setImage:(NSImage *)image;
- (void)							setFullscreenImage:(NSImage *)image;
- (void)							setStatus:(NSString *)status;
- (void)							setFullscreenStatus:(NSString *)status;
- (void)							setImages:(NSMutableArray *)images;
- (NSMutableArray *)				images;

- (void)							startSpinning;
- (void)							stopSpinning;
- (void)							updateMenu:(NSURL *)url;
- (void)							updateFirstResponder;
- (void)							updateButtons:(BOOL)online;
- (void)							updateStatus:(NSString *)name;

@end
