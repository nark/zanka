/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import "WCConsole.h"

@interface WCConsole(Private)

+ (NSColor *)_inputColor;
+ (NSColor *)_outputColor;

- (id)_initConsoleWithConnection:(WCServerConnection *)connection;

- (void)_log:(NSString *)string color:(NSColor *)color;
- (void)_print:(NSAttributedString *)string;

@end


@implementation WCConsole(Private)

+ (NSColor *)_inputColor {
	return [NSColor blueColor];
}



+ (NSColor *)_outputColor {
	return [NSColor blackColor];
}



#pragma mark -

- (id)_initConsoleWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Console"
								   name:NSLS(@"Console", @"Console window title")
							 connection:connection];

	[self window];
	
	[[self connection] addObserver:self
						  selector:@selector(connectionReceivedMessage:)
							  name:WCConnectionReceivedMessage];

	[[self connection] addObserver:self
						  selector:@selector(connectionSentCommand:)
							  name:WCConnectionSentCommand];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_log:(NSString *)string color:(NSColor *)color {
	static NSArray		*separators;
	static NSFont		*font;
	NSDictionary		*attributes;
	NSAttributedString	*attributedString;

	if(!separators) {
		separators = [[NSArray alloc] initWithObjects:
			WCFieldSeparator, WCGroupSeparator, WCRecordSeparator, NULL];
		
		font = [[NSFont fontWithName:@"Monaco" size:9.0] retain];
	}

	string = [string stringByReplacingOccurencesOfStrings:separators withString:@"\t"];

	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		color,		NSForegroundColorAttributeName,
		font,		NSFontAttributeName,
		NULL];
	attributedString = [NSAttributedString attributedStringWithString:string attributes:attributes];

	[self _print:attributedString];
}



- (void)_print:(NSAttributedString *)string {
	float		position;

	position = [[_consoleScrollView verticalScroller] floatValue];
	
	if([[_consoleTextView textStorage] length] > 0)
		[[[_consoleTextView textStorage] mutableString] appendString:@"\n"];
	
	[[_consoleTextView textStorage] appendAttributedString:string];
	
	if(position == 1.0)
		[_consoleTextView performSelectorOnce:@selector(scrollToBottom) withObject:NULL afterDelay:0.05];
}

@end


@implementation WCConsole

+ (id)consoleWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initConsoleWithConnection:connection] autorelease];
}



#pragma mark -

- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCConsoleWindow"] restoreSize:YES visibility:![self isHidden]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCConsoleWindow"];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[super connectionWillTerminate:notification];

	[self close];
	[self autorelease];
}



- (void)connectionReceivedMessage:(NSNotification *)notification {
	[self _log:[notification object] color:[WCConsole _inputColor]];
}



- (void)connectionSentCommand:(NSNotification *)notification {
	[self _log:[notification object] color:[WCConsole _outputColor]];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}

@end
