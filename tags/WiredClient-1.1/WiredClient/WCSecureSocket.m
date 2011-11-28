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

#import "WCConnection.h"
#import "WCError.h"
#import "WCSecureSocket.h"
#import "WCSettings.h"

@implementation WCSecureSocket

- (id)initWithConnection:(WCConnection *)connection type:(unsigned int)type {
	NSString		*ciphers;
	
	self = [super initWithConnection:connection type:type];
	
	// --- create SSL context
	_sslCtx = SSL_CTX_new(TLSv1_client_method());
	
	// --- select ciphers
	if(type == WCSocketTypeControl) {
		ciphers = [WCSettings objectForKey:WCSSLControlCiphers];
	} else {
		if([[WCSettings objectForKey:WCEncryptTransfers] boolValue])
			ciphers = [WCSettings objectForKey:WCSSLTransferCiphers];
		else
			ciphers = [WCSettings objectForKey:WCSSLNullTransferCiphers];
	}
	
	SSL_CTX_set_cipher_list(_sslCtx, [ciphers UTF8String]);

    return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if(_ssl)
		SSL_free(_ssl);
	
	SSL_CTX_free(_sslCtx);

	[super dealloc];
}



#pragma mark -

- (int)connectToHost:(NSString *)host port:(int)port {
	// --- connect TCP socket
	if([super connectToHost:host port:port] < 0)
		return -1;

	// --- connect SSL socket
	_ssl = SSL_new(_sslCtx);
	
	if(!_ssl) {
		[[_connection error] setError:WCConnectionErrorSSLFailed];
		
		return -1;
	}
	
	if(SSL_set_fd(_ssl, _sd) != 1) {
		[[_connection error] setError:WCConnectionErrorSSLFailed];
		
		return -1;
	}
	
	if(SSL_connect(_ssl) != 1) {
		[[_connection error] setError:WCConnectionErrorSSLFailed];
		
		return -1;
	}
	
	return 0;
}



#pragma mark -

- (int)read:(NSMutableData *)data {
	int		bytes;
	
	if(!_connected)
		return -1;

	bytes = SSL_read(_ssl, _buffer, WCClientBufferSize);

	if(bytes > 0) {
		// --- ok
		[data appendBytes:_buffer length:bytes];
	}
	else if(bytes == 0) {
		// --- EOF
		[[_connection error] setError:WCConnectionErrorServerDisconnected];

		return 0;
	}
	else if(bytes == -1 && errno != EAGAIN) {
		// --- error
		[[_connection error] setError:WCConnectionErrorSSLFailed];

		return -1;
	}
	
	return bytes;
}



- (int)write:(NSData *)data {
	int		bytes;
	
	if(!_connected)
		return -1;

	bytes = SSL_write(_ssl, [data bytes], [data length]);
	
	if(bytes < 0 && errno != EAGAIN) {
		[[_connection error] setError:WCConnectionErrorSSLFailed];
		
		return -1;
	}
	
	return bytes;
}



#pragma mark -

- (void)close {
	if(_connected) {
		_connected = NO;
		
		if(SSL_shutdown(_ssl) == 0)
			SSL_shutdown(_ssl);

		[super close];
	}
}



#pragma mark -

- (NSString *)cipher {
	return [NSString stringWithFormat:@"%s/%d %@",
		SSL_get_cipher_name(_ssl),
		SSL_get_cipher_bits(_ssl, NULL),
		NSLocalizedString(@"bits", "Cipher string")];
}



- (BOOL)secure {
	return (SSL_get_cipher_bits(_ssl, NULL) != 0);
}

@end
