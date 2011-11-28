/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPBluetoothRemote.h"

enum _SPWiiRemoteButton {
	SPWiiRemoteButton2					= 0x0001,
	SPWiiRemoteButton1					= 0x0002,
	SPWiiRemoteButtonB					= 0x0004,
	SPWiiRemoteButtonA					= 0x0008,
	SPWiiRemoteButtonMinus				= 0x0010,
	SPWiiRemoteButtonHome				= 0x0080,
	SPWiiRemoteButtonLeft				= 0x0100,
	SPWiiRemoteButtonRight				= 0x0200,
	SPWiiRemoteButtonDown				= 0x0400,
	SPWiiRemoteButtonUp					= 0x0800,
	SPWiiRemoteButtonPlus				= 0x1000
};
typedef enum _SPWiiRemoteButton			SPWiiRemoteButton;


@protocol SPWiiRemoteDelegate;

@interface SPWiiRemote : SPBluetoothRemote {
	id <SPWiiRemoteDelegate>			delegate;
	
	SPWiiRemoteButton					_lastHoldButton;
	NSTimeInterval						_lastHoldButtonTime;
	BOOL								_lastButtonSimulatedHold;

	BOOL								_delegateWiiRemotePressedButton;
	BOOL								_delegateWiiRemoteHeldButton;
	BOOL								_delegateWiiRemoteReleasedButton;
}

+ (SPWiiRemote *)sharedRemote;

- (void)setDelegate:(id <SPWiiRemoteDelegate>)delegate;
- (id <SPWiiRemoteDelegate>)delegate;

- (SPRemoteAction)actionForButton:(SPWiiRemoteButton)button inContext:(SPRemoteContext)context;

@end


@protocol SPWiiRemoteDelegate <NSObject>

- (BOOL)wiiRemoteShouldDisconnect:(SPWiiRemote *)remote;

@optional

- (void)wiiRemote:(SPWiiRemote *)remote pressedButton:(SPWiiRemoteButton)button;
- (void)wiiRemote:(SPWiiRemote *)remote heldButton:(SPWiiRemoteButton)button;
- (void)wiiRemoteReleasedButton:(SPWiiRemote *)remote;

@end
