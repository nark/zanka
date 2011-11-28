/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

enum CPUApplicationIconStatus {
	CPUApplicationIconDefault,
	CPUApplicationIconResetDefault,
	CPUApplicationIconStandard,
	CPUApplicationIconExpanded,
};
typedef enum CPUApplicationIconStatus	CPUApplicationIconStatus;


@class CPUPanel, CPUFloatingView, CPUExpandedView;

@interface CPUController : NSObject {
	IBOutlet NSWindow					*_preferencesWindow;
	
	IBOutlet NSColorWell				*_floatingViewColorWell;
	IBOutlet NSMatrix					*_floatingViewAlphaMatrix;
	IBOutlet NSMatrix					*_floatingViewOrientationMatrix;
	
	IBOutlet NSColorWell				*_expandedViewSystemColorWell;
	IBOutlet NSColorWell				*_expandedViewUserColorWell;
	IBOutlet NSColorWell				*_expandedViewNiceColorWell;
	IBOutlet NSColorWell				*_expandedViewBackgroundColorWell;
	
	IBOutlet NSMatrix					*_applicationIconMatrix;
	
	IBOutlet NSPanel					*_standardPanel;
	IBOutlet NSBox						*_standardBox;
	IBOutlet NSImageView				*_standardBackgroundImageView;
	IBOutlet NSImageView				*_standardImageView;

	CPUPanel							*_floatingPanel;
	CPUFloatingView						*_floatingView;
	
	IBOutlet NSPanel					*_expandedPanel;
	IBOutlet CPUExpandedView			*_expandedView;
	
	NSArray								*_imageViews;
	
	NSImage								*_applicationIcon;
	CPUApplicationIconStatus			_applicationIconStatus;
}

- (IBAction)toggleFloatingWindow:(id)sender;

- (IBAction)clearExpandedWindow:(id)sender;

- (IBAction)openActivityMonitor:(id)sender;
- (IBAction)openTop:(id)sender;

- (IBAction)changeFloatingView:(id)sender;
- (IBAction)changeExpandedView:(id)sender;
- (IBAction)changeApplicationIcon:(id)sender;

- (IBAction)releaseNotes:(id)sender;

@end
