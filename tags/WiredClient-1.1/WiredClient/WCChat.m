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

#import <unistd.h>
#import "NSDateAdditions.h"
#import "WCAccount.h"
#import "WCChat.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCIcons.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCSendMessage.h"
#import "WCSettings.h"
#import "WCSplitView.h"
#import "WCStats.h"
#import "WCTypeAheadTableView.h"
#import "WCURLTextView.h"
#import "WCUser.h"
#import "WCUserInfo.h"

@implementation WCChat

- (id)initWithConnection:(WCConnection *)connection nib:(NSString *)nib {
	self = [super initWithWindowNibName:nib];
	
	// --- get parameters
	_connection		= [connection retain];

	// --- initiate our command history array
	_commandHistory = [[NSMutableArray alloc] init];

	// --- initiate our users dictionaries
	_allUsers		= [[NSMutableDictionary alloc] init];
	_shownUsers		= [[NSMutableDictionary alloc] init];
	_sortedUsers	= [[NSArray alloc] init];
	
	// --- initiate timestamp date
	_timestamp		= [[NSDate dateWithTimeIntervalSinceNow:0] retain];
	
	// --- subscribe to these
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
		selector:@selector(chatShouldAddUser:)
		name:WCChatShouldAddUser
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(chatShouldCompleteUsers:)
		name:WCChatShouldCompleteUsers
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(chatShouldReloadListing:)
		name:WCChatShouldReloadListing
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(userHasJoined:)
		name:WCUserHasJoined
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(userHasLeft:)
		name:WCUserHasLeft
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(userHasChanged:)
		name:WCUserHasChanged
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(userWasKicked:)
		name:WCUserWasKicked
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(userWasBanned:)
		name:WCUserWasBanned
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(chatShouldPrintChat:)
		name:WCChatShouldPrintChat
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(chatShouldPrintAction:)
		name:WCChatShouldPrintAction
		object:NULL];
	
	return self;
}



- (void)dealloc {
	[_connection release];

	[_allUsers release];
	[_shownUsers release];
	[_sortedUsers release];

	[_commandHistory release];

	[_timestamp release];
	
	[super dealloc];
}



#pragma mark -

- (void)connectionPrivilegesDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- update buttons
	[self updateButtons];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	// --- update chat window
	[self update];
	
	// --- scroll to bottom unconditionally
	[_chatOutputTextView scrollRangeToVisible:
		NSMakeRange([[_chatOutputTextView textStorage] length], 0)];
}



- (void)chatShouldAddUser:(NSNotification *)notification {
	NSString		*argument, *cid, *uid, *idle, *admin, *icon, *nick, *login, *address;
	NSArray			*fields;
	WCConnection	*connection;
	WCUser			*user;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	idle	= [fields objectAtIndex:2];
	admin	= [fields objectAtIndex:3];
	icon	= [fields objectAtIndex:4];
	nick	= [fields objectAtIndex:5];
	login	= [fields objectAtIndex:6];
	address	= [fields objectAtIndex:7];
	
	if((unsigned int) [cid intValue] != _cid)
		return;

	// --- allocate a new user and fill out the fields
	user = [[WCUser alloc] init];
	[user setUid:[uid intValue]];
	[user setIdle:[idle intValue]];
	[user setAdmin:[admin intValue]];
	[user setIcon:[icon intValue]];
	[user setNick:nick];
	[user setLogin:login];
	[user setAddress:address];
	[user setJoinTime:[NSDate date]];
	
	// --- add it to our dictionary of users
	[_allUsers setObject:user forKey:[NSNumber numberWithInt:[uid intValue]]];
	[user release];
}



- (void)chatShouldCompleteUsers:(NSNotification *)notification {
	NSString		*argument;
	WCConnection	*connection;

	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	if((unsigned int) [argument intValue] != _cid)
		return;

	// --- enter the accumulated users
	[_shownUsers addEntriesFromDictionary:_allUsers];
	
	// --- sort the users
	[_sortedUsers release];
	_sortedUsers = [_shownUsers keysSortedByValueUsingSelector:@selector(joinTimeSort:)];
	[_sortedUsers retain];

	// --- update users
	[self updateUserCount];

	// --- and reload the table
	[_userListTableView reloadData];
}



- (void)chatShouldReloadListing:(NSNotification *)notification {
	[_userListTableView reloadData];
}




- (void)userHasJoined:(NSNotification *)notification {
	NSString		*argument, *cid, *uid, *idle, *admin, *icon, *nick, *login, *address;
	NSArray			*fields;
	WCConnection	*connection;
	WCUser			*user;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	idle	= [fields objectAtIndex:2];
	admin	= [fields objectAtIndex:3];
	icon	= [fields objectAtIndex:4];
	nick	= [fields objectAtIndex:5];
	login	= [fields objectAtIndex:6];
	address	= [fields objectAtIndex:7];
	
	if((unsigned int) [cid intValue] != _cid)
		return;
	
	// --- allocate a new user and fill out the fields
	user = [[WCUser alloc] init];
	[user setUid:[uid intValue]];
	[user setIdle:[idle intValue]];
	[user setAdmin:[admin intValue]];
	[user setIcon:[icon intValue]];
	[user setNick:nick];
	[user setLogin:login];
	[user setAddress:address];
	[user setJoinTime:[NSDate date]];
	
	// --- add it to our dictionary of users
	[_shownUsers setObject:user forKey:[NSNumber numberWithInt:[uid intValue]]];
	[user release];
	
	// --- sort the users
	[_sortedUsers release];
	_sortedUsers = [_shownUsers keysSortedByValueUsingSelector:@selector(joinTimeSort:)];
	[_sortedUsers retain];

	// --- post chat about it
	if([[WCSettings objectForKey:WCShowJoinLeave] boolValue]) {
		[self printEvent:[NSString stringWithFormat:
			NSLocalizedString(@"%@ has joined", @"Client has joined message (nick)"),
			nick]];
		
	}

	// --- update users
	[self updateUserCount];

	// --- reload the table
	[_userListTableView reloadData];
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCUserJoinEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCUserJoinEventSound]] play];
}



- (void)userHasLeft:(NSNotification *)notification {
	NSString		*argument, *cid, *uid;
	NSArray			*fields;
	WCConnection	*connection;
	WCUser			*user;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	
	if((unsigned int) [cid intValue] != _cid)
		return;
	
	// --- get user
	user = [_shownUsers objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- post chat about it
	if([[WCSettings objectForKey:WCShowJoinLeave] boolValue]) {
		[self printEvent:[NSString stringWithFormat:
			NSLocalizedString(@"%@ has left", @"Client has left message (nick)"),
			[user nick]]];
	}

	// --- remove from dictionary
	[_shownUsers removeObjectForKey:[NSNumber numberWithInt:[user uid]]];

	// --- re-sort
	[_sortedUsers release];
	_sortedUsers = [_shownUsers keysSortedByValueUsingSelector:@selector(joinTimeSort:)];
	[_sortedUsers retain];

	// --- update users
	[self updateUserCount];

	// --- reload the table
	[_userListTableView reloadData];
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCUserLeaveEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCUserLeaveEventSound]] play];
}



- (void)userHasChanged:(NSNotification *)notification {
	NSString		*argument, *uid, *idle, *admin, *icon, *nick;
	NSArray			*fields;
	WCConnection	*connection;
	WCUser			*user;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	uid		= [fields objectAtIndex:0];
	idle	= [fields objectAtIndex:1];
	admin	= [fields objectAtIndex:2];
	icon	= [fields objectAtIndex:3];
	nick	= [fields objectAtIndex:4];
	
	// --- get the user
	user	= [_shownUsers objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	if(!user)
		return;

	// --- post chat about nick changes
	if(![nick isEqualToString:[user nick]] && [[WCSettings objectForKey:WCShowJoinLeave] boolValue]) {
		[self printEvent:[NSString stringWithFormat:
			NSLocalizedString(@"%@ is now known as %@", @"Client rename message (oldnick, newnick)"),
			[user nick],
			nick]];
	}

	// --- update the user
	[user setIdle:[idle intValue]];
	[user setAdmin:[admin intValue]];
	[user setIcon:[icon intValue]];
	[user setNick:nick];

	// --- update users
	[self updateUserCount];

	// --- reload the table
	[_userListTableView reloadData];
}



- (void)userWasKicked:(NSNotification *)notification {
	NSString		*argument, *victim, *killer, *message;
	NSString		*victimNick, *killerNick;
	NSArray			*fields;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	victim		= [fields objectAtIndex:0];
	killer		= [fields objectAtIndex:1];
	message		= [fields objectAtIndex:2];
	
	// --- get the nicks
	victimNick	= [[_shownUsers objectForKey:[NSNumber numberWithInt:[victim intValue]]] nick];
	killerNick	= [[_shownUsers objectForKey:[NSNumber numberWithInt:[killer intValue]]] nick];
	
	// --- post chat about it
	if([[WCSettings objectForKey:WCShowJoinLeave] boolValue]) {
		[self printEvent:[NSString stringWithFormat:
			NSLocalizedString(@"%@ was kicked by %@ (%@)", @"Client kicked message (victim, killer, message)"),
			victimNick,
			killerNick,
			message]];
	}
			
	// --- remove from dictionary
	[_shownUsers removeObjectForKey:[NSNumber numberWithInt:[victim intValue]]];

	// -- resort
	[_sortedUsers release];
	_sortedUsers = [_shownUsers keysSortedByValueUsingSelector:@selector(joinTimeSort:)];
	[_sortedUsers retain];

	// --- update users
	[self updateUserCount];

	// --- reload the table
	[_userListTableView reloadData];
}



- (void)userWasBanned:(NSNotification *)notification {
	NSString		*argument, *victim, *killer, *message;
	NSString		*victimNick, *killerNick;
	NSArray			*fields;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	victim		= [fields objectAtIndex:0];
	killer		= [fields objectAtIndex:1];
	message		= [fields objectAtIndex:2];
	
	// --- get the nicks
	victimNick	= [[_shownUsers objectForKey:[NSNumber numberWithInt:[victim intValue]]] nick];
	killerNick	= [[_shownUsers objectForKey:[NSNumber numberWithInt:[killer intValue]]] nick];
	
	// --- post chat about it
	if([[WCSettings objectForKey:WCShowJoinLeave] boolValue]) {
		[self printEvent:[NSString stringWithFormat:
			NSLocalizedString(@"%@ was banned by %@ (%@)", @"Client banned message (victim, killer, message)"),
			victimNick,
			killerNick,
			message]];
	}
			
	// --- remove from dictionary
	[_shownUsers removeObjectForKey:[NSNumber numberWithInt:[victim intValue]]];

	// -- resort
	[_sortedUsers release];
	_sortedUsers = [_shownUsers keysSortedByValueUsingSelector:@selector(joinTimeSort:)];
	[_sortedUsers retain];

	// --- update users
	[self updateUserCount];

	// --- reload the table
	[_userListTableView reloadData];
}



- (void)chatShouldPrintChat:(NSNotification *)notification {
	NSString			*argument, *cid, *uid, *chat;
	NSString			*nick, *time, *prepend, *output;
	NSMutableString		*format;
	NSArray				*fields;
	WCConnection		*connection;
	WCUser				*user;
	NSDate				*date;
	NSRange				range;
	double				interval;
	int					i, length, offset;
	
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	cid		= [fields objectAtIndex:0];
	uid		= [fields objectAtIndex:1];
	chat	= [fields objectAtIndex:2];

	if((unsigned int) [cid intValue] != _cid)
		return;

	// --- get user
	user = [_shownUsers objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- check ignore
	if([user ignore])
		return;
	
	// --- insert a timestamp
	interval = [[WCSettings objectForKey:WCTimestampChatInterval] doubleValue];
	date = [NSDate dateWithTimeIntervalSinceNow:0 - interval];
	
	if([date compare:_timestamp] == NSOrderedDescending) {
		[self printEvent:[[NSDate date] localizedDateWithFormat:NSShortTimeDateFormatString]];
		
		[_timestamp release];
		_timestamp = [NSDate date];
		[_timestamp retain];
	}
	
	// --- lower the prepend offset a bit when using timestamps
	if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue])
		offset= WCChatPrepend - 4;
	else
		offset = WCChatPrepend;
		
	// --- get nick
	nick = [user nick];
	length = offset - [nick length];
	time = prepend = output = @"";
	
	// --- add timestamp
	if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
		format = [[[NSUserDefaults standardUserDefaults]
			objectForKey:NSTimeFormatString] mutableCopy];
		range = [format rangeOfString:@":%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];

		range = [format rangeOfString:@".%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];
		
		time = [[NSDate date] descriptionWithCalendarFormat:format timeZone:NULL locale:NULL];
	}

	// --- build the string from the nick and the chat message
	output = [[_chatOutputTextView textStorage] length] > 0 ? @"\n" : @"";
	
	if([[WCSettings objectForKey:WCChatStyle] intValue] == WCChatStyleWired) {
	   if(length < 0) {
		   nick = [nick substringToIndex:offset];
	   } else {
		   for(i = 0; i < length; i++)
			   prepend = [prepend stringByAppendingString:@" "];
	   }
	   
	   if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"%@ %@%@: %@", @"Chat message, Wired style (time, padding, nick, message)"),
				time, prepend, nick, chat];
		} else {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"%@%@: %@", @"Chat message, Wired style (padding, nick, message)"),
				prepend, nick, chat];
		}
	}
	else if([[WCSettings objectForKey:WCChatStyle] intValue] == WCChatStyleIRC) {
		if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"%@ <%@> %@", @"Chat message, IRC style (time, nick, message)"),
				time, nick, chat];
		} else {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"<%@> %@", @"Chat message, IRC style (nick, message)"),
				nick, chat];
		}
	}
		
	// --- append
	[[_chatOutputTextView textStorage] appendAttributedString:[_chatOutputTextView scan:output]];

	// --- scroll
	if([[_chatOutputScrollView verticalScroller] floatValue] == 1.0) {
		[_chatOutputTextView scrollRangeToVisible:
			NSMakeRange([[_chatOutputTextView textStorage] length], 0)];
    }

	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCChatEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCChatEventSound]] play];
}



- (void)chatShouldPrintAction:(NSNotification *)notification {
	NSString			*argument, *cid, *uid, *chat;
	NSString			*nick, *output, *time = @"";
	NSArray				*fields;
	NSMutableString		*format;
	NSRange				range;
	NSDate				*date;
	WCConnection		*connection;
	WCUser				*user;
	double				interval;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	cid			= [fields objectAtIndex:0];
	uid			= [fields objectAtIndex:1];
	chat		= [fields objectAtIndex:2];

	if((unsigned int) [cid intValue] != _cid)
		return;

	// --- get user
	user = [_shownUsers objectForKey:[NSNumber numberWithInt:[uid intValue]]];
	
	// --- check ignore
	if([user ignore])
		return;
	
	// --- insert a timestamp
	interval = [[WCSettings objectForKey:WCTimestampChatInterval] doubleValue];
	date = [NSDate dateWithTimeIntervalSinceNow:0 - interval];
	
	if([date compare:_timestamp] == NSOrderedDescending) {
		[self printEvent:[[NSDate date] localizedDateWithFormat:NSShortTimeDateFormatString]];
		
		[_timestamp release];
		_timestamp = [NSDate date];
		[_timestamp retain];
	}
	
	// --- get nick
	nick = [user nick];
	
	// --- add timestamp
	if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
		format = [[[NSUserDefaults standardUserDefaults]
			objectForKey:NSTimeFormatString] mutableCopy];
		range = [format rangeOfString:@":%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];
		
		range = [format rangeOfString:@".%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];

		time = [[NSDate date] descriptionWithCalendarFormat:format timeZone:NULL locale:NULL];
	}

	// --- build the string from the nick and the chat message
	output = [[_chatOutputTextView textStorage] length] > 0 ? @"\n" : @"";
	
	if([[WCSettings objectForKey:WCChatStyle] intValue] == WCChatStyleWired) {
		if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"%@ *** %@ %@", @"Action chat message (time, nick, message)"),
				time, nick, chat];
		} else {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@" *** %@ %@", @"Action chat message (nick, message)"),
				nick, chat];
		}
	}
	else if([[WCSettings objectForKey:WCChatStyle] intValue] == WCChatStyleIRC) {
		if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@"%@ * %@ %@", @"Action chat message (time, nick, message)"),
				time, nick, chat];
		} else {
			output = [output stringByAppendingFormat:
				NSLocalizedString(@" * %@ %@", @"Action chat message (nick, message)"),
				nick, chat];
		}
	}
		
	// --- append
	[[_chatOutputTextView textStorage] appendAttributedString:[_chatOutputTextView scan:output]];

	// --- scroll
	if([[_chatOutputScrollView verticalScroller] floatValue] == 1.0) {
		[_chatOutputTextView scrollRangeToVisible:
			NSMakeRange([[_chatOutputTextView textStorage] length], 0)];
    }
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCChatEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCChatEventSound]] play];
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
		NSSize		size, leftSize, rightSize;
		
		// --- get split view size
		size = [_userListSplitView frame].size;
		
		// --- get static right part size
		rightSize = [_userListView frame].size;
		rightSize.height = size.height;
		
		// --- set dynamic top part size
		leftSize.height = size.height;
		leftSize.width = size.width - [_userListSplitView dividerThickness] - rightSize.width;
		
		// --- set new frames
		[_chatSplitView setFrameSize:leftSize];
		[_userListView setFrameSize:rightSize];
	}
	else if(splitView == _chatSplitView) {
		NSSize		size, topSize, bottomSize;
		
		// --- get split view size
		size = [_chatSplitView frame].size;
		
		// --- get static bottom part size
		bottomSize = [_chatInputScrollView frame].size;
		bottomSize.width = size.width;
		
		// --- set dynamic top part size
		topSize.width = size.width;
		topSize.height = size.height - [_chatSplitView dividerThickness] - bottomSize.height;
		
		// --- set new frames
		[_chatOutputScrollView setFrameSize:topSize];
		[_chatInputScrollView setFrameSize:bottomSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL	commandKey, optionKey, controlKey, value = NO;
	
	// --- we only handle the input area
	if(sender != _chatInputTextView)
		return NO;
	// --- get key state
	commandKey	= (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0);
	optionKey	= (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	controlKey	= (([[NSApp currentEvent] modifierFlags] & NSControlKeyMask) != 0);
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:) ||
	   selector == @selector(insertNewlineIgnoringFieldEditor:)) {
		NSEnumerator		*enumerator;
		NSString			*string, *line;
		BOOL				send = NO;
		unsigned int		lines = 0;
		unsigned long long	bytes;

		string	= [sender string];
		
		if([string length] > 0) {
			// --- add it to the command history
			[_commandHistory addObject:[NSString stringWithString:string]];
			_currentCommand = [_commandHistory count];
			
			if(![string hasPrefix:@"/"]) {
				// --- send it
				send = YES;
			} else {
				// --- try to parse
				if(![self parseCommand:string]) {
					// --- parse failed, send it
					send = YES;
				}
			}

			if(send) {
				// --- split over newlines
				enumerator = [[[[string componentsSeparatedByString:@"\r"] 
					componentsJoinedByString:@"\n"]
						componentsSeparatedByString:@"\n"] objectEnumerator];
				
				while((line = [enumerator nextObject])) {
					// --- we should probably get the hell out here
					if(lines > 50)
						break;
					
					// --- send it
					if([line length] > 0) {
						lines++;
						
						if(selector == @selector(insertNewlineIgnoringFieldEditor:) ||
						   (selector == @selector(insertNewline:) && optionKey)) {
							[[_connection client] sendCommand:[NSString stringWithFormat:
								@"%@ %u%@%@", WCMeCommand, _cid, WCFieldSeparator, line]];
						} else {
							[[_connection client] sendCommand:[NSString stringWithFormat:
								@"%@ %u%@%@", WCSayCommand, _cid, WCFieldSeparator, line]];
						}
					}
				}
					
				// --- save in stats
				bytes = [[WCStats objectForKey:WCStatsChat] unsignedLongLongValue] +
					(unsigned long long) strlen([string UTF8String]);
				[WCStats setObject:[NSNumber numberWithUnsignedLongLong:bytes] forKey:WCStatsChat];
			}
			
			[sender setString:@""];
		}

		value = YES;
	}
	// --- user pressed tab key
	else if(selector == @selector(insertTab:) &&
			[[WCSettings objectForKey:WCTabCompleteNicks] boolValue]) {
		NSMutableArray	*users;
		NSString		*string, *nick, *completed = @"";
		NSEnumerator	*enumerator;
		WCUser			*each;
		BOOL			loop = YES;
		unsigned int	length;
		int				i, count = 0;

		// --- ignore case
		string = [[sender string] lowercaseString];
		length = [string length];
		
		// --- temporary array to hold matching users
		users = [NSMutableArray array];

		if(length > 0) {
			// --- loop over each nick, comparing the beginning of each nick against the
			//     part we've got
			enumerator = [_shownUsers objectEnumerator];
			
			while((each = [enumerator nextObject]) != NULL) {
				if([[each nick] length] >= length) {
					nick = [[[each nick] substringToIndex:length] lowercaseString];
	
					if([nick isEqualToString:string] && ![users containsObject:[each nick]]) {
						[users addObject:[each nick]];
						count++;
						completed = [each nick];
					}
				}
			}
			
			if(count > 1) {
				// --- find the common prefix among the matches
				while(loop) {
					length++;
					enumerator = [users objectEnumerator];
					
					for(i = 1; i < count; i++) {
						if(length > [(NSString *) [users objectAtIndex:i - 1] length] ||
						   length > [(NSString *) [users objectAtIndex:i] length] ||
						   ![[[users objectAtIndex:i - 1] substringToIndex:length] isEqualToString:
								[[users objectAtIndex:i] substringToIndex:length]]) {
							loop = NO;

							break;
						}
					}
				}
				
				// --- set our partial match
				if(length - 1 > [string length])
					[sender setString:[[users objectAtIndex:0] substringToIndex:length - 1]];
			}
			else if(count == 1) {
				// --- just complete the one we found
				[sender setString:[NSString stringWithFormat:@"%@%@",
					completed, [WCSettings objectForKey:WCTabCompleteNicksString]]];
			}
		}

		value = YES;
	}
	// --- user pressed the escape key
	else if(selector == @selector(cancelOperation:)) {
		[sender setString:@""];
		
		value = YES;
	} else {
		int		modifier;
		BOOL	history;
		
		// --- get required modifier
		history = [[WCSettings objectForKey:WCHistoryScrollback] boolValue];
		modifier = [[WCSettings objectForKey:WCHistoryScrollbackModifier] intValue];
		
		// --- user pressed the arrow up key
		if(history &&
		   (selector == @selector(moveUp:) &&
			modifier == WCHistoryScrollbackModifierNone) ||
		   (selector == @selector(moveToBeginningOfDocument:) &&
			modifier == WCHistoryScrollbackModifierCommand &&
			commandKey) ||
		   (selector == @selector(moveToBeginningOfParagraph:) &&
			modifier == WCHistoryScrollbackModifierOption &&
			optionKey) ||
		   (selector == @selector(scrollPageUp:) &&
			modifier == WCHistoryScrollbackModifierControl &&
			controlKey)) {
			if(_currentCommand > 0) {
				// --- save current string
				if(_currentCommand == [_commandHistory count]) {
					[_currentString release];
					
					_currentString = [[sender string] copy];
				}
				
				// --- move up in the command history
				[sender setString:[_commandHistory objectAtIndex:--_currentCommand]];

				value = YES;
			}
		}
		// --- user pressed the arrow down key
		else if(history &&
				(selector == @selector(moveDown:) &&
				 modifier == WCHistoryScrollbackModifierNone) ||
				(selector == @selector(moveToEndOfDocument:) &&
				 modifier == WCHistoryScrollbackModifierCommand &&
				 commandKey) ||
				(selector == @selector(moveToEndOfParagraph:) &&
				 modifier == WCHistoryScrollbackModifierOption &&
				 optionKey) ||
				(selector == @selector(scrollPageDown:) &&
				 modifier == WCHistoryScrollbackModifierControl &&
				 controlKey)) {
			if(_currentCommand + 1 < [_commandHistory count]) {
				// --- move down in the command history
				[sender setString:[_commandHistory objectAtIndex:++_currentCommand]];
		
				value = YES;
			}
			else if(_currentCommand + 1 == [_commandHistory count]) {
				// --- clear
				++_currentCommand;
				
				// --- reset original string
				[sender setString:_currentString];
				[_currentString release];
				_currentString = NULL;
				
				value = YES;
			}
		}
		else if(selector == @selector(moveToBeginningOfDocument:) ||
				selector == @selector(moveToEndOfDocument:) ||
				selector == @selector(scrollPageUp:) ||
				selector == @selector(scrollPageDown:)) {
			[_chatOutputTextView performSelector:selector withObject:self];
		}
	}

	// --- make sure we're always writing in the correct font, if the user
	//     switched to another script for example, this may change
	[_chatInputTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
	
    return value;
}



#pragma mark -

- (void)update {
	NSFont		*font;
	NSColor		*color;
	BOOL		parse = NO;
	
	// --- set font
	font = [WCSettings archivedObjectForKey:WCTextFont];
	
	if(![[_chatOutputTextView font] isEqualTo:font]) {
		[_chatOutputTextView setFont:font];
		[_chatInputTextView setFont:font];
	}

	// --- set background color
	color = [WCSettings archivedObjectForKey:WCChatBackgroundColor];
	
	if(![[_chatOutputTextView backgroundColor] isEqualTo:color]) {
		[_chatOutputTextView setBackgroundColor:color];
		[_chatInputTextView setBackgroundColor:color];
	}

	// --- set text color
	color = [WCSettings archivedObjectForKey:WCChatTextColor];
	
	if(![[_chatOutputTextView textColor] isEqualTo:color]) {
		[_chatOutputTextView setTextColor:color];
		[_chatInputTextView setTextColor:color];
		[_chatInputTextView setInsertionPointColor:color];
		
		parse = YES;
	}
	
	// --- set URL color
	color = [WCSettings archivedObjectForKey:WCURLTextColor];
	
	if(![[_chatOutputTextView urlColor] isEqualTo:color]) {
		[_chatOutputTextView setURLColor:color];
		
		parse = YES;
	}
	
	// --- set event color
	color = [WCSettings archivedObjectForKey:WCEventTextColor];
	
	if(![[_chatOutputTextView eventColor] isEqualTo:color]) {
		[_chatOutputTextView setEventColor:color];
		
		parse = YES;
	}

	// --- parse text
	if(parse) {
		[[_chatOutputTextView textStorage]
			replaceCharactersInRange:NSMakeRange(0, [[_chatOutputTextView string] length])
			withAttributedString:[_chatOutputTextView scan:[_chatOutputTextView string]]];
	}
	
	// --- mark them as updated
	[_chatOutputTextView setNeedsDisplay:YES];
	[_chatInputTextView setNeedsDisplay:YES];
	[_userListTableView reloadData];
}



- (void)updateButtons {
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow];
	
	if(row < 0) {
		[_infoButton setEnabled:NO];
		[_privateMessageButton setEnabled:NO];
	} else {
		[_privateMessageButton setEnabled:YES];

		if([[_connection account] getUserInfo])
			[_infoButton setEnabled:YES];
		else
			[_infoButton setEnabled:NO];
	}
}



- (void)updateUserCount {
	[_userCountTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%u online, %u active", @"User list status"),
		[self numberOfUsers],
		[self numberOfActiveUsers]]];
}



- (void)printEvent:(NSString *)argument {
	NSString			*output, *time;
	NSMutableString		*format;
	NSRange				range;
	
	// --- build the output string
	output = [[_chatOutputTextView textStorage] length] > 0 ? @"\n" : @"";
	
	if([[WCSettings objectForKey:WCTimestampEveryLine] boolValue]) {
		format = [[[NSUserDefaults standardUserDefaults]
			objectForKey:NSTimeFormatString] mutableCopy];
		range = [format rangeOfString:@":%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];
		
		range = [format rangeOfString:@".%S"];
		
		if(range.length > 0)
			[format deleteCharactersInRange:range];
		
		time = [[NSDate date] descriptionWithCalendarFormat:format timeZone:NULL locale:NULL];

		output = [output stringByAppendingFormat:
			@"%@ <<< %@ >>>",
			time, argument];
	} else {
		output = [output stringByAppendingFormat:
			@"<<< %@ >>>",
			argument];
	}
	
	// --- append
	[[_chatOutputTextView textStorage] appendAttributedString:[_chatOutputTextView scan:output]];
	
	// --- scroll
	if([[_chatOutputScrollView verticalScroller] floatValue] == 1.0) {
		[_chatOutputTextView scrollRangeToVisible:
			NSMakeRange([[_chatOutputTextView textStorage] length], 0)];
    }
}



- (BOOL)parseCommand:(NSString *)string {
	NSArray		*arguments;
	NSString	*command, *argument;
	
	// --- switch command
	arguments = [string componentsSeparatedByString:@" "];
	command = [arguments objectAtIndex:0];
	argument = [[arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)] 
		componentsJoinedByString:@" "];
	
	if([command isEqualToString:@"/me"] && [argument length] > 0) {
		unsigned long long	bytes;
		
		// --- send ME command
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %u%@%@", WCMeCommand, _cid, WCFieldSeparator, argument]];
		
		// --- save in stats
		bytes = [[WCStats objectForKey:WCStatsChat] unsignedLongLongValue] +
			(unsigned long long) strlen([argument UTF8String]);
		[WCStats setObject:[NSNumber numberWithUnsignedLongLong:bytes] forKey:WCStatsChat];
		
		return YES;
	}
	else if([command isEqualToString:@"/exec"] && [argument length] > 0) {
		NSEnumerator		*enumerator;
		NSTask				*task;
		NSPipe				*pipe;
		NSFileHandle		*fileHandle;
		NSDictionary		*environment;
		NSData				*buffer;
		NSString			*line, *each;
		int					lines = 0;
		
		// --- get an endpoint
		pipe		= [NSPipe pipe];
		fileHandle	= [pipe fileHandleForReading];
		
		// --- modify the environment
		environment	= [NSDictionary dictionaryWithObjectsAndKeys:
			@"/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin",
			@"PATH",
			NULL];
		
		// --- create task
		task = [[NSTask alloc] init];
		[task setLaunchPath:@"/bin/sh"];
		[task setArguments:[NSArray arrayWithObjects:@"-c", argument, NULL]];
		[task setStandardOutput:pipe];
		[task setStandardError:pipe];
		[task setEnvironment:environment];
		[task launch];
		
		// --- read output
		while((buffer = [fileHandle availableData]) && [buffer length] > 0) {
			line = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
			enumerator = [[[[line componentsSeparatedByString:@"\r"] componentsJoinedByString:@"\n"] 
				componentsSeparatedByString:@"\n"] objectEnumerator];
			
			while((each = [enumerator nextObject])) {
				// --- we should probably get the hell out here
				if(lines > 50) {
					[task terminate];
					
					break;
				}
				
				// --- send it as SAY
				if([each length] > 0) {
					lines++;
					[[_connection client] sendCommand:[NSString stringWithFormat:
						@"%@ %u%@%@", WCSayCommand, _cid, WCFieldSeparator, each]];
				}
			}
			
			[line release];
		}
		
		[task release];
		
		return YES;
	}
	else if([command isEqualToString:@"/nick"] && [argument length] > 0) {
		[[_connection client] sendCommand:WCNickCommand withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/icon"] && [argument length] > 0) {
		[[_connection client] sendCommand:WCIconCommand withArgument:argument];
		
		return YES;
	}
	else if([command isEqualToString:@"/stats"]) {
		[[_connection client] sendCommand:WCSayCommand withArgument:[NSString stringWithFormat:
			@"%u%@%@", _cid, WCFieldSeparator, [WCStats stats]]];
		
		return YES;
	}
#if 0
	// --- contributed by sdz
	// --- do we want this? -morris
	else if([command isEqualToString:@"/msg"] && [argument length] > 0) {
		WCMessage		*message;
		unsigned int	uid;
		
		// --- extract uid from arguments
		uid = [[arguments objectAtIndex:1] intValue];
		arguments = [arguments subarrayWithRange:NSMakeRange(2, [arguments count] - 2)];
		argument = [arguments componentsJoinedByString:@" "];
		
		// --- register it in the history
		message = [[WCMessage alloc] initWithType:WCMessageTypeTo];
		[message setRead:YES];
		[message setDate:[NSDate date]];
		[message setMessage:argument];
		[message setUser:[_shownUsers objectForKey:[NSNumber numberWithInt:uid]]];
		[[_connection messages] add:message];
		
		// --- send it
		[[_connection client] sendCommand:WCMessageCommand withArgument:[NSString stringWithFormat:
			@"%u%@%@", uid, WCFieldSeparator, argument]];
		
		return YES;
	}
#endif
	else if([command isEqualToString:@"/clear"]) {
		[[[_chatOutputTextView textStorage] mutableString] setString:@""];

		return YES;
	}
	
	return NO;
}



- (void)saveChatToURL:(NSURL *)url {
	NSData		*data;
	
	data = [[[_chatOutputTextView textStorage] string] dataUsingEncoding:NSUTF8StringEncoding];
	[data writeToURL:url atomically:YES];
}



#pragma mark -

- (NSMutableDictionary *)users {
	return _shownUsers;
}



- (unsigned int)numberOfUsers {
	return [_shownUsers count];
}



- (unsigned int)numberOfActiveUsers {
	NSEnumerator	*enumerator;
	WCUser			*each;
	unsigned int	active = 0;
	
	enumerator = [_shownUsers objectEnumerator];
	
	while((each = [enumerator nextObject])) {
		if(![each idle])
			active++;
	}

	return active;
}



- (unsigned int)cid {
	return _cid;
}



- (BOOL)canGetInfo {
	return ([_userListTableView selectedRow] >= 0) && [[_connection account] getUserInfo];
}



#pragma mark -

- (IBAction)sendPrivateMessage:(id)sender {
	NSNumber		*key;
	WCUser			*user;
	WCMessage		*message;
	int				row;
	
	// --- get row
	row = [_userListTableView selectedRow];

	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- create a message
	message = [[WCMessage alloc] initWithType:WCMessageTypeTo];
	[message setRead:YES];
	[message setUser:user];
	[message setDate:[NSDate date]];
	
	// --- send message to user
	[(WCSendMessage *) [WCSendMessage alloc] initWithConnection:_connection message:message];
	
	[message release];
}



- (IBAction)info:(id)sender {
	NSNumber	*key;
	WCUser		*user;
	int			row;
	
	// --- get row
	row = [_userListTableView selectedRow]; 

	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- create a user info window
	[[WCUserInfo alloc] initWithConnection:_connection user:user];
}



- (IBAction)ignore:(id)sender {
	NSMutableArray		*ignores;
	NSDictionary		*ignore;
	NSNumber			*key;
	WCUser				*user;
	int					row;
	
	// --- get row
	row = [_userListTableView selectedRow]; 

	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	if([user ignore])
		return;
	
	// --- create mutable ignores
	ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnores]];
	
	// --- create new ignore
	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
				[user nick],	@"Nick",
				[user login],	@"Login",
				[user address],	@"Address",
				NULL];

	// --- add to ignores
	[ignores addObject:ignore];

	// --- set new ignores
	[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnores];
	
	// --- post reload table notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCChatShouldReloadListing
		object:NULL];
}



- (IBAction)unignore:(id)sender {
	NSMutableArray		*ignores;
	NSDictionary		*ignore;
	NSEnumerator		*enumerator;
	NSNumber			*key;
	WCUser				*user;
	BOOL				nick, login, address;
	int					row;
	
	// --- get row
	row = [_userListTableView selectedRow]; 

	if(row < 0)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	if(![user ignore])
		return;
	
	// --- create mutable ignores
	ignores = [NSMutableArray arrayWithArray:[WCSettings objectForKey:WCIgnores]];
	
	// --- while the user is still ignored, loop over all ignores and remove
	//     any that matches
	while([user ignore]) {
		enumerator = [ignores objectEnumerator];

		while((ignore = [enumerator nextObject])) {
			nick = login = address = NO;
	
			if([[ignore objectForKey:@"Nick"] isEqualToString:[user nick]] ||
				[[ignore objectForKey:@"Nick"] isEqualToString:@""])
				nick = YES;
			
			if([[ignore objectForKey:@"Login"] isEqualToString:[user login]] ||
				[[ignore objectForKey:@"Login"] isEqualToString:@""])
				login = YES;
			
			if([[ignore objectForKey:@"Address"] isEqualToString:[user address]] ||
				[[ignore objectForKey:@"Address"] isEqualToString:@""])
				address = YES;
	
			if(nick && login && address) {
				// --- remove
				[ignores removeObject:ignore];

				// --- set new ignores
				[WCSettings setObject:[NSArray arrayWithArray:ignores] forKey:WCIgnores];
			}
		}
	}
	
	// --- post reload table notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCChatShouldReloadListing
		object:NULL];
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_shownUsers count];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}



- (void)tableView:(NSTableView *)sender willDisplayCell:(WCIconCell *)cell forTableColumn:(NSTableColumn *)column row:(int)row {
	NSNumber	*key;
	WCUser		*user;
	
	if(column != _nickTableColumn)
		return;

	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- set the color
	if([user ignore]) {
		[cell setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
			[user color], NSForegroundColorAttributeName,
			[NSNumber numberWithInt:1.0], NSStrikethroughStyleAttributeName,
			NULL]];
	} else {
		[cell setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
			[user color], NSForegroundColorAttributeName,
			NULL]];
	}
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(int)row {
	NSNumber	*key;
	WCUser		*user;
	
	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];

	// --- populate the user list
	if(column == _nickTableColumn) {
		return [NSArray arrayWithObjects:
					[user nick],
					[WCIcons objectForKey:[NSNumber numberWithInt:[user icon]]],
					NULL];
	}
	
	return NULL;
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	NSNumber	*key;
	WCUser		*user;
	int			row;
	
	// --- get row
	row = [[items objectAtIndex:0] intValue];
	
	if(row < 0)
		return NO;
	
	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- put user in pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObjects:WCDragUser, NSStringPboardType, NULL]
				owner:NULL];
	[pasteboard setData:[NSArchiver archivedDataWithRootObject:user] forType:WCDragUser];
	[pasteboard setString:[user nick] forType:NSStringPboardType];
	
	return YES;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	NSNumber		*key;
	WCUser			*user;
	int				row;
	
	// --- get row number
	row = [_userListTableView selectedRow]; 
	
	if(row < 0)
		return;
	
	// --- get user
	key		= [_sortedUsers objectAtIndex:row];
	user	= [_shownUsers objectForKey:key];
	
	// --- put it on the pasteboard
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[user nick] forType:NSStringPboardType];
}

@end
