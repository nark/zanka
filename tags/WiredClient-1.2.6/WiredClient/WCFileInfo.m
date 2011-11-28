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
#import "NSPopUpButtonAdditions.h"
#import "NSStringAdditions.h"
#import "NSTextFieldAdditions.h"
#import "NSURLAdditions.h"
#import "WCAccount.h"
#import "WCConnection.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCMain.h"
#import "WCServer.h"

@implementation WCFileInfo

- (id)initWithConnection:(WCConnection *)connection file:(WCFile *)file {
	self = [super initWithWindowNibName:@"FileInfo"];
	
	// --- get parameters
	_connection = [connection retain];
	_file = [file retain];

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
		selector:@selector(fileInfoShouldShowInfo:)
		name:WCFileInfoShouldShowInfo
		object:NULL];

	// --- send the stat command
	[_connection sendCommand:WCStatCommand withArgument:[_file path] withSender:self];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connection clearSender:self];
	
	[_connection release];
	[_file release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"%@ Info", @"File Info window title (filename)"), [_file name]]];
	
	// --- window position
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"FileInfo"];
}



- (void)windowWillClose:(NSNotification *)notification {
	NSString	*path;
	BOOL		reload = NO;
	
	path = [[_file path] stringByDeletingLastPathComponent];
	
	// --- compare the existing file name with the one in the text field
	if([[self window] isVisible] &&
	   [[_connection account] alterFiles] &&
	   ![[[_file path] lastPathComponent] isEqualToString:[_fileTextField stringValue]]) {
		// --- send the move command
		[_connection sendCommand:WCMoveCommand
					withArgument:[_file path]
					withArgument:[path stringByAppendingPathComponent:[_fileTextField stringValue]]
					  withSender:self];
	
		reload = YES;
	}
	
	// --- compare the existing comment with the one in the text field
	if([[self window] isVisible] &&
	   [[_connection account] alterFiles] &&
	   [_connection protocol] >= 1.1 &&
	   ![[_file comment] isEqualToString:[_commentTextField stringValue]]) {
		// --- send the comment command
		[_connection sendCommand:WCCommentCommand
					withArgument:[path stringByAppendingPathComponent:[_fileTextField stringValue]]
					withArgument:[_commentTextField stringValue]
					  withSender:self];
	}
	
	// --- compare the existing type with the one in the menu
	if([[self window] isVisible] &&
	   [[_connection account] alterFiles] &&
	   [_connection protocol] >= 1.1 &&
	   [_file type] != WCFileTypeFile &&
	   [_file type] != [_kindPopUpButton tagOfSelectedItem]) {
		// --- send the comment command
		[_connection sendCommand:WCTypeCommand
					withArgument:[path stringByAppendingPathComponent:[_fileTextField stringValue]]
					withArgument:[NSString stringWithFormat:@"%u",
						[_kindPopUpButton tagOfSelectedItem]]
					  withSender:self];
		
		reload = YES;
	}

	// --- reload all files affected
	if(reload) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection,
				path,
				[path stringByAppendingPathComponent:[_fileTextField stringValue]],
				NULL]];
	}
	
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



- (void)fileInfoShouldShowInfo:(NSNotification *)notification {
	NSArray				*fields;
	NSString			*argument, *path, *size, *type, *created, *modified, *checksum, *comment = NULL;
	NSImage				*icon = NULL;
	NSRect				rect;
	NSPoint				point;
	WCConnection		*connection;
	int					last = 82;
	
	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get the fields of the input buffer
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	path		= [fields objectAtIndex:0];
	type		= [fields objectAtIndex:1];
	size		= [fields objectAtIndex:2];
	created		= [fields objectAtIndex:3];
	modified	= [fields objectAtIndex:4];
	checksum	= [fields objectAtIndex:5];
	
	/* protocol 1.1 */
	if([_connection protocol] >= 1.1)
		comment = [fields objectAtIndex:6];

	if(![path isEqualToString:[_file path]])
		return;
	
	// --- stop receiving this notification
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
				  name:WCFileInfoShouldShowInfo
				object:NULL];
	
	// --- set fields
	[_fileTextField setStringValue:[_file name]];
	[_kindTextField setStringValue:[_file kind]];
	[_whereTextField setStringValue:[[_file path] stringByDeletingLastPathComponent]];
	[_createdTextField setStringValue:[[NSDate dateWithISO8601String:created] 
		commonDateStringWithRelative:YES seconds:NO]];
	[_modifiedTextField setStringValue:[[NSDate dateWithISO8601String:modified] 
		commonDateStringWithRelative:YES seconds:NO]];
	[_checksumTextField setStringValue:checksum];

	/* protocol 1.1 */
	if([_connection protocol] >= 1.1) {
		[_file setComment:comment];
		[_commentTextField setStringValue:comment];
	}

	switch([_file type]) {
		case WCFileTypeDirectory:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				[size unsignedLongLongValue],
				[size unsignedLongLongValue] == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"Folder"];
			break;
			
		case WCFileTypeUploads:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				[size unsignedLongLongValue],
				[size unsignedLongLongValue] == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"Uploads"];
			break;
			
		case WCFileTypeDropBox:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				[size unsignedLongLongValue],
				[size unsignedLongLongValue] == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"DropBox"];
			break;
			
		case WCFileTypeFile:
			// --- set file size
			[_sizeTextField setStringValue:
				[NSString humanReadableStringWithBytesForSize:[size unsignedLongLongValue]]];
			
			// --- get file type icon
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:[[_file path] pathExtension]];
			break;
	}
	
	// --- remove checksum
	if([_file type] == WCFileTypeFile) {
		[_checksumTextField setFrameWithControl:_checksumTitleTextField atOffset:&last];
	} else {
		[_checksumTextField removeFromSuperview];
		[_checksumTitleTextField removeFromSuperview];
	}
	
	// --- resize
	[_modifiedTextField setFrameWithControl:_modifiedTitleTextField atOffset:&last];
	[_createdTextField setFrameWithControl:_createdTitleTextField atOffset:&last];
	[_whereTextField setFrameWithControl:_whereTitleTextField atOffset:&last];
	[_sizeTextField setFrameWithControl:_sizeTitleTextField atOffset:&last];
	
	// --- switch kind
	if([_file type] == WCFileTypeFile) {
		[_kindTextField setFrameWithControl:_kindTitleTextField atOffset:&last];
		[_kindPopUpButton removeFromSuperview];
	} else {
		last += 3;
		[_kindTextField setFrameWithControl:_kindTitleTextField atOffset:&last];
		point = [_kindTextField frame].origin;
		point.y -= 5;
		[_kindPopUpButton setFrameOrigin:point];
		[_kindTextField removeFromSuperview];

		[_kindPopUpButton selectItemWithTag:[_file type]];
		[_kindPopUpButton setEnabled:[[_connection account] alterFiles]];
	}
		
	// --- scale and set icon
	[icon setSize:NSMakeSize(32.0, 32.0)];
	[_iconImageView setImage:icon];

	// --- resize
	rect = [_fileTextField frame];
	rect.origin.y = last + 20;
	[_fileTextField setFrame:rect];

	rect = [_iconImageView frame];
	rect.origin.y = last + 12;
	[_iconImageView setFrame:rect];
	
	// --- set editable
	[_fileTextField setEditable:[[_connection account] alterFiles]];
	[_kindPopUpButton setEnabled:
		[_connection protocol] >= 1.1 && [[_connection account] alterFiles]];
	[_commentTextField setEditable:
		[_connection protocol] >= 1.1 && [[_connection account] alterFiles]];

	// --- resize and show window
	rect = [[self window] frame];
	rect.size.height = last + 67;
	[[self window] setContentSize:rect.size];
	[self showWindow:self];
}

@end
