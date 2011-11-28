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

#import <Cocoa/Cocoa.h>

@interface WCTracker : NSObject <NSCoding> {
	unsigned int			_type;
	unsigned int			_count;
	unsigned int			_state;
	NSString				*_name;
	unsigned int			_users;
	unsigned long long		_speed;
	BOOL					_guest;
	BOOL					_download;
	unsigned int			_files;
	unsigned long long		_size;
	NSString				*_description;
	NSNetService			*_service;
	NSURL					*_url;
	NSMutableArray			*_children;
}


#define						WCTrackerTypeRendezvous				0
#define						WCTrackerTypeCategory				1
#define						WCTrackerTypeServer					2
#define						WCTrackerTypeTracker				3

#define						WCTrackerStateIdle					0
#define						WCTrackerStateExpanding				1
#define						WCTrackerStateDone					2


- (id)						initWithType:(unsigned int)type;

- (void)					setState:(unsigned int)value;
- (unsigned int)			state;

- (void)					setType:(unsigned int)value;
- (unsigned int)			type;

- (void)					setCount:(unsigned int)value;
- (unsigned int)			count;

- (void)					setName:(NSString *)value;
- (NSString *)				name;

- (void)					setUsers:(unsigned int)value;
- (unsigned int)			users;

- (void)					setSpeed:(unsigned int)value;
- (unsigned int)			speed;

- (void)					setGuest:(BOOL)value;
- (BOOL)					guest;

- (void)					setDownload:(BOOL)value;
- (BOOL)					download;

- (void)					setFiles:(unsigned int)value;
- (unsigned int)			files;

- (void)					setSize:(unsigned long long)value;
- (unsigned long long)		size;

- (void)					setDescription:(NSString *)value;
- (NSString *)				description;

- (void)					setService:(NSNetService *)value;
- (NSNetService *)			service;
	
- (void)					setURL:(NSURL *)value;
- (NSURL *)					URL;
	
- (void)					addChild:(WCTracker *)child;
- (void)					removeChild:(WCTracker *)child;
- (NSMutableArray *)		children;
- (unsigned int)			servers;
- (NSMutableArray *)		filteredChildren:(NSString *)filter;

@end
