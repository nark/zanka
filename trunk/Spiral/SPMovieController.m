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

#import "QTTrack-SPAdditions.h"
#import "SPFullscreenWindow.h"
#import "SPLCDSlider.h"
#import "SPMovieController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistController.h"
#import "SPQTMovieView.h"
#import "SPSettings.h"
#import "SPShortcutTextField.h"

NSString * const SPMovieControllerOpenedMovieNotification					= @"SPMovieControllerOpenedMovieNotification";
NSString * const SPMovieControllerClosedMovieNotification					= @"SPMovieControllerClosedMovieNotification";
NSString * const SPMovieControllerViewCountChangedNotification				= @"SPMovieControllerViewCountChangedNotification";
NSString * const SPMovieControllerSizeChangedNotification					= @"SPMovieControllerSizeChangedNotification";
NSString * const SPMovieControllerAttributesChangedNotification				= @"SPMovieControllerAttributesChangedNotification";
NSString * const SPMovieControllerInteractiveAttributesChangedNotification	= @"SPMovieControllerInteractiveAttributesChangedNotification";
NSString * const SPMovieControllerLoadProgressChangedNotification			= @"SPMovieControllerLoadProgressChangedNotification";


@interface SPMovieController(Private)

+ (NSDictionary *)_overlayStringAttributesForTextField:(NSTextField *)textField;
- (CGFloat)_overlayViewHeight;
- (void)_adjustOverlayTextFields;
- (void)_adjustOverlayImageView;
- (void)_showStatusOverlayForSkipTimeInterval:(NSTimeInterval)timeInterval;
- (void)_flashOverlayString:(NSString *)string textField:(NSTextField *)textField;
- (void)_setOverlayString:(NSString *)string textField:(NSTextField *)textField;
- (void)_flashOverlayImage:(NSImage *)image;
- (void)_setOverlayImage:(NSImage *)image imageView:(NSImageView *)imageView;
- (void)_clearOverlay;
- (void)_hideOverlayWindow;
- (void)_animateHideOverlayTextField:(NSTextField *)textField;
- (void)_animateHideOverlayImageView;

- (void)_loadAttributes;
- (void)_loadTracks;
- (void)_updateTrackLoadingProgress;

- (void)_validate;
- (BOOL)_validatePreviousOrNext:(BOOL)previous;

- (void)_updatePlayButton;
- (void)_updateTrackingSlidersForInterval:(NSTimeInterval)interval;
- (void)_updateTimeTextFieldsForInterval:(NSTimeInterval)interval;

- (NSString *)_currentTimeString;

@end


@implementation SPMovieController(Private)

+ (NSDictionary *)_overlayStringAttributesForTextField:(NSTextField *)textField {
	NSMutableParagraphStyle		*style;
	
	style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:[textField alignment]];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithDouble:-4.0],
			NSStrokeWidthAttributeName,
		[NSColor blackColor],
			NSStrokeColorAttributeName,
		[textField font],
			NSFontAttributeName,
		[NSColor whiteColor],
			NSForegroundColorAttributeName,
		style,
			NSParagraphStyleAttributeName,
		NULL];
}



- (CGFloat)_overlayViewHeight {
	CGFloat			height;
	
	height = floor([_movieView frame].size.height / 16.0);
	
	return WIClamp(height, 18.0, 48.0);
}



- (void)_adjustOverlayTextFields {
	NSFont			*font;
	NSRect			frame;
	NSSize			size;
	CGFloat			height;
	
	height	= [self _overlayViewHeight];
	size	= [_overlayWindow frame].size;
	font	= [NSFont boldSystemFontOfSize:height];
	
	[_overlayLoadingStatusTextField setFont:font];
	[_overlayStatusTextField setFont:font];
	[_overlayTimeTextField setFont:font];
	
	frame = [_overlayTimeTextField frame];
	frame.origin.y = size.height - 25.0 - frame.size.height - height;
	[_overlayTimeTextField setFrame:frame];
}



- (void)_adjustOverlayImageView {
	NSDictionary	*attributes;
	NSRect			frame;
	NSSize			size, imageSize;
	CGFloat			height;
	
	height		= [self _overlayViewHeight];
	size		= [_overlayWindow frame].size;
	imageSize	= [[_overlayImageView image] size];

	frame = [_overlayImageView frame];
	frame.size.height	= height - 8.0;
	frame.size.width	= (imageSize.width > 0.0) ? ((imageSize.width / imageSize.height) * frame.size.height) : frame.size.height;
	frame.size.width	+= 5.0;
	frame.origin.x		= size.width - 25.0 - frame.size.width;
	frame.origin.y		= size.height - 28.0 - frame.size.height;
	
	if([_overlayStatusTextField alphaValue] > 0.0) {
		attributes = [[self class] _overlayStringAttributesForTextField:_overlayStatusTextField];
	
		frame.origin.x -= [[_overlayStatusTextField stringValue] sizeWithAttributes:attributes].width + 15.0;
	}
	
	[_overlayImageView setFrame:frame];
}



- (void)_showStatusOverlayForSkipTimeInterval:(NSTimeInterval)timeInterval {
	float		rate;
	
	rate = [_movie rate];
	
	if(timeInterval > 0.0) {
		[self _flashOverlayString:[NSSWF:@"%.0fs", fabs(timeInterval)] textField:_overlayStatusTextField];
		[self _flashOverlayImage:[NSImage imageNamed:@"OverlaySkipForward"]];
	}
	else if(timeInterval < 0.0) {
		[self _flashOverlayString:[NSSWF:@"%.0fs", fabs(timeInterval)] textField:_overlayStatusTextField];
		[self _flashOverlayImage:[NSImage imageNamed:@"OverlaySkipBack"]];
	}
	else if(rate == 1.0) {
		[self _animateHideOverlayTextField:_overlayStatusTextField];
		[self _flashOverlayImage:[NSImage imageNamed:@"OverlayPlay"]];
	}
	else if(rate == 0.0) {
		[self _animateHideOverlayTextField:_overlayStatusTextField];
		[self _flashOverlayImage:[NSImage imageNamed:@"OverlayPause"]];
	}
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(_animateHideOverlayTextField:)
												   object:_overlayStatusTextField];

		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(_animateHideOverlayTextField:)
												   object:_overlayTimeTextField];

		[NSObject cancelPreviousPerformRequestsWithTarget:self
												 selector:@selector(_animateHideOverlayImageView)];

		if(rate > 1.0) {
			[self _setOverlayString:[NSSWF:@"%.0fx", fabs(rate)] textField:[_overlayStatusTextField animator]];
			[self _setOverlayImage:[NSImage imageNamed:@"OverlayFastForward"] imageView:[_overlayImageView animator]];
		}
		else if(rate < 0.0) {
			[self _setOverlayString:[NSSWF:@"%.0fx", fabs(rate)] textField:[_overlayStatusTextField animator]];
			[self _setOverlayImage:[NSImage imageNamed:@"OverlayRewind"] imageView:[_overlayImageView animator]];
		}
	}
		
	if(rate > 1.0 || rate < 0.0)
		[self _setOverlayString:[self _currentTimeString] textField:[_overlayTimeTextField animator]];
	else
		[self _flashOverlayString:[self _currentTimeString] textField:_overlayTimeTextField];
}



- (void)_flashOverlayString:(NSString *)string textField:(NSTextField *)textField {
	[self _setOverlayString:string textField:[textField animator]];

	[self performSelectorOnce:@selector(_animateHideOverlayTextField:) withObject:textField afterDelay:2.0];
}



- (void)_setOverlayString:(NSString *)string textField:(NSTextField *)textField {
	NSDictionary		*attributes;
	
	attributes = [[self class] _overlayStringAttributesForTextField:textField];
	
	[textField setAttributedStringValue:[NSAttributedString attributedStringWithString:string attributes:attributes]];
	
	[_overlayWindow setAlphaValue:1.0];
	[textField setAlphaValue:1.0];
}



- (void)_flashOverlayImage:(NSImage *)image {
	[self _setOverlayImage:image imageView:[_overlayImageView animator]];

	[self performSelectorOnce:@selector(_animateHideOverlayImageView) afterDelay:2.0];
}



- (void)_setOverlayImage:(NSImage *)image imageView:(NSImageView *)imageView {
	[_overlayImageView setImage:image];

	[self _adjustOverlayImageView];
	
	[_overlayWindow setAlphaValue:1.0];
	[imageView setAlphaValue:1.0];
}



- (void)_clearOverlay {
	[_overlayImageView setImage:NULL];
	[_overlayLoadingStatusTextField setStringValue:@""];
	[_overlayStatusTextField setStringValue:@""];
	[_overlayTimeTextField setStringValue:@""];
}



- (void)_hideOverlayWindow {
	[_overlayImageView setAlphaValue:0.0];
	[_overlayLoadingStatusTextField setAlphaValue:0.0];
	[_overlayStatusTextField setAlphaValue:0.0];
	[_overlayTimeTextField setAlphaValue:0.0];
	
	[self _clearOverlay];
}



- (void)_animateHideOverlayTextField:(NSTextField *)textField {
	[[textField animator] setAlphaValue:0.0];

	[textField performSelector:@selector(setStringValue:) withObject:@"" afterDelay:[[NSAnimationContext currentContext] duration]];
}



- (void)_animateHideOverlayImageView {
	[[_overlayImageView animator] setAlphaValue:0.0];

	[_overlayImageView performSelector:@selector(setImage:) withObject:NULL afterDelay:[[NSAnimationContext currentContext] duration]];
}



#pragma mark -

- (void)_loadAttributes {
	NSString		*name;
	
	_naturalMovieSize	= [[_movie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
	_currentMovieSize	= _naturalMovieSize;
	
	if(!QTGetTimeInterval([_movie duration], &_duration))
		_duration = 0.0;
	
	name = [[[_movie attributeForKey:QTMovieURLAttribute] path] lastPathComponent];
	
	[_hudNameTextField setStringValue:name ? name : @""];

	[self _updateTimeTextFieldsForInterval:[self currentTime]];
	[self _updateTrackingSlidersForInterval:[self currentTime]];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerAttributesChangedNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerSizeChangedNotification object:self];
}



- (void)_loadTracks {
	NSString		*name, *type, *format, *audioPattern, *subtitlePattern;
	QTTrack			*track;
	NSUInteger		audioIndex, subtitleIndex;
	
	[_audioTracks removeAllObjects];
	[_subtitleTracks removeAllObjects];
	
	_hasUnloadedTracks = NO;
	_audioTrack = _subtitleTrack = 0;
	audioIndex = subtitleIndex = 1;
	
	for(track in [_movie tracks]) {
		type = [track attributeForKey:QTTrackMediaTypeAttribute];
		format = [track attributeForKey:QTTrackFormatSummaryAttribute];
		
		if(!format && ![type isEqualToString:QTMediaTypeBase])
			_hasUnloadedTracks = YES;
		
		if([track isAudioTrack]) {
			[_audioTracks addObject:track];

			if([track isEnabled])
				_audioTrack = audioIndex;
			
			audioIndex++;
		}
		else if([track isSubtitleTrack]) {
			[_subtitleTracks addObject:track];
			
			if([track isEnabled])
				_subtitleTrack = subtitleIndex;
			
			subtitleIndex++;
		}
		else if([track isVideoTrack] && [track isEnabled]) {
			_fps = [[[track media] attributeForKey:QTMediaSampleCountAttribute] unsignedIntegerValue] / _duration;
		}
	}
	
	audioPattern = [[SPSettings settings] objectForKey:SPPreferredAudioPattern];
	
	if([audioPattern length] > 0) {
		audioIndex = 1;
		
		for(track in _audioTracks) {
			name = [track attributeForKey:QTTrackDisplayNameAttribute];
			
			if([name containsSubstring:audioPattern options:NSCaseInsensitiveSearch]) {
				[self setAudioTrack:audioIndex];

				break;
			}
			
			audioIndex++;
		}
	}
	
	subtitlePattern = [[SPSettings settings] objectForKey:SPPreferredSubtitlePattern];
	
	if([subtitlePattern length] > 0) {
		subtitleIndex = 1;
		
		for(track in _subtitleTracks) {
			name = [track attributeForKey:QTTrackDisplayNameAttribute];
			
			if([name containsSubstring:subtitlePattern options:NSCaseInsensitiveSearch]) {
				[self setSubtitleTrack:subtitleIndex];

				break;
			}
			
			subtitleIndex++;
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerAttributesChangedNotification object:self];
}



- (void)_updateTrackLoadingProgress {
	NSArray				*tracks;
	NSString			*string;
	QTTrack				*track;
	QTTimeRange			range;
	NSTimeInterval		duration;
	
	if([[_movie attributeForKey:QTMovieLoadStateAttribute] longValue] < QTMovieLoadStateComplete) {
		tracks = [_movie tracksOfMediaType:QTMediaTypeVideo];
		
		if([tracks count] > 0) {
			track = [tracks objectAtIndex:0];
			range = [[track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue];
			
			if(!QTGetTimeInterval(range.duration, &duration))
				duration = 0.0;
			
			_trackLoadingProgress = duration / [self duration];
			
			if(_trackLoadingProgress >= 0.99)
				_trackLoadingProgress = 1.0;
		}
	} else {
		_trackLoadingProgress = 1.0;
	}
	
	if(_fullscreenWindow && _trackLoadingProgress < 1.0 && [_movie rate] == 0.0) {
		string = [NSSWF:NSLS(@"Loading Tracks: %.0f%%", @"Loading tracks overlay"), _trackLoadingProgress * 100.0];

		[self _flashOverlayString:string textField:_overlayLoadingStatusTextField];
	}
	
	[_trackingSlider setProgressDoubleValue:_trackLoadingProgress];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerLoadProgressChangedNotification object:self];
}



#pragma mark -

- (void)_validate {
	BOOL		previous, next;
	
	previous = [self _validatePreviousOrNext:YES];
	next = [self _validatePreviousOrNext:NO];
	
	[_previousButton setEnabled:previous];
	[_nextButton setEnabled:next];
	[_hudPreviousButton setEnabled:previous];
	[_hudNextButton setEnabled:next];
}



- (BOOL)_validatePreviousOrNext:(BOOL)previous {
	SPPlaylistFile			*file;
	SPPlaylistRepeatMode	repeatMode;
	
	file = [self playlistFile];
	
	if([file isRecent])
		return NO;
	
	repeatMode = [[SPPlaylistController playlistController] repeatMode];
	
	if(repeatMode == SPPlaylistRepeatOne || repeatMode == SPPlaylistRepeatAll)
		return YES;
	
	if(previous)
		return ([[SPPlaylistController playlistController] previousFileForFile:file] != NULL);
	else
		return ([[SPPlaylistController playlistController] nextFileForFile:file] != NULL);
}



#pragma mark -

- (void)_updatePlayButton {
	if([self isPlaying]) {
		[_playButton setImage:[NSImage imageNamed:@"Pause"]];
		[_hudPlayButton setImage:[NSImage imageNamed:@"HUDPause"]];
	} else {
		[_playButton setImage:[NSImage imageNamed:@"Play"]];
		[_hudPlayButton setImage:[NSImage imageNamed:@"HUDPlay"]];
	}
}



- (void)_updateTrackingSlidersForInterval:(NSTimeInterval)interval {
	[_trackingSlider setDoubleValue:(interval / [self duration]) * [_trackingSlider maxValue]];
	[_hudTrackingSlider setDoubleValue:(interval / [self duration]) * [_hudTrackingSlider maxValue]];
}



- (void)_updateTimeTextFieldsForInterval:(NSTimeInterval)interval {
	NSString		*elapsed, *remaining;
	
	elapsed = [[self class] shortStringForTimeInterval:interval];
	remaining = [[self class] shortStringForTimeInterval:_duration - interval];
	
	[_elapsedTimeTextField setStringValue:elapsed];
	[_remainingTimeTextField setStringValue:remaining];
	[_hudElapsedTimeTextField setStringValue:elapsed];
	[_hudRemainingTimeTextField setStringValue:remaining];
	
	if([_overlayTimeTextField alphaValue] > 0.0)
		[self _setOverlayString:[self _currentTimeString] textField:_overlayTimeTextField];
}



#pragma mark -

- (NSString *)_currentTimeString {
	return [NSSWF:NSLS(@"%@/%@", @"Current time overlay"),
		[[self class] shortStringForTimeInterval:[self currentTime]],
		[[self class] shortStringForTimeInterval:[self duration]]];
}
	
@end



static NSMutableSet *SPMovieControllerTypes;


@implementation SPMovieController

+ (void)initialize {
	if(self == [SPMovieController class]) {
		SPMovieControllerTypes = [[NSMutableSet alloc] initWithArray:[[[NSBundle mainBundle] infoDictionary] valueForKeyPath: 
			@"CFBundleDocumentTypes.@distinctUnionOfArrays.CFBundleTypeExtensions"]];
		[SPMovieControllerTypes removeObject:@"srt"];
		[SPMovieControllerTypes removeObject:@"ass"];
		[SPMovieControllerTypes removeObject:@"ssa"];
		[SPMovieControllerTypes removeObject:@"idx"];
		[SPMovieControllerTypes removeObject:@"sub"];
	}
}



#pragma mark -

+ (NSString *)shortStringForTimeInterval:(NSTimeInterval)interval {
	NSUInteger		hours, minutes, seconds;
	
	hours = interval / 3600.0;
	interval -= hours * 3600.0;
	
	minutes = interval / 60.0;
	interval -= minutes * 60.0;
	
	seconds = interval;
	
	return [NSSWF:@"%0.2lu:%0.2lu:%0.2lu", hours, minutes, seconds];
}



+ (NSString *)longStringForTimeInterval:(NSTimeInterval)interval {
	NSUInteger		days, hours, minutes;
	NSTimeInterval	seconds;
	
	days = interval / 86400.0;
	interval -= days * 86400.0;
	
	hours = interval / 3600.0;
	interval -= hours * 3600.0;
	
	minutes = interval / 60.0;
	interval -= minutes * 60.0;
	
	seconds = interval;
	
	return [NSSWF:@"%0.1lu:%0.2lu:%0.2lu:%05.2f", days, hours, minutes, seconds];
}



+ (NSTimeInterval)timeIntervalForString:(NSString *)string {
	NSArray		*components;
	NSUInteger	hours, minutes, seconds;
	
	hours = minutes = seconds = 0;
	components = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":.,;"]];
	
	if([components count] == 3) {
		hours = [[components objectAtIndex:0] unsignedIntegerValue];
		components = [components subarrayFromIndex:1];
	}
	
	if([components count] == 2) {
		minutes = [[components objectAtIndex:0] unsignedIntegerValue];
		seconds = [[components objectAtIndex:1] unsignedIntegerValue];
	}
	
	return (hours * 3600.0) + (minutes * 60.0) + seconds;
}



+ (NSTimeInterval)skipTimeIntervalForKey:(unichar)key {
	switch(key) {
		case NSLeftArrowFunctionKey:	return -[[SPSettings settings] intForKey:SPShortJumpInterval];		break;
		case NSRightArrowFunctionKey:	return  [[SPSettings settings] intForKey:SPShortJumpInterval];		break;
		case NSDownArrowFunctionKey:	return -[[SPSettings settings] intForKey:SPMediumJumpInterval];		break;
		case NSUpArrowFunctionKey:		return  [[SPSettings settings] intForKey:SPMediumJumpInterval];		break;
		case NSPageDownFunctionKey:		return -[[SPSettings settings] intForKey:SPLongJumpInterval];		break;
		case NSPageUpFunctionKey:		return  [[SPSettings settings] intForKey:SPLongJumpInterval];		break;
	}
	
	return 0.0;
}



+ (NSString *)shortStringForSize:(NSSize)size {
	return [NSSWF:NSLS(@"%.0f x %.0f", @"Short Size"), size.width, size.height];
}



+ (NSString *)longStringForSize:(NSSize)size {
	return [NSSWF:NSLS(@"%.0f x %.0f pixels", @"Long size"), size.width, size.height];
}



+ (NSString *)stringForAspectRatioOfSize:(NSSize)size {
	unsigned int	a, b, gcd;
	
	a = size.width;
	b = size.height;
	
	while(a > 0 && b > 0) {
		if(a > b)
			a %= b;
		else
			b %= a;
	}
	
	gcd = (a > 0) ? a : b;
	
	return [NSSWF:NSLS(@"%.0f:%.0f", @"Aspect ratio"), size.width / gcd, size.height / gcd];
}



+ (NSArray *)scalingNames {
	return [NSArray arrayWithObjects:
		NSLS(@"Current", @"Scaling"),
		NSLS(@"Half", @"Scaling"),
		NSLS(@"Actual", @"Scaling"),
		NSLS(@"Double", @"Scaling"),
		NSLS(@"Fit to Screen", @"Scaling"),
		NULL];
}



+ (NSArray *)aspectRatioNames {
	return [NSArray arrayWithObjects:
		NSLS(@"Actual", @"Aspect ratio"),
		NSLS(@"16:9", @"Aspect ratio"),
		NSLS(@"16:10", @"Aspect ratio"),
		NSLS(@"4:3", @"Aspect ratio"),
		NULL];
}



+ (NSSet *)movieFileTypes {
	return SPMovieControllerTypes;
}



#pragma mark -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_movie release];
	
	[_overlayWindow release];
	[_overlayView release];
	[_hudWindow release];
	[_hudView release];
	
	[_audioTracks release];
	[_subtitleTracks release];
	
	[_playlistFile release];
	
	[_timer release];

	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	if(_audioTracks)
		return;
	
	_audioTracks		= [[NSMutableArray alloc] init];
	_subtitleTracks		= [[NSMutableArray alloc] init];

	_scaling			= [[SPSettings settings] intForKey:SPDefaultScaling];
	_aspectRatio		= SPActualAspectRatio;
	
	_timer				= [[NSTimer scheduledTimerWithTimeInterval:1.0
															target:self
														  selector:@selector(timer:)
														  userInfo:NULL
														   repeats:YES] retain];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(playlistControllerSettingsChanged:)
			   name:SPPlaylistControllerSettingsChangedNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowDidResize:)
			   name:NSWindowDidResizeNotification
			 object:[_movieView window]];

	[[[NSWorkspace sharedWorkspace] notificationCenter]
		addObserver:self
		   selector:@selector(workspaceSessionDidResignActive:)
			   name:NSWorkspaceSessionDidResignActiveNotification];
	
	[_movieView setDelegate:self];
}



- (void)windowDidResize:(NSNotification *)notification {
	NSWindow		*window;
	NSSize			size;
	
	window = [notification object];
	
	if(window == [_movieView window]) {
		size = [window frame].size;

		_currentMovieSize.width = size.width;
		_currentMovieSize.height = size.height - (size.height - [_movieView frame].size.height);

		[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerAttributesChangedNotification object:self];
		
		if([[_overlayLoadingStatusTextField stringValue] length] > 0)
			[self _setOverlayString:[_overlayLoadingStatusTextField stringValue] textField:_overlayLoadingStatusTextField];

		if([[_overlayStatusTextField stringValue] length] > 0)
			[self _setOverlayString:[_overlayStatusTextField stringValue] textField:_overlayStatusTextField];

		if([[_overlayTimeTextField stringValue] length] > 0)
			[self _setOverlayString:[_overlayTimeTextField stringValue] textField:_overlayTimeTextField];
	}
}



- (void)workspaceSessionDidResignActive:(NSNotification *)notification {
	[self stop];
}



- (void)menuNeedsUpdate:(NSMenu *)menu {
	NSString			*string;
	NSUInteger			index;
	
	if(menu == _overlayMenu) {
		if([self isPlaying])
			[_overlayPlayMenuItem setTitle:NSLS(@"Pause", @"Play/pause menu item")];
		else
			[_overlayPlayMenuItem setTitle:NSLS(@"Play", @"Play/pause menu item")];
		
		[_overlayAudioTrackMenu removeAllItems];
		
		index = 0;
		
		for(string in [self audioTrackNamesForDisplay:YES])
			[_overlayAudioTrackMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(audioTrack:)]];

		[_overlayAudioTrackMenu setOnStateForItemsWithTag:[self audioTrack]];
		
		index = 0;

		[_overlaySubtitleTrackMenu removeAllItems];
		
		for(string in [self subtitleTrackNamesForDisplay:YES])
			[_overlaySubtitleTrackMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(subtitleTrack:)]];

		[_overlaySubtitleTrackMenu setOnStateForItemsWithTag:[self subtitleTrack]];
	}
}



- (void)movieRateDidChange:(NSNotification *)notification {
	NSTimeInterval		interval;
	
	[self _updatePlayButton];

	interval = [self currentTime];
	
	[self _updateTrackingSlidersForInterval:interval];
	[self _updateTimeTextFieldsForInterval:interval];
	
	[[NSNotificationCenter defaultCenter]
			postNotificationName:SPMovieControllerInteractiveAttributesChangedNotification
						  object:self];
}



- (void)movieDidEnd:(NSNotification *)notification {
	if(![self openNextAndStartPlaying:YES]) {
		if([[self playerController] windowShouldClose:_fullscreenWindow])
			[_fullscreenWindow close];
	}
}



- (void)movieLoadStateDidChange:(NSNotification *)notification {
	[self _loadAttributes];
	[self _loadTracks];
}



- (void)movieView:(SPQTMovieView *)movieView didReceiveEvent:(NSEvent *)event {
	NSString		*string;
	NSEventType		type;
	
	type = [event type];
	
	if(type == NSLeftMouseDown) {
		if([event clickCount] == 1) {
			[self performSelectorOnce:@selector(play) afterDelay:0.4];
		} else {
			[[self playerController] fullscreen:self];

			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(play) object:NULL];
		}
	}
	else if(type == NSKeyDown) {
		string = [SPShortcutTextField stringForModifierFlags:[event modifierFlags] keyCode:[event keyCode]];
		
		if([string isEqualToString:[[SPSettings settings] objectForKey:SPShortJumpBackwardShortcut]])
			[self skipTime:-[[SPSettings settings] doubleForKey:SPShortJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPShortJumpForwardShortcut]])
			[self skipTime:[[SPSettings settings] doubleForKey:SPShortJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPMediumJumpBackwardShortcut]])
			[self skipTime:-[[SPSettings settings] doubleForKey:SPMediumJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPMediumJumpForwardShortcut]])
			[self skipTime:[[SPSettings settings] doubleForKey:SPMediumJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPLongJumpBackwardShortcut]])
			[self skipTime:-[[SPSettings settings] doubleForKey:SPLongJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPLongJumpForwardShortcut]])
			[self skipTime:[[SPSettings settings] doubleForKey:SPLongJumpInterval]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPCycleAudioTrackShortcut]])
			[self cycleAudioTracksForwards:![event shiftKeyModifier]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPCycleSubtitleTrackShortcut]])
			[self cycleSubtitleTracksForwards:![event shiftKeyModifier]];
		else if([string isEqualToString:[[SPSettings settings] objectForKey:SPCycleAspectRatioShortcut]])
			[self cycleAspectRatiosForwards:![event shiftKeyModifier]];
		else {
			switch([event characterIgnoringModifiers]) {
				case ' ':
					[self play];
					break;

				case NSEndFunctionKey:
					[self setCurrentTime:0.0];
					
					[self showStatusOverlay];
					break;
					
				case NSHomeFunctionKey:
					[self setCurrentTime:[self duration]];
					
					[self showStatusOverlay];
					break;
			}
		}
	}
}



- (NSMenu *)movieView:(SPQTMovieView *)movieView menuForEvent:(NSEvent *)event {
	return _overlayMenu;
}



- (void)playlistControllerSettingsChanged:(NSNotification *)notification {
	[self _validate];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	
	selector = [item action];
	
	if(selector == @selector(previous:))
		return [self _validatePreviousOrNext:YES];
	else if(selector == @selector(next:))
		return [self _validatePreviousOrNext:NO];
	
	return YES;
}



#pragma mark -

- (void)timer:(NSTimer *)timer {
	NSTimeInterval		interval;
	
	if([self isPlaying]) {
		interval = [self currentTime];
		
		[self _updateTrackingSlidersForInterval:interval];
		[self _updateTimeTextFieldsForInterval:interval];

		[[NSNotificationCenter defaultCenter]
			postNotificationName:SPMovieControllerInteractiveAttributesChangedNotification
						  object:self];
		
		_playingTime += fabs([_movie rate]) * [timer timeInterval];
	}
	
	if(_movie && _trackLoadingProgress < 1.0) {
		[self _updateTrackLoadingProgress];
		
		if(_startPlayingWhenTracksAreLoaded && _trackLoadingProgress >= 1.0 && [_movie rate] < 1.0) {
			_startPlayingWhenTracksAreLoaded = NO;
			
			[_movie play];
		}
	}
}



#pragma mark -

- (id)playerController {
	return _playerController;
}



- (NSWindow *)playerWindow {
	return _playerWindow;
}



- (NSWindow *)overlayWindow {
	if(!_overlayWindow) {
		if([NSBundle loadNibNamed:@"Overlay" owner:self]) {
			_overlayWindow = [[NSWindow alloc] initWithContentRect:[_overlayView frame]
														 styleMask:NSBorderlessWindowMask
														   backing:NSBackingStoreBuffered
															 defer:YES];
			[_overlayWindow setOpaque:NO];
			[_overlayWindow setHasShadow:NO];
			[_overlayWindow setIgnoresMouseEvents:YES];
			[_overlayWindow setBackgroundColor:[NSColor clearColor]];
			[_overlayWindow setContentView:_overlayView];
			[_overlayWindow setReleasedWhenClosed:NO];
		}
	}
	
	return _overlayWindow;
}



- (NSWindow *)HUDWindow {
	if(!_hudWindow) {
		if([NSBundle loadNibNamed:@"HUD" owner:self]) {
			_hudWindow = [[NSWindow alloc] initWithContentRect:[_hudView frame]
													 styleMask:NSBorderlessWindowMask
													   backing:NSBackingStoreBuffered
														 defer:YES];
			
			[_hudWindow setContentView:_hudView];
			[_hudWindow setOpaque:NO];
			[_hudWindow setLevel:NSScreenSaverWindowLevel];
			[_hudWindow setBackgroundColor:[NSColor clearColor]];
			[_hudWindow setMovableByWindowBackground:YES];
			[_hudWindow setReleasedWhenClosed:NO];
		}
	}
	
	return _hudWindow;
}



- (void)setMovie:(QTMovie *)movie playlistFile:(SPPlaylistFile *)file {
	[movie retain];
	
	if(_movie) {
		[[self playlistFile] setViewCount:[[self playlistFile] viewCount] + (_playingTime / _duration)];
		[[self playlistFile] setLocation:[self currentTime]];
		
		if([[self playlistFile] isKindOfClass:[SPPlaylistRepresentedFile class]])
			[[SPPlaylistController playlistController] addRepresentedFile:(SPPlaylistRepresentedFile *) [self playlistFile]];
		
		[[SPPlaylistController playlistController] save];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerViewCountChangedNotification object:self];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerClosedMovieNotification object:self];

		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:QTMovieRateDidChangeNotification
					object:_movie];
		
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:QTMovieLoadStateDidChangeNotification
					object:_movie];
		
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:QTMovieDidEndNotification
					object:_movie];
		
		[_movie setDelegate:NULL];
		[_movie release];
	}
	
	[file retain];
	[_playlistFile release];
	
	_playlistFile = file;
	
	if(movie) {
		_movie = [movie retain];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(movieRateDidChange:)
				   name:QTMovieRateDidChangeNotification
				 object:_movie];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(movieLoadStateDidChange:)
				   name:QTMovieLoadStateDidChangeNotification
				 object:_movie];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(movieDidEnd:)
				   name:QTMovieDidEndNotification
				 object:_movie];

		[_movie setDelegate:self];
		[_movieView setMovie:_movie];
		
		[self _clearOverlay];

		_trackLoadingProgress = 0.0;
		_playingTime = 0.0;
		_startPlayingWhenTracksAreLoaded = NO;
		
		[self _loadAttributes];
		[self _loadTracks];
		[self _updateTrackLoadingProgress];
		[self _updatePlayButton];

		[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerOpenedMovieNotification object:self];
	} else {
		[_movie setIdling:NO];
		[_movieView setMovie:NULL];
		_movie = NULL;

		[self _hideOverlayWindow];
	}
	
	[self _validate];

	[movie release];
}



- (QTMovie *)movie {
	return _movie;
}



- (SPPlaylistFile *)playlistFile {
	return _playlistFile;
}



- (NSTimeInterval)duration {
	return _duration;
}



- (double)fps {
	return _fps;
}



- (void)setCurrentTime:(NSTimeInterval)interval {
	if(interval < 0.0)
		interval = 0.0;
	
	if(interval > [self duration])
		interval = [self duration] - 0.001;
	
	[_movie setCurrentTime:QTMakeTimeWithTimeInterval(interval)];

	[self _updateTimeTextFieldsForInterval:interval];
	[self _updateTrackingSlidersForInterval:interval];

	[[NSNotificationCenter defaultCenter]
		postNotificationName:SPMovieControllerInteractiveAttributesChangedNotification
					  object:self];
}



- (NSTimeInterval)currentTime {
	NSTimeInterval	interval;

	if(QTGetTimeInterval([_movie currentTime], &interval))
		return interval;
	
	return 0.0;
}



- (NSSize)naturalSize {
	return _naturalMovieSize;
}



- (NSSize)currentSize {
	return _currentMovieSize;
}



- (void)setScaling:(SPScaling)scaling {
	_scaling = scaling;

	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerSizeChangedNotification object:self];
}



- (SPScaling)scaling {
	return _scaling;
}



- (NSArray *)audioTracks {
	if(_hasUnloadedTracks)
		[self _loadTracks];

	return _audioTracks;
}



- (void)setAudioTrack:(NSUInteger)index {
	QTTrack			*track;
	NSUInteger		i = 1;

	_audioTrack = index;
	
	for(track in _audioTracks)
		[track setEnabled:(i++ == _audioTrack)];
}



- (NSUInteger)audioTrack {
	return _audioTrack;
}



- (NSArray *)audioTrackNamesForDisplay:(BOOL)display {
	NSMutableArray	*tracks;
	NSString		*name, *format;
	QTTrack			*track;
	
	tracks = [NSMutableArray array];
	[tracks addObject:NSLS(@"None", @"Audio track")];
	
	for(track in [self audioTracks]) {
		name = [track attributeForKey:QTTrackDisplayNameAttribute];
		
		if(display && [name hasPrefix:@"Sound Track"]) {
			format = [track shortFormatSummary];
			
			if(format)
				name = [name stringByAppendingFormat:@", %@", format];
		}

		[tracks addObject:name];
	}
	
	return tracks;
}



- (NSArray *)subtitleTracks {
	if(_hasUnloadedTracks)
		[self _loadTracks];

	return _subtitleTracks;
}



- (void)setSubtitleTrack:(NSUInteger)index {
	QTTrack			*track;
	NSUInteger		i = 1;

	_subtitleTrack = index;
	
	for(track in _subtitleTracks)
		[track setEnabled:(i++ == _subtitleTrack)];
}



- (NSUInteger)subtitleTrack {
	return _subtitleTrack;
}



- (NSArray *)subtitleTrackNamesForDisplay:(BOOL)display {
	NSMutableArray	*tracks;
	NSString		*name, *format;
	QTTrack			*track;
	
	tracks = [NSMutableArray array];
	[tracks addObject:NSLS(@"None", @"Subtitle track")];
	
	for(track in [self subtitleTracks]) {
		name = [track attributeForKey:QTTrackDisplayNameAttribute];
		
		if(display && [name hasPrefix:@"Video Track"]) {
			format = [track shortFormatSummary];
			
			if(format)
				name = [name stringByAppendingFormat:@", %@", format];
		}
		
		[tracks addObject:name];
	}
	
	return tracks;
}



- (void)setAspectRatio:(SPAspectRatio)aspectRatio {
	_aspectRatio = aspectRatio;

	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerSizeChangedNotification object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:SPMovieControllerAttributesChangedNotification object:self];
}



- (SPAspectRatio)aspectRatio {
	return _aspectRatio;
}



- (CGFloat)ratioForAspectRatio:(SPAspectRatio)ratio {
	switch(ratio) {
		case SPActualAspectRatio:
			return _naturalMovieSize.width / _naturalMovieSize.height;
			break;
			
		case SP16_9AspectRatio:
			return 16.0 / 9.0;
			break;
			
		case SP16_10AspectRatio:
			return 16.0 / 10.0;
			break;
			
		case SP4_3AspectRatio:
			return 4.0 / 3.0;
			break;
	}
	
	return 1.0;
}



- (NSArray *)chapterNames {
	NSMutableArray		*chapters;
	NSDictionary		*chapter;
	
	chapters = [NSMutableArray array];
	
	if([_movie hasChapters]) {
		for(chapter in [_movie chapters]) {
			if([chapter objectForKey:QTMovieChapterName])
				[chapters addObject:[chapter objectForKey:QTMovieChapterName]];
		}
	}
	
	return chapters;
}




#pragma mark -

- (void)play {
	_startPlayingWhenTracksAreLoaded = NO;

	if(fabs([_movie rate]) > 1.0) {
		[_movie setRate:1.0];
		[_movie play];
	} else {
		if(![self isPlaying])
			[_movie play];
		else
			[_movie stop];
	}
	
	[self showStatusOverlay];
}



- (void)playAtRate:(float)rate {
	_startPlayingWhenTracksAreLoaded = NO;

	[_movie play];
	[_movie setRate:rate];
	
	[self showStatusOverlay];
}



- (void)playWhenTracksAreLoaded {
	if(_trackLoadingProgress < 1.0)
		_startPlayingWhenTracksAreLoaded = YES;
	else
		[_movie play];
}



- (BOOL)isPlaying {
	return (fabs([_movie rate]) > 0.01);
}



- (void)stepForward {
	[_movie stepForward];
}



- (void)stepBackward {
	[_movie stepBackward];
}



- (void)skipTime:(NSTimeInterval)timeInterval {
	[self setCurrentTime:[self currentTime] + timeInterval];
				
	[self _showStatusOverlayForSkipTimeInterval:timeInterval];
}



- (void)pause {
	[_movie stop];
	
	[self showStatusOverlay];
}



- (void)stop {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(play) object:NULL];

	[_movie stop];
	
	[self _animateHideOverlayTextField:_overlayStatusTextField];
	[self _flashOverlayImage:[NSImage imageNamed:@"OverlayStop"]];
	[self _flashOverlayString:[self _currentTimeString] textField:_overlayTimeTextField];
}



- (void)invalidate {
	[_timer invalidate];
}



- (void)startFullscreenInWindow:(SPFullscreenWindow *)window delegate:(id)delegate didEndSelector:(SEL)selector {
	_fullscreenWindow = window;
	_fullscreenDelegate = delegate;
	_fullscreenSelector = selector;
}



- (void)stopFullscreen {
	[_fullscreenDelegate performSelector:_fullscreenSelector withObject:_fullscreenWindow];

	_fullscreenWindow = NULL;
	_fullscreenDelegate = NULL;
	_fullscreenSelector = NULL;
}



- (BOOL)isInFullscreen {
	return (_fullscreenWindow != NULL);
}



- (void)orderFrontFullscreenHUDWindow {
	[_fullscreenWindow orderFrontHUDWindow];
}



- (void)adjustOverlayWindow {
	[self _adjustOverlayTextFields];
	[self _adjustOverlayImageView];
}



- (void)resumePlaying {
	NSAlert				*alert;
	NSTimeInterval		location;
	BOOL				play = YES;
	
	location = [[self playlistFile] location];
	
	if(location > 0.0 && location < [self duration]) {
		switch([[SPSettings settings] intForKey:SPResumePlayingBehavior]) {
			case SPAlwaysAsk:
				if(![self isInFullscreen]) {
					alert = [NSAlert alertWithMessageText:NSLS(@"This is a previously played file. Please select where to start playing.", @"Resume panel title")
											defaultButton:NSLS(@"Last Time Played", @"Resume panel button")
										  alternateButton:NSLS(@"Cancel", @"Resume panel button")
											  otherButton:NSLS(@"Beginning of File", @"Resume panel button")
								informativeTextWithFormat:[NSSWF:NSLS(@"The last time played was at %@.", @"Resume panel description"),
														   [[self class] shortStringForTimeInterval:location]]];
					
					[alert beginSheetModalForWindow:[_movieView window]
									  modalDelegate:self
									 didEndSelector:@selector(resumePlayingSheetDidEnd:returnCode:contextInfo:)
										contextInfo:NULL];
					
					play = NO;
				}
				break;
			
			case SPFromLastTimePlayed:
				[self setCurrentTime:[[self playlistFile] location]];
				break;

			case SPFromBeginning:
			default:
				break;
		}
	}
	
	if(play && !_disablePlayingWhenOpened && [[SPSettings settings] boolForKey:SPPlayMoviesWhenOpened])
		[self playWhenTracksAreLoaded];
}



- (void)resumePlayingSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[self setCurrentTime:[[self playlistFile] location]];

	if(!_disablePlayingWhenOpened && [[SPSettings settings] boolForKey:SPPlayMoviesWhenOpened])
		[self playWhenTracksAreLoaded];
}



- (float)rate {
	return [_movie rate];
}



- (void)cycleAudioTracksForwards:(BOOL)forwards {
	NSString		*string;
	NSUInteger		count, audioTrack;
	
	count = [[self audioTracks] count];
	
	if(count > 0) {
		audioTrack = [self audioTrack];
		
		if(forwards) {
			if(audioTrack == count)
				audioTrack = 0;
			else
				audioTrack++;
		} else {
			if(audioTrack <= 0)
				audioTrack = count;
			else
				audioTrack--;
		}
		
		[self setAudioTrack:audioTrack];
	}
	
	string = [NSSWF:NSLS(@"Audio Track: %@", @"Audio track overlay"),
		[[self audioTrackNamesForDisplay:YES] objectAtIndex:[self audioTrack]]];
	
	[self _flashOverlayString:string textField:_overlayStatusTextField];
}



- (void)cycleSubtitleTracksForwards:(BOOL)forwards {
	NSString		*string;
	NSUInteger		count, subtitleTrack;
	
	count = [[self subtitleTracks] count];
	
	if(count > 0) {
		subtitleTrack = [self subtitleTrack];
		
		if(forwards) {
			if(subtitleTrack == count)
				subtitleTrack = 0;
			else
				subtitleTrack++;
		} else {
			if(subtitleTrack <= 0)
				subtitleTrack = count;
			else
				subtitleTrack--;
		}
		
		[self setSubtitleTrack:subtitleTrack];
	}
	
	string = [NSSWF:NSLS(@"Subtitle Track: %@", @"Subtitle track overlay"),
		[[self subtitleTrackNamesForDisplay:YES] objectAtIndex:[self subtitleTrack]]];

	[self _flashOverlayString:string textField:_overlayStatusTextField];
}



- (void)cycleAspectRatiosForwards:(BOOL)forwards {
	NSString		*string;
	SPAspectRatio	aspectRatio;
	
	aspectRatio = [self aspectRatio];
	
	if(forwards) {
		if(aspectRatio == SP4_3AspectRatio)
			aspectRatio = SPActualAspectRatio;
		else
			aspectRatio++;
	} else {
		if(aspectRatio == SPActualAspectRatio)
			aspectRatio = SP4_3AspectRatio;
		else
			aspectRatio--;
	}
	
	[self setAspectRatio:aspectRatio]; 

	string = [NSSWF:NSLS(@"Aspect Ratio: %@", @"Aspect ratio overlay"),
		[[[self class] aspectRatioNames] objectAtIndex:[self aspectRatio]]];

	[self _flashOverlayString:string textField:_overlayStatusTextField];
}



- (void)showStatusOverlay {
	[self _showStatusOverlayForSkipTimeInterval:0.0];
}



- (BOOL)openPrevious {
	SPPlaylistFile			*file, *previousFile;
	SPPlaylistRepeatMode	repeatMode;
	
	repeatMode = [[SPPlaylistController playlistController] repeatMode];
	
	if(repeatMode == SPPlaylistRepeatOne) {
		[self setCurrentTime:0.0];
		
		return YES;
	}
	
	file = [self playlistFile];
	
	if([file isRecent])
		return NO;

	while(YES) {
		previousFile = [[SPPlaylistController playlistController] previousFileForFile:file];
		
		if(!previousFile) {
			if(repeatMode == SPPlaylistRepeatAll)
				previousFile = [[SPPlaylistController playlistController] lastFileForFile:file];
		}
		
		if(!previousFile)
			break;
		
		if(previousFile == [self playlistFile]) {
			[self setCurrentTime:0.0];
			
			return YES;
		}
		
		_disablePlayingWhenOpened = [self isPlaying];

		if(![[self playerController] movieController:self shouldOpenFile:previousFile]) {
			file = previousFile;
			
			continue;
		}
		
		[self _flashOverlayImage:[NSImage imageNamed:@"OverlayPrevious"]];

		if(_disablePlayingWhenOpened) {
			[self playWhenTracksAreLoaded];
			
			_disablePlayingWhenOpened = NO;
		}
		
		return YES;
	}
	
	return NO;
}



- (BOOL)openNext {
	return [self openNextAndStartPlaying:([self isPlaying] || _startPlayingWhenTracksAreLoaded)];
}



- (BOOL)openNextAndStartPlaying:(BOOL)startPlaying {
	SPPlaylistFile			*file, *nextFile;
	SPPlaylistRepeatMode	repeatMode;
	
	repeatMode = [[SPPlaylistController playlistController] repeatMode];
	
	if(repeatMode == SPPlaylistRepeatOne) {
		[self setCurrentTime:0.0];
		
		if(startPlaying)
			[self play];
		
		return YES;
	}
	
	file = [self playlistFile];
	
	if([file isRecent])
		return NO;

	while(YES) {
		nextFile = [[SPPlaylistController playlistController] nextFileForFile:file];
		
		if(!nextFile) {
			if(repeatMode == SPPlaylistRepeatAll)
				nextFile = [[SPPlaylistController playlistController] firstFileForFile:file];
		}
		
		if(!nextFile)
			break;
		
		if(nextFile == [self playlistFile]) {
			[self setCurrentTime:0.0];
			
			if(startPlaying)
				[self play];
			
			return YES;
		}
		
		_disablePlayingWhenOpened = startPlaying;

		if(![[self playerController] movieController:self shouldOpenFile:nextFile]) {
			file = nextFile;
			
			continue;
		}

		[self _flashOverlayImage:[NSImage imageNamed:@"OverlayNext"]];

		if(_disablePlayingWhenOpened) {
			[self playWhenTracksAreLoaded];
			
			_disablePlayingWhenOpened = NO;
		}
		
		return YES;
	}
	
	return NO;
}



#pragma mark -

- (IBAction)scaling:(id)sender {
	if(![self isInFullscreen])
		[self setScaling:[sender tag]];
}



- (IBAction)fullscreen:(id)sender {
	if([[self playerController] windowShouldClose:_fullscreenWindow])
		[_fullscreenWindow close];
}



- (IBAction)snapshot:(id)sender {
	NSImage			*image;
	NSData			*data;
	NSString		*name, *path;
	NSUInteger		i = 2;
	
	image = [_movie currentFrameImage];
	data = [[NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]] representationUsingType:NSPNGFileType properties:NULL];
	name = [NSSWF:NSLS(@"Spiral Snapshot %@", @"Snapshot name (time)"),
		[[[self class] shortStringForTimeInterval:[self currentTime]] stringByReplacingOccurencesOfString:@":" withString:@"_"]];
	path = [NSSWF:@"~/Desktop/%@.png", name];
	
	while([[NSFileManager defaultManager] fileExistsAtPath:[path stringByExpandingTildeInPath]] && i < 50)
		path = [NSSWF:@"~/Desktop/%@ %u.png", name, i++];
	
	[data writeToFile:[path stringByExpandingTildeInPath] atomically:YES];
	
	[self _flashOverlayString:NSLS(@"Snapshot Saved To Desktop", @"Snapshot overlay") textField:_overlayStatusTextField];
}



- (IBAction)chapter:(id)sender {
	NSTimeInterval	interval;
	QTTime			time;
	
	time = [_movie startTimeOfChapter:[sender tag]];
	
	if(QTGetTimeInterval(time, &interval))
		[self setCurrentTime:interval];
}



- (IBAction)audioTrack:(id)sender {
	[self setAudioTrack:[sender tag]];
}



- (IBAction)subtitleTrack:(id)sender {
	[self setSubtitleTrack:[sender tag]];
}



- (IBAction)aspectRatio:(id)sender {
	[self setAspectRatio:[sender tag]];
}



- (IBAction)previous:(id)sender {
	[self openPrevious];
}



- (IBAction)next:(id)sender {
	[self openNext];
}



- (IBAction)play:(id)sender {
	[self play];
}



- (IBAction)track:(id)sender {
	[self setCurrentTime:[self duration] * [sender doubleValue] / [sender maxValue]];
}

@end
