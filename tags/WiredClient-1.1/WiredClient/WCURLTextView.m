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

#import "WCURLTextView.h"

@implementation WCURLTextView

- (id)initWithFrame:(NSRect)frame textContainer:(NSTextContainer *)textContainer {
	self = [super initWithFrame:frame textContainer:textContainer];
	
	// --- we're read-only
	[self setEditable:NO];

	// --- create cursor for URLs
	_urlCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"URLCursor"]
										 hotSpot:NSMakePoint(5.0, 0.0)];

	// --- known protocols to link, objects are what to create the url with, the key
	//     is how to recognize them
	_protocols = [[NSDictionary alloc] initWithObjectsAndKeys:
		@"wired://",		@"wired.",
		@"http://",			@"www.",
		@"ftp://",			@"ftp.",
		@"mailto:",			@"mailto:",
		NULL];

	// --- create character sets
	_alphanumericCharacterSet = [[NSCharacterSet alphanumericCharacterSet] retain];
	_skipCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"~.,:;-!?()[]<>"] retain];
	
	return self;
}


- (void)dealloc {
	[_urlCursor release];
	
	[_protocols release];
	
	[_alphanumericCharacterSet release];
	[_skipCharacterSet release];
	
	[_urlColor release];
	[_eventColor release];
	[_textColor release];
	
	[super dealloc];
}



#pragma mark -

- (NSAttributedString *)scan:(NSString *)string {
	NSMutableAttributedString	*outString;
	NSScanner					*scanner;
	NSString					*scanString;
	NSMutableDictionary			*attributes, *defaultAttributes;
	NSRange						range;
	
	// --- create the scanner
	scanner = [NSScanner scannerWithString:string];
	
	// --- default attributes for this textview
	defaultAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self textColor], NSForegroundColorAttributeName,
		[self font], NSFontAttributeName,
		NULL];

	// --- create a mutable attributed string to use
	outString = [[NSMutableAttributedString alloc] initWithString:string attributes:defaultAttributes];
	
	while(![scanner isAtEnd]) {
		// --- reset attributes
		attributes = [NSMutableDictionary dictionaryWithDictionary:defaultAttributes];
		
		// --- skip whitespace
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
								intoString:&scanString];

		if([scanString isEqualToString:@"<<<"]) {
			// --- find the terminating >>>
			range.location = [scanner scanLocation] - 3;
			[scanner scanUpToString:@">>>" intoString:NULL];
			range.length = [scanner scanLocation] - range.location + 3;
			
			// --- set event attributes
			[attributes setObject:[self eventColor] forKey:NSForegroundColorAttributeName];
			[outString setAttributes:attributes range:range];
		} else {
			NSEnumerator	*enumerator;
			NSString		*each, *protocol = @"";
			NSURL			*url;
			NSRange			range, wordRange;
			unichar			next;
			BOOL			found = NO;
			
			// --- skip stuff at beginning of string
			range.location = 0;
			range.length = [scanString length];
			wordRange.location = [scanner scanLocation] - range.length;
			
			while([_skipCharacterSet characterIsMember:[scanString characterAtIndex:range.location]]) {
				range.location++;
				wordRange.location++;
				range.length--;
				
				if(range.length == 0)
					break;
			}
			
			if(range.length == 0)
				continue;
			
			scanString = [scanString substringWithRange:range];

			// --- skip stuff at end of string
			range.location = 0;
			range.length = [scanString length];
			
			while([_skipCharacterSet characterIsMember:[scanString characterAtIndex:range.length - 1]])
				range.length--;
			
			scanString = [scanString substringWithRange:range];
			wordRange.length = [scanString length];
			
			// --- if the string contains "://", but neither begins nor ends with it
			range = [scanString rangeOfString:@"://"];
			
			if(range.location > 1 && range.length != 0 &&
			   range.location + range.length != [scanString length])
				found = YES;

			// --- if the string contains "@", but neither begins nor ends with it
			range = [scanString rangeOfString:@"@"];
			
			if(!found && range.location > 1 && range.length != 0 &&
			   range.location + range.length != [scanString length]) {
				// --- if it contains at least one dot
				if([[scanString componentsSeparatedByString:@"."] count] - 1 >= 1) {
					found = YES;
					protocol = @"mailto:";
				}
			}
			
			// --- loop over all protocols and try identify them
			if(!found) {
				enumerator = [_protocols keyEnumerator];
				
				while((each = [enumerator nextObject])) {
					range = [scanString rangeOfString:each];

					// --- if it begins with the identifier
					if(range.location == 0 && range.length != 0) {
						// --- the character after the identifier is alphanumeric
						next = [scanString characterAtIndex:range.location + range.length];
						
						if([_alphanumericCharacterSet characterIsMember:next]) {
							// --- if it contains at least two dots
							if([[scanString componentsSeparatedByString:@"."] count] - 1 >= 2) {
								found = YES;
								protocol = [_protocols objectForKey:each];
							}
						}
					}
					
					if(found)
						break;
				}
			}
			
			if(found) {
				// --- extract URL
				url = [NSURL URLWithString:[protocol stringByAppendingString:scanString]];
				
				// --- set URL attributes
				if(url) {
					[attributes setObject:_urlColor forKey:NSForegroundColorAttributeName];
					[attributes setObject:url forKey:NSLinkAttributeName];
					[attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] 
								   forKey:NSUnderlineStyleAttributeName];
					[outString setAttributes:attributes range:wordRange];
				}
			}
		}
	}

	return [outString autorelease];
}



- (void)resetCursorRects {
	NSLayoutManager		*layoutManager;
	NSRect				visibleRect;
	NSRectArray			linkRects;
	NSRange				glyphRange, charRange, linkRange;
	unsigned int		scanLocation, linkCount, i;
	
	// --- find the range of visible characters
	layoutManager   = [self layoutManager];
	visibleRect		= [[self enclosingScrollView] documentVisibleRect];
	glyphRange		= [layoutManager glyphRangeForBoundingRect:visibleRect
											   inTextContainer:[self textContainer]];
	charRange		= [layoutManager characterRangeForGlyphRange:glyphRange
												actualGlyphRange:NULL];
	
	// --- loop over all visible characters
	scanLocation = charRange.location;

	while(scanLocation < charRange.location + charRange.length) {
		if([[self textStorage] attribute:NSLinkAttributeName atIndex:scanLocation
						  effectiveRange:&linkRange]) {
			// --- get the array of rects
			linkRects = [layoutManager rectArrayForCharacterRange:linkRange 
									 withinSelectedCharacterRange:linkRange 
												  inTextContainer:[self textContainer] 
														rectCount:&linkCount];
			
			// --- set these rects as cursor rects
			for(i = 0; i < linkCount; i++) {
				[self addCursorRect:NSIntersectionRect(visibleRect, linkRects[i])
							 cursor:_urlCursor];
			}
		}
		
		// --- do the next one over
		scanLocation = linkRange.location + linkRange.length;
	}
}



#pragma mark -

- (NSColor *)urlColor {
	return _urlColor;
}



- (void)setURLColor:(NSColor *)value {
	[value retain];
	[_urlColor release];
	
	_urlColor = value;
}



#pragma mark -

- (NSColor *)eventColor {
	return _eventColor;
}



- (void)setEventColor:(NSColor *)value {
	[value retain];
	[_eventColor release];
	
	_eventColor = value;
}



#pragma mark -

- (NSColor *)textColor {
	return _textColor;
}



- (void)setTextColor:(NSColor *)value {
	[value retain];
	[_textColor release];
	
	_textColor = value;
	
	[super setTextColor:value];
}

@end
