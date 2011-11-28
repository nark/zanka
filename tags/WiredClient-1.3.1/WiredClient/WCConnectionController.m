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

#import "WCConnectionController.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCKeychain.h"
#import "WCPreferences.h"
#import "WCSettings.h"

@interface WCConnectionController(Private)

- (void)_loadWindowTemplate;
- (void)_saveWindowTemplate;

@end


@implementation WCConnectionController(Private)

- (void)_loadWindowTemplate {
	NSDictionary	*windowTemplate;
	
	_identifier = [[[self connection] identifier] retain];
	
	windowTemplate = [WCSettings windowTemplateForKey:_identifier];
	
	if(!windowTemplate)
		windowTemplate = [WCSettings windowTemplateForKey:WCWindowTemplatesDefault];
	
	if(windowTemplate)
		_windowTemplate = [[windowTemplate objectForKey:[self windowNibName]] mutableCopy];

	if(!_windowTemplate)
		_windowTemplate = [[NSMutableDictionary alloc] init];
	
	[self windowTemplateShouldLoad:_windowTemplate];
}



- (void)_saveWindowTemplate {
	NSMutableDictionary		*windowTemplate;
	
	if(_windowTemplate) {
		[self windowTemplateShouldSave:_windowTemplate];
		
		windowTemplate = [[WCSettings windowTemplateForKey:_identifier] mutableCopy];
		
		if(!windowTemplate)
			windowTemplate = [[NSMutableDictionary alloc] init];
		
		[windowTemplate setObject:_windowTemplate forKey:[self windowNibName]];
		
		[WCSettings setWindowTemplate:windowTemplate forKey:_identifier];
		
		[windowTemplate release];
	}
}

@end


@implementation WCConnectionController

- (id)initWithWindowNibName:(NSString *)nibName connection:(WCServerConnection *)connection {
	return [self initWithWindowNibName:nibName name:NULL connection:connection];
}



- (id)initWithWindowNibName:(NSString *)nibName name:(NSString *)name connection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:nibName];

	_name = [name retain];
	_connection = connection;
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WC_applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[_connection addObserver:self
					selector:@selector(_connectionWillTerminate:)
						name:WCConnectionWillTerminate];

	[_connection addObserver:self
					selector:@selector(_connectionDidTerminate:)
						name:WCConnectionDidTerminate];

	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldHide:)
						name:WCServerConnectionShouldHide];
	
	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldUnhide:)
						name:WCServerConnectionShouldUnhide];

	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldLoadWindowTemplate:)
						name:WCServerConnectionShouldLoadWindowTemplate];

	[_connection addObserver:self
					selector:@selector(_serverConnectionShouldSaveWindowTemplate:)
						name:WCServerConnectionShouldSaveWindowTemplate];
	
	if([self respondsToSelector:@selector(connectionDidConnect:)]) {
		[_connection addObserver:self
						selector:@selector(connectionDidConnect:)
							name:WCConnectionDidConnect];
	}

	if([self respondsToSelector:@selector(connectionDidClose:)]) {
		[_connection addObserver:self
						selector:@selector(connectionDidClose:)
							name:WCConnectionDidClose];
	}

	if([self respondsToSelector:@selector(connectionWillTerminate:)]) {
		[_connection addObserver:self
						selector:@selector(connectionWillTerminate:)
							name:WCConnectionWillTerminate];
	}
	
	if([self respondsToSelector:@selector(connectionDidTerminate:)]) {
		[_connection addObserver:self
						selector:@selector(connectionDidTerminate:)
							name:WCConnectionDidTerminate];
	}
	
	if([self respondsToSelector:@selector(serverConnectionLoggedIn:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionLoggedIn:)
							name:WCServerConnectionLoggedIn];
	}
	
	if([self respondsToSelector:@selector(serverConnectionWillReconnect:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionWillReconnect:)
							name:WCServerConnectionWillReconnect];
	}

	if([self respondsToSelector:@selector(serverConnectionServerInfoDidChange:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionServerInfoDidChange:)
							name:WCServerConnectionServerInfoDidChange];
	}

	if([self respondsToSelector:@selector(serverConnectionBannerDidChange:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionBannerDidChange:)
							name:WCServerConnectionBannerDidChange];
	}

	if([self respondsToSelector:@selector(serverConnectionPrivilegesDidChange:)]) {
		[_connection addObserver:self
						selector:@selector(serverConnectionPrivilegesDidChange:)
							name:WCServerConnectionPrivilegesDidChange];
	}
	
	return self;
}



- (void)dealloc {
	[_name release];
	[_identifier release];

	[_connection removeObserver:self];
	_connection = NULL;
	
	[_windowTemplate release];

	[super dealloc];
}



#pragma mark -

- (void)_WC_applicationWillTerminate:(NSNotification *)notification {
	[self _saveWindowTemplate];
}



- (void)_WC_windowWillClose:(NSNotification *)notification {
	if([self isReleasedWhenClosed]) {
		[self _saveWindowTemplate];
		
		[self autorelease];
	}
}



- (void)_connectionWillTerminate:(NSNotification *)notification {
	[self _saveWindowTemplate];
}



- (void)_connectionDidTerminate:(NSNotification *)notification {
	[_connection removeObserver:self];
	_connection = NULL;
}



- (void)_serverConnectionShouldHide:(NSNotification *)notification {
	_wasVisible = [[self window] isVisible];
	_hidden = YES;

	[[self window] orderOut:self];
}



- (void)_serverConnectionShouldUnhide:(NSNotification *)notification {
	if(_wasVisible)
		[[self window] orderFront:self];

	_hidden = NO;
}



- (void)_serverConnectionShouldLoadWindowTemplate:(NSNotification *)notification {
	[self _loadWindowTemplate];
}



- (void)_serverConnectionShouldSaveWindowTemplate:(NSNotification *)notification {
	[self _saveWindowTemplate];
}



#pragma mark -

- (void)windowDidLoad {
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WC_windowWillClose:)
			   name:NSWindowWillCloseNotification
			 object:[self window]];
}



- (NSDictionary *)windowTemplate {
	if(!_windowTemplate)
		[self _loadWindowTemplate];
	
	return _windowTemplate;
}



- (BOOL)isHidden {
	return _hidden;
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];

	_name = name;
}



- (NSString *)name {
	return _name;
}



- (void)setConnection:(WCServerConnection *)connection {
	[connection retain];
	[_connection release];

	_connection = connection;
}



- (WCServerConnection *)connection {
	return _connection;
}



- (void)setReleasedWhenClosed:(BOOL)value {
	_releasedWhenClosed = value;
}



- (BOOL)isReleasedWhenClosed {
	return _releasedWhenClosed;
}



#pragma mark -

- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	BOOL		connected;
	
	if(![self connection])
		return NO;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(reconnect:))
		return !connected;
	else if(selector == @selector(files:) || selector == @selector(postNews:) || selector == @selector(broadcast:))
		return connected;
	
	return YES;
}



- (IBAction)disconnect:(id)sender {
	[[[[self connection] chat] window] performClose:self];
}



- (IBAction)reconnect:(id)sender {
	[[self connection] reconnect];
}



- (IBAction)serverInfo:(id)sender {
	[[[self connection] serverInfo] showWindow:self];
}



- (IBAction)chat:(id)sender {
	[[[self connection] chat] showWindow:self];
}



- (IBAction)news:(id)sender {
	[[[self connection] news] showWindow:self];
}



- (IBAction)messages:(id)sender {
	[[[self connection] messages] showWindow:self];
}



- (IBAction)files:(id)sender {
	[WCFiles filesWithConnection:[self connection] path:[WCFile fileWithRootDirectory]];
}



- (IBAction)transfers:(id)sender {
	[[[self connection] transfers] showWindow:self];
}



- (IBAction)accounts:(id)sender {
	[[[self connection] accounts] showWindow:self];
}



- (IBAction)postNews:(id)sender {
	[[[self connection] news] postNews:self];
}



- (IBAction)broadcast:(id)sender {
	[[[self connection] messages] broadcast:self];
}



#pragma mark -

- (IBAction)search:(id)sender {
	[[[self connection] search] showWindow:self];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary		*bookmark;
	NSString			*host, *login, *password;
	WIURL				*url;
	WCServerConnection	*connection;
	
	connection = [self connection];
	url = [connection URL];
	
	if(url) {
		host		= [url host];
		login		= [url user] ? [url user] : @"";
		password	= [url password] ? [url password] : @"";
		bookmark	= [NSDictionary dictionaryWithObjectsAndKeys:
			[connection name],			WCBookmarksName,
			[url hostpair],				WCBookmarksAddress,
			login,						WCBookmarksLogin,
			@"",						WCBookmarksNick,
			@"",						WCBookmarksStatus,
			[NSString UUIDString],		WCBookmarksIdentifier,
			NULL];
		[WCSettings addBookmark:bookmark];
		
		[[WCKeychain keychain] setPassword:password forBookmark:bookmark];

		[connection setBookmark:bookmark];
		[connection postNotificationName:WCServerConnectionShouldSaveWindowTemplate];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChange];
	}
}



#pragma mark -

- (IBAction)console:(id)sender {
	[[[self connection] console] showWindow:self];
}

@end
