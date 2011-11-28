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

#import "SPAppleRemote.h"
#import "SPPS3Remote.h"
#import "SPWiiRemote.h"

extern NSString * const			SPSpiralErrorDomain;


enum _SPSpiralError {
	SPSpiralExportFailed,
};


@class SPMovieController, SPPlaylistFile;

@interface SPApplicationController : WIObject <SPAppleRemoteDelegate, SPPS3RemoteDelegate, SPWiiRemoteDelegate> {
	IBOutlet NSMenu				*_chaptersMenu;
	IBOutlet NSMenu				*_audioTrackMenu;
	IBOutlet NSMenu				*_subtitleTrackMenu;
	IBOutlet NSMenu				*_aspectRatioMenu;
	
	IBOutlet NSMenu				*_playlistMenu;
	IBOutlet NSMenuItem			*_shuffleMenuItem;
	IBOutlet NSMenuItem			*_repeatOffMenuItem;
	IBOutlet NSMenuItem			*_repeatAllMenuItem;
	IBOutlet NSMenuItem			*_repeatOneMenuItem;
	
	IBOutlet NSPanel			*_aboutPanel;
	IBOutlet NSTextField		*_aboutNameTextField;
	IBOutlet NSTextField		*_aboutVersionTextField;
	IBOutlet NSTextView			*_aboutCreditsTextView;
	IBOutlet NSTextField		*_aboutCopyrightTextField;
	
	IBOutlet SUUpdater			*_updater;
	
	BOOL						_activated;

	BOOL						_holdingAppleRemoteButton;
	BOOL						_holdingPS3RemoteButton;
	BOOL						_holdingWiiRemoteButton;
}

+ (SPApplicationController *)applicationController;

- (SPMovieController *)keyMovieController;

- (BOOL)openFile:(NSString *)path withPlaylistFile:(SPPlaylistFile *)file;
- (BOOL)openFile:(NSString *)path withPlaylistFile:(SPPlaylistFile *)file resumePlaying:(BOOL)resumePlaying enterFullscreen:(BOOL)enterFullscreen;

- (IBAction)about:(id)sender;
- (IBAction)preferences:(id)sender;

- (IBAction)openFile:(id)sender;

- (IBAction)export:(id)sender;

- (IBAction)fullscreen:(id)sender;
- (IBAction)browseInFullscreen:(id)sender;
- (IBAction)shuffle:(id)sender;
- (IBAction)repeatMode:(id)sender;

- (IBAction)playlist:(id)sender;
- (IBAction)inspector:(id)sender;

- (IBAction)releaseNotes:(id)sender;
- (IBAction)crashReports:(id)sender;

@end
