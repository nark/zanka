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
#import "TNSessionController.h"
#import "TNSub.h"
#import "TNTree.h"

@interface TNSessionController(Private)

- (void)updateDataMiningStatus;
- (void)selectHeaviestPath;
- (void)sortNodes;
- (TNNode *)selectedNode;
- (NSArray *)selectedNodes;
- (NSString *)stringFromTime:(double)time;

@end



@implementation TNSessionController

- (id)initWithTree:(TNTree *)tree {
	self = [super initWithWindowNibName:@"Session"];
	
	_tree = [tree retain];
	
	_statsDisplayMode = TNStatsDisplayPercent;
	_colorByPackage = YES;
	
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
	[_treeOutlineView setDefaultSortOrder:ZASortDescending];
	[_treeOutlineView setOutlineTableColumn:_subTableColumn];
	[_treeOutlineView setAutosaveName:@"Tree"];
	[_treeOutlineView setAutosaveTableColumns:YES];
	[_treeOutlineView setHighlightedTableColumn:_totalTableColumn sortOrder:ZASortDescending];
	[_treeOutlineView setMenu:[[[NSApp mainMenu] itemWithTag:1] submenu]];
	
	[_versionTextField setStringValue:[_tree version]];
	[_frequencyTextField setIntValue:[_tree frequency]];
	[_userTimeTextField setStringValue:[self stringFromTime:[_tree userTime]]];
	[_systemTimeTextField setStringValue:[self stringFromTime:[_tree systemTime]]];
	[_wallclockTimeTextField setStringValue:[self stringFromTime:[_tree wallclockTime]]];
	
	[self sortNodes];
	[_treeOutlineView reloadData];
	[self selectHeaviestPath];
	
	[self updateDataMiningStatus];
	
	[[self window] makeFirstResponder:_treeOutlineView];
}



- (void)infoSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[_infoPanel close];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	NSMutableAttributedString	*attributedString;
	NSString					*string = NULL, *name = NULL;
	TNNode						*node;
	SEL							selector;
	
	selector = [item action];
	
	if(selector == @selector(removeCallstackWithSub:) ||
	   selector == @selector(focusSub:) ||
	   selector == @selector(focusPackage:)) {
		node = [self selectedNode];
		
		if(node ) {
			if(selector == @selector(removeCallstackWithSub:)) {
				string = NSLS(@"Remove Callstack With Sub", @"Menu item");
				name = [[node sub] name];
			}
			else if(selector == @selector(focusSub:)) {
				string = NSLS(@"Focus Sub", @"Menu item");
				name = [[node sub] name];
			}
			else if(selector == @selector(focusPackage:)) {
				string = NSLS(@"Focus Package", @"Menu item");
				name = [[node sub] package];
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
	else if(selector == @selector(restore:) || selector == @selector(restoreAll:))
		return ([_tree canRestoreRootNode]);
	
	return YES;
}



- (void)updateDataMiningStatus {
	if([_tree canRestoreRootNode])
		[_dataMiningTextField setStringValue:NSLS(@"Data Mining Active", "Text field")];
	else
		[_dataMiningTextField setStringValue:@""];
}



- (void)selectHeaviestPath {
	TNNode		*node;
	double		before, after, delta;
	int			row;
	
	node = [_tree rootNode];
	
	while([node children] > 0) {
		before	= [node cumulativePercent];
		node	= [node lastChild];
		after	= [node cumulativePercent];
		delta	= (before - after) / before;
		
		if(delta > 0.5)
			break;
		
		[_treeOutlineView expandItem:node];
	}
	
	row = [_treeOutlineView rowForItem:node];
	
	if(row >= 0)
		[_treeOutlineView selectRow:row byExtendingSelection:NO];
}



- (void)sortNodes {
	NSTableColumn   *tableColumn;;
	SEL				selector;
	
	tableColumn = [_treeOutlineView highlightedTableColumn];
	selector = @selector(compareSub:);
	
	if(tableColumn == _selfTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue)
			selector = @selector(compareTime:);
		else if(_statsDisplayMode == TNStatsDisplayPercent)
			selector = @selector(comparePercent:);
	}
	else if(tableColumn == _totalTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue)
			selector = @selector(compareCumulativeTime:);
		else if(_statsDisplayMode == TNStatsDisplayPercent)
			selector = @selector(compareCumulativePercent:);
	}
	else if(tableColumn == _packageTableColumn)
		selector = @selector(comparePackage:);
	else if(tableColumn == _subTableColumn)
		selector = @selector(compareSub:);

	[[_tree rootNode] sortUsingSelector:selector];
}



- (TNNode *)selectedNode {
	int			row;
	
	row = [_treeOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_treeOutlineView itemAtRow:row];
}



- (NSArray *)selectedNodes {
	NSEnumerator	*enumerator;
	NSMutableArray	*nodes;
	NSNumber		*row;
	
	nodes = [NSMutableArray array];
	enumerator = [_treeOutlineView selectedRowEnumerator];
	
	while((row = [enumerator nextObject]))
		[nodes addObject:[_treeOutlineView itemAtRow:[row unsignedIntValue]]];
	
	return nodes;
}



- (NSString *)stringFromTime:(double)time {
	NSString	*unit;
	
	unit = @"s";
	
	if(time < 0.000001) {
		time *= 1000000000.0;
		unit = @"ns";
	}
	else if(time < 0.001) {
		time *= 1000000.0;
		unit = @"us";
	}
	else if(time < 1.0) {
		time *= 1000.0;
		unit = @"ms";
	}
	
	return [NSSWF:@"%.1f %@", time, unit];
}



#pragma mark -

- (void)getInfo:(id)sender {
	[NSApp beginSheet:_infoPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(infoSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)removeCallstackWithSub:(id)sender {
	TNNode		*node, *rootNode;
	int			row;
	
	row = [_treeOutlineView selectedRow];
	
	rootNode = [[_tree rootNode] retain];
	node = [rootNode copy];
	[[self selectedNode] unlink];
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
		
		[_treeOutlineView expandItem:[self selectedNode]];
	}
	
	[self updateDataMiningStatus];
}



- (void)focusSub:(id)sender {
	TNNode		*node;
	
	node = [[TNNode alloc] init];
	[node addChild:[self selectedNode]];
	[node refreshPercent];
	[_tree pushRootNode:node];
	[node release];

	[_treeOutlineView reloadData];

	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self selectedNode]];
	}

	[self updateDataMiningStatus];
}



- (void)focusPackage:(id)sender {
	TNNode			*node, *childNode;
	NSArray			*nodes;
	NSString		*package;
	unsigned int	i, count;
	
	package = [[[self selectedNode] sub] package];
	node = [[TNNode alloc] init];
	nodes = [[_tree rootNode] nodesMatchingPackage:package];
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
		[_treeOutlineView expandItem:[self selectedNode]];
	}

	[self updateDataMiningStatus];
}



- (void)restore:(id)sender {
	[_tree popRootNode];
	[[_tree rootNode] refreshPercent];
	[_treeOutlineView reloadData];

	[_treeOutlineView reloadData];

	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self selectedNode]];
	}

	[self updateDataMiningStatus];
}



- (void)restoreAll:(id)sender {
	[_tree restoreRootNode];
	[[_tree rootNode] refreshPercent];
	[_treeOutlineView reloadData];

	[_treeOutlineView reloadData];
	
	if([_treeOutlineView numberOfRows] > 0) {
		[_treeOutlineView selectRow:0 byExtendingSelection:NO];
		[_treeOutlineView expandItem:[self selectedNode]];
	}

	[self updateDataMiningStatus];
}



#pragma mark -

- (IBAction)statsDisplayMode:(id)sender {
	_statsDisplayMode = [sender indexOfSelectedItem];

	[_treeOutlineView reloadData];
}



- (IBAction)colorByPackage:(id)sender {
	_colorByPackage = ([sender state] == NSOnState);
	
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

	[self updateDataMiningStatus];
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

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		return [[_tree rootNode] children];
	
	return [(TNNode *) item children];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
	unsigned int	i;
	
	if(!item)
		item = [_tree rootNode];
	
	i = ([_treeOutlineView sortOrder] == ZASortDescending)
		? [(TNNode *) item children] - (unsigned int) index - 1
		: (unsigned int) index;
		
	return [(TNNode *) item childAtIndex:i];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	if(tableColumn == _selfTableColumn || tableColumn == _totalTableColumn) {
		if(_statsDisplayMode == TNStatsDisplayValue) {
			double		time;
		
			time = (tableColumn == _selfTableColumn)
				? [item time]
				: [item cumulativeTime];
			return [self stringFromTime:time];
		}
		else if(_statsDisplayMode == TNStatsDisplayPercent) {
			double		percent ;
			
			percent = (tableColumn == _selfTableColumn)
				? [item percent]
				: [item cumulativePercent];
			
			return [NSSWF:@"%.1f%%", percent];
		}
	}
	else if(tableColumn == _packageTableColumn)
		return [[item sub] package];
	else if(tableColumn == _subTableColumn)
		return [[item sub] name];
	
	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ![item isLeaf];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _packageTableColumn || tableColumn == _subTableColumn)
		[cell setTextColor:_colorByPackage ? [item color] : [NSColor blackColor]];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn {
    [_treeOutlineView setHighlightedTableColumn:tableColumn];
    [self sortNodes];
    [_treeOutlineView reloadData];

    return NO;
}

@end
