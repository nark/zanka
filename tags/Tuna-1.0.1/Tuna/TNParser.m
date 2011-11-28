/* $Id$ */

/*
 *  Copyright (c) 2005 Axel Andersson
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

#import "TNNode.h"
#import "TNParser.h"
#import "TNSub.h"
#import "TNTree.h"

@interface TNParser(Private)

enum _TNParserState {
	TNParserStateHeader,
	TNParserStateData,
	TNParserStateFinished,
};
typedef enum _TNParserState		TNParserState;


- (id)_initWithString:(NSString *)string;

- (TNTree *)_parse;
- (NSColor *)_colorForPackage:(NSString *)package;

@end


@implementation TNParser(Private)

- (id)_initWithString:(NSString *)string {
	self = [super init];
	
	_string		= [string retain];

	_nodes		= CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	_subs		= CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);

	_usedColors	= [[NSMutableDictionary alloc] initWithCapacity:50];

	_colors		= [[NSArray alloc] initWithObjects:
		[NSColor blackColor],
		[NSColor colorWithCalibratedHTMLValue:0x5C0808 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x716940 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x1335FE alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xFD54FD alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x056767 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x332738 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xA64379 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x154F15 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x942A93 alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0x0C0C6D alpha:1.0],
		[NSColor colorWithCalibratedHTMLValue:0xFD3B12 alpha:1.0],
	NULL];
	
	return self;
}



#pragma mark -

static inline unsigned int _TNHash(const unichar *buffer, unsigned int length) {
	unsigned int		hash;
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



#pragma mark -

- (TNTree *)_parse {
	NSString		*key, *package, *name;
	TNTree			*tree;
	TNNode			*node, *parentNode, *rootNode;
	TNSub			*sub;
	TNParserState	state;
	CFRange			range, stringRange, bufferRange;
	NSRange			lineRange, fieldRange;
	NSTimeInterval	time;
	unichar			buffer[64];
	double			secondsPerTick;
	unsigned int	i, count, length, stime, utime, ticks;
	
	time			= [NSDate timeIntervalSinceReferenceDate];
	tree			= [[TNTree alloc] init];
	rootNode		= [tree rootNode];
	parentNode		= rootNode;
	state			= TNParserStateHeader;
	length			= [_string length];
	stringRange		= CFRangeMake(0, length);
	secondsPerTick	= 0.0;
	
	while(CFStringFindWithOptions((CFStringRef) _string, (CFStringRef) @"\n", stringRange, 0, &range)) {
		lineRange.location		= stringRange.location;
		lineRange.length		= range.location - lineRange.location;
		stringRange.location	= range.location + 1;
		stringRange.length		= length - stringRange.location;
		
		if(lineRange.length == 0)
			continue;
		
		if(state == TNParserStateData) {
			unichar		type;
	
			type = CFStringGetCharacterAtIndex((CFStringRef) _string, lineRange.location);
			
			switch(type) {
				case '+':
					if(lineRange.length >= 8 && CFStringGetCharacterAtIndex((CFStringRef) _string, lineRange.location + 2) == '&')
						continue;

					// --- retrieve previously saved sub
					bufferRange.location = lineRange.location + 2;
					bufferRange.length = lineRange.length - 2;
					
					CFStringGetCharacters((CFStringRef) _string, bufferRange, buffer);

					sub = (id) CFDictionaryGetValue(_subs, (void *) _TNHash(buffer, bufferRange.length));

					if(sub) {
						// --- add a node
						node = [parentNode childWithSub:sub];
						
						if(node) {
							node->_calls++;
						} else {
							node = [[TNNode allocWithZone:NULL] initWithParent:parentNode sub:sub];
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
					
					// --- extract package
					i			= fieldRange.location + fieldRange.length - lineRange.location + 1;
					fieldRange	= [_string rangeOfString:@" "
												 options:NSLiteralSearch
												   range:NSMakeRange(lineRange.location + i, lineRange.length - i)];
					fieldRange	= NSMakeRange(lineRange.location + i, fieldRange.location - lineRange.location - i);
					package		= [_string substringWithRange:fieldRange];
					
					// --- extract name
					i			= fieldRange.location + fieldRange.length - lineRange.location + 1;
					fieldRange	= NSMakeRange(lineRange.location + i, lineRange.length - i);
					name		= [_string substringWithRange:fieldRange];
					
					// --- add a sub
					sub = [[TNSub alloc] initWithPackage:package name:name color:[self _colorForPackage:package]];
					CFStringGetCharacters((CFStringRef) key, CFRangeMake(0, [key length]), buffer);
					CFDictionaryAddValue(_subs, (void *) _TNHash(buffer, [key length]), sub);
					[sub release];
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
		else if(state == TNParserStateHeader) {
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
				state = TNParserStateData;
				continue;
			}
		}
	}
	
	// --- post-process node
	[rootNode refreshPercent];
	
	NSLog(@"%.2fms", ([NSDate timeIntervalSinceReferenceDate] - time) * 1000.0);

	return tree;
}



- (NSColor *)_colorForPackage:(NSString *)package {
	NSColor		*color;
	
	color = [_usedColors objectForKey:package];
	
	if(!color) {
		if(_colorIndex >= [_colors count])
			_colorIndex = 0;
		
		color = [_colors objectAtIndex:_colorIndex++];
		
		[_usedColors setObject:color forKey:package];
	}
	
	return color;
}

@end



@implementation TNParser

+ (TNTree *)parseWithString:(NSString *)string {
	TNParser	*parser;
	
	parser = [[[self alloc] _initWithString:string] autorelease];

	return [parser _parse];
}



#pragma mark -

- (void)dealloc {
	[_string release];
	
	CFRelease(_nodes);
	CFRelease(_subs);
	
	[_usedColors release];
	
	[_colors release];
	
	[super dealloc];
}

@end
