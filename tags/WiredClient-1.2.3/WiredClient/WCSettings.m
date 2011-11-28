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

#import "WCSettings.h"

@implementation WCSettings

NSUserDefaults			*defaults;
NSMutableDictionary		*settings;


- (id)init {
	NSDictionary	*defaultValues;
	NSString		*key;
	NSEnumerator	*enumerator;
	NSString		*downloadFolder = @"";
	id				object;
	BOOL			isDirectory;
	
	self = [super init];
	
	// --- try to be really clever and guess the download folder
	enumerator = [[NSArray arrayWithObjects:
		@"~/Downloads",
		@"~/Download",
		@"~/Incoming",
		@"~/Desktop/Downloads",
		@"~/Desktop/Download",
		@"~/Desktop/Incoming",
		@"~/Desktop",
		@"~",
		NULL] objectEnumerator];

	while((key = [enumerator nextObject])) {
		if([[NSFileManager defaultManager] fileExistsAtPath:[key stringByStandardizingPath]
												isDirectory:&isDirectory] && isDirectory) {
			downloadFolder = key;
			
			break;
		}
	}
	
	// --- create objects
	defaults		= [NSUserDefaults standardUserDefaults];
	settings		= [[NSMutableDictionary alloc] init];
	
	// --- create default values
	defaultValues	= [NSDictionary dictionaryWithObjectsAndKeys:
		// --- general
		[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Monaco" size:9.0]],
			WCTextFont,
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCEventTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor blueColor]],
			WCURLTextColor,
		[NSNumber numberWithBool:YES],
			WCShowConnectAtStartup,
		[NSNumber numberWithBool:NO],
			WCShowTrackersAtStartup,
		[NSNumber numberWithBool:YES],
			WCConfirmDisconnect,
		
		// --- personal
		NSUserName(),
			WCNick,
		@"",
			WCStatus,
		@"",
			WCCustomIcon,
		[NSNumber numberWithInt:128],
			WCIcon,
		
		// --- bookmarks
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Zanka Server",				WCBookmarksName,
				@"wired.zankasoftware.com",		WCBookmarksAddress,
				@"",							WCBookmarksLogin,
				@"",							WCBookmarksPassword,
				NULL],
			NULL],
			WCBookmarks,
			
		// --- chat
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCChatTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCChatBackgroundColor,
		[NSNumber numberWithInt:WCChatStyleWired],
			WCChatStyle,
		[NSNumber numberWithInt:WCIconSizeLarge],
			WCIconSize,
		[NSNumber numberWithBool:NO],
			WCHistoryScrollback,
		[NSNumber numberWithInt:WCHistoryScrollbackModifierNone],
			WCHistoryScrollbackModifier,
		[NSNumber numberWithBool:YES],
			WCTabCompleteNicks,
		@": ",
			WCTabCompleteNicksString,
		[NSNumber numberWithBool:NO],
			WCHighlightWords,
		[NSArray arrayWithObjects:NULL],
			WCHighlightWordsWords,
		[NSArchiver archivedDataWithRootObject:[NSColor redColor]],
			WCHighlightWordsTextColor,
		[NSNumber numberWithBool:NO],
			WCTimestampChat,
		[NSNumber numberWithInt:300],
			WCTimestampChatInterval,
		[NSNumber numberWithBool:NO],
			WCTimestampEveryLine,
		[NSArchiver archivedDataWithRootObject:[NSColor redColor]],
			WCTimestampEveryLineTextColor,
		[NSNumber numberWithBool:YES],
			WCShowJoinLeave,
		[NSNumber numberWithBool:YES],
			WCShowNickChanges,
		
		// --- news
		[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]],
			WCNewsFont,
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCNewsTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCNewsBackgroundColor,
		[NSNumber numberWithBool:YES],
			WCLoadNewsOnLogin,

		// --- messages
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCMessageTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCMessageBackgroundColor,
		[NSNumber numberWithBool:YES],
			WCShowMessagesInForeground,
		[NSNumber numberWithBool:NO],
			WCShowMessagesInChat,

		// --- files
		[downloadFolder stringByStandardizingPath],
			WCDownloadFolder,
		[NSNumber numberWithBool:NO],
			WCOpenFoldersInNewWindows,
		[NSNumber numberWithBool:YES],
			WCQueueTransfers,
		[NSNumber numberWithBool:YES],
			WCEncryptTransfers,
		[NSNumber numberWithBool:NO],
			WCRemoveTransfers,
			
		// --- trackers
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Zanka Tracker",				@"Name",
				@"wired.zankasoftware.com",		@"Address",
				NULL],
			NULL],
		WCTrackerBookmarks,
		
		// --- ignored users
		[NSArray arrayWithObjects:NULL],
			WCIgnores,
	
		// --- sounds
		@"",
			WCConnectedEventSound,
		@"",
			WCDisconnectedEventSound,
		@"",
			WCChatEventSound,
		@"",
			WCUserJoinEventSound,
		@"",
			WCUserLeaveEventSound,
		@"",
			WCMessagesEventSound,
		@"",
			WCNewsEventSound,
		@"",
			WCBroadcastEventSound,
		@"",
			WCTransferStartedEventSound,
		@"",
			WCTransferDoneEventSound,

		// --- open windows
		[NSNumber numberWithBool:NO],
			WCShowAccounts,
		[NSNumber numberWithBool:NO],
			WCShowConsole,
		[NSNumber numberWithBool:NO],
			WCShowMessages,
		[NSNumber numberWithBool:NO],
			WCShowNews,
		[NSNumber numberWithBool:NO],
			WCShowTransfers,

		// -- SSL
		@"ALL:!LOW:!EXP:!MD5",
			WCSSLControlCiphers,
		@"NULL:ALL:!LOW:!EXP:!MD5",
			WCSSLNullControlCiphers,
		@"RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLTransferCiphers,
		@"NULL:RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLNullTransferCiphers,
		
		// --- default columns
		[NSArray arrayWithObjects:@"Name", @"Size", NULL],
			@"WCTableViewOptions Files Columns",
		[NSArray arrayWithObjects:@"Name", @"Size", NULL],
			@"WCTableViewOptions Search Columns",
		[NSArray arrayWithObjects:@"Name", @"Type", NULL],
			@"WCTableViewOptions Accounts Columns",
		[NSArray arrayWithObjects:@"Name", @"Users", @"Speed", @"Files", @"Size", @"Description", NULL],
			@"WCTableViewOptions Trackers Columns",
		
		NULL];

	// --- loop over keys
	enumerator = [defaultValues keyEnumerator];
	
	while((key = [enumerator nextObject])) {
		object = [defaults objectForKey:key];

		if(object) {
			// --- get object from user defaults
			[settings setObject:object forKey:key];
		} else {
			// --- get object from default values
			[settings setObject:[defaultValues objectForKey:key] forKey:key];
			[defaults setObject:[defaultValues objectForKey:key] forKey:key];
		}
	}
	
	return self;
}



#pragma mark -

+ (id)objectForKey:(id)key {
	return [settings objectForKey:key];
}



+ (NSString *)stringForKey:(id)key {
	return [settings objectForKey:key];
}



+ (BOOL)boolForKey:(id)key {
	return [[settings objectForKey:key] boolValue];
}



+ (int)intForKey:(id)key {
	return [[settings objectForKey:key] intValue];
}



+ (id)archivedObjectForKey:(id)key {
	return [NSUnarchiver unarchiveObjectWithData:[settings objectForKey:key]];
}



+ (void)setObject:(id)object forKey:(id)key {
	[defaults setObject:object forKey:key];
	[settings setObject:object forKey:key];

	[[NSUserDefaults standardUserDefaults] synchronize];
}



+ (void)setArchivedObject:(id)object forKey:(id)key {
	[defaults setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];
	[settings setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
