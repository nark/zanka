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

#import "WCFiles.h"
#import "WCIconCell.h"
#import "WCTableView.h"

@implementation WCTableView

- (id)initWithCoder:(NSCoder *)coder {
	NSMutableCharacterSet	*characterSet;
	
	self = [super initWithCoder:coder];
	
	// --- string for type-ahead
	_typeAheadString = [[NSMutableString alloc] init];
	
	// --- character set of legal characters
	characterSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
	[characterSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	[characterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
	_typeAheadCharacterSet = [characterSet copy];
	[characterSet release];
	
	// --- create array for columns
	_allTableColumns = [[NSMutableArray alloc] init];
	[_allTableColumns addObjectsFromArray:[self tableColumns]];

	// --- create dictionary for tooltips
	_regions = [[NSMutableDictionary alloc] init];
	
	return self;
}



- (void)dealloc {
	[_typeAheadString release];
	[_typeAheadCharacterSet release];
	
	[super dealloc];
}



#pragma mark -

- (void)reloadData {
	[_regions removeAllObjects];
	[self removeAllToolTips];
	
	[super reloadData];
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
	unichar			key;
	unsigned int	flags;
	
	// --- get key
	key = [[event charactersIgnoringModifiers] characterAtIndex:0];
	flags = [event modifierFlags];

	// --- double-click on enter/return
	if(key == NSEnterCharacter || key == NSCarriageReturnCharacter) {
		if([self doubleAction])
			[self doCommandBySelector:[self doubleAction]];
	}
	// --- delete
	else if(key == NSDeleteFunctionKey) {
		if([self deleteAction])
			[self doCommandBySelector:[self deleteAction]];
	}
	// --- enter type-ahead find
	else if([[self dataSource] respondsToSelector:@selector(tableView:stringValueForRow:)] &&
			[_typeAheadCharacterSet characterIsMember:key]) {
		[self interpretKeyEvents:[NSArray arrayWithObject:event]];
	}
	// --- pass down
	else {
		[super keyDown:event];
	}
}



- (void)insertText:(NSString *)string {
	static NSDate			*lastDate;
	NSString				*value;
	NSDate					*date;
	int						i, rows;
	
	// --- get values
	rows	= [self numberOfRows];
	date	= [NSDate date];
	
	// --- compare with previous time
	if([date timeIntervalSinceDate:lastDate] < 0.5)
		[_typeAheadString appendString:string];
	else
		[_typeAheadString setString:string];
	
	// --- save this time
	[lastDate release];
	lastDate = [date retain];
	
	// --- find the first row that matches
	for(i = 0; i < rows; i++) {
		value = [[self dataSource] tableView:self stringValueForRow:i];
		
		if([value compare:_typeAheadString options:NSCaseInsensitiveSearch] > NSOrderedAscending) {
			[self selectRow:i byExtendingSelection:NO];
			[self scrollRowToVisible:i];
			
			break;
		}
	}
}



- (void)moveLeft:(id)sender {
	if([[self delegate] respondsToSelector:@selector(back:)])
	   [[self delegate] back:sender];
}



- (void)moveRight:(id)sender {
	if([[self delegate] respondsToSelector:@selector(forward:)])
	   [[self delegate] forward:sender];
}



- (void)copy:(id)sender {
	if([[self delegate] respondsToSelector:@selector(tableViewShouldCopyInfo:)])
		[[self delegate] tableViewShouldCopyInfo:self];
}



- (void)flagsChanged:(id)sender {
	if([[self delegate] respondsToSelector:@selector(tableViewFlagsDidChange:)])
		[[self delegate] tableViewFlagsDidChange:self];
}



- (void)cancelOperation:(id)sender {
	if([self escapeAction])
		[self doCommandBySelector:[self escapeAction]];
}



#pragma mark -

- (BOOL)clickedHeaderView {
	NSPoint		point;
	
	point = [[self headerView] convertPoint:[[NSApp currentEvent] locationInWindow]
								   fromView:NULL];
	
	return ([[self headerView] hitTest:point] != NULL);
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
		
		if([self autoresizesAllColumnsToFit])
			[self sizeToFit];
		else
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
		
		if([self autoresizesAllColumnsToFit])
			[self sizeToFit];
		else
			[self sizeLastColumnToFit];
		
		[[NSUserDefaults standardUserDefaults] setObject:array forKey:key];
	}
	
	[sheet close];
}

#pragma mark -

- (void)setEscapeAction:(SEL)action {
	_escapeAction = action;
}



- (SEL)escapeAction {
	return _escapeAction;
}



#pragma mark -

- (void)setDeleteAction:(SEL)action {
	_deleteAction = action;
}



- (SEL)deleteAction {
	return _deleteAction;
}



#pragma mark -

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local {
	if(local)
		return NSDragOperationEvery;
	
	return NSDragOperationGeneric;
}



- (NSRect)frameOfCellAtColumn:(int)columnIndex row:(int)rowIndex {
	NSNumber	*tag;
	NSString	*key;
	NSRect		frame;
	
	frame = [super frameOfCellAtColumn:columnIndex row:rowIndex];
	key = [NSString stringWithFormat:@"%d,%d", columnIndex, rowIndex];
	tag = [_regions objectForKey:key];
	
	if(tag)
		[self removeToolTip:[tag intValue]];
	
	tag = [NSNumber numberWithInt:[self addToolTipRect:frame owner:self userData:NULL]];
	[_regions setObject:tag forKey:key];
	
	return frame;
}



- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data {
	int			row;
	
	row = [self rowAtPoint:point];

	if(row >= 0 && [[self dataSource] respondsToSelector:@selector(tableView:toolTipForRow:)])
		return [[self dataSource] tableView:self toolTipForRow:row];

	return NULL;
}

@end
