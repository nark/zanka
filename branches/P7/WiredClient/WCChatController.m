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
#import "WCAccountsController.h"
#import "WCApplicationController.h"
#import "WCChatController.h"
#import "WCChatWindow.h"
#import "WCErrorQueue.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCStats.h"
#import "WCTopic.h"
#import "WCUser.h"
#import "WCUserCell.h"
#import "WCUserInfo.h"

#define WCPublicChatID											1

#define WCLastChatFormat										@"WCLastChatFormat"
#define WCLastChatEncoding										@"WCLastChatEncoding"

#define WCChatPrepend											13
#define WCChatLimit												4096


NSString * const WCChatUserAppearedNotification					= @"WCChatUserAppearedNotification";
NSString * const WCChatUserDisappearedNotification				= @"WCChatUserDisappearedNotification";
NSString * const WCChatUserNickDidChangeNotification			= @"WCChatUserNickDidChangeNotification";
NSString * const WCChatSelfWasKickedFromPublicChatNotification	= @"WCChatSelfWasKickedFromPublicChatNotification";
NSString * const WCChatSelfWasBannedNotification				= @"WCChatSelfWasBannedNotification";
NSString * const WCChatSelfWasDisconnectedNotification			= @"WCChatSelfWasDisconnectedNotification";
NSString * const WCChatRegularChatDidAppearNotification			= @"WCChatRegularChatDidAppearNotification";
NSString * const WCChatHighlightedChatDidAppearNotification		= @"WCChatHighlightedChatDidAppearNotification";
NSString * const WCChatEventDidAppearNotification				= @"WCChatEventDidAppearNotification";

NSString * const WCChatHighlightColorKey						= @"WCChatHighlightColorKey";

NSString * const WCUserPboardType								= @"WCUserPboardType";


enum _WCChatFormat {
	WCChatPlainText,
	WCChatRTF,
	WCChatRTFD,
};
typedef enum _WCChatFormat					WCChatFormat;


@interface WCChatController(Private)

- (void)_updatePreferences;
- (void)_updateSaveChatForPanel:(NSSavePanel *)savePanel;

- (void)_setTopic:(WCTopic *)topic;

- (void)_printString:(NSString *)message;
- (void)_printTimestamp;
- (void)_printTopic;
- (void)_printUserJoin:(WCUser *)user;
- (void)_printUserLeave:(WCUser *)user;
- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick;
- (void)_printUserChange:(WCUser *)user status:(NSString *)status;
- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message;
- (void)_printUserBan:(WCUser *)victim message:(NSString *)message;
- (void)_printUserDisconnect:(WCUser *)victim message:(NSString *)message;
- (void)_printChat:(NSString *)chat by:(WCUser *)user;
- (void)_printActionChat:(NSString *)chat by:(WCUser *)user;

- (NSArray *)_commands;
- (BOOL)_runCommand:(NSString *)command;

- (NSString *)_stringByCompletingString:(NSString *)string;
- (void)_applyChatAttributesToAttributedString:(NSMutableAttributedString *)attributedString;

- (NSColor *)_highlightColorForChat:(NSString *)chat;

@end


@implementation WCChatController(Private)

- (void)_updatePreferences {
	NSMutableArray		*highlightPatterns, *highlightColors;
	NSEnumerator		*enumerator;
	NSDictionary		*highlight;
	
	highlightPatterns	= [NSMutableArray array];
	highlightColors		= [NSMutableArray array];
	
	enumerator = [[[WCSettings settings] objectForKey:WCHighlights] objectEnumerator];
	
	while((highlight = [enumerator nextObject])) {
		[highlightPatterns addObject:[highlight objectForKey:WCHighlightsPattern]];
		[highlightColors addObject:WIColorFromString([highlight objectForKey:WCHighlightsColor])];
	}
	
	if(![highlightPatterns isEqualToArray:_highlightPatterns] || ![highlightColors isEqualToArray:_highlightColors]) {
		[_highlightPatterns setArray:highlightPatterns];
		[_highlightColors setArray:highlightColors];
	
		[self _applyChatAttributesToAttributedString:[_chatOutputTextView textStorage]];
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

- (void)_setTopic:(WCTopic *)topic {
	[topic retain];
	[_topic release];
	
	_topic = topic;
	
	if([[_topic topic] length] > 0) {
		[_topicTextField setToolTip:[_topic topic]];
		[_topicTextField setStringValue:[_topic topic]];
		[_topicNickTextField setStringValue:[NSSWF:
			 NSLS(@"%@ \u2014 %@", @"Chat topic set by (nick, time)"),
			 [_topic nick],
			 [_topicDateFormatter stringFromDate:[_topic date]]]];
	} else {
		[_topicTextField setToolTip:NULL];
		[_topicTextField setStringValue:@""];
		[_topicNickTextField setStringValue:@""];
	}
}



#pragma mark -

- (void)_printString:(NSString *)string {
	NSMutableAttributedString	*attributedString;
	CGFloat						position;
	BOOL						wasEnabled;
	
	position	= [[_chatOutputScrollView verticalScroller] floatValue];
	wasEnabled	= [[_chatOutputScrollView verticalScroller] isEnabled];
	
	if([[_chatOutputTextView textStorage] length] > 0)
		[[[_chatOutputTextView textStorage] mutableString] appendString:@"\n"];
	
	attributedString = [NSMutableAttributedString attributedStringWithString:string];
	
	[self _applyChatAttributesToAttributedString:attributedString];
	[[self class] applyURLAttributesToAttributedString:attributedString];
	
	if(_showSmileys)
		[[self class] applySmileyAttributesToAttributedString:attributedString];
	
	[[_chatOutputTextView textStorage] appendAttributedString:attributedString];
	
	if(position == 1.0 || !wasEnabled)
		[_chatOutputTextView performSelectorOnce:@selector(scrollToBottom) withObject:NULL afterDelay:0.05];
}



- (void)_printTimestamp {
	NSDate			*date;
	NSTimeInterval	interval;
	
	if(!_timestamp)
		_timestamp = [[NSDate date] retain];
	
	interval = [[[WCSettings settings] objectForKey:WCChatTimestampChatInterval] doubleValue];
	date = [NSDate dateWithTimeIntervalSinceNow:-interval];
	
	if([date compare:_timestamp] == NSOrderedDescending) {
		[self printEvent:[_timestampDateFormatter stringFromDate:[NSDate date]]];
		
		[_timestamp release];
		_timestamp = [[NSDate date] retain];
	}
}



- (void)_printTopic {
	[self printEvent:[NSSWF: NSLS(@"%@ changed topic to %@", @"Topic changed (nick, topic)"),
		[_topic nick], [_topic topic]]];
}



- (void)_printUserJoin:(WCUser *)user {
	[self printEvent:[NSSWF:NSLS(@"%@ has joined", @"User has joined message (nick)"),
		[user nick]]];
}



- (void)_printUserLeave:(WCUser *)user {
	[self printEvent:[NSSWF:NSLS(@"%@ has left", @"User has left message (nick)"),
		[user nick]]];
}



- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick {
	[self printEvent:[NSSWF:NSLS(@"%@ is now known as %@", @"User rename message (oldnick, newnick)"),
		[user nick], nick]];
}



- (void)_printUserChange:(WCUser *)user status:(NSString *)status {
	[self printEvent:[NSSWF:NSLS(@"%@ changed status to %@", @"User status changed message (nick, status)"),
		[user nick], status]];
}



- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:NSLS(@"%@ was kicked by %@ (%@)", @"User kicked message (victim, killer, message)"),
			[victim nick], [killer nick], message]];
	} else {
		[self printEvent:[NSSWF:NSLS(@"%@ was kicked by %@", @"User kicked message (victim, killer)"),
			[victim nick], [killer nick]]];
	}
}



- (void)_printUserBan:(WCUser *)victim message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:NSLS(@"%@ was banned (%@)", @"User banned message (victim, message)"),
			[victim nick], message]];
	} else {
		[self printEvent:[NSSWF:NSLS(@"%@ was banned", @"User banned message (victim)"),
			[victim nick]]];
	}
}



- (void)_printUserDisconnect:(WCUser *)victim message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:NSLS(@"%@ was disconnected (%@)", @"User disconnected message (victim, message)"),
			[victim nick], message]];
	} else {
		[self printEvent:[NSSWF:NSLS(@"%@ was disconnected", @"User disconnected message (victim)"),
			[victim nick]]];
	}
}



- (void)_printChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output, *nick;
	NSInteger	offset, length;
	BOOL		timestamp;
	
	timestamp	= [[[self connection] theme] boolForKey:WCThemesChatTimestampEveryLine];
	offset		= timestamp ? WCChatPrepend - 4 : WCChatPrepend;
	nick		= [user nick];
	length		= offset - [nick length];
	
	if(length < 0)
		nick = [nick substringToIndex:offset];
	
	output = [NSSWF:NSLS(@"%@: %@", @"Chat message, Wired style (nick, message)"),
		nick, chat];
	
	if(length > 0)
		output = [NSSWF:@"%*s%@", length, " ", output];
	
	if(timestamp)
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];
	
	[self _printString:output];
}



- (void)_printActionChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output;
	
	output = [NSSWF:NSLS(@" *** %@ %@", @"Action chat message, Wired style (nick, message)"),
		[user nick], chat];
	
	if([[[self connection] theme] boolForKey:WCThemesChatTimestampEveryLine])
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
		@"/afk",
		NULL];
}



- (BOOL)_runCommand:(NSString *)string {
	NSString		*command, *argument;
	WIP7Message		*message;
	NSRange			range;
	NSUInteger		transaction;
	
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
		
		message = [WIP7Message messageWithName:@"wired.chat.send_me" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:argument forName:@"wired.chat.me"];
		[[self connection] sendMessage:message];
		
		[[WCStats stats] addUnsignedLongLong:[argument length] forKey:WCStatsChat];
		
		return YES;
	}
	else if([command isEqualToString:@"/exec"] && [argument length] > 0) {
		NSString			*output;
		
		output = [[self class] outputForShellCommand:argument];
		
		if(output && [output length] > 0) {
			if([output length] > WCChatLimit)
				output = [output substringToIndex:WCChatLimit];
			
			message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
			[message setUInt32:[self chatID] forName:@"wired.chat.id"];
			[message setString:output forName:@"wired.chat.say"];
			[[self connection] sendMessage:message];
		}
		
		return YES;
	}
	else if(([command isEqualToString:@"/nick"] ||
			 [command isEqualToString:@"/n"]) && [argument length] > 0) {
		message = [WIP7Message messageWithName:@"wired.user.set_nick" spec:WCP7Spec];
		[message setString:argument forName:@"wired.user.nick"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/status"] || [command isEqualToString:@"/s"]){
		message = [WIP7Message messageWithName:@"wired.user.set_status" spec:WCP7Spec];
		[message setString:argument forName:@"wired.user.status"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/stats"]) {
		[self stats:self];
		
		return YES;
	}
	else if([command isEqualToString:@"/clear"]) {
		[[[_chatOutputTextView textStorage] mutableString] setString:@""];
		
		return YES;
	}
	else if([command isEqualToString:@"/topic"]) {
		message = [WIP7Message messageWithName:@"wired.chat.set_topic" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:argument forName:@"wired.chat.topic.topic"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/broadcast"] && [argument length] > 0) {
		message = [WIP7Message messageWithName:@"wired.message.send_broadcast" spec:WCP7Spec];
		[message setString:argument forName:@"wired.message.broadcast"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/ping"]) {
		message = [WIP7Message messageWithName:@"wired.send_ping" spec:WCP7Spec];
		transaction = [[self connection] sendMessage:message fromObserver:self selector:@selector(wiredSendPingReply:)];
		
		[_pings setObject:[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]]
				   forKey:[NSNumber numberWithUnsignedInt:transaction]];
		
		return YES;
	}
	else if([command isEqualToString:@"/afk"]) {
		message = [WIP7Message messageWithName:@"wired.user.set_idle" spec:WCP7Spec];
		[message setBool:YES forName:@"wired.user.idle"];
		[[self connection] sendMessage:message];
		
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
	
	nicks		= [self nicks];
	commands	= [self _commands];
	enumerator	= [[NSArray arrayWithObjects:nicks, commands, NULL] objectEnumerator];
	
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
		if(matchingSet == nicks)
			return [prefix stringByAppendingString:[[WCSettings settings] objectForKey:WCChatTabCompleteNicksString]];
		else if(matchingSet == commands)
			return [prefix stringByAppendingString:@" "];
	}
	
	return string;
}



- (void)_applyChatAttributesToAttributedString:(NSMutableAttributedString *)attributedString {
	static NSCharacterSet		*whitespaceSet, *nonWhitespaceSet, *nonTimestampSet, *nonHighlightSet;
	NSMutableCharacterSet		*characterSet;
	NSScanner					*scanner;
	NSString					*word, *chat;
	NSColor						*color;
	NSRange						range, nickRange;

	if(!whitespaceSet) {
		whitespaceSet		= [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonWhitespaceSet	= [[whitespaceSet invertedSet] retain];
		
		characterSet		= [[NSMutableCharacterSet decimalDigitCharacterSet] mutableCopy];
		[characterSet addCharactersInString:@":."];
		[characterSet invert];
		nonTimestampSet		= [characterSet copy];
		[characterSet release];
		
		nonHighlightSet		= [[NSCharacterSet alphanumericCharacterSet] retain];
	}
	
	range = NSMakeRange(0, [attributedString length]);
	
	[attributedString addAttribute:NSForegroundColorAttributeName value:_chatColor range:range];
	[attributedString addAttribute:NSFontAttributeName value:_chatFont range:range];
	
	scanner = [NSScanner scannerWithString:[attributedString string]];
	[scanner setCharactersToBeSkipped:NULL];

	while(![scanner isAtEnd]) {
		[scanner skipUpToCharactersFromSet:nonWhitespaceSet];
		range.location = [scanner scanLocation];
		
		if(![scanner scanUpToCharactersFromSet:whitespaceSet intoString:&word])
			break;
		
		range.length = [scanner scanLocation] - range.location;
		
		if([word rangeOfCharacterFromSet:nonTimestampSet].location == NSNotFound ||
		   [word isEqualToString:@"PM"] || [word isEqualToString:@"AM"]) {
			[attributedString addAttribute:NSForegroundColorAttributeName value:_timestampEveryLineColor range:range];
			
			continue;
		}
		
		if([word isEqualToString:@"<<<"]) {
			if([scanner scanUpToString:@">>>" intoString:NULL]) {
				range.length = [scanner scanLocation] - range.location + 3;

				[attributedString addAttribute:NSForegroundColorAttributeName value:_eventsColor range:range];
				
				[scanner scanUpToString:@"\n" intoString:NULL];

				continue;
			}
		}
		
		if([word isEqualToString:@"*"] || [word isEqualToString:@"***"]) {
			[scanner scanUpToString:@"\n" intoString:NULL];

			continue;
		}
		
		nickRange = range;

		if([word hasSuffix:@":"]) {
			nickRange.length--;

			if(![scanner isAtEnd])
				[scanner setScanLocation:[scanner scanLocation] + 1];
		} else {
			[scanner scanUpToString:@":" intoString:NULL];
			
			nickRange.length = [scanner scanLocation] - range.location;

			if(![scanner isAtEnd])
			   [scanner setScanLocation:[scanner scanLocation] + 1];
		}
		
		if([scanner scanUpToString:@"\n" intoString:&chat]) {
			color = [self _highlightColorForChat:chat];
			
			if(color != NULL)
				[attributedString addAttribute:NSForegroundColorAttributeName value:color range:nickRange];
		}
	}
}



#pragma mark -

- (NSColor *)_highlightColorForChat:(NSString *)chat {
	NSCharacterSet		*alphanumericCharacterSet;
	NSRange				range;
	NSUInteger			i, count, length, index;
	
	alphanumericCharacterSet	= [NSCharacterSet alphanumericCharacterSet];
	length						= [chat length];
	count						= [_highlightPatterns count];
	
	for(i = 0; i < count; i++) {
		range = [chat rangeOfString:[_highlightPatterns objectAtIndex:i] options:NSCaseInsensitiveSearch];

		if(range.location != NSNotFound) {
			index = range.location + range.length;
			
			if(index == length || ![alphanumericCharacterSet characterIsMember:[chat characterAtIndex:index]])
				return [_highlightColors objectAtIndex:i];
		}
	}
	
	return NULL;
}

@end



@implementation WCChatController

+ (NSString *)outputForShellCommand:(NSString *)command {
	NSTask				*task;
	NSPipe				*pipe;
	NSFileHandle		*fileHandle;
	NSDictionary		*environment;
	NSData				*data;
	double				timeout = 5.0;
	
	pipe = [NSPipe pipe];
	fileHandle = [pipe fileHandleForReading];
	
	environment	= [NSDictionary dictionaryWithObject:@"/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin" forKey:@"PATH"];
	
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



+ (void)applyURLAttributesToAttributedString:(NSMutableAttributedString *)attributedString {
	static NSCharacterSet	*whitespaceSet, *nonWhitespaceSet, *skipSet;
	CFStringRef				string, word, subWord;
	CFRange					searchRange, foundRange, wordRange, subRange;
	WIURL					*url;
	NSUInteger				length, wordLength, i;
	CFIndex					index;
	BOOL					interesting;
	
	if(!whitespaceSet) {
		whitespaceSet		= [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonWhitespaceSet	= [[whitespaceSet invertedSet] retain];
		skipSet				= [[NSCharacterSet characterSetWithCharactersInString:@",.?()[]{}<>"] retain];
	}
	
	string = (CFStringRef) [attributedString string];
	length = CFStringGetLength(string);

	searchRange.location = 0;
	searchRange.length = length;
	
	while(searchRange.location != kCFNotFound) {
		if(!CFStringFindCharacterFromSet(string, (CFCharacterSetRef) nonWhitespaceSet, searchRange, 0, &foundRange))
			break;
		
		wordRange.location = foundRange.location;
		searchRange.location = foundRange.location;
		searchRange.length = length - searchRange.location;

		if(!CFStringFindCharacterFromSet(string, (CFCharacterSetRef) whitespaceSet, searchRange, 0, &foundRange)) {
			wordRange.length = length - wordRange.location;
			searchRange.location = kCFNotFound;
		} else {
			wordRange.length = foundRange.location - wordRange.location;
			searchRange.location = foundRange.location + foundRange.length;
			searchRange.length = length - searchRange.location;
		}
		
		if(wordRange.length >= 8) {
			word = CFStringCreateWithSubstring(NULL, string, wordRange);
			
			interesting = NO;
			
			if(!interesting) {
				index = CFStringFind(string, CFSTR("://"), 0).location;
				
				if(index != kCFNotFound && index != 0)
					interesting = YES;
			}
			
			if(!interesting) {
				index = CFStringFind(string, CFSTR("www."), 0).location;
				
				if(index != kCFNotFound && index != 0)
					interesting = YES;
			}

			if(interesting) {
				i = 0;
				wordLength = wordRange.length;
				subRange.location = 0;
				subRange.length = wordLength;
				
				while(i < wordLength && CFCharacterSetIsCharacterMember((CFCharacterSetRef) skipSet, CFStringGetCharacterAtIndex(word, i))) {
					wordRange.location++;
					wordRange.length--;

					subRange.location++;
					subRange.length--;

					i++;
				}
				
				if(subRange.length == 0) {
					CFRelease(word);
					
					continue;
				}
				
				i = wordLength;
				
				while(i > 0 && CFCharacterSetIsCharacterMember((CFCharacterSetRef) skipSet, CFStringGetCharacterAtIndex(word, i - 1))) {
					wordRange.length--;
					subRange.length--;
					
					i--;
				}
				
				if(subRange.length == 0) {
					CFRelease(word);
					
					continue;
				}
				
				if((NSUInteger) subRange.length != wordLength) {
					subWord = CFStringCreateWithSubstring(NULL, word, subRange);
					
					CFRelease(word);
					word = subWord;
				}
				
				url = [WIURL URLWithString:(NSString *) word];
				
				if(url) {
					[attributedString addAttribute:NSLinkAttributeName
											 value:[url URL]
											 range:NSMakeRange(wordRange.location, wordRange.length)];
				}
			}
	
			CFRelease(word);
		}
	}
}



+ (void)applySmileyAttributesToAttributedString:(NSMutableAttributedString *)attributedString {
	static NSCharacterSet		*whitespaceSet;
	WCApplicationController		*controller;
	NSDictionary				*attributes;
	NSMutableString				*string;
	NSAttributedString			*smileyString;
	NSFileWrapper				*wrapper;
	NSTextAttachment			*attachment;
	NSEnumerator				*enumerator;
	NSString					*key, *substring, *smiley, *character;
	NSRange						range, searchRange;
	NSUInteger					length, options;
	BOOL						found;
	
	if(!whitespaceSet)
		whitespaceSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		
	controller	= [WCApplicationController sharedController];
	string		= [attributedString mutableString];
	length		= [attributedString length];
	enumerator	= [[controller allSmileys] objectEnumerator];
	
	while((key = [enumerator nextObject])) {
		searchRange.location = 0;
		searchRange.length = length;
		
		while((range = [string rangeOfString:key options:NSCaseInsensitiveSearch range:searchRange]).location != NSNotFound) {
			found = NO;
			
			if(!((range.location > 0 &&
				![whitespaceSet characterIsMember:[string characterAtIndex:range.location - 1]]) ||
			   (range.location + range.length < length &&
				![whitespaceSet characterIsMember:[string characterAtIndex:range.location + range.length]]))) {
				substring	= [string substringWithRange:range];
				smiley		= [controller pathForSmiley:substring];
				
				if(smiley) {
					attributes = [attributedString attributesAtIndex:range.location effectiveRange:NULL];
					
					if(![attributes objectForKey:NSLinkAttributeName]) {
						wrapper					= [[NSFileWrapper alloc] initWithPath:smiley];
						attachment				= [[WITextAttachment alloc] initWithFileWrapper:wrapper string:substring];
						smileyString			= [NSAttributedString attributedStringWithAttachment:attachment];
						
						[attributedString replaceCharactersInRange:range withAttributedString:smileyString];
						
						length					-= range.length - 1;
						searchRange.location	= range.location + 1;
						searchRange.length		= length - searchRange.location;
						
						range.length			= 1;
						character				= [substring substringFromIndex:[substring length] - 1];
						options					= NSCaseInsensitiveSearch | NSAnchoredSearch;
						
						while((range = [string rangeOfString:character options:options range:searchRange]).location != NSNotFound) {
							[attributedString replaceCharactersInRange:range withAttributedString:attributedString];
							
							searchRange.location++;
							searchRange.length--;
						}
						
						[attachment release];
						[wrapper release];
						
						found = YES;
					}
				}
			}
			
			if(!found) {
				searchRange.location = range.location + range.length;
				searchRange.length = length - searchRange.location;
			}
		}
	}
}



+ (NSString *)stringByDecomposingSmileyAttributesInAttributedString:(NSAttributedString *)attributedString {
	if(![attributedString containsAttachments])
		return [[[attributedString string] copy] autorelease];
	
	return [[attributedString attributedStringByReplacingAttachmentsWithStrings] string];
}



+ (NSString *)URLRegex {
	return @"(?:[a-zA-Z0-9\\-]+)"										/* Scheme */
		   @"://"														/* "://" */
		   @"(?:(?:\\S+?)(?::(?:\\S+?))?@)?"							/* Password and user */
		   @"(?:[a-zA-Z0-9\\-.]+)"										/* Host name */
		   @"(?::(?:\\d+))?"											/* Port */
		   @"(?:(?:/[a-zA-Z0-9\\-._\\?,'+\\&;%#$=~*!():@\\\\]*)+)?";	/* Path */
}



+ (NSString *)schemelessURLRegex {
	return @"(?:www\\.[a-zA-Z0-9\\-.]+)"								/* Host name */
		   @"(?::(?:\\d+))?"											/* Port */
		   @"(?:(?:/[a-zA-Z0-9\\-._?,'+\\&;%#$=~*!():@\\\\]*)+)?";		/* Path */
}



+ (NSString *)mailtoURLRegex {
	return @"(?:[a-zA-Z0-9%_.+\\-]+)"									/* User */
		   @"@"															/* "@" */
		   @"(?:[a-zA-Z0-9.\\-]+?\\.[a-zA-Z]{2,6})";					/* Host name */
}



+ (NSDictionary *)smileyRegexs {
	static NSMutableDictionary	*smileyRegexs;
	NSEnumerator				*enumerator;
	NSMutableString				*regex;
	NSString					*smiley;
	
	if(!smileyRegexs) {
		smileyRegexs	= [[NSMutableDictionary alloc] init];
		enumerator		= [[[WCApplicationController sharedController] allSmileys] objectEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			regex = [[smiley mutableCopy] autorelease];
			
			[regex replaceOccurrencesOfString:@"." withString:@"\\."];
			[regex replaceOccurrencesOfString:@"*" withString:@"\\*"];
			[regex replaceOccurrencesOfString:@"+" withString:@"\\+"];
			[regex replaceOccurrencesOfString:@"^" withString:@"\\^"];
			[regex replaceOccurrencesOfString:@"$" withString:@"\\$"];
			[regex replaceOccurrencesOfString:@"(" withString:@"\\("];
			[regex replaceOccurrencesOfString:@")" withString:@"\\)"];
			[regex replaceOccurrencesOfString:@"[" withString:@"\\["];
			[regex replaceOccurrencesOfString:@"]" withString:@"\\]"];
			[regex replaceOccurrencesOfString:@"-" withString:@"\\-"];
			
			[smileyRegexs setObject:regex forKey:smiley];
			
			if([smiley containsSubstring:@">"]) {
				[regex replaceOccurrencesOfString:@">" withString:@"&#62;"];
				
				[smileyRegexs setObject:regex forKey:smiley];
			}
		}
	}
	
	return smileyRegexs;
}



#pragma mark -

- (id)init {
	self = [super init];
	
	_commandHistory			= [[NSMutableArray alloc] init];
	_users					= [[NSMutableDictionary alloc] init];
	_allUsers				= [[NSMutableArray alloc] init];
	_shownUsers				= [[NSMutableArray alloc] init];
	_pings					= [[NSMutableDictionary alloc] init];
	_highlightPatterns		= [[NSMutableArray alloc] init];
	_highlightColors		= [[NSMutableArray alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(dateDidChange:)
			   name:WCDateDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_connection removeObserver:self];
	
	[_errorQueue release];
	
	if(_loadedNib) {
		[_userListMenu release];
		[_setTopicPanel release];
		[_kickMessagePanel release];
	}
	
	[_saveChatView release];
	
	[_connection release];
	
	[_users release];
	[_allUsers release];
	[_shownUsers release];
	
	[_commandHistory release];
	
	[_chatColor release];
	[_eventsColor release];
	[_timestampEveryLineColor release];
	[_highlightPatterns release];
	[_highlightColors release];
	
	[_timestamp release];
	[_topic release];
	
	[_timestampDateFormatter release];
	[_timestampEveryLineDateFormatter release];
	[_topicDateFormatter release];
	
	[_pings release];

	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	[_userListTableView setTarget:self];
	[_userListTableView setDoubleAction:@selector(sendPrivateMessage:)];
	
	_timestampDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_timestampDateFormatter setDateStyle:NSDateFormatterShortStyle];
	
	_timestampEveryLineDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampEveryLineDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	_topicDateFormatter = [[WIDateFormatter alloc] init];
	[_topicDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_topicDateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_topicDateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _updatePreferences];
}



#pragma mark -

- (void)themeDidChange:(NSDictionary *)theme {
	NSFont			*font;
	NSColor			*color;
	BOOL			reload = NO;
	
	font = WIFontFromString([theme objectForKey:WCThemesChatFont]);

	if(![[_chatOutputTextView font] isEqualTo:font]) {
		[_chatOutputTextView setFont:font];
		[_chatInputTextView setFont:font];
		[_setTopicTextView setFont:font];
		
		[_chatFont release];
		_chatFont = [font retain];
	}
	
	color = WIColorFromString([theme objectForKey:WCThemesChatBackgroundColor]);

	if(![[_chatOutputTextView backgroundColor] isEqualTo:color]) {
		[_chatOutputTextView setBackgroundColor:color];
		[_chatInputTextView setBackgroundColor:color];
		[_setTopicTextView setBackgroundColor:color];
	}

	color = WIColorFromString([theme objectForKey:WCThemesChatTextColor]);

	if(![color isEqualTo:_chatColor]) {
		[_chatOutputTextView setTextColor:color];
		[_chatInputTextView setTextColor:color];
		[_chatInputTextView setInsertionPointColor:color];
		[_setTopicTextView setTextColor:color];
		[_setTopicTextView setInsertionPointColor:color];

		[_chatColor release];
		_chatColor = [color retain];
	
		reload = YES;
	}
	
	color = WIColorFromString([theme objectForKey:WCThemesChatEventsColor]);
	
	if(![color isEqualTo:_eventsColor]) {
		[_eventsColor release];
		_eventsColor = [color retain];
	
		reload = YES;
	}
	
	color = WIColorFromString([theme objectForKey:WCThemesChatTimestampEveryLineColor]);
	
	if(![color isEqualTo:_timestampEveryLineColor]) {
		[_timestampEveryLineColor release];
		_timestampEveryLineColor = [color retain];
		
		reload = YES;
	}
	
	if([theme boolForKey:WCThemesShowSmileys] != _showSmileys) {
		_showSmileys = !_showSmileys;
		
		if(_showSmileys) {
			[[self class] applySmileyAttributesToAttributedString:[_chatOutputTextView textStorage]];
		} else {
			[[_chatOutputTextView textStorage] replaceAttachmentsWithStrings];
		
			reload = YES;
		}
	}

	[_chatOutputTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		WIColorFromString([theme objectForKey:WCThemesChatURLsColor]),
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];
	
	if(reload)
		[self _applyChatAttributesToAttributedString:[_chatOutputTextView textStorage]];

	[_userListTableView setUsesAlternatingRowBackgroundColors:[[theme objectForKey:WCThemesUserListAlternateRows] boolValue]];
	
	switch([[theme objectForKey:WCThemesUserListIconSize] integerValue]) {
		case WCThemesUserListIconSizeLarge:
			[_userListTableView setRowHeight:35.0];
			
			[_iconTableColumn setWidth:[_iconTableColumn maxWidth]];
			[[_nickTableColumn dataCell] setControlSize:NSRegularControlSize];
			break;

		case WCThemesUserListIconSizeSmall:
			[_userListTableView setRowHeight:17.0];

			[_iconTableColumn setWidth:[_iconTableColumn minWidth]];
			[[_nickTableColumn dataCell] setControlSize:NSSmallControlSize];
			break;
	}
	
	[_userListTableView sizeLastColumnToFit];
	[_userListTableView setNeedsDisplay:YES];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _updatePreferences];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[_users removeAllObjects];
	[_shownUsers removeAllObjects];
	[_userListTableView reloadData];
}



- (void)serverConnectionThemeDidChange:(NSNotification *)notification {
	[self themeDidChange:[_connection theme]];
}



- (void)wiredSendPingReply:(WIP7Message *)message {
	NSNumber			*number;
	NSTimeInterval		interval;
	NSUInteger			transaction;
	
	[message getUInt32:&transaction forName:@"wired.transaction"];
	
	number = [_pings objectForKey:[NSNumber numberWithUnsignedInt:transaction]];
	
	if(number) {
		interval = [NSDate timeIntervalSinceReferenceDate] - [number doubleValue];
		
		[self printEvent:[NSSWF:
			NSLS(@"Received ping reply after %.2fms", @"Ping received message (interval)"),
			interval * 1000.0]];
		
		[_pings removeObjectForKey:number];
	}
}



- (void)dateDidChange:(NSNotification *)notification {
	[self _setTopic:_topic];
}



- (void)chatUsersDidChange:(NSNotification *)notification {
	[_userListTableView reloadData];
}



- (void)wiredChatJoinChatReply:(WIP7Message *)message {
	WCUser			*user;
	WCTopic			*topic;
	NSUInteger		i, count;
	
	if([[message name] isEqualToString:@"wired.chat.user_list"]) {
		user = [WCUser userWithMessage:message connection:[self connection]];
		
		[_allUsers addObject:user];
		[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	}
	else if([[message name] isEqualToString:@"wired.chat.user_list.done"]) {
		[_shownUsers addObjectsFromArray:_allUsers];
		[_allUsers removeAllObjects];
		
		count = [_shownUsers count];
		
		for(i = 0; i < count; i++)
			[[self connection] postNotificationName:WCChatUserAppearedNotification object:[_shownUsers objectAtIndex:i]];
		
		_receivedUserList = YES;
		
		[_userListTableView reloadData];
	}
	else if([[message name] isEqualToString:@"wired.chat.topic"]) {
		topic = [WCTopic topicWithMessage:message];
		
		[self _setTopic:topic];
		
		[[self connection] removeObserver:self message:message];
	}
}



- (void)wiredUserGetInfoReply:(WIP7Message *)message {
	WCUser		*user;
	
	if([[message name] isEqualToString:@"wired.user.info"]) {
		user = [WCUser userWithMessage:message connection:[self connection]];
	
		[[[[self connection] administration] accountsController] editUserAccountWithName:[user login]];
		
		[[self connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[[self connection] removeObserver:self message:message];
	}
}



- (void)wiredChatKickUserReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.okay"]) {
		[[self connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[[self connection] removeObserver:self message:message];
	}
}



- (void)wiredChatUserJoin:(WIP7Message *)message {
	WCUser			*user;
	WIP7UInt32		cid;
	
	if(!_receivedUserList)
		return;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	user = [WCUser userWithMessage:message connection:[self connection]];
	
	[_shownUsers addObject:user];
	[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	
	[_userListTableView reloadData];

	if([[[WCSettings settings] eventWithTag:WCEventsUserJoined] boolForKey:WCEventsPostInChat])
		[self _printUserJoin:user];
	
	[[self connection] postNotificationName:WCChatUserAppearedNotification object:user];
	
	[[self connection] triggerEvent:WCEventsUserJoined info1:user];
}



- (void)wiredChatUserLeave:(WIP7Message *)message {
	WCUser			*user;
	WIP7UInt32		cid, uid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != WCPublicChatID && cid != [self chatID])
		return;
	
	[message getUInt32:&uid forName:@"wired.user.id"];
	
	user = [self userWithUserID:uid];
	
	if(!user)
		return;
	
	if([[[WCSettings settings] eventWithTag:WCEventsUserLeft] boolForKey:WCEventsPostInChat])
		[self _printUserLeave:user];
	
	[[self connection] triggerEvent:WCEventsUserLeft info1:user];
	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:user];
	
	[_shownUsers removeObject:user];
	[_users removeObjectForKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	
	[_userListTableView reloadData];
}



- (void)wiredChatTopic:(WIP7Message *)message {
	WCTopic		*topic;
	
	topic = [WCTopic topicWithMessage:message];
	
	if([topic chatID] != [self chatID])
		return;
	
	[self _setTopic:topic];
	
	if([[_topic topic] length] > 0)
		[self _printTopic];
}



- (void)wiredChatSayOrMe:(WIP7Message *)message {
	NSString		*name, *chat;
	NSColor			*color;
	WCUser			*user;
	WIP7UInt32		cid, uid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	[message getUInt32:&uid forName:@"wired.user.id"];
	
	if(cid != [self chatID])
		return;
	
	user = [self userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;
	
	if([[WCSettings settings] boolForKey:WCChatTimestampChat])
		[self _printTimestamp];
	
	name = [message name];
	chat = [message stringForName:name];
	
	if([name isEqualToString:@"wired.chat.say"])
		[self _printChat:chat by:user];
	else
		[self _printActionChat:chat by:user];
	
	color = [self _highlightColorForChat:chat];
	
	if(color != NULL) {
		[[self connection] postNotificationName:WCChatHighlightedChatDidAppearNotification
										 object:[self connection]
									   userInfo:[NSDictionary dictionaryWithObject:color forKey:WCChatHighlightColorKey]];

		[[self connection] triggerEvent:WCEventsHighlightedChatReceived info1:user info2:chat];
	} else {
		[[self connection] postNotificationName:WCChatRegularChatDidAppearNotification object:[self connection]];
		
		[[self connection] triggerEvent:WCEventsChatReceived info1:user info2:chat];
	}
}



- (void)wiredChatUserKick:(WIP7Message *)message {
	NSString		*disconnectMessage;
	WIP7UInt32		killerUserID, victimUserID;
	WCUser			*killer, *victim;
	WIP7UInt32		cid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	[message getUInt32:&killerUserID forName:@"wired.user.id"];
	[message getUInt32:&victimUserID forName:@"wired.user.disconnected_id"];
	
	killer = [self userWithUserID:killerUserID];
	victim = [self userWithUserID:victimUserID];
	
	if(!killer || !victim)
		return;
	
	disconnectMessage = [message stringForName:@"wired.user.disconnect_message"];
	
	[self _printUserKick:victim by:killer message:disconnectMessage];
	
	if(cid == WCPublicChatID && [victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasKickedFromPublicChatNotification object:[self connection]];
	
	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:victim];
	
	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:victimUserID]];
	
	[_userListTableView reloadData];
}



- (void)wiredChatUserDisconnect:(WIP7Message *)message {
	NSString		*disconnectMessage;
	WIP7UInt32		victimUserID;
	WCUser			*victim;
	WIP7UInt32		cid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	[message getUInt32:&victimUserID forName:@"wired.user.disconnected_id"];
	
	victim = [self userWithUserID:victimUserID];
	
	if(!victim)
		return;
	
	disconnectMessage = [message stringForName:@"wired.user.disconnect_message"];
	
	[self _printUserDisconnect:victim message:disconnectMessage];
	
	if(cid == WCPublicChatID && [victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasDisconnectedNotification object:[self connection]];
	
	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:victim];
	
	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:victimUserID]];
	
	[_userListTableView reloadData];
}



- (void)wiredChatUserBan:(WIP7Message *)message {
	NSString		*disconnectMessage;
	WIP7UInt32		victimUserID;
	WCUser			*victim;
	WIP7UInt32		cid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	[message getUInt32:&victimUserID forName:@"wired.user.disconnected_id"];
	
	victim = [self userWithUserID:victimUserID];
	
	if(!victim)
		return;
	
	disconnectMessage = [message stringForName:@"wired.user.disconnect_message"];
	
	[self _printUserBan:victim message:disconnectMessage];
	
	if(cid == WCPublicChatID && [victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasBannedNotification object:[self connection]];
	
	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:victim];
	
	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:victimUserID]];
	
	[_userListTableView reloadData];
}



- (void)wiredChatUserStatus:(WIP7Message *)message {
	NSString		*nick, *status;
	WCUser			*user;
	WIP7UInt32		cid, uid;
	WIP7Enum		color;
	WIP7Bool		idle;
	BOOL			nickChanged = NO;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;

	[message getUInt32:&uid forName:@"wired.user.id"];
	
	user = [self userWithUserID:uid];
	
	if(!user)
		return;
	
	nick = [message stringForName:@"wired.user.nick"];
	
	if(![nick isEqualToString:[user nick]]) {
		if([[[WCSettings settings] eventWithTag:WCEventsUserChangedNick] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user nick:nick];
		
		[[self connection] triggerEvent:WCEventsUserChangedNick info1:user info2:nick];
	
		[user setNick:nick];
		
		nickChanged = YES;
	}
	
	status = [message stringForName:@"wired.user.status"];
	
	if(![status isEqualToString:[user status]]) {
		if([[[WCSettings settings] eventWithTag:WCEventsUserChangedStatus] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user status:status];
		
		[[self connection] triggerEvent:WCEventsUserChangedStatus info1:user info2:status];
	
		[user setStatus:status];
	}
	
	[message getBool:&idle forName:@"wired.user.idle"];
	
	[user setIdle:idle];
	
	if([message getEnum:&color forName:@"wired.account.color"])
		[user setColor:color];
	
	[_userListTableView setNeedsDisplay:YES];
	
	if(nickChanged)
		[[self connection] postNotificationName:WCChatUserNickDidChangeNotification object:user];
}



- (void)wiredChatUserIcon:(WIP7Message *)message {
	NSImage			*image;
	WCUser			*user;
	WIP7UInt32		cid, uid;
	
	[message getUInt32:&cid forName:@"wired.chat.id"];
	
	if(cid != [self chatID])
		return;
	
	[message getUInt32:&uid forName:@"wired.user.id"];
	
	user = [self userWithUserID:uid];
	
	if(!user)
		return;
	
	image = [[NSImage alloc] initWithData:[message dataForName:@"wired.user.icon"]];
	[user setIcon:image];
	[image release];
	
	[_userListTableView setNeedsDisplay:YES];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	if(splitView == _userListSplitView)
		return proposedMin + 50.0;
	else if(splitView == _chatSplitView)
		return proposedMin + 15.0;
	
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



- (void)menuNeedsUpdate:(NSMenu *)menu {
	if(menu == _userListMenu) {
		if([[self selectedUser] isIgnored]) {
			[_ignoreMenuItem setTitle:NSLS(@"Unignore", "User list menu title")];
			[_ignoreMenuItem setAction:@selector(unignore:)];
		} else {
			[_ignoreMenuItem setTitle:NSLS(@"Ignore", "User list menu title")];
			[_ignoreMenuItem setAction:@selector(ignore:)];
		}
	}
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
	WIP7Message		*message;
	NSInteger		historyModifier;
	BOOL			commandKey, optionKey, controlKey, historyScrollback;
	
	commandKey	= [[NSApp currentEvent] commandKeyModifier];
	optionKey	= [[NSApp currentEvent] alternateKeyModifier];
	controlKey	= [[NSApp currentEvent] controlKeyModifier];
	
	historyScrollback = [[WCSettings settings] boolForKey:WCChatHistoryScrollback];
	historyModifier = [[WCSettings settings] integerForKey:WCChatHistoryScrollbackModifier];
	
	if(selector == @selector(insertNewline:) ||
	   selector == @selector(insertNewlineIgnoringFieldEditor:)) {
		NSString		*string;
		NSUInteger		length;
		
		string = [[self class] stringByDecomposingSmileyAttributesInAttributedString:[_chatInputTextView textStorage]];
		length = [string length];
		
		if(length == 0)
			return YES;
		
		if(length > WCChatLimit)
			string = [string substringToIndex:WCChatLimit];
		
		[_commandHistory addObject:[[string copy] autorelease]];
		_currentCommand = [_commandHistory count];
		
		if(![string hasPrefix:@"/"] || ![self _runCommand:string]) {
			if(selector == @selector(insertNewlineIgnoringFieldEditor:) ||
			   (selector == @selector(insertNewline:) && optionKey)) {
				message = [WIP7Message messageWithName:@"wired.chat.send_me" spec:WCP7Spec];
				[message setString:string forName:@"wired.chat.me"];
			} else {
				message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
				[message setString:string forName:@"wired.chat.say"];
			}
			
			[message setUInt32:[self chatID] forName:@"wired.chat.id"];
			[[self connection] sendMessage:message];
			
			[[WCStats stats] addUnsignedLongLong:[string UTF8StringLength] forKey:WCStatsChat];
		}
		
		[_chatInputTextView setString:@""];
		
		return YES;
	}
	else if(selector == @selector(insertTab:)) {
		if([[WCSettings settings] boolForKey:WCChatTabCompleteNicks]) {
			[_chatInputTextView setString:[self _stringByCompletingString:[_chatInputTextView string]]];
			
			return YES;
		}
	}
	else if(selector == @selector(cancelOperation:)) {
		[_chatInputTextView setString:@""];
		
		return YES;
	}
	else if(historyScrollback &&
			((selector == @selector(moveUp:) &&
			  historyModifier == WCChatHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToBeginningOfDocument:) &&
			  historyModifier == WCChatHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToBeginningOfParagraph:) &&
			  historyModifier == WCChatHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageUp:) &&
			  historyModifier == WCChatHistoryScrollbackModifierControl &&
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
	else if(historyScrollback &&
			((selector == @selector(moveDown:) &&
			  historyModifier == WCChatHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToEndOfDocument:) &&
			  historyModifier == WCChatHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToEndOfParagraph:) &&
			  historyModifier == WCChatHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageDown:) &&
			  historyModifier == WCChatHistoryScrollbackModifierControl &&
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
		
		[_setTopicTextView setFont:WIFontFromString([[[self connection] theme] objectForKey:WCThemesChatFont])];
	}
	else if(textView == _chatInputTextView) {
		value = [self chatTextView:textView doCommandBySelector:selector];
		
		[_chatInputTextView setFont:WIFontFromString([[[self connection] theme] objectForKey:WCThemesChatFont])];
	}
	
	return value;
}



#pragma mark -

- (NSString *)saveDocumentMenuItemTitle {
	return NSLS(@"Save Chat\u2026", @"Save menu item");
}



#pragma mark -

- (void)validate {
	BOOL	connected;
	
	connected = [[self connection] isConnected];
	
	if([_userListTableView selectedRow] < 0) {
		[_infoButton setEnabled:NO];
		[_privateMessageButton setEnabled:NO];
		[_kickButton setEnabled:NO];
	} else {
		[_infoButton setEnabled:([[[self connection] account] userGetInfo] && connected)];
		[_privateMessageButton setEnabled:connected];
		[_kickButton setEnabled:(([self chatID] != WCPublicChatID || [[[self connection] account] chatKickUsers]) && connected)];
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
		return ([[[self connection] account] userGetInfo] && [self selectedUser] != NULL && connected);
	else if(selector == @selector(kick:))
		return (([self chatID] != WCPublicChatID || [[[self connection] account] chatKickUsers]) && connected);
	else if(selector == @selector(editAccount:))
		return ([[[self connection] account] userGetInfo] && [[[self connection] account] accountEditUsers] && connected);
	
	return YES;
}



#pragma mark -

- (void)setConnection:(WCServerConnection *)connection {
	[connection retain];
	[_connection release];
	
	_connection = connection;
	
	[_connection addObserver:self
					selector:@selector(linkConnectionLoggedIn:)
						name:WCLinkConnectionLoggedInNotification];

	[_connection addObserver:self
					selector:@selector(serverConnectionThemeDidChange:)
						name:WCServerConnectionThemeDidChangeNotification];

	[_connection addObserver:self selector:@selector(wiredChatUserJoin:) messageName:@"wired.chat.user_join"];
	[_connection addObserver:self selector:@selector(wiredChatUserLeave:) messageName:@"wired.chat.user_leave"];
	[_connection addObserver:self selector:@selector(wiredChatTopic:) messageName:@"wired.chat.topic"];
	[_connection addObserver:self selector:@selector(wiredChatSayOrMe:) messageName:@"wired.chat.say"];
	[_connection addObserver:self selector:@selector(wiredChatSayOrMe:) messageName:@"wired.chat.me"];
	[_connection addObserver:self selector:@selector(wiredChatUserKick:) messageName:@"wired.chat.user_kick"];
	[_connection addObserver:self selector:@selector(wiredChatUserDisconnect:) messageName:@"wired.chat.user_disconnect"];
	[_connection addObserver:self selector:@selector(wiredChatUserBan:) messageName:@"wired.chat.user_ban"];
	[_connection addObserver:self selector:@selector(wiredChatUserStatus:) messageName:@"wired.chat.user_status"];
	[_connection addObserver:self selector:@selector(wiredChatUserIcon:) messageName:@"wired.chat.user_icon"];
	
	[self themeDidChange:[_connection theme]];
}



- (WCServerConnection *)connection {
	return _connection;
}



#pragma mark -

- (NSView *)view {
	return _userListSplitView;
}



- (void)awakeInWindow:(NSWindow *)window {
	[_errorQueue release];
	_errorQueue = [[WCErrorQueue alloc] initWithWindow:window];
}



- (void)loadWindowProperties {
	[_userListSplitView setPropertiesFromDictionary:
		[[[WCSettings settings] objectForKey:WCWindowProperties] objectForKey:@"WCChatControllerUserListSplitView"]];
	[_chatSplitView setPropertiesFromDictionary:
		[[[WCSettings settings] objectForKey:WCWindowProperties] objectForKey:@"WCChatControllerChatSplitView"]];
}



- (void)saveWindowProperties {
	[[WCSettings settings] setObject:[_userListSplitView propertiesDictionary]
							  forKey:@"WCChatControllerUserListSplitView"
				  inDictionaryForKey:WCWindowProperties];
	[[WCSettings settings] setObject:[_chatSplitView propertiesDictionary]
							  forKey:@"WCChatControllerChatSplitView"
				  inDictionaryForKey:WCWindowProperties];
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



- (WCUser *)userWithUserID:(NSUInteger)uid {
	return [_users objectForKey:[NSNumber numberWithInt:uid]];
}



- (void)selectUser:(WCUser *)user {
	NSUInteger	index;
	
	index = [_shownUsers indexOfObject:user];
	
	if(index != NSNotFound) {
		[_userListTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[_userListTableView scrollRowToVisible:index];
		[[_userListTableView window] makeFirstResponder:_userListTableView];
	}
}



- (NSUInteger)chatID {
	return WCPublicChatID;
}



- (NSTextView *)insertionTextView {
	return _chatInputTextView;
}



#pragma mark -

- (void)printEvent:(NSString *)message {
	NSString	*output;
	
	output = [NSSWF:NSLS(@"<<< %@ >>>", @"Chat event (message)"), message];
	
	if([[[self connection] theme] boolForKey:WCThemesChatTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];
	
	[self _printString:output];
	
	[[self connection] postNotificationName:WCChatEventDidAppearNotification object:[self connection]];
}



#pragma mark -

- (IBAction)saveDocument:(id)sender {
	[self saveChat:sender];
}



- (IBAction)stats:(id)sender {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[message setString:[[WCStats stats] stringValue] forName:@"wired.chat.say"];
	[[self connection] sendMessage:message];
}



- (IBAction)saveChat:(id)sender {
	const NSStringEncoding	*encodings;
	NSSavePanel				*savePanel;
	NSAttributedString		*attributedString;
	NSString				*name, *path, *string;
	WCChatFormat			format;
	NSStringEncoding		encoding;
	NSUInteger				i = 0;
	
	format		= [[WCSettings settings] intForKey:WCLastChatFormat];
	encoding	= [[WCSettings settings] intForKey:WCLastChatEncoding];
	
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
	
	if([savePanel runModalForDirectory:[[WCSettings settings] objectForKey:WCDownloadFolder] file:name] == NSFileHandlingPanelOKButton) {
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
	
	[[WCSettings settings] setInt:[_saveChatFileFormatPopUpButton tagOfSelectedItem] forKey:WCLastChatFormat];
	[[WCSettings settings] setInt:[_saveChatPlainTextEncodingPopUpButton tagOfSelectedItem] forKey:WCLastChatEncoding];
}



- (IBAction)setTopic:(id)sender {
	[_setTopicTextView setString:[_topicTextField stringValue]];
	[_setTopicTextView setSelectedRange:NSMakeRange(0, [[_setTopicTextView string] length])];
	
	[NSApp beginSheet:_setTopicPanel
	   modalForWindow:[_userListSplitView window]
		modalDelegate:self
	   didEndSelector:@selector(setTopicSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)setTopicSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.chat.set_topic" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:[_setTopicTextView string] forName:@"wired.chat.topic.topic"];
		[[self connection] sendMessage:message];
	}
	
	[_setTopicPanel close];
	[_setTopicTextView setString:@""];
}



- (IBAction)sendPrivateMessage:(id)sender {
	if(![_privateMessageButton isEnabled])
		return;
	
	[[WCMessages messages] showPrivateMessageToUser:[self selectedUser]];
}



- (IBAction)getInfo:(id)sender {
	[WCUserInfo userInfoWithConnection:[self connection] user:[self selectedUser]];
}



- (IBAction)kick:(id)sender {
	[NSApp beginSheet:_kickMessagePanel
	   modalForWindow:[_userListSplitView window]
		modalDelegate:self
	   didEndSelector:@selector(kickSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self selectedUser] retain]];
}



- (void)kickSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCUser			*user = contextInfo;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.chat.kick_user" spec:WCP7Spec];
		[message setUInt32:[user userID] forName:@"wired.user.id"];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:[_kickMessageTextField stringValue] forName:@"wired.user.disconnect_message"];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredChatKickUserReply:)];
	}
	
	[user release];
	
	[_kickMessagePanel close];
	[_kickMessageTextField setStringValue:@""];
}



- (IBAction)editAccount:(id)sender {
	WIP7Message		*message;
	WCUser			*user;
	
	user = [self selectedUser];
	
	message = [WIP7Message messageWithName:@"wired.user.get_info" spec:WCP7Spec];
	[message setUInt32:[user userID] forName:@"wired.user.id"];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredUserGetInfoReply:)];
}



- (IBAction)ignore:(id)sender {
	NSDictionary	*ignore;
	WCUser			*user;
	
	user = [self selectedUser];
	
	if([user isIgnored])
		return;
	
	ignore = [NSDictionary dictionaryWithObject:[user nick] forKey:WCIgnoresNick];
	
	[[WCSettings settings] addObject:ignore toArrayForKey:WCIgnores];
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIgnoresDidChangeNotification];
	
	[_userListTableView setNeedsDisplay:YES];
}



- (IBAction)unignore:(id)sender {
	NSDictionary		*ignore;
	NSMutableArray		*array;
	NSEnumerator		*enumerator;
	WCUser				*user;
	
	user = [self selectedUser];
	
	if(![user isIgnored])
		return;
	
	array		= [NSMutableArray array];
	enumerator	= [[[WCSettings settings] objectForKey:WCIgnores] objectEnumerator];
	
	while((ignore = [enumerator nextObject])) {
		if(![[ignore objectForKey:WCIgnoresNick] isEqualToString:[user nick]])
			[array addObject:ignore];
	}
	
	[[WCSettings settings] setObject:array forKey:WCIgnores];
	[[NSNotificationCenter defaultCenter] postNotificationName:WCIgnoresDidChangeNotification];
	
	[_userListTableView setNeedsDisplay:YES];
}



#pragma mark -

- (IBAction)fileFormat:(id)sender {
	[self _updateSaveChatForPanel:(NSSavePanel *) [sender window]];
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
		
		[cell setTextColor:[WCUser colorForColor:[user color] idleTint:[user isIdle]]];
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



- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
	NSMutableString		*toolTip;
	WCUser				*user;
	
	user = [self userAtIndex:row];
	toolTip = [[[user nick] mutableCopy] autorelease];
	
	if([[user status] length] > 0)
		[toolTip appendFormat:@"\n%@", [user status]];
	
	return toolTip;
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	WCUser		*user;
	
	user = [self userAtIndex:[indexes firstIndex]];
	
	[pasteboard declareTypes:[NSArray arrayWithObjects:WCUserPboardType, NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[NSSWF:@"%u", [user userID]] forType:WCUserPboardType];
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
