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

#import "WCSplitView.h"

@implementation WCSplitView

- (id)initWithFrame:(NSRect)frame; {
	self = [super initWithFrame:frame];

    [[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(didResizeSubviews:)
		name:NSSplitViewDidResizeSubviewsNotification
		object:self];

    return self;
}



- (id)initWithCoder:(NSCoder *)coder; {
	self = [super initWithCoder:coder];

    [[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(didResizeSubviews:)
		name:NSSplitViewDidResizeSubviewsNotification
		object:self];

    return self;
}



- (void)dealloc; {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_autosaveName release];

	[super dealloc];
}



#pragma mark -

- (void)didResizeSubviews:(NSNotification *)notification {
	NSArray				*subviews;
	NSView				*subview;
	NSMutableArray		*frames;
	int					i, subviewCount;
    
    if([_autosaveName length] == 0)
		return;

	// --- create array
	frames			= [NSMutableArray array];
	subviews		= [self subviews];
	subviewCount	= [subviews count];
	
	for(i = 0; i < subviewCount; i++) {
		subview = [subviews objectAtIndex:i];
		[frames addObject:NSStringFromRect([subview frame])];
	}
        
	// --- save in defaults
	[[NSUserDefaults standardUserDefaults]
		setObject:frames
		forKey:[NSString stringWithFormat:@"WCSplitView Views %@", _autosaveName]];
}



#pragma mark -

- (void)setAutosaveName:(NSString *)value {
	NSArray			*subviews, *frames;
	unsigned int	i, framesCount, subviewCount;

	// --- get value
	[value retain];
	[_autosaveName release];
	_autosaveName = value;
	
	// --- get frames
	frames = [[NSUserDefaults standardUserDefaults] arrayForKey:
		[NSString stringWithFormat:@"WCSplitView Views %@", _autosaveName]];
	
	if(frames) {
		framesCount		= [frames count];
		subviews		= [self subviews];
		subviewCount	= [subviews count];

		for(i = 0; i < subviewCount && i < framesCount; i++)
			[[subviews objectAtIndex:i] setFrame:NSRectFromString([frames objectAtIndex:i])];
	}
}



- (NSString *)autosaveName;{
    return _autosaveName;
}

@end
