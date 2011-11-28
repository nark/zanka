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

#import "WCAccount.h"
#import "WCNews.h"
#import "WCPreferences.h"

@interface WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_validate;
- (void)_reloadNews;
- (void)_readAllPosts;

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
	[_newsTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsBackgroundColor]]];
	[_newsTextView setNeedsDisplay:YES];

	[_newsTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];
	
	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]]];
	[_postTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]]];
	[_postTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsBackgroundColor]]];
	[_postTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]]];
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



- (void)_reloadNews {
	[[_news mutableString] setString:@""];
	[_newsTextView setString:@""];
	[_newsTextView setNeedsDisplay:YES];
	[_progressIndicator startAnimation:self];

	[[self connection] sendCommand:WCNewsCommand];
}



- (void)_readAllPosts {
	while(_unread > 0) {
		_unread--;
		
		[[self connection] postNotificationName:WCNewsDidReadPost object:[self connection]];
	}
}



#pragma mark -

- (NSAttributedString *)_postWithNick:(NSString *)nick date:(NSDate *)date message:(NSString *)message {
	NSMutableAttributedString	*post;
	NSAttributedString			*header, *entry;
	NSDictionary				*attributes;
	NSString					*string;
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTitlesFont]],
			NSFontAttributeName,
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTitlesColor]],
			NSForegroundColorAttributeName,
		NULL];
	string = [NSSWF:NSLS(@"From %@ (%@):\n", @"News header (nick, time)"),
		nick,
		[_dateFormatter stringFromDate:date]];
	header = [NSAttributedString attributedStringWithString:string attributes:attributes];
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]],
			NSFontAttributeName,
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]],
			NSForegroundColorAttributeName,
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
	[_dateFormatter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_newsTextView setEditable:NO];
	[_newsTextView setUsesFindPanel:YES];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _update];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	[self _readAllPosts];
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
	[self _readAllPosts];

	[self close];
	[self autorelease];
	
	[super connectionWillTerminate:notification];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[self _validate];
	[self _reloadNews];
}



- (void)serverConnectionWillReconnect:(NSNotification *)notification {
	[self _readAllPosts];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	NSWindow	*sheet;
	
	sheet = [[self window] attachedSheet];
	
	if(sheet == _postPanel)
		_hiddenNews = [[_postTextView string] copy];
	
	[super serverConnectionShouldHide:notification];
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	[super serverConnectionShouldUnhide:notification];
	
	if(_hiddenNews) {
		[self showPost:_hiddenNews];
		
		[_hiddenNews release];
		_hiddenNews = NULL;
	}
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

	[[self connection] triggerEvent:WCEventsNewsPosted info1:nick info2:message];
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

- (void)showPost:(NSString *)post {
	[self showWindow:self];
	
	[_postTextView setString:post];

	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(postSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (NSUInteger)numberOfUnreadPosts {
	return _unread;
}



#pragma mark -

- (IBAction)postNews:(id)sender {
	[self showPost:@""];
}



- (void)postSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn)
		[[self connection] sendCommand:WCPostCommand withArgument:[_postTextView string]];

	[_postPanel close];
	[_postTextView setString:@""];
	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]]];
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
		
		[self _reloadNews];
	}
}



- (IBAction)reloadNews:(id)sender {
	[self _reloadNews];
}

@end
