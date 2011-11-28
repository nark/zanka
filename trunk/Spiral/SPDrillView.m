/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "SPDrillItem.h"
#import "SPDrillListView.h"
#import "SPDrillView.h"
#import "SPPlaylistController.h"
#import "SPPlaylistItem.h"
#import "SPSettings.h"

#define SPDrillViewTransitionOffset				200.0


enum _SPDrillViewTransition {
	_SPDrillViewTransitionNone,
	_SPDrillViewTransitionIn,
	_SPDrillViewTransitionOut
};
typedef enum _SPDrillViewTransition				_SPDrillViewTransition;


@interface SPDrillView(Private)

- (void)_addListViewWithItem:(id)item transition:(_SPDrillViewTransition)transition selectPlaylistFile:(SPPlaylistFile *)selectPlaylistFile;
- (void)_transitionInListViewFromView:(NSView *)view;
- (void)_transitionOutListViewFromView:(NSView *)view;
- (void)_transitionListViewFromView:(NSView *)view frame:(NSRect)frame;

@end


@implementation SPDrillView(Private)

- (void)_addListViewWithItem:(id)item transition:(_SPDrillViewTransition)transition selectPlaylistFile:(SPPlaylistFile *)selectPlaylistFile {
	NSImageView			*imageView;
	NSImage				*image;
	NSBitmapImageRep	*imageRep;
	NSMutableArray		*drillItems;
	SPDrillItem			*drillItem, *selectedItem, *selectItem = NULL;
	SPDrillListView		*previousListView;
	id					playlistItem;
	
	previousListView = _currentListView;
	
	selectedItem = [previousListView selectedItem];
	
	_currentListView = [[SPDrillListView alloc] initWithFrame:[SPDrillListView frameSizedToFitFromFrame:[self frame]]];
	[_currentListView setAlphaValue:0.0];
	[_currentListView setWantsLayer:YES];

	drillItems = [NSMutableArray array];
	
	for(playlistItem in [item items]) {
		drillItem = [[SPDrillItem alloc] init];
		[drillItem setPlaylistItem:playlistItem];
		[drillItem setStringValue:_simplifyFilenames ? [playlistItem cleanName] : [playlistItem name]];
		[drillItem setImage:[playlistItem iconWithSize:NSMakeSize(128.0, 128.0)]];
		
		if([playlistItem isKindOfClass:[SPPlaylistFile class]]) {
			[drillItem setShowsViewStatus:YES];
			[drillItem setViewStatus:[playlistItem viewStatus]];
		}

		[drillItems addObject:drillItem];
		
		if(selectPlaylistFile) {
			if([selectPlaylistFile isEqual:playlistItem])
				selectItem = [drillItem retain];
		} else {
			if([_currentPlaylistItem isEqual:playlistItem] || [[selectedItem playlistItem] isEqual:playlistItem])
				selectItem = [drillItem retain];
		}
		
		[drillItem release];
	}
	
	[_currentListView setItems:drillItems selectItem:selectItem];
	
	[selectItem release];
	
	[item retain];
	[_currentPlaylistItem release];
	
	_currentPlaylistItem = item;
	
	[self addSubview:_currentListView];

	if(previousListView) {
		if(transition == _SPDrillViewTransitionNone) {
			[previousListView removeFromSuperview];
			[_currentListView setAlphaValue:1.0];
		} else {
			imageRep = [previousListView bitmapImageRepForCachingDisplayInRect:[previousListView visibleRect]];
			[previousListView cacheDisplayInRect:[previousListView visibleRect] toBitmapImageRep:imageRep];
			
			image = [[NSImage alloc] initWithSize:[imageRep size]];
			[image addRepresentation:imageRep];
			
			imageView = [[NSImageView alloc] initWithFrame:[previousListView frame]];
			[imageView setWantsLayer:YES];
			[imageView setImageScaling:NSScaleToFit];
			[imageView setImage:image];
			[self addSubview:imageView];
			
			[previousListView removeFromSuperview];
			
			if(transition == _SPDrillViewTransitionIn)
				[self performSelector:@selector(_transitionInListViewFromView:) withObject:imageView afterDelay:0.05];
			else if(transition == _SPDrillViewTransitionOut)
				[self performSelector:@selector(_transitionOutListViewFromView:) withObject:imageView afterDelay:0.05];
			
			[imageView release];
			[image release];
		}
	} else {
		[_currentListView setAlphaValue:1.0];
	}
	
	[_currentListView release];
}



- (void)_transitionInListViewFromView:(NSView *)view {
	NSRect		frame;
	CGFloat		factor;
	
	frame				= [view frame];
	factor				= frame.size.height / frame.size.width;
	frame.origin.x		-= SPDrillViewTransitionOffset;
	frame.origin.y		-= factor * SPDrillViewTransitionOffset;
	frame.size.width	+= (SPDrillViewTransitionOffset * 2);
	frame.size.height	+= factor * (SPDrillViewTransitionOffset * 2);
	
	[self _transitionListViewFromView:view frame:frame];
}



- (void)_transitionOutListViewFromView:(NSView *)view {
	NSRect		frame;
	CGFloat		factor;
	
	frame				= [view frame];
	factor				= frame.size.height / frame.size.width;
	frame.origin.x		+= SPDrillViewTransitionOffset;
	frame.origin.y		+= factor * SPDrillViewTransitionOffset;
	frame.size.width	-= (SPDrillViewTransitionOffset * 2);
	frame.size.height	-= factor * (SPDrillViewTransitionOffset * 2);
	
	[self _transitionListViewFromView:view frame:frame];
}



- (void)_transitionListViewFromView:(NSView *)view frame:(NSRect)frame {
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.2];
	[[view animator] setFrame:frame];
	[[view animator] setAlphaValue:0.0];
	[[_currentListView animator] setAlphaValue:1.0];
	[view performSelector:@selector(removeFromSuperview) afterDelay:1.0];
	[NSAnimationContext endGrouping];
}

@end



@implementation SPDrillView

- (void)dealloc {
	[_playlist release];
	
	[super dealloc];
}



#pragma mark -

- (void)setDelegate:(id <SPDrillViewDelegate>)aDelegate {
	delegate = aDelegate;
}



- (id <SPDrillViewDelegate>)delegate {
	return delegate;
}



- (void)setPlaylist:(SPPlaylistGroup *)playlist {
	[playlist retain];
	[_playlist release];
	
	_playlist = playlist;
	
	[_currentListView removeFromSuperview];
	_currentListView = NULL;
	
	[self _addListViewWithItem:playlist transition:_SPDrillViewTransitionNone selectPlaylistFile:NULL];
}



- (SPPlaylistGroup *)playlist {
	return _playlist;
}



- (void)setSimplifyFilenames:(BOOL)simplifyFilenames {
	_simplifyFilenames = simplifyFilenames;
}



- (BOOL)simplifyFilenames {
	return _simplifyFilenames;
}



#pragma mark -

- (void)openSelection {
	id		item;

	[[_currentListView selectedItem] setSelected:NO];

	item = [[_currentListView selectedItem] playlistItem];
	
	if([item isKindOfClass:[SPPlaylistContainer class]]) {
		[[self delegate] drillView:self willOpenContainer:item];
		
		[self _addListViewWithItem:item transition:_SPDrillViewTransitionIn selectPlaylistFile:NULL];
	}
	else if([item isKindOfClass:[SPPlaylistFile class]]) {
		[[self delegate] drillView:self shouldOpenFile:item];
	}
}



- (void)closeSelection {
	id		parentItem;
	
	[[_currentListView selectedItem] setSelected:NO];

	parentItem = [_currentPlaylistItem parentItem];
	
	if(parentItem)
		[self _addListViewWithItem:parentItem transition:_SPDrillViewTransitionOut selectPlaylistFile:NULL];
}



- (void)moveSelectionUp {
	[_currentListView moveSelectionUp];
}



- (void)moveSelectionDown {
	[_currentListView moveSelectionDown];
}



#pragma mark -

- (void)reloadDataAndSelectPlaylistFile:(SPPlaylistFile *)file {
	[self _addListViewWithItem:_currentPlaylistItem transition:_SPDrillViewTransitionNone selectPlaylistFile:file];
}



#pragma mark -

- (BOOL)resignFirstResponder {
	return NO;
}



- (void)mouseDown:(NSEvent *)event {
}



- (void)keyDown:(NSEvent *)event {
	unichar		key;
	
	key = [event character];
	
    if(key == NSEnterCharacter || key == NSCarriageReturnCharacter || key == NSRightArrowFunctionKey)
		[self openSelection];
	else if(key == NSBackspaceCharacter || key == NSLeftArrowFunctionKey)
		[self closeSelection];
	else if(key == NSUpArrowFunctionKey)
		[self moveSelectionUp];
	else if(key == NSDownArrowFunctionKey)
		[self moveSelectionDown];
}

@end
