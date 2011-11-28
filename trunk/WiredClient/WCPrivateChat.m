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
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCUser.h"

@interface WCPrivateChat(Private)

- (id)_initPrivateChatWithConnection:(WCServerConnection *)connection chatID:(WCChatID)cid inviteUser:(WCUser *)user;

@end


@implementation WCPrivateChat(Private)

- (id)_initPrivateChatWithConnection:(WCServerConnection *)connection chatID:(WCChatID)cid inviteUser:(WCUser *)user {
	self = [super initChatWithConnection:connection
						   windowNibName:@"PrivateChat"
									name:NSLS(@"Private Chat", @"Chat window title")];
	
	[self setReleasedWhenClosed:YES];
	
	_cid = cid;
	_user = [user retain];

	if([self chatID] == 0) {
		[[self connection] addObserver:self
							  selector:@selector(privateChatReceivedCreate:)
								  name:WCPrivateChatReceivedCreate];
	}

	[[self connection] addObserver:self
						  selector:@selector(privateChatReceivedDecline:)
							  name:WCPrivateChatReceivedDecline];
	
	return self;
}

@end


@implementation WCPrivateChat

+ (id)privateChatWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:NULL] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection chatID:(WCChatID)cid {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:cid inviteUser:NULL] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection inviteUser:(WCUser *)user {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:user] autorelease];
}



+ (id)privateChatWithConnection:(WCServerConnection *)connection chatID:(WCChatID)cid inviteUser:(WCUser *)user {
	return [[[self alloc] _initPrivateChatWithConnection:connection chatID:0 inviteUser:user] autorelease];
}



#pragma mark -

- (void)dealloc {
	[_user release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Private Chat"];

	[[self window] setTitle:[_connection name] withSubtitle:[self name]];

	[_userListTableView registerForDraggedTypes:[NSArray arrayWithObject:WCUserPboardType]];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_connection sendCommand:WCLeaveCommand withArgument:[NSSWF:@"%u", [self chatID]]];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[_connection name] withSubtitle:[self name]];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[super connectionWillTerminate:notification];

	[self close];
}



- (void)privateChatReceivedCreate:(NSNotification *)notification {
	NSString	*cid;
	NSArray		*fields;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	_cid	= [cid unsignedIntValue];
	
	[[self connection] removeObserver:self name:WCPrivateChatReceivedCreate];

	[[self connection] sendCommand:WCWhoCommand withArgument:[NSSWF:@"%u", [self chatID]]];

	if(_user) {
		[_connection sendCommand:WCInviteCommand
					withArgument:[NSSWF:@"%u", [_user userID]]
					withArgument:[NSSWF:@"%u", [self chatID]]];

		[_user release];
		_user = NULL;
	}

	[self showWindow:self];
}



- (void)privateChatReceivedDecline:(NSNotification *)notification {
	NSArray		*fields;
	NSString	*uid, *cid;
	WCUser		*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	uid		= [fields safeObjectAtIndex:1];
	
	if([cid unsignedIntValue] != [self chatID])
		return;

	user = [[[self connection] chat] userWithUserID:[uid unsignedIntValue]];
	
	if(!user)
		return;

	[self printEvent:[NSSWF:
		NSLS(@"%@ has declined invitation", @"Private chat decline message (nick)"),
		[user nick]]];
}



- (float)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	if(splitView == _userListSplitView)
		return proposedMax - 64;
	else if(splitView == _chatSplitView)
		return proposedMax - 15;

	return proposedMax;
}



#pragma mark -

- (WCChatID)chatID {
	return _cid;
}



#pragma mark -

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(row >= 0)
		[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSData			*data;
	WCUser			*user;

	pasteboard = [info draggingPasteboard];
	data = [pasteboard dataForType:WCUserPboardType];
	user = [NSUnarchiver unarchiveObjectWithData:data];

	[_connection sendCommand:WCInviteCommand
				withArgument:[NSSWF:@"%u", [user userID]]
				withArgument:[NSSWF:@"%u", [self chatID]]];

	return YES;
}

@end
