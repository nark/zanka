/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import <WiredAppKit/NSEvent-WIAppKit.h>
#import <WiredAppKit/WITreeCell.h>
#import <WiredAppKit/WITreeTableView.h>
#import <WiredAppKit/WITreeScrollView.h>
#import <WiredAppKit/WITreeView.h>

#define _WITreeViewMinimumTableViewWidth				50.0
#define _WITreeViewMinimumDetailViewWidth				220.0
#define _WITreeViewInitialTableViewWidth				250.0
#define _WITreeViewAnimatedScrollingFPS					(1.0 / 60.0)


NSString * const WIFileIcon								= @"WIFileIcon";
NSString * const WIFileSize								= @"WIFileSize";
NSString * const WIFileKind								= @"WIFileKind";
NSString * const WIFileCreationDate						= @"WIFileCreationDate";
NSString * const WIFileModificationDate					= @"WIFileModificationDate";


@interface WITreeView(Private)

- (void)_initTreeView;

- (void)_addTableView;
- (void)_sizeToFit;
- (CGFloat)_widthOfTableViews:(NSUInteger)count;
- (void)_scrollToIndex:(NSUInteger)index;
- (void)_scrollToSelection;
- (void)_scrollForwardToSelectionAnimated;

- (void)_showDetailViewForPath:(NSString *)path;
- (void)_hideDetailView;
- (void)_resizeDetailView;

- (void)_setPath:(NSString *)path;
- (NSString *)_path;
- (NSUInteger)_numberOfUsedPathComponents;

- (WITreeScrollView *)_newScrollViewWithTableView;
- (NSString *)_pathForTableView:(NSTableView *)tableView;
- (NSArray *)_tableViewsAheadOfTableView:(NSTableView *)tableView;

@end


@implementation WITreeView(Private)

- (void)_initTreeView {
	_views = [[NSMutableArray alloc] init];
	
	[WIDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[NSBundle loadNibNamed:@"TreeDetail" owner:self];
	
	[self setPostsFrameChangedNotifications:YES];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WI_viewFrameDidChangeNotification:)
			   name:NSViewFrameDidChangeNotification
			 object:self];
	
	[self setRootPath:@"/"];
	
	[self _addTableView];
	[self _addTableView];
}



#pragma mark -

- (void)_addTableView {
	NSScrollView		*scrollView;
	NSRect				frame;
	NSUInteger			i, count;
	CGFloat				offset = 0.0;
	
	scrollView = [self _newScrollViewWithTableView];

	count = [_views count];
	
	for(i = 0; i < count; i++)
		offset += [[[_views objectAtIndex:i] enclosingScrollView] frame].size.width - 1.0;
	
	frame = [scrollView frame];
	frame.origin.x = offset - 1.0;
	[scrollView setFrame:frame];
	
	[_views addObject:[scrollView documentView]];
	[self addSubview:scrollView];
	
	[scrollView release];
}



- (void)_sizeToFit {
	NSRect		frame;
	NSSize		size;
	
	frame = [self frame];
	frame.size.width = [self _widthOfTableViews:[self _numberOfUsedPathComponents] + 1];
	size = [[self enclosingScrollView] documentVisibleRect].size;
	
	if(frame.size.width < size.width)
		frame.size.width = size.width;

	[self setFrame:frame];
}



- (CGFloat)_widthOfTableViews:(NSUInteger)count {
	NSUInteger		i;
	CGFloat			width = 0.0;
	
	for(i = 0; i < count; i++)
		width += [[[_views objectAtIndex:i] enclosingScrollView] frame].size.width - 1.0;
	
	return width;
}



- (void)_scrollToIndex:(NSUInteger)index {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_scrollToSelectionAnimated) object:NULL];
	
	_scrollingPoint = NSMakePoint([self _widthOfTableViews:index], 0.0);
	
	[self _scrollForwardToSelectionAnimated];
}



- (void)_scrollToSelection {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_scrollToSelectionAnimated) object:NULL];
	
	_scrollingPoint = NSMakePoint([self frame].size.width, 0.0);
	
	[self _scrollForwardToSelectionAnimated];
}



- (void)_scrollForwardToSelectionAnimated {
	NSPoint		startPoint, point;
	
	startPoint = [[self enclosingScrollView] documentVisibleRect].origin;
	point = NSMakePoint(startPoint.x + ((_scrollingPoint.x - startPoint.x) * _WITreeViewAnimatedScrollingFPS * (1.0 / 0.2)), 0.0);
	
	[self scrollPoint:point];
	
	point = [[self enclosingScrollView] documentVisibleRect].origin;
	
	if(point.x > startPoint.x && point.x < _scrollingPoint.x)
		[self performSelector:@selector(_scrollForwardToSelectionAnimated) withObject:NULL afterDelay:_WITreeViewAnimatedScrollingFPS];
}



#pragma mark -

- (void)_showDetailViewForPath:(NSString *)path {
	NSDictionary	*attributes;
	NSImage			*icon;
	id				value;
	
	attributes = [[self delegate] treeView:self attributesForPath:path];
	
	if(!attributes) {
		[self _hideDetailView];
		
		return;
	}
	
	[self _resizeDetailView];
	
	icon = [attributes objectForKey:WIFileIcon];
	[icon setSize:NSMakeSize(128.0, 128.0)];
	[_iconImageView setImage:icon];
	
	[_nameTextField setStringValue:[path lastPathComponent]];
	
	if((value = [attributes objectForKey:WIFileKind]))
		[_kindTextField setStringValue:value];
	else
		[_kindTextField setStringValue:@""];
	
	[_sizeTextField setStringValue:[NSString humanReadableStringForSizeInBytes:[[attributes objectForKey:WIFileSize] unsignedLongLongValue]]];

	if((value = [attributes objectForKey:WIFileCreationDate]))
		[_createdTextField setStringValue:[_dateFormatter stringFromDate:value]];
	else
		[_createdTextField setStringValue:@""];
		
	if((value = [attributes objectForKey:WIFileModificationDate]))
		[_modifiedTextField setStringValue:[_dateFormatter stringFromDate:value]];
	else
		[_modifiedTextField setStringValue:@""];
	
	if(![_detailView superview])
		[self addSubview:_detailView];
}



- (void)_hideDetailView {
	[_detailView removeFromSuperview];
}



- (void)_resizeDetailView {
	NSRect		frame, lastScrollViewFrame, viewFrame;
	
	lastScrollViewFrame = [[[_views objectAtIndex:[self _numberOfUsedPathComponents]] enclosingScrollView] frame];
	
	frame = [_detailView frame];
	frame.size.width = lastScrollViewFrame.size.width - [NSScroller scrollerWidth] - 1.0;
	frame.size.height = lastScrollViewFrame.size.height;
	frame.origin.x = [self _widthOfTableViews:[self _numberOfUsedPathComponents]];
	[_detailView setFrame:frame];
	
	viewFrame = [_iconImageView frame];
	viewFrame.origin.x = (frame.size.width / 2.0) - (viewFrame.size.width / 2.0);
	[_iconImageView setFrame:viewFrame];
	
	viewFrame = [_attributesView frame];
	viewFrame.origin.x = (frame.size.width / 2.0) - (viewFrame.size.width / 2.0);
	[_attributesView setFrame:viewFrame];
}



#pragma mark -

- (void)_setPath:(NSString *)path {
	[path retain];
	[_path release];
	
	_path = path;
	
	[self reloadData];
	
	if(!_inChangedPath) {
		_inChangedPath = YES;
		[[self delegate] treeView:self changedPath:_path];
		_inChangedPath = NO;
	}
}



- (NSString *)_path {
	return _path;
}



- (NSUInteger)_numberOfUsedPathComponents {
	return [[[self _path] pathComponents] count] - [[[self rootPath] pathComponents] count];
}



#pragma mark -

- (WITreeScrollView *)_newScrollViewWithTableView {
	NSTableColumn		*tableColumn;
	WITreeScrollView	*scrollView;
	WITreeTableView		*tableView;
	WITreeCell			*cell;
	NSRect				frame;
	
	frame = [self frame];
	
	tableView = [[[WITreeTableView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)] autorelease];
	[tableView setDelegate:self];
	[tableView setDataSource:self];
	[tableView setHeaderView:NULL];
	[tableView setAllowsMultipleSelection:YES];
	[tableView setFocusRingType:NSFocusRingTypeNone];
	[tableView setTarget:self];
	[tableView setAction:@selector(tableViewSingleClick:)];
	[tableView setDoubleAction:@selector(tableViewDoubleClick:)];
	[tableView setEscapeAction:@selector(tableViewEscape:)];
	[tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	[tableView setDraggingSourceOperationMask:_draggingSourceOperationMaskForLocal forLocal:YES];
	[tableView setDraggingSourceOperationMask:_draggingSourceOperationMaskForNonLocal forLocal:NO];
	[tableView registerForDraggedTypes:[self registeredDraggedTypes]];
	[tableView setMenu:[self menu]];
	
	cell = [[[WITreeCell alloc] init] autorelease];
	
	tableColumn = [[[NSTableColumn alloc] initWithIdentifier:@""] autorelease];
	[tableColumn setEditable:NO];
	[tableColumn setDataCell:cell];
	[tableColumn setWidth:230.0];
	
	[tableView addTableColumn:tableColumn];
	
	scrollView = [[WITreeScrollView alloc] initWithFrame:NSMakeRect(0.0, -1.0, _WITreeViewInitialTableViewWidth, frame.size.height + 2.0)];
	[scrollView setDelegate:self];
	[scrollView setDocumentView:tableView];
	[scrollView setBorderType:NSBezelBorder];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setAutoresizingMask:NSViewHeightSizable];

	return scrollView;
}



- (NSString *)_pathForTableView:(NSTableView *)tableView {
	NSArray			*components;
	NSString		*path;
	NSUInteger		index, count;
	
	index = [_views indexOfObject:tableView];
	
	if(index == NSNotFound)
		return NULL;
	
	if(index == 0) {
		path = [self rootPath];
	} else {
		components = [[self _path] pathComponents];
		count = [[[self rootPath] pathComponents] count];
		
		if(index + count > [components count])
			return NULL;
		
		path = [NSString pathWithComponents:[components subarrayToIndex:index + count]];
	}
	
	return path;
}



- (NSArray *)_tableViewsAheadOfTableView:(NSTableView *)tableView {
	NSUInteger		index;
	
	index = [_views indexOfObject:tableView];
	
	if(index == NSNotFound || index == [_views count] - 1)
		return NULL;
	
	return [_views subarrayWithRange:NSMakeRange(index + 1, [_views count] - index - 1)];
}

@end



@implementation WITreeView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	
	[self _initTreeView];
	
    return self;
}



- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
	
	[self _initTreeView];
	
    return self;
}



- (void)dealloc {
	[_views release];
	[_path release];
	[_detailView release];
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}




- (id)delegate {
	return delegate;
}



- (void)setDataSource:(id)newDataSource {
	dataSource = newDataSource;
}



- (id)dataSource {
	return dataSource;
}



- (void)setRootPath:(NSString *)rootPath {
	[rootPath retain];
	[_rootPath release];
	
	_rootPath = rootPath;
	
	[self _setPath:rootPath];
}



- (NSString *)rootPath {
	return _rootPath;
}



- (void)setTarget:(id)target {
	_target = target;
}



- (id)target {
	return _target;
}



- (void)setDoubleAction:(SEL)doubleAction {
	_doubleAction = doubleAction;
}



- (SEL)doubleAction {
	return _doubleAction;
}



#pragma mark -

- (void)setDraggingSourceOperationMask:(NSDragOperation)mask forLocal:(BOOL)isLocal {
	NSEnumerator		*enumerator;
	NSTableView			*tableView;
	
	if(isLocal)
		_draggingSourceOperationMaskForLocal = mask;
	else
		_draggingSourceOperationMaskForNonLocal = mask;
	
	enumerator = [_views objectEnumerator];
	
	while((tableView = [enumerator nextObject]))
		[tableView setDraggingSourceOperationMask:mask forLocal:isLocal];
}



#pragma mark -

- (NSString *)selectedPath {
	return _path;
}



- (NSArray *)selectedPaths {
	NSMutableArray		*paths;
	NSIndexSet			*indexes;
	NSString			*path, *name;
	id					responder;
	NSUInteger			index;
	
	paths		= [NSMutableArray array];
	responder	= [[self window] firstResponder];
	
	if([responder isKindOfClass:[NSTableView class]]) {
		path = [self _pathForTableView:responder];
		
		if(path) {
			indexes		= [responder selectedRowIndexes];
			index		= [indexes firstIndex];
			
			while(index != NSNotFound) {
				name = [[self dataSource] treeView:self nameForRow:index inPath:path];
				
				[paths addObject:[path stringByAppendingPathComponent:name]];
				
				index = [indexes indexGreaterThanIndex:index];
			}
		}
	}
	
	return paths;
}



#pragma mark -

- (void)selectPath:(NSString *)path {
	NSTableView		*tableView;
	NSArray			*components, *rootComponents;
	NSString		*rootPath, *partialPath, *component, *name;
	NSUInteger		i, j, count, fileCount;
	
	if([_views count] == 0)
		return;

	rootPath		= [self rootPath];
	rootComponents	= [rootPath pathComponents];
	partialPath		= rootPath;
	components		= [[path pathComponents] subarrayFromIndex:[rootComponents count]];
	tableView		= [_views objectAtIndex:0];
	count			= [components count];
	
	for(i = 0; i < count; i++) {
		component	= [components objectAtIndex:i];
		tableView	= [_views objectAtIndex:i];
		fileCount	= [[self delegate] treeView:self numberOfItemsForPath:partialPath];
		
		for(j = 0; j < fileCount; j++) {
			name = [[self delegate] treeView:self nameForRow:j inPath:partialPath];
			
			if([component isEqualToString:name]) {
				[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:j] byExtendingSelection:NO];
				
				break;
			}
		}
		
		partialPath = [partialPath stringByAppendingPathComponent:[components objectAtIndex:i]];
	}
	
	[[self window] makeFirstResponder:tableView];

	[self scrollPoint:NSMakePoint([self _widthOfTableViews:[_views indexOfObject:tableView]], 0.0)];
}



- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extendingSelection {
	NSTableView		*tableView;
	
	tableView = [_views objectAtIndex:[self _numberOfUsedPathComponents]];
	
	_selectingProgrammatically = YES;
	
	[tableView selectRowIndexes:indexes byExtendingSelection:extendingSelection];

	_selectingProgrammatically = NO;
}



#pragma mark -

- (void)reloadData {
	_reloadingData = YES;
	[_views makeObjectsPerformSelector:@selector(reloadData)];
	_reloadingData = NO;
	
	[self selectPath:[self _path]];
}



#pragma mark -

- (void)_WI_viewFrameDidChangeNotification:(NSNotification *)notification {
	[self _sizeToFit];
	[self _resizeDetailView];
}



#pragma mark -

- (void)keyDown:(NSEvent *)event {
	NSString		*path, *name;
	NSTableView		*tableView;
	NSIndexSet		*indexes;
	id				responder;
	NSUInteger		index;
	NSInteger		row;
	BOOL			handled = NO;
	unichar			key;
	
	key = [event character];
	
	if(key == NSRightArrowFunctionKey || key == NSLeftArrowFunctionKey) {
		responder = [[self window] firstResponder];
		
		if([responder isKindOfClass:[NSTableView class]]) {
			path = [self _pathForTableView:responder];
			
			if(path) {
				row = [responder selectedRow];
				
				if(row >= 0) {
					if(key == NSRightArrowFunctionKey) {
						name		= [[self dataSource] treeView:self nameForRow:row inPath:path];
						path		= [path stringByAppendingPathComponent:name];
						index		= [_views indexOfObject:responder];
						
						if(index == [_views count] - 2)
							[self _addTableView];
						
						tableView = [_views objectAtIndex:index + 1];

						if([[self dataSource] treeView:self numberOfItemsForPath:path] > 0) {
							if([tableView selectedRow] == -1)
								[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
							
							if([tableView selectedRow] >= 0) {
								[[self window] makeFirstResponder:tableView];
								
								name = [[self dataSource] treeView:self nameForRow:[tableView selectedRow] inPath:path];
								
								[self _setPath:[path stringByAppendingPathComponent:name]];
								
								handled = YES;
							}
						}
					} else {
						index = [_views indexOfObject:responder];
						
						if(index > 0) {
							tableView = [_views objectAtIndex:index - 1];
							
							[[self window] makeFirstResponder:tableView];

							if([[responder selectedRowIndexes] count] > 1)
								path = [self _path];
							else
								path = [[self _path] stringByDeletingLastPathComponent];
							
							[self _setPath:path];

							handled = YES;
						}
					}
					
					if(handled) {
						[self _sizeToFit];
						[self _scrollToSelection];
						
						indexes = [tableView selectedRowIndexes];
						
						if(![[self dataSource] treeView:self isPathExpandable:[self _path]] && [indexes count] == 1)
							[self _showDetailViewForPath:[self _path]];
						else
							[self _hideDetailView];

						[self reloadData];
					}
				}
			}
		}
	}
	
	if(!handled)
		[super keyDown:event];
}



- (void)scrollWheel:(NSEvent *)event {
	[[self enclosingScrollView] scrollWheel:event];
}



- (void)registerForDraggedTypes:(NSArray *)types {
	[_views makeObjectsPerformSelector:@selector(registerForDraggedTypes:) withObject:types];
	
	[super registerForDraggedTypes:types];
}



- (void)setMenu:(NSMenu *)menu {
	[_views makeObjectsPerformSelector:@selector(setMenu:) withObject:menu];
	
	[super setMenu:menu];
}



- (void)tableViewSingleClick:(id)sender {
	if([self action])
		[[self target] performSelector:[self action] withObject:self];
}



- (void)tableViewDoubleClick:(id)sender {
	if([self doubleAction])
		[[self target] performSelector:[self doubleAction] withObject:self];
}



- (void)tableViewEscape:(id)sender {
	[sender deselectAll:self];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	NSString		*path;
	
	path = [self _pathForTableView:tableView];
	
	if(!path)
		return 0;

	return [[self dataSource] treeView:self numberOfItemsForPath:path];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString		*path;
	
	path = [self _pathForTableView:tableView];
	
	if(!path)
		return NULL;

	return [[self dataSource] treeView:self nameForRow:row inPath:path];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString		*path, *name;
	
	if([[self delegate] respondsToSelector:@selector(treeView:willDisplayCell:forPath:)]) {
		path = [self _pathForTableView:tableView];
		
		if(path) {
			name = [[self dataSource] treeView:self nameForRow:row inPath:path];
			path = [path stringByAppendingPathComponent:name];
			
			[cell setLeaf:![[self dataSource] treeView:self isPathExpandable:path]];

			[[self delegate] treeView:self willDisplayCell:cell forPath:path];
		}
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSTableView		*tableView;
	NSString		*path, *name;
	NSIndexSet		*indexes;
	NSUInteger		index;
	
	if(_selectingProgrammatically || _reloadingData || _inChangedSelection)
		return;
	
	_inChangedSelection		= YES;
	tableView				= [notification object];
	indexes					= [tableView selectedRowIndexes];
	path					= [self _pathForTableView:tableView];
	
	if(!path)
		return;
	
	if([indexes count] == 1) {
		index		= [indexes firstIndex];
		name		= [[self dataSource] treeView:self nameForRow:index inPath:path];
		path		= [path stringByAppendingPathComponent:name];
			
		if([_views indexOfObject:tableView] == [_views count] - 2)
			[self _addTableView];
	}
	
	[[self _tableViewsAheadOfTableView:tableView] makeObjectsPerformSelector:@selector(deselectAll:) withObject:self];
	
	[self _setPath:path];
	[self _sizeToFit];
	[self _scrollToSelection];

	[self reloadData];
	
	if(![[self dataSource] treeView:self isPathExpandable:path] && [indexes count] == 1)
		[self _showDetailViewForPath:path];
	else
		[self _hideDetailView];
	
	_inChangedSelection = NO;
}



- (NSColor *)tableView:(NSTableView *)tableView labelColorForRow:(NSInteger)row {
	NSString		*path, *name;
	
	if([[self delegate] respondsToSelector:@selector(treeView:labelColorForPath:)]) {
		path = [self _pathForTableView:tableView];

		if(path) {
			name = [[self dataSource] treeView:self nameForRow:row inPath:path];
			path = [path stringByAppendingPathComponent:name];
			
			return [[self delegate] treeView:self labelColorForPath:path];
		}
	}
	
	return NULL;
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableArray		*paths;
	NSString			*path, *name;
	NSUInteger			index;
	
	if([[self delegate] respondsToSelector:@selector(treeView:writePaths:toPasteboard:)]) {
		path = [self _pathForTableView:tableView];
		
		if(path) {
			paths = [NSMutableArray array];
			index = [indexes firstIndex];
			
			while(index != NSNotFound) {
				name = [[self dataSource] treeView:self nameForRow:index inPath:path];
				
				[paths addObject:[path stringByAppendingPathComponent:name]];
				
				index = [indexes indexGreaterThanIndex:index];
			}
			
			return [[self delegate] treeView:self writePaths:paths toPasteboard:pasteboard];
		}
	}

	return NO;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	NSString		*path;
	
	if([[self delegate] respondsToSelector:@selector(treeView:validateDrop:proposedPath:)]) {
		if(operation == NSTableViewDropAbove) {
			[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
			
			row = -1;
		}
		
		path = [self _pathForTableView:tableView];
		
		if(path) {
			if(row >= 0)
				path = [path stringByAppendingPathComponent:[[self dataSource] treeView:self nameForRow:row inPath:path]];
			
			if(![[self dataSource] treeView:self isPathExpandable:path]) {
				[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
				
				path = [path stringByDeletingLastPathComponent];
			}
			
			return [[self delegate] treeView:self validateDrop:info proposedPath:path];
		}
	}
	
	return NSDragOperationNone;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSString		*path;
	
	if([[self delegate] respondsToSelector:@selector(treeView:acceptDrop:path:)]) {
		path = [self _pathForTableView:tableView];
		
		if(path) {
			if(row >= 0)
				path = [path stringByAppendingPathComponent:[[self dataSource] treeView:self nameForRow:row inPath:path]];
			
			return [[self delegate] treeView:self acceptDrop:info path:path];
		}
	}
	
	return NO;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	if([[self delegate] respondsToSelector:@selector(treeViewShouldCopyInfo:)])
		[[self delegate] treeViewShouldCopyInfo:self];
}



- (NSArray *)tableView:(NSTableView *)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedRowsWithIndexes:(NSIndexSet *)indexes {
	NSMutableArray		*paths;
	NSString			*path, *name;
	NSUInteger			index;
	
	if([[self delegate] respondsToSelector:@selector(treeView:namesOfPromisedFilesDroppedAtDestination:forDraggedPaths:)]) {
		path = [self _pathForTableView:tableView];
		
		if(path) {
			paths = [NSMutableArray array];
			index = [indexes firstIndex];
			
			while(index != NSNotFound) {
				name = [[self dataSource] treeView:self nameForRow:index inPath:path];
				
				[paths addObject:[path stringByAppendingPathComponent:name]];
				
				index = [indexes indexGreaterThanIndex:index];
			}

			return [[self delegate] treeView:self namesOfPromisedFilesDroppedAtDestination:destination forDraggedPaths:paths];
		}
	}
	
	return NULL;
}



#pragma mark -

- (void)treeScrollView:(WITreeScrollView *)scrollView shouldResizeToPoint:(NSPoint)point {
	WITreeScrollView	*eachScollView;
	NSRect				frame, windowFrame;
	CGFloat				width, difference;
	NSUInteger			i, index, count;
	
	count = [_views count];
	index = [_views indexOfObject:[scrollView documentView]];
	
	if(index == NSNotFound)
		return;
	
	frame = [scrollView frame];
	width = point.x;
	difference = width - frame.size.width;
	
	if(width < _WITreeViewMinimumTableViewWidth)
		return;
	
	if([_detailView superview] && index == [self _numberOfUsedPathComponents]) {
		if(width < _WITreeViewMinimumDetailViewWidth)
			return;
	}
	
	frame.size.width = width;
	[scrollView setFrame:frame];

	if(index != count - 1) {
		for(i = index + 1; i < count; i++) {
			eachScollView = (WITreeScrollView *) [[_views objectAtIndex:i] enclosingScrollView];
			frame = [eachScollView frame];
			frame.origin.x += difference;
			[eachScollView setFrame:frame];
		}
	}
	
	[self _resizeDetailView];
	
	if(index == [self _numberOfUsedPathComponents]) {
		frame			= [scrollView frame];
		windowFrame		= [[self window] frame];
		width			= frame.origin.x + frame.size.width - 2.0;
		
		if(width > windowFrame.size.width) {
			windowFrame.size.width += difference;
			[[self window] setFrame:windowFrame display:YES];
		}
	}
}



#pragma mark -

- (void)drawRect:(NSRect)rect {
	[[NSColor whiteColor] set];
	NSRectFill(rect);
}

@end
