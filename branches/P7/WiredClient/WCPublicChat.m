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

#import "WCAccount.h"
#import "WCAdministration.h"
#import "WCApplicationController.h"
#import "WCBoards.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCKeychain.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCPublicChatController.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCUser.h"

enum _WCChatActivity {
	WCChatNoActivity						= 0,
	WCChatEventActivity,
	WCChatRegularChatActivity,
	WCChatHighlightedChatActivity,
};
typedef enum _WCChatActivity				WCChatActivity;


@interface WCPublicChat(Private)

- (void)_updateToolbarForConnection:(WCServerConnection *)connection;
- (void)_updateBannerToolbarItem:(NSToolbarItem *)item forConnection:(WCServerConnection *)connection;

- (BOOL)_beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window connection:(WCServerConnection *)connection modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo;

- (void)_closeSelectedTabViewItem;
- (void)_removeTabViewItem:(NSTabViewItem *)tabViewItem;

@end


@implementation WCPublicChat(Private)

- (void)_updateToolbarForConnection:(WCServerConnection *)connection {
	NSToolbarItem		*item;
	
	item = [[[self window] toolbar] itemWithIdentifier:@"Banner"];
	
	[item setEnabled:(connection != NULL)];

	if(connection == [[self selectedChatController] connection]) {
		item = [[[self window] toolbar] itemWithIdentifier:@"Banner"];

		[self _updateBannerToolbarItem:item forConnection:connection];
	}
	
	item = [[[self window] toolbar] itemWithIdentifier:@"Messages"];
	
	[item setImage:[[NSImage imageNamed:@"Messages"] badgedImageWithInt:[[WCMessages messages] numberOfUnreadMessages]]];

	item = [[[self window] toolbar] itemWithIdentifier:@"Boards"];
	
	[item setImage:[[NSImage imageNamed:@"Boards"] badgedImageWithInt:[[WCBoards boards] numberOfUnreadThreads]]];
}



- (void)_updateBannerToolbarItem:(NSToolbarItem *)item forConnection:(WCServerConnection *)connection {
	NSImage		*image;

	if(connection) {
		[item setLabel:[connection name]];
		[item setPaletteLabel:[connection name]];
		[item setToolTip:[connection name]];
	} else {
		[item setLabel:NSLS(@"Banner", @"Banner toolbar item")];
		[item setPaletteLabel:NSLS(@"Banner", @"Banner toolbar item")];
		[item setToolTip:NSLS(@"Banner", @"Banner toolbar item")];
	}
	
	image = [[connection server] banner];
	
	if(image)
		[(NSButton *) [item view] setImage:image];
	else
		[(NSButton *) [item view] setImage:[NSImage imageNamed:@"Banner"]];
}



#pragma mark -

- (BOOL)_beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window connection:(WCServerConnection *)connection modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo {
	NSAlert		*alert;
	
	if([[WCSettings settings] boolForKey:WCConfirmDisconnect] && [connection isConnected]) {
		alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLS(@"Are you sure you want to disconnect?", @"Disconnect dialog title")];
		[alert setInformativeText:NSLS(@"Disconnecting will close any ongoing file transfers.", @"Disconnect dialog description")];
		[alert addButtonWithTitle:NSLS(@"Disconnect", @"Disconnect dialog button")];
		[alert addButtonWithTitle:NSLS(@"Cancel", @"Disconnect dialog button title")];
		[alert beginSheetModalForWindow:window
						  modalDelegate:delegate
						 didEndSelector:selector
							contextInfo:contextInfo];
		[alert release];
		
		return NO;
	}
	
	return YES;
}



#pragma mark -

- (void)_closeSelectedTabViewItem {
	NSTabViewItem			*tabViewItem;
	
	tabViewItem = [_chatTabView selectedTabViewItem];
	
	[self _removeTabViewItem:tabViewItem];
	
	[_chatTabView removeTabViewItem:tabViewItem];
}



- (void)_removeTabViewItem:(NSTabViewItem *)tabViewItem {
	NSString				*identifier;
	WCPublicChatController	*chatController;
	
	identifier		= [tabViewItem identifier];
	chatController	= [_chatControllers objectForKey:identifier];
	
	[chatController saveWindowProperties];
	
	[[chatController connection] terminate];
	
	[_chatControllers removeObjectForKey:identifier];
	[_chatActivity removeObjectForKey:identifier];
	
	if([_chatControllers count] == 0) {
		[self _updateToolbarForConnection:NULL];
		
		[_noConnectionTextField setHidden:NO];
	}
}

@end



@implementation WCPublicChat

+ (id)publicChat {
	static WCPublicChat			*publicChat;
	
	if(!publicChat)
		publicChat = [[self alloc] init];
	
	return publicChat;
}



- (id)init {
	self = [super initWithWindowNibName:@"PublicChatWindow"];
	
	_chatControllers	= [[NSMutableDictionary alloc] init];
	_chatActivity		= [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionServerInfoDidChange:)
			   name:WCServerConnectionServerInfoDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatRegularChatDidAppear:)
			   name:WCChatRegularChatDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatHighlightedChatDidAppear:)
			   name:WCChatHighlightedChatDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatEventDidAppear:)
			   name:WCChatEventDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(boardsDidChangeUnreadCount:)
			   name:WCBoardsDidChangeUnreadCountNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidChangeUnreadCount:)
			   name:WCMessagesDidChangeUnreadCountNotification];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_tabBarControl release];
	
	[_chatControllers release];
	[_chatActivity release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar			*toolbar;
	NSRect				frame;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"PublicChat"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setShowsBaselineSeparator:NO];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"PublicChat"];

	frame				= [[[self window] contentView] frame];
	frame.origin.y		= frame.size.height - 23.0;
	frame.size.height	= 23.0;
	
	_tabBarControl = [[PSMTabBarControl alloc] initWithFrame:frame];
	[_tabBarControl setTabView:_chatTabView];
	[_tabBarControl setStyleNamed:@"Wired"];
	[_tabBarControl setDelegate:self];
	[_tabBarControl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin]; 
	[_tabBarControl setCanCloseOnlyTab:YES];
	[[[self window] contentView] addSubview:_tabBarControl];
	[_chatTabView setDelegate:_tabBarControl];
	
	[self _updateToolbarForConnection:NULL];

	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[[self selectedChatController] saveWindowProperties];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	NSButton		*button;
	
	if([identifier isEqualToString:@"Banner"]) {
		button = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 200.0, 32.0)] autorelease];
		[button setBordered:NO];
		[button setImage:[NSImage imageNamed:@"Banner"]];
		[button setButtonType:NSMomentaryChangeButton];
		
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Banner", @"Banner toolbar item")
												content:button
												 target:self
												 action:@selector(serverInfo:)];
	}
	else if([identifier isEqualToString:@"Boards"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Boards", @"Boards toolbar item")
												content:[NSImage imageNamed:@"Boards"]
												 target:[WCApplicationController sharedController]
												 action:@selector(boards:)];
	}
	else if([identifier isEqualToString:@"Messages"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Messages", @"Messages toolbar item")
												content:[NSImage imageNamed:@"Messages"]
												 target:[WCApplicationController sharedController]
												 action:@selector(messages:)];
	}
	else if([identifier isEqualToString:@"Files"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Files", @"Files toolbar item")
												content:[NSImage imageNamed:@"Folder"]
												 target:self
												 action:@selector(files:)];
	}
	else if([identifier isEqualToString:@"Transfers"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Transfers", @"Transfers toolbar item")
												content:[NSImage imageNamed:@"Transfers"]
												 target:[WCApplicationController sharedController]
												 action:@selector(transfers:)];
	}
	else if([identifier isEqualToString:@"Settings"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Settings", @"Settings toolbar item")
												content:[NSImage imageNamed:@"Settings"]
												 target:self
												 action:@selector(settings:)];
	}
	else if([identifier isEqualToString:@"Monitor"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Monitor", @"Monitor toolbar item")
												content:[NSImage imageNamed:@"Monitor"]
												 target:self
												 action:@selector(monitor:)];
	}
	else if([identifier isEqualToString:@"Events"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Events", @"Events toolbar item")
												content:[NSImage imageNamed:@"Events"]
												 target:self
												 action:@selector(events:)];
	}
	else if([identifier isEqualToString:@"Log"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Log", @"Log toolbar item")
												content:[NSImage imageNamed:@"Log"]
												 target:self
												 action:@selector(log:)];
	}
	else if([identifier isEqualToString:@"Accounts"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Accounts", @"Accounts toolbar item")
												content:[NSImage imageNamed:@"Accounts"]
												 target:self
												 action:@selector(accounts:)];
	}
	else if([identifier isEqualToString:@"Banlist"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Banlist", @"Banlist toolbar item")
												content:[NSImage imageNamed:@"Banlist"]
												 target:self
												 action:@selector(banlist:)];
	}
	else if([identifier isEqualToString:@"Reconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Reconnect"]
												 target:self
												 action:@selector(reconnect:)];
	}
	else if([identifier isEqualToString:@"Disconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Disconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Disconnect"]
												 target:self
												 action:@selector(disconnect:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		NSToolbarSpaceItemIdentifier,
		@"Boards",
		@"Messages",
		@"Files",
		@"Transfers",
		@"Settings",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Reconnect",
		@"Disconnect",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		@"Boards",
		@"Messages",
		@"Files",
		@"Transfers",
		@"Settings",
		@"Monitor",
		@"Events",
		@"Log",
		@"Accounts",
		@"Banlist",
		@"Reconnect",
		@"Disconnect",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)toolbarWillAddItem:(NSNotification *)notification {
	NSToolbarItem		*item;
	
	item = [[notification userInfo] objectForKey:@"item"];
	
	if([[item itemIdentifier] isEqualToString:@"Banner"])
		[self _updateBannerToolbarItem:item forConnection:[[self selectedChatController] connection]];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];

	[[_chatTabView tabViewItemWithIdentifier:[connection identifier]] setLabel:[connection name]];
	
	[self _updateToolbarForConnection:connection];
}



- (void)chatRegularChatDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	WCChatActivity			activity;
	
	connection		= [notification object];
	activity		= [[_chatActivity objectForKey:[connection identifier]] integerValue];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem] && activity < WCChatRegularChatActivity) {
		color = [WIColorFromString([[connection theme] objectForKey:WCThemesChatTextColor]) colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
		
		[_chatActivity setObject:[NSNumber numberWithInteger:WCChatRegularChatActivity] forKey:[connection identifier]];
	}
}



- (void)chatHighlightedChatDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	WCChatActivity			activity;
	
	connection		= [notification object];
	activity		= [[_chatActivity objectForKey:[connection identifier]] integerValue];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem] && activity < WCChatHighlightedChatActivity) {
		color = [[[notification userInfo] objectForKey:WCChatHighlightColorKey] colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
		
		[_chatActivity setObject:[NSNumber numberWithInteger:WCChatHighlightedChatActivity] forKey:[connection identifier]];
	}
}



- (void)chatEventDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	WCChatActivity			activity;
	
	connection		= [notification object];
	activity		= [[_chatActivity objectForKey:[connection identifier]] integerValue];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem] && activity < WCChatEventActivity) {
		color = [WIColorFromString([[connection theme] objectForKey:WCThemesChatEventsColor]) colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
		
		[_chatActivity setObject:[NSNumber numberWithInteger:WCChatEventActivity] forKey:[connection identifier]];
	}
}



- (void)boardsDidChangeUnreadCount:(NSNotification *)notification {
	[self _updateToolbarForConnection:[[self selectedChatController] connection]];
}



- (void)messagesDidChangeUnreadCount:(NSNotification *)notification {
	[self _updateToolbarForConnection:[[self selectedChatController] connection]];
}



- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	WCPublicChatController		*chatController;
	
	chatController = [_chatControllers objectForKey:[tabViewItem identifier]];
	
	[_chatActivity removeObjectForKey:[[chatController connection] identifier]];
	[_tabBarControl setIcon:NULL forTabViewItem:tabViewItem];
}



- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	[self _updateToolbarForConnection:[[self selectedChatController] connection]];
}



- (BOOL)tabView:(NSTabView *)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	WCPublicChatController		*chatController;
	
	chatController = [_chatControllers objectForKey:[tabViewItem identifier]];
	
	return [self _beginConfirmDisconnectSheetModalForWindow:[self window]
												 connection:[chatController connection]
											  modalDelegate:self
											 didEndSelector:@selector(closeTabSheetDidEnd:returnCode:contextInfo:)
												contextInfo:[tabViewItem retain]];
}



- (void)tabView:(NSTabView *)tabView willCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	[self _removeTabViewItem:tabViewItem];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCPublicChatController	*chatController;
	WCServerConnection		*connection;
	SEL						selector;
	
	chatController	= [self selectedChatController];
	connection		= [[self selectedChatController] connection];
	selector		= [item action];
	
	if(selector == @selector(disconnect:))
		return (connection != NULL && [connection isConnected]);
	else if(selector == @selector(reconnect:))
		return (connection != NULL && ![connection isConnected] && ![connection isManuallyReconnecting]);
	else if(selector == @selector(files:))
		return (connection != NULL && [connection isConnected] && [[connection account] fileListFiles]);
	else if(selector == @selector(broadcast:))
		return (connection != NULL && [connection isConnected]);
	else if(selector == @selector(changePassword:))
		return (connection != NULL && [connection isConnected] && [[connection account] accountChangePassword]);
	else if(selector == @selector(serverInfo:) || selector == @selector(administration:) ||
			selector == @selector(console:))
		return (connection != NULL);
	else if(selector == @selector(nextConnection:) || selector == @selector(previousConnection:))
		return ([_chatControllers count] > 1);
	
	return [chatController validateMenuItem:item];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCServerConnection		*connection;
	SEL						selector;
	
	connection		= [[self selectedChatController] connection];
	selector		= [item action];
	
	if(selector == @selector(banner:))
		return (connection != NULL);
	else if(selector == @selector(disconnect:))
		return (connection != NULL && [connection isConnected] && ![connection isDisconnecting]);
	else if(selector == @selector(reconnect:))
		return (connection != NULL && ![connection isConnected] && ![connection isManuallyReconnecting]);
	else if(selector == @selector(files:))
		return (connection != NULL && [connection isConnected] && [[connection account] fileListFiles]);
	else if(selector == @selector(serverInfo:) || selector == @selector(administration:) ||
			selector == @selector(settings:) || selector == @selector(monitor:) ||
			selector == @selector(events:) || selector == @selector(log:) ||
			selector == @selector(accounts:) || selector == @selector(banlist:))
		return (connection != NULL);
	
	return YES;
}



#pragma mark -

- (NSString *)saveDocumentMenuItemTitle {
	return [[self selectedChatController] saveDocumentMenuItemTitle];
}



#pragma mark -

- (IBAction)saveDocument:(id)sender {
	[self saveChat:sender];
}



- (IBAction)disconnect:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];

	if([self _beginConfirmDisconnectSheetModalForWindow:[self window]
											 connection:connection
										  modalDelegate:self
										 didEndSelector:@selector(disconnectSheetDidEnd:returnCode:contextInfo:)
											contextInfo:[connection retain]]) {
		[connection disconnect];
		[connection release];
	}
}



- (void)disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCServerConnection		*connection = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn)
		[connection disconnect];
	
	[connection release];
}



- (IBAction)reconnect:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[connection reconnect];
}



- (IBAction)serverInfo:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection serverInfo] showWindow:self];
}



- (IBAction)files:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[WCFiles filesWithConnection:connection file:[WCFile fileWithRootDirectoryForConnection:connection]];
}



- (IBAction)administration:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] showWindow:self];
}



- (IBAction)settings:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] settingsController]];
	[[connection administration] showWindow:self];
}



- (IBAction)monitor:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] monitorController]];
	[[connection administration] showWindow:self];
}



- (IBAction)events:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] eventsController]];
	[[connection administration] showWindow:self];
}



- (IBAction)log:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] logController]];
	[[connection administration] showWindow:self];
}



- (IBAction)accounts:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] accountsController]];
	[[connection administration] showWindow:self];
}



- (IBAction)banlist:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] selectController:[[connection administration] banlistController]];
	[[connection administration] showWindow:self];
}



- (IBAction)console:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection console] showWindow:self];
}



- (IBAction)getInfo:(id)sender {
	[[self selectedChatController] getInfo:sender];
}



- (IBAction)saveChat:(id)sender {
	[[self selectedChatController] saveChat:sender];
}



- (IBAction)setTopic:(id)sender {
	[[self selectedChatController] setTopic:sender];
}



- (IBAction)broadcast:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[WCMessages messages] showBroadcastForConnection:connection];
}



- (IBAction)changePassword:(id)sender {
	[[self selectedChatController] changePassword:sender];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary		*bookmark;
	NSString			*login, *password;
	WIURL				*url;
	WCServerConnection	*connection;
	
	connection	= [[self selectedChatController] connection];
	url			= [connection URL];
	
	if(url) {
		login		= [url user] ? [url user] : @"";
		password	= [url password] ? [url password] : @"";
		bookmark	= [NSDictionary dictionaryWithObjectsAndKeys:
		   [connection name],			WCBookmarksName,
		   [url hostpair],				WCBookmarksAddress,
		   login,						WCBookmarksLogin,
		   @"",							WCBookmarksNick,
		   @"",							WCBookmarksStatus,
		   [NSString UUIDString],		WCBookmarksIdentifier,
		   NULL];
		
		[[WCSettings settings] addObject:bookmark toArrayForKey:WCBookmarks];
		
		[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
		
		[connection setBookmark:bookmark];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
	}
}



#pragma mark -

- (IBAction)nextConnection:(id)sender {
	NSArray				*items;
	NSUInteger			index, newIndex;
	
	items = [_chatTabView tabViewItems];
	index = [items indexOfObject:[_chatTabView selectedTabViewItem]];
	
	if([items count] > 0) {
		if(index == [items count] - 1)
			newIndex = 0;
		else
			newIndex = index + 1;
		
		[_chatTabView selectTabViewItemAtIndex:newIndex];

		[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
	}
}



- (IBAction)previousConnection:(id)sender {
	NSArray				*items;
	NSUInteger			index, newIndex;
	
	items = [_chatTabView tabViewItems];
	index = [items indexOfObject:[_chatTabView selectedTabViewItem]];
	
	if([items count] > 0) {
		if(index == 0)
			newIndex = [items count] - 1;
		else
			newIndex = index - 1;
		
		[_chatTabView selectTabViewItemAtIndex:newIndex];

		[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
	}
}



- (IBAction)closeTab:(id)sender {
	NSTabViewItem			*tabViewItem;
	WCServerConnection		*connection;
	
	tabViewItem		= [_chatTabView selectedTabViewItem];
	connection		= [[self selectedChatController] connection];
	
	if([self _beginConfirmDisconnectSheetModalForWindow:[self window]
											 connection:connection
										  modalDelegate:self
										 didEndSelector:@selector(closeTabSheetDidEnd:returnCode:contextInfo:)
											contextInfo:[tabViewItem retain]]) {
		[self _removeTabViewItem:tabViewItem];
		
		[_chatTabView removeTabViewItem:tabViewItem];
		
		[tabViewItem release];
	}
}



- (void)closeTabSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSTabViewItem		*tabViewItem = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		[self _removeTabViewItem:tabViewItem];
		
		[_chatTabView removeTabViewItem:tabViewItem];
	}
	
	[tabViewItem release];
}



#pragma mark -

- (NSTextView *)insertionTextView {
	return [[self selectedChatController] insertionTextView];
}



#pragma mark -

- (void)addChatController:(WCPublicChatController *)chatController {
	NSTabViewItem		*tabViewItem;
	NSString			*identifier;
	
	identifier = [[chatController connection] identifier];
	
	if([_chatControllers objectForKey:identifier] != NULL)
		return;
	
	[[chatController connection] setIdentifier:identifier];
	
	[_chatControllers setObject:chatController forKey:identifier];
	
	if([_chatControllers count] == 1)
		[_noConnectionTextField setHidden:YES];
	
	tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:identifier] autorelease];
	[tabViewItem setLabel:[[chatController connection] name]];
	[tabViewItem setView:[chatController view]];
	
	[_chatTabView addTabViewItem:tabViewItem];
	[_chatTabView selectTabViewItem:tabViewItem];
	
	[chatController awakeInWindow:[self window]];
	[chatController loadWindowProperties];
}



- (void)selectChatController:(WCPublicChatController *)chatController {
	[_chatTabView selectTabViewItemWithIdentifier:[[chatController connection] identifier]];

	[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
}



- (WCPublicChatController *)selectedChatController {
	NSString			*identifier;
	
	identifier = [[_chatTabView selectedTabViewItem] identifier];
	
	return [_chatControllers objectForKey:identifier];
}



- (WCPublicChatController *)chatControllerForConnectionIdentifier:(NSString *)identifier {
	return [_chatControllers objectForKey:identifier];
}



- (NSArray *)chatControllers {
	return [_chatControllers allValues];
}

@end
