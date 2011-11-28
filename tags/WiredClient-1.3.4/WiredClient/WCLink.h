/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

@protocol WCConnection;

@interface WCLink : WIObject {
	WISocket				*_socket;
	WIURL					*_url;
	
	NSTimer					*_pingTimer;
	
	id						_delegate;
	BOOL					_delegateLinkConnected;
	BOOL					_delegateLinkClosed;
	BOOL					_delegateLinkTerminated;
	BOOL					_delegateLinkSentCommand;
	BOOL					_delegateLinkReceivedMessage;
	
	BOOL					_reading;
	BOOL					_closing;
	BOOL					_terminating;
}


- (id)initLinkWithURL:(WIURL *)url;

- (void)setDelegate:(id)delegate;
- (id)delegate;

- (WIURL *)URL;
- (WISocket *)socket;
- (BOOL)isReading;

- (void)connect;
- (void)disconnect;
- (void)terminate;
- (void)sendCommand:(NSString *)command;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2;
- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3;
- (void)sendCommand:(NSString *)command withArguments:(NSArray *)arguments;

@end



@interface NSObject(WCLinkDelegate)

- (void)linkConnected:(WCLink *)link;
- (void)linkClosed:(WCLink *)link error:(WIError *)error;
- (void)linkTerminated:(WCLink *)link;
- (void)link:(WCLink *)link sentCommand:(NSString *)command;
- (void)link:(WCLink *)link receivedMessage:(WCProtocolMessage)message arguments:(NSArray *)arguments;

@end
