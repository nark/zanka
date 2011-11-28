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

enum _WNAddressFamily {
	WNAddressNull					= WI_ADDRESS_NULL,
	WNAddressIPv4					= WI_ADDRESS_IPV4,
	WNAddressIPv6					= WI_ADDRESS_IPV6
};
typedef enum _WNAddressFamily		WNAddressFamily;


@class WNError;

@interface WNAddress : WIObject {
	wi_address_t					*_address;
}


+ (WNAddress *)addressWithString:(NSString *)address error:(WNError **)error;
+ (WNAddress *)addressWithNetService:(NSNetService *)netService error:(WNError **)error;

- (id)initWithString:(NSString *)address error:(WNError **)error;
- (id)initWithNetService:(NSNetService *)netService error:(WNError **)error;

- (void)setPort:(NSUInteger)port;
- (NSUInteger)port;

- (WNAddressFamily)family;
- (NSString *)string;
- (NSString *)hostname;

@end


@interface WNAddress(WISocketAdditions)

- (wi_address_t *)address;

@end
