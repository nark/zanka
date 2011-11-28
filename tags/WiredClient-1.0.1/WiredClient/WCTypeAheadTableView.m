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

#import <sys/time.h>
#import "WCTypeAheadTableView.h"

@implementation WCTypeAheadTableView

- (id)initWithCoder:(NSCoder *)coder {
	NSMutableCharacterSet	*characterSet;

	self = [super initWithCoder:coder];

	// --- string for type-ahead
	_full = [[NSMutableString string] retain];
	
	// --- character set of legal characters
	characterSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	[characterSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	[characterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
	_characterSet = [characterSet copy];
	[characterSet release];	

	return self;
}



- (void)dealloc {
	[_full release];
	[_characterSet release];
	
	[super dealloc];
}



#pragma mark -

- (void)keyDown:(NSEvent *)event {
	if([[event characters] length] > 0) {
		// --- interpret valid keydowns as events to trigger insertText:
		if([_characterSet characterIsMember:[[event characters] characterAtIndex:0]])
			[self interpretKeyEvents:[NSArray arrayWithObject:event]];
		else
			[super keyDown:event];
	}
}



- (void)insertText:(NSString *)string {
	static NSDate			*last;
	NSTableColumn			*column;
	NSString				*value;
	NSDate					*date;
	int						i, rows;
	
	// --- get values
	rows	= [self numberOfRows];
	column	= [[self tableColumns] objectAtIndex:0];
	date	= [NSDate date];
	
	// --- compare with previous time
	if([date timeIntervalSinceDate:last] < 0.5)
		[_full appendString:string];
	else
		[_full setString:string];
	
	// --- save this time
	[last release];
	last = [date retain];
	
	// --- find the first row that matches
	for(i = 0; i < rows; i++) {
		value = [[[self dataSource] tableView:self objectValueForTableColumn:column row:i] objectAtIndex:0];
		
		if([value compare:_full options:NSCaseInsensitiveSearch] > NSOrderedAscending) {
			[self selectRow:i byExtendingSelection:NO];
			[self scrollRowToVisible:i];
			
			break;
		}
	}
}

@end
