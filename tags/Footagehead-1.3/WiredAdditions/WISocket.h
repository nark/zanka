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

@interface WISocketContext : WIObject {
	wi_socket_context_t				*_context;
}


+ (WISocketContext *)socketContextForClient;

- (void)setSSLCiphers:(NSString *)iphers;

@end


#define WISocketBufferSize			WI_SOCKET_BUFFER_SIZE


enum _WISocketType {
	WISocketTCP						= WI_SOCKET_TCP,
	WISocketUDP						= WI_SOCKET_UDP
};
typedef enum _WISocketType			WISocketType;


enum _WISocketDirection {
	WISocketRead					= WI_SOCKET_READ,
	WISocketWrite					= WI_SOCKET_WRITE
};
typedef enum _WISocketDirection		WISocketDirection;


@class WIAddress, WIError;

@interface WISocket : WIObject {
	wi_socket_t						*_socket;
	
	WIAddress						*_address;
	
	NSMutableString					*_buffer;
}


+ (WISocket *)socketWithAddress:(WIAddress *)address type:(WISocketType)type;
+ (WISocket *)socketWithFileDescriptor:(int)sd;

- (id)initWithAddress:(WIAddress *)address type:(WISocketType)type;
- (id)initWithFileDescriptor:(int)sd;

- (WIAddress *)address;
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
- (void)setDirection:(WISocketDirection)direction;
- (WISocketDirection)direction;
- (void)setBlocking:(BOOL)blocking;
- (BOOL)blocking;
- (void)setInteractive:(BOOL)interactive;
- (BOOL)interactive;

- (BOOL)waitWithTimeout:(double)timeout;

- (BOOL)connectWithContext:(WISocketContext *)context timeout:(double)timeout error:(WIError **)error;
- (void)close;

- (BOOL)writeString:(NSString *)string encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WIError **)error;

- (NSString *)readStringOfLength:(NSUInteger)length encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WIError **)error;
- (NSString *)readStringUpToString:(NSString *)separator encoding:(NSStringEncoding)encoding timeout:(double)timeout error:(WIError **)error;

@end
