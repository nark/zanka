/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Axel Andersson
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

#import <WiredNetworking/WNAddress.h>
#import <WiredNetworking/WNError.h>
#import <WiredNetworking/WNSocket.h>

#define _WNSocketBufferMaxSize				131072


@interface WNSocketContext(Private)

- (wi_socket_context_t *)_context;

@end


@implementation WNSocketContext(Private)

- (wi_socket_context_t *)_context {
	return _context;
}

@end


@implementation WNSocketContext

+ (WNSocketContext *)socketContextForClient {
	WNSocketContext		*context;
	
	context = [[self alloc] init];

	wi_socket_context_set_ssl_type(context->_context, WI_SOCKET_SSL_CLIENT);
	
	return [context autorelease];
}



- (id)init {
	wi_pool_t	*pool;
	
	self = [super init];
	
	pool = wi_pool_init(wi_pool_alloc());
	_context = wi_socket_context_init(wi_socket_context_alloc());
	wi_release(pool);
	
	return self;
}



- (void)dealloc {
	wi_release(_context);
	
	[super dealloc];
}



#pragma mark -

- (void)setSSLCiphers:(NSString *)ciphers {
	wi_pool_t	*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	wi_socket_context_set_ssl_ciphers(_context, wi_string_with_cstring([ciphers UTF8String]));
	wi_release(pool);
}

@end


@implementation WNSocket

+ (WNSocket *)socketWithAddress:(WNAddress *)address type:(WNSocketType)type {
	return [[[self alloc] initWithAddress:address type:type] autorelease];
}



+ (WNSocket *)socketWithFileDescriptor:(int)sd {
	return [[[self alloc] initWithFileDescriptor:sd] autorelease];
}



- (id)initWithAddress:(WNAddress *)address type:(WNSocketType)type {
	wi_pool_t	*pool;
	
	self = [self init];
	
	pool = wi_pool_init(wi_pool_alloc());
	_socket = wi_socket_init_with_address(wi_socket_alloc(), [address address], type);
	wi_release(pool);

	_address = [address retain];
	
	return self;
}



- (id)initWithFileDescriptor:(int)sd {
	wi_pool_t	*pool;
	
	self = [self init];
	
	pool = wi_pool_init(wi_pool_alloc());
	_socket = wi_socket_init_with_descriptor(wi_socket_alloc(), sd);
	wi_release(pool);
	
	return self;
}



- (id)init {
	self = [super init];
	
	_buffer = [[NSMutableString alloc] initWithCapacity:WNSocketBufferSize];
	
	return self;
}



- (void)dealloc {
	wi_pool_t	*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	wi_release(_socket);
	wi_release(pool);
	
	[_address release];
	[_buffer release];

	[super dealloc];
}



#pragma mark -

- (WNAddress *)address {
	return _address;
}



- (int)fileDescriptor {
	return wi_socket_descriptor(_socket);
}



- (SSL *)SSL {
	return wi_socket_ssl(_socket);
}



- (NSString *)cipherVersion {
	NSString		*string;
	wi_pool_t		*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	string = [NSString stringWithUTF8String:wi_string_cstring(wi_socket_cipher_version(_socket))];
	wi_release(pool);
	
	return string;
}



- (NSString *)cipherName {
	NSString		*string;
	wi_pool_t		*pool;
	
	pool = wi_pool_init(wi_pool_alloc());
	string = [NSString stringWithUTF8String:wi_string_cstring(wi_socket_cipher_name(_socket))];
	wi_release(pool);
	
	return string;
}



- (NSUInteger)cipherBits {
	return wi_socket_cipher_bits(_socket);
}



- (NSString *)certificateName {
	NSString		*string = NULL;
	wi_pool_t		*pool;
	wi_string_t		*wstring;
	
	pool = wi_pool_init(wi_pool_alloc());
	wstring = wi_socket_certificate_name(_socket);
	
	if(wstring)
		string = [NSString stringWithUTF8String:wi_string_cstring(wstring)];
	
	wi_release(pool);
	
	return string;
}



- (NSUInteger)certificateBits {
	return wi_socket_certificate_bits(_socket);
}



- (NSString *)certificateHostname {
	NSString		*string = NULL;
	wi_pool_t		*pool;
	wi_string_t		*wstring;
	
	pool = wi_pool_init(wi_pool_alloc());
	wstring = wi_socket_certificate_hostname(_socket);
	
	if(wstring)
		string = [NSString stringWithUTF8String:wi_string_cstring(wstring)];
	
	wi_release(pool);
	
	return string;
}



#pragma mark -

- (void)setPort:(NSUInteger)port {
	wi_socket_set_port(_socket, port);
	
	[_address setPort:port];
}



- (NSUInteger)port {
	return wi_socket_port(_socket);
}



- (void)setDirection:(WNSocketDirection)direction {
	wi_socket_set_direction(_socket, (wi_socket_direction_t) direction);
}



- (WNSocketDirection)direction {
	return (WNSocketDirection) wi_socket_direction(_socket);
}



- (void)setBlocking:(BOOL)blocking {
	wi_socket_set_blocking(_socket, blocking);
}



- (BOOL)blocking {
	return wi_socket_blocking(_socket);
}



- (void)setInteractive:(BOOL)interactive {
	wi_socket_set_interactive(_socket, interactive);
}



- (BOOL)interactive {
	return wi_socket_interactive(_socket);
}



#pragma mark -

- (BOOL)waitWithTimeout:(double)timeout {
	wi_pool_t			*pool;
	wi_socket_state_t	state;
	
	pool = wi_pool_init(wi_pool_alloc());
	state = wi_socket_wait(_socket, timeout);
	wi_release(pool);
	
	return (state == WI_SOCKET_READY);
}



#pragma mark -

- (BOOL)connectWithContext:(WNSocketContext *)context timeout:(double)timeout error:(WNError **)error {
	wi_pool_t		*pool;
	BOOL			result = YES;
	
	pool = wi_pool_init(wi_pool_alloc());
	
	wi_uuid();
	
	if(!wi_socket_connect(_socket, [context _context], timeout)) {
		if(error) {
			*error = [WNError errorWithDomain:WNWiredNetworkingErrorDomain
										 code:WNSocketConnectFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										 [WNError errorWithDomain:WNLibWiredErrorDomain],	WNLibWiredErrorKey,
										 [_address string],									WIArgumentErrorKey,
										 NULL]];
		}
		
		result = NO;
	}
	
	wi_release(pool);
	
	return result;
}



- (void)close {
	wi_pool_t		*pool;

	pool = wi_pool_init(wi_pool_alloc());
	wi_socket_close(_socket);
	wi_release(pool);
}



#pragma mark -

- (BOOL)writeString:(NSString *)string encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error {
	NSData			*data;
	wi_pool_t		*pool;
	BOOL			result = NO;
	
	pool = wi_pool_init(wi_pool_alloc());
	data = [string dataUsingEncoding:encoding];
	
	if(wi_socket_write_buffer(_socket, timeout, [data bytes], [data length]) < 0) {
		if(error) {
			*error = [WNError errorWithDomain:WNWiredNetworkingErrorDomain
										 code:WNSocketWriteFailed
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
										 [WNError errorWithDomain:WNLibWiredErrorDomain],	WNLibWiredErrorKey,
										 [_address string],									WIArgumentErrorKey,
										 NULL]];
		}
		
		result = NO;
	}
	
	wi_release(pool);
	
	return result;
}



#pragma mark -

- (NSString *)readStringOfLength:(NSUInteger)length encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error {
	NSMutableString		*string, *substring;
	wi_pool_t			*pool;
	char				buffer[WNSocketBufferSize];
	wi_integer_t		bytes = -1;
	
	pool = wi_pool_init(wi_pool_alloc());
	string = [[NSMutableString alloc] initWithCapacity:length];
	
	while(length > sizeof(buffer)) {
		bytes = wi_socket_read_buffer(_socket, timeout, buffer, sizeof(buffer));
		
		if(bytes <= 0)
			goto end;
		
		substring = [[NSString alloc] initWithBytes:buffer length:bytes encoding:encoding];
		
		if(substring) {
			[string appendString:substring];
			[substring release];
			
			length -= bytes;
		}
	}
	
	if(length > 0) {
		do {
			bytes = wi_socket_read_buffer(_socket, timeout, buffer, length);
			
			if(bytes <= 0)
				goto end;
			
			substring = [[NSString alloc] initWithBytes:buffer length:bytes encoding:encoding];
			
			if(substring) {
				[string appendString:substring];
				[substring release];
			}
		} while(!substring);
	}

end:
	if([string length] == 0) {
		if(bytes < 0) {
			if(error) {
				*error = [WNError errorWithDomain:WNWiredNetworkingErrorDomain
											 code:WNSocketReadFailed
										 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											 [WNError errorWithDomain:WNLibWiredErrorDomain],	WNLibWiredErrorKey,
											 [_address string],									WIArgumentErrorKey,
											 NULL]];
			}

			[string release];
			
			string = NULL;
		}
	}
	
	wi_release(pool);
	
	return [string autorelease];
}



- (NSString *)readStringUpToString:(NSString *)separator encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error {
	NSString		*string, *substring;
	NSUInteger		index;
	
	index = [_buffer rangeOfString:separator].location;
	
	if(index != NSNotFound) {
		substring = [_buffer substringToIndex:index + [separator length]];
		
		[_buffer deleteCharactersInRange:NSMakeRange(0, [substring length])];
		
		return substring;
	}
	
	while((string = [self readStringOfLength:WNSocketBufferSize encoding:encoding timeout:timeout error:error])) {
		if([string length] == 0)
			return string;
		
		[_buffer appendString:string];
		
		index = [_buffer rangeOfString:separator].location;
		
		if(index == NSNotFound) {
			if([_buffer length] > _WNSocketBufferMaxSize) {
				substring = [_buffer substringToIndex:_WNSocketBufferMaxSize];
				
				[_buffer deleteCharactersInRange:NSMakeRange(0, [substring length])];
				
				return substring;
			}
		} else {
			substring = [_buffer substringToIndex:index + [separator length]];
			
			[_buffer deleteCharactersInRange:NSMakeRange(0, [substring length])];
			
			return substring;
		}
	}
	
	return NULL;
}

@end
