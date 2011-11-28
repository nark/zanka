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

#import "NSDateAdditions.h"
#import "WCAccount.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCMain.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCSettings.h"
#import "WCURLTextView.h"

@implementation WCNews

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"News"];
	
	// --- get parameters
	_connection = [connection retain];
	
	// --- initiate our news string, this will hold the entire news
	_news = [[NSMutableString string] retain];
	
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
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];
		
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionPrivilegesDidChange:)
		name:WCConnectionPrivilegesDidChange
		object:NULL];
		
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(preferencesDidChange:)
		name:WCPreferencesDidChange
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(newsShouldAddNews:)
		name:WCNewsShouldAddNews
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(newsShouldCompleteNews:)
		name:WCNewsShouldCompleteNews
		object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(newsShouldAddNewNews:)
		name:WCNewsShouldAddNewNews
		object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection release];
	[_news release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- set window positions
	[self setWindowFrameAutosaveName:@"News"];
	[self setShouldCascadeWindows:NO];
	[_postWindow center];
	
	// --- set up window
	[self update];
	[self updateButtons];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- set titles when host is resolved
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"News", @"News window title"), 0x2014, [_connection name]]];
	[_postWindow setTitle:[NSString stringWithFormat:@"%@ %C %@",
		NSLocalizedString(@"Post News", @"Post News window title"), 0x2014, [_connection name]]];

	// --- show window
	if([[WCSettings objectForKey:WCShowNews] boolValue])
		[self showWindow:self];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				forKey:WCShowNews];

	[self close];
	[self release];
}



- (void)connectionPrivilegesDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- update buttons
	[self updateButtons];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}



- (void)newsShouldAddNews:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *nick, *date, *news;
	WCConnection	*connection;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	nick	= [fields objectAtIndex:0];
	date	= [fields objectAtIndex:1];
	news	= [fields objectAtIndex:2];

	// --- add news
	[_news appendFormat:NSLocalizedString(@"From %@ (%@):\n\n%@\n%@\n", @"News header (nick, time, message, delimiter"),
		nick,
		[[NSDate dateWithISO8601String:date] localizedDateWithFormat:NSShortTimeDateFormatString],
		news,
		NSLocalizedString(@"________________________________________________________________________",
						  @"News delimiter")];
}



- (void)newsShouldCompleteNews:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- show news
	[[_newsTextView textStorage] setAttributedString:[_newsTextView scan:_news]];
}



- (void)newsShouldAddNewNews:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *nick, *date, *news, *output;
	WCConnection	*connection;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	nick	= [fields objectAtIndex:0];
	date	= [fields objectAtIndex:1];
	news	= [fields objectAtIndex:2];

	// --- format news
	output = [NSString stringWithFormat:@"%@ %@ (%@):\n\n%@\n%@\n",
		NSLocalizedString(@"From", @"News from"),
		nick,
		[[NSDate dateWithISO8601String:date] localizedDateWithFormat:NSShortTimeDateFormatString],
		news,
		NSLocalizedString(@"________________________________________________________________________",
						  @"News delimiter")];

	// --- insert news at beginning
	[_news insertString:output atIndex:0];
	[[_newsTextView textStorage] setAttributedString:[_newsTextView scan:_news]];
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCSoundForNewPosts] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCSoundForNewPosts]] play];
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		value = NO;
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:)) {
		if(*[[[NSApp currentEvent] characters] cString] == NSEnterCharacter) {
			[self send:self];
			
			value = YES;
		}
	}
	
	return value;
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		// --- send clear news command
		[[_connection client] sendCommand:WCClearNewsCommand];
		
		// --- clear the news
		[_news setString:@""];
		
		// --- re-request news so that if the news couldn't be cleared, it will at least be refilled
		[[_connection client] sendCommand:WCNewsCommand];
	}
}



#pragma mark -

- (void)update {
	// --- font
	[_newsTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
	[_postTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];

	// --- color
	[_newsTextView setBackColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];
	[_newsTextView setForeColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_newsTextView setURLColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
	[_newsTextView setEventColor:[WCSettings archivedObjectForKey:WCEventTextColor]];

	[_postTextView setBackgroundColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];
	[_postTextView setTextColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_postTextView setInsertionPointColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	
	// --- parse text
	[[_newsTextView textStorage]
		replaceCharactersInRange:NSMakeRange(0, [[_newsTextView string] length])
		withAttributedString:[_newsTextView scan:[_newsTextView string]]];
	
	// --- mark them as updated
	[_newsTextView setNeedsDisplay:YES];
	[_postTextView setNeedsDisplay:YES];
}



- (void)updateButtons {
	if([[_connection account] postNews])
		[_postButton setEnabled:YES];
	else
		[_postButton setEnabled:NO];

	if([[_connection account] clearNews])
		[_clearButton setEnabled:YES];
	else
		[_clearButton setEnabled:NO];
}



#pragma mark -

- (void)add:(NSString *)add {
	[_news appendString:add];
}



- (void)append:(NSString *)add {
	[_news insertString:add atIndex:0];
	[[_newsTextView textStorage] setAttributedString:[_newsTextView scan:_news]];
}



- (void)complete {
}



#pragma mark -

- (IBAction)post:(id)sender {
	// --- show window
	[_postWindow makeKeyAndOrderFront:self];
}



- (IBAction)clear:(id)sender {
	// --- bring up an alert
	NSBeginAlertSheet(NSLocalizedString(@"Are you sure you want to clear the news?", @"Clear news dialog title"),
					  NSLocalizedString(@"Clear", @"Clear news button title"),
					  @"Cancel",
					  NULL,
					  [self window],
					  self,
					  @selector(clearSheetDidEnd: returnCode: contextInfo:),
					  NULL,
					  NULL,
					  NSLocalizedString(@"This cannot be undone.", @"Clear news dialog description"),
					  NULL);
}



- (IBAction)reload:(id)sender {
	// --- clear
	[_news setString:@""];
	[_newsTextView setNeedsDisplay:YES];
	
	// --- re-request news
	[[_connection client] sendCommand:WCNewsCommand];
}



- (IBAction)send:(id)sender {
	// --- send command
	[[_connection client] sendCommand:WCPostCommand withArgument:[_postTextView string]];
	
	// --- close window
	[_postWindow close];

	// --- re-set
	[_postTextView setString:@""];
	[_postTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
}

@end
