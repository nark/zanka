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

#import "NSAlert-WCAdditions.h"
#import "WCConversation.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCStats.h"
#import "WCUser.h"

static NSInteger _WCMessagesCompareMessages(id, id, void *);


static NSInteger _WCMessagesCompareMessages(id message1, id message2, void *contextInfo) {
	NSComparisonResult	result;
	
	result = [message1 compareType:message2];
	
	if(result != NSOrderedSame)
		return result;
	
	return (NSComparisonResult) [message1 performSelector:(SEL) contextInfo withObject:message2];
}



@interface WCMessages(Private)

- (id)_initMessagesWithConnection:(WCServerConnection *)connection;

- (void)_showDialogForMessage:(WCMessage *)message;
- (NSString *)_stringForMessageString:(NSString *)string;

- (void)_update;
- (void)_validate;

- (NSArray *)_conversationsForType:(WCMessageType)type;
- (NSArray *)_messagesForType:(WCMessageType)type;
- (NSArray *)_unreadMessagesForType:(WCMessageType)type;
- (NSArray *)_messagesForConversation:(WCConversation *)conversation unreadOnly:(BOOL)unreadOnly;
- (NSArray *)_messagesSortedForView;
- (id)_selectedConversation;
- (WCMessage *)_selectedMessage;
- (WCMessage *)_selectedMessageForTraversing;
- (WCMessage *)_messageAtIndex:(NSUInteger)index;
- (void)_selectMessage:(WCMessage *)message;
- (SEL)_sortSelector;
- (void)_readMessages;
- (void)_removeAllMessages;
- (void)_removeAllConversations;

@end


@implementation WCMessages(Private)

- (id)_initMessagesWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Messages"
								   name:NSLS(@"Messages", @"Messages window title")
							 connection:connection];

	_titles = [[NSMutableArray alloc] init];
	[_titles addObject:NSLS(@"Conversations", @"Messages item")];
	[_titles addObject:NSLS(@"Broadcasts", @"Messages item")];

	_allConversations	= [[NSMutableArray alloc] init];
	_conversations		= [[NSMutableDictionary alloc] init];
	_allMessages		= [[NSMutableArray alloc] init];
	_shownMessages		= [[NSMutableArray alloc] init];
	_conversationIcon	= [[NSImage imageNamed:@"Conversation"] retain];
	
	_messageFilter	= [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	_userFilter		= [[WITextFilter alloc] initWithSelectors:@selector(filterWiredSmallSmilies:), 0];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[self connection] addObserver:self
						  selector:@selector(messagesReceivedMessage:)
							  name:WCMessagesReceivedMessage];

	[[self connection] addObserver:self
						  selector:@selector(messagesReceivedBroadcast:)
							  name:WCMessagesReceivedBroadcast];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_showDialogForMessage:(WCMessage *)message {
	NSAlert		*alert;
	NSString	*title, *nick, *server, *time;
	
	nick	= [message userNick];
	server	= [[self connection] name];
	time	= [_dialogDateFormatter stringFromDate:[message date]];
	
	if([message type] == WCMessagePrivateMessage)
		title = [NSSWF:NSLS(@"Private message from %@ on %@ at %@", @"Message dialog title (nick, server, time)"), nick, server, time];
	else
		title = [NSSWF:NSLS(@"Broadcast from %@ on %@ at %@", @"Broadcast dialog title (nick, server, time)"), nick, server, time];
	
	alert = [NSAlert alertWithMessageText:title
							defaultButton:nil
						  alternateButton:nil
							  otherButton:nil
				informativeTextWithFormat:@"%@", [message message]];
	
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runNonModal];
	
	[message setRead:YES];
}



- (NSString *)_stringForMessageString:(NSString *)string {
	NSString	*command, *argument;
	NSRange		range;
	
	range = [string rangeOfString:@" "];
	
	if(range.location == NSNotFound) {
		command = string;
		argument = @"";
	} else {
		command = [string substringToIndex:range.location];
		argument = [string substringFromIndex:range.location + 1];
	}
	
	if([command isEqualToString:@"/exec"] && [argument length] > 0)
		return [WCChat outputForShellCommand:argument];
	else if([command isEqualToString:@"/stats"])
		return [[WCStats stats] stringValue];
	
	return string;
}



#pragma mark -

- (void)_update {
	[_messageTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]]];
	[_messageTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_messageTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesBackgroundColor]]];
	[_messageTextView setNeedsDisplay:YES];

	[_messageTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];
	
	[_replyTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]]];
	[_replyTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_replyTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesBackgroundColor]]];
	[_replyTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_replyTextView setNeedsDisplay:YES];

	[_broadcastTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesFont]]];
	[_broadcastTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_broadcastTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesBackgroundColor]]];
	[_broadcastTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesTextColor]]];
	[_broadcastTextView setNeedsDisplay:YES];
	
	[_messageTextView setString:[[_messageTextView textStorage] string] withFilter:_messageFilter];

	[_messagesTableView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCMessagesListFont]]];
	[_messagesTableView setUsesAlternatingRowBackgroundColors:[[WCSettings settings] boolForKey:WCMessagesListAlternateRows]];
	[_messagesTableView setNeedsDisplay:YES];
}



- (void)_validate {
	[_clearButton setEnabled:([_allMessages count] > 0)];
	[_replyButton setEnabled:([self _selectedMessage] != NULL && [[self connection] isConnected])];
}



#pragma mark -

- (NSArray *)_conversationsForType:(WCMessageType)type {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCConversation	*conversation;
	
	array = [NSMutableArray array];
	enumerator = [_allConversations objectEnumerator];
	
	while((conversation = [enumerator nextObject])) {
		if([conversation type] == type)
			[array addObject:conversation];
	}
	
	[array reverse];
	
	return array;
}



- (NSArray *)_messagesForType:(WCMessageType)type {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCMessage		*message;
	
	array = [NSMutableArray array];
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if(type == [message type])
			[array addObject:message];
	}
	
	return array;
}



- (NSArray *)_unreadMessagesForType:(WCMessageType)type {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCMessage		*message;
	
	array = [NSMutableArray array];
	enumerator = [[self _messagesForType:type] objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if(![message isRead])
			[array addObject:message];
	}
	
	return array;
}



- (NSArray *)_messagesForConversation:(WCConversation *)conversation unreadOnly:(BOOL)unreadOnly {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCMessage		*message;
	WCMessageType	type;
	
	array = [NSMutableArray array];
	type = [conversation type];
	enumerator = [unreadOnly ? [self _unreadMessagesForType:type] : [self _messagesForType:type] objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if([[message conversation] isEqual:conversation])
			[array addObject:message];
	}
	
	return array;
}



- (NSArray *)_messagesSortedForView {
	NSMutableArray		*array;
	NSMutableArray		*messages;
	WISortOrder			order;
	
	array = [NSMutableArray array];
	order = [_messagesTableView sortOrder];
	
	messages = [[[self _messagesForType:WCMessagePrivateMessage] mutableCopy] autorelease];
	[messages sortUsingFunction:_WCMessagesCompareMessages context:[self _sortSelector]];
	
	if(order == WISortDescending)
		[messages reverse];
	
	[array addObjectsFromArray:messages];
	
	messages = [[[self _messagesForType:WCMessageBroadcast] mutableCopy] autorelease];
	[messages sortUsingFunction:_WCMessagesCompareMessages context:[self _sortSelector]];
	
	if(order == WISortDescending)
		[messages reverse];
	
	[array addObjectsFromArray:messages];
	
	return array;
}



- (id)_selectedConversation {
	NSInteger		row;
	
	row = [_conversationsOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_conversationsOutlineView itemAtRow:row];
}



- (WCMessage *)_selectedMessage {
	NSInteger		row;
	
	row = [_messagesTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _messageAtIndex:row];
}



- (WCMessage *)_selectedMessageForTraversing {
	NSArray			*messages;
	WCConversation	*conversation;
	WCMessage		*message;
	WCMessageType	type;
	id				item;
	
	message = [self _selectedMessage];
	
	if(message)
		return message;
	
	type = WCMessagePrivateMessage;
	item = [self _selectedConversation];
	
	if(item) {
		if([item isKindOfClass:[NSString class]]) {
			if([_titles indexOfObject:item] == 0)
				type = WCMessagePrivateMessage;
			else if([_titles indexOfObject:item] == 1)
				type = WCMessageBroadcast;
		}
		else if([item isKindOfClass:[WCConversation class]]) {
			conversation = item;
			type = [conversation type];
		}
	}
	
	messages = [self _messagesForType:type];
	
	if([messages count] > 0)
		return [messages objectAtIndex:0];
	
	type = (type == WCMessagePrivateMessage) ? WCMessageBroadcast : WCMessagePrivateMessage;
	
	messages = [self _messagesForType:type];
	
	if([messages count] > 0)
		return [messages objectAtIndex:0];
	
	return NULL;
}



- (WCMessage *)_messageAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [_shownMessages count] - index - 1
		: index;

	return [_shownMessages objectAtIndex:i];
}



- (void)_selectMessage:(WCMessage *)message {
	WCConversation		*conversation;
	NSUInteger			i, index;
	NSInteger			row;
	
	conversation = [message conversation];
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row < 0)
		return;
	
	[_conversationsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	
	index = [_shownMessages indexOfObject:message];
	
	if(index == NSNotFound)
		return;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [_shownMessages count] - index - 1
		: index;

	[_messagesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
}



- (void)_sortMessages {
	[_shownMessages sortUsingSelector:[self _sortSelector]];
}



- (SEL)_sortSelector {
	NSTableColumn	*tableColumn;
	
	tableColumn = [_messagesTableView highlightedTableColumn];
	
	if(tableColumn == _userTableColumn)
		return @selector(compareUser:);
	else if(tableColumn == _timeTableColumn)
		return @selector(compareDate:);

	return @selector(compareDate:);
}



- (void)_readMessages {
	NSEnumerator	*enumerator;
	WCMessage		*message;
	
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if(![message isRead]) {
			[message setRead:YES];
			
			_unread--;
			
			[[self connection] postNotificationName:WCMessagesDidReadMessage object:[self connection]];
		}
	}
}



- (void)_removeAllMessages {
	[_allMessages removeAllObjects];
	[_shownMessages removeAllObjects];
	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
}



- (void)_removeAllConversations {
	[_allConversations removeAllObjects];
	[_conversations removeAllObjects];
	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
}

@end


@implementation WCMessages

+ (id)messagesWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initMessagesWithConnection:connection] autorelease];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_titles release];
	[_allConversations release];
	[_conversations release];
	[_allMessages release];
	[_shownMessages release];
	
	[_messageFilter release];
	[_userFilter release];
	[_conversationIcon release];
	
	[_messageUser release];
	
	[_tableDateFormatter release];
	[_dialogDateFormatter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WIIconCell	*iconCell;
	
	iconCell = [[WIIconCell alloc] init];
	[_messagesTableColumn setDataCell:iconCell];
	[iconCell release];

	[_messagesTableView setTarget:self];
	[_messagesTableView setDoubleAction:@selector(reply:)];
	[_messagesTableView setAllowsUserCustomization:YES];
	[_messagesTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_messagesTableView setDefaultSortOrder:WISortAscending];
	[_conversationsOutlineView expandItem:[_titles objectAtIndex:0]];
	[_conversationsOutlineView expandItem:[_titles objectAtIndex:1]];
	
	[_messageTextView setEditable:NO];
	[_messageTextView setUsesFindPanel:YES];
	
	_tableDateFormatter = [[WIDateFormatter alloc] init];
	[_tableDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_tableDateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_tableDateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_dialogDateFormatter = [[WIDateFormatter alloc] init];
	[_dialogDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	[self _update];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCMessagesWindow"] restoreSize:YES visibility:![self isHidden]];
	[_conversationsSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCMessagesConversationsSplitView"]];
	[_messagesSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCMessagesMessagesSplitView"]];
	[_messagesTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCMessagesMessagesTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCMessagesWindow"];
	[windowTemplate setObject:[_conversationsSplitView propertiesDictionary] forKey:@"WCMessagesConversationsSplitView"];
	[windowTemplate setObject:[_messagesSplitView propertiesDictionary] forKey:@"WCMessagesMessagesSplitView"];
	[windowTemplate setObject:[_messagesTableView propertiesDictionary] forKey:@"WCMessagesMessagesTableView"];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[self _readMessages];
	
	[super connectionWillTerminate:notification];

	[self close];
	[self autorelease];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[self _validate];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	NSWindow	*sheet;
	
	sheet = [[self window] attachedSheet];
	
	if(sheet == _replyPanel)
		_hiddenMessage = [[_replyTextView string] copy];
	else if(sheet == _broadcastPanel)
		_hiddenBroadcast = [[_broadcastTextView string] copy];
	
	[super serverConnectionShouldHide:notification];
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	[super serverConnectionShouldUnhide:notification];
	
	if(_hiddenMessage) {
		[self showPrivateMessageToUser:_messageUser message:_hiddenMessage];
		
		[_hiddenMessage release];
		_hiddenMessage = NULL;
	}
	else if(_hiddenBroadcast) {
		[self showBroadcast:_hiddenBroadcast];
		
		[_hiddenBroadcast release];
		_hiddenBroadcast = NULL;
	}
}



- (void)messagesReceivedMessage:(NSNotification *)notification {
	NSArray			*arguments;
	NSString		*key;
	WCUser			*user;
	WCMessage		*message;
	WCConversation  *conversation;

	arguments		= [[notification userInfo] objectForKey:WCArgumentsKey];
	user			= [[[self connection] chat] userWithUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	
	if(!user || [user isIgnored])
		return;
	
	key				= [WCConversation keyForType:WCMessagePrivateMessage user:user connection:[self connection]];
	conversation	= [_conversations objectForKey:key];
	
	if(!conversation) {
		conversation = [WCConversation messageConversationWithUser:user connection:[self connection]];
		[_allConversations addObject:conversation];
		[_conversations setObject:conversation forKey:[conversation key]];
	}

	message			= [WCMessage messageWithArguments:arguments user:user conversation:conversation];

	[_allMessages addObject:message];
	
	[_conversationsOutlineView reloadData];
	[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
	
	if([[[WCSettings settings] eventForTag:WCEventsMessageReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];
	else
		_unread++;

	[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesReceived];

	[[self connection] postNotificationName:WCMessagesDidAddMessage object:message];

	[[self connection] triggerEvent:WCEventsMessageReceived info1:message];
	
	[self _validate];
}



- (void)messagesReceivedBroadcast:(NSNotification *)notification {
	NSArray			*arguments;
	NSString		*key;
	WCUser			*user;
	WCMessage		*message;
	WCConversation  *conversation;

	arguments		= [[notification userInfo] objectForKey:WCArgumentsKey];
	user			= [[[self connection] chat] userWithUserID:[[arguments safeObjectAtIndex:0] unsignedIntValue]];
	
	if(!user || [user isIgnored])
		return;

	key				= [WCConversation keyForType:WCMessageBroadcast user:user connection:[self connection]];
	conversation	= [_conversations objectForKey:key];
	
	if(!conversation) {
		conversation = [WCConversation broadcastConversationWithUser:user connection:[self connection]];
		[_allConversations addObject:conversation];
		[_conversations setObject:conversation forKey:[conversation key]];
	}

	message			= [WCMessage broadcastWithArguments:arguments user:user conversation:conversation];
	
	[_allMessages addObject:message];

	[_conversationsOutlineView reloadData];
	[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
	
	if([[[WCSettings settings] eventForTag:WCEventsBroadcastReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];
	else
		_unread++;

	[[self connection] postNotificationName:WCMessagesDidAddMessage object:message];

	[[self connection] triggerEvent:WCEventsBroadcastReceived info1:message];
	
	[self _validate];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _conversationsSplitView) {
		NSSize		size, leftSize, rightSize;
		
		size = [_conversationsSplitView frame].size;
		leftSize = [_conversationsView frame].size;
		leftSize.height = size.height;
		rightSize.height = size.height;
		rightSize.width = size.width - [_conversationsSplitView dividerThickness] - leftSize.width;
		
		[_conversationsView setFrameSize:leftSize];
		[_messagesView setFrameSize:rightSize];
	}
	else if(splitView == _messagesSplitView) {
		NSSize		size, topSize, bottomSize;
		
		size = [_messagesSplitView frame].size;
		topSize = [_messageListView frame].size;
		topSize.width = size.width;
		bottomSize.width = size.width;
		bottomSize.height = size.height - [_messagesSplitView dividerThickness] - topSize.height;
		
		[_messageListView setFrameSize:topSize];
		[_messageView setFrameSize:bottomSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	BOOL		value = NO;

	if(selector == @selector(insertNewline:)) {
		if([[NSApp currentEvent] character] == NSEnterCharacter) {
			[self submitSheet:textView];

			value = YES;
		}
	}

	return value;
}



#pragma mark -

- (void)showNextUnreadMessage {
	NSArray			*messages;
	WCMessage		*message, *selectedMessage;
	NSUInteger		i, index, count;
	
	message = [self _selectedMessageForTraversing];
	
	if(!message)
		return;
	
	messages = [self _messagesSortedForView];
	selectedMessage = [self _selectedMessage];
	
	if(!selectedMessage || message == selectedMessage) {
		index = [messages indexOfObject:message];
		
		if(index == NSNotFound)
			return;
		
		count = [messages count];
		i = (index < count - 1) ? index + 1 : 0;
		
		do {
			message = [messages objectAtIndex:i];
			
			if(![message isRead])
				break;
			
			message = NULL;
			
			i = (i < count - 1) ? i + 1 : 0;
		} while(i != index);
	}
	
	if(message)
		[self _selectMessage:message];
}



- (void)showPreviousUnreadMessage {
	NSArray			*messages;
	WCMessage		*message;
	NSUInteger		i, index, count;
	
	message = [self _selectedMessageForTraversing];
	
	if(!message)
		return;
	
	messages = [self _messagesSortedForView];

	if(message == [self _selectedMessage]) {
		index = [messages indexOfObject:message];
		
		if(index == NSNotFound)
			return;
		
		count = [messages count];
		i = (index > 0) ? index - 1 : count - 1;
		
		do {
			message = [messages objectAtIndex:i];
			
			if(![message isRead])
				break;
			
			message = NULL;
			
			i = (i > 0) ? i - 1 : count - 1;
		} while(i != index);
	}

	[self _selectMessage:message];
}



- (void)showPrivateMessageToUser:(WCUser *)user {
	[self showPrivateMessageToUser:user message:@""];
}



- (void)showPrivateMessageToUser:(WCUser *)user message:(NSString *)message {
	[user retain];
	[_messageUser release];
	_messageUser = user;
	
	[_userTextField setStringValue:[_messageUser nick]];

	[_replyTextView setString:message];
	
	[self showWindow:self];
	
	[NSApp beginSheet:_replyPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(replySheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)showBroadcast:(NSString *)broadcast {
	[self showWindow:self];

	[_broadcastTextView setString:broadcast];
	
	[NSApp beginSheet:_broadcastPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(broadcastSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (NSUInteger)numberOfUnreadMessages {
	return _unread;
}



#pragma mark -

- (IBAction)broadcast:(id)sender {
	[self showBroadcast:@""];
}



- (void)broadcastSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[[self connection] sendCommand:WCBroadcastCommand withArgument:[self _stringForMessageString:[_broadcastTextView string]]];

	[_broadcastPanel close];
	[_broadcastTextView setString:@""];
}



- (IBAction)reply:(id)sender {
	WCMessage   *message;
	WCUser		*user;
	WCError		*error;
	
	message = [self _selectedMessage];
	
	if(!message)
		return;
	
	user = [[[self connection] chat] userWithUserID:[message userID]];
	
	if(user) {
		[self showPrivateMessageToUser:user];
	} else {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientClientNotFound];
		[[self connection] triggerEvent:WCEventsError info1:error];
		[[error alert] beginSheetModalForWindow:[self window]];
	}
}



- (void)replySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSString		*key;
	WCMessage		*message;
	WCConversation  *conversation;
	
	if(returnCode == NSAlertDefaultReturn) {
		key				= [WCConversation keyForType:WCMessagePrivateMessage user:_messageUser connection:[self connection]];
		conversation	= [_conversations objectForKey:key];
		
		if(!conversation) {
			conversation = [WCConversation messageConversationWithUser:_messageUser connection:[self connection]];
			[_allConversations addObject:conversation];
			[_conversations setObject:conversation forKey:[conversation key]];
		}
		
		message = [WCMessage messageToUser:_messageUser string:[[[_replyTextView string] copy] autorelease] conversation:conversation];

		[_allMessages addObject:message];
		
		[[self connection] sendCommand:WCMessageCommand
						  withArgument:[NSSWF:@"%u", [message userID]]
						  withArgument:[self _stringForMessageString:[message message]]];

		[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesSent];
		
		[_conversationsOutlineView reloadData];
		[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
	}
	
	[_replyPanel close];
	[_replyTextView setString:@""];
}



- (IBAction)clearMessages:(id)sender {
	if([_allMessages count] > 0) {
		NSBeginAlertSheet(NSLS(@"Are you sure you want to clear the message history?", @"Clear messages dialog title"),
						  NSLS(@"Clear", @"Clear messages dialog button"),
						  NSLS(@"Cancel", @"Clear messages dialog button"),
						  NULL,
						  [self window],
						  self,
						  @selector(clearSheetDidEnd:returnCode:contextInfo:),
						  NULL,
						  NULL,
						  NSLS(@"This cannot be undone.", @"Clear messages dialog description"));
	}
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		[self _readMessages];
		
		[self _removeAllMessages];
		[self _removeAllConversations];
		
		[self _validate];
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		return [_titles count];
	
	if([_titles indexOfObject:item] == 0)
		return [[self _conversationsForType:WCMessagePrivateMessage] count];
	else if([_titles indexOfObject:item] == 1)
		return [[self _conversationsForType:WCMessageBroadcast] count];
	
	return 0;
}



- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
	if(!item)
		return [_titles objectAtIndex:index];
	
	if([_titles indexOfObject:item] == 0)
		return [[self _conversationsForType:WCMessagePrivateMessage] objectAtIndex:index];
	else if([_titles indexOfObject:item] == 1)
		return [[self _conversationsForType:WCMessageBroadcast] objectAtIndex:index];
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString			*name = NULL;
	WCConversation		*conversation;
	NSUInteger			count = 0;
	
	if([item isKindOfClass:[NSString class]]) {
		name = item;

		if([_titles indexOfObject:item] == 0)
			count = [[self _unreadMessagesForType:WCMessagePrivateMessage] count];
		else if([_titles indexOfObject:item] == 1)
			count = [[self _unreadMessagesForType:WCMessageBroadcast] count];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		conversation = item;
		name = [conversation userNick];
		count = [[self _messagesForConversation:conversation unreadOnly:YES] count];
	}
	
	if(count > 0)
		name = [name stringByAppendingFormat:@" (%lu)", count];
	
	return [[NSAttributedString attributedStringWithString:name] attributedStringByApplyingFilter:_userFilter];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSImage			*image = NULL;
	NSUInteger		count = 0;
	
	if([item isKindOfClass:[NSString class]]) {
		image = _conversationIcon;

		if([_titles indexOfObject:item] == 0)
			count = [[self _unreadMessagesForType:WCMessagePrivateMessage] count];
		else if([_titles indexOfObject:item] == 1)
			count = [[self _unreadMessagesForType:WCMessageBroadcast] count];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		count = [[self _messagesForConversation:item unreadOnly:YES] count];
		image = NULL;
	}	

	if(count > 0)
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	[cell setImage:image];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	if([_titles containsObject:item])
		return YES;
	
	return NO;
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	NSArray			*messages = NULL;
	id				item;

	item = [self _selectedConversation];

	if([item isKindOfClass:[NSString class]]) {
		if([_titles indexOfObject:item] == 0)
			messages = [self _messagesForType:WCMessagePrivateMessage];
		else if([_titles indexOfObject:item] == 1)
			messages = [self _messagesForType:WCMessageBroadcast];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		messages = [self _messagesForConversation:item unreadOnly:NO];
	}
	
	[_shownMessages setArray:messages];
	[self _sortMessages];
	
	[_messagesTableView reloadData];
	[_messagesTableView deselectAll:self];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownMessages count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	NSString			*string;
	WCMessage			*message;
	
	message = [self _messageAtIndex:row];
	
	if(column == _userTableColumn) {
		if([message direction] == WCMessageTo)
			string = [NSSWF:NSLS(@"To: %@", @"Message to (nick)"), [message userNick]];
		else
			string = [NSSWF:NSLS(@"From: %@", @"Message from (nick)"), [message userNick]];

		return [[NSAttributedString attributedStringWithString:string] attributedStringByApplyingFilter:_userFilter];
	}
	else if(column == _timeTableColumn) {
		return [_tableDateFormatter stringFromDate:[message date]];
	}
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCMessage		*message;
	
	message = [self _messageAtIndex:row];
	
	if(![message isRead])
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_messagesTableView setHighlightedTableColumn:tableColumn];
	[self _sortMessages];
	[_messagesTableView reloadData];
	[[_messagesTableView delegate] tableViewSelectionDidChange:NULL];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	WCMessage   *message;
	
	message = [self _selectedMessage];
	
	if(!message) {
		[_messageTextView setString:@""];
	} else {
		if(![message isRead]) {
			[message setRead:YES];
			[_conversationsOutlineView setNeedsDisplay:YES];
			[_messagesTableView setNeedsDisplay:YES];
			
			_unread--;
		
			[[self connection] postNotificationName:WCMessagesDidReadMessage object:[self connection]];
		}
		
		[_messageTextView setString:[message message] withFilter:_messageFilter];
	}
	
	[self _validate];
}

@end
