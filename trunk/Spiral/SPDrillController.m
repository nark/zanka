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

#import "SPDrillController.h"
#import "SPDrillView.h"
#import "SPFullscreenWindow.h"
#import "SPInspectorController.h"
#import "SPMovieController.h"
#import "SPPlaylistController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistLoader.h"
#import "SPPreferencesController.h"
#import "SPQTMovieView.h"
#import "SPSettings.h"

@interface SPDrillController(Private)

- (void)_adjustWindowFrame;

@end


@implementation SPDrillController(Private)

- (void)_adjustWindowFrame {
	NSSize		size;
	NSRect		frame, visibleFrame;
	CGFloat		aspectRatio;
	
	aspectRatio			= [_movieController ratioForAspectRatio:[_movieController aspectRatio]];
	visibleFrame		= [[_movieView window] frame];
	size				= [_movieController naturalSize];
	
	if(visibleFrame.size.width / size.width < visibleFrame.size.height / floor(size.width / aspectRatio)) {
		size.width		= visibleFrame.size.width;
		size.height		= floor(size.width / aspectRatio);
	} else {
		size.height		= visibleFrame.size.height;
		size.width		= floor(size.height / (1.0 / aspectRatio));
	}
	
	frame.size			= size;
	frame.origin.x		= floor((visibleFrame.size.width  - frame.size.width)  / 2.0);
	frame.origin.y		= floor((visibleFrame.size.height - frame.size.height) / 2.0);
	
	[_movieView setFrame:frame];
	[_overlayWindow setFrame:frame display:YES];
	[_movieController adjustOverlayWindow];
	[[_movieView window] display];
}

@end



@implementation SPDrillController

+ (SPDrillController *)drillController {
	static SPDrillController		*drillController;
	
	if(!drillController)
		drillController = [[self alloc] init];
	
	return drillController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Drill"];
	
	_loader = [[SPPlaylistLoader alloc] init];
	[_loader setDelegate:self];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:SPPreferencesDidChangeNotification];

	[self window];
	
	return self;
}



- (void)dealloc {
	[_movieView release];
	[_drillContentView release];
	[_loader release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	SPFullscreenWindow	*window;
	NSRect				frame, screenFrame;
	
	window = [[SPFullscreenWindow alloc] initWithScreen:[NSScreen mainScreen]];
	[window setDelegate:self];
	[window setReleasedWhenClosed:NO];
	[window setContentView:[[self window] contentView]];
	[window setAnimates:YES];
	[self setWindow:window];
	
	_overlayWindow = [[_movieController overlayWindow] retain];
	[_overlayWindow orderFront:self];
	[_overlayWindow setFrame:[[self window] frame] display:YES];
	[window addChildWindow:_overlayWindow ordered:NSWindowAbove];
	
	_hudWindow = [[_movieController HUDWindow] retain];
	frame = [_hudWindow frame];
	screenFrame = [[[self window] screen] frame];
	frame.origin.x = floor((screenFrame.size.width - frame.size.width) / 2.0);
	frame.origin.y = 0.2 * screenFrame.size.height;
	[_hudWindow setFrame:frame display:NO];
	[window release];
	
	[_movieView retain];
	[_drillContentView retain];
	
	[_drillView setSimplifyFilenames:[[SPSettings settings] boolForKey:SPSimplifyFilenames]];
	[_drillView setPlaylist:[[SPPlaylistController playlistController] playlist]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerSizeChanged:)
			   name:SPMovieControllerSizeChangedNotification
			 object:_movieController];
}



- (BOOL)windowShouldClose:(id)window {
	if([_movieController isInFullscreen]) {
		[_movieController stopFullscreen];
		
		return NO;
	}
	
	return YES;
}



- (void)windowWillClose:(NSNotification *)notification {
	[_hudWindow orderOut:self];
	
	if(_inspectorWasVisible)
		[[[[SPInspectorController inspectorController] window] animator] setAlphaValue:1.0];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[_drillView setSimplifyFilenames:[[SPSettings settings] boolForKey:SPSimplifyFilenames]];
}



- (void)drillView:(SPDrillView *)drillView willOpenContainer:(id)container {
	if([container isKindOfClass:[SPPlaylistFolder class]])
		[_loader loadContentsOfFolder:container synchronously:YES];
	else if([container isKindOfClass:[SPPlaylistSmartGroup class]])
		[_loader loadSmartGroup:container synchronously:YES];
}



- (void)drillView:(SPDrillView *)drillView shouldOpenFile:(SPPlaylistFile *)file {
	QTMovie		*movie;
	NSError		*error;
	
	movie = [QTMovie movieWithFile:[file resolvedPath] error:&error];

	if(!movie)
		return;
	
	[[self window] setContentView:_movieView];
	[[self window] makeFirstResponder:_movieView];
	[[self window] display];
	[(SPFullscreenWindow *) [self window] setHUDWindow:_hudWindow];
	
	[_movieController setMovie:movie playlistFile:file];
	[_movieController startFullscreenInWindow:(SPFullscreenWindow *) [self window]
									 delegate:self
							   didEndSelector:@selector(movieControllerFullscreenDidEnd:)];
	[self _adjustWindowFrame];
	[_movieController resumePlaying];
	[_movieController playWhenTracksAreLoaded];
}



- (BOOL)movieController:(SPMovieController *)movieController shouldOpenFile:(SPPlaylistFile *)file {
	QTMovie		*movie;
	NSError		*error;
	
	movie = [QTMovie movieWithFile:[file resolvedPath] error:&error];
	
	if(!movie)
		return NO;

	[_movieController setMovie:movie playlistFile:file];
	[self _adjustWindowFrame];
	[_movieController playWhenTracksAreLoaded];
	
	return YES;
}



- (void)movieControllerSizeChanged:(NSNotification *)notification {
	[self _adjustWindowFrame];
}



- (void)movieControllerFullscreenDidEnd:(SPFullscreenWindow *)window {
	[_movieController stop];
	[_movieController setMovie:NULL playlistFile:NULL];
	
	[[self window] setContentView:_drillContentView];
	[[self window] makeFirstResponder:_drillView];
	[(SPFullscreenWindow *) [self window] setHUDWindow:NULL];
	[_hudWindow orderOut:self];
	
	[_drillView reloadDataAndSelectPlaylistFile:[_movieController playlistFile]];
}



#pragma mark -

- (void)showWindow:(id)sender {
	_inspectorWasVisible = [[[SPInspectorController inspectorController] window] isVisible];
	
	[[[[SPInspectorController inspectorController] window] animator] setAlphaValue:0.0];
	
	[_drillView reloadDataAndSelectPlaylistFile:[_movieController playlistFile]];

	[super showWindow:sender];
	
	[[self window] makeFirstResponder:_drillView];
}



- (SPMovieController *)movieController {
	return _movieController;
}



#pragma mark -

- (void)openSelection {
	[_drillView openSelection];
}



- (void)closeSelection {
	[_drillView closeSelection];
}



- (void)closeWindow {
	if([_movieController isInFullscreen])
		[_movieController stopFullscreen];
	else
		[[self window] performClose:self];
}



- (void)moveSelectionDown {
	[_drillView moveSelectionDown];
}



- (void)moveSelectionUp {
	[_drillView moveSelectionUp];
}



#pragma mark -

- (IBAction)fullscreen:(id)sender {
	[self browseInFullscreen:sender];
}



- (IBAction)browseInFullscreen:(id)sender {
	[_movieController stopFullscreen];

	[[self window] performClose:self];
}

@end
