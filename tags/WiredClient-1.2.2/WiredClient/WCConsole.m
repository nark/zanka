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
#import "WCConsole.h"
#import "WCMain.h"
#import "WCSettings.h"

@implementation WCConsole

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Console"];
	
	// --- get parameters
	_connection = [connection retain];
	
	// --- load the window
	[self window];
		
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionHasAttached:)
			   name:WCConnectionHasAttached
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionServerInfoDidChange:)
			   name:WCConnectionServerInfoDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connection release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- set window positions
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Console"];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
		
	// --- show window
	if([WCSettings boolForKey:WCShowConsole])
		[self showWindow:self];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Console", @"Console window title")]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				forKey:WCShowConsole];
	
	[self close];
	[self release];
}



#pragma mark -

- (void)print:(NSString *)input color:(NSColor *)color {
	NSMutableString			*string;
	NSAttributedString		*output;
	NSDictionary			*attributes;
	
	// --- create mutable string
	string = [[NSMutableString alloc] initWithCapacity:[input length]];
	[string appendString:input];

	// --- perform replacement
	[string replaceOccurrencesOfString:WCFieldSeparator
			withString:@"\t"
			options:0
			range:NSMakeRange(0, [string length])];

	[string replaceOccurrencesOfString:WCGroupSeparator
			withString:@"\t"
			options:0
			range:NSMakeRange(0, [string length])];

	[string replaceOccurrencesOfString:WCRecordSeparator
			withString:@"\t"
			options:0
			range:NSMakeRange(0, [string length])];
	
	// --- create attributed string
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					color, NSForegroundColorAttributeName,
					[NSFont fontWithName:@"Helvetica" size:11], NSFontAttributeName,
					NULL];
	output = [[NSAttributedString alloc] initWithString:string attributes:attributes];
	
	// --- print
	[[_consoleTextView textStorage] appendAttributedString:output];

	// --- scroll with it
	[_consoleTextView scrollRangeToVisible:NSMakeRange([[_consoleTextView textStorage] length], 0)];
	
	// --- release strings
	[output release];
	[string release];
}

@end
