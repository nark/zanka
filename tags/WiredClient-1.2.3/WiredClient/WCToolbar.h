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

@class WCConnection, WCPreferences, WCToolbarItem;

@interface WCToolbar : NSObject {
	WCConnection				*_connection;
	WCPreferences				*_preferences;
	
	NSToolbar					*_toolbar;
	NSMutableDictionary			*_toolbarItems;
}


#define WCChatToolbar			@"WCChatToolbar"
#define WCPreferencesToolbar	@"WCPreferencesToolbar"


- (id)							initWithConnection:(WCConnection *)connection;
- (id)							initWithPreferences:(WCPreferences *)preferences;

- (NSToolbar *)					chatToolbar;
- (NSToolbar *)					preferencesToolbar;

- (void)						addItem:(NSString *)identifier name:(NSString *)name selector:(SEL)selector content:(id)content action:(SEL)action;
- (BOOL)						validateToolbarItem:(WCToolbarItem *)item;
- (void)						updateMessagesIcon:(unsigned int)unread;

@end
