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

#import "AppleRemote.h"

@implementation SPAppleRemote

+ (SPAppleRemote *)sharedRemote {
	static SPAppleRemote		*sharedRemote;
	
	if(!sharedRemote)
		sharedRemote = [[self alloc] init];
	
	return sharedRemote;
}



- (id)init { 
	self = [super init];
	
	_remote = [[AppleRemote alloc] initWithDelegate:self];

	return self;
}



- (void)dealloc {
	[_remote release];

	[super dealloc];
}



#pragma mark -

- (void)sendRemoteButtonEvent:(RemoteControlEventIdentifier)event pressedDown:(BOOL)pressedDown remoteControl:(RemoteControl *)remoteControl {
	if(pressedDown) {
		switch(event) {
			case kRemoteButtonPlus:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonVolumePlus];
				break;
				
			case kRemoteButtonMinus:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonVolumeMinus];
				break;
				
			case kRemoteButtonMenu:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonMenu];
				break;
				
			case kRemoteButtonPlay:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonPlay];
				break;
				
			case kRemoteButtonRight:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonRight];
				break;
				
			case kRemoteButtonLeft:
				if(_delegateAppleRemotePressedButton)
					[delegate appleRemotePressedButton:SPAppleRemoteButtonLeft];
				break;
				
			case kRemoteButtonPlus_Hold:
				break;
				
			case kRemoteButtonMinus_Hold:	
				break;
				
			case kRemoteButtonMenu_Hold:	
				if(_delegateAppleRemoteHeldButton)
					[delegate appleRemoteHeldButton:SPAppleRemoteButtonMenuHold];
				break;
				
			case kRemoteButtonPlay_Hold:	
				break;
				
			case kRemoteButtonRight_Hold:
				if(_delegateAppleRemoteHeldButton)
					[delegate appleRemoteHeldButton:SPAppleRemoteButtonRightHold];
				break;
				
			case kRemoteButtonLeft_Hold:
				if(_delegateAppleRemoteHeldButton)
					[delegate appleRemoteHeldButton:SPAppleRemoteButtonLeftHold];
				break;
				
			case kRemoteControl_Switched:
				break;
		}
	} else {
		if(_delegateAppleRemoteReleasedButton)
			[delegate appleRemoteReleasedButton];
	}
}



#pragma mark -

- (void)setDelegate:(id <SPAppleRemoteDelegate>)aDelegate {
	delegate = aDelegate;
	
	_delegateAppleRemotePressedButton	= [delegate respondsToSelector:@selector(appleRemotePressedButton:)];
	_delegateAppleRemoteHeldButton		= [delegate respondsToSelector:@selector(appleRemoteHeldButton:)];
	_delegateAppleRemoteReleasedButton	= [delegate respondsToSelector:@selector(appleRemoteReleasedButton)];
}



- (id <SPAppleRemoteDelegate>)delegate {
	return delegate;
}



#pragma mark -

- (void)startListening {
	[_remote startListening:self];
}



- (void)stopListening {
	[_remote stopListening:self];
}



- (BOOL)isListening {
	return [_remote isListeningToRemote];
}



#pragma mark -

- (SPRemoteAction)actionForButton:(SPAppleRemoteButton)button inContext:(SPRemoteContext)context {
	switch(button) {
		case SPAppleRemoteButtonVolumePlus:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteCycleSubtitleTracks;
			else
				return SPRemoteUp;
			break;

		case SPAppleRemoteButtonVolumeMinus:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteCycleAudioTracks;
			else
				return SPRemoteDown;
			break;
		
		case SPAppleRemoteButtonMenu:
			if(context == SPRemoteDrillView)
				return SPRemoteHideDrillView;
			else if(context == SPRemoteFullscreenPlayer)
				return SPRemoteCloseFullscreenMovie;
			else
				return SPRemoteShowDrillView;
			break;
		
		case SPAppleRemoteButtonPlay:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemotePlayOrPause;
			else
				return SPRemoteEnter;
			break;
		
		case SPAppleRemoteButtonRight:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteNext;
			else
				return SPRemoteRight;
			break;
		
		case SPAppleRemoteButtonLeft:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemotePrevious;
			else
				return SPRemoteLeft;
			break;
		
		case SPAppleRemoteButtonRightHold:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteScanForward;
			else
				return SPRemoteRight;
			break;
		
		case SPAppleRemoteButtonLeftHold:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteScanBackward;
			else
				return SPRemoteLeft;
			break;
		
		default:
			return SPRemoteDoNothing;
			break;
	}

	return SPRemoteDoNothing;
}

@end
