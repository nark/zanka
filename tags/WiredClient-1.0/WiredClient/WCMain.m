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

#import <sys/utsname.h>
#import <openssl/ssl.h>
#import "NSNumberAdditions.h"
#import "WCAboutWindow.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCApplication.h"
#import "WCChat.h"
#import "WCClient.h"
#import "WCConsole.h"
#import "WCConnection.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCIcons.h"
#import "WCMain.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCSecureSocket.h"
#import "WCServerInfo.h"
#import "WCSettings.h"
#import "WCStats.h"
#import "WCTextFinder.h"
#import "WCTrackers.h"
#import "WCTransfers.h"

@implementation WCMain

WCMain			*WCSharedMain;


- (id)init {
	struct utsname		name;
	
	self = [super init];

	// --- set our shared instance
	WCSharedMain = self;
	
	// --- initiate SSL
	SSL_library_init();
	SSL_load_error_strings();
	
	// --- ignore PIPE
	signal(SIGPIPE, SIG_IGN);

	// --- initiate and read our static settings, icons and stats
	_icons		= [[WCIcons alloc] init];
	_settings   = [[WCSettings alloc] init];
	_stats		= [[WCStats alloc] init];

	// --- initiate controllers
	_textFinder	= [[WCTextFinder alloc] init];
	_trackers	= [[WCTrackers alloc] init];

	// --- initiate static version string
	uname(&name);
	
	_version = [[NSString alloc] initWithFormat: @"%@/%@ (%s; %s; powerpc) (%s; CoreFoundation %.1f; AppKit %.2f)",
		@"Wired Client",
		[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
		name.sysname,
		name.release,
		SSLeay_version(SSLEAY_VERSION),
		kCFCoreFoundationVersionNumber,
		NSAppKitVersionNumber];

	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionHasAttached:)
		name:WCConnectionHasAttached
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionHasClosed:)
		name:WCConnectionHasClosed
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionPrivilegesDidChange:)
		name:WCConnectionPrivilegesDidChange
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(windowDidBecomeActive:)
		name:WCWindowDidBecomeActive
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(windowDidBecomeInactive:)
		name:WCWindowDidBecomeInactive
		object:NULL];
		
	// --- create stats saving timer
	[NSTimer scheduledTimerWithTimeInterval:900
			target:self
			selector:@selector(saveStats:)
			userInfo:NULL
			repeats:YES];

	// --- register a selector to use when receiving an open URL message
	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:self
		andSelector:@selector(handleAppleEvent:withReplyEvent:)
		forEventClass:kInternetEventClass
		andEventID:kAEGetURL];
		
	// --- change cwd to home
	[[NSFileManager defaultManager] changeCurrentDirectoryPath:NSHomeDirectory()];
	
	// --- create our directories in ~/Library/Application Support/
	[[NSFileManager defaultManager]
		createDirectoryAtPath:[WCApplicationSupportPath stringByStandardizingPath]
		attributes:NULL];
	[[NSFileManager defaultManager]
		createDirectoryAtPath:[[WCApplicationSupportPath stringByStandardizingPath] 
			stringByAppendingPathComponent:@"Icons"]
		attributes:NULL];
	
	return self;
}



- (void)awakeFromNib {
	// --- initiate the preferences once we have nib bindings
	_preferences = [[WCPreferences alloc] init];

	// --- workaround to assign command-backspace to the delete menu item
	[_deleteMenuItem setKeyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
	[_deleteMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	
	// --- we manage menus ourselves
	[_connectionMenu setAutoenablesItems:NO];
	[_filesMenu setAutoenablesItems:NO];
	
	// --- update menus according to preferences
	[self updateMenus];
	[self updateBookmarksMenu];
	
	// --- center connect window
	[[self window] center];

	// --- open the connection window
	if([[WCSettings objectForKey:WCShowConnectAtStartup] boolValue] == YES)
		[self connect:self];
}



#pragma mark -

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
	if([[filename pathExtension] isEqualToString:@"WiredIcons"]) {
		NSString	*path, *title, *description;
		BOOL		result;
		
		// --- get full destination path
		path = [[[WCApplicationSupportPath stringByStandardizingPath]
					stringByAppendingPathComponent:@"Icons"]
						stringByAppendingPathComponent:[filename lastPathComponent]];
		
		// --- try to copy
		result = [[NSFileManager defaultManager] copyPath:filename toPath:path handler:NULL];
		
		if(result) {
			// --- display panel
			title = NSLocalizedString(@"Icon Pack Installed", "Icon pack OK dialog title");
			description = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" has been installed as \"%@\".", "Icon pack OK dialog description"), [filename lastPathComponent], path];

			NSRunAlertPanel(title, description, NULL, NULL, NULL);
			
			// --- send notification
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCIconsShouldReload
							  object:NULL];
			
			// --- unlink pack
			[[NSFileManager defaultManager] removeFileAtPath:filename handler:NULL];

			return YES;
		} else {
			// --- display panel
			title = NSLocalizedString(@"Icon Pack Error", "Icon pack not OK dialog title");
			description = [NSString stringWithFormat:NSLocalizedString(@"Could not install \"%@\" as \"%@\".", "Icon pack not OK dialog description"), [filename lastPathComponent], path];

			NSRunAlertPanel(title, description, NULL, NULL, NULL);
			
			return NO;
		}
	}
	
	return NO;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	// --- if we have connection left to confirm, bring up an alert and handle application
	//     closing ourselves
	if(_connections > 0 && [[_activeConnection client] connected] &&
	   [[WCSettings objectForKey:WCConfirmDisconnect] boolValue] == YES) {
		if(NSRunAlertPanel(NSLocalizedString(@"Are you sure you want to quit?", @"Quit dialog title"),
						   NSLocalizedString(@"All connections will be terminated.", @"Quit dialog description"),
						   NULL, @"Cancel", NULL) == NSAlertDefaultReturn)
			return NSTerminateNow;
		else
			return NSTerminateCancel;
	}

	return NSTerminateNow;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	// --- broadcast termination notice to the active connection
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCConnectionShouldTerminate
					  object:_activeConnection];
	
	// --- save stats
	[WCStats save];
}



- (void)applicationDidBecomeActive:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCApplicationDidChangeStatus
		object:NULL];
}



- (void)applicationDidResignActive:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCApplicationDidChangeStatus
		object:NULL];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];
	
	_runningConnection = NULL;

	[[self window] close];

	[WCStats startCounting];
}



- (void)connectionHasClosed:(NSNotification *)notification {
	if(_connections == 1)
		[WCStats stopCounting];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	_connections--;

	if(_connections == 0)
		[WCStats stopCounting];
	
	_runningConnection = NULL;
	_activeConnection = NULL;
	_activeWindow = NULL;
	
	[_progressIndicator stopAnimation:self];

	[self updateMenus];
}



- (void)connectionPrivilegesDidChange:(NSNotification *)notification {
	if([notification object] != _activeConnection)
		return;
	
	[self updateMenus];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];
	
	if(_runningConnection) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionShouldTerminate
			object:_runningConnection];
	}
}



- (void)windowDidBecomeActive:(NSNotification *)notification {
	_activeWindow = [notification object];
	_activeConnection = [(WCWindowController *) _activeWindow connection];
	
	[self updateMenus];
}



- (void)windowDidBecomeInactive:(NSNotification *)notification {
	_activeWindow = NULL;
	_activeConnection = NULL;
	
	[self updateMenus];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self updateMenus];
	[self updateBookmarksMenu];
}



#pragma mark -

- (void)updateIcon {
	NSImage			*displayImage, *badgeImage, *backgroundImage;
	NSString		*badge;
	NSDictionary	*attributes;
	int				badgeX, fontX;
	
	// --- select an image and location depending on the count width
	if(_unread >= 100) {
		badge	= [NSString stringWithString:@"Baadge"];
		badgeX	= 60;
		fontX	= 74;
	}
	else if(_unread >= 10) {
		badge	= [NSString stringWithString:@"Badge"];
		badgeX	= 72;
		fontX	= 84;
	} else {
		badge	= [NSString stringWithString:@"Badge"];
		badgeX	= 72;
		fontX	= 91;
	}
	
	// --- get the images
	displayImage	= [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
	backgroundImage	= [NSImage imageNamed:@"WiredClient"];
	badgeImage		= [NSImage imageNamed:badge];
	
	// --- bold, white font
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica-Bold" size:24.0], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName,
		NULL];
	
	[backgroundImage setScalesWhenResized:YES];
	[backgroundImage setSize:NSMakeSize(128, 128)];
	
	// --- start drawing
	[displayImage lockFocus];
	[backgroundImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
	
	if(_unread > 0) {
		[badgeImage compositeToPoint:NSMakePoint(badgeX, 77) operation:NSCompositeSourceOver];
		[[NSString stringWithFormat:@"%u", _unread]
			drawAtPoint:NSMakePoint(fontX, 90) withAttributes:attributes];
	}
	
	// --- set icon
	[displayImage unlockFocus];
	[NSApp setApplicationIconImage:displayImage];
	
	// --- release
	[displayImage release];
}



- (void)updateMenus {
	// --- add/remove ellipsis depending on if a dialog will be shown or not
	if([[WCSettings objectForKey:WCConfirmDisconnect] boolValue]) {
		[_disconnectMenuItem setTitle:[NSString stringWithFormat:
			@"%@%C", NSLocalizedString(@"Disconnect", @"Disconnect menu item"), 0x2026]];
	} else {
		[_disconnectMenuItem setTitle:NSLocalizedString(@"Disconnect", @"Disconnect menu item")];
	}
	
	// --- enable/disable connection menu
	if(_activeConnection) {
		[_serverInfoMenuItem setEnabled:YES];
		[_chatMenuItem setEnabled:YES];
		[_newsMenuItem setEnabled:YES];
		[_messagesMenuItem setEnabled:YES];
		[_filesMenuItem setEnabled:YES];
		[_transfersMenuItem setEnabled:YES];
		[_searchMenuItem setEnabled:YES];
		[_consoleMenuItem setEnabled:YES];
		[_accountsMenuItem setEnabled:YES];
		
		if([_activeWindow isKindOfClass:[WCChat class]])
			[_saveChatMenuItem setEnabled:YES];
		else
			[_saveChatMenuItem setEnabled:NO];
		
		if([_activeWindow conformsToProtocol:@protocol(WCGetInfoValidation)]) {
			if([_activeWindow canGetInfo])
				[_getInfoMenuItem setEnabled:YES];
			else
				[_getInfoMenuItem setEnabled:NO];
		} else {
			[_getInfoMenuItem setEnabled:NO];
		}
		
		if([[_activeConnection account] postNews])
			[_postNewMenuItem setEnabled:YES];
		else
			[_postNewMenuItem setEnabled:NO];

		if([[_activeConnection account] broadcast])
			[_broadcastMenuItem setEnabled:YES];
		else
			[_broadcastMenuItem setEnabled:NO];

		[_disconnectMenuItem setEnabled:YES];
		
		[_addBookmarkMenuItem setEnabled:YES];
	} else {
		[_serverInfoMenuItem setEnabled:NO];
		[_chatMenuItem setEnabled:NO];
		[_newsMenuItem setEnabled:NO];
		[_messagesMenuItem setEnabled:NO];
		[_filesMenuItem setEnabled:NO];
		[_transfersMenuItem setEnabled:NO];
		[_searchMenuItem setEnabled:NO];
		[_consoleMenuItem setEnabled:NO];
		[_accountsMenuItem setEnabled:NO];
		[_saveChatMenuItem setEnabled:NO];
		[_getInfoMenuItem setEnabled:NO];
		[_postNewMenuItem setEnabled:NO];
		[_broadcastMenuItem setEnabled:NO];
		[_disconnectMenuItem setEnabled:NO];
		
		[_addBookmarkMenuItem setEnabled:NO];
	}
	
	// --- enable/disable files menu
	if([_activeWindow class] == [WCFiles class]) {
		if([_activeWindow canCreateFolders])
			[_newFolderMenuItem setEnabled:YES];
		else
			[_newFolderMenuItem setEnabled:NO];

		[_reloadMenuItem setEnabled:YES];

		if([_activeWindow canDeleteFiles])
			[_deleteMenuItem setEnabled:YES];
		else
			[_deleteMenuItem setEnabled:NO];
		
		if([_activeWindow canMoveBack])
			[_backMenuItem setEnabled:YES];
		else
			[_backMenuItem setEnabled:NO];

		if([_activeWindow canMoveForward])
			[_forwardMenuItem setEnabled:YES];
		else
			[_forwardMenuItem setEnabled:NO];
	} else {
		[_newFolderMenuItem setEnabled:NO];
		[_reloadMenuItem setEnabled:NO];
		[_deleteMenuItem setEnabled:NO];
		[_backMenuItem setEnabled:NO];
		[_forwardMenuItem setEnabled:NO];
	}
	
	// --- enable/disable bookmarks menu
	if(_activeConnection)
		[_addBookmarkMenuItem setEnabled:YES];
	else
		[_addBookmarkMenuItem setEnabled:NO];
}



- (void)updateBookmarksMenu {
	NSArray			*bookmarks;
	NSEnumerator	*enumerator;
	NSDictionary	*each;
	NSString		*equivalent;
	NSMenuItem		*item;
	int				i;
	
	// --- first clear all bookmarks
	i = [_bookmarksMenu numberOfItems];

	while(i-- > 0) {
		if([[_bookmarksMenu itemAtIndex:i] tag] == 0)
			[_bookmarksMenu removeItemAtIndex:i];
	}

	bookmarks	= [WCSettings objectForKey:WCBookmarks];
	enumerator	= [bookmarks objectEnumerator];
	i			= 0;
	
	// --- add the spacer
	if([bookmarks count] > 0)
		[_bookmarksMenu addItem:[NSMenuItem separatorItem]];
	
	while((each = [enumerator nextObject])) {
		// --- figure out equivalent
		equivalent = ++i < 10 ? [NSString stringWithFormat:@"%d", i] : @"";
		
		// --- create menu item
		item = [[NSMenuItem alloc] initWithTitle:[each objectForKey:@"Name"]
										  action:@selector(bookmark:)
								   keyEquivalent:equivalent];
		[item setRepresentedObject:each];
	
		// --- insert
		[_bookmarksMenu addItem:item];
		[item release];
	}
}



- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSString	*string;
	NSURL		*url;
	
	// --- extract URL
	string	= [[event descriptorForKeyword:keyDirectObject] stringValue];
	url		= [NSURL URLWithString:string];
	
	// --- set fields of connect window
	[_addressTextField setStringValue:[url host]];
	[_loginTextField setStringValue:[url user] ? [url user] : @""];
	[_passwordTextField setStringValue:[url password] ? [url password] : @""];
	
	// --- connect
	[self showConnect:url];
	[self connectWithWindow:self];
}



- (void)handleStatsKey {
	if(_activeConnection && [_activeWindow isKindOfClass:[WCChat class]]) {
		[[_activeConnection client]
			sendCommand:WCSayCommand
			withArgument:[NSString stringWithFormat:
				@"%u%@%@",
				[_activeWindow cid],
				WCFieldSeparator,
				[WCStats stats]]];
	}
}



- (void)saveStats:(NSTimer *)timer {
	[WCStats save];
}



#pragma mark -

- (NSString *)version {
	return _version;
}



- (unsigned int)unread {
	return _unread;
}



- (void)setUnread:(unsigned int)value {
	_unread = value;
}



#pragma mark -

- (void)showConnect:(NSURL *)url {
	NSString	*address;
	
	// --- get host:port pair
	if([url port] && [[url port] intValue] != 2000)
		address = [NSString stringWithFormat:@"%@:%@", [url host], [url port]];
	else
		address = [url host];
		
	// --- set fields of connect window
	[_addressTextField setStringValue:address ? address : @""];
	[_loginTextField setStringValue:[url user] ? [url user] : @""];
	[_passwordTextField setStringValue:[url password] ? [url password] : @""];
	
	// --- always start here
	[[self window] makeFirstResponder:_addressTextField];
	
	// --- show window
	[self showWindow:self];
}



- (IBAction)connectWithWindow:(id)sender {
	[self connectWithWindow:sender name:NULL];
}



- (IBAction)connectWithWindow:(id)sender name:(NSString *)name {
	NSString		*address, *login, *password, *string;
	NSURL			*url;
//	WCConnection	*connection;
	
	// --- get fields
	address		= [_addressTextField stringValue];
	login		= [_loginTextField stringValue];
	password	= [_passwordTextField stringValue];
	
	// --- create URL
	string		= [NSString stringWithFormat:@"wired://%@:%@@%@/", login, password, address];
	url			= [NSURL URLWithString:string];
	
	// --- start spinning
	[_progressIndicator startAnimation:self];

	// --- create connection
	_connections++;
	_runningConnection = [[WCConnection alloc] initWithURL:url name:name];
}



- (NSWindow *)shownWindow {
	if([[self window] isVisible])
		return [self window];
	
	return NULL;
}



#pragma mark -

- (IBAction)about:(id)sender {
	if((GetCurrentKeyModifiers() & optionKey) != 0) {
		WCAboutWindow		*window;
		
		window = [[WCAboutWindow alloc] init];
	} else {
		NSMutableParagraphStyle		*style;
		NSMutableAttributedString	*credits;
		NSAttributedString			*header, *stats;
		NSData						*rtf;

		// --- read in Credits.rtf
		rtf = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]];
		credits = [[NSMutableAttributedString alloc] initWithRTF:rtf documentAttributes:NULL];
		
		// --- align center
		style = [[NSMutableParagraphStyle alloc] init];
		[style setAlignment:NSCenterTextAlignment];
		
		// --- create "Stats" header
		header = [[NSAttributedString alloc]
					initWithString:[NSString stringWithFormat:@"%@\n", NSLocalizedString(@"Stats", @"About box title")]
					attributes:[NSDictionary dictionaryWithObjectsAndKeys:
						[NSFont fontWithName:@"Helvetica-Bold" size:12.0],
							NSFontAttributeName,
						[NSColor grayColor],
							NSForegroundColorAttributeName,
						style,
							NSParagraphStyleAttributeName,
						NULL]];

		// --- create stats string
		stats = [[NSAttributedString alloc]
					initWithString:[NSString stringWithFormat:@"%@\n\n", [WCStats stats]]
					attributes:[NSDictionary dictionaryWithObjectsAndKeys:
						[NSFont fontWithName:@"Helvetica" size:12.0], NSFontAttributeName,
						style, NSParagraphStyleAttributeName,
						NULL]];
		
		// --- alter credits string
		[credits insertAttributedString:stats atIndex:0];
		[credits insertAttributedString:header atIndex:0];

		// --- run about panel
		[NSApp orderFrontStandardAboutPanelWithOptions:
			[NSDictionary dictionaryWithObjectsAndKeys:credits, @"Credits", NULL]];
		
		[header release];
		[stats release];
		[style release];
		[credits release];
	}
}



- (IBAction)preferences:(id)sender {
	[_preferences showWindow:self];
}



#pragma mark -

- (IBAction)connect:(id)sender {
	[self showConnect:NULL];
}



- (IBAction)showTrackers:(id)sender {
	[_trackers showWindow:self];
}



- (IBAction)serverInfo:(id)sender {
	[[_activeConnection serverInfo] showWindow:self];
}



- (IBAction)chat:(id)sender {
	[[_activeConnection chat] showWindow:self];
}



- (IBAction)news:(id)sender {
	[[_activeConnection news] showWindow:self];
}



- (IBAction)messages:(id)sender {
	[[_activeConnection messages] showWindow:self];
}



- (IBAction)files:(id)sender {
	WCFile		*root;
	
	root = [[WCFile alloc] initWithType:WCFileTypeDirectory];
	[root setPath:@"/"];

	[[WCFiles alloc] initWithConnection:_activeConnection path:root];
	
	[root release];
}



- (IBAction)transfers:(id)sender {
	[[_activeConnection transfers] showWindow:self];
}



- (IBAction)console:(id)sender {
	[[_activeConnection console] showWindow:self];
}



- (IBAction)accounts:(id)sender {
	[[_activeConnection accounts] showWindow:self];
}



- (IBAction)saveChat:(id)sender {
	NSSavePanel		*savePanel;
	NSString		*name;
	int				result;
	
	if([_activeWindow isKindOfClass:[WCPublicChat class]]) {
		name = [NSString stringWithFormat:NSLocalizedString(@"%@ Public Chat.txt", "Save chat file name (server)"),
			[_activeConnection name]];
	}
	else if([_activeWindow isKindOfClass:[WCPrivateChat class]]) {
		name = [NSString stringWithFormat:NSLocalizedString(@"%@ Private Chat.txt", "Save chat file name (server)"),
			[_activeConnection name]];
	} else {
		return;
	}
	
	// --- run savepanel
	savePanel = [NSSavePanel savePanel];
	result = [savePanel runModalForDirectory:[WCSettings objectForKey:WCDownloadFolder]
										file:name];
	
	if(result == NSFileHandlingPanelOKButton)
		[_activeWindow saveChatToURL:[savePanel URL]];
}



- (IBAction)getInfo:(id)sender {
	if([_activeWindow conformsToProtocol:@protocol(WCGetInfoValidation)])
		[_activeWindow info:self];
}



- (IBAction)postNews:(id)sender {
	[[_activeConnection news] post:self];
}



- (IBAction)broadcast:(id)sender {
	[[_activeConnection messages] showBroadcast];
}



- (IBAction)disconnect:(id)sender {
	[[[_activeConnection chat] window] performClose:self];
}



#pragma mark -

- (IBAction)findPanel:(id)sender {
	[_textFinder setResponder:[[NSApp keyWindow] firstResponder]];
	[_textFinder showWindow:self];
}



- (IBAction)findNext:(id)sender {
	[_textFinder setResponder:[[NSApp keyWindow] firstResponder]];
	[_textFinder next:sender];
}



- (IBAction)findPrevious:(id)sender {
	[_textFinder setResponder:[[NSApp keyWindow] firstResponder]];
	[_textFinder previous:sender];
}



- (IBAction)useSelectionForFind:(id)sender {
	[_textFinder setResponder:[[NSApp keyWindow] firstResponder]];
	[_textFinder useSelectionForFind];
}



- (IBAction)jumpToSelection:(id)sender {
	[_textFinder setResponder:[[NSApp keyWindow] firstResponder]];
	[_textFinder jumpToSelection];
}


#pragma mark -

- (IBAction)largerText:(id)sender {
	NSFont		*oldFont, *newFont;
	float		newSize;
	
	oldFont = [WCSettings archivedObjectForKey:WCTextFont];
	newSize = [oldFont pointSize] + 1;
	newFont = [NSFont fontWithName:[oldFont fontName] size:newSize];
	
	[WCSettings setArchivedObject:newFont forKey:WCTextFont];
	
	// --- broadcast preferences change
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCPreferencesDidChange object:NULL];
}



- (IBAction)smallerText:(id)sender {
	NSFont		*oldFont, *newFont;
	float		newSize;
	
	oldFont = [WCSettings archivedObjectForKey:WCTextFont];
	newSize = [oldFont pointSize] == 1 ? 1 : [oldFont pointSize] - 1;
	newFont = [NSFont fontWithName:[oldFont fontName] size:newSize];
	
	[WCSettings setArchivedObject:newFont forKey:WCTextFont];
	
	// --- broadcast preferences change
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCPreferencesDidChange object:NULL];
}



#pragma mark -

- (IBAction)search:(id)sender {
	[[_activeConnection search] showWindow:self];
}



- (IBAction)newFolder:(id)sender {
	if([_activeWindow class] == [WCFiles class])
		[_activeWindow newFolder:sender];
}



- (IBAction)reload:(id)sender {
	if([_activeWindow class] == [WCFiles class])
		[_activeWindow reload:sender];
}



- (IBAction)delete:(id)sender {
	if([_activeWindow class] == [WCFiles class])
		[_activeWindow delete:sender];
}



- (IBAction)back:(id)sender {
	if([_activeWindow class] == [WCFiles class])
		[_activeWindow back:sender];
}



- (IBAction)forward:(id)sender {
	if([_activeWindow class] == [WCFiles class])
		[_activeWindow forward:sender];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary	*bookmark;
	NSMutableArray	*bookmarks;
	NSURL			*url;
	
	// --- create mutable bookmarks
	bookmarks = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];

	// --- get this URL
	url = [_activeConnection URL];
	
	// --- create new bookmark for this URL
	if(url) {
		bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
						[_activeConnection name],				@"Name",
						[url host],								@"Address",
						[url user] ? [url user] : @"",			@"Login",
						[url password] ? [url password] : @"",	@"Password",
						NULL];
	
		// --- add the bookmark
		[bookmarks addObject:bookmark];
		[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
		
		// --- update menu
		[self updateBookmarksMenu];
	}
}



- (IBAction)bookmark:(id)sender {
	NSDictionary	*bookmark;
	NSURL			*url;

	// --- get bookmark
	bookmark	= [sender representedObject];
	url			= [NSURL URLWithString:[NSString stringWithFormat:@"wired://%@:%@@%@",
						[bookmark objectForKey:@"Login"],
						[bookmark objectForKey:@"Password"],
						[bookmark objectForKey:@"Address"]]];
	
	// --- connect
	[self showConnect:url];
	[self connectWithWindow:self name:[bookmark objectForKey:@"Name"]];
}

@end
