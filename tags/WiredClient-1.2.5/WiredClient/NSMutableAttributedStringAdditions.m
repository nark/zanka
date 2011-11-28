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

#import "NSArrayAdditions.h"
#import "NSMutableAttributedStringAdditions.h"
#import "NSScannerAdditions.h"
#import "NSURLAdditions.h"
#import "WCSettings.h"

@implementation NSMutableAttributedString(WCURLScanning)

- (void)addURLAttributes {
	static NSCharacterSet   *whitespace = NULL, *nonwhitespace = NULL, *skip = NULL;
	NSEnumerator			*enumerator;
	NSScanner				*scanner;
	NSArray					*lines;
	NSURL					*url;
	NSString				*line, *word;
	NSRange					range;
	unsigned int			index, length, offset = 0;
	
	// --- init static charsets
	if(!whitespace || !nonwhitespace || !skip) {
		whitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonwhitespace = [[whitespace invertedSet] retain];
		skip = [[NSCharacterSet characterSetWithCharactersInString:@",.?()[]{}<>"] retain];
	}
	
	// --- loop over every line
	lines = [[self string] componentsSeparatedByString:@"\n"];
	enumerator = [lines objectEnumerator];
	
	while((line = [enumerator nextObject])) {
		scanner = [[NSScanner alloc] initWithString:line];
		
		while(![scanner isAtEnd]) {
			// --- extract word
			[scanner skipUpToCharactersFromSet:nonwhitespace];
			range.location = [scanner scanLocation];
			[scanner scanUpToCharactersFromSet:whitespace intoString:&word];
			range.length = [scanner scanLocation] - range.location;
			
			// --- skip leading whatever
			length = [word length];
			index = 0;

			while(index < length && [skip characterIsMember:[word characterAtIndex:index]]) {
				index++;
				range.location++;
				range.length--;
			}
			
			// --- skip tailing whatever
			word = [line substringWithRange:range];
			index = [word length];

			while(index > 0 && [skip characterIsMember:[word characterAtIndex:index - 1]]) {
				index--;
				range.length--;
			}
			
			// --- extract URL
			word = [line substringWithRange:range];
			url = [NSURL URLWithLooseString:word];
			
			if(url) {
				range.location += offset;
				
				[self addAttribute:NSForegroundColorAttributeName
							 value:[WCSettings archivedObjectForKey:WCURLTextColor]
							 range:range];
				
				[self addAttribute:NSLinkAttributeName
							 value:url
							 range:range];
				
				[self addAttribute:NSUnderlineStyleAttributeName
							 value:[NSNumber numberWithInt:NSSingleUnderlineStyle]
							 range:range];
			}
		}
		
		offset += [scanner scanLocation] + 1;
		[scanner release];
	}
}

@end



@implementation NSMutableAttributedString(WCChatScanning)

- (void)addChatAttributes {
	static NSCharacterSet			*whitespace, *nonwhitespace, *digits;
	static NSMutableCharacterSet	*nontimestamp;
	NSEnumerator					*enumerator;
	NSScanner						*scanner;
	NSArray							*lines, *highlightWords;
	NSString						*line, *word;
	NSColor							*eventTextColor, *timestampEveryLineTextColor, *highlightWordsTextColor;
	NSRange							range, nickRange;
	BOOL							foundNick, foundPartialNick, foundAction, foundWord, foundHighlight;
	BOOL							timestampEveryLine;
	int								offset = 0;
	
	// --- init static charsets
	if(!whitespace || !nonwhitespace || !digits) {
		whitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonwhitespace = [[whitespace invertedSet] retain];
		digits = [[NSCharacterSet decimalDigitCharacterSet] retain];
		nontimestamp = [[NSMutableCharacterSet decimalDigitCharacterSet] retain];
		[nontimestamp addCharactersInString:@":."];
		[nontimestamp invert];
	}
	
	// --- cache settings here
	timestampEveryLine = [WCSettings boolForKey:WCTimestampEveryLine];
	eventTextColor = [WCSettings archivedObjectForKey:WCEventTextColor];
	timestampEveryLineTextColor = [WCSettings archivedObjectForKey:WCTimestampEveryLineTextColor];
	highlightWords = [WCSettings objectForKey:WCHighlightWordsWords];
	highlightWordsTextColor = [WCSettings archivedObjectForKey:WCHighlightWordsTextColor];
	
	// --- loop over every line
	lines = [[self string] componentsSeparatedByString:@"\n"];
	enumerator = [lines objectEnumerator];
	
	while((line = [enumerator nextObject])) {
		foundNick = foundPartialNick = foundAction = foundWord = foundHighlight = NO;
		scanner = [[NSScanner alloc] initWithString:line];
		[scanner setCharactersToBeSkipped:NULL];
		
		while(![scanner isAtEnd] && !foundHighlight) {
			[scanner skipUpToCharactersFromSet:nonwhitespace];
			range.location = [scanner scanLocation];
			[scanner scanUpToCharactersFromSet:whitespace intoString:&word];
			range.length = [scanner scanLocation] - range.location;
			
			// --- <<< event >>>
			if([word isEqualToString:@"<<<"] && [scanner scanUpToString:@">>>" intoString:NULL]) {
				range.length = [scanner scanLocation] - range.location + 3;
				range.location += offset;
				
				[self addAttribute:NSForegroundColorAttributeName
							 value:eventTextColor
							 range:range];

				continue;
			}

			// --- date
			if(!foundWord && !foundNick && timestampEveryLine) {
				if([word rangeOfCharacterFromSet:nontimestamp].location == NSNotFound ||
				   [word isEqualToString:@"PM"] || [word isEqualToString:@"AM"]) {
					range.location += offset;
					
					[self addAttribute:NSForegroundColorAttributeName
								 value:timestampEveryLineTextColor
								 range:range];
					continue;
				}
			}
			
			// --- action
			if(!foundWord && !foundNick) {
				if([word isEqualToString:@"*"] || [word isEqualToString:@"***"]) {
					foundAction = YES;
					continue;
				}
			}

			// --- nick
			if(!foundAction && !foundNick && !foundWord) {
				if(!foundPartialNick) {
					nickRange = range;
					
					if([word hasPrefix:@"<"]) {
						nickRange.location++;
						nickRange.length--;
					}
					
					if([word hasSuffix:@":"]) {
						foundNick = YES;
						nickRange.length--;
					}
					else if([word hasSuffix:@">"]) {
						foundNick = YES;
						nickRange.length--;
					}
					
					if(!foundNick)
						foundPartialNick = YES;
				} else {
					nickRange.length = [scanner scanLocation] - nickRange.location;
					
					if([word hasSuffix:@":"] || [word hasSuffix:@">"]) {
						nickRange.length--;
						foundNick = YES;
					}
				}

				continue;
			}
			
			// --- every word in actual chat
			if(foundNick && !foundHighlight && [highlightWords containsSubstring:word]) {
				nickRange.location += offset;
		
				[self addAttribute:NSForegroundColorAttributeName
							 value:highlightWordsTextColor
							 range:nickRange];
				
				foundHighlight = YES;
			}
			
			foundWord = YES;
		}
		
		offset += [line length] + 1;
		[scanner release];
	}
}

@end