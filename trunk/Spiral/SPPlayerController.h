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

@class SPMovieController, SPQTMovieView, SPFullscreenWindow, SPPlaylistFile;

@interface SPPlayerController : WIWindowController {
	IBOutlet SPMovieController			*_movieController;
	IBOutlet SPQTMovieView				*_movieView;
	
	IBOutlet NSPanel					*_jumpToTimePanel;
	IBOutlet NSTextField				*_jumpToTimeTextField;
	
	SPFullscreenWindow					*_fullscreenWindow;
	NSWindow							*_overlayWindow;
	NSWindow							*_hudWindow;
	
	NSRect								_movieViewFrame;
	BOOL								_movingWindow;
	BOOL								_moveWindowWhenFittingToScreen;
}

+ (SPPlayerController *)currentPlayerController;
- (SPMovieController *)movieController;

- (void)setMovie:(QTMovie *)movie playlistFile:(SPPlaylistFile *)file;

- (IBAction)scaling:(id)sender;
- (IBAction)fullscreen:(id)sender;
- (IBAction)snapshot:(id)sender;
- (IBAction)chapter:(id)sender;
- (IBAction)audioTrack:(id)sender;
- (IBAction)subtitleTrack:(id)sender;
- (IBAction)aspectRatio:(id)sender;
- (IBAction)previous:(id)sender;
- (IBAction)next:(id)sender;
- (IBAction)revealInFinder:(id)sender;

@end
