/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Axel Andersson
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

#import "NSString-WCAdditions.h"
#import "WCApplicationController.h"

@implementation NSMutableAttributedString(WCAdditions)

- (void)filterWiredChat:(WITextFilter *)filter {
	static NSCharacterSet		*whitespaceSet, *nonWhitespaceSet, *nonTimestampSet, *nonHighlightSet;
	NSMutableCharacterSet		*characterSet;
	NSEnumerator				*enumerator;
	NSScanner					*scanner;
	NSMutableArray				*highlightPatterns, *highlightStrings, *highlightColors;
	NSDictionary				*highlight;
	NSString					*word, *chat;
	NSColor						*color, *eventsTextColor, *timestampEveryLineColor;
	NSRange						range, nickRange, patternRange;
	NSUInteger					i, style, highlightCount, length;
	BOOL						running = YES;

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

	eventsTextColor			= [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatEventsColor]];
	timestampEveryLineColor	= [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCTimestampEveryLineColor]];

	highlightPatterns		= [NSMutableArray array];
	highlightStrings		= [NSMutableArray array];
	highlightColors			= [NSMutableArray array];
	enumerator				= [[WCSettings objectForKey:WCHighlights] objectEnumerator];
	
	while((highlight = [enumerator nextObject])) {
		[highlightPatterns addObject:[highlight objectForKey:WCHighlightsPattern]];
		[highlightStrings addObject:[highlight objectForKey:WCHighlightsColor]];
		[highlightColors addObject:[NSNull null]];
	}
	
	highlightCount = [highlightPatterns count];
	
	scanner = [NSScanner scannerWithString:[self string]];
	[scanner setCharactersToBeSkipped:NULL];

	while(running) {
		// --- extract word
		[scanner skipUpToCharactersFromSet:nonWhitespaceSet];
		range.location = [scanner scanLocation];
		
		if(![scanner scanUpToCharactersFromSet:whitespaceSet intoString:&word]) {
			running = NO;

			continue;
		}
		
		range.length = [scanner scanLocation] - range.location;
		
		// --- scan timestamps patterns
		if([word rangeOfCharacterFromSet:nonTimestampSet].location == NSNotFound ||
		   [word isEqualToString:@"PM"] || [word isEqualToString:@"AM"]) {
			[self addAttribute:NSForegroundColorAttributeName value:timestampEveryLineColor range:range];
			
			goto nextword;
		}
		
		// --- scan <<< >>> patterns
		if([word isEqualToString:@"<<<"]) {
			if([scanner scanUpToString:@">>>" intoString:NULL]) {
				range.length = [scanner scanLocation] - range.location + 3;

				[self addAttribute:NSForegroundColorAttributeName value:eventsTextColor range:range];
				
				goto nextline;
			}
		}
		
		// --- scan and skip action chat
		if([word isEqualToString:@"*"] || [word isEqualToString:@"***"])
			goto nextline;
		
		// --- scan nick name
		nickRange = range;
		style = [word hasPrefix:@"<"] ? WCChatStyleIRC : WCChatStyleWired;
		
		if(style == WCChatStyleIRC) {
			nickRange.location++;
			nickRange.length--;
		}
		
		if(style == WCChatStyleWired && [word hasSuffix:@":"]) {
			nickRange.length--;

			if(![scanner isAtEnd])
				[scanner setScanLocation:[scanner scanLocation] + 1];
		}
		else if(style == WCChatStyleIRC && [word hasSuffix:@">"]) {
			nickRange.length--;

			if(![scanner isAtEnd])
				[scanner setScanLocation:[scanner scanLocation] + 1];
		}
		else {
			[scanner scanUpToString:style == WCChatStyleWired ? @":" : @">" intoString:NULL];
			
			nickRange.length = [scanner scanLocation] - range.location;

			if(![scanner isAtEnd])
			   [scanner setScanLocation:[scanner scanLocation] + 1];
		}
		
		// --- scan rest of line
		if([scanner scanUpToString:@"\n" intoString:&chat]) {
			length = [chat length];
			
			// --- scan chat line for highlight patterns
			for(i = 0; i < highlightCount; i++) {
				patternRange = [chat rangeOfString:[highlightPatterns objectAtIndex:i] options:NSCaseInsensitiveSearch];
				
				if(patternRange.location != NSNotFound) {
					if(patternRange.location + patternRange.length == length ||
					   ![[NSCharacterSet alphanumericCharacterSet] characterIsMember:
						 [chat characterAtIndex:patternRange.location + patternRange.length]]) {
						color = [highlightColors objectAtIndex:i];
						
						if(![color isKindOfClass:[NSColor class]]) {
							color = WIColorFromString([highlightStrings objectAtIndex:i]);
							[highlightColors replaceObjectAtIndex:i withObject:color];
						}
						
						[self addAttribute:NSForegroundColorAttributeName value:color range:nickRange];
						
						break;
					}
				}
			}
		}
		
nextword:
		// --- scan next word
		continue;
		
nextline:
		// --- scan and skip until newline
		[scanner scanUpToString:@"\n" intoString:NULL];
		continue;
	}
}



#pragma mark -

- (void)_filterWiredSmilies:(WITextFilter *)filter small:(BOOL)small {
	static NSCharacterSet		*whitespaceSet;
	WCApplicationController		*controller;
	NSDictionary				*attributes;
	NSMutableString				*string;
	NSAttributedString			*attributedString;
	NSFileWrapper				*wrapper;
	NSTextAttachment			*attachment;
	NSEnumerator				*enumerator;
	NSString					*key, *substring, *smiley, *character;
	NSRange						range, searchRange;
	unsigned int				length, options;
	BOOL						found;
	
	if(![WCSettings boolForKey:WCShowSmileys])
		return;
	
	if(!whitespaceSet)
		whitespaceSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		
	controller	= [WCApplicationController sharedController];
	string		= [self mutableString];
	length		= [self length];
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
					attributes = [self attributesAtIndex:range.location effectiveRange:NULL];
					
					if(![attributes objectForKey:NSLinkAttributeName]) {
						wrapper					= [[NSFileWrapper alloc] initWithPath:smiley];
						attachment				= [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
						
						if(small)
							[[(NSTextAttachmentCell *) [attachment attachmentCell] image] setSize:NSMakeSize(14.0, 14.0)];
						
						attributedString		= [NSAttributedString attributedStringWithAttachment:attachment];
						
						[self replaceCharactersInRange:range withAttributedString:attributedString];
						
						length					-= range.length - 1;
						searchRange.location	= range.location + 1;
						searchRange.length		= length - searchRange.location;
						
						range.length			= 1;
						character				= [substring substringFromIndex:[substring length] - 1];
						options					= NSCaseInsensitiveSearch | NSAnchoredSearch;
						
						while((range = [string rangeOfString:character options:options range:searchRange]).location != NSNotFound) {
							[self replaceCharactersInRange:range withAttributedString:attributedString];
							
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



- (void)filterWiredSmallSmilies:(WITextFilter *)filter {
	[self _filterWiredSmilies:filter small:YES];
}



- (void)filterWiredSmilies:(WITextFilter *)filter {
	[self _filterWiredSmilies:filter small:NO];
}



#pragma mark -

#define _WCURLFilterInterestingLength		8


static inline BOOL _WCURLFilterStringLooksInteresting(CFStringRef string) {
	CFIndex		index;
	
	index = CFStringFind(string, CFSTR("://"), 0).location;
	
	if(index != kCFNotFound && index != 0)
		return YES;
	
	index = CFStringFind(string, CFSTR("www."), 0).location;
	
	if(index != kCFNotFound && index != 0)
		return YES;

	index = CFStringFind(string, CFSTR("wired."), 0).location;

	if(index != kCFNotFound && index != 0)
		return YES;

	return NO;
}



- (void)filterURLs:(WITextFilter *)filter {
	static NSCharacterSet	*whitespaceSet, *nonWhitespaceSet, *skipSet;
	CFStringRef				string, word, subWord;
	CFRange					searchRange, foundRange, wordRange, subRange;
	WIURL					*url;
	unsigned int			length, wordLength, i;
	
	if(!whitespaceSet) {
		whitespaceSet		= [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonWhitespaceSet	= [[whitespaceSet invertedSet] retain];
		skipSet				= [[NSCharacterSet characterSetWithCharactersInString:@",.?()[]{}<>"] retain];
	}
	
	string = (CFStringRef) [self string];
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
		
		if(wordRange.length >= _WCURLFilterInterestingLength) {
			word = CFStringCreateWithSubstring(NULL, string, wordRange);
			
			if(_WCURLFilterStringLooksInteresting(word)) {
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
				
				if(subRange.length == 0)
					goto next;
				
				i = wordLength;
				
				while(i > 0 && CFCharacterSetIsCharacterMember((CFCharacterSetRef) skipSet, CFStringGetCharacterAtIndex(word, i - 1))) {
					wordRange.length--;
					subRange.length--;
					
					i--;
				}
				
				if(subRange.length == 0)
					goto next;
				
				if((unsigned int) subRange.length != wordLength) {
					subWord = CFStringCreateWithSubstring(NULL, word, subRange);
					
					CFRelease(word);
					word = subWord;
				}
				
				url = [WIURL URLWithString:(NSString *) word];
				
				if(url) {
					[self addAttribute:NSLinkAttributeName
								 value:[url URL]
								 range:NSMakeRange(wordRange.location, wordRange.length)];
				}
			}
	
next:
			CFRelease(word);
		}
	}
}

@end
