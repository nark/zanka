/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import <WiredAdditions/NSColor-WIAdditions.h>
#import <WiredAdditions/NSDictionary-WIAdditions.h>
#import <WiredAdditions/NSEvent-WIAdditions.h>
#import <WiredAdditions/NSFont-WIAdditions.h>
#import <WiredAdditions/NSNotificationCenter-WIAdditions.h>
#import <WiredAdditions/NSObject-WIAdditions.h>
#import <WiredAdditions/WIOutlineView.h>
#import <WiredAdditions/WITableHeaderView.h>
#import <WiredAdditions/WITableView.h>

#import "WITableViewManager.h"

@interface _WITableViewManager(Private)

static int _selectRowCompare(id, id, void *);

- (NSPanel *)_viewOptionsPanel;

- (void)_setTableColumnIdentifiers:(NSArray *)identifiers;
- (NSArray *)_tableColumnIdentifiers;
- (void)_setTableColumnWidths:(NSDictionary *)widths;
- (NSDictionary *)_tableColumnWidths;
- (NSTableColumn *)_tableColumnWithIdentifier:(NSString *)identifier;
- (BOOL)_includeTableColumnWithIdentifier:(NSString *)identifier;
- (BOOL)_excludeTableColumnWithIdentifier:(NSString *)identifier;
- (void)_setHighlightedTableColumnIdentifier:(NSString *)identifier sortOrder:(NSNumber *)sortOrder;
- (void)_sizeToFitLastColumn;
- (void)_saveTableColumns;

@end


@implementation _WITableViewManager(Private)

static int _selectRowCompare(id object1, id object2, void *contextInfo) {
	unsigned int	options;
	
	options = *(unsigned int *) contextInfo;
	
	return [object1 compare:object2 options:options];
}



#pragma mark -

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
		[textField setStringValue:WILS(@"Show Columns", @"WITableViewManager: configuration panel")];
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
		[button setTitle:WILS(@"OK", @"WITableViewManager: configuration panel")];
		[button setKeyEquivalent:[NSSWF:@"\r"]];
		[button setTarget:[[_tableView window] windowController]];
		[button setAction:@selector(submitSheet:)];
		[[button cell] setBezelStyle:NSRoundedBezelStyle];
		[[button cell] setFont:[NSFont systemFont]];
		[[panel contentView] addSubview:button];
		[button release];

		rect = NSMakeRect(contentRect.size.width - 82.0 - 82.0 - 14.0, 12.0, 82.0, 32.0);
		button = [[NSButton alloc] initWithFrame:rect];
		[button setButtonType:NSMomentaryPushButton];
		[button setTitle:WILS(@"Cancel", @"WITableViewManager: configuration panel")];
		[button setKeyEquivalent:[NSSWF:@"%C", NSEscapeFunctionKey]];
		[button setTarget:[[_tableView window] windowController]];
		[button setAction:@selector(cancelSheet:)];
		[[button cell] setBezelStyle:NSRoundedBezelStyle];
		[[button cell] setFont:[NSFont systemFont]];
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
					[self _excludeTableColumnWithIdentifier:identifier];
				else
					[self _includeTableColumnWithIdentifier:identifier];
			}
		}
		
		[self _sizeToFitLastColumn];
		
		if([_tableView autosaveTableColumns])
			[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
	}
	
	[sheet close];
}



#pragma mark -

- (void)_setTableColumnIdentifiers:(NSArray *)identifiers {
	NSEnumerator	*enumerator;
	NSArray			*columns;
	NSString		*identifier;
	
	if(identifiers)
		columns = identifiers;
	else
		columns = [self defaultTableColumnIdentifiers];
	
	if(columns) {
		while([_tableView numberOfColumns] > 1)
			[_tableView removeTableColumn:[[_tableView tableColumns] objectAtIndex:1]];
		
		enumerator = [columns objectEnumerator];
		
		while((identifier = [enumerator nextObject]))
			[self _includeTableColumnWithIdentifier:identifier];
		
		[_tableView sizeToFit];
	}
}



- (NSArray *)_tableColumnIdentifiers {
	NSEnumerator	*enumerator;
	NSMutableArray	*columns;
	NSTableColumn	*column;
	
	columns = [NSMutableArray array];
	enumerator = [[_tableView tableColumns] objectEnumerator];
	
	while((column = [enumerator nextObject]))
		[columns addObject:[column identifier]];
	
	return columns;
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



- (void)_setTableColumnWidths:(NSDictionary *)widths {
	NSEnumerator	*enumerator;
	NSString		*identifier;

	if(!widths)
		return;

	enumerator = [widths keyEnumerator];
		
	while((identifier = [enumerator nextObject]))
		[[self _tableColumnWithIdentifier:identifier] setWidth:[widths doubleForKey:identifier]];
}



- (NSDictionary *)_tableColumnWidths {
	NSMutableDictionary		*widths;
	NSEnumerator			*enumerator;
	NSTableColumn			*tableColumn;
	
	widths = [NSMutableDictionary dictionary];
	enumerator = [_allTableColumns objectEnumerator];
	
	while((tableColumn = [enumerator nextObject]))
		[widths setDouble:[tableColumn width] forKey:[tableColumn identifier]];
	
	return widths;
}



- (BOOL)_includeTableColumnWithIdentifier:(NSString *)identifier {
	NSTableColumn		*tableColumn;
	
	if(![_tableView tableColumnWithIdentifier:identifier]) {
		tableColumn = [self _tableColumnWithIdentifier:identifier];
		
		if(tableColumn) {
			[_tableView addTableColumn:tableColumn];
			
			return YES;
		}
	}
	
	return NO;
}



- (BOOL)_excludeTableColumnWithIdentifier:(NSString *)identifier {
	[_tableView removeTableColumn:[self _tableColumnWithIdentifier:identifier]];

	return YES;
}



- (void)_setHighlightedTableColumnIdentifier:(NSString *)identifier sortOrder:(NSNumber *)sortOrder {
	NSTableColumn		*tableColumn = NULL;
	NSImage				*image;
	
	if(!identifier)
		identifier = [self defaultHighlightedTableColumnIdentifier];
	
	if(identifier)
		tableColumn = [self _tableColumnWithIdentifier:identifier];

	if(tableColumn)
		[_tableView setHighlightedTableColumn:tableColumn];
	
	if(sortOrder)
		_sortOrder = [sortOrder intValue];
	else
		_sortOrder = [self defaultSortOrder];
	
	if(tableColumn) {
		image = _sortOrder == WISortAscending ? _sortAscendingImage : _sortDescendingImage;
		[_tableView setIndicatorImage:image inTableColumn:tableColumn];
	}
}



- (void)_sizeToFitLastColumn {
	NSScrollView		*scrollView;
	NSArray				*tableColumns;
	NSSize				size;
	float				width = 0.0;
	unsigned int		i, count;
	
	tableColumns = [_tableView tableColumns];
	count = [tableColumns count] - 1;
	
	for(i = 0; i < count; i++)
		width += [[tableColumns objectAtIndex:i] width];
	
	scrollView = [_tableView enclosingScrollView];
	size = [scrollView contentSize];
	
	if(width >= size.width - 50.0) {
		width = [[tableColumns objectAtIndex:count - 1] width] / 2.0;

		[[tableColumns objectAtIndex:count - 1] setWidth:width];
		[[tableColumns objectAtIndex:count] setWidth:width];
	}
}



- (void)_saveTableColumns {
	[[NSUserDefaults standardUserDefaults] setObject:[self _tableColumnIdentifiers]
											  forKey:[NSSWF:@"WITableViewManager %@ Columns", [_tableView autosaveName]]];

	[[NSUserDefaults standardUserDefaults] setObject:[self _tableColumnWidths]
											  forKey:[NSSWF:@"WITableViewManager %@ Widths", [_tableView autosaveName]]];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end



@implementation _WITableViewManager

- (id)initWithTableView:(NSTableView *)tableView {
	WITableHeaderView	*headerView;
	
	self = [super init];
	
	_tableView = tableView;

	_allTableColumns = [[NSMutableArray alloc] initWithCapacity:[_tableView numberOfColumns]];
	[_allTableColumns addObjectsFromArray:[_tableView tableColumns]];
		
	_sortAscendingImage = [[NSImage alloc] initWithContentsOfFile:
		[[NSBundle bundleForClass:[self class]] pathForResource:@"WISortAscending" ofType:@"tiff"]];
	_sortDescendingImage = [[NSImage alloc] initWithContentsOfFile:
		[[NSBundle bundleForClass:[self class]] pathForResource:@"WISortDescending" ofType:@"tiff"]];

	if([_tableView isKindOfClass:[NSOutlineView class]]) {
		_stringValueForRow		= @selector(outlineView:stringValueForRow:);
		_shouldCopyInfo			= @selector(outlineViewShouldCopyInfo:);
		_flagsDidChange			= @selector(outlineViewFlagsDidChange:);
		_didClickTableColumn	= @selector(outlineView:didClickTableColumn:);
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(outlineViewColumnDidMove:)
				   name:NSOutlineViewColumnDidMoveNotification
				 object:_tableView];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(outlineViewColumnDidResize:)
				   name:NSOutlineViewColumnDidResizeNotification
				 object:_tableView];
	} else {
		_stringValueForRow		= @selector(tableView:stringValueForRow:);
		_shouldCopyInfo			= @selector(tableViewShouldCopyInfo:);
		_flagsDidChange			= @selector(tableViewFlagsDidChange:);
		_didClickTableColumn	= @selector(tableView:didClickTableColumn:);
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(tableViewColumnDidMove:)
				   name:NSTableViewColumnDidMoveNotification
				 object:_tableView];
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(tableViewColumnDidResize:)
				   name:NSTableViewColumnDidResizeNotification
				 object:_tableView];
	}
	
	if([_tableView headerView]) {
		headerView = [[WITableHeaderView alloc] initWithFrame:[[_tableView headerView] frame]];
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

- (void)tableViewColumnDidMove:(NSNotification *)notification {
	if([_tableView autosaveTableColumns])
		[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
}



- (void)tableViewColumnDidResize:(NSNotification *)notification {
	if([_tableView autosaveTableColumns])
		[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
}



- (void)outlineViewColumnDidMove:(NSNotification *)notification {
	if([_tableView autosaveTableColumns])
		[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
}



- (void)outlineViewColumnDidResize:(NSNotification *)notification {
	if([_tableView autosaveTableColumns])
		[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
}



#pragma mark -

- (void)selectRowWithStringValue:(NSString *)string {
	[self selectRowWithStringValue:string options:0];
}



- (void)selectRowWithStringValue:(NSString *)string options:(unsigned int)options {
	NSMutableArray	*strings;
	NSArray			*sortedStrings;
	NSString		*value, *m, *match;
	unsigned int	i, row, rows;
	
	rows = [_tableView numberOfRows];
	strings = [[NSMutableArray alloc] initWithCapacity:rows];
	
	row = NSNotFound;
	m = match = @"";
	
	for(i = 0; i < rows; i++) {
		value = [[_tableView delegate] tableView:_tableView stringValueForRow:i];
		m = [value commonPrefixWithString:string options:options];
		
		if([m length] > [match length]) {
			match = m;
			row = i;
		}
		
		if(row == NSNotFound)
			[strings addObject:value];
	}
	
	if(row == NSNotFound) {
		sortedStrings = [strings sortedArrayUsingFunction:_selectRowCompare context:&options];
		
		for(i = 0; i < rows; i++) {
			if([[sortedStrings objectAtIndex:i] compare:string options:options] >= NSOrderedSame) {
				row = i;
				
				break;
			}
		}
		
		if(row != NSNotFound)
			row = [strings indexOfObjectIdenticalTo:[sortedStrings objectAtIndex:row]];
	}
	
	if(row != NSNotFound) {
		[_tableView selectRow:row byExtendingSelection:NO];
		[_tableView scrollRowToVisible:row];
	}

	[strings release];
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
					else
						[(NSButton *) view setState:NSOffState];
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



- (NSArray *)allTableColumns {
	return _allTableColumns;
}



- (void)includeTableColumn:(NSTableColumn *)tableColumn {
	[self includeTableColumnWithIdentifier:[tableColumn identifier]];
}



- (void)includeTableColumnWithIdentifier:(NSString *)identifier {
	if([self _includeTableColumnWithIdentifier:identifier]) {
		[self _sizeToFitLastColumn];
		
		if([_tableView autosaveTableColumns])
			[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
	}
}



- (void)excludeTableColumn:(NSTableColumn *)tableColumn {
	[self excludeTableColumnWithIdentifier:[tableColumn identifier]];
}



- (void)excludeTableColumnWithIdentifier:(NSString *)identifier {
	if([self _excludeTableColumnWithIdentifier:identifier]) {
		[self _sizeToFitLastColumn];

		if([_tableView autosaveTableColumns])
			[self performSelectorOnce:@selector(_saveTableColumns) afterDelay:0.1];
	}
}



- (WISortOrder)sortOrder {
	return _sortOrder;
}



- (void)setAutosaveTableColumns:(BOOL)value {
	NSString		*identifier;
	NSArray			*columns;
	NSDictionary	*widths;
	NSNumber		*sortOrder;
	
	if(value) {
		columns = [[NSUserDefaults standardUserDefaults] arrayForKey:
			[NSSWF:@"WITableViewManager %@ Columns", [_tableView autosaveName]]];
		
		[self _setTableColumnIdentifiers:columns];

		widths = [[NSUserDefaults standardUserDefaults] dictionaryForKey:
			[NSSWF:@"WITableViewManager %@ Widths", [_tableView autosaveName]]];
		
		[self _setTableColumnWidths:widths];

		identifier = [[NSUserDefaults standardUserDefaults] objectForKey:
			[NSSWF:@"WITableViewManager %@ Selected Column", [_tableView autosaveName]]];
		
		sortOrder = [[NSUserDefaults standardUserDefaults] objectForKey:
			[NSSWF:@"WITableViewManager %@ Sort Order", [_tableView autosaveName]]];
		
		[self _setHighlightedTableColumnIdentifier:identifier sortOrder:sortOrder];
	}
}



- (void)setHighlightedTableColumn:(NSTableColumn *)tableColumn {
	NSImage		*image;
	
	if([_tableView highlightedTableColumn]) {
		if([_tableView highlightedTableColumn] == tableColumn) {
			_sortOrder = !_sortOrder;
		} else {
			_sortOrder = WISortAscending;
			[_tableView setIndicatorImage:NULL inTableColumn:[_tableView highlightedTableColumn]];
		}
	}
	
	if([_tableView autosaveTableColumns]) {
		[[NSUserDefaults standardUserDefaults] setObject:[tableColumn identifier]
												  forKey:[NSSWF:@"WITableViewManager %@ Selected Column", [_tableView autosaveName]]];
		
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:_sortOrder]
												  forKey:[NSSWF:@"WITableViewManager %@ Sort Order", [_tableView autosaveName]]];

		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	image = _sortOrder == WISortAscending ? _sortAscendingImage : _sortDescendingImage;
	[_tableView setIndicatorImage:image  inTableColumn:tableColumn];
}



#pragma mark -

- (void)setPropertiesFromDictionary:(NSDictionary *)dictionary {
	id		columns, widths, identifier, sortOrder;
	
	if([self allowsUserCustomization])
		columns = [dictionary objectForKey:@"_WITableView_columns"];
	else
		columns = NULL;
		
	[self _setTableColumnIdentifiers:columns];
	
	widths = [dictionary objectForKey:@"_WITableView_widths"];
	
	[self _setTableColumnWidths:widths];

	identifier = [dictionary objectForKey:@"_WITableView_highlightTableColumn_identifier"];
	sortOrder = [dictionary objectForKey:@"_WITableView_sortOrder"];

	[self _setHighlightedTableColumnIdentifier:identifier sortOrder:sortOrder];
}



- (NSDictionary *)propertiesDictionary {
	NSMutableDictionary		*dictionary;
	NSTableColumn			*tableColumn;
	
	dictionary = [NSMutableDictionary dictionary];
	
	[dictionary setObject:[self _tableColumnIdentifiers] forKey:@"_WITableView_columns"];
	[dictionary setObject:[self _tableColumnWidths] forKey:@"_WITableView_widths"];
	[dictionary setInt:_sortOrder forKey:@"_WITableView_sortOrder"];

	tableColumn = [_tableView highlightedTableColumn];
	
	if(tableColumn)
		[dictionary setObject:[tableColumn identifier] forKey:@"_WITableView_highlightTableColumn_identifier"];
		
	return dictionary;
}



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



- (void)setDefaultSortOrder:(WISortOrder)order {
	_defaultSortOrder = order;
}



- (WISortOrder)defaultSortOrder {
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
