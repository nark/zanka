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

#import "WCServer.h"
#import "WCServerInfo.h"

@interface WCServerInfo(Private)

- (id)_initServerInfoWithConnection:(WCServerConnection *)connection;

- (void)_updateServerInfo;

- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(float *)offset;

@end


@implementation WCServerInfo(Private)

- (id)_initServerInfoWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"ServerInfo" connection:connection];

	[self window];

	[[self connection] addObserver:self
						  selector:@selector(serverConnectionReceivedServerInfo:)
							  name:WCServerConnectionReceivedServerInfo];

	[[self connection] addObserver:self
						  selector:@selector(serverConnectionBannerDidChange:)
							  name:WCServerConnectionBannerDidChange];

	[self retain];
	
	return self;
}



#pragma mark -

- (void)_updateServerInfo {
	WNSocket		*socket;
	WIURL			*url;
	WCServer		*server;
	NSRect			rect;
	float			offset = 18.0;

	socket	= [[self connection] socket];
	server	= [[self connection] server];
	url		= [[[[self connection] URL] copy] autorelease];
	
	[url setUser:NULL];
	[url setPassword:NULL];

	// --- set fields
	[_nameTextField setStringValue:[server name]];
	[_descriptionTextField setStringValue:[server serverDescription]];
	[_uptimeTextField setStringValue:[NSSWF:
		NSLS(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:
			[[NSDate date] timeIntervalSinceDate:[server startupDate]]],
		[_dateFormatter stringFromDate:[server startupDate]]]];
	[_urlTextField setStringValue:[url humanReadableString]];
	[_versionTextField setStringValue:[[server serverVersion] wiredVersion]];
	[_protocolTextField setStringValue:[NSSWF:@"%.1f", [server protocol]]];
	[_sslProtocolTextField setStringValue:[socket cipherVersion]];
	[_certificateTextField setStringValue:[NSSWF:NSLS(@"%@/%lu bits, %@", @"Certificate description (name, bits, hostname)"),
		[socket certificateName],
		[socket certificateBits],
		[socket certificateHostname]]];
	[_cipherTextField setStringValue:[NSSWF:NSLS(@"%@/%lu bits", @"Cipher description (name, bits)"),
		[socket cipherName],
		[socket cipherBits]]];
	[_filesTextField setIntValue:[server files]];
	[_sizeTextField setStringValue:
		[NSString humanReadableStringForSizeInBytes:[server size]]];
	
	// --- resize dynamic fields
	if([socket certificateBits] > 0) {
		[self _resizeTextField:_certificateTextField withTextField:_certificateTitleTextField atOffset:&offset];
	} else {
		[_certificateTextField removeFromSuperviewWithoutNeedingDisplay];
		_certificateTextField = NULL;
		
		[_certificateTitleTextField removeFromSuperviewWithoutNeedingDisplay];
		_certificateTitleTextField = NULL;
	}

	[self _resizeTextField:_cipherTextField withTextField:_cipherTitleTextField atOffset:&offset];
	[self _resizeTextField:_sslProtocolTextField withTextField:_sslProtocolTitleTextField atOffset:&offset];
	[self _resizeTextField:_protocolTextField withTextField:_protocolTitleTextField atOffset:&offset];
	[self _resizeTextField:_versionTextField withTextField:_versionTitleTextField atOffset:&offset];
	[self _resizeTextField:_sizeTextField withTextField:_sizeTitleTextField atOffset:&offset];
	[self _resizeTextField:_filesTextField withTextField:_filesTitleTextField atOffset:&offset];
	[self _resizeTextField:_urlTextField withTextField:_urlTitleTextField atOffset:&offset];
	[self _resizeTextField:_uptimeTextField withTextField:_uptimeTitleTextField atOffset:&offset];
	[self _resizeTextField:_descriptionTextField withTextField:_descriptionTitleTextField atOffset:&offset];

	// --- resize banner
	if([_bannerImageView image]) {
		rect = [_bannerImageView frame];
		rect.origin.y = offset + 14.0;
		offset += rect.size.height + 14.0;
		[_bannerImageView setFrame:rect];
	}

	// --- resize name field
	rect = [_nameTextField frame];
	rect.origin.y = offset + 14.0;
	offset += rect.size.height + 14.0;
	[_nameTextField setFrame:rect];

	// --- resize window
	rect = [[self window] frame];
	rect.size.height = offset + 14.0;
	[[self window] setContentSize:rect.size];
}



#pragma mark -

- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(float *)offset {
	double		height;
	
	if([[textField stringValue] length] == 0) {
		[textField setFrameOrigin:NSMakePoint([textField frame].origin.x, -100.0)];
		[titleTextField setFrameOrigin:NSMakePoint([titleTextField frame].origin.x, -100.0)];
	} else {
		[textField setFrameSize:[[textField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, _fieldFrame.size.width, 10000.0)]];
		[textField setFrameOrigin:NSMakePoint(_fieldFrame.origin.x, *offset)];

		height = [textField frame].size.height;
		
		[titleTextField setFrameSize:NSMakeSize([titleTextField frame].size.width, height)];
		[titleTextField setFrameOrigin:NSMakePoint([titleTextField frame].origin.x, *offset)];
		
		*offset += height + 2.0;
	}
}

@end


@implementation WCServerInfo

+ (id)serverInfoWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initServerInfoWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterNormalNaturalLanguageStyle];

	_fieldFrame	= [_descriptionTextField frame];

	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	WCServer	*server;

	server = [[self connection] server];

	[_uptimeTextField setStringValue:[NSSWF:
		NSLS(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:
			[[NSDate date] timeIntervalSinceDate:[server startupDate]]],
		[_dateFormatter stringFromDate:[server startupDate]]]];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCServerInfoWindow"] restoreSize:NO visibility:![self isHidden]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCServerInfoWindow"];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[self close];
	
	[self autorelease];
	
	[super connectionWillTerminate:notification];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];
}



- (void)serverConnectionReceivedServerInfo:(NSNotification *)notification {
	[[self window] setTitle:[NSSWF:
		NSLS(@"%@ Info", @"Server info window title (server)"), [[self connection] name]]];

	[self _updateServerInfo];
}



- (void)serverConnectionBannerDidChange:(NSNotification *)notification {
	[_bannerImageView setImage:[[[self connection] server] banner]];

	[self _updateServerInfo];
}

@end
