/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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
#import "WCApplicationController.h"
#import "WCNews.h"
#import "WCNewsPost.h"
#import "WCPreferences.h"

@interface WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_validate;
- (void)_reloadNews;
- (void)_readAllPosts;

- (NSAttributedString *)_attributedStringForPost:(WCNewsPost *)post;
- (NSAttributedString *)_attributedStringForPosts;

@end


@implementation WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"News"
								   name:NSLS(@"News", @"News window title")
							 connection:connection];

	_posts = [[NSMutableArray alloc] init];
	_newsFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(dateDidChange:)
			   name:WCDateDidChange];
	
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
	[_newsTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsBackgroundColor]]];
	[_newsTextView setNeedsDisplay:YES];

	[_newsTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];
	
	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]]];
	[_postTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTextColor]]];
	[_postTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsBackgroundColor]]];
	[_postTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTextColor]]];
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
	[_posts removeAllObjects];
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

- (NSAttributedString *)_attributedStringForPost:(WCNewsPost *)post {
	NSMutableAttributedString	*attributedString;
	NSAttributedString			*header, *entry;
	NSDictionary				*attributes;
	NSString					*string;
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTitlesFont]],
			NSFontAttributeName,
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTitlesColor]],
			NSForegroundColorAttributeName,
		NULL];
	string = [NSSWF:NSLS(@"From %@ (%@):\n", @"News header (nick, time)"),
		[post userNick],
		[_dateFormatter stringFromDate:[post date]]];
	header = [NSAttributedString attributedStringWithString:string attributes:attributes];
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]],
			NSFontAttributeName,
		[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsTextColor]],
			NSForegroundColorAttributeName,
		NULL];
	entry = [NSAttributedString attributedStringWithString:[post message] attributes:attributes];
	
	attributedString = [NSMutableAttributedString attributedString];
	[attributedString appendAttributedString:header];
	[attributedString appendAttributedString:entry];
	
	return [attributedString attributedStringByApplyingFilter:_newsFilter];
}



- (NSAttributedString *)_attributedStringForPosts {
	NSMutableAttributedString	*attributedString;
	NSUInteger					i, count;
	
	attributedString = [NSMutableAttributedString attributedString];
	count = [_posts count];
	
	for(i = 0; i < count; i++) {
		[attributedString appendAttributedString:[self _attributedStringForPost:[_posts objectAtIndex:i]]];
		
		if(i != count - 1)
			[[attributedString mutableString] appendString:@"\n\n"];
	}
	
	return attributedString;
}

@end


@implementation WCNews

+ (id)newsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initNewsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_posts release];
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

	[super connectionWillTerminate:notification];

	[self close];
	[self autorelease];
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
	WCNewsPost			*post;
	
	post = [WCNewsPost newsPostWithArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if(!post)
		return;
	
	[_posts addObject:post];
}



- (void)newsShouldCompleteNews:(NSNotification *)notification {
	[[_newsTextView textStorage] setAttributedString:[self _attributedStringForPosts]];

	[_progressIndicator stopAnimation:self];
}



- (void)newsShouldAddNewNews:(NSNotification *)notification {
	NSAttributedString		*string;
	WCNewsPost				*post;
	
	post = [WCNewsPost newsPostWithArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	
	if(!post)
		return;

	if([_posts count] == 0)
		[_posts addObject:post];
	else
		[_posts insertObject:post atIndex:0];
	
	string = [self _attributedStringForPost:post];
	
	if([_posts count] > 0)
		[[[_newsTextView textStorage] mutableString] insertString:@"\n\n" atIndex:0];
	
	[[_newsTextView textStorage] insertAttributedString:string atIndex:0];
	
	if(![[self window] isVisible]) {
		_unread++;
		
		[[self connection] postNotificationName:WCNewsDidAddPost object:[self connection]];
	}

	[[self connection] triggerEvent:WCEventsNewsPosted info1:[post userNick] info2:[post message]];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)dateDidChange:(NSNotification *)notification {
	[[_newsTextView textStorage] setAttributedString:[self _attributedStringForPosts]];
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
	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[WCSettings settings] objectForKey:WCNewsFont]]];
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
