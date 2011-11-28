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

#import "SPQTMovieView.h"

extern NSString * const				SPMovieControllerOpenedMovieNotification;
extern NSString * const				SPMovieControllerClosedMovieNotification;
extern NSString * const				SPMovieControllerViewCountChangedNotification;
extern NSString * const				SPMovieControllerSizeChangedNotification;
extern NSString * const				SPMovieControllerAttributesChangedNotification;
extern NSString * const				SPMovieControllerInteractiveAttributesChangedNotification;
extern NSString * const				SPMovieControllerLoadProgressChangedNotification;

enum _SPAspectRatio {
	SPActualAspectRatio				= 0,
	SP16_9AspectRatio,
	SP16_10AspectRatio,
	SP4_3AspectRatio
};
typedef enum _SPAspectRatio			SPAspectRatio;

enum _SPScaling {
	SPCurrentSize					= 0,
	SPHalfSize,
	SPActualSize,
	SPDoubleSize,
	SPFitToScreen
};
typedef enum _SPScaling				SPScaling;

enum _SPResumeBehavior {
	SPFromBeginning					= 0,
	SPFromLastTimePlayed,
	SPAlwaysAsk
};
typedef enum _SPResumeBehavior		SPResumeBehavior;


@class SPFullscreenWindow, SPOverlayProgressView, SPHUDPanel, SPHUDSlider, SPLCDSlider, SPPlaylistFile;

@interface SPMovieController : WIObject <SPQTMovieViewDelegate> {
	IBOutlet id						_playerController;
	IBOutlet NSWindow				*_playerWindow;
	
	IBOutlet SPQTMovieView			*_movieView;
	
	IBOutlet NSButton				*_previousButton;
	IBOutlet NSButton				*_playButton;
	IBOutlet NSButton				*_nextButton;
	IBOutlet NSTextField			*_elapsedTimeTextField;
	IBOutlet SPLCDSlider			*_trackingSlider;
	IBOutlet NSTextField			*_remainingTimeTextField;
	
	IBOutlet NSView					*_overlayView;
	IBOutlet NSImageView			*_overlayImageView;
	IBOutlet NSTextField			*_overlayLoadingStatusTextField;
	IBOutlet NSTextField			*_overlayStatusTextField;
	IBOutlet NSTextField			*_overlayTimeTextField;
	IBOutlet NSMenu					*_overlayMenu;
	IBOutlet NSMenuItem				*_overlayPlayMenuItem;
	IBOutlet NSMenu					*_overlayAudioTrackMenu;
	IBOutlet NSMenu					*_overlaySubtitleTrackMenu;
	
	IBOutlet NSView					*_hudView;
	IBOutlet NSTextField			*_hudNameTextField;
	IBOutlet NSButton				*_hudPreviousButton;
	IBOutlet NSButton				*_hudPlayButton;
	IBOutlet NSButton				*_hudNextButton;
	IBOutlet NSTextField			*_hudElapsedTimeTextField;
	IBOutlet SPHUDSlider			*_hudTrackingSlider;
	IBOutlet NSTextField			*_hudRemainingTimeTextField;
	
	NSWindow						*_overlayWindow;
	NSWindow						*_hudWindow;
	SPFullscreenWindow				*_fullscreenWindow;
	id								_fullscreenDelegate;
	SEL								_fullscreenSelector;
	
	QTMovie							*_movie;
	NSTimeInterval					_duration;
	double							_fps;
	NSSize							_naturalMovieSize, _currentMovieSize;
	SPScaling						_scaling;
	NSMutableArray					*_audioTracks, *_subtitleTracks;
	NSUInteger						_audioTrack, _subtitleTrack;
	SPAspectRatio					_aspectRatio;
	NSTimeInterval					_trackLoadingProgress;

	SPPlaylistFile					*_playlistFile;
	NSTimeInterval					_playingTime;

	NSTimer							*_timer;

	NSRect							_movieViewFrame;
	BOOL							_movingWindow;
	BOOL							_disablePlayingWhenOpened;
	BOOL							_startPlayingWhenTracksAreLoaded;
	BOOL							_hasUnloadedTracks;
}

+ (NSString *)shortStringForTimeInterval:(NSTimeInterval)interval;
+ (NSString *)longStringForTimeInterval:(NSTimeInterval)interval;
+ (NSTimeInterval)timeIntervalForString:(NSString *)string;
+ (NSTimeInterval)skipTimeIntervalForKey:(unichar)key;
+ (NSString *)shortStringForSize:(NSSize)size;
+ (NSString *)longStringForSize:(NSSize)size;
+ (NSString *)stringForAspectRatioOfSize:(NSSize)size;
+ (NSArray *)scalingNames;
+ (NSArray *)aspectRatioNames;
+ (NSSet *)movieFileTypes;

- (NSWindow *)playerWindow;
- (NSWindow *)overlayWindow;
- (NSWindow *)HUDWindow;
- (id)playerController;
- (void)setMovie:(QTMovie *)movie playlistFile:(SPPlaylistFile *)file;
- (QTMovie *)movie;
- (SPPlaylistFile *)playlistFile;
- (NSTimeInterval)duration;
- (double)fps;
- (void)setCurrentTime:(NSTimeInterval)interval;
- (NSTimeInterval)currentTime;
- (NSSize)naturalSize;
- (NSSize)currentSize;
- (void)setScaling:(SPScaling)scaling;
- (SPScaling)scaling;
- (NSArray *)audioTracks;
- (void)setAudioTrack:(NSUInteger)index;
- (NSUInteger)audioTrack;
- (NSArray *)audioTrackNamesForDisplay:(BOOL)display;
- (NSArray *)subtitleTracks;
- (void)setSubtitleTrack:(NSUInteger)index;
- (NSUInteger)subtitleTrack;
- (NSArray *)subtitleTrackNamesForDisplay:(BOOL)display;
- (void)setAspectRatio:(SPAspectRatio)aspectRatio;
- (SPAspectRatio)aspectRatio;
- (CGFloat)ratioForAspectRatio:(SPAspectRatio)ratio;
- (NSArray *)chapterNames;

- (void)play;
- (void)playAtRate:(float)rate;
- (void)playWhenTracksAreLoaded;
- (BOOL)isPlaying;
- (void)stepForward;
- (void)stepBackward;
- (void)skipTime:(NSTimeInterval)timeInterval;
- (void)pause;
- (void)stop;
- (void)invalidate;
- (void)startFullscreenInWindow:(SPFullscreenWindow *)window delegate:(id)delegate didEndSelector:(SEL)selector;
- (void)stopFullscreen;
- (BOOL)isInFullscreen;
- (void)orderFrontFullscreenHUDWindow;
- (void)adjustOverlayWindow;
- (void)resumePlaying;
- (float)rate;
- (void)cycleAudioTracksForwards:(BOOL)forwards;
- (void)cycleSubtitleTracksForwards:(BOOL)forwards;
- (void)cycleAspectRatiosForwards:(BOOL)forwards;
- (void)showStatusOverlay;
- (BOOL)openNext;
- (BOOL)openNextAndStartPlaying:(BOOL)startPlaying;
- (BOOL)openPrevious;

- (IBAction)scaling:(id)sender;
- (IBAction)fullscreen:(id)sender;
- (IBAction)snapshot:(id)sender;
- (IBAction)chapter:(id)sender;
- (IBAction)audioTrack:(id)sender;
- (IBAction)subtitleTrack:(id)sender;
- (IBAction)aspectRatio:(id)sender;
- (IBAction)previous:(id)sender;
- (IBAction)next:(id)sender;
- (IBAction)play:(id)sender;
- (IBAction)track:(id)sender;

@end


@interface NSObject(SPMovieControllerDelegate)

- (BOOL)movieController:(SPMovieController *)movieController shouldOpenFile:(SPPlaylistFile *)file;

@end
