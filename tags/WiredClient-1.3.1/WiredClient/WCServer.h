/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

@class WCAccount;

@interface WCServer : WIObject <NSCoding> {
	NSString				*_name;
	NSString				*_serverDescription;
	NSString				*_serverVersion;
	WIURL					*_url;
	NSDate					*_startupDate;
	double					_protocol;
	NSImage					*_banner;
	unsigned int			_files;
	unsigned long long		_size;
	WCAccount				*_account;
}


- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setServerDescription:(NSString *)serverDescription;
- (NSString *)serverDescription;
- (void)setServerVersion:(NSString *)serverVersion;
- (NSString *)serverVersion;
- (void)setURL:(WIURL *)url;
- (WIURL *)URL;
- (void)setStartupDate:(NSDate *)startDate;
- (NSDate *)startupDate;
- (void)setProtocol:(double)protocol;
- (double)protocol;
- (void)setBanner:(NSImage *)banner;
- (NSImage *)banner;
- (void)setFiles:(unsigned int)files;
- (unsigned int)files;
- (void)setSize:(unsigned long long)setSize;
- (unsigned long long)size;
- (void)setAccount:(WCAccount *)account;
- (WCAccount *)account;

@end
