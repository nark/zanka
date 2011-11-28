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

@interface WCSettings : NSObject

#define WCNick									@"WCNick"
#define WCIcon									@"WCIcon"

#define WCTextFont								@"WCTextFont"
#define WCShowConnectAtStartup					@"WCShowConnectAtStartup"
#define WCConfirmDisconnect						@"WCConfirmDisconnect"

#define WCBookmarks								@"WCBookmarks"

#define WCChatTextColor							@"WCChatTextColor"
#define WCChatBackgroundColor					@"WCChatBackgroundColor"
#define WCEventTextColor						@"WCEventTextColor"
#define WCURLTextColor							@"WCURLTextColor"
#define WCNickCompleteWith						@"WCNickCompleteWith"
#define WCShowEventTimestamps					@"WCShowEventTimestamps"
#define WCShowChatTimestamps					@"WCShowChatTimestamps"
#define WCOptionKeyForHistory					@"WCOptionKeyForHistory"

#define WCNewsTextColor							@"WCNewsTextColor"
#define WCNewsBackgroundColor					@"WCNewsBackgroundColor"
#define WCLoadNewsOnLogin						@"WCLoadNewsOnLogin"
#define WCSoundForNewPosts						@"WCSoundForNewPosts"

#define WCMessageTextColor						@"WCMessageTextColor"
#define WCMessageBackgroundColor				@"WCMessageBackgroundColor"
#define WCShowMessagesInForeground				@"WCShowMessagesInForeground"

#define WCDownloadFolder						@"WCDownloadFolder"
#define WCOpenFoldersInNewWindows				@"WCOpenFoldersInNewWindows"
#define WCQueueTransfers						@"WCQueueTransfers"
#define WCEncryptTransfers						@"WCEncryptTransfers"

#define WCIgnoredUsers							@"WCIgnoredUsers"

#define WCTrackerBookmarks						@"WCTrackerBookmarks"

#define WCShowAccounts							@"WCShowAccounts"
#define WCShowConsole							@"WCShowConsole"
#define WCShowMessages							@"WCShowMessages"
#define WCShowNews								@"WCShowNews"
#define WCShowTransfers							@"WCShowTransfers"


+ (id)											objectForKey:(id)key;
+ (id)											archivedObjectForKey:(id)key;
+ (void)										setObject:(id)object forKey:(id)key;
+ (void)										setArchivedObject:(id)object forKey:(id)key;

@end
