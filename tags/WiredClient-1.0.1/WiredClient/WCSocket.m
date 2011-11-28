/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <unistd.h>
#import "WCConnection.h"
#import "WCError.h"
#import "WCSocket.h"

@implementation WCSocket

- (id)initWithConnection:(WCConnection *)connection type:(unsigned int)type {
	self = [super init];
	
	// --- get parameters
	_connection	= [connection retain];
	_type		= type;
	
	// --- create a socket
	_sd			= socket(AF_INET, SOCK_STREAM, 0);
	_connected	= NO;
	
	return self;
}



- (void)dealloc {
	[_connection release];

	[super dealloc];
}



#pragma mark -

- (int)connectToHost:(NSString *)host port:(int)port {
	struct sockaddr_in		addr;
	
	memset(&addr, 0, sizeof(addr));
	addr.sin_family		= AF_INET;
	addr.sin_port		= htons(port);
	addr.sin_len		= sizeof(addr);

	// --- resolve host name
	if(inet_aton([host cString], &addr.sin_addr) == NULL) {
		struct hostent		*hp;
			
		hp = gethostbyname([host cString]);

		if(hp == NULL) {
			[[_connection error] setError:WCConnectionErrorResolveFailed];
			
			return -1;
		}
			
		memcpy(&addr.sin_addr, hp->h_addr, sizeof(addr.sin_addr));
	}
	
	// --- connect TCP socket
	if(connect(_sd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
		[[_connection error] setError:WCConnectionErrorConnectFailed];
		
		return -1;
	}
	_connected = YES;
	
	return 0;
}



#pragma mark -

- (int)read:(NSMutableData *)data {
	int		bytes;
	
	if(!_connected)
		return 0;

	bytes = read(_sd, _buffer, WCClientBufferSize);

	// --- ok
	if(bytes > 0) {
		[data appendBytes:_buffer length:bytes];
	}
	// --- EOF
	else if(bytes == 0) {
		[[_connection error] setError:WCConnectionErrorServerDisconnected];
		
		return 0;
	}
	// --- error
	else if(bytes == -1 && errno != EAGAIN) {
		[[_connection error] setError:WCConnectionErrorReadFailed];

		return -1;
	}
	
	return bytes;
}



- (int)write:(NSData *)data {
	int		bytes;
	
	if(!_connected)
		return 0;

	bytes = write(_sd, [data bytes], [data length]);
	
	if(bytes < 0 && errno != EAGAIN) {
		[[_connection error] setError:WCConnectionErrorWriteFailed];
		
		return -1;
	}
	
	return bytes;
}



#pragma mark -

- (BOOL)connected {
	return _connected;
}



- (void)close {
	close(_sd);
}

@end
