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

#import "WCConnection.h"
#import "WCWindowController.h"

NSMutableDictionary			*frames;

@implementation WCWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];

	// --- don't let NSWindowController do anything
	[super setShouldCascadeWindows:NO];
	
	// --- init frames dictionary
	if(!frames)
		frames = [[NSMutableDictionary alloc] init];
	
	return self;
}



#pragma mark -

- (void)windowDidMove:(NSNotification *)notification {
	if([_autosaveName length] > 0 && [[self window] isVisible]) {
		NSString	*key, *value;
		
		// --- get key and value
		key = [NSString stringWithFormat:@"WCWindowController Frame %@", _autosaveName];
		value = NSStringFromRect([[self window] frame]);
		
		// --- update frames
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[frames setObject:value forKey:key];
	}
}



- (void)windowDidResize:(NSNotification *)notification {
	if([_autosaveName length] > 0 && [[self window] isVisible]) {
		NSString	*key, *value;
		
		// --- get key and value
		key = [NSString stringWithFormat:@"WCWindowController Frame %@", _autosaveName];
		value = NSStringFromRect([[self window] frame]);
		
		// --- update frames
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[frames setObject:value forKey:key];
	}
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	if([_autosaveName length] > 0 && [[self window] isVisible]) {
		NSString	*key, *value;
		
		// --- get key and value
		key = [NSString stringWithFormat:@"WCWindowController Frame %@", _autosaveName];
		value = NSStringFromRect([[self window] frame]);
		
		// --- update frames
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[frames setObject:value forKey:key];
	}

	// --- post notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCWindowDidBecomeActive
		object:self];
}



- (void)windowWillClose:(NSNotification *)notification {
	if([_autosaveName length] > 0 && [[self window] isVisible]) {
		NSString	*key, *value;
		
		// --- get key and value
		key = [NSString stringWithFormat:@"WCWindowController Frame %@", _autosaveName];
		value = NSStringFromRect([[self window] frame]);
		
		// --- update frames
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
		[frames setObject:value forKey:key];
	}
	
	// --- post notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WCWindowDidBecomeInactive
		object:self];
}



#pragma mark -

- (void)setShouldCascadeWindows:(BOOL)value {
	// --- save value
	_cascade = value;
}



- (void)setWindowFrameAutosaveName:(NSString *)value {
	NSString		*key, *frame, *cascade;
	NSRect			rect;
	
	// --- save string
	[value retain];
	[_autosaveName release];
	
	_autosaveName = value;
	
	if([_autosaveName length] > 0) {
		// --- get saved frame
		key = [NSString stringWithFormat:@"WCWindowController Frame %@", _autosaveName];
		frame = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		
		if([frame length] > 0) {
			// --- get frame
			rect = NSRectFromString(frame);
			
			// --- look up previous frame if we should cascade
			if(_cascade) {
				cascade = [frames objectForKey:key];
				
				if([cascade length] > 0) {
					rect = NSRectFromString(cascade);
					rect.origin.x += 20;
					rect.origin.y -= 20;
				}
			}

			// --- set new frame
			[[self window] setFrame:rect display:YES];
			
			// --- save frame
			[frames setObject:NSStringFromRect(rect) forKey:key];
		}
	}
}



#pragma mark -

- (NSWindow *)shownWindow {
	if([[self window] isVisible])
		return [self window];
	
	return NULL;
}



- (WCConnection *)connection {
	return _connection;
}



#pragma mark -

- (IBAction)okSheet:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSRunStoppedResponse];
}



- (IBAction)cancelSheet:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSRunAbortedResponse];
}

@end
