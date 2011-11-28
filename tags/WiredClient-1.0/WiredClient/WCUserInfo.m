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
	[[_connection client] sendCommand:WCInfoCommand withArgument:[NSString stringWithFormat:
		@"%d", [_user uid]]];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection release];
	[_user release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"%@ Info", @"User Info window title (nick)"), [_user nick]]];
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)userInfoShouldShowInfo:(NSNotification *)notification {
	NSArray				*fields, *transfers;
	NSString			*argument, *uid, *host, *version, *cipher, *cipherBits;
	NSString			*loginTime, *idleTime, *downloads, *uploads;
	NSDate				*loginDate, *idleDate;
	NSEnumerator		*enumerator;
	NSRect				rect;
	WCConnection		*connection;
	int					last = 4;

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
	
	if((unsigned int) [uid intValue] != [_user uid])
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
		
		rect = [_downloadsTitleTextField frame];
		rect.origin.y = last;
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
		[_downloadsTitleTextField setFrame:rect];
	} else {
		[_downloadsTitleTextField removeFromSuperview];
	}

	// --- get dates
	loginDate   = [NSDate dateWithISO8601String:loginTime];
	idleDate	= [NSDate dateWithISO8601String:idleTime];
	
	// --- set fields
	[_iconImageView setImage:[WCIcons objectForKey:[NSNumber numberWithInt:[_user icon]]]];
	[_nickTextField setStringValue:[_user nick]];
	[_loginTextField setStringValue:[_user login]];
	[_addressTextField setStringValue:[_user address]];
	[_hostTextField setStringValue:host];
	[_versionTextField setStringValue:[version versionString]];
	[_cipherTextField setStringValue:[NSString stringWithFormat:@"%@/%@ %@",
			cipher,
			cipherBits,
			NSLocalizedString(@"bits", "Cipher string")]];
	[_loginTimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[[NSNumber numberWithInt:time(NULL) - [loginDate timeIntervalSince1970]] humanReadableTime],
		[loginDate localizedDateWithFormat:NSShortTimeDateFormatString]]];
	[_idleTimeTextField setStringValue:[NSString stringWithFormat:
		NSLocalizedString(@"%@,\nsince %@", @"Time stamp (time counter, time string)"),
		[[NSNumber numberWithInt:time(NULL) - [idleDate timeIntervalSince1970]] humanReadableTime],
		[idleDate localizedDateWithFormat:NSShortTimeDateFormatString]]];
	
	// --- resize
	[_idleTimeTextField setFrameForString:[_idleTimeTextField stringValue] 
							  withControl:_idleTimeTitleTextField
								   offset:&last];
	[_loginTimeTextField setFrameForString:[_loginTimeTextField stringValue] 
							   withControl:_loginTimeTitleTextField
									offset:&last];

	if([cipher length] > 0) {
		[_cipherTextField setFrameForString:[_cipherTextField stringValue] 
								withControl:_cipherTitleTextField
									 offset:&last];
	} else {
		[_cipherTextField removeFromSuperview];
		[_cipherTitleTextField removeFromSuperview];
	}
	
	if([version length] > 0) {
		[_versionTextField setFrameForString:[_versionTextField stringValue] 
								 withControl:_versionTitleTextField
									  offset:&last];
	} else {
		[_versionTextField removeFromSuperview];
		[_versionTitleTextField removeFromSuperview];
	}

	if([host length] > 0) {
		[_hostTextField setFrameForString:[_hostTextField stringValue]
							  withControl:_hostTitleTextField
								   offset:&last];
	} else {
		[_hostTextField removeFromSuperview];
		[_hostTitleTextField removeFromSuperview];
	}
	
	[_addressTextField setFrameForString:[_addressTextField stringValue] 
							 withControl:_addressTitleTextField
								  offset:&last];
	[_loginTextField setFrameForString:[_loginTextField stringValue]
						   withControl:_loginTitleTextField
								offset:&last];

	rect = [_nickTextField frame];
	rect.origin.y = last + 33;
	[_nickTextField setFrame:rect];

	rect = [_iconImageView frame];
	rect.origin.y = last + 22;
	[_iconImageView setFrame:rect];

	// --- resize and show window
	rect = [[self window] frame];
	rect.size.height = last + 74;
	[[self window] setContentSize:rect.size];
	[[self window] center];
	[self showWindow:self];
}



#pragma mark -

- (void)drawTransfer:(NSString *)argument last:(int *)last {
	NSProgressIndicator	*progressIndicator;
	NSTextField			*statusTextField, *nameTextField;
	NSArray				*fields;
	NSString			*path, *transferred, *size, *speed;
	NSScanner			*scanner;
	off_t				transferred_l, size_l;
	
	// --- split fields
	fields		= [argument componentsSeparatedByString:WCRecordSeparator];
	path		= [fields objectAtIndex:0];
	transferred	= [fields objectAtIndex:1];
	size		= [fields objectAtIndex:2];
	speed		= [fields objectAtIndex:3];

	// --- get sizes
	scanner = [NSScanner scannerWithString:transferred];
	[scanner scanLongLong:&transferred_l];

	scanner = [NSScanner scannerWithString:size];
	[scanner scanLongLong:&size_l];
	
	// --- set up status text field
	statusTextField = [[NSTextField alloc] init];
	[statusTextField setEditable:NO];
	[statusTextField setDrawsBackground:NO];
	[statusTextField setBordered:NO];
	[statusTextField setSelectable:YES];
	[statusTextField setFont:[NSFont systemFontOfSize:10.0]];
	[statusTextField setStringValue:[NSString stringWithFormat:
		@"%@ of %@, %@/s",
		[[NSNumber numberWithUnsignedLongLong:transferred_l] humanReadableSize],
		[[NSNumber numberWithUnsignedLongLong:size_l] humanReadableSize],
		[[NSNumber numberWithInt:[speed intValue]] humanReadableSize]]];
	[statusTextField setFrame:NSMakeRect(87, *last + 14, 193, 14)];
	*last += 18;
	[[[self window] contentView] addSubview:statusTextField];

	// --- set up progress indicator
	progressIndicator = [[NSProgressIndicator alloc] init];
	[progressIndicator setControlSize:NSSmallControlSize];
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setMaxValue:1.0];
	[progressIndicator setDoubleValue:[transferred doubleValue] / [size doubleValue]];
	[progressIndicator setFrame:NSMakeRect(89, *last + 12, 193, 12)];
	*last += 10;
	[[[self window] contentView] addSubview:progressIndicator];
	
	// --- set up name text field
	nameTextField = [[NSTextField alloc] init];
	[nameTextField setEditable:NO];
	[nameTextField setDrawsBackground:NO];
	[nameTextField setBordered:NO];
	[nameTextField setSelectable:YES];
	[nameTextField setFont:[NSFont systemFontOfSize:11.0]];
	[nameTextField setStringValue:[path lastPathComponent]];
	[nameTextField setFrame:NSMakeRect(87, *last + 14, 193, 14)];
	[nameTextField setFrameForString:[nameTextField stringValue] 
						 withControl:NULL
							  offset:last];
	[[[self window] contentView] addSubview:nameTextField];
	
	[statusTextField release];
	[progressIndicator release];
	[nameTextField release];
}

@end
