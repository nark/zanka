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
#import "SPPreferencesController.h"
#import "SPSettings.h"
#import "SPShortcutTextField.h"
#import "SPShortcutTextView.h"

NSString * const SPPreferencesDidChangeNotification		= @"SPPreferencesDidChangeNotification";


@interface SPPreferencesController(Private)

- (void)_updateFastForwardSpeedTextField;
- (void)_updatePS3RemoteStatus;
- (void)_updateWiiRemoteStatus;

@end


@implementation SPPreferencesController(Private)

- (void)_updateFastForwardSpeedTextField {
	[_fastForwardSpeedTextField setStringValue:[NSSWF:
		NSLS(@"1 minute takes %u seconds.", @"Fast forward speed label"),
		(NSUInteger) ceil(60.0 / [[SPSettings settings] doubleForKey:SPFastForwardFactor])]];
}



- (void)_updatePS3RemoteStatus {
	SPPS3Remote		*remote;

	remote = [SPPS3Remote sharedRemote];
	
	if(![remote hasDevice]) {
		[_PS3RemoteTextField setStringValue:NSLS(@"No remote found", @"Remote status")];
		[_PS3RemoteImageView setImage:[NSImage imageNamed:@"RemoteNoDeviceFound"]];
		[_PS3RemoteProgressIndicator stopAnimation:self];
	}
	else if([remote isConnected]) {
		[_PS3RemoteTextField setStringValue:NSLS(@"Connected", @"Remote status")];
		[_PS3RemoteImageView setImage:[NSImage imageNamed:@"RemoteConnected"]];
		[_PS3RemoteProgressIndicator stopAnimation:self];
	}
	else if([remote isConnecting]) {
		[_PS3RemoteTextField setStringValue:NSLS(@"Connecting...", @"Remote status")];
		[_PS3RemoteImageView setImage:NULL];
		[_PS3RemoteProgressIndicator startAnimation:self];
	}
	else {
		[_PS3RemoteTextField setStringValue:NSLS(@"Not connected", @"Remote status")];
		[_PS3RemoteImageView setImage:[NSImage imageNamed:@"RemoteNotConnected"]];
		[_PS3RemoteProgressIndicator stopAnimation:self];
	}
}



- (void)_updateWiiRemoteStatus {
	SPWiiRemote		*remote;

	remote = [SPWiiRemote sharedRemote];
	
	if(![remote hasDevice]) {
		[_wiiRemoteTextField setStringValue:NSLS(@"No remote found", @"Remote status")];
		[_wiiRemoteImageView setImage:[NSImage imageNamed:@"RemoteNoDeviceFound"]];
		[_wiiRemoteProgressIndicator stopAnimation:self];
	}
	else if([remote isConnected]) {
		[_wiiRemoteTextField setStringValue:NSLS(@"Connected", @"Remote status")];
		[_wiiRemoteImageView setImage:[NSImage imageNamed:@"RemoteConnected"]];
		[_wiiRemoteProgressIndicator stopAnimation:self];
	}
	else if([remote isConnecting]) {
		[_wiiRemoteTextField setStringValue:NSLS(@"Connecting...", @"Remote status")];
		[_wiiRemoteImageView setImage:NULL];
		[_wiiRemoteProgressIndicator startAnimation:self];
	}
	else {
		[_wiiRemoteTextField setStringValue:NSLS(@"Not connected", @"Remote status")];
		[_wiiRemoteImageView setImage:[NSImage imageNamed:@"RemoteNotConnected"]];
		[_wiiRemoteProgressIndicator stopAnimation:self];
	}
}

@end



@implementation SPPreferencesController

+ (SPPreferencesController *)preferencesController {
	static SPPreferencesController		*preferencesController;
	
	if(!preferencesController)
		preferencesController = [[self alloc] init];
	
	return preferencesController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Preferences"];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bluetoothRemoteWillConnect:)
			   name:SPBluetoothRemoteWillConnect];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bluetoothRemoteDidConnect:)
			   name:SPBluetoothRemoteDidConnect];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bluetoothRemoteDidDisconnect:)
			   name:SPBluetoothRemoteDidDisconnect];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_identifiers release];
	[_views release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSArray		*languages;
	
	[self addPreferenceView:_generalView
					   name:NSLS(@"General", @"General preferences")
					  image:[NSImage imageNamed:@"General"]];
	
	[self addPreferenceView:_keyBindingsView
					   name:NSLS(@"Key Bindings", @"Key bindings preferences")
					  image:[NSImage imageNamed:@"KeyBindings"]];
	
	// Remove remotes preferences until non-Apple remotes can be made to work correctly
/*	[self addPreferenceView:_remotesView
					   name:NSLS(@"Remotes", @"Remotes preferences")
					  image:[NSImage imageNamed:@"Remotes"]];*/
	
	languages = [NSArray arrayWithObjects:
		NSLS(@"English", @"Language"),
		NSLS(@"French", @"Language"),
		NSLS(@"German", @"Language"),
		NSLS(@"Italian", @"Language"),
		NSLS(@"Dutch", @"Language"),
		NSLS(@"Swedish", @"Language"),
		NSLS(@"Spanish", @"Language"),
		NSLS(@"Danish", @"Language"),
		NSLS(@"Portugese", @"Language"),
		NSLS(@"Norwegian", @"Language"),
		NSLS(@"Hebrew", @"Language"),
		NSLS(@"Japanese", @"Language"),
		NSLS(@"Arabic", @"Language"),
		NSLS(@"Greek", @"Language"),
		NSLS(@"Icelandic", @"Language"),
		NULL];
	
	[_preferredAudioComboBox addItemsWithObjectValues:languages];
	[_preferredSubtitleComboBox addItemsWithObjectValues:languages];

	[_playMoviesWhenOpenedButton setState:[[SPSettings settings] boolForKey:SPPlayMoviesWhenOpened]];
	[_simplifyFilenamesButton setState:[[SPSettings settings] boolForKey:SPSimplifyFilenames]];
	[_checkForUpdateButton setState:[[SPSettings settings] boolForKey:SPCheckForUpdate]];
	[_defaultSizePopUpButton selectItemWithTag:[[SPSettings settings] intForKey:SPDefaultScaling]];
	[_resumeBehaviorMatrix selectCellWithTag:[[SPSettings settings] intForKey:SPResumePlayingBehavior]];
	[_fastForwardSpeedSlider setDoubleValue:sqrt([[SPSettings settings] doubleForKey:SPFastForwardFactor])];
	[_preferredAudioComboBox setStringValue:[[SPSettings settings] objectForKey:SPPreferredAudioPattern]];
	[_preferredSubtitleComboBox setStringValue:[[SPSettings settings] objectForKey:SPPreferredSubtitlePattern]];
	
	[self _updateFastForwardSpeedTextField];

	[_shortJumpBackwardTextField setStringValue:[[SPSettings settings] objectForKey:SPShortJumpBackwardShortcut]];
	[_shortJumpForwardTextField setStringValue:[[SPSettings settings] objectForKey:SPShortJumpForwardShortcut]];
	[_shortJumpIntervalPopUpButton selectItemWithTag:[[SPSettings settings] intForKey:SPShortJumpInterval]];
	[_mediumJumpBackwardTextField setStringValue:[[SPSettings settings] objectForKey:SPMediumJumpBackwardShortcut]];
	[_mediumJumpForwardTextField setStringValue:[[SPSettings settings] objectForKey:SPMediumJumpForwardShortcut]];
	[_mediumJumpIntervalPopUpButton selectItemWithTag:[[SPSettings settings] intForKey:SPMediumJumpInterval]];
	[_longJumpBackwardTextField setStringValue:[[SPSettings settings] objectForKey:SPLongJumpBackwardShortcut]];
	[_longJumpForwardTextField setStringValue:[[SPSettings settings] objectForKey:SPLongJumpForwardShortcut]];
	[_longJumpIntervalPopUpButton selectItemWithTag:[[SPSettings settings] intForKey:SPLongJumpInterval]];
	[_cycleAudioTrackTextField setStringValue:[[SPSettings settings] objectForKey:SPCycleAudioTrackShortcut]];
	[_cycleSubtitleTrackTextField setStringValue:[[SPSettings settings] objectForKey:SPCycleSubtitleTrackShortcut]];
	[_cycleAspectRatioTextField setStringValue:[[SPSettings settings] objectForKey:SPCycleAspectRatioShortcut]];

	[self _updatePS3RemoteStatus];
	[self _updateWiiRemoteStatus];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[self preferredAudioTrack:self];
	[self preferredSubtitle:self];
}



- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)object {
	static SPShortcutTextView		*fieldEditor;
	
	if([object isKindOfClass:[SPShortcutTextField class]]) {
		if(!fieldEditor) {
			fieldEditor = [[SPShortcutTextView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
			[fieldEditor setFieldEditor:YES];
		}
		
		return fieldEditor;
	}
	
	return NULL;
}



- (void)bluetoothRemoteWillConnect:(NSNotification *)notification {
	id		remote;
	
	remote = [notification object];
		
	if(remote == [SPPS3Remote sharedRemote])
		[self _updatePS3RemoteStatus];
	else if(remote == [SPWiiRemote sharedRemote])
		[self _updateWiiRemoteStatus];
}



- (void)bluetoothRemoteDidConnect:(NSNotification *)notification {
	id		remote;
	
	remote = [notification object];
	
	if(remote == [SPPS3Remote sharedRemote])
		[self _updatePS3RemoteStatus];
	else if(remote == [SPWiiRemote sharedRemote])
		[self _updateWiiRemoteStatus];
}



- (void)bluetoothRemoteDidDisconnect:(NSNotification *)notification {
	id		remote;
	
	remote = [notification object];
		
	if(remote == [SPPS3Remote sharedRemote])
		[self _updatePS3RemoteStatus];
	else if(remote == [SPWiiRemote sharedRemote])
		[self _updateWiiRemoteStatus];
}



#pragma mark -

- (IBAction)playMoviesWhenOpened:(id)sender {
	[[SPSettings settings] setBool:[_playMoviesWhenOpenedButton state] forKey:SPPlayMoviesWhenOpened];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)simplifyFilenames:(id)sender {
	[[SPSettings settings] setBool:[_simplifyFilenamesButton state] forKey:SPSimplifyFilenames];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)checkForUpdate:(id)sender {
	[[SPSettings settings] setBool:[_checkForUpdateButton state] forKey:SPCheckForUpdate];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)defaultSize:(id)sender {
	[[SPSettings settings] setInt:[_defaultSizePopUpButton tagOfSelectedItem] forKey:SPDefaultScaling];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)resumeBehavior:(id)sender {
	[[SPSettings settings] setInt:[[_resumeBehaviorMatrix selectedCell] tag] forKey:SPResumePlayingBehavior];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)fastForwardSpeed:(id)sender {
	[[SPSettings settings] setDouble:pow(2.0, [_fastForwardSpeedSlider doubleValue]) forKey:SPFastForwardFactor];
	
	[self _updateFastForwardSpeedTextField];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)preferredAudioTrack:(id)sender {
	[[SPSettings settings] setObject:[_preferredAudioComboBox stringValue] forKey:SPPreferredAudioPattern];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)preferredSubtitle:(id)sender {
	[[SPSettings settings] setObject:[_preferredSubtitleComboBox stringValue] forKey:SPPreferredSubtitlePattern];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



#pragma mark -

- (IBAction)shortJumpBackward:(id)sender {
	[[SPSettings settings] setObject:[_shortJumpBackwardTextField stringValue] forKey:SPShortJumpBackwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)shortJumpForward:(id)sender {
	[[SPSettings settings] setObject:[_shortJumpForwardTextField stringValue] forKey:SPShortJumpForwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)shortJumpInterval:(id)sender {
	[[SPSettings settings] setInt:[_shortJumpIntervalPopUpButton tagOfSelectedItem] forKey:SPShortJumpInterval];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)mediumJumpBackward:(id)sender {
	[[SPSettings settings] setObject:[_mediumJumpBackwardTextField stringValue] forKey:SPMediumJumpBackwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)mediumJumpForward:(id)sender {
	[[SPSettings settings] setObject:[_mediumJumpForwardTextField stringValue] forKey:SPMediumJumpForwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)mediumJumpInterval:(id)sender {
	[[SPSettings settings] setInt:[_mediumJumpIntervalPopUpButton tagOfSelectedItem] forKey:SPMediumJumpInterval];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)longJumpBackward:(id)sender {
	[[SPSettings settings] setObject:[_longJumpBackwardTextField stringValue] forKey:SPLongJumpBackwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)longJumpForward:(id)sender {
	[[SPSettings settings] setObject:[_longJumpForwardTextField stringValue] forKey:SPLongJumpForwardShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)longJumpInterval:(id)sender {
	[[SPSettings settings] setInt:[_longJumpIntervalPopUpButton tagOfSelectedItem] forKey:SPLongJumpInterval];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)cycleAudioTrack:(id)sender {
	[[SPSettings settings] setObject:[_cycleAudioTrackTextField stringValue] forKey:SPCycleAudioTrackShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)cycleSubtitleTrack:(id)sender {
	[[SPSettings settings] setObject:[_cycleSubtitleTrackTextField stringValue] forKey:SPCycleSubtitleTrackShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}



- (IBAction)cycleAspectRatio:(id)sender {
	[[SPSettings settings] setObject:[_cycleAspectRatioTextField stringValue] forKey:SPCycleAspectRatioShortcut];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPPreferencesDidChangeNotification];
}

@end
