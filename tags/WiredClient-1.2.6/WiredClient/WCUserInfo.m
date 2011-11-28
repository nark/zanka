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
#import "WCConnection.h"
#import "WCIcons.h"
#import "WCMain.h"
#import "WCUser.h"
#import "WCUserInfo.h"

@implementation WCUserInfo

- (id)initWithConnection:(WCConnection *)connection user:(WCUser *)user {
	self = [super initWithWindowNibName:@"UserInfo"];
	
	// --- get parameters
	_connection = [connection retain];
	_user = [user retain];

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
		selector:@selector(userInfoShouldShowInfo:)
		name:WCUserInfoShouldShowInfo
		object:NULL];

	// --- send the info command
	[_connection sendCommand:WCInfoCommand
				withArgument:[NSString stringWithFormat:@"%u", [_user uid]]
				  withSender:self];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection clearSender:self];

	[_connection release];
	[_user release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"%@ Info", @"User Info window title (nick)"), [_user nick]]];
	
	// --- window position
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"UserInfo"];
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (BOOL)connectionShouldHandleError:(int)error {
	[self release];
	
	return NO;
}



- (void)userInfoShouldShowInfo:(NSNotification *)notification {
	NSArray				*fields, *transfers;
	NSString			*argument, *uid, *host, *version, *cipher, *cipherBits;
	NSString			*loginTime, *idleTime, *downloads, *uploads;
	NSDate				*loginDate, *idleDate;
	NSEnumerator		*enumerator;
	NSRect				rect;
	NSTimeInterval		loginInterval, idleInterval;
	WCConnection		*connection;
	int					last = 18;

	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- get the fields of the input buffer
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	uid			= [fields objectAtIndex:0];
	host		= [fields objectAtIndex:7];
	version		= [fields objectAtIndex:8];
	cipher		= [fields objectAtIndex:9];
	cipherBits	= [fields objectAtIndex:10];
	loginTime	= [fields objectAtIndex:11];
	idleTime	= [fields objectAtIndex:12];
	downloads	= [fields objectAtIndex:13];
	uploads		= [fields objectAtIndex:14];
	
	if([uid unsignedIntValue] != [_user uid])
		return;
	
	// --- stop receiving this notification
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCUserInfoShouldShowInfo
		object:NULL];

	// --- resize window to a temporary size while we move stuff around
	rect = [[self window] frame];
	rect.size.height = 1024;
	[[self window] setContentSize:rect.size];

	// --- show uploads
	if([uploads length] > 0) {
		transfers	= [uploads componentsSeparatedByString:WCGroupSeparator];
		enumerator	= [transfers reverseObjectEnumerator];
		
		while((argument = [enumerator nextObject]))
			[self drawTransfer:argument last:&last];
		
		rect = [_uploadsTitleTextField frame];
		rect.origin.y = last;
		last += rect.size.height;
		[_uploadsTitleTextField setFrame:rect];
	} else {
		[_uploadsTitleTextField removeFromSuperview];
	}

	// --- show downloads
	if([downloads length] > 0) {
		transfers	= [downloads componentsSeparatedByString:WCGroupSeparator];
		enumerator	= [transfers reverseObjectEnumerator];
		
		while((argument = [enumerator nextObject]))
			[self drawTransfer:argument last:&last];
		
		rect = [_downloadsTitleTextField frame];
		rect.origin.y = last;
		last += rect.size.height;
		[_downloadsTitleTextField setFrame:rect];
	} else {
		[_downloadsTitleTextField removeFromSuperview];
	}

	// --- get dates
	loginDate		= [NSDate dateWithISO8601String:loginTime];
	loginInterval   = [[NSDate date] timeIntervalSince1970] - [loginDate timeIntervalSince1970];
	idleDate		= [NSDate dateWithISO8601String:idleTime];
	idleInterval	= [[NSDate date] timeIntervalSince1970] - [idleDate timeIntervalSince1970];

	// --- set fields
	[_iconImageView setImage:[_user iconWithIdleTint:NO]];
	[_nickTextField setStringValue:[_user nick]];
	
	if([_user status])
		[_statusTextField setStringValue:[_user status]];

	[_loginTextField setStringValue:[_user login]];
	[_idTextField setStringValue:uid];
	[_addressTextField setStringValue:[_user address]];
	[_hostTextField setStringValue:host];
	[_versionTextField setStringValue:[version clientVersion]];
	[_cipherTextField setStringValue:[NSString stringWithFormat:@"%@/%@ %@",
		cipher,
		cipherBits,
		NSLocalizedString(@"bits", "Cipher string")]];
	[_loginTimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:loginInterval],
		[loginDate commonDateStringWithRelative:YES capitalized:NO seconds:NO]]];
	[_idleTimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[NSString humanReadableStringForTimeInterval:idleInterval],
		[idleDate commonDateStringWithRelative:YES capitalized:NO seconds:NO]]];
	
	// --- resize
	[_idleTimeTextField setFrameWithControl:_idleTimeTitleTextField atOffset:&last];
	[_loginTimeTextField setFrameWithControl:_loginTimeTitleTextField atOffset:&last];

	if([cipher length] > 0) {
		[_cipherTextField setFrameWithControl:_cipherTitleTextField atOffset:&last];
	} else {
		[_cipherTextField removeFromSuperview];
		[_cipherTitleTextField removeFromSuperview];
	}
	
	if([version length] > 0) {
		[_versionTextField setFrameWithControl:_versionTitleTextField atOffset:&last];
	} else {
		[_versionTextField removeFromSuperview];
		[_versionTitleTextField removeFromSuperview];
	}

	if([host length] > 0) {
		[_hostTextField setFrameWithControl:_hostTitleTextField atOffset:&last];
	} else {
		[_hostTextField removeFromSuperview];
		[_hostTitleTextField removeFromSuperview];
	}
	
	[_addressTextField setFrameWithControl:_addressTitleTextField atOffset:&last];
 	[_idTextField setFrameWithControl:_idTitleTextField atOffset:&last];
	[_loginTextField setFrameWithControl:_loginTitleTextField atOffset:&last];
	
	if([_user status]) {
		[_statusTextField setFrameWithControl:_statusTitleTextField atOffset:&last];
	} else {
		[_statusTextField removeFromSuperview];
		[_statusTitleTextField removeFromSuperview];
	}

	rect = [_nickTextField frame];
	rect.origin.y = last + 23;
	[_nickTextField setFrame:rect];

	rect = [_iconImageView frame];
	rect.origin.y = last + 12;
	[_iconImageView setFrame:rect];

	// --- resize and show window
	rect = [[self window] frame];
	rect.size.height = last + 64;
	[[self window] setContentSize:rect.size];
	[self showWindow:self];
}



#pragma mark -

- (void)drawTransfer:(NSString *)argument last:(int *)last {
	NSProgressIndicator	*progressIndicator;
	NSTextField			*textField;
	NSArray				*fields;
	NSString			*path, *transferred, *size, *speed;
	
	// --- split fields
	fields		= [argument componentsSeparatedByString:WCRecordSeparator];
	path		= [fields objectAtIndex:0];
	transferred	= [fields objectAtIndex:1];
	size		= [fields objectAtIndex:2];
	speed		= [fields objectAtIndex:3];

	// --- set up status text field
	textField = [[NSTextField alloc] init];
	[textField setEditable:NO];
	[textField setDrawsBackground:NO];
	[textField setBordered:NO];
	[textField setSelectable:YES];
	[textField setFont:[NSFont systemFontOfSize:11.0]];
	[textField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@ of %@, %@/s", "User info transfer (transferred, total, speed)"),
		[NSString humanReadableStringForSize:[transferred unsignedLongLongValue]],
		[NSString humanReadableStringForSize:[size unsignedLongLongValue]],
		[NSString humanReadableStringForSize:[speed unsignedLongLongValue]]]];
	[textField setFrame:NSMakeRect(85, *last, 193, 14)];
	[[[self window] contentView] addSubview:textField];
	[textField release];

	// --- set up progress indicator
	progressIndicator = [[NSProgressIndicator alloc] init];
	[progressIndicator setControlSize:NSSmallControlSize];
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setMaxValue:1.0];
	[progressIndicator setDoubleValue:[transferred doubleValue] / [size doubleValue]];
	*last += 14;
	[progressIndicator setFrame:NSMakeRect(87, *last, 193, 12)];
	[[[self window] contentView] addSubview:progressIndicator];
	[progressIndicator release];
	
	// --- set up name text field
	textField = [[NSTextField alloc] init];
	[textField setEditable:NO];
	[textField setDrawsBackground:NO];
	[textField setBordered:NO];
	[textField setSelectable:YES];
	[textField setFont:[NSFont systemFontOfSize:11.0]];
	[textField setStringValue:[path lastPathComponent]];
	*last += 14;
	[textField setFrame:NSMakeRect(85, *last, 193, 14)];
	[[[self window] contentView] addSubview:textField];
	[textField release];
}

@end
