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

#import "WCAboutWindow.h"
#import "WCApplicationController.h"
#import "WCChat.h"
#import "WCConsole.h"
#import "WCDock.h"
#import "WCKeychain.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"
#import "WCStats.h"
#import "WCTrackers.h"
#import "WCUser.h"

#define WCGrowlServerConnected			@"Connected to server"
#define WCGrowlServerDisconnected		@"Disconnected from server"
#define WCGrowlError					@"Error"
#define WCGrowlUserJoined				@"User joined"
#define WCGrowlUserChangedNick			@"User changed nick"
#define WCGrowlUserChangedStatus		@"User changed status"
#define WCGrowlUserJoined				@"User joined"
#define WCGrowlUserLeft					@"User left"
#define WCGrowlChatReceived				@"Chat received"
#define WCGrowlHighlightedChatReceived	@"Highlighted chat received"
#define WCGrowlMessageReceived			@"Message received"
#define WCGrowlNewsPosted				@"News posted"
#define WCGrowlBroadcastReceived		@"Broadcast received"
#define WCGrowlTransferStarted			@"Transfer started"
#define WCGrowlTransferFinished			@"Transfer finished"


static NSInteger _WCCompareSmileyLength(id, id, void *);

static NSInteger _WCCompareSmileyLength(id object1, id object2, void *context) {
	NSUInteger	length1 = [(NSString *) object1 length];
	NSUInteger	length2 = [(NSString *) object2 length];
	
	if(length1 > length2)
		return -1;
	else if(length1 < length2)
		return 1;
	
	return 0;
}


@interface WCApplicationController(Private)

- (void)_loadSmileys;

- (void)_update;
- (void)_updateApplicationIcon;
- (void)_updateBookmarksMenu;

- (void)_connectWithBookmark:(NSDictionary *)bookmark;
- (BOOL)_openConnectionWithURL:(WIURL *)url;

@end


@implementation WCApplicationController(Private)

- (void)_loadSmileys {
	NSBundle			*bundle;
	NSMenuItem			*item;
	NSMutableArray		*array;
	NSDictionary		*dictionary, *list, *map, *names;
	NSEnumerator		*enumerator;
	NSString			*path, *file, *name, *smiley, *title;
	
	bundle			= [self bundle];
	path			= [bundle pathForResource:@"Smileys" ofType:@"plist"];
	dictionary		= [NSDictionary dictionaryWithContentsOfFile:path];
	list			= [dictionary objectForKey:@"List"];
	map				= [dictionary objectForKey:@"Map"];
	enumerator		= [map keyEnumerator];
	_smileys		= [[NSMutableDictionary alloc] initWithCapacity:[map count]];

	while((smiley = [enumerator nextObject])) {
		file = [map objectForKey:smiley];
		path = [bundle pathForResource:file ofType:NULL];
		
		if(path)
			[_smileys setObject:path forKey:[smiley lowercaseString]];
		else
			NSLog(@"*** -[%@ %@]: could not find image \"%@\"", [self class], NSStringFromSelector(_cmd), file);
	}
	
	array = [NSMutableArray arrayWithObjects:
		@"Smile.tiff",
		@"Wink.tiff",
		@"Frown.tiff",
		@"Slant.tiff",
		@"Gasp.tiff",
		@"Laugh.tiff",
		@"Kiss.tiff",
		@"Yuck.tiff",
		@"Embarrassed.tiff",
		@"Footinmouth.tiff",
		@"Cool.tiff",
		@"Angry.tiff",
		@"Innocent.tiff",
		@"Cry.tiff",
		@"Sealed.tiff",
		@"Moneymouth.tiff",
		NULL];
	
	names = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Smile", @"Smiley"),					@"Smile.tiff",
		NSLS(@"Wink", @"Smiley"),					@"Wink.tiff",
		NSLS(@"Frown", @"Smiley"),					@"Frown.tiff",
		NSLS(@"Undecided", @"Smiley"),				@"Slant.tiff",
		NSLS(@"Gasp", @"Smiley"),					@"Gasp.tiff",
		NSLS(@"Laugh", @"Smiley"),					@"Laugh.tiff",
		NSLS(@"Kiss", @"Smiley"),					@"Kiss.tiff",
		NSLS(@"Sticking out tongue", @"Smiley"),	@"Yuck.tiff",
		NSLS(@"Embarrassed", @"Smiley"),			@"Embarrassed.tiff",
		NSLS(@"Foot in mouth", @"Smiley"),			@"Footinmouth.tiff",
		NSLS(@"Cool", @"Smiley"),					@"Cool.tiff",
		NSLS(@"Angry", @"Smiley"),					@"Angry.tiff",
		NSLS(@"Innocent", @"Smiley"),				@"Innocent.tiff",
		NSLS(@"Cry", @"Smiley"),					@"Cry.tiff",
		NSLS(@"Lips are sealed", @"Smiley"),		@"Sealed.tiff",
		NSLS(@"Money-mouth", @"Smiley"),			@"Moneymouth.tiff",
		NULL];

	[array addObjectsFromArray:[[[[NSSet setWithArray:[list allKeys]] setByMinusingSet:[NSSet setWithArray:array]] allObjects] sortedArrayUsingSelector:@selector(compare:)]];
	
	enumerator = [array objectEnumerator];
	
	while((name = [enumerator nextObject])) {
		smiley	= [list objectForKey:name];
		path	= [_smileys objectForKey:[smiley lowercaseString]];
		title	= [names objectForKey:name];
		
		if(!title)
			title = [name stringByDeletingPathExtension];
		
		item = [NSMenuItem itemWithTitle:title];
		[item setRepresentedObject:path];
		[item setImage:[[[NSImage alloc] initWithContentsOfFile:path] autorelease]];
		[item setAction:@selector(insertSmiley:)];
		[item setToolTip:smiley];
		[_insertSmileyMenu addItem:item];
	}
	
	_sortedSmileys = [[[_smileys allKeys] sortedArrayUsingFunction:_WCCompareSmileyLength context:NULL] retain];
}



#pragma mark -

- (void)_update {
	if([WCSettings boolForKey:WCConfirmDisconnect]) {
		[_disconnectMenuItem setTitle:[NSSWF:
			@"%@%C", NSLS(@"Disconnect", @"Disconnect menu item"), 0x2026]];
	} else {
		[_disconnectMenuItem setTitle:NSLS(@"Disconnect", @"Disconnect menu item")];
	}
}



- (void)_updateApplicationIcon {
	[NSApp setApplicationIconImage:
		[[NSImage imageNamed:@"NSApplicationIcon"] badgedImageWithInt:_unread]];
}



- (void)_updateBookmarksMenu {
	NSEnumerator	*enumerator;
	NSArray			*bookmarks;
	NSDictionary	*bookmark;
	NSString		*equivalent;
	NSMenuItem		*item;
	NSUInteger		i = 1;

	while((item = (NSMenuItem *) [_bookmarksMenu itemWithTag:0]))
		[_bookmarksMenu removeItem:item];

	bookmarks = [WCSettings objectForKey:WCBookmarks];

	if([bookmarks count] > 0)
		[_bookmarksMenu addItem:[NSMenuItem separatorItem]];

	enumerator = [bookmarks objectEnumerator];

	while((bookmark = [enumerator nextObject])) {
		equivalent = i < 10 ? [NSSWF:@"%lu", i] : @"";

		item = [[NSMenuItem alloc] initWithTitle:[bookmark objectForKey:WCBookmarksName]
										  action:@selector(bookmark:)
								   keyEquivalent:equivalent];
		[item setRepresentedObject:bookmark];

		[_bookmarksMenu addItem:item];
		[item release];

		i++;
	}
}



#pragma mark -

- (void)_connectWithBookmark:(NSDictionary *)bookmark {
	NSString			*address, *login, *password;
	WCServerConnection	*connection;
	WIURL				*url;

	address		= [bookmark objectForKey:WCBookmarksAddress];
	login		= [bookmark objectForKey:WCBookmarksLogin];
	password	= [[WCKeychain keychain] passwordForBookmark:bookmark];

	url = [WIURL URLWithString:address scheme:@"wired"];
	[url setUser:login];
	[url setPassword:password ? password : @""];
	
	if(![self _openConnectionWithURL:url]) {
		connection = [WCServerConnection serverConnectionWithURL:url bookmark:bookmark];
	
		[connection showWindow:self];
		[connection connect];
	}
}



- (BOOL)_openConnectionWithURL:(WIURL *)url {
	WCServerConnection		*connection;
	
	if([WCSettings boolForKey:WCPreventMultipleConnections]) {
		connection = [[WCDock dock] connectionWithURL:url];
		
		if(connection) {
			[[WCDock dock] openConnection:connection];
			
			return YES;
		}
	}
	
	return NO;
}

@end


@implementation WCApplicationController

static WCApplicationController		*sharedController;


+ (WCApplicationController *)sharedController {
	return sharedController;
}



- (id)init {
	NSTimer				*timer;
	NSCalendarDate		*date;

	sharedController = self = [super init];
	
#ifndef RELEASE
	[[WIExceptionHandler sharedExceptionHandler] enable];
#endif

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChange];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		  selector:@selector(messagesDidAddMessage:)
			   name:WCMessagesDidAddMessage];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidReadMessage:)
			   name:WCMessagesDidReadMessage];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidAddPost:)
			   name:WCNewsDidAddPost];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidReadPost:)
			   name:WCNewsDidReadPost];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionTriggeredEvent:)
			   name:WCServerConnectionTriggeredEvent];
	
	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:self
		andSelector:@selector(handleAppleEvent:withReplyEvent:)
		forEventClass:kInternetEventClass
		andEventID:kAEGetURL];

	[[NSFileManager defaultManager]
		createDirectoryAtPath:[WCApplicationSupportPath stringByStandardizingPath]
		attributes:NULL];

	date = [[NSCalendarDate dateAtStartOfCurrentDay] dateByAddingDays:1];
	timer = [[NSTimer alloc] initWithFireDate:date
									 interval:86400.0
									   target:self
									 selector:@selector(dailyTimer:)
									 userInfo:NULL
									  repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	[timer release];
	
	signal(SIGPIPE, SIG_IGN);

	return self;
}



- (void)awakeFromNib {
	WCServerConnection	*connection;
	NSEnumerator		*enumerator;
	NSDictionary		*bookmark;
	
#ifdef RELEASE
	[[NSApp mainMenu] removeItemAtIndex:[[NSApp mainMenu] indexOfItemWithSubmenu:_debugMenu]];
#endif
	
	[WIDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	
	[GrowlApplicationBridge setGrowlDelegate:self];
		
	(void) [WCDock dock];
	(void) [WCStats stats];
	
	[_deleteMenuItem setKeyEquivalent:[NSSWF:@"%C", NSBackspaceCharacter]];
	[_deleteMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	
	[self _update];
	[self _updateBookmarksMenu];

	if([WCSettings boolForKey:WCShowTrackersAtStartup])
		[[WCTrackers trackers] showWindow:self];

	if([WCSettings boolForKey:WCShowDockAtStartup])
		[[WCDock dock] showWindow:self];
	
	if([WCSettings boolForKey:WCShowConnectAtStartup]) {
		connection = [WCServerConnection serverConnection];
		
		[connection showWindow:self];
	}
	
	if((GetCurrentKeyModifiers() & optionKey) == 0) {
		enumerator = [[WCSettings objectForKey:WCBookmarks] objectEnumerator];

		while((bookmark = [enumerator nextObject])) {
			if([[bookmark objectForKey:WCBookmarksAutoConnect] boolValue])
				[self _connectWithBookmark:bookmark];
		}
	}
}



#pragma mark -

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if([WCSettings boolForKey:WCConfirmDisconnect] && [[WCDock dock] connectedConnections] > 0)
		return [(WIApplication *) NSApp runTerminationDelayPanelWithTimeInterval:30.0];

	return NSTerminateNow;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	_unread = 0;

	[self _updateApplicationIcon];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	[self _updateBookmarksMenu];
}



- (void)messagesDidAddMessage:(NSNotification *)notification {
	if(![[notification object] isRead]) {
		_unread++;
		
		[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
	}
}



- (void)messagesDidReadMessage:(NSNotification *)notification {
	_unread--;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidAddPost:(NSNotification *)notification {
	_unread++;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidReadPost:(NSNotification *)notification {
	_unread--;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)serverConnectionTriggeredEvent:(NSNotification *)notification {
	NSDictionary		*event;
	NSString			*sound;
	NSNumber			*clickContext;
	WCServerConnection	*connection;
	id					info1, info2;
	
	event = [notification object];
	connection = [[notification userInfo] objectForKey:WCServerConnectionEventConnectionKey];
	info1 = [[notification userInfo] objectForKey:WCServerConnectionEventInfo1Key];
	info2 = [[notification userInfo] objectForKey:WCServerConnectionEventInfo2Key];
	
	if([event boolForKey:WCEventsPlaySound]) {
		sound = [event objectForKey:WCEventsSound];
		
		if(sound)
			[NSSound playSoundNamed:sound];
	}
	   
	if([event boolForKey:WCEventsBounceInDock])
		[NSApp requestUserAttention:NSInformationalRequest];
	
	clickContext = [NSNumber numberWithUnsignedInteger:[[WCDock dock] indexOfConnection:connection]];
	
	switch([event intForKey:WCEventsEvent]) {
		case WCEventsServerConnected:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Connected", @"Growl event connected title")
										description:[NSSWF:NSLS(@"Connected to %@", @"Growl event connected description (server)"),
											[connection name]]
								   notificationName:WCGrowlServerConnected
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:NULL];
			break;

		case WCEventsServerDisconnected:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Disconnected", @"Growl event disconnected title")
										description:[NSSWF:NSLS(@"Disconnected from %@", @"Growl event disconnected description (server)"),
											[connection name]]
								   notificationName:WCGrowlServerDisconnected
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsError:
			[GrowlApplicationBridge notifyWithTitle:[info1 localizedDescription]
										description:[info1 localizedFailureReason]
								   notificationName:WCGrowlError
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserJoined:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User joined", @"Growl event user joined title")
										description:[info1 nick]
								   notificationName:WCGrowlUserJoined
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserChangedNick:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User changed nick", @"Growl event user changed nick title")
										description:[NSSWF:NSLS(@"%@ is now known as %@", @"Growl event user changed nick description (oldnick, newnick)"),
											[info1 nick], info2]
								   notificationName:WCGrowlUserChangedNick
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserChangedStatus:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User changed status", @"Growl event user changed status title")
										description:[NSSWF:NSLS(@"%@ changed status to %@", @"Growl event user changed status description (nick, status)"),
											[info1 nick], info2]
								   notificationName:WCGrowlUserChangedStatus
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserLeft:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User left", @"Growl event user left title")
										description:[info1 nick]
								   notificationName:WCGrowlUserLeft
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsChatReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Chat received", @"Growl event chat received title")
										description:[NSSWF:@"%@: %@", [info1 nick], info2]
								   notificationName:WCGrowlChatReceived
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsHighlightedChatReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Chat received", @"Growl event chat received title")
										description:[NSSWF:@"%@: %@", [info1 nick], info2]
								   notificationName:WCGrowlHighlightedChatReceived
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsMessageReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Message received", @"Growl event message received title")
										description:[NSSWF:@"%@: %@", [info1 userNick], [info1 message]]
								   notificationName:WCGrowlMessageReceived
										   iconData:[[[[connection chat] userWithUserID:[info1 userID]] icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsNewsPosted:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"News posted", @"Growl event news posted title")
										description:[NSSWF:@"%@: %@", info1, info2]
								   notificationName:WCGrowlNewsPosted
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsBroadcastReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Broadcast received", @"Growl event broadcast received title")
										description:[NSSWF:@"%@: %@", [info1 userNick], [info1 message]]
								   notificationName:WCGrowlBroadcastReceived
										   iconData:[[[[connection chat] userWithUserID:[info1 userID]] icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsTransferStarted:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Transfer started", @"Growl event transfer started title")
										description:[info1 name]
								   notificationName:WCGrowlTransferStarted
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsTransferFinished:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Transfer finished", @"Growl event transfer started title")
										description:[info1 name]
								   notificationName:WCGrowlTransferFinished
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
	}
}



#pragma mark -

- (NSDictionary *)registrationDictionaryForGrowl {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:
			WCGrowlServerConnected,
			WCGrowlServerDisconnected,
			WCGrowlError,
			WCGrowlUserJoined,
			WCGrowlUserChangedNick,
			WCGrowlUserChangedStatus,
			WCGrowlUserLeft,
			WCGrowlChatReceived,
			WCGrowlHighlightedChatReceived,
			WCGrowlMessageReceived,
			WCGrowlNewsPosted,
			WCGrowlBroadcastReceived,
			WCGrowlTransferStarted,
			WCGrowlTransferFinished,
			NULL],
		GROWL_NOTIFICATIONS_ALL,
		[NSArray arrayWithObjects:
			WCGrowlServerDisconnected,
			WCGrowlHighlightedChatReceived,
			WCGrowlMessageReceived,
			WCGrowlNewsPosted,
			WCGrowlBroadcastReceived,
			WCGrowlTransferFinished,
			NULL],
		GROWL_NOTIFICATIONS_DEFAULT,
		NULL];
}



- (void)growlNotificationWasClicked:(id)clickContext {
	WCServerConnection	*connection;
	
	[NSApp activateIgnoringOtherApps:YES];
	
	connection = [[WCDock dock] connectionAtIndex:[clickContext unsignedIntegerValue]];

	[[WCDock dock] openConnection:connection];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;

	selector = [item action];
	
	if(selector == @selector(hideConnection:) ||
	   selector == @selector(nextConnection:) ||
	   selector == @selector(previousConnection:) ||
	   selector == @selector(makeLayoutDefault:) ||
	   selector == @selector(restoreLayoutToDefault:) ||
	   selector == @selector(restoreAllLayoutsToDefault:))
		return [[WCDock dock] validateMenuItem:item];
	
	return YES;
}



- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSString				*string;
	WIURL					*url;
	WCServerConnection		*connection;

	string = [[event descriptorForKeyword:keyDirectObject] stringValue];
	url = [WIURL URLWithString:string];

	if([[url scheme] isEqualToString:@"wired"]) {
		if(![self _openConnectionWithURL:url]) {
			connection = [WCServerConnection serverConnectionWithURL:url];
	
			[connection showWindow:self];
			[connection connect];
		}
	}
	else if([[url scheme] isEqualToString:@"wiredtracker"]) {
		[WCSettings addTrackerBookmark:[NSDictionary dictionaryWithObjectsAndKeys:
			[url host],			WCTrackerBookmarksName,
			[url hostpair],		WCTrackerBookmarksAddress,
			NULL]];

		[[WCTrackers trackers] showWindow:self];
	}
}



- (void)dailyTimer:(NSTimer *)timer {
	[[NSNotificationCenter defaultCenter] postNotificationName:WCDateDidChange];
}



#pragma mark -

- (NSString *)clientVersion {
	NSBundle			*bundle;
	NSDictionary		*dictionary;
	const NXArchInfo	*arch;
	struct utsname		name;
	
	if(!_clientVersion) {
		bundle = [NSBundle mainBundle];
		dictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		arch = NXGetArchInfoFromCpuType(NXGetLocalArchInfo()->cputype, CPU_SUBTYPE_MULTIPLE);

		uname(&name);

		_clientVersion = [[NSString alloc] initWithFormat:@"%@/%@ (%@; %@; %s) (%s %s; %s; %@ %.1f; %@ %.2f)",
			[bundle objectForInfoDictionaryKey:@"CFBundleExecutable"],
			[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
			[dictionary objectForKey:@"ProductName"],
			[dictionary objectForKey:@"ProductVersion"],
			arch->name,
			name.sysname,
			name.release,
			SSLeay_version(SSLEAY_VERSION),
			@"CoreFoundation",
			kCFCoreFoundationVersionNumber,
			@"AppKit",
			NSAppKitVersionNumber];
	}

	return _clientVersion;
}



#pragma mark -

- (NSArray *)allSmileys {
	if(!_sortedSmileys)
		[self _loadSmileys];
	
	return _sortedSmileys;
}



- (NSString *)pathForSmiley:(NSString *)smiley {
	if(!_smileys)
		[self _loadSmileys];
	
	return [_smileys objectForKey:[smiley lowercaseString]];
}



#pragma mark -

- (IBAction)about:(id)sender {
	NSMutableParagraphStyle		*style;
	NSMutableAttributedString	*credits;
	NSDictionary				*attributes;
	NSAttributedString			*header, *stats;
	NSData						*rtf;
	NSString					*string;
	
	if((GetCurrentKeyModifiers() & optionKey) != 0) {
		// --- go custom about window
		[[WCAboutWindow aboutWindow] makeKeyAndOrderFront:self];
	} else {
		// --- read in Credits.rtf
		rtf = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]];
		credits = [[[NSMutableAttributedString alloc] initWithRTF:rtf documentAttributes:NULL] autorelease];

		// --- create "Stats" header
		style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[style setAlignment:NSCenterTextAlignment];
		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont boldSystemFontOfSize:11.0],	NSFontAttributeName,
			[NSColor grayColor],					NSForegroundColorAttributeName,
			style,									NSParagraphStyleAttributeName,
			NULL];
		string = [NSSWF:@"%@\n", NSLS(@"Stats", @"About box title")];
		header = [NSAttributedString attributedStringWithString:string attributes:attributes];

		// --- create stats string
		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont systemFontOfSize:11.0],			NSFontAttributeName,
			style,									NSParagraphStyleAttributeName,
			NULL];
		string = [NSSWF:@"%@\n\n", [[WCStats stats] stringValue]];
		stats = [NSAttributedString attributedStringWithString:string attributes:attributes];

		[credits insertAttributedString:stats atIndex:0];
		[credits insertAttributedString:header atIndex:0];

		[NSApp orderFrontStandardAboutPanelWithOptions:
			[NSDictionary dictionaryWithObject:credits forKey:@"Credits"]];
	}
}



- (IBAction)preferences:(id)sender {
	[[WCPreferences preferences] showWindow:self];
}



#pragma mark -

- (IBAction)connect:(id)sender {
	WCServerConnection		*connection;
	
	connection = [WCServerConnection serverConnection];
	
	[connection showWindow:self];
}



#pragma mark -

- (IBAction)bookmark:(id)sender {
	[self _connectWithBookmark:[sender representedObject]];
}



#pragma mark -

- (IBAction)showDock:(id)sender {
	[[WCDock dock] showWindow:self];
}



- (IBAction)showTrackers:(id)sender {
	[[WCTrackers trackers] showWindow:self];
}



- (IBAction)hideConnection:(id)sender {
	[[WCDock dock] hideConnection:sender];
}



- (IBAction)nextConnection:(id)sender {
	[[WCDock dock] nextConnection:sender];
}



- (IBAction)previousConnection:(id)sender {
	[[WCDock dock] previousConnection:sender];
}



- (IBAction)makeLayoutDefault:(id)sender {
	[[WCDock dock] makeLayoutDefault:sender];
}



- (IBAction)restoreLayoutToDefault:(id)sender {
	[[WCDock dock] restoreLayoutToDefault:sender];
}



- (IBAction)restoreAllLayoutsToDefault:(id)sender {
	[[WCDock dock] restoreAllLayoutsToDefault:sender];
}



#pragma mark -

- (IBAction)manual:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#2"]];
}

@end
