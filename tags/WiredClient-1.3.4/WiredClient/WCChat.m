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
#import "WCAccountEditor.h" 
#import "WCAccounts.h" 
#import "WCApplicationController.h" 
#import "WCChat.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCServer.h"
#import "WCStats.h"
#import "WCTopic.h"
#import "WCUser.h"
#import "WCUserCell.h"
#import "WCUserInfo.h"

#define WCPublicChatID				1

#define WCLastChatFormat			@"WCLastChatFormat"
#define WCLastChatEncoding			@"WCLastChatEncoding"


enum _WCChatFormat {
	WCChatPlainText,
	WCChatRTF,
	WCChatRTFD,
};
typedef enum _WCChatFormat			WCChatFormat;


@interface WCChat(Private)

- (void)_update;
- (void)_updateTopic;
- (void)_updateSaveChatForPanel:(NSSavePanel *)savePanel;

- (void)_printString:(NSString *)message;
- (void)_printTimestamp;
- (void)_printUserJoin:(WCUser *)user;
- (void)_printUserLeave:(WCUser *)user;
- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick;
- (void)_printUserChange:(WCUser *)user status:(NSString *)status;
- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message;
- (void)_printUserBan:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message;
- (void)_printChat:(NSString *)chat by:(WCUser *)user;
- (void)_printActionChat:(NSString *)chat by:(WCUser *)user;

- (NSArray *)_commands;
- (BOOL)_runCommand:(NSString *)command;

- (NSString *)_stringByCompletingString:(NSString *)string;
- (NSString *)_stringByDecomposingAttributedString:(NSAttributedString *)attributedString;

- (BOOL)_isHighlightedChat:(NSString *)chat;

@end


@implementation WCChat(Private)

- (void)_update {
	NSFont		*font;
	NSColor		*color;

	font = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatFont]];

	if(![[_chatOutputTextView font] isEqualTo:font]) {
		[_chatOutputTextView setFont:font];
		[_chatInputTextView setFont:font];
		[_setTopicTextView setFont:font];
	}
	
	color = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatBackgroundColor]];

	if(![[_chatOutputTextView backgroundColor] isEqualTo:color]) {
		[_chatOutputTextView setBackgroundColor:color];
		[_chatInputTextView setBackgroundColor:color];
		[_setTopicTextView setBackgroundColor:color];
	}

	color = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatTextColor]];

	if(![[_chatOutputTextView textColor] isEqualTo:color]) {
		[_chatOutputTextView setTextColor:color];
		[_chatInputTextView setTextColor:color];
		[_chatInputTextView setInsertionPointColor:color];
		[_setTopicTextView setTextColor:color];
		[_setTopicTextView setInsertionPointColor:color];

		[_chatOutputTextView setString:[_chatOutputTextView string] withFilter:_chatFilter];
	}
	
	[_chatOutputTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];

	[_userListTableView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatUserListFont]]];
	[_userListTableView setUsesAlternatingRowBackgroundColors:[WCSettings boolForKey:WCChatUserListAlternateRows]];
	
	switch([WCSettings intForKey:WCChatUserListIconSize]) {
		case WCChatUserListIconSizeLarge:
			[_userListTableView setRowHeight:35.0];
			
			[[_nickTableColumn dataCell] setControlSize:NSRegularControlSize];
			break;

		case WCChatUserListIconSizeSmall:
			[_userListTableView setRowHeight:17.0];

			[[_nickTableColumn dataCell] setControlSize:NSSmallControlSize];
			break;
	}
	
	[_chatOutputTextView setNeedsDisplay:YES];
	[_chatInputTextView setNeedsDisplay:YES];
	[_setTopicTextView setNeedsDisplay:YES];
	[_userListTableView setNeedsDisplay:YES];
}



- (void)_updateTopic {
	NSMutableAttributedString	*string;
	
	if(_topic) {
		string = [NSMutableAttributedString attributedStringWithString:[_topic topic]];
		
		[_topicTextField setToolTip:[_topic topic]];
		[_topicTextField setAttributedStringValue:[string attributedStringByApplyingFilter:_topicFilter]];
		[_topicNickTextField setStringValue:[NSSWF:
			NSLS(@"%@ %C %@", @"Chat topic set by (nick, time)"),
			[_topic nick],
			0x2014,
			[_topicDateFormatter stringFromDate:[_topic date]]]];
	} else {
		[_topicTextField setToolTip:NULL];
		[_topicTextField setStringValue:@""];
		[_topicNickTextField setStringValue:@""];
	}
}



- (void)_updateSaveChatForPanel:(NSSavePanel *)savePanel {
	WCChatFormat		format;
	
	format = [_saveChatFileFormatPopUpButton tagOfSelectedItem];
	
	switch(format) {
		case WCChatPlainText:
			[savePanel setRequiredFileType:@"txt"];
			break;
			
		case WCChatRTF:
			[savePanel setRequiredFileType:@"rtf"];
			break;

		case WCChatRTFD:
			[savePanel setRequiredFileType:@"rtfd"];
			break;
	}

	[_saveChatPlainTextEncodingPopUpButton setEnabled:(format == WCChatPlainText)];
}



#pragma mark -

- (void)_printString:(NSString *)string {
	float		position;
	
	position = [[_chatOutputScrollView verticalScroller] floatValue];
	
	if([[_chatOutputTextView textStorage] length] > 0)
		[[[_chatOutputTextView textStorage] mutableString] appendString:@"\n"];
	
	[_chatOutputTextView appendString:string withFilter:_chatFilter];
	
	if(position == 1.0)
		[_chatOutputTextView performSelectorOnce:@selector(scrollToBottom) withObject:NULL afterDelay:0.05];
}



- (void)_printTimestamp {
	NSDate			*date;
	NSTimeInterval	interval;
	
	if(!_timestamp)
		_timestamp = [[NSDate date] retain];
	
	interval = [[WCSettings objectForKey:WCTimestampChatInterval] doubleValue];
	date = [NSDate dateWithTimeIntervalSinceNow:-interval];
	
	if([date compare:_timestamp] == NSOrderedDescending) {
		[self printEvent:[_timestampDateFormatter stringFromDate:[NSDate date]]];
		
		[_timestamp release];
		_timestamp = [[NSDate date] retain];
	}
}



- (void)_printUserJoin:(WCUser *)user {
	[self printEvent:[NSSWF:
		NSLS(@"%@ has joined", @"Client has joined message (nick)"),
		[user nick]]];
}



- (void)_printUserLeave:(WCUser *)user {
	[self printEvent:[NSSWF:
		NSLS(@"%@ has left", @"Client has left message (nick)"),
		[user nick]]];
}



- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick {
	[self printEvent:[NSSWF:
		NSLS(@"%@ is now known as %@", @"Client rename message (oldnick, newnick)"),
		[user nick],
		nick]];
}



- (void)_printUserChange:(WCUser *)user status:(NSString *)status {
	[self printEvent:[NSSWF:
		NSLS(@"%@ changed status to %@", @"Client status changed message (nick, status)"),
		[user nick],
		status]];
}



- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was kicked by %@ (%@)", @"Client kicked message (victim, killer, message)"),
			[victim nick],
			[killer nick],
			message]];
	} else {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was kicked by %@", @"Client kicked message (victim, killer)"),
			[victim nick],
			[killer nick]]];
	}
}



- (void)_printUserBan:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was banned by %@ (%@)", @"Client banned message (victim, killer, message)"),
			[victim nick],
			[killer nick],
			message]];
	} else {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was banned by %@", @"Client banned message (victim, killer)"),
			[victim nick],
			[killer nick]]];
	}
}



- (void)_printChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output, *nick;
	NSInteger	offset, length;
	
	switch([WCSettings intForKey:WCChatStyle]) {
		case WCChatStyleWired:
		default:
			offset = [WCSettings boolForKey:WCTimestampEveryLine] ? WCChatPrepend - 4 : WCChatPrepend;
			nick = [user nick];
			length = offset - [nick length];

			if(length < 0)
				nick = [nick substringToIndex:offset];
			
			output = [NSSWF:NSLS(@"%@: %@", @"Chat message, Wired style (nick, message)"),
				nick, chat];
			
			if(length > 0)
				output = [NSSWF:@"%*s%@", length, " ", output];
			break;
			
		case WCChatStyleIRC:
			output = [NSSWF:NSLS(@"<%@> %@", @"Chat message, IRC style (nick, message)"),
				[user nick], chat];
			break;
	}
	
	if([WCSettings boolForKey:WCTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];

	[self _printString:output];
}



- (void)_printActionChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output;

	switch([WCSettings intForKey:WCChatStyle]) {
		case WCChatStyleWired:
		default:
			output = [NSSWF:NSLS(@" *** %@ %@", @"Action chat message, Wired style (nick, message)"),
				[user nick], chat];
			break;
			
		case WCChatStyleIRC:
			output = [NSSWF:NSLS(@" * %@ %@", @"Action chat message, IRC style (nick, message)"),
				[user nick], chat];
			break;
	}

	if([WCSettings boolForKey:WCTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];
	
	[self _printString:output];
}



#pragma mark -

- (NSArray *)_commands {
	return [NSArray arrayWithObjects:
		@"/me",
		@"/exec",
		@"/nick",
		@"/status",
		@"/stats",
		@"/clear",
		@"/topic",
		@"/broadcast",
		@"/ping",
		NULL];
}



- (BOOL)_runCommand:(NSString *)string {
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
	
	if([command isEqualToString:@"/me"] && [argument length] > 0) {
		if([argument length] > WCChatLimit)
			argument = [argument substringToIndex:WCChatLimit];
		
		[[self connection] sendCommand:WCMeCommand
						  withArgument:[NSSWF:@"%u", [self chatID]]
						  withArgument:argument];
		
		[[WCStats stats] addUnsignedLongLong:[argument length] forKey:WCStatsChat];
		
		return YES;
	}
	else if([command isEqualToString:@"/exec"] && [argument length] > 0) {
		NSString			*output;
		
		output = [[self class] outputForShellCommand:argument];
		
		if(output && [output length] > 0) {
			if([output length] > WCChatLimit)
				output = [output substringToIndex:WCChatLimit];

			[[self connection] sendCommand:WCSayCommand
							  withArgument:[NSSWF:@"%u", [self chatID]]
							  withArgument:output];
		}
		
		return YES;
	}
	else if(([command isEqualToString:@"/nick"] ||
			 [command isEqualToString:@"/n"]) && [argument length] > 0) {
		[[self connection] sendCommand:WCNickCommand withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/status"] || [command isEqualToString:@"/s"]){
		[[self connection] sendCommand:WCStatusCommand withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/stats"]) {
		[[self connection] sendCommand:WCSayCommand
						  withArgument:[NSSWF:@"%u", [self chatID]]
						  withArgument:[[WCStats stats] stringValue]];
		
		return YES;
	}
	else if([command isEqualToString:@"/clear"]) {
		[[[_chatOutputTextView textStorage] mutableString] setString:@""];
		
		return YES;
	}
	else if([command isEqualToString:@"/topic"]) {
		[[self connection] sendCommand:WCTopicCommand
						  withArgument:[NSSWF:@"%u", [self chatID]]
						  withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/broadcast"] && [argument length] > 0) {
		[[self connection] sendCommand:WCBroadcastCommand withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/ping"]) {
		if(!_receivingPings) {
			[[self connection] addObserver:self
								  selector:@selector(serverConnectionReceivedPing:)
									  name:WCServerConnectionReceivedPing];
			
			_receivingPings = YES;
		}
		
		_pingInterval = [NSDate timeIntervalSinceReferenceDate];
		
		[[self connection] sendCommand:WCPingCommand];
		
		return YES;
	}

	return NO;
}



#pragma mark -

- (NSString *)_stringByCompletingString:(NSString *)string {
	NSEnumerator	*enumerator, *setEnumerator;
	NSArray			*nicks, *commands, *set, *matchingSet = NULL;
	NSString		*match, *prefix = NULL;
	NSUInteger		matches = 0;
	
	nicks = [self nicks];
	commands = [self _commands];
	enumerator = [[NSArray arrayWithObjects:nicks, commands, NULL] objectEnumerator];
	
	while((set = [enumerator nextObject])) {
		setEnumerator = [set objectEnumerator];
		
		while((match = [setEnumerator nextObject])) {
			if([match rangeOfString:string options:NSCaseInsensitiveSearch].location == 0) {
				if(matches == 0) {
					prefix = match;
					matches = 1;
				} else {
					prefix = [prefix commonPrefixWithString:match options:NSCaseInsensitiveSearch];
				
					if([prefix length] < [match length])
						matches++;
				}
				
				matchingSet = set;
			}
		}
	}
	
	if(matches > 1)
		return prefix;

	if(matches == 1) {
		if(matchingSet == nicks) {
			return [prefix stringByAppendingString:
				[WCSettings objectForKey:WCTabCompleteNicksString]];
		}
		else if(matchingSet == commands) {
			return [prefix stringByAppendingString:@" "];
		}
	}
	
	return string;
}



- (NSString *)_stringByDecomposingAttributedString:(NSAttributedString *)attributedString {
	if(![attributedString containsAttachments])
		return [attributedString string];
	
	return [[attributedString attributedStringByReplacingAttachmentsWithStrings] string];
}



#pragma mark -

- (BOOL)_isHighlightedChat:(NSString *)chat {
	NSEnumerator		*enumerator;
	NSDictionary		*highlight;
	
	enumerator = [[WCSettings objectForKey:WCHighlights] objectEnumerator];
	
	while((highlight = [enumerator nextObject])) {
		if([chat rangeOfString:[highlight objectForKey:WCHighlightsPattern] options:NSCaseInsensitiveSearch].location != NSNotFound)
			return YES;
	}
	
	return NO;
}

@end


@implementation WCChat

+ (NSString *)outputForShellCommand:(NSString *)command {
	NSTask				*task;
	NSPipe				*pipe;
	NSFileHandle		*fileHandle;
	NSDictionary		*environment;
	NSData				*data;
	double				timeout = 5.0;
	
	pipe = [NSPipe pipe];
	fileHandle = [pipe fileHandleForReading];
	
	environment	= [NSDictionary dictionaryWithObject:@"/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
											  forKey:@"PATH"];
	
	task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", command, NULL]];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task setEnvironment:environment];
	[task launch];
	
	while([task isRunning]) {
		usleep(100000);
		timeout -= 0.1;
		
		if(timeout <= 0.0) {
			[task terminate];
			
			break;
		}
	}
	
	data = [fileHandle readDataToEndOfFile];
	
	return [NSString stringWithData:data encoding:NSUTF8StringEncoding];
}



#pragma mark -

+ (id)allocWithZone:(NSZone *)zone {
	if([self isEqual:[WCChat class]]) {
		NSLog(@"*** -[%@ allocWithZone:]: attempt to instantiate abstract class", self);

		return NULL;
	}

	return [super allocWithZone:zone];
}



- (id)initChatWithConnection:(WCServerConnection *)connection windowNibName:(NSString *)windowNibName name:(NSString *)name {
	self = [super initWithWindowNibName:windowNibName name:name connection:connection];

	_commandHistory				= [[NSMutableArray alloc] init];
	_users						= [[NSMutableDictionary alloc] init];
	_allUsers					= [[NSMutableArray alloc] init];
	_shownUsers					= [[NSMutableArray alloc] init];
	_queuedChatNotifications	= [[NSMutableArray alloc] init];
	
	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(dateDidChange:)
			   name:WCDateDidChange];

	[[self connection] addObserver:self
						  selector:@selector(chatUsersDidChange:)
							  name:WCChatUsersDidChange];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUser:)
							  name:WCChatReceivedUser];

	[[self connection] addObserver:self
						  selector:@selector(chatCompletedUsers:)
							  name:WCChatCompletedUsers];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserJoin:)
							  name:WCChatReceivedUserJoin];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserLeave:)
							  name:WCChatReceivedUserLeave];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserChange:)
							  name:WCChatReceivedUserChange];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserIconChange:)
							  name:WCChatReceivedUserIconChange];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserKick:)
							  name:WCChatReceivedUserKick];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedUserBan:)
							  name:WCChatReceivedUserBan];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedChat:)
							  name:WCChatReceivedChat];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedActionChat:)
							  name:WCChatReceivedActionChat];

	[[self connection] addObserver:self
						  selector:@selector(chatReceivedTopic:)
							  name:WCChatReceivedTopic];
	
	[self retain];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_saveChatView release];
	
	[_users release];
	[_allUsers release];
	[_shownUsers release];

	[_commandHistory release];

	[_chatFilter release];
	[_topicFilter release];
	[_timestamp release];
	[_topic release];
	
	[_timestampDateFormatter release];
	[_timestampEveryLineDateFormatter release];
	[_topicDateFormatter release];
	
	[_queuedChatNotifications release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSImageCell		*imageCell;
	WCUserCell		*userCell;

	imageCell = [[NSImageCell alloc] init];
	[imageCell setImageAlignment:NSImageAlignCenter];
	[_iconTableColumn setDataCell:imageCell];
	[imageCell release];

	userCell = [[WCUserCell alloc] init];
	[_nickTableColumn setDataCell:userCell];
	[userCell release];

	[_chatOutputTextView setEditable:NO];
	[_chatOutputTextView setUsesFindPanel:YES];
	[_userListTableView setTarget:self];
	[_userListTableView setDoubleAction:@selector(sendPrivateMessage:)];

	_chatFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterWiredChat:), @selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	_topicFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmallSmilies:), 0];

	_timestampDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_timestampDateFormatter setDateStyle:NSDateFormatterShortStyle];
	
	_timestampEveryLineDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampEveryLineDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	_topicDateFormatter = [[WIDateFormatter alloc] init];
	[_topicDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_topicDateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_topicDateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _update];
	[self validate];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_userListTableView setDataSource:NULL];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[_userListSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCChatUserListSplitView"]];
	[_chatSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCChatSplitView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[_userListSplitView propertiesDictionary] forKey:@"WCChatUserListSplitView"];
	[windowTemplate setObject:[_chatSplitView propertiesDictionary] forKey:@"WCChatSplitView"];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self validate];
	
	_receivedUserList = NO;
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	if([[self connection] isReconnecting]) {
		[_topic release];
		_topic = NULL;
		
		[self _updateTopic];
	}
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[_users removeAllObjects];
	[_shownUsers removeAllObjects];
	[_userListTableView reloadData];

	[self validate];
}



- (void)serverConnectionReceivedPing:(NSNotification *)notification {
	NSTimeInterval		interval;
	
	interval = [NSDate timeIntervalSinceReferenceDate];
	
	[self printEvent:[NSSWF:
		NSLS(@"Received ping reply after %.2fms", @"Ping received message (interval)"),
		(interval - _pingInterval) * 1000.0]];
	
	[[self connection] removeObserver:self name:WCServerConnectionReceivedPing];

	_receivingPings = NO;
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self validate];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)dateDidChange:(NSNotification *)notification {
	[self _updateTopic];
}



- (void)chatUsersDidChange:(NSNotification *)notification {
	[_userListTableView reloadData];
}



- (void)chatReceivedUser:(NSNotification *)notification {
	WCUser			*user;

	user = [WCUser userWithArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if([user chatID] != [self chatID])
		return;

	[_allUsers addObject:user];
	[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];
}



- (void)chatCompletedUsers:(NSNotification *)notification {
	NSEnumerator	*enumerator;
	NSArray			*fields;
	NSString		*cid;
	NSNotification	*queuedNotification;

	fields = [[notification userInfo] objectForKey:WCArgumentsKey];
	cid = [fields safeObjectAtIndex:0];

	if([cid unsignedIntValue] != [self chatID])
		return;

	[_shownUsers addObjectsFromArray:_allUsers];
	[_allUsers removeAllObjects];

	[[self connection] postNotificationName:WCChatUsersDidChange object:[self connection]];
	
	_receivedUserList = YES;
	
	enumerator = [_queuedChatNotifications objectEnumerator];
	
	while((queuedNotification = [enumerator nextObject])) {
		if([[queuedNotification name] isEqualToString:WCChatReceivedChat])
			[self performSelector:@selector(chatReceivedChat:) withObject:queuedNotification];
		else if([[queuedNotification name] isEqualToString:WCChatReceivedActionChat])
			[self performSelector:@selector(chatReceivedActionChat:) withObject:queuedNotification];
	}
}



- (void)chatReceivedUserJoin:(NSNotification *)notification {
	WCUser			*user;

	if(!_receivedUserList)
		return;
	
	user = [WCUser userWithArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];

	if([user chatID] != [self chatID])
		return;
	
	if([_users objectForKey:[NSNumber numberWithUnsignedInt:[user userID]]])
		return;

	[_shownUsers addObject:user];
	[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];

	if([[WCSettings eventForTag:WCEventsUserJoined] boolForKey:WCEventsPostInChat])
		[self _printUserJoin:user];
	
	[[self connection] postNotificationName:WCChatUsersDidChange object:[self connection]];

	[[self connection] triggerEvent:WCEventsUserJoined info1:user];
}



- (void)chatReceivedUserLeave:(NSNotification *)notification {
	NSString		*cid, *uid;
	NSArray			*fields;
	WCUser			*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	uid		= [fields safeObjectAtIndex:1];

	if([cid unsignedIntValue] != WCPublicChatID && [cid unsignedIntValue] != [self chatID])
		return;

	user = [self userWithUserID:[uid unsignedIntValue]];
	
	if(!user)
		return;

	if([[WCSettings eventForTag:WCEventsUserLeft] boolForKey:WCEventsPostInChat])
		[self _printUserLeave:user];

	[[self connection] triggerEvent:WCEventsUserLeft info1:user];

	[_shownUsers removeObject:user];
	[_users removeObjectForKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	
	[[self connection] postNotificationName:WCChatUsersDidChange object:[self connection]];
}



- (void)chatReceivedUserChange:(NSNotification *)notification {
	NSString		*uid, *idle, *admin, *nick, *status;
	NSArray			*fields;
	WCUser			*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	uid		= [fields safeObjectAtIndex:0];
	idle	= [fields safeObjectAtIndex:1];
	admin	= [fields safeObjectAtIndex:2];
	nick	= [fields safeObjectAtIndex:4];
	status  = [fields safeObjectAtIndex:5];

	user = [self userWithUserID:[uid unsignedIntValue]];

	if(!user)
		return;

	if(![nick isEqualToString:[user nick]]) {
		if([[WCSettings eventForTag:WCEventsUserChangedNick] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user nick:nick];

		[[self connection] triggerEvent:WCEventsUserChangedNick info1:user info2:nick];
	}

	if(![status isEqualToString:[user status]]) {
		if([[WCSettings eventForTag:WCEventsUserChangedStatus] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user status:status];
		
		[[self connection] triggerEvent:WCEventsUserChangedStatus info1:user info2:status];
	}
	
	[user setNick:nick];
	[user setStatus:status];
	[user setIdle:[idle unsignedIntValue]];
	[user setAdmin:[admin unsignedIntValue]];

	[_userListTableView setNeedsDisplay:YES];
}



- (void)chatReceivedUserIconChange:(NSNotification *)notification {
	NSString		*uid, *icon;
	NSArray			*fields;
	NSData			*data;
	NSImage			*image;
	WCUser			*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	uid		= [fields safeObjectAtIndex:0];
	icon	= [fields safeObjectAtIndex:1];

	user = [self userWithUserID:[uid unsignedIntValue]];

	if(!user)
		return;

	data = [NSData dataWithBase64EncodedString:icon];
	image = [[NSImage alloc] initWithData:data];
	[user setIcon:image];
	[image release];

	[_userListTableView setNeedsDisplay:YES];
}



- (void)chatReceivedUserKick:(NSNotification *)notification {
	NSString	*uid1, *uid2, *message;
	NSArray		*fields;
	WCUser		*victim, *killer;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	uid1	= [fields safeObjectAtIndex:0];
	uid2	= [fields safeObjectAtIndex:1];
	message	= [fields safeObjectAtIndex:2];

	victim = [self userWithUserID:[uid1 unsignedIntValue]];
	killer = [self userWithUserID:[uid2 unsignedIntValue]];

	if(!victim || !killer)
		return;

	[self _printUserKick:victim by:killer message:message];
	
	if([victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasKicked object:[self connection]];

	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:[victim userID]]];
	
	[[self connection] postNotificationName:WCChatUsersDidChange object:[self connection]];
}



- (void)chatReceivedUserBan:(NSNotification *)notification {
	NSString	*uid1, *uid2, *message;
	NSArray		*fields;
	WCUser		*victim, *killer;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	uid1	= [fields safeObjectAtIndex:0];
	uid2	= [fields safeObjectAtIndex:1];
	message	= [fields safeObjectAtIndex:2];

	victim = [self userWithUserID:[uid1 unsignedIntValue]];
	killer = [self userWithUserID:[uid2 unsignedIntValue]];

	if(!victim || !killer)
		return;

	[self _printUserBan:victim by:killer message:message];

	if([victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasBanned object:[self connection]];

	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:[victim userID]]];
	
	[[self connection] postNotificationName:WCChatUsersDidChange object:[self connection]];
}



- (void)chatReceivedChat:(NSNotification *)notification {
	NSString			*cid, *uid, *chat;
	NSArray				*fields;
	WCUser				*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	uid		= [fields safeObjectAtIndex:1];
	chat	= [fields safeObjectAtIndex:2];

	if([cid unsignedIntValue] != [self chatID])
		return;
	
	if(!_receivedUserList) {
		[_queuedChatNotifications addObject:notification];
		
		return;
	}

	user = [self userWithUserID:[uid unsignedIntValue]];

	if(!user || [user isIgnored])
		return;

	if([WCSettings boolForKey:WCTimestampChat])
		[self _printTimestamp];

	[self _printChat:chat by:user];
	
	if([self _isHighlightedChat:chat])
		[[self connection] triggerEvent:WCEventsHighlightedChatReceived info1:user info2:chat];
	else
		[[self connection] triggerEvent:WCEventsChatReceived info1:user info2:chat];
}



- (void)chatReceivedActionChat:(NSNotification *)notification {
	NSString			*cid, *uid, *chat;
	NSArray				*fields;
	WCUser				*user;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	cid		= [fields safeObjectAtIndex:0];
	uid		= [fields safeObjectAtIndex:1];
	chat	= [fields safeObjectAtIndex:2];

	if([cid unsignedIntValue] != [self chatID])
		return;

	if(!_receivedUserList) {
		[_queuedChatNotifications addObject:notification];
		
		return;
	}
	
	user = [self userWithUserID:[uid unsignedIntValue]];

	if(!user || [user isIgnored])
		return;

	if([WCSettings boolForKey:WCTimestampChat])
		[self _printTimestamp];

	[self _printActionChat:chat by:user];

	if([self _isHighlightedChat:chat])
		[[self connection] triggerEvent:WCEventsHighlightedChatReceived info1:user info2:chat];
	else
		[[self connection] triggerEvent:WCEventsChatReceived info1:user info2:chat];
}



- (void)chatReceivedTopic:(NSNotification *)notification {
	WCTopic		*topic;
	
	topic = [WCTopic topicWithArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if([topic chatID] != [self chatID])
		return;
	
	[_topic release];
	_topic = [topic retain];

	[self _updateTopic];
}



- (float)splitView:(NSSplitView *)splitView constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset {
	if(splitView == _userListSplitView)
		return proposedMin + 50;
	else if(splitView == _chatSplitView)
		return proposedMin + 15;

	return proposedMin;
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _userListSplitView) {
		NSSize		size, rightSize, leftSize;

		size = [_userListSplitView frame].size;
		rightSize = [_userListView frame].size;
		rightSize.height = size.height;
		leftSize.height = size.height;
		leftSize.width = size.width - [_userListSplitView dividerThickness] - rightSize.width;

		[_chatView setFrameSize:leftSize];
		[_userListView setFrameSize:rightSize];
	}
	else if(splitView == _chatSplitView) {
		NSSize		size, bottomSize, topSize;

		size = [_chatSplitView frame].size;
		bottomSize = [_chatInputScrollView frame].size;
		bottomSize.width = size.width;
		topSize.width = size.width;
		topSize.height = size.height - [_chatSplitView dividerThickness] - bottomSize.height;

		[_chatOutputScrollView setFrameSize:topSize];
		[_chatInputScrollView setFrameSize:bottomSize];
	}

	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



- (BOOL)topicTextView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	if(selector == @selector(insertNewline:)) {
		if([[NSApp currentEvent] character] == NSEnterCharacter) {
			[self submitSheet:textView];
			
			return YES;
		}
	}
	
	return NO;
}



- (BOOL)chatTextView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	NSInteger	historyModifier;
	BOOL		commandKey, optionKey, controlKey, historyScrollback;

	commandKey	= (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0);
	optionKey	= (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	controlKey	= (([[NSApp currentEvent] modifierFlags] & NSControlKeyMask) != 0);

	historyScrollback = [WCSettings boolForKey:WCHistoryScrollback];
	historyModifier = [WCSettings integerForKey:WCHistoryScrollbackModifier];
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:) ||
	   selector == @selector(insertNewlineIgnoringFieldEditor:)) {
		NSString		*string, *command;
		BOOL			post = YES;
		NSUInteger		length;

		string = [self _stringByDecomposingAttributedString:[_chatInputTextView textStorage]];
		length = [string length];
		
		if(length == 0)
			return YES;

		if(length > WCChatLimit)
			string = [string substringToIndex:WCChatLimit];
		
		[_commandHistory addObject:[[string copy] autorelease]];
		_currentCommand = [_commandHistory count];
		
		if([string hasPrefix:@"/"]) {
			if([self _runCommand:string])
				post = NO;
		}

		if(post) {
			if(selector == @selector(insertNewlineIgnoringFieldEditor:) ||
			   (selector == @selector(insertNewline:) && optionKey))
				command = WCMeCommand;
			else
				command = WCSayCommand;
			
			[[self connection] sendCommand:command
							  withArgument:[NSSWF:@"%u", [self chatID]]
							  withArgument:string];

			[[WCStats stats] addUnsignedLongLong:[string UTF8StringLength] forKey:WCStatsChat];
		}

		[_chatInputTextView setString:@""];

		return YES;
	}
	// --- user pressed tab key
	else if(selector == @selector(insertTab:)) {
		if([WCSettings boolForKey:WCTabCompleteNicks]) {
			[_chatInputTextView setString:[self _stringByCompletingString:[_chatInputTextView string]]];
			
			return YES;
		}
	}
	// --- user pressed the escape key
	else if(selector == @selector(cancelOperation:)) {
		[_chatInputTextView setString:@""];

		return YES;
	}
	// --- user pressed configured history up key
	else if(historyScrollback &&
			((selector == @selector(moveUp:) &&
			  historyModifier == WCHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToBeginningOfDocument:) &&
			  historyModifier == WCHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToBeginningOfParagraph:) &&
			  historyModifier == WCHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageUp:) &&
			  historyModifier == WCHistoryScrollbackModifierControl &&
			  controlKey))) {
		if(_currentCommand > 0) {
			if(_currentCommand == [_commandHistory count]) {
				[_currentString release];

				_currentString = [[_chatInputTextView string] copy];
			}

			[_chatInputTextView setString:[_commandHistory objectAtIndex:--_currentCommand]];

			return YES;
		}
	}
	// --- user pressed the arrow down key
	else if(historyScrollback &&
			((selector == @selector(moveDown:) &&
			  historyModifier == WCHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToEndOfDocument:) &&
			  historyModifier == WCHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToEndOfParagraph:) &&
			  historyModifier == WCHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageDown:) &&
			  historyModifier == WCHistoryScrollbackModifierControl &&
			  controlKey))) {
		if(_currentCommand + 1 < [_commandHistory count]) {
			[_chatInputTextView setString:[_commandHistory objectAtIndex:++_currentCommand]];

			return YES;
		}
		else if(_currentCommand + 1 == [_commandHistory count]) {
			_currentCommand++;
			[_chatInputTextView setString:_currentString];
			[_currentString release];
			_currentString = NULL;

			return YES;
		}
	}
	// --- user pressed cmd/ctrl arrow up/down or page up/down
	else if(selector == @selector(moveToBeginningOfDocument:) ||
			selector == @selector(moveToEndOfDocument:) ||
			selector == @selector(scrollToBeginningOfDocument:) ||
			selector == @selector(scrollToEndOfDocument:) ||
			selector == @selector(scrollPageUp:) ||
			selector == @selector(scrollPageDown:)) {
		[_chatOutputTextView performSelector:selector withObject:self];
		
		return YES;
	}
	
	return NO;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	BOOL	value = NO;

	if(textView == _setTopicTextView) {
		value = [self topicTextView:textView doCommandBySelector:selector];
		[_setTopicTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatFont]]];
	}
	else if(textView == _chatInputTextView) {
		value = [self chatTextView:textView doCommandBySelector:selector];
		[_chatInputTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatFont]]];
	}
	
	return value;
}



#pragma mark -

- (void)validate {
	BOOL		connected;
	
	connected = [[self connection] isConnected];
	
	if([_userListTableView selectedRow] >= 0) {
		[_infoButton setEnabled:([[[self connection] account] getUserInfo] && connected)];
		[_privateMessageButton setEnabled:connected];
	} else {
		[_infoButton setEnabled:NO];
		[_privateMessageButton setEnabled:NO];
	}
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	BOOL	connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(sendPrivateMessage:))
		return connected;
	else if(selector == @selector(getInfo:))
		return ([[[self connection] account] getUserInfo] && connected && ([_userListTableView selectedRow] >= 0));
	else if(selector == @selector(editAccount:))
		return ([[[self connection] account] editAccounts] && connected);
	else if(selector == @selector(ignore:) || selector == @selector(unignore:)) {
		if([[self selectedUser] isIgnored]) {
			[item setTitle:NSLS(@"Unignore", "User list menu title")];
			[item setAction:@selector(unignore:)];
		} else {
			[item setTitle:NSLS(@"Ignore", "User list menu title")];
			[item setAction:@selector(ignore:)];
		}
	}
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (WCUser *)selectedUser {
	NSInteger		row;

	row = [_userListTableView selectedRow];

	if(row < 0)
		return NULL;

	return [_shownUsers objectAtIndex:row];
}



- (NSArray *)selectedUsers {
	return [NSArray arrayWithObject:[self selectedUser]];
}



- (NSArray *)users {
	return _shownUsers;
}



- (NSArray *)nicks {
	NSEnumerator	*enumerator;
	NSMutableArray	*nicks;
	WCUser			*user;
	
	nicks = [NSMutableArray array];
	enumerator = [_shownUsers objectEnumerator];
	
	while((user = [enumerator nextObject]))
		[nicks addObject:[user nick]];
	
	return nicks;
}



- (WCUser *)userAtIndex:(NSUInteger)index {
	return [_shownUsers objectAtIndex:index];
}



- (WCUser *)userWithUserID:(WCUserID)uid {
	return [_users objectForKey:[NSNumber numberWithInt:uid]];
}



- (WCChatID)chatID {
	return WCPublicChatID;
}



- (NSTextView *)insertionTextView {
	return _chatInputTextView;
}



#pragma mark -

- (void)printEvent:(NSString *)message {
	NSString	*output;

	output = [NSSWF:NSLS(@"<<< %@ >>>", @"Chat event (message)"), message];

	if([WCSettings boolForKey:WCTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];

	[self _printString:output];
}



#pragma mark -

- (IBAction)stats:(id)sender {
	[[self connection] sendCommand:WCSayCommand
					  withArgument:[NSSWF:@"%u", [self chatID]]
					  withArgument:[[WCStats stats] stringValue]];
}



- (IBAction)saveChat:(id)sender {
	const NSStringEncoding	*encodings;
	NSSavePanel				*savePanel;
	NSAttributedString		*attributedString;
	NSString				*name, *path, *string;
	WCChatFormat			format;
	NSStringEncoding		encoding;
	NSUInteger				i = 0;
	 
	format		= [WCSettings intForKey:WCLastChatFormat];
	encoding	= [WCSettings intForKey:WCLastChatEncoding];
	
	if(encoding == 0)
		encoding = NSUTF8StringEncoding;
	
	if(!_saveChatView) {
		[NSBundle loadNibNamed:@"SaveChat" owner:self];
		
		[_saveChatFileFormatPopUpButton removeAllItems];
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Plain Text", @"Save chat format") tag:WCChatPlainText]];
		
		[_saveChatPlainTextEncodingPopUpButton removeAllItems];

		encodings = [NSString availableStringEncodings];
		
		while(encodings[i]) {
			if(encodings[i] <= NSMacOSRomanStringEncoding) {
				[_saveChatPlainTextEncodingPopUpButton addItem:
					[NSMenuItem itemWithTitle:[NSString localizedNameOfStringEncoding:encodings[i]] tag:encodings[i]]];
			}
			
			i++;
		}
	}
	
	if([_saveChatFileFormatPopUpButton numberOfItems] > 1)
		[_saveChatFileFormatPopUpButton removeItemAtIndex:1];
	
	if([[_chatOutputTextView textStorage] containsAttachments]) {
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Rich Text With Graphics Format (RTFD)", @"Save chat format") tag:WCChatRTFD]];
		
		if(format == WCChatRTF)
			format = WCChatRTFD;
	} else {
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Rich Text Format (RTF)", @"Save chat format") tag:WCChatRTF]];
		
		if(format == WCChatRTFD)
			format = WCChatRTF;
	}
	
	[_saveChatFileFormatPopUpButton selectItemWithTag:format];
	[_saveChatPlainTextEncodingPopUpButton selectItemWithTag:encoding];
	
	if([self chatID] == WCPublicChatID) {
		name = [NSSWF:NSLS(@"%@ Public Chat", "Save chat file name (server)"),
			[[self connection] name]];
	} else {
		name = [NSSWF:NSLS(@"%@ Private Chat", "Save chat file name (server)"),
			[[self connection] name]];
	}
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView:_saveChatView];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setTitle:NSLS(@"Save Chat", @"Save chat save panel title")];
	
	[self _updateSaveChatForPanel:savePanel];

	if([savePanel runModalForDirectory:[WCSettings objectForKey:WCDownloadFolder] file:name] == NSFileHandlingPanelOKButton) {
		path		= [savePanel filename];
		format		= [_saveChatFileFormatPopUpButton tagOfSelectedItem];
		encoding	= [_saveChatPlainTextEncodingPopUpButton tagOfSelectedItem];
		
		switch(format) {
			case WCChatPlainText:
				string = [_chatOutputTextView string];
				
				[[string dataUsingEncoding:encoding]
					writeToFile:path atomically:YES];
				break;
			
			case WCChatRTF:
				attributedString = [_chatOutputTextView textStorage];
				
				[[attributedString RTFFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:NULL]
					writeToFile:path atomically:YES];
				break;
			
			case WCChatRTFD:
				attributedString = [_chatOutputTextView textStorage];
				
				[[attributedString RTFDFileWrapperFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:NULL]
					writeToFile:path atomically:YES updateFilenames:YES];
				break;
		}
	}
	
	[WCSettings setInt:[_saveChatFileFormatPopUpButton tagOfSelectedItem] forKey:WCLastChatFormat];
	[WCSettings setInt:[_saveChatPlainTextEncodingPopUpButton tagOfSelectedItem] forKey:WCLastChatEncoding];
}



- (IBAction)setTopic:(id)sender {
	[_setTopicTextView setString:[_topicTextField stringValue]];
	[_setTopicTextView setSelectedRange:NSMakeRange(0, [[_setTopicTextView string] length])];
	
	[NSApp beginSheet:_setTopicPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(topicSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)topicSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		[[self connection] sendCommand:WCTopicCommand
						  withArgument:[NSSWF:@"%u", [self chatID]]
						  withArgument:[_setTopicTextView string]];
	}

	[_setTopicPanel close];
	[_setTopicTextView setString:@""];
}



- (IBAction)sendPrivateMessage:(id)sender {
	if(![_privateMessageButton isEnabled])
		return;
	
	[[[self connection] messages] showPrivateMessageToUser:[self selectedUser]];
}



- (IBAction)getInfo:(id)sender {
	[WCUserInfo userInfoWithConnection:[self connection] user:[self selectedUser]];
}



- (IBAction)editAccount:(id)sender {
	WCAccount		*account;
	WCUser			*user;

	user = [self selectedUser];
	account = [[[self connection] accounts] userWithName:[user login]];

	[WCAccountEditor accountEditorWithConnection:[self connection] account:account];
}



- (IBAction)ignore:(id)sender {
	NSDictionary	*ignore;
	WCUser			*user;

	user = [self selectedUser];

	if([user isIgnored])
		return;

	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
				[user nick],	WCIgnoresNick,
				[user login],	WCIgnoresLogin,
				[user address],	WCIgnoresAddress,
				NULL];
	[WCSettings addIgnore:ignore];

	[_userListTableView setNeedsDisplay:YES];
}



- (IBAction)unignore:(id)sender {
	NSDictionary		*ignore;
	NSEnumerator		*enumerator;
	WCUser				*user;
	BOOL				nick, login, address;
	NSUInteger			i;

	user = [self selectedUser];

	if(![user isIgnored])
		return;

	while([user isIgnored]) {
		enumerator = [[WCSettings objectForKey:WCIgnores] objectEnumerator];
		i = 0;

		while((ignore = [enumerator nextObject])) {
			nick = login = address = NO;

			if([[ignore objectForKey:WCIgnoresNick] isEqualToString:[user nick]] ||
				[[ignore objectForKey:WCIgnoresNick] isEqualToString:@""])
				nick = YES;

			if([[ignore objectForKey:WCIgnoresLogin] isEqualToString:[user login]] ||
				[[ignore objectForKey:WCIgnoresLogin] isEqualToString:@""])
				login = YES;

			if([[ignore objectForKey:WCIgnoresAddress] isEqualToString:[user address]] ||
				[[ignore objectForKey:WCIgnoresAddress] isEqualToString:@""])
				address = YES;

			if(nick && login && address)
				[WCSettings removeIgnoreAtIndex:i];
			
			i++;
		}
	}

	[_userListTableView setNeedsDisplay:YES];
}



#pragma mark -

- (IBAction)fileFormat:(id)sender {
	[self _updateSaveChatForPanel:(NSSavePanel *) [sender window]];
}



#pragma mark -

- (void)insertSmiley:(id)sender {
	NSFileWrapper		*wrapper;
	NSTextAttachment	*attachment;
	NSAttributedString	*attributedString;
	
	wrapper				= [[NSFileWrapper alloc] initWithPath:[sender representedObject]];
	attachment			= [[WITextAttachment alloc] initWithFileWrapper:wrapper string:[sender toolTip]];
	attributedString	= [NSAttributedString attributedStringWithAttachment:attachment];
	
	[_chatInputTextView insertText:attributedString];
	
	[attachment release];
	[wrapper release];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownUsers count];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self validate];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCUser		*user;

	if(column == _nickTableColumn) {
		user = [self userAtIndex:row];

		[cell setTextColor:[user color]];
		[cell setIgnored:[user isIgnored]];
	}
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCUser		*user;

	user = [self userAtIndex:row];
	
	if(column == _iconTableColumn)
		return [user iconWithIdleTint:YES];
	else if(column == _nickTableColumn) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[user nick],		WCUserCellNickKey,
			[user status],		WCUserCellStatusKey,
			NULL];
	}

	return NULL;
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self userAtIndex:row] nick];
}



- (NSString *)tableView:(NSTableView *)tableView toolTipForRow:(NSInteger)row {
	WCUser		*user;

	user = [self userAtIndex:row];

	return [user status] && [[user status] length] > 0
		? [NSSWF:@"%@\n%@", [user nick], [user status]]
		: [user nick];
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCUser		*user;
	NSInteger	row;

	row = [[items objectAtIndex:0] integerValue];
	user = [self userAtIndex:row];

	[pasteboard declareTypes:[NSArray arrayWithObjects:WCUserPboardType, NSStringPboardType, NULL]
				owner:NULL];
	[pasteboard setData:[NSArchiver archivedDataWithRootObject:user] forType:WCUserPboardType];
	[pasteboard setString:[user nick] forType:NSStringPboardType];

	return YES;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCUser			*user;

	user = [self selectedUser];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[user nick] forType:NSStringPboardType];
}

@end
