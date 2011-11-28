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

#define WCTextFont								@"WCTextFont"
#define WCEventTextColor						@"WCEventTextColor"
#define WCURLTextColor							@"WCURLTextColor"
#define WCShowConnectAtStartup					@"WCShowConnectAtStartup"
#define WCShowTrackersAtStartup					@"WCShowTrackersAtStartup"
#define WCConfirmDisconnect						@"WCConfirmDisconnect"

#define WCNick									@"WCNick"
#define WCStatus								@"WCStatus"
#define WCCustomIcon							@"WCCustomIcon"
#define WCIcon									@"WCIcon"

#define WCBookmarks								@"WCBookmarks"
#define WCBookmarksName								@"Name"
#define WCBookmarksAddress							@"Address"
#define WCBookmarksLogin							@"Login"
#define WCBookmarksPassword							@"Password"

#define WCChatTextColor							@"WCChatTextColor"
#define WCChatBackgroundColor					@"WCChatBackgroundColor"
#define WCChatStyle								@"WCChatStyle"
#define WCChatStyleWired							0
#define WCChatStyleIRC								1
#define WCIconSize								@"WCIconSize"
#define WCIconSizeLarge								0
#define WCIconSizeSmall								1
#define WCHistoryScrollback						@"WCHistoryScrollback"
#define WCHistoryScrollbackModifier				@"WCHistoryScrollbackModifier"
#define WCHistoryScrollbackModifierNone				0
#define WCHistoryScrollbackModifierCommand			1
#define WCHistoryScrollbackModifierOption			2
#define WCHistoryScrollbackModifierControl			3
#define WCHighlightWords						@"WCHighlightWords"
#define WCHighlightWordsWords					@"WCHighlightWordsWords"
#define WCHighlightWordsTextColor				@"WCHighlightWordsTextColor"
#define WCTabCompleteNicks						@"WCTabCompleteNicks"
#define WCTabCompleteNicksString				@"WCTabCompleteNicksString"
#define WCTimestampChat							@"WCTimestampChat"
#define WCTimestampChatInterval					@"WCTimestampChatInterval"
#define WCTimestampEveryLine					@"WCTimestampEveryLine"
#define WCTimestampEveryLineTextColor			@"WCTimestampEveryLineTextColor"
#define WCShowJoinLeave							@"WCShowJoinLeave"
#define WCShowNickChanges						@"WCShowNickChanges"

#define WCNewsFont								@"WCNewsFont"
#define WCNewsTextColor							@"WCNewsTextColor"
#define WCNewsBackgroundColor					@"WCNewsBackgroundColor"
#define WCLoadNewsOnLogin						@"WCLoadNewsOnLogin"

#define WCMessageTextColor						@"WCMessageTextColor"
#define WCMessageBackgroundColor				@"WCMessageBackgroundColor"
#define WCShowMessagesInForeground				@"WCShowMessagesInForeground"
#define WCShowMessagesInChat					@"WCShowMessagesInChat"

#define WCDownloadFolder						@"WCDownloadFolder"
#define WCOpenFoldersInNewWindows				@"WCOpenFoldersInNewWindows"
#define WCQueueTransfers						@"WCQueueTransfers"
#define WCEncryptTransfers						@"WCEncryptTransfers"
#define WCRemoveTransfers						@"WCRemoveTransfers"

#define WCIgnores								@"WCIgnores"
#define WCIgnoresNick								@"Nick"
#define WCIgnoresLogin								@"Login"
#define WCIgnoresAddress							@"Address"

#define WCTrackerBookmarks						@"WCTrackerBookmarks"
#define WCTrackerBookmarksName						@"Name"
#define WCTrackerBookmarksAddress					@"Address"

#define WCConnectedEventSound					@"WCConnectedEventSound"
#define WCDisconnectedEventSound				@"WCDisconnectedEventSound"
#define WCChatEventSound						@"WCChatEventSound"
#define WCUserJoinEventSound					@"WCUserJoinEventSound"
#define WCUserLeaveEventSound					@"WCUserLeaveEventSound"
#define WCMessagesEventSound					@"WCMessagesEventSound"
#define WCNewsEventSound						@"WCNewsEventSound"
#define WCBroadcastEventSound					@"WCBroadcastEventSound"
#define WCTransferStartedEventSound				@"WCTransferStartedEventSound"
#define WCTransferDoneEventSound				@"WCTransferDoneEventSound"

#define WCShowAccounts							@"WCShowAccounts"
#define WCShowConsole							@"WCShowConsole"
#define WCShowMessages							@"WCShowMessages"
#define WCShowNews								@"WCShowNews"
#define WCShowTransfers							@"WCShowTransfers"

#define WCSSLControlCiphers						@"WCSSLControlCiphers"
#define WCSSLNullControlCiphers					@"WCSSLNullControlCiphers"
#define WCSSLTransferCiphers					@"WCSSLTransferCiphers"
#define WCSSLNullTransferCiphers				@"WCSSLNullTransferCiphers"


+ (id)											objectForKey:(id)key;
+ (NSString *)									stringForKey:(id)key;
+ (BOOL)										boolForKey:(id)key;
+ (int)											intForKey:(id)key;
+ (id)											archivedObjectForKey:(id)key;
+ (void)										setObject:(id)object forKey:(id)key;
+ (void)										setArchivedObject:(id)object forKey:(id)key;

@end
