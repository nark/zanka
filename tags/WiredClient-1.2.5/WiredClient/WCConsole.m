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

#import "NSStringAdditions.h"
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
}



#pragma mark -

- (void)logInput:(NSString *)string {
	NSString	*input;
	
	input = [string stringByReplacingOccurencesOfStrings:[NSArray arrayWithObjects:
		WCFieldSeparator, WCGroupSeparator, WCRecordSeparator, NULL]
											   withString:@"\t"];

	[self log:input color:[NSColor blueColor]];
}



- (void)logOutput:(NSString *)string {
	NSString	*output;
	
	output = [string stringByReplacingOccurencesOfStrings:[NSArray arrayWithObjects:
		WCFieldSeparator, WCGroupSeparator, WCRecordSeparator, NULL]
											   withString:@"\t"];

	[self log:output color:[NSColor blackColor]];
}



- (void)log:(NSString *)string color:(NSColor *)color {
	NSDictionary		*attributes;
	NSAttributedString	*attributedString;
	
	// --- create attributed string
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		color, NSForegroundColorAttributeName,
		[NSFont fontWithName:@"Helvetica" size:11], NSFontAttributeName,
		NULL];
	attributedString = [[NSAttributedString alloc] initWithString:string attributes:attributes];

	// --- print
	if([[_consoleTextView textStorage] length] > 0)
		[[[_consoleTextView textStorage] mutableString] appendString:@"\n"];
		
	[[_consoleTextView textStorage] appendAttributedString:attributedString];
	
	// --- scroll with it
	if([[_consoleScrollView verticalScroller] floatValue] == 1.0) {
		[_consoleTextView scrollRangeToVisible:
			NSMakeRange([[_consoleTextView textStorage] length], 0)];
    }
	
	// --- release
	[attributedString release];
}

@end
