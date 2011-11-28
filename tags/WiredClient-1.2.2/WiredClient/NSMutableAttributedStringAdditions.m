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
	static NSCharacterSet   *whitespace = NULL, *nonwhitespace = NULL, *digits = NULL;
	NSEnumerator			*enumerator;
	NSScanner				*scanner;
	NSArray					*lines;
	NSString				*line, *word;
	NSRange					range, nickRange;
	BOOL					foundNick, foundAction, foundWord;
	int						offset = 0;
	
	// --- init static charsets
	if(!whitespace || !nonwhitespace || !digits) {
		whitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
		nonwhitespace = [[whitespace invertedSet] retain];
		digits = [[NSCharacterSet decimalDigitCharacterSet] retain];
	}
	
	// --- loop over every line
	lines = [[self string] componentsSeparatedByString:@"\n"];
	enumerator = [lines objectEnumerator];
	
	while((line = [enumerator nextObject])) {
		foundNick = foundAction = foundWord = NO;
		scanner = [[NSScanner alloc] initWithString:line];
		[scanner setCharactersToBeSkipped:NULL];
		
		while(![scanner isAtEnd]) {
			[scanner skipUpToCharactersFromSet:nonwhitespace];
			range.location = [scanner scanLocation];
			[scanner scanUpToCharactersFromSet:whitespace intoString:&word];
			range.length = [scanner scanLocation] - range.location;
			
			// --- <<< event >>>
			if([word isEqualToString:@"<<<"] && [scanner scanUpToString:@">>>" intoString:NULL]) {
				range.length = [scanner scanLocation] - range.location + 3;
				range.location += offset;
				
				[self addAttribute:NSForegroundColorAttributeName
							 value:[WCSettings archivedObjectForKey:WCEventTextColor]
							 range:range];
			}
			// --- date
			else if(!foundNick && ([digits characterIsMember:[word characterAtIndex:0]] ||
					[word isEqualToString:@"PM"] || [word isEqualToString:@"AM"])) {
				range.location += offset;
				
				[self addAttribute:NSForegroundColorAttributeName
							 value:[WCSettings archivedObjectForKey:WCTimestampEveryLineTextColor]
							 range:range];
			}
			// --- action
			else if(!foundNick && [word hasPrefix:@"*"] &&
					![word hasSuffix:@":"] && ![word hasSuffix:@">"]) {
				foundAction = YES;
			}
			// --- nick
			else if(!foundNick && (foundAction || [word hasSuffix:@":"] || [word hasSuffix:@">"])) {
				nickRange = range;
				
				if([word hasSuffix:@":"] || [word hasSuffix:@">"])
					nickRange.length--;
				
				if([word hasPrefix:@"<"]) {
					nickRange.location++;
					nickRange.length--;
				}

				foundNick = YES;
			}
			// --- every word in actual chat
			else {
				if(!foundWord &&
				   [[WCSettings objectForKey:WCHighlightWordsWords] containsSubstring:word]) {								nickRange.location += offset;
				
					[self addAttribute:NSForegroundColorAttributeName
								 value:[WCSettings archivedObjectForKey:WCHighlightWordsTextColor]
								 range:nickRange];
					
					foundWord = YES;
				}
			}
		}
		
		offset += [line length] + 1;
		[scanner release];
	}
}

@end