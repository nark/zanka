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
#import "TNPerlTree.h"
#import "TNSessionController.h"

@interface TNSessionController(Private)

- (void)_updateDataMiningStatus;
- (void)_selectHeaviestPath;
- (void)_sortNodes;
- (TNNode *)_selectedNode;
- (NSArray *)_selectedNodes;
- (NSString *)_stringFromTime:(NSTimeInterval)time;

@end


@implementation TNSessionController(Private)

- (void)_updateDataMiningStatus {
	if([_tree canRestoreRootNode])
		[_dataMiningTextField setStringValue:NSLS(@"Data Mining Active", "Text field")];
	else
		[_dataMiningTextField setStringValue:@""];
}



- (void)_selectHeaviestPath {
	TNNode		*node;
	double		before, after, delta;
	NSInteger	row;

	node = [_tree rootNode];
	
	while([node children] > 0) {
		before	= [node cumulativePercent];
		node	= [node childWithHighestCumulativePercent];
		after	= [node cumulativePercent];
		delta	= (before - after) / before;
		
		if(delta > 0.5)
			break;
		
		[_treeOutlineView expandItem:node];
	}
	
	row = [_treeOutlineView rowForItem:node];
	
	if(row >= 0) {
		[_treeOutlineView selectRow:row byExtendingSelection:NO];
		[_treeOutlineView scrollRowToVisible:row];
	}
}



- (void)_sortNodes {
	NSTableColumn   *tableColumn;;
	SEL				selector;
	
	tableColumn = [_treeOutlineView highlightedTableColumn];
	selector = @selector(compareSymbol:);
	
	if(tableColumn == _selfTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue)
			selector = @selector(compareValue:);
		else if(_statsDisplayMode == TNStatsDisplayPercent)
			selector = @selector(comparePercent:);
	}
	else if(tableColumn == _totalTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue)
			selector = @selector(compareCumulativeValue:);
		else if(_statsDisplayMode == TNStatsDisplayPercent)
			selector = @selector(compareCumulativePercent:);
	}
	else if(tableColumn == _libraryTableColumn)
		selector = @selector(compareLibrary:);
	else if(tableColumn == _symbolTableColumn)
		selector = @selector(compareSymbol:);

	[[_tree rootNode] sortUsingSelector:selector order:[_treeOutlineView sortOrder]];
}



- (TNNode *)_selectedNode {
	NSInteger		row;
	
	row = [_treeOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_treeOutlineView itemAtRow:row];
}



- (NSArray *)_selectedNodes {
	NSEnumerator	*enumerator;
	NSMutableArray	*nodes;
	NSNumber		*row;
	
	nodes = [NSMutableArray array];
	enumerator = [_treeOutlineView selectedRowEnumerator];
	
	while((row = [enumerator nextObject]))
		[nodes addObject:[_treeOutlineView itemAtRow:[row unsignedIntValue]]];
	
	return nodes;
}



- (NSString *)_stringFromTime:(NSTimeInterval)time {
	NSString	*unit;
	
	unit = @"s";
	
	if(time < 0.000001) {
		time *= 1000000000.0;
		unit = @"ns";
	}
	else if(time < 0.001) {
		time *= 1000000.0;
		unit = [NSSWF:@"%Cs", 0x00B5];
	}
	else if(time < 1.0) {
		time *= 1000.0;
		unit = @"ms";
	}
	
	return [NSSWF:@"%.1f %@", time, unit];
}

@end



@implementation TNSessionController

- (id)initWithTree:(id)tree {
	self = [super initWithWindowNibName:@"Session"];
	
	_tree = [tree retain];
	
	_statsDisplayMode = TNStatsDisplayPercent;
	_colorByLibrary = YES;
	
	return self;
}



- (void)dealloc {
	[_tree release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
    [self setShouldCascadeWindows:YES];
    [self setWindowFrameAutosaveName:@"Session"];
	
	[_treeOutlineView setDefaultHighlightedTableColumnIdentifier:@"Total"];
	[_treeOutlineView setDefaultSortOrder:WISortDescending];
	[_treeOutlineView setOutlineTableColumn:_symbolTableColumn];
	[_treeOutlineView setAutoresizesOutlineColumn:NO];
	[_treeOutlineView setAutosaveName:@"Tree"];
	[_treeOutlineView setAutosaveTableColumns:YES];
	[_treeOutlineView setMenu:[[[NSApp mainMenu] itemWithTag:1] submenu]];

	[_symbolTableColumn setWidth:600.0];
	
	if([_tree isKindOfClass:[TNPerlTree class]]) {
		[_perlVersionTextField setStringValue:[_tree version]];
		[_perlFrequencyTextField setIntValue:[_tree frequency]];
		[_perlUserTimeTextField setStringValue:[self _stringFromTime:[_tree userTime]]];
		[_perlSystemTimeTextField setStringValue:[self _stringFromTime:[_tree systemTime]]];
		[_perlWallclockTimeTextField setStringValue:[self _stringFromTime:[_tree wallclockTime]]];
	} else {
		[_treeOutlineView removeTableColumn:_selfTableColumn];
	}
	
	[self _sortNodes];
	[_treeOutlineView reloadData];
	[self _selectHeaviestPath];
	
	[self _updateDataMiningStatus];
	
	[[self window] makeFirstResponder:_treeOutlineView];
}



- (void)infoSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	[sheet close];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	NSMutableAttributedString	*attributedString;
	NSString					*string = NULL, *name = NULL;
	TNNode						*node;
	SEL							selector;
	
	selector = [item action];
	
	if(selector == @selector(removeCallstackWithSymbol:) ||
	   selector == @selector(focusSymbol:) ||
	   selector == @selector(focusLibrary:)) {
		node = [self _selectedNode];
		
		if(node ) {
			if(selector == @selector(removeCallstackWithSymbol:)) {
				string = NSLS(@"Remove Callstack With Symbol", @"Menu item");
				name = [[node function] symbol];
			}
			else if(selector == @selector(focusSymbol:)) {
				string = NSLS(@"Focus Symbol", @"Menu item");
				name = [[node function] symbol];
			}
			else if(selector == @selector(focusLibrary:)) {
				string = NSLS(@"Focus Library", @"Menu item");
				name = [[node function] library];
			}
			
			attributedString = [NSMutableAttributedString attributedStringWithString:
				[string stringByAppendingFormat:@" %@", name]];
			[attributedString addAttribute:NSFontAttributeName
									 value:[NSFont menuBarFontOfSize:0.0]
									  range:NSMakeRange(0, [string length])];
			[attributedString addAttribute:NSFontAttributeName
									 value:[[NSFont menuBarFontOfSize:0.0] boldFont]
									  range:NSMakeRange([string length] + 1, [name length])];
			
			[item setAttributedTitle:attributedString];
		}
		
		return (node != NULL);
	}
	else if(selector == @selector(restore:) || selector == @selector(restoreAll:)) {
		return ([_tree canRestoreRootNode]);
	}
	else if(selector == @selector(getInfo:)) {
		return [_tree isKindOfClass:[TNPerlTree class]];
	}
	
	return YES;
}



#pragma mark -

- (BOOL)findString:(NSString *)string {
	TNNode			*selectedNode, *node, *parentNode;
	NSMutableArray	*nodes;
	NSUInteger		i, count;
	NSInteger		row;
	
	selectedNode = [self _selectedNode];
	node = [[_tree rootNode] nodeMatchingSymbolSubstring:string afterNode:selectedNode];
	
	if(!node)
		node = [[_tree rootNode] nodeMatchingSymbolSubstring:string beforeNode:selectedNode];
	
	if(node) {
		nodes = [[NSMutableArray alloc] init];
		parentNode = node;
		
		while(parentNode) {
			[nodes addObject:parentNode];
			parentNode = [parentNode parent];
		}
		
		count = [nodes count];
		
		for(i = count; i > 0; i--)
			[_treeOutlineView expandItem:[nodes objectAtIndex:i - 1]];
		
		row = [_treeOutlineView rowForItem:node];
		
		if(row >= 0) {
			[_treeOutlineView selectRow:row byExtendingSelection:NO];
			[_treeOutlineView scrollRowToVisible:row];
		}
		
		[nodes release];
		
		return YES;
	}
	
	return NO;
}



#pragma mark -

- (void)getInfo:(id)sender {
	if([_tree isKindOfClass:[TNPerlTree class]]) {
		[NSApp beginSheet:_perlInfoPanel
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:@selector(infoSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:NULL];
	}
}



- (void)removeCallstackWithSymbol:(id)sender {
	TNNode		*node, *rootNode;
	NSInteger	row;
	
	row = [_treeOutlineView selectedRow];
	
	rootNode = [[_tree rootNode] retain];
	node = [rootNode copy];
	[[self _selectedNode] unlink];
	[rootNode refreshPercent];
	[_tree popRootNode];
	[_tree pushRootNode:node];
	[_tree pushRootNode:rootNode];
	[node release];
	[rootNode release];

	[_treeOutlineView reloadData];
	
	if([_treeOutlineView numberOfRows] > 0) {
		if([_treeOutlineView selectedRow] < 0)
			[_treeOutlineView selectRow:row > 0 ? row - 1 : 0 byExtendingSelection:NO];
		
		[_treeOutlineView expandItem:[self _selectedNode]];
	}
	
	[self _updateDataMiningStatus];
}



- (void)focusSymbol:(id)sender {
	TNNode		*node;
	
	node = [[TNNode alloc] init];
	[node addChild:[self _selectedNode]];
	[node refreshPercent];
	[_tree pushRootNode:node];
	[node release];

	[_treeOutlineView reloadData];

	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self _selectedNode]];
	}

	[self _updateDataMiningStatus];
}



- (void)focusLibrary:(id)sender {
	TNNode			*node, *childNode;
	NSArray			*nodes;
	NSString		*library;
	NSUInteger		i, count;
	
	library = [[[self _selectedNode] function] library];
	node = [[TNNode alloc] init];
	nodes = [[_tree rootNode] nodesMatchingLibrary:library];
	count = [nodes count];
	
	for(i = 0; i < count; i++) {
		childNode = [[nodes objectAtIndex:i] copy];
		[node addChild:childNode];
		[childNode release];
	}
	
	[node collapse];
	[node refreshPercent];
	[_tree pushRootNode:node];
	[node release];
	
	[_treeOutlineView reloadData];

	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self _selectedNode]];
	}

	[self _updateDataMiningStatus];
}



- (void)restore:(id)sender {
	[_tree popRootNode];
	[[_tree rootNode] refreshPercent];
	[_treeOutlineView reloadData];

	[_treeOutlineView reloadData];

	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self _selectedNode]];
	}

	[self _updateDataMiningStatus];
	[self _selectHeaviestPath];
}



- (void)restoreAll:(id)sender {
	[_tree restoreRootNode];
	[[_tree rootNode] refreshPercent];
	[_treeOutlineView reloadData];

	[_treeOutlineView reloadData];
	
	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self _selectedNode]];
	}

	[self _updateDataMiningStatus];
	[self _selectHeaviestPath];
}



- (void)showFonts:(id)sender {
	[[NSFontManager sharedFontManager] setSelectedFont:[_treeOutlineView font] isMultiple:NO];
	[[NSFontManager sharedFontManager] orderFrontFontPanel:self];
}



- (void)changeFont:(id)sender {
	NSFont		*font;
	
	font = [sender convertFont:[_treeOutlineView font]];
	
	[_treeOutlineView setFont:font];
	[_treeOutlineView setRowHeight:([font capHeight] * 2.0) - ([font capHeight] / 4.0)];
}



#pragma mark -

- (IBAction)statsDisplayMode:(id)sender {
	_statsDisplayMode = [sender indexOfSelectedItem];

	[_treeOutlineView reloadData];
}



- (IBAction)colorByLibrary:(id)sender {
	_colorByLibrary = ([sender state] == NSOnState);
	
	[_treeOutlineView setNeedsDisplay:YES];
}



- (IBAction)hideWeight:(id)sender {
	TNNode		*node;
	
	if([sender state] == NSOnState) {
		[_weightTextField setEnabled:YES];
		
		node = [[_tree rootNode] copy];
		[node discardNodesWithCumulativePercentLessThan:[_weightTextField floatValue]];
		[_tree pushRootNode:node];
		[node release];
	} else {
		[_weightTextField setEnabled:NO];
		
		[_tree popRootNode];
	}

	[_treeOutlineView reloadData];

	[self _updateDataMiningStatus];
}



- (IBAction)hideWeightPercent:(id)sender {
	TNNode	*node;
	
	[_tree popRootNode];
	node = [[_tree rootNode] copy];
	[node discardNodesWithCumulativePercentLessThan:[_weightTextField floatValue]];
	[_tree pushRootNode:node];
	[node release];

	[_treeOutlineView reloadData];
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		return [(TNNode *) [_tree rootNode] children];
	
	return [(TNNode *) item children];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		item = [_tree rootNode];
	
	return [(TNNode *) item childAtIndex:index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	TNNode		*node;
	
	node = item;
	
	if(tableColumn == _selfTableColumn || tableColumn == _totalTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue) {
			if([_tree isKindOfClass:[TNPerlTree class]]) {
				NSTimeInterval		time;
		
				time = (tableColumn == _selfTableColumn)
					? [(TNPerlNode *) node time]
					: [(TNPerlNode *) node cumulativeTime];

				return [self _stringFromTime:time];
			} else {
				return [NSSWF:@"%u", [node calls]];
			}
		}
		else if(_statsDisplayMode == TNStatsDisplayPercent) {
			double		percent;
			
			percent = (tableColumn == _selfTableColumn)
				? [node percent]
				: [node cumulativePercent];
			
			return [NSSWF:@"%.1f%%", percent];
		}
	}
	else if(tableColumn == _libraryTableColumn)
		return [[node function] library];
	else if(tableColumn == _symbolTableColumn)
		return [[node function] symbol];
	
	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ![item isLeaf];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _libraryTableColumn || tableColumn == _symbolTableColumn)
		[cell setTextColor:_colorByLibrary ? [item color] : [NSColor blackColor]];
}



- (void)outlineViewItemDidExpand:(NSNotification *)notification {
	TNNode		*node;
	id			cell;
	CGFloat		width;
	
	node = [[notification userInfo] objectForKey:@"NSObject"];
	cell = [_symbolTableColumn dataCell];
	[cell setStringValue:[[node function] symbol]];
	width = [[_symbolTableColumn dataCell] cellSize].width +
		([_treeOutlineView levelForItem:node] * [_treeOutlineView indentationPerLevel]);
	
	if(width > [_symbolTableColumn width])
		[_symbolTableColumn setWidth:width];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn {
    [_treeOutlineView setHighlightedTableColumn:tableColumn];
    [self _sortNodes];
    [_treeOutlineView reloadData];

    return NO;
}



- (void)outlineViewShouldCopyInfo:(NSOutlineView *)outlineView {
	NSEnumerator		*enumerator;
	NSPasteboard		*pasteboard;
	NSMutableArray		*rows;
	NSMutableString		*indentation, *string;
	NSArray				*nodes;
	TNNode				*node;
	NSInteger			level, baseLevel;
	BOOL				showSelf;
	
	nodes = [self _selectedNodes];
	
	if([nodes count] > 0) {
		rows = [NSMutableArray array];
		indentation = [NSMutableString string];
		baseLevel = [_treeOutlineView levelForItem:[nodes objectAtIndex:0]];
		enumerator = [nodes objectEnumerator];
		showSelf = [[_treeOutlineView tableColumns] containsObject:_selfTableColumn];
		
		while((node = [enumerator nextObject])) {
			[indentation setString:@""];
			
			level = [_treeOutlineView levelForItem:node] - baseLevel;
			
			while(level > 0) {
				[indentation appendString:@"  "];
				level--;
			}
			
			string = [NSMutableString stringWithFormat:@"%@%.1f%% %@ %@",
				indentation,
				[node cumulativePercent],
				[[node function] library],
				[[node function] symbol]];
			
			if(showSelf)
				[string insertString:[NSSWF:@"%.1f%% ", [node percent]] atIndex:[indentation length]];
			
			[rows addObject:string];
		}
		
		pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
		[pasteboard setString:[rows componentsJoinedByString:@"\n"] forType:NSStringPboardType];
	}
}

@end
