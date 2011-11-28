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

#import "SPDrillItem.h"
#import "SPDrillTextField.h"
#import "SPDrillViewStatusView.h"
#import "SPPlaylistItem.h"

@implementation SPDrillItem

- (id)init {
	self = [super init];
	
	[NSBundle loadNibNamed:@"DrillItem" owner:self];
	
	[self setShowsViewStatus:NO];
	
	return self;
}



- (void)dealloc {
	[_playlistItem release];
	[_view release];
	
	[super dealloc];
}



#pragma mark -

- (void)setPlaylistItem:(id)playlistItem {
	[playlistItem retain];
	[_playlistItem release];
	
	_playlistItem = playlistItem;
}



- (id)playlistItem {
	return _playlistItem;
}



- (void)setImage:(NSImage *)image {
	[_imageView setImage:image];
}



- (NSImage *)image {
	return [_imageView image];
}



- (void)setStringValue:(NSString *)string {
	[_textField setStringValue:string];
}



- (NSString *)stringValue {
	return [_textField stringValue];
}



- (void)setShowsViewStatus:(BOOL)value {
	NSRect		textFieldFrame, viewStatusViewFrame;
	
	if(value != [self showsViewStatus]) {
		[_viewStatusView setHidden:!value];
		
		textFieldFrame = [_textField frame];
		viewStatusViewFrame = [_viewStatusView frame];

		if(value) {
			textFieldFrame.origin.x = viewStatusViewFrame.origin.x + viewStatusViewFrame.size.width + 20.0;
			textFieldFrame.size.width -= viewStatusViewFrame.size.width + 20.0;
		} else {
			textFieldFrame.size.width += textFieldFrame.origin.x - viewStatusViewFrame.origin.x;
			textFieldFrame.origin.x = viewStatusViewFrame.origin.x;
		}

		[_textField setFrame:textFieldFrame];
	}
}



- (BOOL)showsViewStatus {
	return ![_viewStatusView isHidden];
}



- (void)setViewStatus:(SPPlaylistViewStatus)viewStatus {
	[_viewStatusView setViewStatus:viewStatus];
}



- (SPPlaylistViewStatus)viewStatus {
	return [_viewStatusView viewStatus];
}



- (void)setSelected:(BOOL)selected {
	_selected = selected;
	
	if(_selected)
		[_textField startAnimatingIfNeeded];
	else
		[_textField stopAnimating];
}



- (BOOL)isSelected {
	return _selected;
}



- (NSView *)view {
	return _view;
}

@end
