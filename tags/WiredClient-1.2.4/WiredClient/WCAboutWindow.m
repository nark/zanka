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

#import "NSImageAdditions.h"
#import "WCAboutWindow.h"
#import "WCApplication.h"

@implementation WCAboutWindow

- (id)init {
	NSMutableAttributedString	*leftString, *rightString;
	NSDictionary				*attributes;
	NSView						*view;
	NSImage						*leftImage, *rightImage;
	NSEnumerator				*enumerator;
	NSScreen					*screen, *last = NULL;
	NSRect						viewRect, leftRect, rightRect;
	int							width = 0, height;
	
	// --- loop over available screens
	enumerator = [[NSScreen screens] objectEnumerator];
	
	while((screen = [enumerator nextObject])) {
		if(!last) {
			// --- add first
			width += [screen frame].size.width;
		} else {
			if(NSEqualSizes([screen frame].size, [last frame].size) &&
			   [screen frame].origin.y == [last frame].origin.y) {
				// --- add another screen of equal size and along the same boundary
				width += [screen frame].size.width;
			}
		}
		
		last = screen;
	}
	
	// --- set height based on width
	height = width / 11;
	
	// --- set window size
	viewRect = [[NSScreen mainScreen] frame];
	viewRect.origin.x = 0;
	viewRect.origin.y = (viewRect.size.height - height) / 2;
	viewRect.size.height = height;
	viewRect.size.width = width;
	
	// --- create window
	self = [super initWithContentRect:viewRect
							styleMask:NSBorderlessWindowMask
							  backing:NSBackingStoreBuffered
								defer:NO];
	
	// --- create view
	viewRect.origin.x = viewRect.origin.y = 0;
	view = [[NSView alloc] initWithFrame:viewRect];

	// --- set options
	[self setReleasedWhenClosed:YES];
	[self setBackgroundColor:[NSColor clearColor]];
	[self setOpaque:NO];
	[self setLevel:NSScreenSaverWindowLevel];
	[self setContentView:view];

	// --- create strings
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:@"Helvetica-Bold" size:width / 14.60], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		NULL];

	leftString = [[NSMutableAttributedString alloc] initWithString:@"Close the world,"
														attributes: attributes];
	rightString = [[NSMutableAttributedString alloc] initWithString:@"Open the nExt"
														attributes: attributes];
	
	// --- red 'E'
	[rightString addAttribute:NSForegroundColorAttributeName
						value:[[NSColor redColor] shadowWithLevel:0.5]
						range:NSMakeRange(10, 1)];
	
	// --- create images
	leftRect = NSMakeRect(0, 0, (double) viewRect.size.width * 0.53, viewRect.size.height);
	leftImage = [[NSImage alloc] initWithSize:leftRect.size];
	rightRect = NSMakeRect(leftRect.size.width, 0, viewRect.size.width - leftRect.size.width, viewRect.size.height);
	rightImage = [[NSImage alloc] initWithSize:rightRect.size];
	
	// --- draw strings in images
	[leftImage lockFocus];
	[leftString drawInRect:leftRect];
	[leftImage unlockFocus];

	[rightImage lockFocus];
	[rightString drawInRect:leftRect];
	[rightImage unlockFocus];
	[rightImage mirror];
	
	// --- display window
	[self makeKeyAndOrderFront:self];
	[self display];
	
	// --- draw images in view
	[view lockFocus];
	[leftImage compositeToPoint:leftRect.origin operation:NSCompositeSourceOver];
	[rightImage compositeToPoint:rightRect.origin operation:NSCompositeSourceOver];
	[view unlockFocus];
	
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationDidChangeStatus:)
			   name:WCApplicationDidChangeStatus
			 object:NULL];

	[leftString release];
	[rightString release];
	[leftImage release];
	[rightImage release];
	
	return self;
}



- (void)applicationDidChangeStatus:(NSNotification *)notification {
	[self close];
}



- (void)keyDown:(NSEvent *)event {
	[self close];
}



- (void)mouseDown:(NSEvent *)event {
	[self close];
}



- (BOOL)canBecomeKeyWindow {
	return YES;
}

@end
