/* $Id$ */

/*
 *  Copyright (c) 2005-2006 Axel Andersson
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

#import "WCConnection.h"
#import "WCLink.h"

@interface WCLink(Private)

- (void)_parseMessage:(NSString *)string;

@end


@implementation WCLink(Private)

- (void)_parseMessage:(NSString *)string {
	NSArray			*arguments;
	unsigned int	message;

	message = [[string substringToIndex:WCMessageLength] unsignedIntValue];
	arguments = [[string substringFromIndex:WCMessageLength + 1] componentsSeparatedByString:WCFieldSeparator];
		
	[_delegate link:self receivedMessage:message arguments:arguments];
}

@end


@implementation WCLink

- (id)initLinkWithURL:(WIURL *)url {
	self = [super init];
	
	_url = [url retain];
	
	return self;
}



- (void)dealloc {
	[_url release];
	[_pingTimer release];
	
	[super dealloc];
}



#pragma mark -

- (void)setDelegate:(id)delegate {
	_delegate = delegate;
	
	_delegateLinkConnected = [_delegate respondsToSelector:@selector(linkConnected:)];
	_delegateLinkClosed = [_delegate respondsToSelector:@selector(linkClosed:error:)];
	_delegateLinkTerminated = [_delegate respondsToSelector:@selector(linkTerminated:)];
	_delegateLinkSentCommand = [_delegate respondsToSelector:@selector(link:sentCommand:)];
	_delegateLinkReceivedMessage = [_delegate respondsToSelector:@selector(link:receivedMessage:arguments:)];
}



- (id)delegate {
	return _delegate;
}



#pragma mark -

- (WIURL *)URL {
	return _url;
}



- (WISocket *)socket {
	return _socket;
}



- (BOOL)isReading {
	return _reading;
}



#pragma mark -

- (void)connect {
	_reading = YES;
	_terminating = NO;

	[WIThread detachNewThreadSelector:@selector(linkThread:) toTarget:self withObject:NULL];
	
	_pingTimer = [[NSTimer scheduledTimerWithTimeInterval:60.0
												   target:self
												 selector:@selector(pingTimer:)
												 userInfo:NULL
												  repeats:YES] retain];
	
}



- (void)close {
	_closing = YES;
	_reading = NO;
}



- (void)terminate {
	_terminating = YES;
	_reading = NO;
}



- (void)sendCommand:(NSString *)command {
	[self sendCommand:command withArguments:NULL];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 {
	[self sendCommand:command withArguments:[NSArray arrayWithObject:argument1]];
}



- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 {
	[self sendCommand:command withArguments:[NSArray arrayWithObjects:argument1, argument2, NULL]];
}


- (void)sendCommand:(NSString *)command withArgument:(NSString *)argument1 withArgument:(NSString *)argument2 withArgument:(NSString *)argument3 {
	[self sendCommand:command withArguments:[NSArray arrayWithObjects:argument1, argument2, argument3, NULL]];
}



- (void)sendCommand:(NSString *)command withArguments:(NSArray *)arguments {
	NSString	*string;

	if([arguments count] > 0)
		string = [NSSWF:@"%@ %@", command, [arguments componentsJoinedByString:WCFieldSeparator]];
	else
		string = command;

	[_socket writeString:[string stringByAppendingString:WCMessageSeparator]
				encoding:NSUTF8StringEncoding
				 timeout:0.0
				   error:NULL];
	
	if(_delegateLinkSentCommand)
		[_delegate link:self sentCommand:string];
}



#pragma mark -

- (void)linkThread:(id)arg {
	NSAutoreleasePool	*pool, *loopPool = NULL;
	NSString			*string, *arguments;
	WIError				*error = NULL;
	WISocketContext		*context;
	WIAddress			*address;
	unsigned int		message, i = 0;
	BOOL				failed = NO;

	pool = [[NSAutoreleasePool alloc] init];
	
	[_delegate retain];
	
	context = [WISocketContext socketContextForClient];
	[context setSSLCiphers:[WCSettings objectForKey:WCSSLControlCiphers]];
	
	address = [WIAddress addressWithString:[_url host] error:&error];
	
	if(!address)
		goto close;
	
	[address setPort:[_url port]];

	_socket = [[WISocket alloc] initWithAddress:address type:WISocketTCP];
	[_socket setInteractive:YES];
	
	if(![_socket connectWithContext:context timeout:30.0 error:&error]) {
		failed = YES;
		
		goto close;
	}
	
	if(_delegateLinkConnected)
		[_delegate linkConnected:self];
	
	while(!_closing && !_terminating) {
		if(!loopPool)
			loopPool = [[NSAutoreleasePool alloc] init];
		
		error = NULL;
		string = [_socket readStringUpToString:WCMessageSeparator encoding:NSUTF8StringEncoding timeout:1.0 error:&error];
		
		if(_closing || _terminating || (string && [string length] == 0)) {
			goto close;
		}
		else if(!string) {
			if([[[error userInfo] objectForKey:WILibWiredErrorKey] code] == ETIMEDOUT) {
				continue;
			} else {
				failed = YES;
				
				goto close;
			}
		}
		
		message = [[string substringToIndex:WCMessageLength] unsignedIntValue];
		arguments = [string substringWithRange:NSMakeRange(WCMessageLength + 1, [string length] - WCMessageLength - 2)];
		
		if(_delegateLinkReceivedMessage)
			[_delegate link:self receivedMessage:message arguments:[arguments componentsSeparatedByString:WCFieldSeparator]];
		
		if(++i % 100 == 0) {
			[loopPool release];
			loopPool = NULL;
		}
	}
	
close:
	[_pingTimer invalidate];
		
	if(_terminating) {
		if(_delegateLinkTerminated)
			[_delegate linkTerminated:self];
	} else {
		if(_delegateLinkClosed)
			[_delegate linkClosed:self error:error];
	}
	
	_reading = NO;

	if(!failed)
		[_socket close];
	
	[_socket release];
	
	[_delegate release];
	[loopPool release];
	[pool release];
}



- (void)pingTimer:(NSTimer *)timer {
	[self sendCommand:WCPingCommand];
}

@end
