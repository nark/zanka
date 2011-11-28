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

#import "SPRemote.h"

enum _SPAppleRemoteButton {
	SPAppleRemoteButtonVolumePlus				= 1 << 1,
	SPAppleRemoteButtonVolumeMinus				= 1 << 2,
	SPAppleRemoteButtonMenu						= 1 << 3,
	SPAppleRemoteButtonPlay						= 1 << 4,
	SPAppleRemoteButtonRight					= 1 << 5,
	SPAppleRemoteButtonLeft						= 1 << 6,
	SPAppleRemoteButtonRightHold				= 1 << 7,
	SPAppleRemoteButtonLeftHold					= 1 << 8,
	SPAppleRemoteButtonMenuHold					= 1 << 9,
	SPAppleRemoteButtonPlaySleep				= 1 << 10,
	SPAppleRemoteControlSwitched				= 1 << 11
};
typedef enum _SPAppleRemoteButton				SPAppleRemoteButton;


@class AppleRemote;

@protocol SPAppleRemoteDelegate;

@interface SPAppleRemote : SPRemote {
	IBOutlet id <SPAppleRemoteDelegate>			delegate;
	
	AppleRemote									*_remote;

	BOOL										_delegateAppleRemotePressedButton;
	BOOL										_delegateAppleRemoteHeldButton;
	BOOL										_delegateAppleRemoteReleasedButton;
}

+ (SPAppleRemote *)sharedRemote;

- (void)setDelegate:(id <SPAppleRemoteDelegate>)delegate;
- (id <SPAppleRemoteDelegate>)delegate;

- (void)startListening;
- (void)stopListening;
- (BOOL)isListening;

- (SPRemoteAction)actionForButton:(SPAppleRemoteButton)button inContext:(SPRemoteContext)context;

@end


@protocol SPAppleRemoteDelegate <NSObject>

@optional

- (void)appleRemotePressedButton:(SPAppleRemoteButton)button;
- (void)appleRemoteHeldButton:(SPAppleRemoteButton)button;
- (void)appleRemoteReleasedButton;

@end
