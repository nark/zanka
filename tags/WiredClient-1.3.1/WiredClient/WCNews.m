/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCAccount.h"
#import "WCNews.h"
#import "WCPreferences.h"

@interface WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_validate;

- (NSAttributedString *)_postWithNick:(NSString *)nick date:(NSDate *)date message:(NSString *)message;

@end


@implementation WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"News"
								   name:NSLS(@"News", @"News window title")
							 connection:connection];

	_news = [[NSMutableAttributedString alloc] init];
	_newsFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[self connection] addObserver:self
						  selector:@selector(newsShouldAddNews:)
							  name:WCNewsShouldAddNews];

	[[self connection] addObserver:self
						  selector:@selector(newsShouldCompleteNews:)
							  name:WCNewsShouldCompleteNews];

	[[self connection] addObserver:self
						  selector:@selector(newsShouldAddNewNews:)
							  name:WCNewsShouldAddNewNews];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_update {
	[_newsTextView setBackgroundColor:[WCSettings objectForKey:WCNewsBackgroundColor]];
	[_newsTextView setNeedsDisplay:YES];

	[_newsTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[WCSettings objectForKey:WCChatURLsColor],			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],	NSUnderlineStyleAttributeName,
		NULL]];
	
	[_postTextView setFont:[WCSettings objectForKey:WCNewsFont]];
	[_postTextView setTextColor:[WCSettings objectForKey:WCNewsTextColor]];
	[_postTextView setBackgroundColor:[WCSettings objectForKey:WCNewsBackgroundColor]];
	[_postTextView setInsertionPointColor:[WCSettings objectForKey:WCNewsTextColor]];
	[_postTextView setNeedsDisplay:YES];
}



- (void)_validate {
	WCAccount	*account;
	BOOL		connected;

	account = [[self connection] account];
	connected = [[self connection] isConnected];

	[_reloadButton setEnabled:connected];
	[_postButton setEnabled:([account postNews] && connected)];
	[_clearButton setEnabled:([account clearNews] && connected)];
}



#pragma mark -

- (NSAttributedString *)_postWithNick:(NSString *)nick date:(NSDate *)date message:(NSString *)message {
	NSMutableAttributedString	*post;
	NSAttributedString			*header, *entry;
	NSDictionary				*attributes;
	NSString					*string;
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[WCSettings objectForKey:WCNewsTitlesFont],		NSFontAttributeName,
		[WCSettings objectForKey:WCNewsTitlesColor],	NSForegroundColorAttributeName,
		NULL];
	string = [NSSWF:NSLS(@"From %@ (%@):\n", @"News header (nick, time)"),
		nick,
		[date commonDateStringWithSeconds:NO]];
	header = [NSAttributedString attributedStringWithString:string attributes:attributes];
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[WCSettings objectForKey:WCNewsFont],			NSFontAttributeName,
		[WCSettings objectForKey:WCNewsTextColor],		NSForegroundColorAttributeName,
		NULL];
	entry = [NSAttributedString attributedStringWithString:message attributes:attributes];
	
	post = [NSMutableAttributedString attributedString];
	[post appendAttributedString:header];
	[post appendAttributedString:entry];
	
	return post;
}

@end


@implementation WCNews

+ (id)newsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initNewsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_news release];
	[_newsFilter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_newsTextView setEditable:NO];
	[_newsTextView setUsesFindPanel:YES];
	
	[self _update];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	while(_unread > 0) {
		_unread--;
		
		[[self connection] postNotificationName:WCNewsDidReadPost object:[self connection]];
	}
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCNewsWindow"] restoreSize:YES visibility:![self isHidden]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCNewsWindow"];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[self close];
	[self autorelease];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[[_news mutableString] setString:@""];

	[self _validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)newsShouldAddNews:(NSNotification *)notification {
	NSArray					*fields;
	NSString				*nick, *date, *message;
	NSAttributedString		*post;

	fields = [[notification userInfo] objectForKey:WCArgumentsKey];
	
	if([fields count] < 3)
		return;
	
	nick	= [fields safeObjectAtIndex:0];
	date	= [fields safeObjectAtIndex:1];
	message	= [fields safeObjectAtIndex:2];

	post = [self _postWithNick:nick date:[NSDate dateWithISO8601String:date] message:message];
	[_news appendAttributedString:post];
	[[_news mutableString] appendString:@"\n\n"];
}



- (void)newsShouldCompleteNews:(NSNotification *)notification {
	NSRange		range;

	while([[_news mutableString] hasSuffix:@"\n"]) {
		range = NSMakeRange([[_news mutableString] length] - 1, 1);
		[[_news mutableString] deleteCharactersInRange:range];
	}

	[[_newsTextView textStorage] setAttributedString:[_news attributedStringByApplyingFilter:_newsFilter]];
	[_progressIndicator stopAnimation:self];
}



- (void)newsShouldAddNewNews:(NSNotification *)notification {
	NSArray					*fields;
	NSString				*nick, *date, *message;
	NSAttributedString		*post;

	fields	= [[notification userInfo] objectForKey:WCArgumentsKey];
	nick	= [fields safeObjectAtIndex:0];
	date	= [fields safeObjectAtIndex:1];
	message	= [fields safeObjectAtIndex:2];

	post = [self _postWithNick:nick date:[NSDate dateWithISO8601String:date] message:message];
	[[_news mutableString] insertString:@"\n\n" atIndex:0];
	[_news insertAttributedString:[post attributedStringByApplyingFilter:_newsFilter] atIndex:0];
	[[_newsTextView textStorage] setAttributedString:_news];
	
	if(![[self window] isVisible]) {
		_unread++;
		
		[[self connection] postNotificationName:WCNewsDidAddPost object:[self connection]];
	}

	[[self connection] postNotificationName:WCServerConnectionTriggeredEvent eventTag:WCEventsNewsPosted];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		value = NO;

	if(selector == @selector(insertNewline:)) {
		if([[[NSApp currentEvent] characters] characterAtIndex:0] == NSEnterCharacter) {
			[self submitSheet:_postTextView];

			value = YES;
		}
	}

	return value;
}



#pragma mark -

- (unsigned int)numberOfUnreadPosts {
	return _unread;
}



#pragma mark -

- (IBAction)postNews:(id)sender {
	[self showWindow:self];

	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(postSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)postSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSRunStoppedResponse)
		[[self connection] sendCommand:WCPostCommand withArgument:[_postTextView string]];

	[_postPanel close];
	[_postTextView setString:@""];
	[_postTextView setFont:[WCSettings objectForKey:WCNewsFont]];
}



- (IBAction)clearNews:(id)sender {
	NSBeginAlertSheet(NSLS(@"Are you sure you want to clear the news?", @"Clear news dialog title"),
					  NSLS(@"Clear", @"Clear news button title"),
					  NSLS(@"Cancel", @"Clear news button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(clearSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Clear news dialog description"));
}




- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		[[self connection] sendCommand:WCClearNewsCommand];

		[self reloadNews:self];
	}
}



- (IBAction)reloadNews:(id)sender {
	[[_news mutableString] setString:@""];
	[_newsTextView setString:@""];
	[_newsTextView setNeedsDisplay:YES];
	[_progressIndicator startAnimation:self];

	[[self connection] sendCommand:WCNewsCommand];
}

@end
