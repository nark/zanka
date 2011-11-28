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

enum WCTrackerType {
	WCTrackerTypeRendezvous		= 0,
	WCTrackerTypeCategory,
	WCTrackerTypeServer,
	WCTrackerTypeTracker
};
typedef enum WCTrackerType		WCTrackerType;

enum WCTrackerState {
	WCTrackerStateIdle			= 0,
	WCTrackerStateExpanding,
	WCTrackerStateDone
};
typedef enum WCTrackerState		WCTrackerState;


@interface WCTracker : NSObject {
	WCTrackerType				_type;
	WCTrackerState				_state;

	NSString					*_name;
	NSString					*_description;
	NSURL						*_url;
	NSString					*_urlString;
	unsigned int				_users;
	NSString					*_usersString;
	unsigned int				_speed;
	NSString					*_speedString;
	unsigned int				_files;
	NSString					*_filesString;
	unsigned long long			_size;
	NSString					*_sizeString;
	BOOL						_guest;
	NSString					*_guestString;
	BOOL						_download;
	NSString					*_downloadString;
	
	NSNetService				*_service;
	double						_protocol;
	NSMutableArray				*_children;
}


- (id)							initWithType:(WCTrackerType)type;

- (void)						setType:(WCTrackerType)value;
- (WCTrackerType)				type;

- (void)						setState:(WCTrackerState)value;
- (WCTrackerState)				state;

- (void)						setName:(NSString *)value;
- (NSString *)					name;

- (void)						setDescription:(NSString *)value;
- (NSString *)					description;

- (void)						setUsers:(unsigned int)value;
- (unsigned int)				users;
- (NSString *)					usersString;

- (void)						setSpeed:(unsigned int)value;
- (unsigned int)				speed;
- (NSString *)					speedString;

- (void)						setFiles:(unsigned int)value;
- (unsigned int)				files;
- (NSString *)					filesString;

- (void)						setSize:(unsigned long long)value;
- (unsigned long long)			size;
- (NSString *)					sizeString;

- (void)						setGuest:(BOOL)value;
- (BOOL)						guest;
- (NSString *)					guestString;

- (void)						setDownload:(BOOL)value;
- (BOOL)						download;
- (NSString *)					downloadString;
	
- (void)						setURL:(NSURL *)value;
- (NSURL *)						URL;
- (NSString *)					URLString;

- (void)						setService:(NSNetService *)value;
- (NSNetService *)				service;

- (void)						setProtocol:(double)value;
- (double)						protocol;
	
- (void)						addChild:(WCTracker *)child;
- (void)						removeChild:(WCTracker *)child;
- (NSMutableArray *)			children;
- (unsigned int)				servers;
- (NSMutableArray *)			filteredChildren:(NSString *)filter;
- (void)						sortChildrenUsingSelector:(SEL)selector;

@end
