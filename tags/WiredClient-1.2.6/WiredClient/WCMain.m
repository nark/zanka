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

#import "NSImageAdditions.h"
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "NSThreadAdditions.h"
#import "WCAboutWindow.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCApplication.h"
#import "WCChat.h"
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
#import "WCTableView.h"
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
	
	_clientVersion = [[NSString alloc] initWithFormat: @"%@/%@ (%s; %s; powerpc) (%s; CoreFoundation %.1f; AppKit %.2f)",
		[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
		[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
		name.sysname,
		name.release,
		SSLeay_version(SSLEAY_VERSION),
		kCFCoreFoundationVersionNumber,
		NSAppKitVersionNumber];
	
	// --- set exception handler
	if([WCSettings boolForKey:WCReportExceptions]) {
		[[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
		[[NSExceptionHandler defaultExceptionHandler] 
			setExceptionHandlingMask:NSLogAndHandleEveryExceptionMask];
	}

	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionHasAttached:)
		name:WCConnectionHasAttached
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionGotServerInfo:)
			   name:WCConnectionGotServerInfo
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
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChange
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
	
	// --- update menus according to preferences
	[self updateBookmarksMenu];
	
	// --- center connect window
	[[self window] center];

	// --- open the connection window
	if([WCSettings boolForKey:WCShowConnectAtStartup])
		[self connect:self];

	// --- open the tackers window
	if([WCSettings boolForKey:WCShowTrackersAtStartup])
		[_trackers showWindow:self];
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
	WCConnection	*connection;
	int				result;
	
	connection = [(WCWindowController *) [[NSApp keyWindow] windowController] connection];
	
	// --- if we have connection left to confirm, bring up an alert and handle
	//     application closing ourselves
	if([connection connected] && [WCSettings boolForKey:WCConfirmDisconnect]) {
		result = NSRunAlertPanel(NSLocalizedString(@"Are you sure you want to quit?", @"Quit dialog title"),
						   NSLocalizedString(@"All connections will be terminated.", @"Quit dialog description"),
						   NSLocalizedString(@"Quit", @"Quit dialog button title"),
						   NSLocalizedString(@"Cancel", @"Quit dialog button title"),
						   NULL);
		if(result == NSAlertDefaultReturn)
			return NSTerminateNow;
		else
			return NSTerminateCancel;
	}

	return NSTerminateNow;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
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



- (BOOL)exceptionHandler:(NSExceptionHandler *)exceptionHandler shouldLogException:(NSException *)exception mask:(unsigned int)mask {
	NSArray		*stacks;
	NSString	*trace, *command, *info;
	FILE		*fp;
	char		buffer[BUFSIZ];
	int			i = 0;

	trace = [[exception userInfo] objectForKey:NSStackTraceKey];
	
	if(trace) {
		stacks = [trace componentsSeparatedByString:@"  "];
		command = [NSString stringWithFormat:@"/usr/bin/atos -p %d %@",
			getpid(), trace];
		fp = popen([command UTF8String], "r");
		
		if(fp) {
			info = [NSString stringWithFormat:@"Command:    %@\nVersion:    %@ (%@)\nPID:        %d\n\nException:  %@: %@\n\nStack Trace:\n",
				[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
				[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
				[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
				getpid(),
				[exception name],
				[exception reason]];

			[_exceptionTextView performSelectorOnMainThread:@selector(setFont:)
												 withObject:[NSFont fontWithName:@"Monaco" size:9.0]];
			[_exceptionTextView performSelectorOnMainThread:@selector(setString:)
												 withObject:info];
			
			while(fgets(buffer, sizeof(buffer), fp) != NULL) {
				[[[_exceptionTextView textStorage] mutableString] appendFormat:@"%d%*s%@ in %s",
					i,
					i < 10 ? 3 : i < 100 ? 2 : i < 1000 ? 3 : 1,
					" ",
					[stacks objectAtIndex:i],
					buffer];
				
				i++;
			}
			
			[_exceptionPanel performSelectorOnMainThread:@selector(center)];
			[_exceptionPanel performSelectorOnMainThread:@selector(makeKeyAndOrderFront:)
											  withObject:self];
			
			pclose(fp);
		}
	}
	
	return YES;
}



- (void)connectionHasAttached:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];
	_connection = NULL;
	
	[[self window] close];

	[WCStats startCounting];
}



- (void)connectionGotServerInfo:(NSNotification *)notification {
	_connection = NULL;
}



- (void)connectionHasClosed:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];

	if(_connections == 1)
		[WCStats stopCounting];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];

	_connections--;

	if(_connections == 0)
		[WCStats stopCounting];
	
	_connection = NULL;
}



- (void)windowWillClose:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];
	
	if(_connection) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCConnectionShouldCancel
			object:_connection];
		
		_connection = NULL;
	}
}



- (void)preferencesDidChange:(NSNotification *)notification {
	// --- add/remove ellipsis depending on if a dialog will be shown or not
	if([WCSettings boolForKey:WCConfirmDisconnect]) {
		[_disconnectMenuItem setTitle:[NSString stringWithFormat:
			@"%@%C", NSLocalizedString(@"Disconnect", @"Disconnect menu item"), 0x2026]];
	} else {
		[_disconnectMenuItem setTitle:NSLocalizedString(@"Disconnect", @"Disconnect menu item")];
	}

	// --- reload bookmarks
	[self updateBookmarksMenu];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	// --- reload bookmarks
	[self updateBookmarksMenu];
}



#pragma mark -

- (void)updateIcon {
	[NSApp setApplicationIconImage:[[NSImage imageNamed:@"NSApplicationIcon"]
		badgedImageWithInt:_unread]];
}



- (void)updateBookmarksMenu {
	NSEnumerator	*enumerator;
	NSArray			*bookmarks;
	NSDictionary	*bookmark;
	NSString		*equivalent;
	NSMenuItem		*item;
	int				i = 1;
	
	// --- first clear all bookmarks
	while((item = (NSMenuItem *) [_bookmarksMenu itemWithTag:0]))
		[_bookmarksMenu removeItem:item];

	// --- get new bookmarks
	bookmarks	= [WCSettings objectForKey:WCBookmarks];
	enumerator	= [bookmarks objectEnumerator];
	
	// --- add the spacer
	if([bookmarks count] > 0)
		[_bookmarksMenu addItem:[NSMenuItem separatorItem]];
	
	while((bookmark = [enumerator nextObject])) {
		// --- figure out equivalent
		equivalent = i < 10 ? [NSString stringWithFormat:@"%d", i] : @"";
		
		// --- create menu item
		item = [[NSMenuItem alloc] initWithTitle:[bookmark objectForKey:WCBookmarksName]
										  action:@selector(bookmark:)
								   keyEquivalent:equivalent];
		[item setRepresentedObject:bookmark];
	
		// --- insert
		[_bookmarksMenu addItem:item];
		[item release];

		i++;
	}
}



- (BOOL)validateMenuItem:(id <NSMenuItem>)item {
	WCConnection	*connection = NULL;
	id				controller = NULL;
	
	// --- get active connection
	controller = [[NSApp keyWindow] windowController];
	
	if([controller isKindOfClass:[WCWindowController class]])
		connection = [(WCWindowController *) controller connection];
	
	// --- connection menu
	if(item == _serverInfoMenuItem)
		return (connection != NULL);
	else if(item == _chatMenuItem)
		return (connection != NULL);
	else if(item == _newsMenuItem)
		return (connection != NULL);
	else if(item == _messagesMenuItem)
		return (connection != NULL);
	else if(item == _filesMenuItem)
		return (connection != NULL);
	else if(item == _transfersMenuItem)
		return (connection != NULL);
	else if(item == _consoleMenuItem)
		return (connection != NULL);
	else if(item == _accountsMenuItem)
		return (connection != NULL);
	else if(item == _saveChatMenuItem)
		return [controller isKindOfClass:[WCChat class]];
	else if(item == _getInfoMenuItem)
		return [controller conformsToProtocol:@protocol(WCGetInfoValidation)] && [controller canGetInfo];
	else if(item == _postNewMenuItem)
		return [[connection account] postNews];
	else if(item == _broadcastMenuItem)
		return [[connection account] broadcast];
	else if(item == _setTopicMenuItem)
		return [controller isKindOfClass:[WCChat class]] && ([controller cid] != 1 || [[connection account] setTopic]);
	else if(item == _disconnectMenuItem)
		return (connection != NULL);
	
	// --- view menu
	else if(item == _viewOptionsMenuItem)
		return [controller conformsToProtocol:@protocol(WCTableViewSelectOptions)];

	// --- files menu
	else if(item == _searchMenuItem)
		return (connection != NULL);
	else if(item == _newFolderMenuItem)
		return [controller isKindOfClass:[WCFiles class]] && [controller canCreateFolders];
	else if(item == _reloadMenuItem)
		return [controller isKindOfClass:[WCFiles class]];
	else if(item == _deleteMenuItem)
		return [controller isKindOfClass:[WCFiles class]] && [controller canDeleteFiles];
	else if(item == _backMenuItem)
		return [controller isKindOfClass:[WCFiles class]] && [controller canMoveBack];
	else if(item == _forwardMenuItem)
		return [controller isKindOfClass:[WCFiles class]] && [controller canMoveForward];
	
	// --- bookmarks menu
	else if(item == _addBookmarkMenuItem)
		return (connection != NULL);
	
	return YES;
}




- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSMutableArray  *trackers;
	NSDictionary	*tracker;
	NSString		*string, *address;
	NSURL			*url;
	
	// --- extract URL
	string	= [[event descriptorForKeyword:keyDirectObject] stringValue];
	url		= [NSURL URLWithString:string];
	
	if([[url scheme] isEqualToString:@"wired"]) {
		// --- set fields of connect window
		[_addressTextField setStringValue:[url host]];
		[_loginTextField setStringValue:[url user] ? [url user] : @""];
		[_passwordTextField setStringValue:[url password] ? [url password] : @""];
		
		// --- connect
		[self showConnect:url];
		[self connectWithWindow:self];
	}
	else if([[url scheme] isEqualToString:@"wiredtracker"]) {
		// --- get host:port
		address = [url host];
		
		if([url port])
			address = [address stringByAppendingFormat:@":%u", [[url port] intValue]];
		
		// --- create mutable trackers
		trackers = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCTrackerBookmarks]];
		
		// --- create tracker
		tracker = [NSDictionary dictionaryWithObjectsAndKeys:
			[url host],		WCTrackerBookmarksName,
			address,		WCTrackerBookmarksAddress,
			NULL];
			
		// --- add to trackers
		[trackers addObject:tracker];
	
		// --- set new trackers
		[WCSettings setObject:[NSArray arrayWithArray:trackers] forKey:WCTrackerBookmarks];
		
		// --- reload trackers
		[_trackers updateTrackers];
		[_trackers showWindow:self];
	}
}



- (void)handleStatsKey {
	WCConnection	*connection;
	id				controller;
	
	// --- get active connection
	controller = [[NSApp keyWindow] windowController];
	connection = [(WCWindowController *) controller connection];
	
	// --- send stats
	if(connection && [controller isKindOfClass:[WCChat class]]) {
		[connection sendCommand:WCSayCommand
				   withArgument:[NSString stringWithFormat:@"%u", [controller cid]]
				   withArgument:[WCStats stats]
					 withSender:self];
	}
}



- (void)saveStats:(NSTimer *)timer {
	[WCStats save];
}



#pragma mark -

- (WCTrackers *)trackers {
	return _trackers;
}



- (NSString *)clientVersion {
	return _clientVersion;
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
	[_loginTextField setStringValue:[url user] ? [[url user] stringByReplacingURLPercentEscapes] : @""];
	[_passwordTextField setStringValue:[url password] ? [[url password] stringByReplacingURLPercentEscapes] : @""];
	
	// --- always start here
	[[self window] makeFirstResponder:_addressTextField];
	
	// --- show window
	[self showWindow:self];
}



- (IBAction)connectWithWindow:(id)sender {
	[self connectWithWindow:sender name:NULL];
}



- (IBAction)connectWithWindow:(id)sender name:(NSString *)name {
	NSString		*address, *login, *password;
	NSURL			*url;
	
	// --- get fields
	address		= [_addressTextField stringValue];
	login		= [_loginTextField stringValue];
	password	= [_passwordTextField stringValue];
	
	// --- escape characters in login and password
	login		= [login stringByAddingURLPercentEscapes];
	password	= [password stringByAddingURLPercentEscapes];
	
	// --- create URL
	url = [NSURL URLWithString:[NSString stringWithFormat:@"wired://%@:%@@%@/",
		login, password, address]];
	
	// --- start spinning
	[_progressIndicator startAnimation:self];

	// --- create connection
	_connections++;
	_connection = [[WCConnection alloc] initServerConnectionWithURL:url name:name];
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
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] serverInfo] showWindow:self];
}



- (IBAction)chat:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] chat] showWindow:self];
}



- (IBAction)news:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] news] showWindow:self];
}



- (IBAction)messages:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] messages] showWindow:self];
}



- (IBAction)files:(id)sender {
	WCConnection	*connection;
	WCFile			*root;
	
	connection = [(WCWindowController *) [[NSApp keyWindow] windowController] connection];
	root = [[WCFile alloc] initWithType:WCFileTypeDirectory];
	[root setPath:@"/"];

	[[WCFiles alloc] initWithConnection:connection path:root];
	
	[root release];
}



- (IBAction)transfers:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] transfers] showWindow:self];
}



- (IBAction)console:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] console] showWindow:self];
}



- (IBAction)accounts:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] accounts] showWindow:self];
}



- (IBAction)saveChat:(id)sender {
	NSSavePanel		*savePanel;
	NSString		*name, *path;
	WCConnection	*connection;
	id				controller;
	
	// --- get active window
	controller = [[NSApp keyWindow] windowController];
	connection = [(WCWindowController *) controller connection];
	
	// --- get filename
	if([controller isKindOfClass:[WCPublicChat class]]) {
		name = [NSString stringWithFormat:NSLocalizedString(@"%@ Public Chat.txt", "Save chat file name (server)"),
			[connection name]];
	}
	else if([controller isKindOfClass:[WCPrivateChat class]]) {
		name = [NSString stringWithFormat:NSLocalizedString(@"%@ Private Chat.txt", "Save chat file name (server)"),
			[connection name]];
	} else {
		return;
	}
	
	// --- create savepanel
	path = [WCSettings objectForKey:WCDownloadFolder];
	savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setTitle:NSLocalizedString(@"Save Chat", @"Save chat save panel title")];
		
	// --- run panel
	if([savePanel runModalForDirectory:path file:name] == NSFileHandlingPanelOKButton)
		[controller saveChatToURL:[savePanel URL]];
}



- (IBAction)getInfo:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];

	if([controller conformsToProtocol:@protocol(WCGetInfoValidation)])
		[controller info:self];
}



- (IBAction)postNews:(id)sender {
	WCNews		*news;
	
	news = [[(WCWindowController *) [[NSApp keyWindow] windowController] connection] news];
	[news showWindow:self];
	[news post:self];
}



- (IBAction)broadcast:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] messages] showBroadcast];
}



- (IBAction)setTopic:(id)sender {
	[(WCChat *) [[NSApp keyWindow] windowController] showSetTopic];
}



- (IBAction)disconnect:(id)sender {
	[[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] chat] window] performClose:self];
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



- (IBAction)viewOptions:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller conformsToProtocol:@protocol(WCTableViewSelectOptions)])
		[(WCTableView *) [controller tableView] showViewOptions];
}



#pragma mark -

- (IBAction)search:(id)sender {
	[[[(WCWindowController *) [[NSApp keyWindow] windowController] connection] search] showWindow:self];
}



- (IBAction)newFolder:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller class] == [WCFiles class])
		[controller newFolder:sender];
}



- (IBAction)reload:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller class] == [WCFiles class])
		[controller reload:sender];
}



- (IBAction)delete:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller class] == [WCFiles class])
		[controller delete:sender];
}



- (IBAction)back:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller class] == [WCFiles class])
		[controller back:sender];
}



- (IBAction)forward:(id)sender {
	id		controller;
	
	controller = [[NSApp keyWindow] windowController];
	
	if([controller class] == [WCFiles class])
		[controller forward:sender];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary	*bookmark;
	NSMutableArray	*bookmarks;
	NSURL			*url;
	NSString		*host, *login, *password;
	WCConnection	*connection;
	
	// --- create mutable bookmarks
	bookmarks = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCBookmarks]];

	// --- get active conection
	connection = [(WCWindowController *) [[NSApp keyWindow] windowController] connection];
	url = [connection URL];
	
	// --- create new bookmark for this URL
	if(url) {
		host = [url host];
		
		if([url port] && [[url port] intValue] != 2000)
			host = [host stringByAppendingFormat:@":%@", [url port]];
		
		login		= [url user] ? [[url user] stringByReplacingURLPercentEscapes] : @"";
		password	= [url password] ? [[url password] stringByReplacingURLPercentEscapes] : @"";
		bookmark	= [NSDictionary dictionaryWithObjectsAndKeys:
			[connection name],		WCBookmarksName,
			host,					WCBookmarksAddress,
			login,					WCBookmarksLogin,
			password,				WCBookmarksPassword,
			NULL];
	
		// --- add the bookmark
		[bookmarks addObject:bookmark];
		[WCSettings setObject:[NSArray arrayWithArray:bookmarks] forKey:WCBookmarks];
		
		// --- broadcast preferences change
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange object:NULL];
	}
}



- (IBAction)bookmark:(id)sender {
	NSDictionary	*bookmark;
	NSString		*address, *login, *password;
	NSURL			*url;

	// --- get bookmark
	bookmark	= [sender representedObject];
	address		= [bookmark objectForKey:WCBookmarksAddress];
	login		= [[bookmark objectForKey:WCBookmarksLogin] stringByAddingURLPercentEscapes];
	password	= [[bookmark objectForKey:WCBookmarksPassword] stringByAddingURLPercentEscapes];
	url			= [NSURL URLWithString:[NSString stringWithFormat:@"wired://%@:%@@%@/",
		login, password, address]];
	
	// --- connect
	[self showConnect:url];
	[self connectWithWindow:self name:[bookmark objectForKey:WCBookmarksName]];
}

@end
