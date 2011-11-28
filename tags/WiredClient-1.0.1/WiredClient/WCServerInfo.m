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
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "NSTextFieldAdditions.h"
#import "WCClient.h"
#import "WCConnection.h"
#import "WCSecuresocket.h"
#import "WCServerInfo.h"

@implementation WCServerInfo

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"ServerInfo"];
	
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
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionGotServerInfo:)
			   name:WCConnectionGotServerInfo
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverInfoShouldShowBanner:)
			   name:WCServerInfoShouldShowBanner
			 object:NULL];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection release];
	[_uptime release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- set window positions
	[self setWindowFrameAutosaveName:@"ServerInfo"];
	[self setShouldCascadeWindows:NO];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	// --- update uptime
	if(_uptime) {
		[_uptimeTextField setStringValue:[NSString stringWithFormat:
			NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
			[[NSNumber numberWithInt:time(NULL) - [_uptime timeIntervalSince1970]] humanReadableTime],
			[_uptime localizedDateWithFormat:NSShortTimeDateFormatString]]];
	}
	
	[super windowDidBecomeKey:notification];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %@",
		[_connection name], NSLocalizedString(@"Info", @"Server info window title")]];
	
	// --- get banner
	[[_connection client] sendCommand:WCGetCommand withArgument:[NSString stringWithFormat:
		@"%@%@%u", @"/WIRED/banner.png", WCFieldSeparator, 0]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	[self close];
	[self release];
}



- (void)connectionGotServerInfo:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *version, *protocol, *name, *description, *url, *uptime;
	NSRect			rect;
	WCConnection	*connection;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	version		= [fields objectAtIndex:0];
	protocol	= [fields objectAtIndex:1];
	name		= [fields objectAtIndex:2];
	description	= [fields objectAtIndex:3];
	uptime		= [fields objectAtIndex:4];
	
	// --- build url string
	url = [NSString stringWithFormat:@"%@://%@", [[_connection URL] scheme], [[_connection URL] host]];
	
	if([[_connection URL] port])
		url = [url stringByAppendingFormat:@":%@", [[_connection URL] port]];

	url = [url stringByAppendingString:@"/"];
	
	// --- save uptime
	_uptime = [[NSDate dateWithISO8601String:uptime] retain];

	// --- set fields
	[_nameTextField setStringValue:name];
	[_descriptionTextField setStringValue:description];
	[_uptimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[[NSNumber numberWithInt:time(NULL) - [_uptime timeIntervalSince1970]] humanReadableTime],
		[_uptime localizedDateWithFormat:NSShortTimeDateFormatString]]];
	[_urlTextField setStringValue:url];
	[_versionTextField setStringValue:[version versionString]];
	[_protocolTextField setStringValue:protocol];
	[_cipherTextField setStringValue:[[[_connection client] socket] cipher]];

	// --- resize (begin from bottom)
	_last = 4;
	
	[_cipherTextField setFrameForString:[_cipherTextField stringValue] 
							withControl:_cipherTitleTextField
								 offset:&_last];
	[_protocolTextField setFrameForString:[_protocolTextField stringValue] 
							  withControl:_protocolTitleTextField
								   offset:&_last];
	[_versionTextField setFrameForString:[_versionTextField stringValue] 
							 withControl:_versionTitleTextField
								  offset:&_last];
	[_urlTextField setFrameForString:[_urlTextField stringValue] 
						 withControl:_urlTitleTextField
							  offset:&_last];
	[_uptimeTextField setFrameForString:[_uptimeTextField stringValue] 
							withControl:_uptimeTitleTextField
								 offset:&_last];
	[_descriptionTextField setFrameForString:[_descriptionTextField stringValue] 
								 withControl:_descriptionTitleTextField
									  offset:&_last];

	// --- resize top fields
	rect = [_nameTextField frame];
	rect.origin.y = _last + 90;
	[_nameTextField setFrame:rect];
	
	rect = [_bannerImageView frame];
	rect.origin.y = _last + 22;
	[_bannerImageView setFrame:rect];

	// --- resize window
	rect = [[self window] frame];
	rect.size.height = _last + 127;
	[[self window] setContentSize:rect.size];
}



- (void)serverInfoShouldShowBanner:(NSNotification *)notification {
	NSString		*path;
	NSImage			*banner = NULL;
	WCConnection	*connection;
	NSRect			rect;
	off_t			size = 0;
	
	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	path		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get size
	if(![path isEqualToString:@""])
		size = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO] fileSize];
	
	// --- open banner
	if(size > 0)
		banner = [[NSImage alloc] initWithContentsOfFile:path];
	
	if(banner) {
		// --- set image
		[_bannerImageView setImage:banner];
		[banner release];
	} else {
		// --- remove imageview
		[_bannerImageView removeFromSuperview];

		// --- resize top fields
		rect = [_nameTextField frame];
		rect.origin.y = _last + 25;
		[_nameTextField setFrame:rect];

		// --- resize window
		rect = [[self window] frame];
		rect.size.height = _last + 62;
		[[self window] setContentSize:rect.size];
	}
	
	[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
}

@end
