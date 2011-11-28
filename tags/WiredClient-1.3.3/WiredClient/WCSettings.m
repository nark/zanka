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

#import "WCKeychain.h"
#import "WCPreferences.h"
#import "WCTrackers.h"

@interface WCSettings(Private)

+ (void)_convert;

@end


@implementation WCSettings(Private)

+ (void)_convert {
	NSEnumerator		*enumerator;
	NSArray				*bookmarks;
	NSMutableArray		*newBookmarks;
	NSDictionary		*bookmark;
	NSMutableDictionary	*newBookmark;
	NSString			*password;
	
	// --- add WCBookmarksIdentifier/Nick/Status to all bookmarks
	bookmarks = [self objectForKey:WCBookmarks];
	newBookmarks = [NSMutableArray array];
	enumerator = [bookmarks objectEnumerator];
	
	while((bookmark = [enumerator nextObject])) {
		newBookmark = [NSMutableDictionary dictionaryWithDictionary:bookmark];
		
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
}

@end


@implementation WCSettings

+ (void)loadWithIdentifier:(NSString *)identifier {
#ifndef RELEASE
	NSUserDefaults	*defaults;
	NSDictionary	*persistentDomain;
	
	defaults = [NSUserDefaults standardUserDefaults];
	persistentDomain = [defaults persistentDomainForName:@"com.zanka.WiredClientDebug"];
		
	if(!persistentDomain) {
		persistentDomain = [defaults persistentDomainForName:@"com.zanka.WiredClient"];
		
		if(persistentDomain)
			[defaults setPersistentDomain:persistentDomain forName:@"com.zanka.WiredClientDebug"];
	}
	
	[defaults synchronize];
#endif
	
	[super loadWithIdentifier:identifier];
	
	[self _convert];
}


	
+ (NSDictionary *)defaults {
	NSEnumerator	*enumerator;
	NSString		*key, *downloadFolder = @"~";

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
		if([[NSFileManager defaultManager] directoryExistsAtPath:[key stringByStandardizingPath]]) {
			downloadFolder = key;
			
			break;
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		// --- general
		NSUserName(),
			WCNick,
		@"",
			WCStatus,
		@"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABGdBTUEAANkE3LLa"
		@"AgAAB7NJREFUeJztl31sVfUZxz/nnvO7p/f2hbb0Ddvby6XtpaVWECmgIorLNLyU"
		@"LAhbxpoyNmYVcZlBpEt0FDUxrrBlGTh1E0hGQQeJCx3BGUp1KC8iL7YFKRNKedEu"
		@"fS+9vb333HOe/YEQCkznZuI/fpNfcv74Pc/n+/yeJ3ly4Ft9w9L+l5hNmzaVHT16"
		@"9LbW0615Do7m9/nPFRUXfbxgwYK6zMzMga/dJUBdXd09k+6YtNvAEANDFEpu9h0s"
		@"CB5++eWXf/C1gZubm91Tp0596wrITDTFe6spSd/xSvLsBBkxJ15SZiVK4lSveP2e"
		@"q2YCgUBTS0tL9pfl/8IWHDx4sHja3dOaJSboiTpqikbSHYlkjskkJSmVeD0Bzdaw"
		@"JEp3rIuu9k76TvUT3h8lctxCEN6se3N6WVnZ3hMnTow6fvz4OE3TtNLS0sN+v7/n"
		@"Cw0cO3YsUDqp9AwxUEGDhDlu8sYGyfX4cYlONBbBiTnYtoPjOGiahuWK0k0PHZFP"
		@"6XvnEoM7o8QsGyPOsNLS0lQgEKCjo4OTJ08yY8aM7Q0NDQv+owG3221LVFxmiSJ5"
		@"QTy3+0opH1/BhFG386dDr7L/9D7C4TCWY2E7Fg4ODoJuGOhuF6HEPi41heh/ZQjH"
		@"ckjNTKW4uJj6+nrOnj1LMBiksrKyWr8ZfNGiRb9pPNJ4l8pUjFjoIT+9kMK0Ip68"
		@"/ylGJozEnzCabcdf51997YSsfnpCHQzaA9guG8uJEnUi6DEDvUAQU4g2x+gP9dPa"
		@"2kpTUxOVlZV0d3ezY8eOVNfNDGyp3fKEhkbcVIPU1HQM26A71E1nZycArT2nGZIh"
		@"+sOdhKJ9TBg7hexsP4PhPqKuMJYWIaKFcXrAW6bj9qmruR+a9xAA6enpOI6jjOvh"
		@"K1euXLH2xbW4R7tJmOwh2ZVCV7iT3lgvy/c8gT85wIcXD/BZzzk0Bf9YdpiSnNsA"
		@"eOzvj7D1g9cwTS+ia2iGhksH43sW/B4efeRRFv5oIQAbNmygqKjoyA0z4PP5TrWf"
		@"by+InxNH+oMpxA3GMxgdIOIM4TJc6MogFLlEpGuQO++8l13f3z0sPuulREQsdMON"
		@"ZoDlGoIYVIQeZ80v1gKwbNky1q9fT1tbW+oNL9B+vr3ApVyYt+tIBAbsfqJaBMdl"
		@"Yzk2segQTtRB88Ds/LIb2ufyCDYOomxsLFxxsOauVym/5ccAVD1Vxfr161m1atXj"
		@"fr+/Z5iBkpKSvR83fYye7kJPBysSJaZbOEYMASzCEBHyS8bxxv1vEhg5Zhj85+8v"
		@"xVZRNBNELHKzCthb+iFxHg8A5eXl1NbWsmLFiqdWr169DuCqgUAgcLK3p3csgBgC"
		@"HsG2ozjiYOsWsaiFSnbz7NRf8/CtSwGI9IWZtv1OIvYQ0ViYTuczDB9oJizN/yXP"
		@"5K8GoIcuJj09kTO156ioqFhbU1NTc4VrACxZsuSF06dPjx0KD3H+wnkUOijBcceI"
		@"OmGwIFhYwv4HD8PnA72/5QCzt9yD0w9aPLgSQeVpqBRFXdH7TEifAEDj+WM88MFk"
		@"hgYEgLy8vDPXvppx8eJFb2FhYdXOnTuZPn06AOGBCAmWAyZkpeVSc+vvmJk3+3LE"
		@"EMyvn8vud3ahZ2iYRYADrhHwUMFi1gVfuZr8Z4cW8dfDW3EXasQVKgbRcLlcMqxv"
		@"M2fO/PO8efOkt7dXgKunrOFBebdrj1yrqv3LJfVFQ1JWGZK5XcnWs5ulsf8jef5C"
		@"tZwZ+OTqvTfObpHs7YmSvlFJ1ltK8iVeRlZdXlQ7duy4d5iBjIyMtrlz54qIyMED"
		@"B6X+rXq5XtWHnpGslxIl9XlDMjYrGfW2kl0df7vh3vmus3L33omSvklJVp2SnH0e"
		@"8R3zSIF4JfG+ODFQw6sHWL58+UqllPT29g5Ldq7tgix+r1wy/uiWkWuUZGxVkl3v"
		@"lZxDbslpdouEh8O3XdgqGZuVZP5FyS3vuiX3ozjJbYyT0Rc9EujwiokpEydMbLjB"
		@"AMC4ceP2ATJ+/HiZXDpZRpgjBJCUakOydirJafBK7hGv+I97xX/KI74WU15t/8Mw"
		@"A/cdmCKj3lbiOxonuSc8kttsSs4HpuSLR0YsvFz9tm3bHrierQN0dHS8Vltbe0gp"
		@"dTIYDO7s7u92t7e3B4wBk9Qa9flYAG5BU4AuNHy6i+6eECmXkln6z5/yUWgfxi0a"
		@"mgKxBAmDKgLnM43uJUJaRuq5jZs2Pn69gZuu49bW1uRgINgDkPycIvlpjWirAzZg"
		@"gKaB1W0TOyNIBDQFRo6GnqQhFkgY9FHgHq1zsdAm2uLw+vat350/f/7u61k33YaB"
		@"QKD32ReerQTof8am51cOKqChxQsScnBCDi5dw8hyYWSAkeFC0zScfnBCgnsiqNE6"
		@"n95hY7U4/OThxS/cDP6lqqqqelKhRKEkabZH/Kc8khfziL/NlJz9bsl+15TsBrdk"
		@"N7jFd8wtgb7LPR+13SNmkikKJRXlFb/9yuBrVVtbO+uKCRMlSXNNydxgiv8Tj4wZ"
		@"jJPAJVPGDHjEd8gjac+Z4h17GaxQUl1d/dj/Bb9WixcvrrmS+MvOnFlzNrW1taX8"
		@"N3m/8o/JunXrfrhn9577G5saJ3V2dPps21Zp6WnniscVH5k2fdp7U6ZM2ThjxozY"
		@"Vy/xW31D+jfvNtPdS+ASBQAAAABJRU5ErkJggg==",
			WCCustomIcon,
		
		[NSNumber numberWithBool:YES],
			WCShowConnectAtStartup,
		[NSNumber numberWithBool:NO],
			WCShowDockAtStartup,
		[NSNumber numberWithBool:NO],
			WCShowTrackersAtStartup,
		
		[NSNumber numberWithBool:NO],
			WCAutoHideOnSwitch,
		[NSNumber numberWithBool:YES],
			WCPreventMultipleConnections,
		[NSNumber numberWithBool:YES],
			WCConfirmDisconnect,
		[NSNumber numberWithBool:NO],
			WCAutoReconnect,
			
		[NSNumber numberWithBool:YES],
			WCCheckForUpdate,
		
		// --- interface/chat
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCChatTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCChatBackgroundColor,
		[NSArchiver archivedDataWithRootObject:[NSColor redColor]],
			WCChatEventsColor,
		[NSArchiver archivedDataWithRootObject:[NSColor blueColor]],
			WCChatURLsColor,
		[NSArchiver archivedDataWithRootObject:[NSFont userFixedPitchFontOfSize:9.0]],
			WCChatFont,
		[NSArchiver archivedDataWithRootObject:[NSFont systemFontOfSize:12.0]],
			WCChatUserListFont,
		[NSNumber numberWithInt:WCChatUserListIconSizeLarge],
			WCChatUserListIconSize,
		[NSNumber numberWithBool:NO],
			WCChatUserListAlternateRows,
		
		// --- interface/messages
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCMessagesTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCMessagesBackgroundColor,
		[NSArchiver archivedDataWithRootObject:[NSFont userFixedPitchFontOfSize:9.0]],
			WCMessagesFont,
		[NSArchiver archivedDataWithRootObject:[NSFont systemFontOfSize:12.0]],
			WCMessagesListFont,
		[NSNumber numberWithBool:NO],
			WCMessagesListAlternateRows,
		
		// --- interface/news
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCNewsTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCNewsBackgroundColor,
		[NSArchiver archivedDataWithRootObject:[NSColor grayColor]],
			WCNewsTitlesColor,
		[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]],
			WCNewsFont,
		[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica-Bold" size:12.0]],
			WCNewsTitlesFont,
		
		// --- interface/files
		[NSArchiver archivedDataWithRootObject:[NSFont systemFontOfSize:12.0]],
			WCFilesFont,
		[NSNumber numberWithBool:NO],
			WCFilesAlternateRows,
		
		// --- interface/transfers
		[NSNumber numberWithBool:YES],
			WCTransfersShowProgressBar,
		[NSNumber numberWithBool:NO],
			WCTransfersAlternateRows,

		// --- interface/preview
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
			WCPreviewTextColor,
		[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]],
			WCPreviewBackgroundColor,
		[NSArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Helvetica" size:12.0]],
			WCPreviewFont,
		
		// --- interface/trackers
		[NSNumber numberWithBool:NO],
			WCTrackersAlternateRows,

		// --- bookmarks
		[NSArray array],
			WCBookmarks,
		
		// --- chat/settings
		[NSNumber numberWithInt:WCChatStyleWired],
			WCChatStyle,
		[NSNumber numberWithBool:NO],
			WCHistoryScrollback,
		[NSNumber numberWithInt:WCHistoryScrollbackModifierNone],
			WCHistoryScrollbackModifier,
		[NSNumber numberWithBool:YES],
			WCTabCompleteNicks,
		@": ",
			WCTabCompleteNicksString,
		[NSNumber numberWithBool:NO],
			WCTimestampChat,
		[NSNumber numberWithInt:300],
			WCTimestampChatInterval,
		[NSNumber numberWithBool:NO],
			WCTimestampEveryLine,
		[NSArchiver archivedDataWithRootObject:[NSColor redColor]],
			WCTimestampEveryLineColor,
		[NSNumber numberWithBool:NO],
			WCShowSmileys,

		// --- chat/highlights
		[NSArray array],
			WCHighlights,

		// --- chat/ignores
		[NSArray array],
			WCIgnores,

		// --- events
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
				[NSNumber numberWithInt:WCEventsNewsPosted],				WCEventsEvent,
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

		// --- files
		[downloadFolder stringByStandardizingPath],
			WCDownloadFolder,
		[NSNumber numberWithBool:NO],
			WCOpenFoldersInNewWindows,
		[NSNumber numberWithBool:YES],
			WCQueueTransfers,
		[NSNumber numberWithBool:YES],
			WCEncryptTransfers,
		[NSNumber numberWithBool:YES],
			WCCheckForResourceForks,
		[NSNumber numberWithBool:NO],
			WCRemoveTransfers,
		[NSNumber numberWithInt:WCFilesStyleList],
			WCFilesStyle,
		
		// --- trackers
		[NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Zanka Tracker",				@"Name",
				@"wired.zankasoftware.com",		@"Address",
				NULL]],
			WCTrackerBookmarks,
		
		// --- window templates
		[NSDictionary dictionary],
			WCWindowTemplates,
		
		// -- SSL
		@"ALL:!LOW:!EXP:!MD5",
			WCSSLControlCiphers,
		@"NULL:ALL:!LOW:!EXP:!MD5",
			WCSSLNullControlCiphers,
		@"RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLTransferCiphers,
		@"NULL:RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLNullTransferCiphers,
		
		// --- debug
		[NSNumber numberWithBool:NO],
			WCDebug,
		
		NULL];
}



#pragma mark -

+ (NSDictionary *)eventForTag:(NSUInteger)tag {
	NSEnumerator	*enumerator;
	NSDictionary	*event;
	
	enumerator = [[self objectForKey:WCEvents] objectEnumerator];
	
	while((event = [enumerator nextObject])) {
		if([event unsignedIntegerForKey:WCEventsEvent] == tag)
			return event;
	}
	
	return NULL;
}



+ (void)setEvent:(NSDictionary *)event forTag:(NSUInteger)tag {
	NSMutableArray		*events;
	NSDictionary		*previousEvent;
	NSUInteger			i;
	
	events = [[self objectForKey:WCEvents] mutableCopy];
	previousEvent = [self eventForTag:tag];
	
	if(!previousEvent) {
		[events addObject:event];
	} else {
		i = [events indexOfObject:previousEvent];
		[events replaceObjectAtIndex:i withObject:event];
	}
	
	[self setObject:events forKey:WCEvents];
	[events release];
}



#pragma mark -

+ (NSDictionary *)bookmarkAtIndex:(NSUInteger)index {
	return [[self objectForKey:WCBookmarks] objectAtIndex:index];
}



+ (void)addBookmark:(NSDictionary *)bookmark {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCBookmarks] mutableCopy];
	[bookmarks addObject:bookmark];
	[self setObject:bookmarks forKey:WCBookmarks];
	[bookmarks release];
}



+ (void)setBookmark:(NSDictionary *)bookmark atIndex:(NSUInteger)index {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCBookmarks] mutableCopy];
	[bookmarks replaceObjectAtIndex:index withObject:bookmark];
	[self setObject:bookmarks forKey:WCBookmarks];
	[bookmarks release];
}



+ (void)removeBookmarkAtIndex:(NSUInteger)index {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCBookmarks] mutableCopy];
	[bookmarks removeObjectAtIndex:index];
	[self setObject:bookmarks forKey:WCBookmarks];
	[bookmarks release];
}



#pragma mark -

+ (NSDictionary *)trackerBookmarkAtIndex:(NSUInteger)index {
	return [[self objectForKey:WCTrackerBookmarks] objectAtIndex:index];
}



+ (void)addTrackerBookmark:(NSDictionary *)bookmark {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCTrackerBookmarks] mutableCopy];
	[bookmarks addObject:bookmark];
	[self setObject:bookmarks forKey:WCTrackerBookmarks];
	[bookmarks release];
}



+ (void)setTrackerBookmark:(NSDictionary *)bookmark atIndex:(NSUInteger)index {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCTrackerBookmarks] mutableCopy];
	[bookmarks replaceObjectAtIndex:index withObject:bookmark];
	[self setObject:bookmarks forKey:WCTrackerBookmarks];
	[bookmarks release];
}



+ (void)removeTrackerBookmarkAtIndex:(NSUInteger)index {
	NSMutableArray		*bookmarks;
	
	bookmarks = [[self objectForKey:WCTrackerBookmarks] mutableCopy];
	[bookmarks removeObjectAtIndex:index];
	[self setObject:bookmarks forKey:WCTrackerBookmarks];
	[bookmarks release];
}



#pragma mark -

+ (NSDictionary *)highlightAtIndex:(NSUInteger)index {
	return [[self objectForKey:WCHighlights] objectAtIndex:index];
}



+ (void)addHighlight:(NSDictionary *)highlight {
	NSMutableArray		*highlights;
	
	highlights = [[self objectForKey:WCHighlights] mutableCopy];
	[highlights addObject:highlight];
	[self setObject:highlights forKey:WCHighlights];
	[highlights release];
}



+ (void)setHighlight:(NSDictionary *)highlight atIndex:(NSUInteger)index {
	NSMutableArray		*highlights;
	
	highlights = [[self objectForKey:WCHighlights] mutableCopy];
	[highlights replaceObjectAtIndex:index withObject:highlight];
	[self setObject:highlights forKey:WCHighlights];
	[highlights release];
}



+ (void)removeHighlightAtIndex:(NSUInteger)index {
	NSMutableArray		*highlights;
	
	highlights = [[self objectForKey:WCHighlights] mutableCopy];
	[highlights removeObjectAtIndex:index];
	[self setObject:highlights forKey:WCHighlights];
	[highlights release];
}



#pragma mark -

+ (NSDictionary *)ignoreAtIndex:(NSUInteger)index {
	return [[self objectForKey:WCIgnores] objectAtIndex:index];
}



+ (void)addIgnore:(NSDictionary *)ignore {
	NSMutableArray		*ignores;
	
	ignores = [[self objectForKey:WCIgnores] mutableCopy];
	[ignores addObject:ignore];
	[self setObject:ignores forKey:WCIgnores];
	[ignores release];
}



+ (void)setIgnore:(NSDictionary *)ignore atIndex:(NSUInteger)index {
	NSMutableArray		*ignores;
	
	ignores = [[self objectForKey:WCIgnores] mutableCopy];
	[ignores replaceObjectAtIndex:index withObject:ignore];
	[self setObject:ignores forKey:WCIgnores];
	[ignores release];
}



+ (void)removeIgnoreAtIndex:(NSUInteger)index {
	NSMutableArray		*ignores;
	
	ignores = [[self objectForKey:WCIgnores] mutableCopy];
	[ignores removeObjectAtIndex:index];
	[self setObject:ignores forKey:WCIgnores];
	[ignores release];
}



#pragma mark -

+ (NSDictionary *)windowTemplateForKey:(NSString *)key {
	return [[self objectForKey:WCWindowTemplates] objectForKey:key];
}



+ (void)setWindowTemplate:(NSDictionary *)windowTemplate forKey:(NSString *)key {
	NSMutableDictionary		*windowTemplates;
	
	windowTemplates = [[self objectForKey:WCWindowTemplates] mutableCopy];
	[windowTemplates setObject:windowTemplate forKey:key];
	[self setObject:windowTemplates forKey:WCWindowTemplates];
	[windowTemplates release];
}

@end
