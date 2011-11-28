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
#import "SPApplicationController.h"
#import "SPDrillController.h"
#import "SPExportController.h"
#import "SPInspectorController.h"
#import "SPMovieController.h"
#import "SPPlayerController.h"
#import "SPPlaylistController.h"
#import "SPPlaylistItem.h"
#import "SPPreferencesController.h"
#import "SPPS3Remote.h"
#import "SPSettings.h"
#import "SPWiiRemote.h"

#define SPFilenameErrorKey				@"SPFilenameErrorKey"
#define SPRecoveryURLErrorKey			@"SPRecoveryURLErrorKey"


NSString * const SPSpiralErrorDomain	= @"SPSpiralErrorDomain";

static SPApplicationController			*SPSharedApplicationController;


@interface SPApplicationController(Private)

- (void)_update;

- (SPPlaylistRepresentedFile *)_representedFileForPath:(NSString *)path;

- (SPRemoteContext)_remoteContext;
- (void)_handleRemoteAction:(SPRemoteAction)action;

- (BOOL)_hasQuicktimeComponentWithName:(NSString *)name;
- (BOOL)_hasPerianInstalled;
- (BOOL)_hasFlip4MacWMVImportInstalled;

@end


@implementation SPApplicationController(Private)

- (void)_update {
	[_updater setAutomaticallyChecksForUpdates:[[SPSettings settings] boolForKey:SPCheckForUpdate]];
}



#pragma mark -

- (SPPlaylistRepresentedFile *)_representedFileForPath:(NSString *)path {
	SPPlaylistRepresentedFile	*file;
	
	file = [[SPPlaylistController playlistController] representedFileForPath:path];
	
	if(!file) {
		file = [SPPlaylistRepresentedFile fileWithPath:path];

		[[SPPlaylistController playlistController] addRepresentedFile:file];
	}
	
	return file;
}



#pragma mark -

- (SPRemoteContext)_remoteContext {
	SPMovieController	*movieController;
	id					delegate;
	
	delegate = [[NSApp keyWindow] delegate];
	
	if([delegate isKindOfClass:[SPPlayerController class]]) {
		return SPRemotePlayer;
	}
	else if([delegate isKindOfClass:[SPDrillController class]]) {
		movieController = [delegate movieController];
		
		if([movieController isInFullscreen])
			return SPRemoteFullscreenPlayer;
		else
			return SPRemoteDrillView;
	}
	else if([delegate isKindOfClass:[SPPlaylistController class]]) {
		return SPRemotePlaylist;
	}
    
	return SPRemoteNone;
}



- (void)_handleRemoteAction:(SPRemoteAction)action {
	SPMovieController		*movieController;
	double					rate;
	id						delegate;

	delegate = [[NSApp keyWindow] delegate];
	movieController = [self keyMovieController];
	
	switch(action) {
		case SPRemoteDoNothing:
			break;
		
		case SPRemoteUp:
			[delegate moveSelectionUp];
			break;
		
		case SPRemoteDown:
			[delegate moveSelectionDown];
			break;
		
		case SPRemoteRight:
			[delegate openSelection];
			break;
		
		case SPRemoteLeft:
			[delegate closeSelection];
			break;
		
		case SPRemoteEnter:
			[delegate openSelection];
			break;
		
		case SPRemotePlay:
			[movieController playAtRate:1.0];
			break;
		
		case SPRemotePlayOrPause:
			[movieController play];
			break;
		
		case SPRemotePause:
			[movieController pause];
			break;
		
		case SPRemoteStop:
			[movieController stop];
			break;
		
		case SPRemoteNext:
			[movieController openNext];
			break;
		
		case SPRemotePrevious:
			[movieController openPrevious];
			break;
		
		case SPRemoteBack:
			if([movieController isInFullscreen])
				[delegate closeWindow];
			else
				[delegate closeSelection];
			break;
			
		case SPRemoteScanForward:
			rate = [[SPSettings settings] doubleForKey:SPFastForwardFactor];
			
			[movieController playAtRate:rate];
			break;
		
		case SPRemoteScanBackward:
			rate = [[SPSettings settings] doubleForKey:SPFastForwardFactor];
			
			[movieController playAtRate:-rate];
			break;
		
		case SPRemoteStepForward:
			[movieController skipTime:[SPMovieController skipTimeIntervalForKey:NSUpArrowFunctionKey]];
			break;
		
		case SPRemoteStepBackward:
			[movieController skipTime:[SPMovieController skipTimeIntervalForKey:NSDownArrowFunctionKey]];
			break;
		
		case SPRemoteCycleSubtitleTracks:
			[movieController cycleSubtitleTracksForwards:YES];
			break;
		
		case SPRemoteCycleAudioTracks:
			[movieController cycleAudioTracksForwards:YES];
			break;
		
		case SPRemoteEject:
			[[NSWorkspace sharedWorkspace] ejectCDDrive];
			break;
		
		case SPRemoteShowHUD:
			[movieController orderFrontFullscreenHUDWindow];
			break;
			
		case SPRemoteDisplayTime:
			[movieController showStatusOverlay];
			break;
		
		case SPRemoteShowDrillView:
			[[SPDrillController drillController] showWindow:self];
			break;
		
		case SPRemoteHideDrillView:
			[delegate closeWindow];
			break;
		
		case SPRemoteCloseFullscreenMovie:
			[delegate closeWindow];
			break;
	}
}



#pragma mark -

- (BOOL)_hasQuicktimeComponentWithName:(NSString *)name {
	NSString		*libraryPath, *componentPath;
	
	for(libraryPath in NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES)) {
		componentPath = [libraryPath stringByAppendingPathComponent:[NSSWF:@"Quicktime/%@.component", name]];
		
		if([[NSFileManager defaultManager] fileExistsAtPath:componentPath])
			return YES;
	}
	
	return NO;
}



- (BOOL)_hasPerianInstalled {
	return [self _hasQuicktimeComponentWithName:@"Perian"];
}



- (BOOL)_hasFlip4MacWMVImportInstalled {
	return [self _hasQuicktimeComponentWithName:@"Flip4Mac WMV Import"];
}

@end



@implementation SPApplicationController

+ (SPApplicationController *)applicationController {
	return SPSharedApplicationController;
}



#pragma mark -

- (void)awakeFromNib {
	NSMutableDictionary		*dictionary;
	NSArray					*array;
	
	[[[QTMovie alloc] init] release];

	SPSharedApplicationController = self;
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:SPPreferencesDidChangeNotification];
	
	[_updater setSendsSystemProfile:YES];
	
#ifdef SPConfigurationRelease
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/sparkle.pl?file=spiral.xml"]];
#else
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/sparkle.pl?file=spiral-nightly.xml"]];
#endif
	
	[WIDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	[NSNumberFormatter setDefaultFormatterBehavior:NSNumberFormatterBehavior10_4];
	
	dictionary = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"org.perian.Perian"] mutableCopy] autorelease];
	
	/* http://trac.perian.org/browser/trunk/CommonUtils.c?rev=1186#L312 */
	array = [dictionary objectForKey:@"TransparentModeSubtitleAppList"];
	
	if(!array || ![array isKindOfClass:[NSArray class]])
		array = [NSArray arrayWithObjects:@"CoreMediaAuthoringSourcePropertyHelper", @"Front Row", @"QTPlayerHelper", nil];
	
	if(![array containsObject:@"Spiral"]) {
		array = [array arrayByAddingObject:@"Spiral"];
		
		[dictionary setObject:array forKey:@"TransparentModeSubtitleAppList"];
	}
	
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:dictionary forName:@"org.perian.Perian"];
	
	[[SPAppleRemote sharedRemote] setDelegate:self];
//	[[SPPS3Remote sharedRemote] setDelegate:self];
//	[[SPWiiRemote sharedRemote] setDelegate:self];
	
	[self _update];
}



- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	if([[SPSettings settings] boolForKey:SPShowPlaylist])
		[[SPPlaylistController playlistController] showWindow:self];

	if([[SPSettings settings] boolForKey:SPShowInspector])
		[[SPInspectorController inspectorController] showWindow:self];
}



- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSData			*data;
	SPPlaylistFile	*file;
	
	data = [[SPSettings settings] objectForKey:SPOpenFile];
	
	if(data) {
		file = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		if(file)
			[self openFile:[file resolvedPath] withPlaylistFile:file];
		
		[[SPSettings settings] removeObjectForKey:SPOpenFile];
	}
}



- (BOOL)application:(NSApplication *)application openFile:(NSString *)path {
	SPPlaylistRepresentedFile	*file;
	
	file = [self _representedFileForPath:path];
	
	return [self openFile:path withPlaylistFile:file];
}



- (NSError *)application:(NSApplication *)application willPresentError:(NSError *)error {
	NSMutableDictionary		*userInfo;
	NSString				*filename, *recoverySuggestion;
	
	if([error domain] == NSOSStatusErrorDomain && [error code] == -2048) {
		userInfo = [NSMutableDictionary dictionary];
		recoverySuggestion = [[[[error userInfo] objectForKey:NSUnderlyingErrorKey] userInfo] objectForKey:NSLocalizedDescriptionKey];
		
		if(!recoverySuggestion)
			recoverySuggestion = [[error userInfo] objectForKey:NSLocalizedDescriptionKey];

		if(!recoverySuggestion)
			recoverySuggestion = NSLS(@"The file is not a movie file.", @"Error description");
		
		filename = [[error userInfo] objectForKey:SPFilenameErrorKey];
		
		if([[[filename pathExtension] lowercaseString] isEqualToString:@"wmv"] && ![self _hasFlip4MacWMVImportInstalled]) {
			recoverySuggestion = [recoverySuggestion stringByAppendingFormat:@"\n\n%@",
				NSLS(@"Try installing Flip4Mac WMV, a free QuickTime component that adds native support for the Windows Media file format.",
					 @"Error recovery suggestion")];
		
			[userInfo setObject:[NSArray arrayWithObjects:
								NSLS(@"OK", @"Error button title"),
								NSLS(@"Flip4Mac WMV Homepage", @"Error button title"),
								NULL]
						 forKey:NSLocalizedRecoveryOptionsErrorKey];
			[userInfo setObject:self forKey:NSRecoveryAttempterErrorKey];
			[userInfo setObject:[WIURL URLWithString:@"http://www.flip4mac.com/wmv_download.htm"] forKey:SPRecoveryURLErrorKey];
		}
		else if(![self _hasPerianInstalled]) {
			recoverySuggestion = [recoverySuggestion stringByAppendingFormat:@"\n\n%@",
				NSLS(@"Try installing Perian, a free QuickTime component that adds native support for many popular video formats.",
					 @"Error recovery suggestion")];
		
			[userInfo setObject:[NSArray arrayWithObjects:
								NSLS(@"OK", @"Error button title"),
								NSLS(@"Perian Homepage", @"Error button title"),
								NULL]
						 forKey:NSLocalizedRecoveryOptionsErrorKey];
			[userInfo setObject:self forKey:NSRecoveryAttempterErrorKey];
			[userInfo setObject:[WIURL URLWithString:@"http://www.perian.org/"] forKey:SPRecoveryURLErrorKey];
		}
		
		[userInfo setObject:recoverySuggestion forKey:NSLocalizedRecoverySuggestionErrorKey];
		[userInfo setObject:NSLS(@"The movie could not be opened.", @"Error description") forKey:NSLocalizedDescriptionKey];
		
		return [NSError errorWithDomain:[error domain] code:[error code] userInfo:userInfo];
	}
	
	return error;
}



- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)optionIndex {
	if(optionIndex == 1)
		[[NSWorkspace sharedWorkspace] openURL:[[[error userInfo] objectForKey:SPRecoveryURLErrorKey] URL]];
	
	return NO;
}



- (void)applicationDidBecomeActive:(NSNotification *)notification {
	[[SPAppleRemote sharedRemote] startListening];
	
	if(_activated && ![SPPlayerController currentPlayerController])
		[[SPPlaylistController playlistController] showWindow:self];
	
	_activated = YES;
}



- (void)applicationWillResignActive:(NSNotification *)notification {
	id		delegate;
	
	[[SPAppleRemote sharedRemote] stopListening];
	
	delegate = [[NSApp keyWindow] delegate];
	
	if(([delegate isKindOfClass:[SPPlayerController class]] && [(SPMovieController *) [delegate movieController] isInFullscreen]) ||
	   [delegate isKindOfClass:[SPDrillController class]]) {
		[NSApp activateIgnoringOtherApps:YES];
	}
}



- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if([[SPExportController exportController] numberOfExports] > 0 ||
	   [[SPPlaylistController playlistController] numberOfExports] > 0) {
		return [(WIApplication *) NSApp runTerminationDelayPanelWithTimeInterval:30.0 message:NSLS(@"There are unfinished exports. Quitting now will terminate them.", @"Quit warning")];
	}
	
	return NSTerminateNow;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[[SPSettings settings] setBool:[[[SPPlaylistController playlistController] window] isVisible]
							forKey:SPShowPlaylist];

	[[SPSettings settings] setBool:[[[SPInspectorController inspectorController] window] isVisible]
							forKey:SPShowInspector];

	[[SPExportController exportController] stopAllExports];
	[[SPPlaylistController playlistController] stopAllExports];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)menuNeedsUpdate:(NSMenu *)menu {
	NSString				*string;
	SPMovieController		*movieController;
	NSUInteger				index = 0;
	SPPlaylistRepeatMode	repeatMode;
	
	movieController = [self keyMovieController];

	if(menu == _playlistMenu) {
		[_shuffleMenuItem setState:[[SPPlaylistController playlistController] shuffle]];

		repeatMode = [[SPPlaylistController playlistController] repeatMode];
		
		[_repeatOffMenuItem setState:(repeatMode == SPPlaylistRepeatOff)];
		[_repeatAllMenuItem setState:(repeatMode == SPPlaylistRepeatAll)];
		[_repeatOneMenuItem setState:(repeatMode == SPPlaylistRepeatOne)];
	}
	else if(menu == _aspectRatioMenu) {
		if([_aspectRatioMenu numberOfItems] == 0) {
			for(string in [SPMovieController aspectRatioNames])
				[_aspectRatioMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(aspectRatio:)]];
		}
		
		if(movieController)
			[_aspectRatioMenu setOnStateForItemsWithTag:[movieController aspectRatio]];
	}
	else if(menu == _chaptersMenu || menu == _audioTrackMenu || menu == _subtitleTrackMenu) {
		if(!movieController) {
			[menu removeAllItems];
		} else {
			if(menu == _chaptersMenu) {
				[_chaptersMenu removeAllItems];
				
				for(string in [movieController chapterNames])
					[_chaptersMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(chapter:)]];
			}
			else if(menu == _audioTrackMenu) {
				[_audioTrackMenu removeAllItems];
				
				for(string in [movieController audioTrackNamesForDisplay:YES])
					[_audioTrackMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(audioTrack:)]];

				[_audioTrackMenu setOnStateForItemsWithTag:[movieController audioTrack]];
			}
			else if(menu == _subtitleTrackMenu) {
				[_subtitleTrackMenu removeAllItems];
				
				for(string in [movieController subtitleTrackNamesForDisplay:YES])
					[_subtitleTrackMenu addItem:[NSMenuItem itemWithTitle:string tag:index++ action:@selector(subtitleTrack:)]];

				[_subtitleTrackMenu setOnStateForItemsWithTag:[movieController subtitleTrack]];
			}
		}
		
		if([menu numberOfItems] == 0)
			[menu addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"View menu item")]];
	}
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	
	selector = [item action];
	
	if(selector == @selector(export:))
		return ([self keyMovieController] != NULL);
	
	return YES;
}



#pragma mark -

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
	return NO;
}



- (void)updaterWillRelaunchApplication:(SUUpdater *)updater {
	SPPlaylistFile		*file;
	
	file = [[self keyMovieController] playlistFile];
	
	if(file)
		[[SPSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:file] forKey:SPOpenFile];
}



#pragma mark -

- (void)appleRemotePressedButton:(SPAppleRemoteButton)button {
	SPRemoteAction		action;
	
	action = [[SPAppleRemote sharedRemote] actionForButton:button inContext:[self _remoteContext]];
	
	[self _handleRemoteAction:action];
	
	_holdingAppleRemoteButton = NO;
}



- (void)appleRemoteHeldButton:(SPAppleRemoteButton)button {
	_holdingAppleRemoteButton = YES;
		
	[self performSelector:@selector(holdAppleRemoteButton:) 
			   withObject:[NSNumber numberWithInt:button]];
}



- (void)holdAppleRemoteButton:(NSNumber *)button {
	SPRemoteAction		action;
	
	if(_holdingAppleRemoteButton) {
		action = [[SPAppleRemote sharedRemote] actionForButton:[button intValue] inContext:[self _remoteContext]];
		
		[self _handleRemoteAction:action];
		
		[self performSelector:@selector(holdAppleRemoteButton:) 
				   withObject:button
				   afterDelay:0.05];
	}
}



- (void)appleRemoteReleasedButton {
	SPMovieController		*movieController;

	movieController = [self keyMovieController];
	
	if(movieController) {
		if(fabs([movieController rate]) > 1.0)
			[movieController playAtRate:1.0];
	}

	_holdingAppleRemoteButton = NO;
}



#pragma mark -

- (BOOL)PS3RemoteShouldDisconnect:(SPPS3Remote *)remote {
	return ([self keyMovieController] == NULL);
}



- (void)PS3Remote:(SPPS3Remote *)remote pressedButton:(SPPS3RemoteButton)button {
	SPRemoteAction		action;
	
	if([NSApp isActive]) {
		action = [[SPPS3Remote sharedRemote] actionForButton:button inContext:[self _remoteContext]];
		
		[self _handleRemoteAction:action];

		_holdingPS3RemoteButton = NO;
	}
}



- (void)PS3Remote:(SPPS3Remote *)remote heldButton:(SPPS3RemoteButton)button {
	if([NSApp isActive]) {
		_holdingPS3RemoteButton = YES;
		
		[self performSelector:@selector(holdPS3RemoteButton:) 
				   withObject:[NSNumber numberWithInt:button]];
	}
}



- (void)holdPS3RemoteButton:(NSNumber *)button {
	SPRemoteAction		action;
	
	if([NSApp isActive] && _holdingPS3RemoteButton) {
		action = [[SPPS3Remote sharedRemote] actionForButton:[button intValue] inContext:[self _remoteContext]];
		
		[self _handleRemoteAction:action];
		 
		[self performSelector:@selector(holdPS3RemoteButton:) 
				   withObject:button
				   afterDelay:0.05];
	}
}



- (void)PS3RemoteReleasedButton:(SPPS3Remote *)remote {
	if([NSApp isActive])
		_holdingPS3RemoteButton = NO;
}



#pragma mark -

- (BOOL)wiiRemoteShouldDisconnect:(SPWiiRemote *)remote {
	return ([self keyMovieController] == NULL);
}



- (void)wiiRemote:(SPWiiRemote *)remote pressedButton:(SPWiiRemoteButton)button {
	SPRemoteAction		action;
	
	if([NSApp isActive]) {
		action = [[SPWiiRemote sharedRemote] actionForButton:button inContext:[self _remoteContext]];
		
		[self _handleRemoteAction:action];
		
		_holdingWiiRemoteButton = NO;
	}
}



- (void)wiiRemote:(SPWiiRemote *)remote heldButton:(SPWiiRemoteButton)button {
	if([NSApp isActive]) {
		_holdingWiiRemoteButton = YES;
		
		[self performSelector:@selector(holdWiiRemoteButton:) 
				   withObject:[NSNumber numberWithInt:button]];
	}
}



- (void)holdWiiRemoteButton:(NSNumber *)button {
	SPRemoteAction		action;
	
	if([NSApp isActive] && _holdingWiiRemoteButton) {
		action = [[SPWiiRemote sharedRemote] actionForButton:[button intValue] inContext:[self _remoteContext]];
		
		[self _handleRemoteAction:action];
		 
		[self performSelector:@selector(holdWiiRemoteButton:) 
				   withObject:button
				   afterDelay:0.05];
	}
}



- (void)wiiRemoteReleasedButton:(SPWiiRemote *)remote {
	if([NSApp isActive])
		_holdingWiiRemoteButton = NO;
}



#pragma mark -

- (SPMovieController *)keyMovieController {
	id		delegate;
	
	delegate = [[NSApp keyWindow] delegate];
	
	if([delegate isKindOfClass:[SPPlayerController class]] || [delegate isKindOfClass:[SPDrillController class]])
		return [delegate movieController];
	
	return NULL;
}



#pragma mark -

- (BOOL)openFile:(NSString *)path withPlaylistFile:(SPPlaylistFile *)file {
	return [self openFile:path withPlaylistFile:file resumePlaying:YES enterFullscreen:NO];
}



- (BOOL)openFile:(NSString *)path withPlaylistFile:(SPPlaylistFile *)file resumePlaying:(BOOL)resumePlaying enterFullscreen:(BOOL)enterFullscreen {
	NSDictionary			*attributes;
	NSError					*error = NULL;
	QTMovie					*movie;
	SPPlayerController		*controller;
	
	controller = [SPPlayerController currentPlayerController];
	
	if(!controller)
		controller = [[[SPPlayerController alloc] init] autorelease];
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		path,							QTMovieFileNameAttribute,
//		[NSNumber numberWithBool:YES],	@"QTMovieOpenForPlaybackAttribute",
		NULL];
	movie = [[QTMovie alloc] initWithAttributes:attributes error:&error];
	
	if(!movie) {
		if(error) {
			if(![[controller movieController] isInFullscreen]) {
				error = [error errorByAddingUserInfo:
					[NSDictionary dictionaryWithObject:[path lastPathComponent] forKey:SPFilenameErrorKey]];

				[[NSDocumentController sharedDocumentController] presentError:error];
			}
		}
		
		return NO;
	}
	
	[SPPlaylistLoader setMovieDataForFile:file movie:movie];
	
	[controller setMovie:movie playlistFile:file];
	[[controller window] setRepresentedFilename:path];
	[[controller window] setTitle:[path lastPathComponent]];
	
	if(![[controller movieController] isInFullscreen])
		[controller showWindow:self];
	
	if(resumePlaying)
		[[controller movieController] resumePlaying];
	
	if(enterFullscreen)
		[controller fullscreen:self];
	
	[movie release];
	
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[[WIURL fileURLWithPath:path] URL]];
	
	return YES;
}



#pragma mark -

- (IBAction)about:(id)sender {
	NSMutableDictionary		*infoDictionary;
	
	infoDictionary = [[[[self bundle] infoDictionary] mutableCopy] autorelease];
	
	[infoDictionary addEntriesFromDictionary:[[self bundle] localizedInfoDictionary]];
	
	[_aboutNameTextField setStringValue:[infoDictionary objectForKey:@"CFBundleName"]];
	[_aboutVersionTextField setStringValue:[NSSWF:@"%@ %@ (%@)",
		NSLS(@"Version", @"About box title"),
		[infoDictionary objectForKey:@"CFBundleShortVersionString"],
		[infoDictionary objectForKey:@"CFBundleVersion"]]];
	[_aboutCreditsTextView setAttributedString:
		[[[NSAttributedString alloc] initWithPath:[[self bundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:NULL] autorelease]];
	[_aboutCreditsTextView scrollToTop];
	[_aboutCopyrightTextField setStringValue:[infoDictionary objectForKey:@"NSHumanReadableCopyright"]];
	[_aboutPanel center];
	[_aboutPanel makeKeyAndOrderFront:self];
}



- (IBAction)preferences:(id)sender {
	[[SPPreferencesController preferencesController] showWindow:self];
}



- (IBAction)openFile:(id)sender {
	NSOpenPanel				*openPanel;
	NSString				*path;
	SPPlaylistFile			*file;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setAllowsMultipleSelection:NO];
	
	if([openPanel runModalForTypes:[[SPMovieController movieFileTypes] allObjects]] == NSOKButton) {
		path = [openPanel filename];
		file = [self _representedFileForPath:path];
		
		[self openFile:path withPlaylistFile:file];
	}
}



- (IBAction)export:(id)sender {
	NSString			*audioPattern, *subtitlePattern;
	SPMovieController	*movieController;
	id					delegate;
	
	movieController = [self keyMovieController];
	delegate = [[NSApp keyWindow] delegate];
	
	if(movieController && [delegate isKindOfClass:[SPPlayerController class]]) {
		audioPattern = ([movieController audioTrack] > 0)
			? [[movieController audioTrackNamesForDisplay:NO] objectAtIndex:[movieController audioTrack]]
			: NULL;
		
		subtitlePattern = ([movieController subtitleTrack] > 0)
			? [[movieController subtitleTrackNamesForDisplay:NO] objectAtIndex:[movieController subtitleTrack]]
			: NULL;

		[[SPExportController exportController] beginSavePanelForWindow:[delegate window]
																 movie:[movieController movie]
														  playlistFile:[movieController playlistFile]
														  audioPattern:audioPattern
													   subtitlePattern:subtitlePattern];
	}
}



- (IBAction)fullscreen:(id)sender {
	[self browseInFullscreen:sender];
}



- (IBAction)browseInFullscreen:(id)sender {
	[[SPDrillController drillController] showWindow:self];
}



- (IBAction)shuffle:(id)sender {
	[[SPPlaylistController playlistController] setShuffle:![[SPPlaylistController playlistController] shuffle]];
}



- (IBAction)repeatMode:(id)sender {
	[[SPPlaylistController playlistController] setRepeatMode:[sender tag]];
}



- (IBAction)inspector:(id)sender {
	if(![[[SPInspectorController inspectorController] window] isVisible])
		[[SPInspectorController inspectorController] showWindow:self];
	else
		[[SPInspectorController inspectorController] close];
}



- (IBAction)playlist:(id)sender {
	[[SPPlaylistController playlistController] showWindow:self];
}



#pragma mark -

- (IBAction)releaseNotes:(id)sender {
	NSString		*path;
	
	path = [[self bundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
	
	[[WIReleaseNotesController releaseNotesController]
		setReleaseNotesWithRTF:[NSData dataWithContentsOfFile:path]];
	[[WIReleaseNotesController releaseNotesController] showWindow:self];
}



- (IBAction)crashReports:(id)sender {
	[[WICrashReportsController crashReportsController] setApplicationName:[NSApp name]];
	[[WICrashReportsController crashReportsController] showWindow:self];
}

@end
