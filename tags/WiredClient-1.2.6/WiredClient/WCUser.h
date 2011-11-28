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

@interface WCUser : NSObject <NSCoding> {
	unsigned int			_uid;
	BOOL					_idle;
	BOOL					_admin;
	int						_icon;
	NSString				*_nick;
	NSString				*_login;
	NSString				*_address;
	NSString				*_host;
	NSString				*_status;
	NSImage					*_iconImage;
	NSDate					*_joinTime;
}


- (void)					setUid:(unsigned int)value;
- (unsigned int)			uid;

- (void)					setIdle:(BOOL)value;
- (BOOL)					isIdle;

- (void)					setAdmin:(BOOL)value;
- (BOOL)					isAdmin;

- (void)					setIcon:(int)value;
- (void)					setIconImage:(NSImage *)value;
- (NSImage *)				iconWithIdleTint:(BOOL)value;

- (void)					setNick:(NSString *)value;
- (NSString *)				nick;

- (void)					setLogin:(NSString *)value;
- (NSString *)				login;

- (void)					setAddress:(NSString *)value;
- (NSString *)				address;

- (void)					setHost:(NSString *)value;
- (NSString *)				host;

- (void)					setStatus:(NSString *)value;
- (NSString *)				status;

- (void)					setJoinTime:(NSDate *)value;
- (NSDate *)				joinTime;

- (NSColor *)				color;
- (BOOL)					ignore;

@end
