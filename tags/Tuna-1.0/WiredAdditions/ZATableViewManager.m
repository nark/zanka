/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import <ZankaAdditions/NSColor-ZAAdditions.h>
#import <ZankaAdditions/NSEvent-ZAAdditions.h>
#import <ZankaAdditions/NSFont-ZAAdditions.h>
#import <ZankaAdditions/NSObject-ZAAdditions.h>
#import <ZankaAdditions/ZAOutlineView.h>
#import <ZankaAdditions/ZATableHeaderView.h>
#import <ZankaAdditions/ZATableView.h>

#import "ZATableViewManager.h"

@interface _ZATableViewManager(Private)

- (NSPanel *)_viewOptionsPanel;
- (NSTableColumn *)_tableColumnWithIdentifier:(NSString *)identifier;
- (void)_saveTableColumns;

@end


@implementation _ZATableViewManager

- (id)initWithTableView:(NSTableView *)tableView {
	ZATableHeaderView	*headerView;
	
	self = [super init];
	
	_tableView = tableView;

	_allTableColumns = [[NSMutableArray alloc] initWithCapacity:[_tableView numberOfColumns]];
	[_allTableColumns addObjectsFromArray:[_tableView tableColumns]];
		
	_sortAscendingImage = [[NSImage alloc] initWithContentsOfFile:
		[[NSBundle bundleForClass:[self class]] pathForResource:@"ZASortAscending" ofType:@"tiff"]];
	_sortDescendingImage = [[NSImage alloc] initWithContentsOfFile:
		[[NSBundle bundleForClass:[self class]] pathForResource:@"ZASortDescending" ofType:@"tiff"]];

	if([_tableView isKindOfClass:[NSTableView class]]) {
		_stringValueForRow	= @selector(tableView:stringValueForRow:);
		_shouldCopyInfo		= @selector(tableViewShouldCopyInfo:);
		_flagsDidChange		= @selector(tableViewFlagsDidChange:);
	} else {
		_stringValueForRow	= @selector(outlineView:stringValueForRow:);
		_shouldCopyInfo		= @selector(outlineViewShouldCopyInfo:);
		_flagsDidChange		= @selector(outlineViewFlagsDidChange:);
	}
	
	if([_tableView headerView]) {
		headerView = [[ZATableHeaderView alloc] initWithFrame:[[_tableView headerView] frame]];
		[_tableView setHeaderView:headerView];
		[headerView release];
	}

	return self;
}



- (void)dealloc {
	[_allTableColumns release];

	[_sortAscendingImage release];
	[_sortDescendingImage release];

	[super dealloc];
}



#pragma mark -

- (void)selectRowWithStringValue:(NSString *)string {
	[self selectRowWithStringValue:string options:0];
}



- (void)selectRowWithStringValue:(NSString *)string options:(unsigned int)options {
	NSString	*value, *m, *match;
	int			i, rows, row;
	
	rows = [_tableView numberOfRows];
	m = match = @"";
	
	for(i = 0, row = -1; i < rows; i++) {
		value = [[_tableView delegate] tableView:_tableView stringValueForRow:i];
		m = [value commonPrefixWithString:string options:options];
		
		if([m length] > [match length]) {
			match = m;
			row = i;
		}
	}
	
	if(row >= 0) {
		[_tableView selectRow:row byExtendingSelection:NO];
		[_tableView scrollRowToVisible:row];
	}
}



#pragma mark -

- (BOOL)keyDown:(NSEvent *)event {
	unichar		key;
	
	key = [event character];
	
	if(key == NSEnterCharacter || key == NSCarriageReturnCharacter) {
		if([_tableView doubleAction]) {
			[_tableView doCommandBySelector:[_tableView doubleAction]];
			
			return YES;
		}
	}
	else if(key == NSUpArrowFunctionKey && [event commandKeyModifier]) {
		if([self upAction]) {
			[_tableView doCommandBySelector:[self upAction]];
			
			return YES;
		}
	}
	else if(key == NSDownArrowFunctionKey && [event commandKeyModifier]) {
		if([self downAction]) {
			[_tableView doCommandBySelector:[self downAction]];
			
			return YES;
		}
	}
	else if(key == NSLeftArrowFunctionKey) {
		if([self backAction]) {
			[_tableView doCommandBySelector:[self backAction]];
			
			return YES;
		}
	}
	else if(key == NSRightArrowFunctionKey) {
		if([self forwardAction]) {
			[_tableView doCommandBySelector:[self forwardAction]];
			
			return YES;
		}
	}
	else if(key == NSDeleteFunctionKey) {
		if([self deleteAction]) {
			[_tableView doCommandBySelector:[self deleteAction]];
			
			return YES;
		}
	}
	else if(key == NSEscapeFunctionKey) {
		if([self escapeAction]) {
			[_tableView doCommandBySelector:[self escapeAction]];
			
			return YES;
		}
	}
	
	if([[_tableView delegate] respondsToSelector:_stringValueForRow]) {
		static NSCharacterSet   *set;
		
		if(!set) {
			NSMutableCharacterSet   *mutableSet;
			
			mutableSet = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
			[mutableSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
			[mutableSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
			set = [mutableSet copy];
			[mutableSet release];
		}
		
		if([set characterIsMember:key]) {
			[_tableView interpretKeyEvents:[NSArray arrayWithObject:event]];
			
			return YES;
		}
	}
	
	return NO;
}



- (void)insertText:(NSString *)string {
	if(!_string)
		_string = [[NSMutableString alloc] init];
	
	[_string appendString:string];
	[self selectRowWithStringValue:_string options:NSCaseInsensitiveSearch];
	[_string performSelectorOnce:@selector(setString:) withObject:@"" afterDelay:0.5];
}



- (void)copy:(id)sender {
	if([[_tableView delegate] respondsToSelector:_shouldCopyInfo])
		[[_tableView delegate] performSelector:_shouldCopyInfo withObject:_tableView];
}



- (void)flagsChanged:(id)sender {
	if([[_tableView delegate] respondsToSelector:_flagsDidChange])
		[[_tableView delegate] performSelector:_flagsDidChange withObject:_tableView];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	if([item action] == @selector(showViewOptions:))
		return [self allowsUserCustomization];
	
	return YES;
}



- (IBAction)showViewOptions:(id)sender {
	NSEnumerator	*enumerator;
	NSPanel			*panel;
	id				view;
	
	if([self allowsUserCustomization]) {
		panel = [self _viewOptionsPanel];
		
		if(panel) {
			enumerator = [[[panel contentView] subviews] objectEnumerator];
			
			while((view = [enumerator nextObject])) {
				if([view isKindOfClass:[NSButton class]] && [[view alternateTitle] length] > 0) {
					if([_tableView tableColumnWithIdentifier:[view alternateTitle]])
						[(NSButton *) view setState:NSOnState];
				}
			}

			[NSApp beginSheet:panel
			   modalForWindow:[_tableView window]
				modalDelegate:self
			   didEndSelector:@selector(_viewOptionsSheetDidEnd:returnCode:contextInfo:)
				  contextInfo:NULL];
		}
	}
}



- (NSPanel *)_viewOptionsPanel {
	NSEnumerator	*enumerator;
	NSTableColumn   *tableColumn;
	NSMutableArray  *array;
	NSPanel			*panel;
	NSTextField		*textField;
	NSButton		*button;
	NSRect			rect, contentRect;
	float			width;
	int				i = 0;
	
	if(!_viewOptionsPanel) {
		width = 100.0;
		array = [NSMutableArray array];
		enumerator = [[_allTableColumns subarrayWithRange:NSMakeRange(1, [_allTableColumns count] - 1)] objectEnumerator];
		
		while((tableColumn = [enumerator nextObject])) {
			button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 1000, 1000)];
			[button setButtonType:NSSwitchButton];
			[button setTitle:[[tableColumn headerCell] stringValue]];
			[button setAlternateTitle:[tableColumn identifier]];
			[[button cell] setControlSize:NSSmallControlSize];
			[[button cell] setFont:[NSFont smallSystemFont]];
			[button sizeToFit];
			
			if([button frame].size.width > width)
				width = [button frame].size.width;

			[array addObject:button];
			[button release];
		}
		
		contentRect = NSMakeRect(0.0, 0.0, 50.0 + width + width, 97.0 + (ceil([array count] / (double) 2) * 20.0));
		panel = [[NSPanel alloc] initWithContentRect:contentRect
										   styleMask:NSTitledWindowMask
											 backing:NSBackingStoreBuffered
											   defer:YES];
		
		rect = NSMakeRect(20.0, contentRect.size.height - 40.0, contentRect.size.width - 40.0, 17.0);
		textField = [[NSTextField alloc] initWithFrame:rect];
		[textField setStringValue:NSLocalizedStringFromTableInBundle(@"Show Columns", NULL, [ZAObject bundle], @"ZATableViewManager: configuration panel")];
		[textField setEditable:NO];
		[textField setBordered:NO];
		[textField setDrawsBackground:NO];
		[[panel contentView] addSubview:textField];
		[textField release];
		
		enumerator = [array objectEnumerator];
		
		while((button = [enumerator nextObject])) {
			rect = [button frame];
			rect.origin.x = (i % 2 == 0) ? 29.0 : 29.0 + 4.0 + width;
			rect.origin.y = contentRect.size.height - 43.0 - rect.size.height;
			rect.origin.y -= (floor(i / (double) 2.0)) * 18.0;
			[button setFrame:rect];
			
			[[panel contentView] addSubview:button];
			
			i++;
		}
		
		rect = NSMakeRect(contentRect.size.width - 82.0 - 14.0, 12.0, 82.0, 32.0);
		button = [[NSButton alloc] initWithFrame:rect];
		[button setButtonType:NSMomentaryPushButton];
		[button setTitle:NSLocalizedStringFromTableInBundle(@"OK", NULL, [ZAObject bundle], @"ZATableViewManager: configuration panel")];
		[button setKeyEquivalent:[NSSWF:@"\r"]];
		[button setAction:@selector(submitSheet:)];
		[[button cell] setBezelStyle:NSRoundedBezelStyle];
		[[button cell] setFont:[NSFont smallSystemFont]];
		[[panel contentView] addSubview:button];
		[button release];

		rect = NSMakeRect(contentRect.size.width - 82.0 - 82.0 - 14.0, 12.0, 82.0, 32.0);
		button = [[NSButton alloc] initWithFrame:rect];
		[button setButtonType:NSMomentaryPushButton];
		[button setTitle:NSLocalizedStringFromTableInBundle(@"Cancel", NULL, [ZAObject bundle], @"ZATableViewManager: configuration panel")];
		[button setKeyEquivalent:[NSSWF:@"%C", NSEscapeFunctionKey]];
		[button setAction:@selector(cancelSheet:)];
		[[button cell] setBezelStyle:NSRoundedBezelStyle];
		[[button cell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		[[panel contentView] addSubview:button];
		[button release];

		_viewOptionsPanel = panel;
	}
	
	return _viewOptionsPanel;
}



- (void)_viewOptionsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	NSEnumerator	*enumerator;
	NSString		*identifier;
	id				view;
	
	if(returnCode == NSRunStoppedResponse) {
		enumerator = [[[sheet contentView] subviews] objectEnumerator];
		
		while((view = [enumerator nextObject])) {
			if([view isKindOfClass:[NSButton class]] && [[view alternateTitle] length] > 0) {
				identifier = [view alternateTitle];
				
				if([(NSButton *) view state] == NSOffState)
					[self excludeTableColumnWithIdentifier:identifier];
				else
					[self includeTableColumnWithIdentifier:identifier];
			}
		}
	}
	
	[sheet close];
}



- (NSArray *)allTableColumns {
	return _allTableColumns;
}



- (void)includeTableColumn:(NSTableColumn *)tableColumn {
	[self includeTableColumnWithIdentifier:[tableColumn identifier]];
}



- (void)includeTableColumnWithIdentifier:(NSString *)identifier {
	NSTableColumn		*tableColumn;
	unsigned int		index;
	
	if(![_tableView tableColumnWithIdentifier:identifier]) {
		tableColumn = [self _tableColumnWithIdentifier:identifier];
		
		if(tableColumn) {
			[_tableView addTableColumn:tableColumn];
			
			index = [_allTableColumns indexOfObject:tableColumn];
			
			if(index < [[_tableView tableColumns] count])
				[_tableView moveColumn:[[_tableView tableColumns] count] - 1 toColumn:index];
			
			[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.0];
		}
	}
}



- (void)excludeTableColumn:(NSTableColumn *)tableColumn {
	[self excludeTableColumnWithIdentifier:[tableColumn identifier]];
}



- (void)excludeTableColumnWithIdentifier:(NSString *)identifier {
	[_tableView removeTableColumn:[self _tableColumnWithIdentifier:identifier]];

	[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.0];
}



- (NSTableColumn *)_tableColumnWithIdentifier:(NSString *)identifier {
	NSEnumerator	*enumerator;
	NSTableColumn   *tableColumn;
	
	enumerator = [_allTableColumns objectEnumerator];
	
	while((tableColumn = [enumerator nextObject])) {
		if([[tableColumn identifier] isEqualToString:identifier])
			return tableColumn;
	}
	
	return NULL;
}



- (void)_saveTableColumns {
	NSEnumerator	*enumerator;
	NSMutableArray	*columns;
	NSTableColumn	*column;
	NSString		*key;
	
	columns = [NSMutableArray array];
	enumerator = [[_tableView tableColumns] objectEnumerator];
	
	while((column = [enumerator nextObject]))
		[columns addObject:[column identifier]];
	
	if(![_tableView highlightedTableColumn]) {
		if([[_tableView delegate] respondsToSelector:@selector(tableView:didClickTableColumn:)]) {
			[[_tableView delegate] tableView:_tableView
						 didClickTableColumn:[[_tableView tableColumns] objectAtIndex:0]];
		}
	}

	if([_tableView autoresizesAllColumnsToFit])
		[_tableView sizeToFit];
	else
		[_tableView sizeLastColumnToFit];
	
	key = [NSSWF:@"%@ %@ Columns", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
	[[NSUserDefaults standardUserDefaults] setObject:columns forKey:key];
}




- (ZASortOrder)sortOrder {
	return _sortOrder;
}



- (void)setAutosaveTableColumns:(BOOL)value {
	NSEnumerator	*enumerator;
	NSString		*key, *identifier;
	NSArray			*array, *columns;
	NSNumber		*number;
	
	if(value) {
		key = [NSSWF:@"%@ %@ Columns", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
		array = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
		
		if(array)
			columns = array;
		else if([self defaultTableColumnIdentifiers])
			columns = [self defaultTableColumnIdentifiers];
		else
			columns = NULL;
		
		if(columns) {
			while([_tableView numberOfColumns] > 1)
				[_tableView removeTableColumn:[[_tableView tableColumns] objectAtIndex:1]];
			
			enumerator = [columns objectEnumerator];
			
			while((identifier = [enumerator nextObject]))
				[self includeTableColumnWithIdentifier:identifier];
			
			if([_tableView autoresizesAllColumnsToFit])
				[_tableView sizeToFit];
			else
				[_tableView sizeLastColumnToFit];
		}

		key = [NSSWF:@"%@ %@ Sort Order", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
		number = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		
		if(number)
			_sortOrder = [number intValue];
		else
			_sortOrder = [self defaultSortOrder];
		
		key = [NSSWF:@"%@ %@ Selected Column", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
		identifier = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		
		if(identifier) {
			[_tableView setHighlightedTableColumn:[self _tableColumnWithIdentifier:identifier]];
		}
		else if([self defaultHighlightedTableColumnIdentifier]) {
			[_tableView setHighlightedTableColumn:[self _tableColumnWithIdentifier:
				[self defaultHighlightedTableColumnIdentifier]]];
		}
	}
}



- (void)setHighlightedTableColumn:(NSTableColumn *)tableColumn {
	NSString	*key;
	NSImage		*image;
	
	if([_tableView highlightedTableColumn]) {
		if([_tableView highlightedTableColumn] == tableColumn) {
			_sortOrder = !_sortOrder;
		} else {
			_sortOrder = ZASortAscending;
			[_tableView setIndicatorImage:NULL inTableColumn:[_tableView highlightedTableColumn]];
		}
	}
	
	key = [NSSWF:@"%@ %@ Selected Column", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
	[[NSUserDefaults standardUserDefaults] setObject:[tableColumn identifier] forKey:key];
	
	key = [NSSWF:@"%@ %@ Sort Order", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:_sortOrder] forKey:key];
	
	image = _sortOrder == ZASortAscending ? _sortAscendingImage : _sortDescendingImage;
	[_tableView setIndicatorImage:image  inTableColumn:tableColumn];
}



- (void)setHighlightedTableColumn:(NSTableColumn *)tableColumn sortOrder:(ZASortOrder)sortOrder {
	NSString	*key;
	NSImage		*image;
	
	_sortOrder = sortOrder;
	[_tableView setIndicatorImage:NULL inTableColumn:[_tableView highlightedTableColumn]];
	
	key = [NSSWF:@"%@ %@ Selected Column", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
	[[NSUserDefaults standardUserDefaults] setObject:[tableColumn identifier] forKey:key];
	
	key = [NSSWF:@"%@ %@ Sort Order", NSStringFromClass([_tableView class]), [_tableView autosaveName]];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:_sortOrder] forKey:key];
	
	image = _sortOrder == ZASortAscending ? _sortAscendingImage : _sortDescendingImage;
	[_tableView setIndicatorImage:image  inTableColumn:tableColumn];
}



#pragma mark -

- (void)setAllowsUserCustomization:(BOOL)value {
	_allowsUserCustomization = value;
}



- (BOOL)allowsUserCustomization {
	return _allowsUserCustomization;
}



- (void)setDefaultTableColumnIdentifiers:(NSArray *)columns {
	[columns retain];
	[_defaultTableColumnIdentifiers release];
	
	_defaultTableColumnIdentifiers = columns;
}



- (NSArray *)defaultTableColumnIdentifiers {
	return _defaultTableColumnIdentifiers;
}



- (void)setDefaultHighlightedTableColumnIdentifier:(NSString *)identifier {
	[identifier retain];
	[_defaultHighlightedTableColumnIdentifier release];
	
	_defaultHighlightedTableColumnIdentifier = identifier;
}



- (NSString *)defaultHighlightedTableColumnIdentifier {
	return _defaultHighlightedTableColumnIdentifier;
}



- (void)setDefaultSortOrder:(ZASortOrder)order {
	_defaultSortOrder = order;
}



- (ZASortOrder)defaultSortOrder {
	return _defaultSortOrder;
}



- (void)setUpAction:(SEL)action {
	_upAction = action;
}



- (SEL)upAction {
	return _upAction;
}



- (void)setDownAction:(SEL)action {
	_downAction = action;
}



- (SEL)downAction {
	return _downAction;
}



- (void)setBackAction:(SEL)action {
	_backAction = action;
}



- (SEL)backAction {
	return _backAction;
}



- (void)setForwardAction:(SEL)action {
	_forwardAction = action;
}



- (SEL)forwardAction {
	return _forwardAction;
}



- (void)setEscapeAction:(SEL)action {
	_escapeAction = action;
}



- (SEL)escapeAction {
	return _escapeAction;
}



- (void)setDeleteAction:(SEL)action {
	_deleteAction = action;
}



- (SEL)deleteAction {
	return _deleteAction;
}



- (void)setDrawsStripes:(BOOL)value {
	_drawsStripes = value;
}



- (BOOL)drawsStripes {
	return _drawsStripes;
}



- (void)setFont:(NSFont *)font {
	NSEnumerator	*enumerator;
	NSTableColumn   *tableColumn;
	id				tableCell;
	
	enumerator = [_allTableColumns objectEnumerator];
	
	while((tableColumn = [enumerator nextObject])) {
		tableCell = [tableColumn dataCell];
		
		if([tableCell respondsToSelector:@selector(setFont:)])
			[tableCell setFont:font];
	}
	
	[font retain];
	[_font release];
	
	_font = font;
	
	[_tableView setNeedsDisplay:YES];
}



- (NSFont *)font {
	return _font;
}



#pragma mark -

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local {
	if(local)
		return NSDragOperationEvery;
	
	return NSDragOperationGeneric;
}



- (void)highlightSelectionInClipRect:(NSRect)rect {
	if([self drawsStripes])
		[self drawStripesInRect:rect];
}



- (void)drawStripesInRect:(NSRect)rect {
	NSRect		stripeRect;
	float		height, bottom;
	int			firstStripe;
	
	height = [_tableView rowHeight] + [_tableView intercellSpacing].height;
	bottom = NSMaxY(rect);
	
	firstStripe = rect.origin.y / height;
	
	if(firstStripe % 2 == 0)
		firstStripe++;
	
	[[NSColor stripeColor] set];
	
	stripeRect.origin.x = rect.origin.x;
	stripeRect.origin.y = firstStripe * height;
	stripeRect.size.width = rect.size.width;
	stripeRect.size.height = height;
	
	while(stripeRect.origin.y < bottom) {
		NSRectFill(stripeRect);
		
		stripeRect.origin.y += height * 2.0;
	}
}



- (NSMenu *)menuForEvent:(NSEvent *)event defaultMenu:(NSMenu *)menu {
	int		row;
	
	row = [_tableView rowAtPoint:[_tableView convertPoint:[event locationInWindow] fromView:NULL]];
	
	if(row < 0)
		return NULL;
	
	if(![_tableView isRowSelected:row])
		[_tableView selectRow:row byExtendingSelection:NO];
	
	return menu;
}

@end
