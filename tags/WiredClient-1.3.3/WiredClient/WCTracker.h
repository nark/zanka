/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

enum _WCTrackerType {
	WCTrackerBonjour,
	WCTrackerCategory,
	WCTrackerServer,
	WCTrackerTracker
};
typedef enum _WCTrackerType		WCTrackerType;

enum _WCTrackerState {
	WCTrackerIdle,
	WCTrackerLoading
};
typedef enum _WCTrackerState	WCTrackerState;


@interface WCTracker : WIObject {
	WCTrackerType				_type;
	WCTrackerState				_state;
	double						_protocol;
	NSImage						*_icon;
	NSString					*_name;
	NSString					*_serverDescription;
	WIURL						*_url;
	NSUInteger					_users;
	NSUInteger					_speed;
	NSUInteger					_files;
	WIFileOffset				_size;
	BOOL						_guest;
	BOOL						_download;
	NSNetService				*_netService;

	NSMutableArray				*_children;
}


+ (id)bonjourTracker;
+ (id)bonjourServerWithNetService:(NSNetService *)netService;
+ (id)trackerWithBookmark:(NSDictionary *)bookmark;
+ (id)trackerCategoryWithName:(NSString *)name;
+ (id)trackerServerWithArguments:(NSArray *)arguments;

- (void)setState:(WCTrackerState)state;
- (WCTrackerState)state;

- (void)setProtocol:(double)protocol;
- (double)protocol;

- (WCTrackerType)type;
- (NSImage *)icon;
- (NSString *)name;
- (NSString *)nameWithNumberOfServers;
- (NSString *)nameWithNumberOfServersMatchingFilter:(NSString *)filter;
- (NSString *)serverDescription;
- (NSUInteger)users;
- (NSUInteger)speed;
- (NSUInteger)files;
- (WIFileOffset)size;
- (BOOL)guest;
- (BOOL)download;
- (WIURL *)URL;
- (NSNetService *)netService;
- (BOOL)matchesFilter:(NSString *)filter;

- (void)addChild:(WCTracker *)child;
- (void)removeChild:(WCTracker *)child;
- (void)removeAllChildren;
- (NSEnumerator *)childEnumerator;
- (void)sortChildrenUsingSelector:(SEL)selector;
- (NSArray *)childrenMatchingFilter:(NSString *)filter;

- (WCTracker *)categoryWithName:(NSString *)name;
- (WCTracker *)categoryForPath:(NSString *)path;
- (NSUInteger)numberOfServers;
- (NSUInteger)numberOfServersMatchingFilter:(NSString *)filter;

- (NSComparisonResult)compareType:(WCTracker *)tracker;
- (NSComparisonResult)compareName:(WCTracker *)tracker;
- (NSComparisonResult)compareUsers:(WCTracker *)tracker;
- (NSComparisonResult)compareSpeed:(WCTracker *)tracker;
- (NSComparisonResult)compareGuest:(WCTracker *)tracker;
- (NSComparisonResult)compareDownload:(WCTracker *)tracker;
- (NSComparisonResult)compareFiles:(WCTracker *)tracker;
- (NSComparisonResult)compareSize:(WCTracker *)tracker;
- (NSComparisonResult)compareDescription:(WCTracker *)tracker;

@end
