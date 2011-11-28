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

#import <ZankaAdditions/ZASplitView.h>

@interface ZASplitView(Private)

- (void)_saveSplitViewPosition;
- (void)_loadSplitViewPosition;

@end


@implementation ZASplitView

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowWillClose:)
			   name:NSWindowWillCloseNotification
			 object:[self window]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification
			 object:NULL];
}



- (void)dealloc; {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_autosaveName release];

	[super dealloc];
}



#pragma mark -

- (void)windowWillClose:(NSNotification *)notification {
	[self _saveSplitViewPosition];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[self _saveSplitViewPosition];
}



#pragma mark -

- (void)_saveSplitViewPosition {
	NSMutableArray	*frames;
	NSString		*key;
	int				i, subviewCount;
	
	if([[self autosaveName] length] > 0) {
		frames = [NSMutableArray array];
		subviewCount = [[self subviews] count];
		
		for(i = 0; i < subviewCount; i++)
			[frames addObject:NSStringFromRect([[[self subviews] objectAtIndex:i] frame])];

			key = [NSSWF:@"%@ %@ Views", NSStringFromClass([self class]), [self autosaveName]];
			[[NSUserDefaults standardUserDefaults] setObject:frames forKey:key];
	}
}



- (void)_loadSplitViewPosition {
	NSArray		*frames;
	NSString	*key;
	int			i, frameCount, subviewCount;
	
	key = [NSSWF:@"%@ %@ Views", NSStringFromClass([self class]), [self autosaveName]];
	frames = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
	
	if(frames) {
		frameCount = [frames count];
		subviewCount = [[self subviews] count];
		
		for(i = 0; i < subviewCount && i < frameCount; i++)
			[[[self subviews] objectAtIndex:i] setFrame:NSRectFromString([frames objectAtIndex:i])];
	}
}



#pragma mark -

- (void)setAutosaveName:(NSString *)value {
	[value retain];
	[_autosaveName release];
	_autosaveName = value;
	
	[self _loadSplitViewPosition];
}



- (NSString *)autosaveName;{
	return _autosaveName;
}

@end
