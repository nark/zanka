/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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


@interface WITreeView(Private)

- (void)_initTreeView;

- (void)_addTableView;
- (void)_sizeToFit;
- (CGFloat)_widthOfTableViews:(NSUInteger)count;
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
	frame.origin.x = offset;
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
	
	[[self delegate] treeView:self changedPath:_path];
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
	[tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	
	cell = [[[WITreeCell alloc] init] autorelease];
	
	tableColumn = [[[NSTableColumn alloc] initWithIdentifier:@""] autorelease];
	[tableColumn setEditable:NO];
	[tableColumn setDataCell:cell];
	[tableColumn setWidth:230.0];
	
	[tableView addTableColumn:tableColumn];
	
	scrollView = [[WITreeScrollView alloc] initWithFrame:NSMakeRect(0.0, -1.0, _WITreeViewInitialTableViewWidth, frame.size.height + 1.0)];
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

- (NSString *)selectedPath {
	return _path;
}



- (void)reloadData {
	[_views makeObjectsPerformSelector:@selector(reloadData)];
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
						
						tableView	= [_views objectAtIndex:index + 1];

						if([[self dataSource] treeView:self numberOfItemsForPath:path] > 0) {
							if([tableView selectedRow] == -1)
								[tableView selectRow:0 byExtendingSelection:NO];
							
							[[self window] makeFirstResponder:tableView];
							
							name = [[self dataSource] treeView:self nameForRow:[tableView selectedRow] inPath:path];
							
							[self _setPath:[path stringByAppendingPathComponent:name]];
							
							handled = YES;
						}
					} else {
						index = [_views indexOfObject:responder];
						
						if(index > 0) {
							[[self window] makeFirstResponder:[_views objectAtIndex:index - 1]];

							[self _setPath:[[self _path] stringByDeletingLastPathComponent]];

							handled = YES;
						}
					}
					
					if(handled) {
						[self _sizeToFit];
						[self _scrollToSelection];
						
						if(![[self dataSource] treeView:self isPathExpandable:[self _path]])
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



- (void)tableViewSingleClick:(id)sender {
	if([self action])
		[[self target] performSelector:[self action] withObject:self];
}



- (void)tableViewDoubleClick:(id)sender {
	if([self doubleAction])
		[[self target] performSelector:[self doubleAction] withObject:self];
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
	NSInteger		row;
	
	tableView = [notification object];
	path = [self _pathForTableView:tableView];
	
	if(!path)
		return;
	
	row = [tableView selectedRow];
	
	if(row >= 0) {
		name = [[self dataSource] treeView:self nameForRow:row inPath:path];
		path = [path stringByAppendingPathComponent:name];
		
		if([_views indexOfObject:tableView] == [_views count] - 2)
			[self _addTableView];
	}
	
	[[self _tableViewsAheadOfTableView:tableView] makeObjectsPerformSelector:@selector(deselectAll:) withObject:self];
	
	[self _setPath:path];
	
	[self _sizeToFit];
	[self _scrollToSelection];

	[self reloadData];
	
	if(![[self dataSource] treeView:self isPathExpandable:path])
		[self _showDetailViewForPath:path];
	else
		[self _hideDetailView];
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
