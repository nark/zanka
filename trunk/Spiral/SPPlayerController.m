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

#import "SPApplicationController.h"
#import "SPFullscreenWindow.h"
#import "SPLCDSlider.h"
#import "SPMovieController.h"
#import "SPPlayerController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistController.h"
#import "SPQTMovieView.h"
#import "SPSettings.h"

static SPPlayerController			*SPPlayerControllerCurrentController;

@interface SPPlayerController(Private)

- (void)_adjustWindowFrame;
- (void)_adjustHUDWindowFrame;

@end


@implementation SPPlayerController(Private)

- (void)_adjustWindowFrame {
	NSSize		size, minSize;
	NSRect		frame, previousFrame, screenFrame, visibleFrame;
	SPScaling	scaling;
	CGFloat		heightDifference, aspectRatio;
	
	aspectRatio = [_movieController ratioForAspectRatio:[_movieController aspectRatio]];

	if([self window] == [_movieView window]) {
		previousFrame = frame		= [[self window] frame];
		heightDifference			= frame.size.height - [_movieView frame].size.height;
		
		if([_movieController naturalSize].width > 0.0) {
			screenFrame				= [[[self window] screen] frame];
			visibleFrame			= [[[self window] screen] visibleFrame];
			scaling					= [_movieController scaling];

			if(screenFrame.size.width - visibleFrame.size.width <= 10.0)
				visibleFrame.size.width = screenFrame.size.width;
		
			switch(scaling) {
				case SPCurrentSize:
					size			= [_movieController currentSize];
					break;
					
				case SPActualSize:
					size			= [_movieController naturalSize];
					break;
					
				case SPHalfSize:
					size			= [_movieController naturalSize];
					size.width		= floor(size.width  / 2.0);
					size.height		= floor(size.height / 2.0);
					break;
					
				case SPDoubleSize:
					size			= [_movieController naturalSize];
					size.width		= size.width  * 2.0;
					size.height		= size.height * 2.0;
					break;
					
				default:
					break;
			}
			
			if(scaling != SPFitToScreen) {
				if(size.width > visibleFrame.size.width || size.height > visibleFrame.size.height)
					scaling	= SPFitToScreen;
			}
			
			if(scaling == SPFitToScreen) {
				size				= [_movieController naturalSize];
				
				if(floor(visibleFrame.size.width / aspectRatio) + heightDifference < visibleFrame.size.height) {
					size.width		= visibleFrame.size.width;
					size.height		= floor(visibleFrame.size.width / aspectRatio) + heightDifference;
				} else {
					size.height		= visibleFrame.size.height;
					size.width		= floor((size.height - heightDifference) / (1.0 / aspectRatio));
				}
			} else {
				size.height			= floor(size.width / aspectRatio) + heightDifference;
			}
			
			minSize = [[self window] minSize];
			
			if(size.width < minSize.width) {
				size.width			= minSize.width;
				size.height			= floor(size.width / aspectRatio) + heightDifference;
			}
			else if(size.height < minSize.height) {
				size.height			= minSize.height;
				size.width			= floor((size.height - heightDifference) / (1.0 / aspectRatio));
			}

			if(size.width < minSize.width || size.height < minSize.height)
				size = minSize;
			
			frame.size = size;
			
			if(scaling == SPFitToScreen && _moveWindowWhenFittingToScreen/* && !kim*/) {
				frame.origin.x = visibleFrame.origin.x + floor((visibleFrame.size.width  - frame.size.width)  / 2.0);
				frame.origin.y = visibleFrame.origin.y + floor((visibleFrame.size.height - frame.size.height) / 2.0);
				
				_moveWindowWhenFittingToScreen = NO;
			} else {
				frame.origin.y -= frame.size.height - previousFrame.size.height;
			}
			
			_movingWindow = YES;
			[[self window] setFrame:frame display:YES animate:YES];
			_movingWindow = NO;
		} else {
			frame = [[self window] frame];
			frame.size.height = heightDifference;
			frame.origin.y -= frame.size.height - previousFrame.size.height;
			
			_movingWindow = YES;
			[[self window] setFrame:frame display:YES animate:YES];
			_movingWindow = NO;
		}
	} else {
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
}



- (void)_adjustHUDWindowFrame {
	NSRect		frame, screenFrame;
	
	screenFrame		= [[[self window] screen] frame];

	frame			= [_hudWindow frame];
	frame.origin.x	= screenFrame.origin.x + floor((screenFrame.size.width - frame.size.width) / 2.0);
	frame.origin.y	= screenFrame.origin.y + (0.2 * screenFrame.size.height);

	[_hudWindow setFrame:frame display:NO];
}

@end



@implementation SPPlayerController

+ (SPPlayerController *)currentPlayerController {
	return SPPlayerControllerCurrentController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Player"];
	
	[self window];

	SPPlayerControllerCurrentController = self;
	
	[self retain];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_overlayWindow release];
	[_hudWindow release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSRect		frame;
	
	[self setShouldCascadeWindows:YES];
	[self setShouldSaveWindowFrameOriginOnly:YES];
	[self setWindowFrameAutosaveName:@"Player"];
	
	_moveWindowWhenFittingToScreen = YES;

	frame.origin = [[self window] convertBaseToScreen:[_movieView frame].origin];
	frame.size = [_movieView frame].size;
	
	_overlayWindow = [[_movieController overlayWindow] retain];

	[_overlayWindow orderFront:self];
	[_overlayWindow setFrame:frame display:YES];
	[[self window] addChildWindow:_overlayWindow ordered:NSWindowAbove];
	[_movieController adjustOverlayWindow];
	
	_hudWindow = [[_movieController HUDWindow] retain];
	
	[self _adjustHUDWindowFrame];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerSizeChanged:)
			   name:SPMovieControllerSizeChangedNotification
			 object:_movieController];
}



- (void)windowWillClose:(NSNotification *)notification {
	if([notification object] == [self window]) {
		[_movieController stop];
		[_movieController setMovie:NULL playlistFile:NULL];
		[_movieController invalidate];
		
		SPPlayerControllerCurrentController = NULL;
		
		[self autorelease];
	} else {
		[_movieController stopFullscreen];
	}
}



- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)proposedSize {
	if(window != [self window] || _movingWindow)
		return proposedSize;
	
	if([_movieController naturalSize].width > 0.0) {
		[_movieController setScaling:SPCurrentSize];
		
		if([[NSApp currentEvent] shiftKeyModifier])
			return proposedSize;

		proposedSize.height = floor(proposedSize.width / [_movieController ratioForAspectRatio:[_movieController aspectRatio]]) +
			[[self window] frame].size.height - [_movieView frame].size.height;

		return proposedSize;
	}
	
	return NSMakeSize(proposedSize.width, [[self window] frame].size.height - [_movieView frame].size.height);
}



- (void)windowDidMove:(NSNotification *)notification {
	if([notification object] != [self window] || [[NSApp currentEvent] alternateKeyModifier] || _movingWindow)
		return;
	
	_movingWindow = YES;
	[[self window] snapToScreenEdgeAndDisplay:YES animate:YES];
	_movingWindow = NO;
}



- (void)windowDidResize:(NSNotification *)notification {
	NSRect		frame;
	
	if([notification object] == [self window]) {
		frame.origin = [[self window] convertBaseToScreen:[_movieView frame].origin];
		frame.size = [_movieView frame].size;
		[_overlayWindow setFrame:frame display:YES];
		[_movieController adjustOverlayWindow];
	}
}



- (BOOL)windowShouldClose:(id)window {
	return YES;
}



- (void)windowDidChangeScreen:(NSNotification *)notification {
	if([notification object] == [self window])
		[self _adjustHUDWindowFrame];
}



- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	NSTimeInterval	interval;
	unichar			key;
	
	if(control == _jumpToTimeTextField) {
		key = [[NSApp currentEvent] characterIgnoringModifiers];
		
		switch(key) {
			case NSLeftArrowFunctionKey:
			case NSRightArrowFunctionKey:
			case NSDownArrowFunctionKey:
			case NSUpArrowFunctionKey:
			case NSPageDownFunctionKey:
			case NSPageUpFunctionKey:
				interval = [SPMovieController timeIntervalForString:[_jumpToTimeTextField stringValue]] +
					[SPMovieController skipTimeIntervalForKey:key];
				
				if(interval < 0.0)
					interval = 0.0;
				
				if(interval > [_movieController duration])
					interval = [_movieController duration];
				
				[_jumpToTimeTextField setStringValue:[SPMovieController shortStringForTimeInterval:interval]];
				return YES;
				break;

			case NSEndFunctionKey:
				[_jumpToTimeTextField setStringValue:[SPMovieController shortStringForTimeInterval:0.0]];
				return YES;
				break;

			case NSHomeFunctionKey:
				[_jumpToTimeTextField setStringValue:[SPMovieController shortStringForTimeInterval:[_movieController duration]]];
				return YES;
				break;
		}
	}
			
	return NO;
}



- (BOOL)movieController:(SPMovieController *)movieController shouldOpenFile:(SPPlaylistFile *)file {
	return [[SPApplicationController applicationController] openFile:[file resolvedPath] withPlaylistFile:file];
}



- (void)movieControllerSizeChanged:(NSNotification *)notification {
	if(![[NSApp currentEvent] shiftKeyModifier])
		[self _adjustWindowFrame];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	return [_movieController validateMenuItem:item];
}



#pragma mark -

- (SPMovieController *)movieController {
	return _movieController;
}



#pragma mark -

- (void)setMovie:(QTMovie *)movie playlistFile:(SPPlaylistFile *)file {
	[[self movieController] setMovie:movie playlistFile:file];
	
	[self _adjustWindowFrame];
}



#pragma mark -

- (IBAction)scaling:(id)sender {
	[_movieController scaling:sender];
}



- (IBAction)fullscreen:(id)sender {
	if(!_fullscreenWindow) {
		[[self window] setAlphaValue:0.0];
		
		_fullscreenWindow = [[SPFullscreenWindow alloc] initWithScreen:[[self window] screen]];
		[_fullscreenWindow setHUDWindow:_hudWindow],
		[_fullscreenWindow setReleasedWhenClosed:YES];
		[_fullscreenWindow setDelegate:self];
		[_fullscreenWindow setAnimates:YES];
		
		[[self window] removeChildWindow:_overlayWindow];
		[_fullscreenWindow addChildWindow:_overlayWindow ordered:NSWindowAbove];
		
		[_movieView retain];
		[_movieView removeFromSuperview];
		[[_fullscreenWindow contentView] addSubview:_movieView];
		[_fullscreenWindow makeFirstResponder:_movieView];
		_movieViewFrame = [_movieView frame];
		[_movieView release];
		
		[_movieController startFullscreenInWindow:_fullscreenWindow delegate:self didEndSelector:@selector(movieControllerFullscreenDidEnd:)];

		[self _adjustWindowFrame];
		[_fullscreenWindow makeKeyAndOrderFront:self];
	} else {
		[_fullscreenWindow performClose:self];
	}
}



- (void)movieControllerFullscreenDidEnd:(SPFullscreenWindow *)window {
	NSRect		frame;
	
	[_hudWindow close];
	
	frame.origin = [[self window] convertBaseToScreen:_movieViewFrame.origin];
	frame.size = _movieViewFrame.size;

	[window removeChildWindow:_overlayWindow];
	[_overlayWindow setFrame:frame display:YES];
	[[self window] addChildWindow:_overlayWindow ordered:NSWindowAbove];
	[_movieController adjustOverlayWindow];
	
	[_movieView retain];
	[_movieView removeFromSuperview];
	[_movieView setFrame:_movieViewFrame];
	[[[self window] contentView] addSubview:_movieView];
	[[self window] makeFirstResponder:_movieView];
	[_movieView release];
	
	[self _adjustWindowFrame];
	
	[[self window] setAlphaValue:1.0];

	_fullscreenWindow = NULL;
}



- (IBAction)snapshot:(id)sender {
	[_movieController snapshot:sender];
}



- (IBAction)jumpToTime:(id)sender {
	[_jumpToTimeTextField setStringValue:[SPMovieController shortStringForTimeInterval:[_movieController currentTime]]];
	
	[NSApp beginSheet:_jumpToTimePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(jumpToTimeSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)jumpToTimeSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSTimeInterval		interval;
	
	if(returnCode == NSOKButton) {
		interval = [SPMovieController timeIntervalForString:[_jumpToTimeTextField stringValue]];

		[_movieController setCurrentTime:WIClamp(interval, 0.0, [_movieController duration])];
	}
	
	[sheet close];
}



- (IBAction)chapter:(id)sender {
	[_movieController chapter:sender];
}



- (IBAction)audioTrack:(id)sender {
	[_movieController audioTrack:sender];
}



- (IBAction)subtitleTrack:(id)sender {
	[_movieController subtitleTrack:sender];
}



- (IBAction)aspectRatio:(id)sender {
	[_movieController aspectRatio:sender];
}



- (IBAction)previous:(id)sender {
	[_movieController previous:sender];
}



- (IBAction)next:(id)sender {
	[_movieController next:sender];
}



- (IBAction)revealInFinder:(id)sender {
    [[NSWorkspace sharedWorkspace] selectFile:[[self window] representedFilename] inFileViewerRootedAtPath:NULL];
}

@end
