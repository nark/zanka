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

#import "WCOutlineView.h"
#import "WCTableView.h"

@implementation WCOutlineView

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	// --- create array for columns
	_allTableColumns = [[NSMutableArray alloc] init];
	[_allTableColumns addObjectsFromArray:[self tableColumns]];
	
	return self;
}



- (void)dealloc {
	[_allTableColumns release];
	
	[super dealloc];
}



#pragma mark -

- (NSMenu *)menuForEvent:(NSEvent *)event {
	int			row;
	
	row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:NULL]];
	
	if(row >= 0) {
		[self selectRow:row byExtendingSelection:NO]; 

		return [super menuForEvent:event];
	}
	
	return NULL;
}



- (void)keyDown:(NSEvent *)event {
	unichar		key;
	
	// --- get key
	key = [[event characters] characterAtIndex:0];

	// --- double-click on enter/return
	if(key == NSEnterCharacter || key == NSCarriageReturnCharacter)
		[super doCommandBySelector:[super doubleAction]];
	else
		[super keyDown:event];
}



- (void)copy:(id)sender {
	if([[self delegate] respondsToSelector:@selector(outlineViewShouldCopyInfo:)])
		[[self delegate] outlineViewShouldCopyInfo:self];
}



- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local {
	if(local)
		return NSDragOperationEvery;
	
	return NSDragOperationGeneric;
}



#pragma mark -

- (void)setAutosaveTableColumns:(BOOL)value {
	NSEnumerator	*enumerator;
	NSString		*key;
	NSArray			*columns;
	NSTableColumn   *tableColumn;
	
	if([[self delegate] conformsToProtocol:@protocol(WCTableViewSelectOptions)]) {
		key = [NSString stringWithFormat:@"WCTableViewOptions %@ Columns", [self autosaveName]];
		columns = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
		enumerator = [[self tableColumns] objectEnumerator];
		
		while((tableColumn = [enumerator nextObject])) {
			if(![columns containsObject:[tableColumn identifier]])
				[self removeTableColumn:tableColumn];
		}
		
		[self sizeLastColumnToFit];
	}
	
	[super setAutosaveTableColumns:value];
}



- (void)showViewOptions {
	NSEnumerator	*enumerator;
	id				view;
	
	if([[self delegate] conformsToProtocol:@protocol(WCTableViewSelectOptions)]) {
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
}



- (void)viewOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSEnumerator	*enumerator, *arrayEnumerator;
	NSMutableArray  *array;
	NSString		*key, *identifier;
	NSTableColumn   *tableColumn;
	id				view;
	
	if(returnCode == NSRunStoppedResponse) {
		key = [NSString stringWithFormat:@"WCTableViewOptions %@ Columns", [self autosaveName]];
		enumerator = [[[sheet contentView] subviews] objectEnumerator];

		array = [NSMutableArray array];
		[array addObject:[[[self tableColumns] objectAtIndex:0] identifier]];
		
		while((view = [enumerator nextObject])) {
			if([view isKindOfClass:[NSButton class]]) {
				identifier = [view alternateTitle];
				
				if(!identifier || [identifier length] == 0)
					continue;
				
				if([(NSButton *) view state] == NSOnState) {
					if(![self tableColumnWithIdentifier:identifier]) {
						arrayEnumerator = [_allTableColumns objectEnumerator];
						
						while((tableColumn = [arrayEnumerator nextObject])) {
							if([identifier isEqualToString:[tableColumn identifier]]) {
								[self addTableColumn:tableColumn];
								[self moveColumn:[[self tableColumns] count] - 1
										toColumn:[_allTableColumns indexOfObject:tableColumn]];
							}
						}
					}

					[array addObject:identifier];
				} else {
					[self removeTableColumn:[self tableColumnWithIdentifier:identifier]];
				}
			}
		}
		
		[self sizeLastColumnToFit];

		[[NSUserDefaults standardUserDefaults] setObject:array forKey:key];
	}
	
	[sheet close];
}

@end
