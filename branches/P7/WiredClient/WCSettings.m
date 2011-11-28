/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "WCKeychain.h"
#import "WCPreferences.h"

#define _WCAutoHideOnSwitch								@"WCAutoHideOnSwitch"
#define _WCPreventMultipleConnections					@"WCPreventMultipleConnections"

#define _WCChatTextColor								@"WCChatTextColor"
#define _WCChatBackgroundColor							@"WCChatBackgroundColor"
#define _WCChatEventsColor								@"WCChatEventsColor"
#define _WCChatURLsColor								@"WCChatURLsColor"
#define _WCChatFont										@"WCChatFont"
#define _WCChatUserListAlternateRows					@"WCChatUserListAlternateRows"
#define _WCChatUserListIconSize							@"WCChatUserListIconSize"

#define _WCShowSmileys									@"WCShowSmileys"
#define _WCTimestampEveryLine							@"WCTimestampEveryLine"
#define _WCTimestampEveryLineColor						@"WCTimestampEveryLineColor"

#define _WCMessagesTextColor							@"WCMessagesTextColor"
#define _WCMessagesBackgroundColor						@"WCMessagesBackgroundColor"
#define _WCMessagesFont									@"WCMessagesFont"
#define _WCMessagesListAlternateRows					@"WCMessagesListAlternateRows"

#define _WCNewsTextColor								@"WCNewsTextColor"
#define _WCNewsBackgroundColor							@"WCNewsBackgroundColor"
#define _WCNewsFont										@"WCNewsFont"

#define _WCFilesAlternateRows							@"WCFilesAlternateRows"

#define _WCTransfersShowProgressBar						@"WCTransfersShowProgressBar"
#define _WCTransfersAlternateRows						@"WCTransfersAlternateRows"

#define _WCTrackersAlternateRows						@"WCTrackersAlternateRows"

#define _WCWindowTemplates								@"WCWindowTemplates"
#define _WCWindowTemplatesDefault						@"WCWindowTemplatesDefault"


NSString * const WCNick									= @"WCNick";
NSString * const WCStatus								= @"WCStatus";
NSString * const WCIcon									= @"WCCustomIcon";

NSString * const WCCheckForUpdate						= @"WCCheckForUpdate";

NSString * const WCShowConnectAtStartup					= @"WCShowConnectAtStartup";
NSString * const WCShowServersAtStartup					= @"WCShowTrackersAtStartup";

NSString * const WCConfirmDisconnect					= @"WCConfirmDisconnect";
NSString * const WCAutoReconnect						= @"WCAutoReconnect";

NSString * const WCTheme								= @"WCTheme";

NSString * const WCThemes								= @"WCThemes";
NSString * const WCThemesName							= @"WCThemesName";
NSString * const WCThemesBuiltinName					= @"WCThemesBuiltinName";
NSString * const WCThemesIdentifier						= @"WCThemesIdentifier";
NSString * const WCThemesShowSmileys					= @"WCThemesShowSmileys";
NSString * const WCThemesChatFont						= @"WCThemesChatFont";
NSString * const WCThemesChatTextColor					= @"WCThemesChatTextColor";
NSString * const WCThemesChatBackgroundColor			= @"WCThemesChatBackgroundColor";
NSString * const WCThemesChatEventsColor				= @"WCThemesChatEventsColor";
NSString * const WCThemesChatURLsColor					= @"WCThemesChatURLsColor";
NSString * const WCThemesChatTimestampEveryLineColor	= @"WCThemesChatTimestampEveryLineColor";
NSString * const WCThemesChatTimestampEveryLine			= @"WCThemesChatTimestampEveryLine";
NSString * const WCThemesMessagesFont					= @"WCThemesMessagesFont";
NSString * const WCThemesMessagesTextColor				= @"WCThemesMessagesTextColor";
NSString * const WCThemesMessagesBackgroundColor		= @"WCThemesMessagesBackgroundColor";
NSString * const WCThemesBoardsFont						= @"WCThemesBoardsFont";
NSString * const WCThemesBoardsTextColor				= @"WCThemesBoardsTextColor";
NSString * const WCThemesBoardsBackgroundColor			= @"WCThemesBoardsBackgroundColor";
NSString * const WCThemesUserListIconSize				= @"WCThemesUserListIconSize";
NSString * const WCThemesUserListAlternateRows			= @"WCThemesUserListAlternateRows";
NSString * const WCThemesFileListAlternateRows			= @"WCThemesFileListAlternateRows";
NSString * const WCThemesFileListIconSize				= @"WCThemesFileListIconSize";
NSString * const WCThemesTransferListShowProgressBar	= @"WCThemesTransferListShowProgressBar";
NSString * const WCThemesTransferListAlternateRows		= @"WCThemesTransferListAlternateRows";
NSString * const WCThemesTrackerListAlternateRows		= @"WCThemesTrackerListAlternateRows";
NSString * const WCThemesMonitorIconSize				= @"WCThemesMonitorIconSize";
NSString * const WCThemesMonitorAlternateRows			= @"WCThemesMonitorAlternateRows";

NSString * const WCMessageConversations					= @"WCMessageConversations";
NSString * const WCBroadcastConversations				= @"WCBroadcastConversations";

NSString * const WCBookmarks							= @"WCBookmarks";
NSString * const WCBookmarksName						= @"Name";
NSString * const WCBookmarksAddress						= @"Address";
NSString * const WCBookmarksLogin						= @"Login";
NSString * const WCBookmarksPassword					= @"Password";
NSString * const WCBookmarksIdentifier					= @"Identifier";
NSString * const WCBookmarksNick						= @"Nick";
NSString * const WCBookmarksStatus						= @"Status";
NSString * const WCBookmarksAutoConnect					= @"AutoJoin";
NSString * const WCBookmarksAutoReconnect				= @"AutoReconnect";
NSString * const WCBookmarksTheme						= @"Theme";

NSString * const WCChatHistoryScrollback				= @"WCHistoryScrollback";
NSString * const WCChatHistoryScrollbackModifier		= @"WCHistoryScrollbackModifier";
NSString * const WCChatTabCompleteNicks					= @"WCTabCompleteNicks";
NSString * const WCChatTabCompleteNicksString			= @"WCTabCompleteNicksString";
NSString * const WCChatTimestampChat					= @"WCTimestampChat";
NSString * const WCChatTimestampChatInterval			= @"WCTimestampChatInterval";

NSString * const WCHighlights							= @"WCHighlights";
NSString * const WCHighlightsPattern					= @"WCHighlightsPattern";
NSString * const WCHighlightsColor						= @"WCHighlightsColor";

NSString * const WCIgnores								= @"WCIgnores";
NSString * const WCIgnoresNick							= @"Nick";

NSString * const WCEvents								= @"WCEvents";
NSString * const WCEventsEvent							= @"WCEventsEvent";
NSString * const WCEventsPlaySound						= @"WCEventsPlaySound";
NSString * const WCEventsSound							= @"WCEventsSound";
NSString * const WCEventsBounceInDock					= @"WCEventsBounceInDock";
NSString * const WCEventsPostInChat						= @"WCEventsPostInChat";
NSString * const WCEventsShowDialog						= @"WCEventsShowDialog";

NSString * const WCEventsVolume							= @"WCEventsVolume";

NSString * const WCTransferList							= @"WCTransferList";
NSString * const WCDownloadFolder						= @"WCDownloadFolder";
NSString * const WCOpenFoldersInNewWindows				= @"WCOpenFoldersInNewWindows";
NSString * const WCQueueTransfers						= @"WCQueueTransfers";
NSString * const WCCheckForResourceForks				= @"WCCheckForResourceForks";
NSString * const WCRemoveTransfers						= @"WCRemoveTransfers";
NSString * const WCFilesStyle							= @"WCFilesStyle";

NSString * const WCTrackerBookmarks						= @"WCTrackerBookmarks";
NSString * const WCTrackerBookmarksName					= @"Name";
NSString * const WCTrackerBookmarksAddress				= @"Address";
NSString * const WCTrackerBookmarksLogin				= @"Login";
NSString * const WCTrackerBookmarksPassword				= @"Password";
NSString * const WCTrackerBookmarksIdentifier			= @"Identifier";

NSString * const WCWindowProperties						= @"WCWindowProperties";

NSString * const WCCollapsedBoards						= @"WCCollapsedBoards";
NSString * const WCReadBoardPosts						= @"WCReadBoardPosts";
NSString * const WCBoardFilters							= @"WCBoardFilters";
NSString * const WCBoardPostContinuousSpellChecking		= @"WCBoardPostContinuousSpellChecking";

NSString * const WCPlaces								= @"WCPlaces";

NSString * const WCDebug								= @"WCDebug";


@interface WCSettings(Private)

- (void)_upgrade;

- (NSDictionary *)_themeWithBuiltinName:(NSString *)builtinName;

@end


@implementation WCSettings(Private)

- (void)_upgrade {
	NSEnumerator			*enumerator, *keyEnumerator;
	NSDictionary			*defaults, *defaultTheme;
	NSArray					*themes, *bookmarks;
	NSMutableArray			*newThemes, *newBookmarks;
	NSDictionary			*theme, *builtinTheme, *bookmark;
	NSMutableDictionary		*newTheme, *newBookmark;
	NSString				*key, *password, *identifier, *builtinName;
	
	defaults		= [self defaults];
	defaultTheme	= [[defaults objectForKey:WCThemes] objectAtIndex:0];
	
	/* Convert old font/color settings to theme */
	if([[self objectForKey:WCThemes] isEqualToArray:[NSArray arrayWithObject:defaultTheme]]) {
		newTheme = [[defaultTheme mutableCopy] autorelease];
		
		if([self objectForKey:_WCChatURLsColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatURLsColor]])
						 forKey:WCThemesChatURLsColor];
		}
		
		if([self objectForKey:_WCChatTextColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatTextColor]])
						 forKey:WCThemesChatTextColor];
		}
		
		if([self objectForKey:_WCChatBackgroundColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatBackgroundColor]])
						 forKey:WCThemesChatBackgroundColor];
		}
		
		if([self objectForKey:_WCChatEventsColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatEventsColor]])
						 forKey:WCThemesChatEventsColor];
		}
		
		if([self objectForKey:_WCChatFont]) {
			[newTheme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatFont]])
						 forKey:WCThemesChatFont];
		}
		
		if([self objectForKey:_WCTimestampEveryLine]) {
			[newTheme setObject:[self objectForKey:_WCTimestampEveryLine]
						 forKey:WCThemesChatTimestampEveryLine];
		}
		
		if([self objectForKey:_WCTimestampEveryLineColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCTimestampEveryLineColor]])
						 forKey:WCThemesChatTimestampEveryLineColor];
		}
		
		if([self objectForKey:_WCMessagesTextColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesTextColor]])
						 forKey:WCThemesMessagesTextColor];
		}
		
		if([self objectForKey:_WCMessagesBackgroundColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesBackgroundColor]])
						 forKey:WCThemesMessagesBackgroundColor];
		}
		
		if([self objectForKey:_WCMessagesFont]) {
			[newTheme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesFont]])
						 forKey:WCThemesMessagesFont];
		}
		
		if([self objectForKey:_WCNewsTextColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsTextColor]])
						 forKey:WCThemesBoardsTextColor];
		}
		
		if([self objectForKey:_WCNewsBackgroundColor]) {
			[newTheme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsBackgroundColor]])
						 forKey:WCThemesBoardsBackgroundColor];
		}
		
		if([self objectForKey:_WCNewsFont]) {
			[newTheme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsFont]])
						 forKey:WCThemesBoardsFont];
		}
		
		if([self objectForKey:_WCFilesAlternateRows]) {
			[newTheme setObject:[self objectForKey:_WCFilesAlternateRows]
						 forKey:WCThemesFileListAlternateRows];
		}
		
		if([self objectForKey:_WCTransfersShowProgressBar]) {
			[newTheme setObject:[self objectForKey:_WCTransfersShowProgressBar]
						 forKey:WCThemesTransferListShowProgressBar];
		}
		
		if([self objectForKey:_WCTransfersAlternateRows]) {
			[newTheme setObject:[self objectForKey:_WCTransfersAlternateRows]
						 forKey:WCThemesTransferListAlternateRows];
		}
		
		if([self objectForKey:_WCTrackersAlternateRows]) {
			[newTheme setObject:[self objectForKey:_WCTrackersAlternateRows]
						 forKey:WCThemesTrackerListAlternateRows];
		}
		
		if([self objectForKey:_WCShowSmileys]) {
			[newTheme setObject:[self objectForKey:_WCShowSmileys]
						 forKey:WCThemesShowSmileys];
		}
		
		if(![newTheme isEqualToDictionary:defaultTheme]) {
			[newTheme setObject:@"Wired Client 1.x" forKey:WCThemesName];
			[newTheme setObject:[NSString UUIDString] forKey:WCThemesIdentifier];
			
			[self addObject:newTheme toArrayForKey:WCThemes];
		}

		/*		
		[self removeObjectForKey:_WCChatTextColor];
		[self removeObjectForKey:_WCChatBackgroundColor];
		[self removeObjectForKey:_WCChatEventsColor];
		[self removeObjectForKey:_WCChatURLsColor];
		[self removeObjectForKey:_WCChatFont];
		[self removeObjectForKey:_WCChatUserListAlternateRows];
		[self removeObjectForKey:_WCChatUserListIconSize];
		[self removeObjectForKey:_WCTimestampEveryLineColor];
		[self removeObjectForKey:_WCMessagesTextColor];
		[self removeObjectForKey:_WCMessagesBackgroundColor];
		[self removeObjectForKey:_WCMessagesFont];
		[self removeObjectForKey:_WCMessagesListAlternateRows];
		[self removeObjectForKey:_WCNewsTextColor];
		[self removeObjectForKey:_WCNewsBackgroundColor];
		[self removeObjectForKey:_WCNewsFont];
		[self removeObjectForKey:_WCFilesAlternateRows];
		[self removeObjectForKey:_WCTransfersShowProgressBar];
		[self removeObjectForKey:_WCTransfersAlternateRows];
		[self removeObjectForKey:_WCTrackersAlternateRows];
		[self removeObjectForKey:_WCShowSmileys];
		*/
	}
	
	/* Convert themes */
	builtinName		= NULL;
	identifier		= [self objectForKey:WCTheme];
	themes			= [self objectForKey:WCThemes];
	newThemes		= [NSMutableArray array];
	enumerator		= [themes objectEnumerator];
	
	while((theme = [enumerator nextObject])) {
		if([theme objectForKey:WCThemesBuiltinName]) {
			if([[theme objectForKey:WCThemesIdentifier] isEqualToString:identifier])
				builtinName = [theme objectForKey:WCThemesBuiltinName];
		} else {
			newTheme		= [[theme mutableCopy] autorelease];
			keyEnumerator	= [defaultTheme keyEnumerator];
			
			while((key = [keyEnumerator nextObject])) {
				if(![key isEqualToString:WCThemesBuiltinName]) {
					if(![newTheme objectForKey:key])
						[newTheme setObject:[defaultTheme objectForKey:key] forKey:key];
				}
			}
			
			[newThemes addObject:newTheme];
		}
	}
	
	/* Add all default themes */
	enumerator = [[defaults objectForKey:WCThemes] reverseObjectEnumerator];
	
	while((builtinTheme = [enumerator nextObject])) {
		if([newThemes count] > 0)
			[newThemes insertObject:builtinTheme atIndex:0];
		else
			[newThemes addObject:builtinTheme];
		
		if(builtinName && [[builtinTheme objectForKey:WCThemesBuiltinName] isEqualToString:builtinName])
			[self setObject:[builtinTheme objectForKey:WCThemesIdentifier] forKey:WCTheme];
	}
	
	[self setObject:newThemes forKey:WCThemes];

	/* Convert bookmarks */
	bookmarks		= [self objectForKey:WCBookmarks];
	newBookmarks	= [NSMutableArray array];
	enumerator		= [bookmarks objectEnumerator];
	
	while((bookmark = [enumerator nextObject])) {
		newBookmark = [[bookmark mutableCopy] autorelease];
		
		if(![newBookmark objectForKey:WCBookmarksIdentifier])
			[newBookmark setObject:[NSString UUIDString] forKey:WCBookmarksIdentifier];

		if(![newBookmark objectForKey:WCBookmarksNick])
			[newBookmark setObject:@"" forKey:WCBookmarksNick];

		if(![newBookmark objectForKey:WCBookmarksStatus])
			[newBookmark setObject:@"" forKey:WCBookmarksStatus];
		
		password = [newBookmark objectForKey:WCBookmarksPassword];

		if(password) {
			if([password length] > 0)
				[[WCKeychain keychain] setPassword:password forBookmark:newBookmark];
			
			[newBookmark removeObjectForKey:WCBookmarksPassword];
		}
	
		[newBookmarks addObject:newBookmark];
	}
	
	[self setObject:newBookmarks forKey:WCBookmarks];

	/* Convert tracker bookmarks */
	bookmarks		= [self objectForKey:WCTrackerBookmarks];
	newBookmarks	= [NSMutableArray array];
	enumerator		= [bookmarks objectEnumerator];
	
	while((bookmark = [enumerator nextObject])) {
		newBookmark = [[bookmark mutableCopy] autorelease];
		
		if(![newBookmark objectForKey:WCTrackerBookmarksIdentifier])
			[newBookmark setObject:[NSString UUIDString] forKey:WCTrackerBookmarksIdentifier];

		if(![newBookmark objectForKey:WCTrackerBookmarksLogin])
			[newBookmark setObject:@"" forKey:WCTrackerBookmarksLogin];
		
		[newBookmarks addObject:newBookmark];
	}
	
	/* Check download folder */
	if(![[NSFileManager defaultManager] directoryExistsAtPath:[self objectForKey:WCDownloadFolder]])
		[self setObject:[@"~/Desktop" stringByExpandingTildeInPath] forKey:WCDownloadFolder];
	
	[self setObject:newBookmarks forKey:WCTrackerBookmarks];
}



#pragma mark -

- (NSDictionary *)_themeWithBuiltinName:(NSString *)builtinName {
	NSEnumerator	*enumerator;
	NSDictionary	*theme;
	
	enumerator = [[self objectForKey:WCThemes] objectEnumerator];
	
	while((theme = [enumerator nextObject])) {
		if([[theme objectForKey:WCThemesBuiltinName] isEqualToString:builtinName])
			return theme;
	}
	
	return NULL;
}

@end


@implementation WCSettings

+ (id)settings {
	static BOOL			upgraded;
#ifndef WCConfigurationRelease
	static BOOL			migrated;
	NSDictionary		*dictionary;
#endif
	id					settings;
	
#ifndef WCConfigurationRelease
	if(!migrated) {
		dictionary = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.zanka.WiredClientDebugP7"];
			
		if(!dictionary) {
			dictionary = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.zanka.WiredClient"];
			
			if(dictionary)
				[[NSUserDefaults standardUserDefaults] setPersistentDomain:dictionary forName:@"com.zanka.WiredClientDebugP7"];
		}
		
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
#endif
	
	settings = [super settings];
	
	if(!upgraded) {
		[settings _upgrade];
		
		upgraded = YES;
	}
	
	return settings;
}



#pragma mark -

- (NSDictionary *)defaults {
	static NSDictionary		*defaults;
	NSString				*basicThemeIdentifier;
	
	if(!defaults) {
		basicThemeIdentifier = [NSString UUIDString];
		
		defaults = [NSDictionary dictionaryWithObjectsAndKeys:
			NSUserName(),
				WCNick,
			@"",
				WCStatus,
			@"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAKQ2lDQ1BJQ0MgUHJv"
			@"ZmlsZQAAeAGdlndUU1kTwO97L73QEkKREnoNTUoAkRJ6kV5FJSQBQgkYErBXRAVX"
			@"FBVpiiKLIi64uhRZK6JYWBQUsC/IIqCsi6uIimVf9Bxl/9j9vrPzx5zfmztz79yZ"
			@"uec8ACi+gUJRJqwAQIZIIg7z8WDGxMYx8d0ABkSAA9YAcHnZWUHh3hEAFT8vDjMb"
			@"dZKxTKDP+nX/F7jF8g1hMj+b/n+lyMsSS9CdQtCQuXxBNg/lPJTTcyVZMvskyvTE"
			@"NBnDGBmL0QRRVpVx8hc2/+zzhd1kzM8Q8VEfWc5Z/Ay+jDtQ3pIjFaCMBKKcnyMU"
			@"5KJ8G2X9dGmGEOU3KNMzBNxsADAUmV0i4KWgbIUyRRwRxkF5HgAESvIsTpzFEsEy"
			@"NE8AOJlZy8XC5BQJ05hnwrR2dGQzfQW56QKJhBXC5aVxxXwmJzMjiytaDsCXO8ui"
			@"gJKstky0yPbWjvb2LBsLtPxf5V8Xv3r9O8h6+8XjZejnnkGMrm+2b7HfbJnVALCn"
			@"0Nrs+GZLLAOgZRMAqve+2fQPACCfB0DzjVn3YcjmJUUiyXKytMzNzbUQCngWsoJ+"
			@"lf/p8NXzn2HWeRay877WjukpSOJK0yVMWVF5memZUjEzO4vLEzBZfxtidOv/HDgr"
			@"rVl5mIcJkgRigQg9KgqdMqEoGW23iC+UCDNFTKHonzr8H8Nm5SDDL3ONAq3mI6Av"
			@"sQAKN+gA+b0LYGhkgMTvR1egr30LJEYB2cuL1h79Mvcoo+uf9d8UXIR+wtnCZKbM"
			@"zAmLYPKk4hwZo29CprCABOQBHagBLaAHjAEL2AAH4AzcgBfwB8EgAsSCxYAHUkAG"
			@"EINcsAqsB/mgEOwAe0A5qAI1oA40gBOgBZwGF8BlcB3cBH3gPhgEI+AZmASvwQwE"
			@"QXiICtEgNUgbMoDMIBuIDc2HvKBAKAyKhRKgZEgESaFV0EaoECqGyqGDUB30I3QK"
			@"ugBdhXqgu9AQNA79Cb2DEZgC02FN2BC2hNmwOxwAR8CL4GR4KbwCzoO3w6VwNXwM"
			@"boYvwNfhPngQfgZPIQAhIwxEB2EhbISDBCNxSBIiRtYgBUgJUo00IG1IJ3ILGUQm"
			@"kLcYHIaGYWJYGGeMLyYSw8MsxazBbMOUY45gmjEdmFuYIcwk5iOWitXAmmGdsH7Y"
			@"GGwyNhebjy3B1mKbsJewfdgR7GscDsfAGeEccL64WFwqbiVuG24frhF3HteDG8ZN"
			@"4fF4NbwZ3gUfjOfiJfh8fBn+GP4cvhc/gn9DIBO0CTYEb0IcQUTYQCghHCWcJfQS"
			@"RgkzRAWiAdGJGEzkE5cTi4g1xDbiDeIIcYakSDIiuZAiSKmk9aRSUgPpEukB6SWZ"
			@"TNYlO5JDyULyOnIp+Tj5CnmI/JaiRDGlcCjxFCllO+Uw5TzlLuUllUo1pLpR46gS"
			@"6nZqHfUi9RH1jRxNzkLOT44vt1auQq5ZrlfuuTxR3kDeXX6x/Ar5EvmT8jfkJxSI"
			@"CoYKHAWuwhqFCoVTCgMKU4o0RWvFYMUMxW2KRxWvKo4p4ZUMlbyU+Ep5SoeULioN"
			@"0xCaHo1D49E20mpol2gjdBzdiO5HT6UX0n+gd9MnlZWUbZWjlJcpVyifUR5kIAxD"
			@"hh8jnVHEOMHoZ7xT0VRxVxGobFVpUOlVmVado+qmKlAtUG1U7VN9p8ZU81JLU9up"
			@"1qL2UB2jbqoeqp6rvl/9kvrEHPoc5zm8OQVzTsy5pwFrmGqEaazUOKTRpTGlqaXp"
			@"o5mlWaZ5UXNCi6HlppWqtVvrrNa4Nk17vrZQe7f2Oe2nTGWmOzOdWcrsYE7qaOj4"
			@"6kh1Dup068zoGulG6m7QbdR9qEfSY+sl6e3Wa9eb1NfWD9JfpV+vf8+AaMA2SDHY"
			@"a9BpMG1oZBhtuNmwxXDMSNXIz2iFUb3RA2OqsavxUuNq49smOBO2SZrJPpObprCp"
			@"nWmKaYXpDTPYzN5MaLbPrMcca+5oLjKvNh9gUVjurBxWPWvIgmERaLHBosXiuaW+"
			@"ZZzlTstOy49WdlbpVjVW962VrP2tN1i3Wf9pY2rDs6mwuT2XOtd77tq5rXNf2JrZ"
			@"Cmz3296xo9kF2W22a7f7YO9gL7ZvsB930HdIcKh0GGDT2SHsbewrjlhHD8e1jqcd"
			@"3zrZO0mcTjj94cxyTnM+6jw2z2ieYF7NvGEXXReuy0GXwfnM+QnzD8wfdNVx5bpW"
			@"uz5203Pju9W6jbqbuKe6H3N/7mHlIfZo8pjmOHFWc857Ip4+ngWe3V5KXpFe5V6P"
			@"vHW9k73rvSd97HxW+pz3xfoG+O70HfDT9OP51flN+jv4r/bvCKAEhAeUBzwONA0U"
			@"B7YFwUH+QbuCHiwwWCBa0BIMgv2CdwU/DDEKWRrycyguNCS0IvRJmHXYqrDOcFr4"
			@"kvCj4a8jPCKKIu5HGkdKI9uj5KPio+qipqM9o4ujB2MsY1bHXI9VjxXGtsbh46Li"
			@"auOmFnot3LNwJN4uPj++f5HRomWLri5WX5y++MwS+SXcJScTsAnRCUcT3nODudXc"
			@"qUS/xMrESR6Ht5f3jO/G380fF7gIigWjSS5JxUljyS7Ju5LHU1xTSlImhBxhufBF"
			@"qm9qVep0WnDa4bRP6dHpjRmEjISMUyIlUZqoI1Mrc1lmT5ZZVn7W4FKnpXuWTooD"
			@"xLXZUPai7FYJHf2Z6pIaSzdJh3Lm51TkvMmNyj25THGZaFnXctPlW5ePrvBe8f1K"
			@"zEreyvZVOqvWrxpa7b764BpoTeKa9rV6a/PWjqzzWXdkPWl92vpfNlhtKN7wamP0"
			@"xrY8zbx1ecObfDbV58vli/MHNjtvrtqC2SLc0r117tayrR8L+AXXCq0KSwrfb+Nt"
			@"u/ad9Xel333anrS9u8i+aP8O3A7Rjv6drjuPFCsWryge3hW0q3k3c3fB7ld7luy5"
			@"WmJbUrWXtFe6d7A0sLS1TL9sR9n78pTyvgqPisZKjcqtldP7+Pt697vtb6jSrCqs"
			@"endAeODOQZ+DzdWG1SWHcIdyDj2piarp/J79fV2tem1h7YfDosODR8KOdNQ51NUd"
			@"1ThaVA/XS+vHj8Ufu/mD5w+tDayGg42MxsLj4Lj0+NMfE37sPxFwov0k+2TDTwY/"
			@"VTbRmgqaoeblzZMtKS2DrbGtPaf8T7W3Obc1/Wzx8+HTOqcrziifKTpLOpt39tO5"
			@"Feemzmedn7iQfGG4fUn7/YsxF293hHZ0Xwq4dOWy9+WLne6d5664XDl91enqqWvs"
			@"ay3X7a83d9l1Nf1i90tTt3138w2HG603HW+29czrOdvr2nvhluety7f9bl/vW9DX"
			@"0x/Zf2cgfmDwDv/O2N30uy/u5dybub/uAfZBwUOFhyWPNB5V/2rya+Og/eCZIc+h"
			@"rsfhj+8P84af/Zb92/uRvCfUJyWj2qN1YzZjp8e9x28+Xfh05FnWs5mJ/N8Vf698"
			@"bvz8pz/c/uiajJkceSF+8enPbS/VXh5+ZfuqfSpk6tHrjNcz0wVv1N4cect+2/ku"
			@"+t3oTO57/PvSDyYf2j4GfHzwKePTp78AA5vz/OzO54oAAAAJcEhZcwAACxMAAAsT"
			@"AQCanBgAAAa+SURBVFgJ7VZtbFvVGX7uteM4SWO7JWmbpUkM1SqkKFukIiBZAFuI"
			@"UYFEXaYy0f0gaIMNRmlRCm3VSU0rUJnKxhAanz+SikpErVBTlTWbNIGTlhY6UNIB"
			@"hXVrcfqRFBCx3dSJ77V9D897/EGWtVCJ/UHilZ97vt5z3uf9uOca+F6+QxEIkGsn"
			@"sYeIE2oWPuG4h4gQ/3fp5okXMzqbRHEsZC6LiPENVINcF49bRc/lM7GwbT4W//gq"
			@"zG0MIGfmkMlmYBPjH41jbHgck+9PQVnCQ0svn48QCT26yOPrCIjRN4mAUW6gLjwf"
			@"y1bdiqbaINLZaUxniEKrx9k0UvYkxs6N4fTAGFJH0kVzI+zsLQxuKrSDbGNE76UI"
			@"BLgoYQy4a1y47oFr0La0HR5XGRym/tzkOBLTcRJII52bhkUi6ZwFK5eG7diwczZS"
			@"x6cQfzUFlVYIBAJobW3FmjVrkEgkcPToUfT29kq//1IExPOQu9aFG9a14wd1dfBV"
			@"+LHh5k0IVATw9NAfMPDx67hAjy0atp0MHJWFYziAyZ2mAniyfTaDiRdTcKY5Lsie"
			@"PXsQiUTQ39+PFStWaPXiWrHtZCckg6aV9XBVmxhNjmIqO4XGuU3wef2omVODpJ1E"
			@"PD2BlHUBGdtCLpdlbIQAjbm4uQzwXFWGObeVy1ElkWiIFFt3aeWrzmbp+joqUdHk"
			@"xenzp3RY0840njv8LOr99Xjz5N+RykyiuqwaXTeuR/PCFpy3knhq6EkcS34AQ04l"
			@"CYPRqP5pOaxjGVgf5bB27VqEQiE5Hjt27JAmOjsFUnjDsrLwsXkw6b2SsFLLNAym"
			@"wQePuxyJdByWZaGrfT3WhTeIupZDsYP4Wd/tMOcYMMpkk+J+IP2BjTuSP0dPT4/W"
			@"i0ajCIfD0g/PjkBEZr0tZTB87JgOaFcTUOwnswkgyxvI4cE5hfamDlEvSXuwQ68J"
			@"YaVPpl5W4fkHX8ZdS36h9UZGRnTuOdhCRGcSkOTcI1rli0lAVgzmU4qqQELWisbX"
			@"3cDQ17XIVEneOnkg77VLNjho9rfgT6Hn0VzzI60jxsVzVv8OTnTL5EwCEp+gTLpq"
			@"eYCbxuUcAUkoxTE9b1vUga3hbWhekDf+/pl/yhacToziqQPbWHkycvCrqx9E1zUb"
			@"4S8Xv4ChdwaxfFlEjO/k8Jd6ko8igaf5nkaEoYjOn6xIBCjidUNVI7aEtmHZD2/X"
			@"c8npJFb3/Rr7P9xHfarysjKqgIYrGvDHm59DR8NNME0JH7D9wBPYsq0bqQTzl7+A"
			@"pNUiZkLBYHCtVGeRgPZeCoiGfW4/un6yAfctfaCwBeh7dyc27V+PSZXU0RIC1SzQ"
			@"zub70HXtRng8HtaOoaOyev/9OBwfglFZ2i5esbLzIgQ2U4qvhZ51LAeLqhah67qN"
			@"uKt5VUEVkBxvf+MJHDpzAL5qHx6//ve4smYx3vviCFYuuRuN/iBcLpc2/tK7f8b2"
			@"fzyOC94k3PWSx5KI8XxoC1MqHo+r4eFhxRtKdXd3q6P/GmHKv5JTEzH10Gv3q9ot"
			@"lWr+9iq14JlK9ddjf1GpVErZtq1yuZxyHEfj4OigWr77FjX/hXJV1+dV9X/zqobD"
			@"FcqzRG4obThSosKOUBNLM+dK/YGP96FvZCcG/vO6zq9ZxTx78zUxuioOt9utvZVw"
			@"J9MJ/C76KHbFXoE51+AdwtolDK8BZ0Lh7LLSx2kuDSSKRiQFMd7JQflQiMRiMQwO"
			@"DuK9K97Cp3VndYG56nggC0yMS9mqKeCcNYZGT1C2aBk4uQ+7x1+Bi+E2eYfoopTi"
			@"5I2YfClTVOtnp2RcJiUCrYR884OEiCgE5FWsfbKCh+W9NnilS7GxNElA4WqjBT0d"
			@"u9BQ3YRDY0PojK5Eyn8epj9vXN8fzHb2jIPxOy19MB9hIlocSCsEZoqMJUQniEDV"
			@"rW7M20DLEifeC3K3yw4nw8/OeSJJMoysENNEJeTyOlJH5ajLt+iz3/Dz/KEu+ihn"
			@"wsR/CQP0PyLJepvozJxwkGP+Km9hZXtYJ3LJCBnuMtw0xLEhdVEpUSLkBhTDNnVp"
			@"87PfloxLVNuIUiGwr+ViBGQhRowSkcxxB9awA2+bqT8yUseF+4lE8kYNk4bpLWzu"
			@"4F2THXPw+cM2Mv/mXD6l4nlMBrPlUgREb4TQJLJjCqm9dI1euRtZZPzaaWP0VDG9"
			@"EnIp0twXCpN9WUxs5Z+TpDYlnotxOeuiwq3fKK3U6CGk1eJpNjWR8hYWBX/pg/xz"
			@"ekohS8yQfvbvJRIz5r5Vt5O75W0RK5dCnGtCNkRcllxOBGYfFOCEREMgfZFYAVG2"
			@"38t3KwJfAsGsuKFv/AGwAAAAAElFTkSuQmCC",
				WCIcon,
			
			[NSNumber numberWithBool:NO],
				WCShowConnectAtStartup,
			[NSNumber numberWithBool:YES],
				WCShowServersAtStartup,
			
			[NSNumber numberWithBool:YES],
				WCConfirmDisconnect,
			[NSNumber numberWithBool:NO],
				WCAutoReconnect,
			
			[NSNumber numberWithBool:YES],
				WCCheckForUpdate,
			
			basicThemeIdentifier,
				WCTheme,
			[NSArray arrayWithObjects:
				[NSDictionary dictionaryWithObjectsAndKeys:
					NSLS(@"Basic", @"Theme"),										WCThemesName,
					@"Basic",														WCThemesBuiltinName,
					basicThemeIdentifier,											WCThemesIdentifier,
					WIStringFromFont([NSFont userFixedPitchFontOfSize:9.0]),		WCThemesChatFont,
					WIStringFromColor([NSColor blackColor]),						WCThemesChatTextColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesChatBackgroundColor,
					WIStringFromColor([NSColor redColor]),							WCThemesChatEventsColor,
					WIStringFromColor([NSColor redColor]),							WCThemesChatTimestampEveryLineColor,
					WIStringFromColor([NSColor blueColor]),							WCThemesChatURLsColor,
					WIStringFromFont([NSFont fontWithName:@"Helvetica" size:13.0]),	WCThemesMessagesFont,
					WIStringFromColor([NSColor blackColor]),						WCThemesMessagesTextColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesMessagesBackgroundColor,
					WIStringFromFont([NSFont fontWithName:@"Helvetica" size:13.0]),	WCThemesBoardsFont,
					WIStringFromColor([NSColor blackColor]),						WCThemesBoardsTextColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesBoardsBackgroundColor,
					[NSNumber numberWithBool:NO],									WCThemesShowSmileys,
					[NSNumber numberWithBool:NO],									WCThemesChatTimestampEveryLine,
					[NSNumber numberWithInteger:WCThemesUserListIconSizeLarge],		WCThemesUserListIconSize,
					[NSNumber numberWithBool:YES],									WCThemesUserListAlternateRows,
					[NSNumber numberWithBool:YES],									WCThemesFileListAlternateRows,
					[NSNumber numberWithInteger:WCThemesFileListIconSizeLarge],		WCThemesFileListIconSize,
					[NSNumber numberWithBool:YES],									WCThemesTransferListShowProgressBar,
					[NSNumber numberWithBool:YES],									WCThemesTransferListAlternateRows,
					[NSNumber numberWithBool:YES],									WCThemesTrackerListAlternateRows,
					[NSNumber numberWithInteger:WCThemesMonitorIconSizeLarge],		WCThemesMonitorIconSize,
					[NSNumber numberWithBool:YES],									WCThemesMonitorAlternateRows,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					NSLS(@"Hacker", @"Theme"),										WCThemesName,
					@"Hacker",														WCThemesBuiltinName,
					[NSString UUIDString],											WCThemesIdentifier,
					WIStringFromFont([NSFont fontWithName:@"Monaco" size:9.0]),		WCThemesChatFont,
					WIStringFromColor([NSColor greenColor]),						WCThemesChatTextColor,
					WIStringFromColor([NSColor blackColor]),						WCThemesChatBackgroundColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesChatEventsColor,
					WIStringFromColor([NSColor redColor]),							WCThemesChatTimestampEveryLineColor,
					WIStringFromColor([NSColor redColor]),							WCThemesChatURLsColor,
					WIStringFromFont([NSFont fontWithName:@"Helvetica" size:13.0]),	WCThemesMessagesFont,
					WIStringFromColor([NSColor blackColor]),						WCThemesMessagesTextColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesMessagesBackgroundColor,
					WIStringFromFont([NSFont fontWithName:@"Helvetica" size:13.0]),	WCThemesBoardsFont,
					WIStringFromColor([NSColor blackColor]),						WCThemesBoardsTextColor,
					WIStringFromColor([NSColor whiteColor]),						WCThemesBoardsBackgroundColor,
					[NSNumber numberWithBool:NO],									WCThemesShowSmileys,
					[NSNumber numberWithBool:NO],									WCThemesChatTimestampEveryLine,
					[NSNumber numberWithInteger:WCThemesUserListIconSizeLarge],		WCThemesUserListIconSize,
					[NSNumber numberWithBool:YES],									WCThemesUserListAlternateRows,
					[NSNumber numberWithInteger:WCThemesFileListIconSizeLarge],		WCThemesFileListIconSize,
					[NSNumber numberWithBool:YES],									WCThemesFileListAlternateRows,
					[NSNumber numberWithBool:YES],									WCThemesTransferListShowProgressBar,
					[NSNumber numberWithBool:YES],									WCThemesTransferListAlternateRows,
					[NSNumber numberWithBool:YES],									WCThemesTrackerListAlternateRows,
					[NSNumber numberWithInteger:WCThemesMonitorIconSizeLarge],		WCThemesMonitorIconSize,
					[NSNumber numberWithBool:YES],									WCThemesMonitorAlternateRows,
				 NULL],
			 NULL],
				WCThemes,

			[NSArray array],
				WCBookmarks,
			
			[NSNumber numberWithBool:NO],
				WCChatHistoryScrollback,
			[NSNumber numberWithInt:WCChatHistoryScrollbackModifierNone],
				WCChatHistoryScrollbackModifier,
			[NSNumber numberWithBool:YES],
				WCChatTabCompleteNicks,
			@": ",
				WCChatTabCompleteNicksString,
			[NSNumber numberWithBool:NO],
				WCChatTimestampChat,
			[NSNumber numberWithInt:600],
				WCChatTimestampChatInterval,

			[NSArray array],
				WCHighlights,

			[NSArray array],
				WCIgnores,

			[NSArray arrayWithObjects:
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsServerConnected],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsServerDisconnected],		WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsError],						WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsUserJoined],				WCEventsEvent,
					[NSNumber numberWithBool:YES],								WCEventsPostInChat,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsUserChangedNick],			WCEventsEvent,
					[NSNumber numberWithBool:YES],								WCEventsPostInChat,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsUserLeft],					WCEventsEvent,
					[NSNumber numberWithBool:YES],								WCEventsPostInChat,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsChatReceived],				WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsMessageReceived],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsBoardPostReceived],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsBroadcastReceived],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsTransferStarted],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsTransferFinished],			WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsUserChangedStatus],			WCEventsEvent,
					[NSNumber numberWithBool:NO],								WCEventsPostInChat,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsHighlightedChatReceived],	WCEventsEvent,
					NULL],
				[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithInt:WCEventsChatInvitationReceived],	WCEventsEvent,
					NULL],
				NULL],
				WCEvents,
			[NSNumber numberWithFloat:1.0],
				WCEventsVolume,

			[@"~/Downloads" stringByExpandingTildeInPath],
				WCDownloadFolder,
			[NSNumber numberWithBool:NO],
				WCOpenFoldersInNewWindows,
			[NSNumber numberWithBool:YES],
				WCQueueTransfers,
			[NSNumber numberWithBool:YES],
				WCCheckForResourceForks,
			[NSNumber numberWithBool:NO],
				WCRemoveTransfers,
			[NSNumber numberWithInt:WCFilesStyleList],
				WCFilesStyle,
			
			[NSArray arrayWithObject:
				[NSDictionary dictionaryWithObjectsAndKeys:
					@"Zanka Tracker",				WCTrackerBookmarksName,
					@"wired.zankasoftware.com",		WCTrackerBookmarksAddress,
					@"",							WCTrackerBookmarksLogin,
					[NSString UUIDString],			WCTrackerBookmarksIdentifier,
					NULL]],
				WCTrackerBookmarks,
				
			[NSDictionary dictionary],
				WCWindowProperties,
			
			[NSArray array],
				WCReadBoardPosts,
			[NSNumber numberWithBool:NO],
				WCBoardPostContinuousSpellChecking,
			
			[NSNumber numberWithBool:NO],
				WCDebug,
			NULL];
	}
	
	return defaults;
}



#pragma mark -

- (NSDictionary *)themeWithIdentifier:(NSString *)identifier {
	NSEnumerator	*enumerator;
	NSDictionary	*theme;
	
	enumerator = [[self objectForKey:WCThemes] objectEnumerator];
	
	while((theme = [enumerator nextObject])) {
		if([[theme objectForKey:WCThemesIdentifier] isEqualToString:identifier])
			return theme;
	}
	
	return NULL;
}



#pragma mark -

- (NSDictionary *)eventWithTag:(NSUInteger)tag {
	NSEnumerator	*enumerator;
	NSDictionary	*event;
	
	enumerator = [[self objectForKey:WCEvents] objectEnumerator];
	
	while((event = [enumerator nextObject])) {
		if([event unsignedIntegerForKey:WCEventsEvent] == tag)
			return event;
	}
	
	return NULL;
}

@end
