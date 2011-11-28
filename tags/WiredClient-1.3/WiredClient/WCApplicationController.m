/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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
#import "WCConsole.h"
#import "WCDock.h"
#import "WCKeychain.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"
#import "WCStats.h"
#import "WCTrackers.h"

@interface WCApplicationController(Private)

- (void)_update;
- (void)_updateApplicationIcon;
- (void)_updateBookmarksMenu;

@end


@implementation WCApplicationController(Private)

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
	int				i = 1;

	while((item = (NSMenuItem *) [_bookmarksMenu itemWithTag:0]))
		[_bookmarksMenu removeItem:item];

	bookmarks = [WCSettings objectForKey:WCBookmarks];

	if([bookmarks count] > 0)
		[_bookmarksMenu addItem:[NSMenuItem separatorItem]];

	enumerator = [bookmarks objectEnumerator];

	while((bookmark = [enumerator nextObject])) {
		equivalent = i < 10 ? [NSSWF:@"%d", i] : @"";

		item = [[NSMenuItem alloc] initWithTitle:[bookmark objectForKey:WCBookmarksName]
										  action:@selector(bookmark:)
								   keyEquivalent:equivalent];
		[item setRepresentedObject:bookmark];

		[_bookmarksMenu addItem:item];
		[item release];

		i++;
	}
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

	date = [[NSCalendarDate dateAtMidnight] dateByAddingDays:1];
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
	
#ifdef RELEASE
	[[NSApp mainMenu] removeItemAtIndex:[[NSApp mainMenu] indexOfItemWithSubmenu:_debugMenu]];
#endif
	
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
}



#pragma mark -

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	if([WCSettings boolForKey:WCConfirmDisconnect] && [[WCDock dock] openConnections] > 0)
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
	_unread++;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
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
	
	event = [notification object];
	
	if([event boolForKey:WCEventsPlaySound])
		[NSSound playSoundNamed:[event objectForKey:WCEventsSound]];
	   
	if([event boolForKey:WCEventsBounceInDock])
		[NSApp requestUserAttention:NSInformationalRequest];
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
		connection = [WCServerConnection serverConnectionWithURL:url];
	
		[connection showWindow:self];
		[connection connect];
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
			[NSFont fontWithName:@"Helvetica-Bold" size:12.0],	NSFontAttributeName,
			[NSColor grayColor],								NSForegroundColorAttributeName,
			style,												NSParagraphStyleAttributeName,
			NULL];
		string = [NSSWF:@"%@\n", NSLS(@"Stats", @"About box title")];
		header = [NSAttributedString attributedStringWithString:string attributes:attributes];

		// --- create stats string
		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"Helvetica" size:12.0],	NSFontAttributeName,
			style,											NSParagraphStyleAttributeName,
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
	NSDictionary		*bookmark;
	NSString			*address, *login, *password;
	WCServerConnection	*connection;
	WIURL				*url;

	bookmark = [sender representedObject];
	address = [bookmark objectForKey:WCBookmarksAddress];
	login = [bookmark objectForKey:WCBookmarksLogin];
	password = [[WCKeychain keychain] passwordForBookmark:bookmark];

	url = [WIURL URLWithString:address scheme:@"wired"];
	[url setUser:login];
	[url setPassword:password ? password : @""];
	
	connection = [WCServerConnection serverConnectionWithURL:url bookmark:bookmark];
	
	[connection showWindow:self];
	[connection connect];
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
