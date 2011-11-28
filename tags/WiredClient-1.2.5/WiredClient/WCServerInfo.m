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
#import "NSURLAdditions.h"
#import "WCConnection.h"
#import "WCSecuresocket.h"
#import "WCServer.h"
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
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionServerInfoDidChange:)
			   name:WCConnectionServerInfoDidChange
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionServerBannerDidChange:)
			   name:WCConnectionServerBannerDidChange
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
	[self setWindowFrameAutosaveName:@"ServerInfo"];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	WCServer	*server;
	
	// --- get server
	server = [_connection server];

	// --- update uptime
	[_uptimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:
			[[NSDate date] timeIntervalSinceDate:[server started]]],
		[[server started] commonDateStringWithRelative:YES capitalized:NO seconds:NO]]];
	
	[super windowDidBecomeKey:notification];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	[self close];
	[self release];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %@",
		[_connection name], NSLocalizedString(@"Info", @"Server info window title")]];

	// --- update info
	[self updateServerInfo];
}



- (void)connectionServerBannerDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;

	// --- set banner
	[_bannerImageView setImage:[[_connection server] banner]];

	// --- update info
	[self updateServerInfo];
}



#pragma mark -

- (void)updateServerInfo {
	WCServer	*server;
	NSRect		rect;
	
	// --- reset
	_last = 0;
	
	// --- get server
	server = [_connection server];
	
	// --- set fields
	[_nameTextField setStringValue:[server name]];
	[_descriptionTextField setStringValue:[server description]];
	[_uptimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:
			[[NSDate date] timeIntervalSinceDate:[server started]]],
		[[server started] commonDateStringWithRelative:YES capitalized:NO seconds:NO]]];
	[_urlTextField setStringValue:[[_connection URL] humanReadableURL]];
	[_versionTextField setStringValue:[[server version] clientVersion]];
	[_protocolTextField setStringValue:[NSString stringWithFormat:@"%.1f", [server protocol]]];
	[_certificateTextField setStringValue:[[_connection socket] certificate]];
	[_cipherTextField setStringValue:[[_connection socket] cipher]];
	
	// --- protocol 1.1
	if([server protocol] >= 1.1) {
		[_filesTextField setIntValue:[server files]];
		[_sizeTextField setStringValue:
			[NSString humanReadableStringForSize:[server size]]];
	}
	
	// --- resize (begin from bottom)
	[_certificateTextField setFrameWithControl:_certificateTitleTextField atOffset:&_last];
	[_cipherTextField setFrameWithControl:_cipherTitleTextField atOffset:&_last];
	[_protocolTextField setFrameWithControl:_protocolTitleTextField atOffset:&_last];
	[_versionTextField setFrameWithControl:_versionTitleTextField atOffset:&_last];
	[_sizeTextField setFrameWithControl:_sizeTitleTextField atOffset:&_last];
	[_filesTextField setFrameWithControl:_filesTitleTextField atOffset:&_last];
	[_urlTextField setFrameWithControl:_urlTitleTextField atOffset:&_last];
	[_uptimeTextField setFrameWithControl:_uptimeTitleTextField atOffset:&_last];
	[_descriptionTextField setFrameWithControl:_descriptionTitleTextField atOffset:&_last];
	
	// --- resize top fields
	if([_bannerImageView image]) {
		rect = [_bannerImageView frame];
		rect.origin.y = _last + 14;
		_last += rect.size.height + 14;
		[_bannerImageView setFrame:rect];
	}

	rect = [_nameTextField frame];
	rect.origin.y = _last + 14;
	_last += rect.size.height + 14;
	[_nameTextField setFrame:rect];
	
	// --- resize window
	rect = [[self window] frame];
	rect.size.height = _last + 14;
	[[self window] setContentSize:rect.size];
}

@end
