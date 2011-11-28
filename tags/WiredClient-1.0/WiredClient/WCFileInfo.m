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
#import "NSTextFieldAdditions.h"
#import "NSURLAdditions.h"
#import "WCAccount.h"
#import "WCClient.h"
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
	[[_connection client] sendCommand:[NSString stringWithFormat:
		@"%@ %@", WCStatCommand, [_file path]]];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_connection release];
	[_file release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setTitle:[NSString stringWithFormat:
		NSLocalizedString(@"%@ Info", @"File Info window title (filename)"), [_file name]]];
}



- (void)windowWillClose:(NSNotification *)notification {
	NSString		*oldFileName, *newFileName, *filePath;
	
	oldFileName 	= [[_file path] lastPathComponent];
	newFileName 	= [_fileTextField stringValue];
	filePath		= [[_file path] stringByDeletingLastPathComponent];
	
	// --- compare the existing file name with the one in the text field
	if([[self window] isVisible] && [[_connection account] moveFiles] &&
	   ![oldFileName isEqualToString:newFileName]) {
		// --- send the move command
		[[_connection client] sendCommand:[NSString stringWithFormat:
			@"%@ %@%@%@",
			WCMoveCommand,
			[_file path],
			WCFieldSeparator,
			[filePath stringByAppendingPathComponent:newFileName]]];
	
		// --- reload all files affected
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection, filePath, NULL]];
	}
	
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



- (void)fileInfoShouldShowInfo:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *size, *type, *created, *modified, *checksum, *path;
	NSScanner		*scanner;
	NSImage			*icon = NULL;
	NSRect			rect;
	WCConnection	*connection;
	off_t			size_l;
	int				last = 4;
	
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

	if(![path isEqualToString:[_file path]])
		return;

	// --- get size
	scanner = [NSScanner scannerWithString:size];
	[scanner scanLongLong:&size_l];
	
	// --- set fields
	[_fileTextField setStringValue:[_file name]];
	[_kindTextField setStringValue:[_file kind]];
	[_whereTextField setStringValue:[[_file path] stringByDeletingLastPathComponent]];
	[_createdTextField setStringValue:[[NSDate dateWithISO8601String:created] 
		localizedDateWithFormat:NSShortTimeDateFormatString]];
	[_modifiedTextField setStringValue:[[NSDate dateWithISO8601String:modified] 
		localizedDateWithFormat:NSShortTimeDateFormatString]];
	[_checksumTextField setStringValue:checksum];

	switch([_file type]) {
		case WCFileTypeDirectory:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				size_l,
				size_l == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"Folder"];
			break;
			
		case WCFileTypeUploads:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				size_l,
				size_l == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"Uploads"];
			break;
			
		case WCFileTypeDropBox:
			// --- set subfolder count
			[_sizeTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"%llu %@", @"File info folder size (count, 'item(s)'"),
				size_l,
				size_l == 1
					? NSLocalizedString(@"item", @"Item singular")
					: NSLocalizedString(@"items", @"Item plural")]];
			
			icon = [NSImage imageNamed:@"DropBox"];
			break;
			
		case WCFileTypeFile:
			// --- set file size
			[_sizeTextField setStringValue:[[NSNumber numberWithUnsignedLongLong:size_l] humanReadableSizeWithBytes]];
			
			// --- get file type icon
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:[[_file path] pathExtension]];
			break;
	}
	
	// --- remove checksum
	if([_file type] == WCFileTypeFile) {
		[_checksumTextField setFrameForString:[_checksumTextField stringValue] 
								  withControl:_checksumTitleTextField
									   offset:&last];
	} else {
		[_checksumTextField removeFromSuperview];
		[_checksumTitleTextField removeFromSuperview];
	}
	
	// --- resize
	[_modifiedTextField setFrameForString:[_modifiedTextField stringValue] 
							  withControl:_modifiedTitleTextField
								   offset:&last];
	[_createdTextField setFrameForString:[_createdTextField stringValue] 
							 withControl:_createdTitleTextField
								  offset:&last];
	[_whereTextField setFrameForString:[_whereTextField stringValue]
						   withControl:_whereTitleTextField
								offset:&last];
	[_sizeTextField setFrameForString:[_sizeTextField stringValue]
						  withControl:_sizeTitleTextField
							   offset:&last];
	[_kindTextField setFrameForString:[_kindTextField stringValue]
						  withControl:_kindTitleTextField
							   offset:&last];
	
	// --- scale and set icon
	[icon setSize:NSMakeSize(32.0, 32.0)];
	[_iconImageView setImage:icon];

	// --- resize
	rect = [_fileTextField frame];
	rect.origin.y = last + 30;
	[_fileTextField setFrame:rect];

	rect = [_iconImageView frame];
	rect.origin.y = last + 22;
	[_iconImageView setFrame:rect];
	
	// --- set editable
	[_fileTextField setEditable:[[_connection account] moveFiles]];

	// --- resize and show window
	rect = [[self window] frame];
	rect.size.height = last + 77;
	[[self window] setContentSize:rect.size];
	[[self window] center];
	[self showWindow:self];

	// --- stop receiving this notification
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:WCFileInfoShouldShowInfo
		object:NULL];
}

@end
