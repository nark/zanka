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

#import "NSAlert-WCAdditions.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCTransfers.h"
#import "WCUser.h"

@interface WCPublicChat(Private)

- (id)_initPublicChatWithConnection:(WCServerConnection *)connection;

- (NSToolbar *)_toolbar;

- (void)_updateMessagesIcon;
- (void)_updateNewsIcon;

@end


@implementation WCPublicChat(Private)

- (id)_initPublicChatWithConnection:(WCServerConnection *)connection {
	self = [super initChatWithConnection:connection
						   windowNibName:@"PublicChat"
									name:NSLS(@"Chat", @"Chat window title")];

	[[self connection] addObserver:self
						  selector:@selector(messagesDidAddMessage:)
							  name:WCMessagesDidAddMessage];
	
	[[self connection] addObserver:self
						  selector:@selector(messagesDidReadMessage:)
							  name:WCMessagesDidReadMessage];
	
	[[self connection] addObserver:self
						  selector:@selector(newsDidAddPost:)
							  name:WCNewsDidAddPost];
	
	[[self connection] addObserver:self
						  selector:@selector(newsDidReadPost:)
							  name:WCNewsDidReadPost];
	
	[[self connection] addObserver:self
						  selector:@selector(privateChatReceivedInvite:)
							  name:WCPrivateChatReceivedInvite];
	
	return self;
}



#pragma mark -

- (NSToolbar *)_toolbar {
	NSToolbar		*toolbar;
	NSToolbarItem	*item;
	NSButton		*button;

	_toolbarItems = [[NSMutableDictionary alloc] init];

	// --- news
	item = [NSToolbarItem toolbarItemWithIdentifier:@"News"
											   name:NSLS(@"News", @"News toolbar item")
											content:[NSImage imageNamed:@"News"]
											 target:self
											 action:@selector(news:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- messages
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Messages"
											   name:NSLS(@"Messages", @"Messages toolbar item")
											content:[NSImage imageNamed:@"Messages"]
											 target:self
											 action:@selector(messages:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- files
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Files"
											   name:NSLS(@"Files", @"Files toolbar item")
											content:[NSImage imageNamed:@"Folder"]
											 target:self
											 action:@selector(files:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- search
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Search"
											   name:NSLS(@"Search", @"Search toolbar item")
											content:[NSImage imageNamed:@"Search"]
											 target:self
											 action:@selector(search:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];
	
	// --- transfers
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Transfers"
											   name:NSLS(@"Transfers", @"Transfers toolbar item")
											content:[NSImage imageNamed:@"Transfers"]
											 target:self
											 action:@selector(transfers:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- accounts
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Accounts"
											   name:NSLS(@"Accounts", @"Accounts toolbar item")
											content:[NSImage imageNamed:@"Accounts"]
											 target:self
											 action:@selector(accounts:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- disconnect
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Disconnect"
											   name:NSLS(@"Disconnect", @"Disconnect toolbar item")
											content:[NSImage imageNamed:@"Disconnect"]
											 target:self
											 action:@selector(disconnect:)];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	// --- banner
	button = [[NSButton alloc] init];
	[button setFrame:NSMakeRect(0, 0, 32, 32)];
	[button setBordered:NO];
	[button setImage:[NSImage imageNamed:@"Banner"]];
	item = [NSToolbarItem toolbarItemWithIdentifier:@"Banner"
											   name:NSLS(@"Banner", @"Banner toolbar item")
											content:button
											 target:self
											 action:@selector(banner:)];
	[button release];
	[_toolbarItems setObject:item forKey:[item itemIdentifier]];

	toolbar = [[NSToolbar alloc] initWithIdentifier:[NSString UUIDString]];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];

	return [toolbar autorelease];
}



#pragma mark -

- (void)_updateMessagesIcon {
	NSToolbarItem	*item;

	item = [_toolbarItems objectForKey:@"Messages"];
	[item setImage:[[NSImage imageNamed:@"Messages"] badgedImageWithInt:[[[self connection] messages] numberOfUnreadMessages]]];
}



- (void)_updateNewsIcon {
	NSToolbarItem	*item;
	
	item = [_toolbarItems objectForKey:@"News"];
	[item setImage:[[NSImage imageNamed:@"News"] badgedImageWithInt:[[[self connection] news] numberOfUnreadPosts]]];
}

@end


@implementation WCPublicChat

+ (id)publicChatWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initPublicChatWithConnection:connection] autorelease];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setToolbar:[self _toolbar]];

	[super windowDidLoad];
}



- (BOOL)windowShouldClose:(id)sender {
	if([WCSettings boolForKey:WCConfirmDisconnect] && [[self connection] isConnected]) {
		NSBeginAlertSheet(NSLS(@"Are you sure you want to disconnect?", @"Disconnect dialog title"),
						  NSLS(@"Disconnect", @"Disconnect dialog button"),
						  NSLS(@"Cancel", @"Disconnect dialog button title"),
						  NULL,
						  [self window],
						  self,
						  @selector(disconnectSheetDidEnd:returnCode:contextInfo:),
						  NULL,
						  NULL,
						  NSLS(@"Disconnecting will close any ongoing file transfers.", @"Disconnect dialog description"));

		return NO;
	}

	return YES;
}



- (void)windowWillClose:(NSNotification *)notification {
	[[self connection] terminate];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCChatWindow"] restoreSize:YES visibility:![self isHidden]];
	
	[super windowTemplateShouldLoad:windowTemplate];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCChatWindow"];
	
	[super windowTemplateShouldSave:windowTemplate];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	return [_toolbarItems objectForKey:identifier];
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"News",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Disconnect",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"News",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		@"Disconnect",
		@"Banner",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)connectionDidClose:(NSNotification *)notification {
	WCError		*error;
	
	[[self window] setTitle:[[self connection] name] withSubtitle:[NSSWF:@"%@ %C %@",
		NSLS(@"Chat", @"Chat window title"),
		0x2014,
		NSLS(@"Disconnected", "Chat window title")]];
	
	if(![[self connection] isReconnecting]) {
		error = [[notification userInfo] objectForKey:WCErrorKey];
		
		if(!error)
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientServerDisconnected];
		
		if([[self window] isMiniaturized])
			[self showWindow:self];
		
		if([[self window] isVisible]) {
			[[NSNotificationCenter defaultCenter] postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsError];
			[[error alert] beginSheetModalForWindow:[self window]];
		}
	}
	
	[self validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[_userListTableView setDataSource:NULL];

	[self autorelease];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[super serverConnectionLoggedIn:notification];

	[self showWindow:self];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	NSToolbarItem	*item;

	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];

	item = [_toolbarItems objectForKey:@"Banner"];
	[item setLabel:[[self connection] name]];
	[item setPaletteLabel:[[self connection] name]];
	[item setToolTip:[[self connection] name]];
}




- (void)serverConnectionBannerDidChange:(NSNotification *)notification {
	NSImage				*image;
	NSToolbarItem		*item;

	image = [[[self connection] server] banner];

	if(image) {
		item = [_toolbarItems objectForKey:@"Banner"];
		[item setImage:image];

		if([image size].width <= 200.0 && [image size].height <= 32.0) {
			[item setMinSize:[image size]];
			[item setMaxSize:[image size]];
		} else {
			[item setMinSize:NSMakeSize(32.0 * ([image size].width / [image size].height), 32.0)];
			[item setMaxSize:NSMakeSize(32.0 * ([image size].width / [image size].height), 32.0)];
		}
	}
}



- (void)privateChatReceivedInvite:(NSNotification *)notification {
	NSEnumerator	*enumerator;
	NSArray			*fields;
	NSString		*uid, *cid;
	NSString		*title, *description;
	NSPanel			*panel;
	NSControl		*control;
	WCUser			*user;
	int				i = 0;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	uid		= [fields safeObjectAtIndex:1];

	user = [self userWithUserID:[uid intValue]];

	if(!user || [user isIgnored])
		return;

	title = [NSSWF:
		NSLS(@"%@ has invited you to a private chat.", @"Private chat invite dialog title (nick)"),
		[user nick]];
	description	= [NSSWF:
		NSLS(@"Join to open a separate private chat with %@.", @"Private chat invite dialog description (nick)"),
		[user nick]];
	panel = NSGetAlertPanel(title, description,
							NSLS(@"Join", @"Private chat invite button title"),
							NSLS(@"Ignore", @"Private chat invite button title"),
							NSLS(@"Decline", @"Private chat invite button title"));

	enumerator = [[[panel contentView] subviews] objectEnumerator];

	while((control = [enumerator nextObject])) {
		if([control isKindOfClass:[NSButton class]]) {
			[control setTarget:self];
			[control setTag:[cid intValue]];

			switch(i++) {
				case 0:
					[control setAction:@selector(joinChat:)];
					break;

				case 1:
					[control setAction:@selector(ignoreChat:)];
					break;

				case 2:
					[control setAction:@selector(declineChat:)];
					break;
			}
		}
	}

	[panel makeKeyAndOrderFront:self];
}



- (void)messagesDidAddMessage:(NSNotification *)notification {
	[self performSelector:@selector(_updateMessagesIcon) withObject:NULL afterDelay:0.0];
}



- (void)messagesDidReadMessage:(NSNotification *)notification {
	[self performSelector:@selector(_updateMessagesIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidAddPost:(NSNotification *)notification {
	[self performSelector:@selector(_updateNewsIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidReadPost:(NSNotification *)notification {
	[self performSelector:@selector(_updateNewsIcon) withObject:NULL afterDelay:0.0];
}



- (void)disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[self close];
}



- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 176;
	else if(splitView == _chatSplitView)
		return proposedMax - 15;

	return proposedMax;
}



#pragma mark -

- (void)validate {
	int			row;
	BOOL		connected;

	row = [_userListTableView selectedRow];
	connected = [[self connection] isConnected];

	if(row < 0) {
		[_privateChatButton setEnabled:NO];
		[_banButton setEnabled:NO];
		[_kickButton setEnabled:NO];
	} else {
		[_privateChatButton setEnabled:connected];
		[_kickButton setEnabled:([[[self connection] account] kickUsers] && connected)];
		[_banButton setEnabled:([[[self connection] account] banUsers] && connected)];
	}

	[super validate];
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	BOOL		connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(startPrivateChat:))
		return connected;
	else if(selector == @selector(kick:))
		return ([[[self connection] account] kickUsers] && connected);
	else if(selector == @selector(ban:))
		return ([[[self connection] account] banUsers] && connected);
	else if(selector == @selector(setTopic:))
		return ([[[self connection] account] setTopic] && connected);

	return [super validateMenuItem:item];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	SEL			selector;
	
	selector = [item action];
	
	if(selector == @selector(disconnect:))
		return [NSApp isActive];
	else if(selector == @selector(files:))
		return [[self connection] isConnected];

	return YES;
}



#pragma mark -

- (IBAction)startPrivateChat:(id)sender {
	[WCPrivateChat privateChatWithConnection:[self connection] inviteUser:[self selectedUser]];

	[[self connection] sendCommand:WCPrivateChatCommand];
}



- (IBAction)ban:(id)sender {
	[NSApp beginSheet:_banMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(banSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self selectedUser] retain]];
}



- (void)banSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCUser		*user = (WCUser *) contextInfo;

	if(returnCode == NSRunStoppedResponse) {
		[[self connection] sendCommand:WCBanCommand
						  withArgument:[NSSWF:@"%u", [user userID]]
						  withArgument:[_banMessageTextField stringValue]];
	}

	[user release];

	[_banMessagePanel close];
	[_banMessageTextField setStringValue:@""];
}



- (IBAction)kick:(id)sender {
	[NSApp beginSheet:_kickMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(kickSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self selectedUser] retain]];
}



- (void)kickSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCUser		*user = (WCUser *) contextInfo;

	if(returnCode == NSRunStoppedResponse) {
		[[self connection] sendCommand:WCKickCommand
						  withArgument:[NSSWF:@"%u", [user userID]]
						  withArgument:[_kickMessageTextField stringValue]];
	}

	[user release];

	[_kickMessagePanel close];
	[_kickMessageTextField setStringValue:@""];
}



#pragma mark -

- (void)joinChat:(id)sender {
	WCPrivateChat	*chat;
	unsigned int	cid;

	cid = [sender tag];
	chat = [WCPrivateChat privateChatWithConnection:[self connection] chatID:cid];
	[chat showWindow:self];

	[[self connection] sendCommand:WCJoinCommand withArgument:[NSSWF:@"%u", cid]];
	[[self connection] sendCommand:WCWhoCommand withArgument:[NSSWF:@"%u", cid]];
	
	[[sender window] orderOut:self];
	NSReleaseAlertPanel([sender window]);
}



- (void)declineChat:(id)sender {
	[[self connection] sendCommand:WCDeclineCommand withArgument:[NSSWF:@"%u", [sender tag]]];

	[[sender window] orderOut:self];
	NSReleaseAlertPanel([sender window]);
}



- (void)ignoreChat:(id)sender {
	[[sender window] orderOut:self];

	NSReleaseAlertPanel([sender window]);
}



- (void)banner:(id)sender {
	[[[self connection] serverInfo] showWindow:self];
}

@end
