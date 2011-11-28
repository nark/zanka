/* $Id$ */

/*
 *  Copyright (c) 2004 Axel Andersson
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

#import "NSTableViewAdditions.h"

@implementation NSTableView(WCTableViewOptions)

- (void)viewOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSEnumerator	*enumerator;
	NSMutableArray  *array;
	NSTableColumn   *tableColumn;
	id				view;
	
	if(returnCode == NSRunStoppedResponse) {
		enumerator = [[[sheet contentView] subviews] objectEnumerator];
		array = [NSMutableArray array];
		[array addObject:[[[self tableColumns] objectAtIndex:0] identifier]];
		
		while((view = [enumerator nextObject])) {
			if([view isKindOfClass:[NSButton class]] && [[view alternateTitle] length] > 0) {
				if([(NSButton *) view state] == NSOnState) {
					if(![self tableColumnWithIdentifier:[view alternateTitle]]) {
						tableColumn = [[NSTableColumn alloc] initWithIdentifier:[view alternateTitle]];
						[[tableColumn headerCell] setStringValue:
							NSLocalizedStringFromTable([view alternateTitle], @"Columns", @"Columns")];
						[tableColumn setEditable:NO];
						[self addTableColumn:tableColumn];
						[tableColumn release];
					}
					
					[array addObject:[view alternateTitle]];
				} else {
					[self removeTableColumn:
						[self tableColumnWithIdentifier:[view alternateTitle]]];
				}
			}
		}
		
		[[NSUserDefaults standardUserDefaults]
			setObject:array
			   forKey:[NSString stringWithFormat:@"WCTableViewOptions %@ Columns", [self autosaveName]]];
	}
	
	[sheet close];
}



- (void)showViewOptions {
	NSEnumerator	*enumerator;
	id				view;
	
	enumerator = [[[[[self delegate] viewOptionsPanel] contentView] subviews] objectEnumerator];
	
	while((view = [enumerator nextObject])) {
		if([view isKindOfClass:[NSButton class]] && [[view alternateTitle] length] > 0) {
			if([self tableColumnWithIdentifier:[view alternateTitle]])
				[(NSButton *) view setState:NSOnState];
		}
	}
	
	[NSApp beginSheet:[[self delegate] viewOptionsPanel]
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(viewOptionsSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)updateViewOptions {
	NSEnumerator	*enumerator;
	NSString		*key;
	NSArray			*columns;
	NSTableColumn   *tableColumn, *newTableColumn;
	
	key = [NSString stringWithFormat:@"WCTableViewOptions %@ Columns", [self autosaveName]];
	columns = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
	
	if(columns) {
		enumerator = [[self tableColumns] objectEnumerator];
		
		while((tableColumn = [enumerator nextObject])) {
			if([columns containsObject:[tableColumn identifier]]) {
				if(![self tableColumnWithIdentifier:[tableColumn identifier]]) {
					newTableColumn = [[NSTableColumn alloc] initWithIdentifier:[tableColumn identifier]];
					[[newTableColumn headerCell] setStringValue:
						NSLocalizedStringFromTable([tableColumn identifier], @"Columns", @"Columns")];
					[newTableColumn setEditable:NO];
					[self addTableColumn:newTableColumn];
					[newTableColumn release];
				}
			} else {
				[self removeTableColumn:tableColumn];
			}
		}
	}
}

@end
