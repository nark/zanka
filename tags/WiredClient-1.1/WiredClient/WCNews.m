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
	_news = [[NSMutableAttributedString alloc] init];
	
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
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"News"];
	
	// --- set up window
	[self update];
	[self updateButtons];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
		
	// --- set titles when host is resolved
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"News", @"News window title")]];

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



- (void)newsShouldAddNews:(NSNotification *)notification {
	NSArray				*fields;
	NSString			*argument, *nick, *date, *news;
	NSAttributedString  *header;
	NSFont				*font, *headerFont;
	WCConnection		*connection;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- update from prefs
	[self update];

	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	nick	= [fields objectAtIndex:0];
	date	= [fields objectAtIndex:1];
	news	= [fields objectAtIndex:2];
	
	// --- get fonts
	font		= [WCSettings archivedObjectForKey:WCNewsFont];
	headerFont  = [NSFont fontWithName:[NSString stringWithFormat:@"%@-Bold", [font familyName]]
								  size:[font pointSize]];

	if(!headerFont)
		headerFont = font;

	// --- create header
	header = [[NSAttributedString alloc]
					initWithString:[NSString stringWithFormat:
							NSLocalizedString(@"From %@ (%@):", @"News header (nick, time"),
							nick,
							[[NSDate dateWithISO8601String:date] 
								localizedDateWithFormat:NSShortTimeDateFormatString]]
						attributes:[NSDictionary dictionaryWithObjectsAndKeys:
							headerFont,
								NSFontAttributeName,
							[NSColor grayColor],
								NSForegroundColorAttributeName,
							NULL]];

	// --- append to news
	[_news appendAttributedString:header];
	[[_news mutableString] appendString:@"\n"];
	[_news appendAttributedString:[_newsTextView scan:news]];
	[[_news mutableString] appendString:@"\n\n"];
	
	[header release];
}



- (void)newsShouldCompleteNews:(NSNotification *)notification {
	NSRange		range;
	
	if([notification object] != _connection)
		return;
	
	// --- delete trailing newlines
	while([[_news mutableString] hasSuffix:@"\n"]) {
		range.location = [[_news mutableString] length] - 1;
		range.length = 1;
		[[_news mutableString] deleteCharactersInRange:range];
	}
	
	// --- show news
	[[_newsTextView textStorage] setAttributedString:_news];
}



- (void)newsShouldAddNewNews:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *nick, *date, *news;
	NSAttributedString  *header;
	NSFont				*font, *headerFont;
	WCConnection	*connection;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- update from prefs
	[self update];

	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	nick	= [fields objectAtIndex:0];
	date	= [fields objectAtIndex:1];
	news	= [fields objectAtIndex:2];

	// --- get fonts
	font		= [WCSettings archivedObjectForKey:WCNewsFont];
	headerFont  = [NSFont fontWithName:[NSString stringWithFormat:@"%@-Bold", [font familyName]]
								  size:[font pointSize]];
	
	if(!headerFont)
		headerFont = font;
	
	// --- create header
	header = [[NSAttributedString alloc]
					initWithString:[NSString stringWithFormat:
						NSLocalizedString(@"From %@ (%@):", @"News header (nick, time"),
						nick,
						[[NSDate dateWithISO8601String:date] 
								localizedDateWithFormat:NSShortTimeDateFormatString]]
						attributes:[NSDictionary dictionaryWithObjectsAndKeys:
							headerFont,
							NSFontAttributeName,
							[NSColor grayColor],
							NSForegroundColorAttributeName,
							NULL]];
	
	// --- insert at top
	[[_news mutableString] insertString:@"\n\n" atIndex:0];
	[_news insertAttributedString:[_newsTextView scan:news] atIndex:0];
	[[_news mutableString] insertString:@"\n" atIndex:0];
	[_news insertAttributedString:header atIndex:0];
	
	// --- show news
	[[_newsTextView textStorage] setAttributedString:_news];

	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCNewsEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCNewsEventSound]] play];
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		value = NO;
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:)) {
		if(*[[[NSApp currentEvent] characters] cString] == NSEnterCharacter) {
			[self okSheet:_postTextView];
			
			value = YES;
		}
	}
	
	return value;
}




- (void)postSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSRunStoppedResponse) {
		// --- send command
		[[_connection client] sendCommand:WCPostCommand withArgument:[_postTextView string]];
	}

	// --- close sheet
	[_postPanel close];
	
	// --- clear for next round
	[_postTextView setString:@""];
	[_postTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];
}




- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		// --- send clear news command
		[[_connection client] sendCommand:WCClearNewsCommand];
		
		// --- re-request news so that if the news couldn't be cleared, it will at least be refilled
		[self reload:self];
	}
}



#pragma mark -

- (void)update {
	// --- font
	[_newsTextView setFont:[WCSettings archivedObjectForKey:WCNewsFont]];
	[_postTextView setFont:[WCSettings archivedObjectForKey:WCTextFont]];

	// --- color
	[_newsTextView setTextColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_newsTextView setBackgroundColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];
	[_newsTextView setURLColor:[WCSettings archivedObjectForKey:WCURLTextColor]];
	[_newsTextView setEventColor:[WCSettings archivedObjectForKey:WCEventTextColor]];
	[_postTextView setTextColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	[_postTextView setBackgroundColor:[WCSettings archivedObjectForKey:WCNewsBackgroundColor]];
	[_postTextView setInsertionPointColor:[WCSettings archivedObjectForKey:WCNewsTextColor]];
	
	// --- mark them as updated
	[_newsTextView setNeedsDisplay:YES];
	[_postTextView setNeedsDisplay:YES];
}



- (void)updateButtons {
	[_postButton setEnabled:[[_connection account] postNews]];
	[_clearButton setEnabled:[[_connection account] clearNews]];
}



#pragma mark -

- (IBAction)post:(id)sender {
	// --- show window
//	[_postWindow makeKeyAndOrderFront:self];
	
	// --- bring up sheet
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(postSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
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
	[_news release];
	_news = [[NSMutableAttributedString alloc] init];
	[[_newsTextView textStorage] setAttributedString:_news]; 
	[_newsTextView setNeedsDisplay:YES];
	
	// --- re-request news
	[[_connection client] sendCommand:WCNewsCommand];
}

@end
