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

#import "SPDrillGradientView.h"
#import "SPDrillItem.h"
#import "SPDrillListView.h"
#import "SPDrillSelectionView.h"

#define SPDrillListViewItemHeight					150.0

@interface SPDrillListView(Private)

- (void)_initDrillListView;

- (NSUInteger)_visibleItems;
- (NSRange)_visibleRangeForIndex:(NSUInteger)index;
- (NSRect)_frameForIndex:(NSInteger)index;
- (void)_layoutItemsWithAnimation:(BOOL)animation;

@end


@implementation SPDrillListView(Private)

- (void)_initDrillListView {
	_topGradientView = [[SPDrillGradientView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
	[_topGradientView setDrawsGradientAtTop:YES];
	[_topGradientView setHidden:YES];
	[self addSubview:_topGradientView];
	[_topGradientView release];
	
	_bottomGradientView = [[SPDrillGradientView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
	[_bottomGradientView setDrawsGradientAtBottom:YES];
	[_bottomGradientView setHidden:YES];
	[self addSubview:_bottomGradientView];
	[_bottomGradientView release];
	
	_selectionView = [[SPDrillSelectionView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];
	[self addSubview:_selectionView];
	[_selectionView release];

	_items = [[NSMutableArray alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowDidBecomeKey:)
			   name:NSWindowDidBecomeKeyNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowDidResignKey:)
			   name:NSWindowDidResignKeyNotification];
}



#pragma mark -

- (NSUInteger)_visibleItems {
	return floor([self frame].size.height / SPDrillListViewItemHeight);
}



- (NSRange)_visibleRangeForIndex:(NSUInteger)index {
	NSUInteger		visibleItems;
	
	visibleItems = [self _visibleItems];
	
	if([_items count] < visibleItems)
		return NSMakeRange(0, [_items count]);
	else if([_items count] < index + visibleItems)
		return NSMakeRange([_items count] - visibleItems, visibleItems);
	else
		return NSMakeRange(index, visibleItems);
}



- (NSRect)_frameForIndex:(NSInteger)index {
	NSSize		size;
	CGFloat		yOffset;
	
	size = [self frame].size;
	
	if([_items count] < [self _visibleItems])
		yOffset = floor((size.height - (SPDrillListViewItemHeight * [_items count])) / 2.0);
	else
		yOffset = 0.0;
	
	return NSMakeRect(0.0, size.height - ((index + 1) * SPDrillListViewItemHeight) - yOffset, size.width, SPDrillListViewItemHeight);
}



- (void)_layoutItemsWithAnimation:(BOOL)animation {
	SPDrillItem		*item;
	NSRect			frame;
	NSInteger		index;
	BOOL			top, bottom;
	
	if(animation)
		[NSAnimationContext beginGrouping];
	
	index = -_visibleRange.location;
	
	for(item in _items) {
		frame = [self _frameForIndex:index];

		if(animation)
			[[[item view] animator] setFrame:frame];
		else
			[[item view] setFrame:frame];
		
		if(index == 0)
			[_topGradientView setFrame:frame];
		else if((NSUInteger) index + 1 == _visibleRange.length)
			[_bottomGradientView setFrame:frame];
		
		index++;
	}
	
	top = (_visibleRange.location == 0);
	
	if(animation)
		[[_topGradientView animator] setHidden:top];
	else
		[_topGradientView setHidden:top];

	bottom = ([_items count] <= _visibleRange.location + _visibleRange.length);

	if(animation)
		[[_bottomGradientView animator] setHidden:bottom];
	else
		[_bottomGradientView setHidden:bottom];

	if(animation)
		[NSAnimationContext endGrouping];
}

@end



@implementation SPDrillListView

+ (NSRect)frameSizedToFitFromFrame:(NSRect)frame {
	NSSize		size;
	
	size = frame.size;

	frame.size.height	= floor((size.height - 80.0) / SPDrillListViewItemHeight) * SPDrillListViewItemHeight;
	frame.size.width	-= 80.0;
	frame.origin.x		+= floor((size.width  - frame.size.width)  / 2.0);
	frame.origin.y		+= floor((size.height - frame.size.height) / 2.0);
	
	return frame;
}



#pragma mark -

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initDrillListView];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_items release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidBecomeKey:(NSNotification *)notification {
	if([notification object] == [self window])
		[[self selectedItem] setSelected:YES];
}



- (void)windowDidResignKey:(NSNotification *)notification {
	if([notification object] == [self window])
		[[self selectedItem] setSelected:NO];
}



#pragma mark -

- (void)setItems:(NSArray *)items selectItem:(SPDrillItem *)selectItem {
	SPDrillItem			*item;
	NSUInteger			index;
	
	for(item in _items)
		[[item view] removeFromSuperviewWithoutNeedingDisplay];
	
	[_items removeAllObjects];
	
	for(item in items) {
		[self addSubview:[item view] positioned:NSWindowBelow relativeTo:_topGradientView];
		[_items addObject:item];
	}
	
	if(selectItem) {
		index = [_items indexOfObject:selectItem];
		
		if(index > 0)
			index--;
		
		_visibleRange	= [self _visibleRangeForIndex:index];
		_selectedIndex	= [[_items subarrayWithRange:_visibleRange] indexOfObject:selectItem];
	} else {
		_selectedIndex	= 0;
		_visibleRange	= [self _visibleRangeForIndex:_selectedIndex];
	}
	
	if([_items count] == 0)
		[_selectionView setHidden:YES];
	else
		[_selectionView setFrame:[self _frameForIndex:_selectedIndex]];
	
	[self _layoutItemsWithAnimation:NO];
	
	[[self selectedItem] setSelected:YES];

	[self setNeedsDisplay:YES];
}



- (void)moveSelectionUp {
	SPDrillItem		*previousSelection;
	BOOL			changedSelection = NO;
	
	if(_visibleRange.location + _selectedIndex > 0) {
		previousSelection = [self selectedItem];
		
		if(_visibleRange.location > 0 && _selectedIndex <= 1) {
			_visibleRange = [self _visibleRangeForIndex:_visibleRange.location + _selectedIndex - 2];
			
			[self _layoutItemsWithAnimation:YES];
			
			changedSelection = YES;
		}
		else if(_selectedIndex > 1 || (_selectedIndex > 0 && _visibleRange.location == 0)) {
			_selectedIndex--;
			
			[[_selectionView animator] setFrame:[self _frameForIndex:_selectedIndex]];

			changedSelection = YES;
		}
		
		if(changedSelection) {
			[previousSelection setSelected:NO];
			[[self selectedItem] setSelected:YES];
		}
	}
}



- (void)moveSelectionDown {
	SPDrillItem		*previousSelection;
	NSUInteger		count, visibleItems;
	BOOL			changedSelection = NO;
	
	count = [_items count];
	visibleItems = _visibleRange.location + _visibleRange.length;
	
	if(_visibleRange.location + _selectedIndex + 1 < count) {
		previousSelection = [self selectedItem];
		
		if(_selectedIndex + 2 >= _visibleRange.length && visibleItems < count) {
			_visibleRange = [self _visibleRangeForIndex:_visibleRange.location + _selectedIndex - _visibleRange.length + 3];
			
			[self _layoutItemsWithAnimation:YES];
			
			changedSelection = YES;
		}
		else if(_selectedIndex + 2 < _visibleRange.length || (visibleItems >= count && _selectedIndex + 1 < _visibleRange.length)) {
			_selectedIndex++;
		
			[[_selectionView animator] setFrame:[self _frameForIndex:_selectedIndex]];

			changedSelection = YES;
		}

		if(changedSelection) {
			[previousSelection setSelected:NO];
			[[self selectedItem] setSelected:YES];
		}
	}
}



- (SPDrillItem *)selectedItem {
	NSArray		*items;
	
	items = [_items subarrayWithRange:_visibleRange];
	
	if(_selectedIndex < [items count])
		return [items objectAtIndex:_selectedIndex];
	
	return NULL;
}

@end
