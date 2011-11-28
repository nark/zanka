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

extern NSString * const						SPPreferencesDidChangeNotification;

@class SPShortcutTextField;

@interface SPPreferencesController : WIPreferencesController {
	IBOutlet NSView							*_generalView;
	IBOutlet NSView							*_keyBindingsView;
	IBOutlet NSView							*_remotesView;
	
	IBOutlet NSButton						*_playMoviesWhenOpenedButton;
	IBOutlet NSButton						*_simplifyFilenamesButton;
	IBOutlet NSButton						*_checkForUpdateButton;
	IBOutlet NSPopUpButton					*_defaultSizePopUpButton;
	IBOutlet NSMatrix						*_resumeBehaviorMatrix;
	IBOutlet NSSlider						*_fastForwardSpeedSlider;
	IBOutlet NSTextField					*_fastForwardSpeedTextField;
	IBOutlet NSComboBox						*_preferredAudioComboBox;
	IBOutlet NSComboBox						*_preferredSubtitleComboBox;
	
	IBOutlet SPShortcutTextField			*_shortJumpBackwardTextField;
	IBOutlet SPShortcutTextField			*_shortJumpForwardTextField;
	IBOutlet NSPopUpButton					*_shortJumpIntervalPopUpButton;
	IBOutlet SPShortcutTextField			*_mediumJumpBackwardTextField;
	IBOutlet SPShortcutTextField			*_mediumJumpForwardTextField;
	IBOutlet NSPopUpButton					*_mediumJumpIntervalPopUpButton;
	IBOutlet SPShortcutTextField			*_longJumpBackwardTextField;
	IBOutlet SPShortcutTextField			*_longJumpForwardTextField;
	IBOutlet NSPopUpButton					*_longJumpIntervalPopUpButton;
	IBOutlet SPShortcutTextField			*_cycleAudioTrackTextField;
	IBOutlet SPShortcutTextField			*_cycleSubtitleTrackTextField;
	IBOutlet SPShortcutTextField			*_cycleAspectRatioTextField;

	IBOutlet NSImageView					*_PS3RemoteImageView;
	IBOutlet NSTextField					*_PS3RemoteTextField;
	IBOutlet NSProgressIndicator			*_PS3RemoteProgressIndicator;
	IBOutlet NSImageView					*_wiiRemoteImageView;
	IBOutlet NSTextField					*_wiiRemoteTextField;
	IBOutlet NSProgressIndicator			*_wiiRemoteProgressIndicator;
}

+ (SPPreferencesController *)preferencesController;

- (IBAction)playMoviesWhenOpened:(id)sender;
- (IBAction)simplifyFilenames:(id)sender;
- (IBAction)checkForUpdate:(id)sender;
- (IBAction)defaultSize:(id)sender;
- (IBAction)resumeBehavior:(id)sender;
- (IBAction)fastForwardSpeed:(id)sender;
- (IBAction)preferredAudioTrack:(id)sender;
- (IBAction)preferredSubtitle:(id)sender;

- (IBAction)shortJumpBackward:(id)sender;
- (IBAction)shortJumpForward:(id)sender;
- (IBAction)shortJumpInterval:(id)sender;
- (IBAction)mediumJumpBackward:(id)sender;
- (IBAction)mediumJumpForward:(id)sender;
- (IBAction)mediumJumpInterval:(id)sender;
- (IBAction)longJumpBackward:(id)sender;
- (IBAction)longJumpForward:(id)sender;
- (IBAction)longJumpInterval:(id)sender;
- (IBAction)cycleAudioTrack:(id)sender;
- (IBAction)cycleSubtitleTrack:(id)sender;
- (IBAction)cycleAspectRatio:(id)sender;

@end
