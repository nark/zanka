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

#import "SPWiiRemote.h"

@interface SPWiiRemote(Private)

- (void)_enableLEDLight1;
- (void)_writeCommand:(unsigned char *)data length:(NSUInteger)length;
- (void)_handleButton:(unsigned int)button;

@end


@implementation SPWiiRemote(Private)

- (void)_enableLEDLight1 {
	unsigned char	buffer[2];

	buffer[0] = 0x11;
	buffer[1] = 0x10;
	
	return [self _writeCommand:buffer length:sizeof(buffer)];
}



- (void)_writeCommand:(unsigned char *)data length:(NSUInteger)length {
	unsigned char	buffer[40];
	
	memset(buffer, 0, sizeof(buffer));
	buffer[0] = 0x52;
	memcpy(buffer + 1, data, length);
	
	if(_controlConnected)
		[_controlChannel writeSync:buffer length:length + 1];
}



- (void)_handleButton:(unsigned int)button {
	if(button != 0x00) {
		_lastHoldButton = button;
		_lastHoldButtonTime = [NSDate timeIntervalSinceReferenceDate];
		
		[self performSelector:@selector(_handleSimulatedHoldButton:) 
				   withObject:[NSNumber numberWithDouble:_lastHoldButtonTime]
				   afterDelay:0.3];

		if(_delegateWiiRemotePressedButton)
			[delegate wiiRemote:self pressedButton:button];
	} else {
		if(_lastButtonSimulatedHold) {
			_lastHoldButton = 0;
			_lastButtonSimulatedHold = NO;
		} else {
			_lastHoldButton = 0;
		}
		
		if(_delegateWiiRemoteReleasedButton)
			[delegate wiiRemoteReleasedButton:self];
	}
}



- (void)_handleSimulatedHoldButton:(id)time {
	if(_lastHoldButton > 0 && _lastHoldButtonTime == [time doubleValue]) {
		_lastButtonSimulatedHold = YES;

		if(_delegateWiiRemoteHeldButton)
			[delegate wiiRemote:self heldButton:_lastHoldButton];
	}
}

@end



@implementation SPWiiRemote

+ (NSString *)remoteName {
	return @"Nintendo RVL-CNT-01";
}



#pragma mark -

+ (SPWiiRemote *)sharedRemote {
	static SPWiiRemote		*sharedRemote;
	
	if(!sharedRemote)
		sharedRemote = [[self alloc] init];
	
	return sharedRemote;
}



+ (BOOL)needsControlChannel {
	return YES;
}



+ (BOOL)needsInterruptChannel {
	return YES;
}



#pragma mark -

- (id)init {
	self = [super init];
	
	[[IOBluetoothDeviceInquiry inquiryWithDelegate:self] start];
	
	return self;
}



#pragma mark -

- (void)remoteDidConnect {
	[self _enableLEDLight1];
	
	[self disconnectAfterDelay];
	
	[super remoteDidConnect];
}



- (BOOL)remoteShouldDisconnect {
	return [delegate wiiRemoteShouldDisconnect:self];
}



#pragma mark -

- (void)setDelegate:(id <SPWiiRemoteDelegate>)aDelegate {
	delegate = aDelegate;
	
	_delegateWiiRemotePressedButton		= [delegate respondsToSelector:@selector(wiiRemotePressedButton:)];
	_delegateWiiRemoteHeldButton		= [delegate respondsToSelector:@selector(wiiRemoteHeldButton:)];
	_delegateWiiRemoteReleasedButton	= [delegate respondsToSelector:@selector(wiiRemoteReleasedButton)];
}



- (id <SPWiiRemoteDelegate>)delegate {
	return delegate;
}



#pragma mark -

- (SPRemoteAction)actionForButton:(SPWiiRemoteButton)button inContext:(SPRemoteContext)context {
	switch(button) {
		case SPWiiRemoteButton1:
			return SPRemoteCycleSubtitleTracks;
			break;
			
		case SPWiiRemoteButton2:
			return SPRemoteCycleAudioTracks;
			break;
			
		case SPWiiRemoteButtonB:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemotePlayOrPause;
			else
				return SPRemoteEnter;
			break;
			
		case SPWiiRemoteButtonA:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemotePlayOrPause;
			else
				return SPRemoteEnter;
			break;
			
		case SPWiiRemoteButtonMinus:
			return SPRemoteScanBackward;
			break;
			
		case SPWiiRemoteButtonHome:
			if(context == SPRemoteDrillView)
				return SPRemoteHideDrillView;
			else if(context == SPRemoteFullscreenPlayer)
				return SPRemoteCloseFullscreenMovie;
			else
				return SPRemoteShowDrillView;
			break;
			
		case SPWiiRemoteButtonLeft:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemotePrevious;
			else
				return SPRemoteLeft;
			break;
			
		case SPWiiRemoteButtonRight:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteNext;
			else
				return SPRemoteRight;
			break;
			
		case SPWiiRemoteButtonDown:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteStepBackward;
			else
				return SPRemoteDown;
			break;
			
		case SPWiiRemoteButtonUp:
			if(context == SPRemotePlayer || context == SPRemoteFullscreenPlayer)
				return SPRemoteStepForward;
			else
				return SPRemoteUp;
			break;
			
		case SPWiiRemoteButtonPlus:
			return SPRemoteScanForward;
			break;
	}
	
	return SPRemoteDoNothing;
}



#pragma mark -

- (void)deviceInquiryComplete:(IOBluetoothDeviceInquiry *)inquiry error:(IOReturn)error aborted:(BOOL)aborted {
	if(error == kIOReturnSuccess)
		[inquiry start];
	else
		NSLog(@"*** -[%@ deviceInquiryComplete:error:aborted:]: %s", [self class], mach_error_string(error));
}



- (void)deviceInquiryDeviceNameUpdated:(IOBluetoothDeviceInquiry *)inquiry device:(IOBluetoothDevice *)device devicesRemaining:(uint32_t)devicesRemaining {
	if([[device getName] isEqualToString:[[self class] remoteName]]) {
		[device retain];
		[_device release];
		
		_device = device;
		
		[self connectAfterDelay];
	}
}



- (void)deviceInquiryDeviceFound:(IOBluetoothDeviceInquiry *)inquiry device:(IOBluetoothDevice *)device {
	if([[device getName] isEqualToString:[[self class] remoteName]]) {
		[device retain];
		[_device release];
		
		_device = device;
		
		[self connectAfterDelay];
	}
}



#pragma mark -

- (void)l2capChannelData:(IOBluetoothL2CAPChannel *)channel data:(unsigned char *)buffer length:(NSUInteger)length {
	if(length == 4 && buffer[1] == 0x30)
		[self _handleButton:buffer[2] << 8 | buffer[3]];

	[self disconnectAfterDelay];
}

@end
