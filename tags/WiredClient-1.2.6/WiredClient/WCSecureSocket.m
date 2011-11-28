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

- (id)initWithConnection:(WCConnection *)connection {
	self = [super init];
	
	// --- get parameters
	_connection = [connection retain];
	
	// --- create socket
	_sd = socket(AF_INET, SOCK_STREAM, 0);
	
	// --- create SSL context
	_sslCtx = SSL_CTX_new(TLSv1_client_method());

	// --- create data
	_data = [[NSMutableData alloc] initWithCapacity:WCSocketBufferInitialSize];
	
    return self;
}



- (void)dealloc {
	if(_ssl)
		SSL_free(_ssl);
	
	SSL_CTX_free(_sslCtx);
	
	[_connection release];
	[_data release];
	
	[super dealloc];
}



#pragma mark -

- (int)connectToHost:(NSString *)host port:(int)port {
	struct sockaddr_in		addr;
	
	// --- set address
	memset(&addr, 0, sizeof(addr));
	addr.sin_family		= AF_INET;
	addr.sin_port		= htons(port);
	addr.sin_len		= sizeof(addr);
	
	// --- resolve host name
	if(!inet_aton([host UTF8String], &addr.sin_addr)) {
		struct hostent		*hp;
		
		hp = gethostbyname([host UTF8String]);
		
		if(!hp) {
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
	
	// --- connect SSL socket
	_ssl = SSL_new(_sslCtx);
	
	if(!_ssl) {
		[[_connection error] setError:WCConnectionErrorSSLConnectFailed];
		
		return -1;
	}
	
	if(SSL_set_fd(_ssl, _sd) != 1) {
		[[_connection error] setError:WCConnectionErrorSSLConnectFailed];
		
		return -1;
	}
	
	if(SSL_connect(_ssl) != 1) {
		[[_connection error] setError:WCConnectionErrorSSLConnectFailed];
		
		return -1;
	}
	
	_connected = YES;
	
	return 0;
}



- (void)readInBackgroundAndNotify {
	NSAutoreleasePool   *pool;
	NSData				*data;
	struct timeval		tv;
	fd_set				rfds;
	char				buf[WCSocketBufferSize];
	char				*buffer;
	unsigned int		buffer_size, buffer_offset;
	int					bytes, state;
	
	buffer_size = WCSocketBufferInitialSize;
	buffer = (char *) malloc(buffer_size);
	memset(buffer, 0, buffer_size);
	buffer_offset = 0;
	
	_reading = YES;

	while(_reading) {
		do {
			FD_ZERO(&rfds);
			FD_SET(_sd, &rfds);
			tv.tv_sec = 0;
			tv.tv_usec = 100000;
			state = select(_sd + 1, &rfds, NULL, NULL, &tv);
		} while(state == 0 && _reading);
		
		if(!_reading)
			break;
		
		if(state < 0) {
			NSLog(@"select: %s", strerror(errno));
			[[_connection error] setError:WCConnectionErrorReadFailed];
			
			break;
		}
		
		// --- read from SSL
		[_lock lock];
		bytes = SSL_read(_ssl, buf, sizeof(buf));
		[_lock unlock];
		
		if(bytes == 0) {
			// --- EOF
			break;
		}
		else if(bytes < 0) {
			// --- error in SSL communication
			NSLog(@"SSL_read: %s, %s",
				ERR_reason_error_string(ERR_get_error()), strerror(errno));
			[[_connection error] setError:WCConnectionErrorSSLFailed];
			
			break;
		}

		// --- increase buffer size?
		if(buffer_offset + bytes >= buffer_size) {
			buffer_size += bytes;
			buffer = realloc(buffer, buffer_size);
		}

		// --- append to buffer
		strlcat(buffer + buffer_offset, buf, buffer_size - buffer_offset);
		buffer_offset += bytes;
		
		if(buffer[buffer_offset - 1] == 4) {
			// --- announce data
			pool = [[NSAutoreleasePool alloc] init];
			data = [[NSData alloc] initWithBytes:buffer length:buffer_offset - 1];
			[_connection receiveData:data];
			[data release];
			[pool release];
			
			// --- reset buffer
			memset(buffer, 0, buffer_size);
			buffer_offset = 0;
		}
	}
	
	[self close];
	
	free(buffer);
}



- (NSData *)readDataOfLength:(unsigned int)length {
	NSData	*data = NULL;
	char	*buffer = NULL;
	int		bytes;
    
	// --- not connected
    if(!_connected)
		goto end;
	
	// --- allocate buffer
	buffer = (char *) malloc(length);
	
	// --- read from socket
	[_lock lock];
    bytes = SSL_read(_ssl, buffer, length);
	[_lock unlock];
	
	if(bytes > 0) {
		// --- success
		data = [NSData dataWithBytes:buffer length:bytes];
		
		goto end;
	}
	else if(bytes == 0) {
        // --- EOF
		data = [NSData data];
		
		goto end;
    }
    else if(bytes < -1) {
        // --- error
		NSLog(@"SSL_read: %s, %s",
			ERR_reason_error_string(ERR_get_error()), strerror(errno));
        [[_connection error] setError:WCConnectionErrorSSLFailed];

        goto end;
	}

end:
	// --- clean up
	if(buffer)
		free(buffer);
	
    return data;
}



- (int)writeData:(NSData *)data {
	int		bytes;
	
	// --- not connected
	if(!_connected)
		return -1;

	// --- write to socket
	[_lock lock];
	bytes = SSL_write(_ssl, [data bytes], [data length]);
	[_lock unlock];
	
	if(bytes < 0) {
		// --- error
		NSLog(@"SSL_write: %s, %s",
			ERR_reason_error_string(ERR_get_error()), strerror(errno));
		[[_connection error] setError:WCConnectionErrorSSLFailed];
		
		return -1;
	}
	
	return bytes;
}



- (void)close {
	_connected = NO;
	
	if(!_reading) {
		if(SSL_shutdown(_ssl) == 0)
			SSL_shutdown(_ssl);
		
		close(_sd);
	}
	
	_reading = NO;
}



#pragma mark -

- (void)setCiphers:(NSString *)value {
	SSL_CTX_set_cipher_list(_sslCtx, [value UTF8String]);
}



- (void)setLocking:(BOOL)value {
	if(value && !_lock) {
		_lock = [[NSLock alloc] init];
	}
	else if(_lock) {
		[_lock release];
		_lock = NULL;
	}
}



- (void)setNoDelay:(BOOL)value {
	int		on = 1, off = 0;

	if(value)
		setsockopt(_sd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
	else
		setsockopt(_sd, IPPROTO_TCP, TCP_NODELAY, &off, sizeof(off));
}



#pragma mark -

- (BOOL)connected {
	return _connected;
}



- (SSL *)SSL {
	return _ssl;
}



- (NSString *)cipher {
	return [NSString stringWithFormat:
		NSLocalizedString(@"%s/%d bits", "Cipher (type, size)"),
		SSL_get_cipher_name(_ssl),
		SSL_get_cipher_bits(_ssl, NULL)];
}



- (NSString *)certificate {
	NSString	*string, *type = @"";
	X509		*cert = NULL;
	EVP_PKEY	*key = NULL;
	char		hostname[MAXHOSTNAMELEN];
	int			size;

	// --- get certificate
	string = NSLocalizedString(@"Anonymous", @"Anonymous certificate");
	cert = SSL_get_peer_certificate(_ssl);
	
	if(!cert)
		goto end;
	
	// --- get host
	X509_NAME_get_text_by_NID(X509_get_subject_name(cert), NID_commonName,
							  hostname, sizeof(hostname));

	// --- get public key
	key = X509_get_pubkey(cert);
	
	if(!key)
		goto end;
	
	// --- get size
	size = 8 * EVP_PKEY_size(key);
	
	// --- get type
	switch(EVP_PKEY_type(key->type)) {
		case EVP_PKEY_RSA:
			type = @"RSA";
			break;
			
		case EVP_PKEY_DSA:
			type = @"DSA";
			break;
			
		case EVP_PKEY_DH:
			type = @"DH";
			break;
	}
	
	// --- get string
	string = [NSString stringWithFormat:
		NSLocalizedString(@"%@/%d bits, %s", @"Certificate (type, size, hostname)"),
		type, size, hostname];

end:
	if(cert)
		X509_free(cert);
	
	if(key)
		EVP_PKEY_free(key);
	
	return string;
}



- (BOOL)isSecure {
	return (SSL_get_cipher_bits(_ssl, NULL) != 0);
}

@end

