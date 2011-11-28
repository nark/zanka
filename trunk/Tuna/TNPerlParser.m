/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
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

#import "TNPerlNode.h"
#import "TNPerlParser.h"
#import "TNPerlTree.h"

enum _TNPerlParserState {
	TNPerlParserStateHeader,
	TNPerlParserStateData,
	TNPerlParserStateFinished,
};
typedef enum _TNPerlParserState		TNPerlParserState;


static inline NSUInteger _TNPerlHash(const unichar *buffer, unsigned int length) {
	NSUInteger			hash;
	const unichar		*end, *end4;
	
	hash	= length;
	end		= buffer + length;
	end4	= buffer + (length & ~3);

	while(buffer < end4) {
		hash = hash * 67503105 + buffer[0] * 16974593 + buffer[1] * 66049 + buffer[2] * 257 + buffer[3];
		buffer += 4;
	}

	while(buffer < end)
		hash = hash * 257 + *buffer++;
	
	return hash + (hash << (length & 31));
}



@implementation TNPerlParser

+ (BOOL)handlesString:(NSString *)string {
	return [string hasPrefix:@"#fOrTyTwO"];
}



#pragma mark -

- (id)initWithString:(NSString *)string {
	self = [super initWithString:string];
	
	_nodes = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	
	return self;
}



- (void)dealloc {
	CFRelease(_nodes);

	[super dealloc];
}



#pragma mark -

- (id)parsedTree {
	NSString			*key, *library, *symbol;
	TNPerlTree			*tree;
	TNPerlNode			*node, *parentNode, *rootNode;
	TNFunction			*function;
	TNPerlParserState	state;
	CFRange				range, stringRange, bufferRange;
	NSRange				lineRange, fieldRange;
	unichar				buffer[64];
	double				secondsPerTick;
	NSUInteger			i, count, length, stime, utime, ticks;
	
	tree				= [[TNPerlTree alloc] init];
	rootNode			= [tree rootNode];
	parentNode			= rootNode;
	state				= TNPerlParserStateHeader;
	length				= [_string length];
	stringRange			= CFRangeMake(0, length);
	secondsPerTick		= 0.0;
	
	while(CFStringFindWithOptions((CFStringRef) _string, (CFStringRef) @"\n", stringRange, 0, &range)) {
		lineRange.location		= stringRange.location;
		lineRange.length		= range.location - lineRange.location;
		stringRange.location	= range.location + 1;
		stringRange.length		= length - stringRange.location;
		
		if(lineRange.length == 0)
			continue;
		
		if(state == TNPerlParserStateData) {
			unichar		type;
	
			type = CFStringGetCharacterAtIndex((CFStringRef) _string, lineRange.location);
			
			switch(type) {
				case '+':
					if(lineRange.length >= 8 && CFStringGetCharacterAtIndex((CFStringRef) _string, lineRange.location + 2) == '&')
						continue;

					// --- retrieve previously saved function
					bufferRange.location = lineRange.location + 2;
					bufferRange.length = lineRange.length - 2;
					
					if((NSUInteger) bufferRange.length > sizeof(buffer) - 1)
						bufferRange.length = sizeof(buffer) - 1;
					
					CFStringGetCharacters((CFStringRef) _string, bufferRange, buffer);

					function = (id) CFDictionaryGetValue(_functions, (void *) _TNPerlHash(buffer, bufferRange.length));

					if(function) {
						// --- add a node
						node = [parentNode childWithFunctionIdenticalTo:function];
						
						if(node) {
							node->_calls++;
						} else {
							node = [[TNPerlNode allocWithZone:NULL] initWithParent:parentNode function:function];
							[parentNode addChild:node];
							[node release];
						}
						
						// --- add for timing
						bufferRange.location = CFArrayGetCount(_nodes);
						bufferRange.length = 0;
						
						CFArrayReplaceValues(_nodes, bufferRange, (void *) &node, 1);

						// --- climb up
						parentNode = node;
					}
					break;
				
				case '-':
					if(lineRange.length >= 8 && CFStringGetCharacterAtIndex((CFStringRef) _string, lineRange.location + 2) == '&')
						continue;

					// --- climb down
					parentNode = parentNode->_parent;
					break;
				
				case '&':
					// --- extract key
					i			= 2;
					fieldRange	= [_string rangeOfString:@" "
												 options:NSLiteralSearch
												   range:NSMakeRange(lineRange.location + i, lineRange.length - i)];
					fieldRange	= NSMakeRange(lineRange.location + i, fieldRange.location - lineRange.location - i);
					key			= [_string substringWithRange:fieldRange];
					
					// --- extract library
					i			= fieldRange.location + fieldRange.length - lineRange.location + 1;
					fieldRange	= [_string rangeOfString:@" "
												 options:NSLiteralSearch
												   range:NSMakeRange(lineRange.location + i, lineRange.length - i)];
					fieldRange	= NSMakeRange(lineRange.location + i, fieldRange.location - lineRange.location - i);
					library		= [_string substringWithRange:fieldRange];
					
					// --- extract symbol
					i			= fieldRange.location + fieldRange.length - lineRange.location + 1;
					fieldRange	= NSMakeRange(lineRange.location + i, lineRange.length - i);
					symbol		= [_string substringWithRange:fieldRange];
					
					// --- add a function
					function = [[TNFunction alloc] initWithLibrary:library symbol:symbol color:[self colorForLibrary:library]];
					CFStringGetCharacters((CFStringRef) key, CFRangeMake(0, [key length]), buffer);
					CFDictionaryAddValue(_functions, (void *) _TNPerlHash(buffer, [key length]), function);
					[function release];
					break;
					
				case '@':
					count = CFArrayGetCount(_nodes);
					
					if(count > 0) {
						// --- extract user time
						i			= 2;
						fieldRange	= [_string rangeOfString:@" "
													 options:NSLiteralSearch
													   range:NSMakeRange(lineRange.location + i, lineRange.length - i)];
						fieldRange	= NSMakeRange(lineRange.location + i, fieldRange.location - lineRange.location - i);
						utime		= [[_string substringWithRange:fieldRange] unsignedIntValue];
						
						// --- extract system time
						i			= fieldRange.location + fieldRange.length - lineRange.location + 1;
						fieldRange	= [_string rangeOfString:@" "
													 options:NSLiteralSearch
													   range:NSMakeRange(lineRange.location + i, lineRange.length - i)];
						fieldRange	= NSMakeRange(lineRange.location + i, fieldRange.location - lineRange.location - i);
						stime		= [[_string substringWithRange:fieldRange] unsignedIntValue];
						
						// --- we only consider total time
						ticks		= utime + stime;
						
						if(ticks > 0) {
							double		time;
							
							// --- add time for all nodes since last timestamp
							time = (ticks * secondsPerTick) / count;
							
							for(i = 0; i < count; i++)
								[(id) CFArrayGetValueAtIndex(_nodes, i) addTime:time];
							
							CFArrayRemoveAllValues(_nodes);
						}
					}
					break;
			}
		}
		else if(state == TNPerlParserStateHeader) {
			unichar		prefix;
			
			prefix = [_string characterAtIndex:lineRange.location];
			
			if(prefix == '#') {
				// --- comment
				continue;
			}
			else if(prefix == '$') {
				NSScanner	*scanner;
				NSString	*line, *name, *value;
				
				// --- variables in header
				line = [_string substringWithRange:lineRange];
				scanner = [NSScanner scannerWithString:line];
				
				while(![scanner isAtEnd]) {
					name = value = NULL;
					
					[scanner scanString:@"$" intoString:NULL];
					[scanner scanUpToString:@"=" intoString:&name];
					[scanner scanString:@"=" intoString:NULL];
					
					if([scanner scanString:@"'" intoString:NULL]) {
						[scanner scanUpToString:@"';" intoString:&value];
						[scanner scanString:@"';" intoString:NULL];
					} else {
						[scanner scanUpToString:@";" intoString:&value];
						[scanner scanString:@";" intoString:NULL];
					}
					
					if(name && value)
						[tree->_variables setObject:value forKey:name];
				}
			}
			else if([[_string substringWithRange:lineRange] isEqualToString:@"PART2"]) {
				// --- get frequency
				secondsPerTick = 1.0 / (double) [[tree->_variables objectForKey:@"hz"] floatValue];
				
				// --- beginning of data dump
				state = TNPerlParserStateData;
				continue;
			}
		}
	}
	
	// --- post-process node
	[rootNode refreshPercent];
	
	return [tree autorelease];
}

@end
