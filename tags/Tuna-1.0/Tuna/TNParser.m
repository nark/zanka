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

enum TNParserState {
	TNParserStateHeader,
	TNParserStateData,
	TNParserStateFinished,
};
typedef enum TNParserState		TNParserState;


- (id)initWithString:(NSString *)string;

- (TNTree *)parse;
- (NSColor *)colorForPackage:(NSString *)package;

@end



@implementation TNParser

+ (TNTree *)parseWithString:(NSString *)string {
	TNParser	*parser;
	
	parser = [[[self alloc] initWithString:string] autorelease];

	return [parser parse];
}



#pragma mark -

- (id)initWithString:(NSString *)string {
	self = [super init];
	
	_string		= [string retain];

	_subs		= [[NSMutableDictionary alloc] initWithCapacity:1000];
	_nodes		= [[NSMutableArray alloc] initWithCapacity:500];

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



- (void)dealloc {
	[_string release];
	
	[_subs release];
	[_nodes release];
	
	[_usedColors release];
	
	[_colors release];
	
	[super dealloc];
}



#pragma mark -

- (TNTree *)parse {
	NSString		*line;
	TNTree			*tree;
	TNNode			*node, *parentNode, *rootNode;
	TNParserState	state;
	NSRange			range;
	double			secondsPerTick;
	unsigned int	offset, length;
	
	tree			= [[TNTree alloc] init];
	rootNode		= [tree rootNode];
	parentNode		= rootNode;
	state			= TNParserStateHeader;
	offset			= 0;
	length			= [_string length];
	secondsPerTick	= 0.0;
	
	while(YES) {
		range = [_string rangeOfString:@"\n" options:0 range:NSMakeRange(offset, length - offset)];
		
		if(range.location == NSNotFound)
			break;
		
		line = [_string substringWithRange:NSMakeRange(offset, range.location - offset)];
		offset = range.location + 1;
		
		if(state == TNParserStateHeader) {
			if([line hasPrefix:@"#"]) {
				// --- comment
				continue;
			}
			else if([line hasPrefix:@"$"]) {
				NSScanner	*scanner;
				NSString	*name, *value;
				
				// --- variables in header
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
			else if([line isEqualToString:@"PART2"]) {
				// --- get frequency
				secondsPerTick = 1.0 / (double) [[tree->_variables objectForKey:@"hz"] floatValue];

				// --- beginning of data dump
				state = TNParserStateData;
				continue;
			}
		}
		else if(state == TNParserStateData && [line length] > 0) {
			unichar		type;
			
			type = [line characterAtIndex:0];
			
			if(type == '+' || type == '*') {
				TNSub			*sub;
				unsigned int	index;
		
				// --- retrieve previously saved sub
				sub = [_subs objectForKey:line];
				
				if(!sub)
					continue;
				
				// --- add a node
				index = [parentNode indexOfChildWithSub:sub];
				
				if(index == NSNotFound) {
					node = [[TNNode alloc] initWithParent:parentNode sub:sub];
					[parentNode addChild:node];
					[node release];
				} else {
					node = [parentNode->_children objectAtIndex:index];
					node->_calls++;
				}
				
				// --- add for timing
				[_nodes addObject:node];

				// --- climb up
				parentNode = node;
			}
			else if(type == '-') {
				if([line characterAtIndex:2] != '&') {
					// --- climb down
					parentNode = parentNode->_parent;
				}
			}
			else if(type == '&') {
				NSString		*key, *package, *name;
				TNSub			*sub;
				NSRange			range;
				unsigned int	lineLength, lineOffset;
				
				lineLength = [line length];
				lineOffset = 2;

				// --- extract key
				range		= [line rangeOfString:@" " options:0 range:NSMakeRange(lineOffset, lineLength - lineOffset)];
				key			= [line substringWithRange:NSMakeRange(lineOffset, range.location - lineOffset)];
				lineOffset	= range.location + 1;

				// --- extract package
				range		= [line rangeOfString:@" " options:0 range:NSMakeRange(lineOffset, lineLength - lineOffset)];
				package		= [line substringWithRange:NSMakeRange(lineOffset, range.location - lineOffset)];
				lineOffset	= range.location + 1;
				
				// --- extract name
				name		= [line substringWithRange:NSMakeRange(lineOffset, lineLength - lineOffset)];

				// --- add a sub
				sub = [[TNSub alloc] initWithPackage:package name:name color:[self colorForPackage:package]];
				[_subs setObject:sub forKey:[@"+ " stringByAppendingString:key]];
				[sub release];
			}
			else if(type == '@') {
				unsigned int	i, count, stime, utime, ticks;
				
				count = [_nodes count];
				
				if(count > 0) {
					utime = [[line substringWithRange:NSMakeRange(2, 1)] intValue];
					stime = [[line substringWithRange:NSMakeRange(4, 1)] intValue];
					ticks = utime + stime;
					
					if(ticks > 0) {
						double		time;
						
						// --- add time for all nodes since last timestamp
						time = (ticks * secondsPerTick) / count;
						
						for(i = 0; i < count; i++)
							[[_nodes objectAtIndex:i] addTime:time];

						[_nodes removeAllObjects];
					}
				}
			}
		}
	}
	
	// --- post-process node
	[rootNode refreshPercent];
	
	return tree;
}



- (NSColor *)colorForPackage:(NSString *)package {
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
