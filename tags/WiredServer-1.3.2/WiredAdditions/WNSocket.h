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

#import <openssl/ssl.h>

@interface WNSocketContext : WIObject {
	wi_socket_context_t				*_context;
}


+ (WNSocketContext *)socketContextForClient;

- (void)setSSLCiphers:(NSString *)iphers;

@end


#define WNSocketBufferSize			WI_SOCKET_BUFFER_SIZE


enum _WNSocketType {
	WNSocketTCP						= WI_SOCKET_TCP,
	WNSocketUDP						= WI_SOCKET_UDP
};
typedef enum _WNSocketType			WNSocketType;


enum _WNSocketDirection {
	WNSocketRead					= WI_SOCKET_READ,
	WNSocketWrite					= WI_SOCKET_WRITE
};
typedef enum _WNSocketDirection		WNSocketDirection;


@class WNAddress, WNError;

@interface WNSocket : WIObject {
	wi_socket_t						*_socket;
	
	WNAddress						*_address;
	
	NSMutableString					*_buffer;
}


+ (WNSocket *)socketWithAddress:(WNAddress *)address type:(WNSocketType)type;
+ (WNSocket *)socketWithFileDescriptor:(int)sd;

- (id)initWithAddress:(WNAddress *)address type:(WNSocketType)type;
- (id)initWithFileDescriptor:(int)sd;

- (WNAddress *)address;
- (int)fileDescriptor;
- (SSL *)SSL;
- (NSString *)cipherVersion;
- (NSString *)cipherName;
- (NSUInteger)cipherBits;
- (NSString *)certificateName;
- (NSUInteger)certificateBits;
- (NSString *)certificateHostname;

- (void)setPort:(NSUInteger)port;
- (NSUInteger)port;
- (void)setDirection:(WNSocketDirection)direction;
- (WNSocketDirection)direction;
- (void)setBlocking:(BOOL)blocking;
- (BOOL)blocking;
- (void)setInteractive:(BOOL)interactive;
- (BOOL)interactive;

- (BOOL)waitWithTimeout:(double)timeout;

- (BOOL)connectWithContext:(WNSocketContext *)context timeout:(double)timeout error:(WNError **)error;
- (void)close;

- (BOOL)writeString:(NSString *)string encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error;

- (NSString *)readStringOfLength:(NSUInteger)length encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error;
- (NSString *)readStringUpToString:(NSString *)separator encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WNError **)error;

@end
