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

#import "WCAccount.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"

@interface WCFileInfo(Private)

- (id)_initFileInfoWithConnection:(WCServerConnection *)connection file:(WCFile *)file;

- (void)_validate;

- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(float *)offset;

@end


@implementation WCFileInfo(Private)

- (id)_initFileInfoWithConnection:(WCServerConnection *)connection file:(WCFile *)file {
	self = [super initWithWindowNibName:@"FileInfo" connection:connection];

	_file = [file retain];

	[self setReleasedWhenClosed:YES];
	[self window];

	[[self connection] addObserver:self
						  selector:@selector(fileInfoReceivedFileInfo:)
							  name:WCFileInfoReceivedFileInfo];

	[[self connection] sendCommand:WCStatCommand withArgument:[_file path]];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_validate {
	BOOL		connected;
	
	connected = [[self connection] isConnected];
	
	[_fileTextField setEnabled:connected];
	[_kindPopUpButton setEnabled:connected];
	[_commentTextField setEnabled:connected];
}



#pragma mark -

- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(float *)offset {
	NSSize		size;
	NSPoint		point;
	double		height;
	
	if([[textField stringValue] length] == 0) {
		point = [textField frame].origin;
		[textField setFrameOrigin:NSMakePoint(point.x, -100.0)];

		point = [titleTextField frame].origin;
		[titleTextField setFrameOrigin:NSMakePoint(point.x, -100.0)];
	} else {
		[textField sizeToFitFromContent];
		height = [textField frame].size.height;
		size = [titleTextField frame].size;
		[titleTextField setFrameSize:NSMakeSize(size.width, height)];
		
		point = [textField frame].origin;
		[textField setFrameOrigin:NSMakePoint(point.x, *offset)];
		point = [titleTextField frame].origin;
		[titleTextField setFrameOrigin:NSMakePoint(point.x, *offset)];

		*offset += height + 2.0;
	}
}

@end


@implementation WCFileInfo

+ (id)fileInfoWithConnection:(WCServerConnection *)connection file:(WCFile *)file {
	return [[[self alloc] _initFileInfoWithConnection:connection file:file] autorelease];
}



- (void)dealloc {
	[_file release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator		*enumerator;
	NSMenuItem			*item;
	
	enumerator = [[_kindPopUpButton itemArray] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[item setImage:[WCFile iconForFolderType:[item tag] width:12.0]];

	[self windowTemplate];
	
	[[self window] setTitle:[NSSWF:
		NSLS(@"%@ Info", @"File info window title (filename)"), [_file name]]];
	
	[self setShouldCascadeWindows:YES];
	[self setShouldSaveWindowFrameOriginOnly:YES];
	[self setWindowFrameAutosaveName:@"FileInfo"];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	NSDictionary	*dictionary;
	NSString		*parentPath, *path;
	BOOL			reload = NO;

	parentPath = [[_file path] stringByDeletingLastPathComponent];
	path = [parentPath stringByAppendingPathComponent:[_fileTextField stringValue]];

	if([[self window] isOnScreen] && [[[self connection] account] alterFiles] && [[self connection] isConnected]) {
		// --- compare the existing file name with the one in the text field
		if(![[_file name] isEqualToString:[_fileTextField stringValue]]) {
			[[self connection] sendCommand:WCMoveCommand
							  withArgument:[_file path]
							  withArgument:path];
			
			reload = YES;
		}
		
		// --- compare the existing comment with the one in the text field
		if(![[_file comment] isEqualToString:[_commentTextField stringValue]]) {
			if([[self connection] protocol] >= 1.1) {
				[[self connection] sendCommand:WCCommentCommand
								  withArgument:path
								  withArgument:[_commentTextField stringValue]];
			}
		}

		// --- compare the existing type with the one in the menu
		if([_file isFolder] && [_file type] != (WCFileType) [_kindPopUpButton tagOfSelectedItem]) {
			if([[self connection] protocol] >= 1.1) {
				[[self connection] sendCommand:WCTypeCommand
								  withArgument:path
								  withArgument:[NSSWF:@"%u", [_kindPopUpButton tagOfSelectedItem]]];

				reload = YES;
			}
		}
	}

	if(reload) {
		dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
			parentPath,		WCFilePathKey,
			path,			WCFileSelectPathKey,
			NULL];
		
		[[self connection] postNotificationName:WCFilesShouldReload
										 object:[self connection]
									   userInfo:dictionary];
	}
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[self close];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self _validate];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSControl		*control;
	
	control = [notification object];
	
	if(control == _fileTextField) {
		[_kindPopUpButton selectItemWithTag:
			[WCFile folderTypeForString:[_fileTextField stringValue]]];
	}
}



- (void)fileInfoReceivedFileInfo:(NSNotification *)notification {
	WCFile			*file;
	NSRect			rect;
	NSPoint			point;
	float			offset = 84.0;

	file = [WCFile fileWithInfoArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];

	if(![[file path] isEqualToString:[_file path]])
		return;
	
	[_file release];
	_file = [file retain];

	// --- set fields
	[_iconImageView setImage:[file iconWithWidth:32.0]];
	[_fileTextField setStringValue:[file name]];
	[_kindTextField setStringValue:[file kind]];
	[_kindPopUpButton selectItemWithTag:[file type]];
	[_whereTextField setStringValue:[[file path] stringByDeletingLastPathComponent]];
	[_createdTextField setStringValue:[[file creationDate] commonDateStringWithSeconds:NO]];
	[_modifiedTextField setStringValue:[[file modificationDate] commonDateStringWithSeconds:NO]];
	[_checksumTextField setStringValue:[file checksum]];
	[_commentTextField setStringValue:[file comment]];

	[_fileTextField setEditable:[[[self connection] account] alterFiles]];
	[_kindPopUpButton setEnabled:
		[[self connection] protocol] >= 1.1 && [[[self connection] account] alterFiles]];
	[_commentTextField setEditable:
		[[self connection] protocol] >= 1.1 && [[[self connection] account] alterFiles]];
	
	if([file type] == WCFileFile) {
		[_sizeTextField setStringValue:
			[NSString humanReadableStringWithBytesForSize:[file size]]];
	} else {
		[_sizeTextField setStringValue:[NSSWF:
			NSLS(@"%llu %@", @"File info folder size (count, 'item(s)'"),
			[file size],
			[file size] == 1
				? NSLS(@"item", @"Item singular")
				: NSLS(@"items", @"Item plural")]];
	}

	// --- resize fields
	[self _resizeTextField:_checksumTextField withTextField:_checksumTitleTextField atOffset:&offset];
	[self _resizeTextField:_modifiedTextField withTextField:_modifiedTitleTextField atOffset:&offset];
	[self _resizeTextField:_createdTextField withTextField:_createdTitleTextField atOffset:&offset];
	[self _resizeTextField:_whereTextField withTextField:_whereTitleTextField atOffset:&offset];
	[self _resizeTextField:_sizeTextField withTextField:_sizeTitleTextField atOffset:&offset];
	
	// --- resize kind
	if([file type] == WCFileFile) {
		[self _resizeTextField:_kindTextField withTextField:_kindTitleTextField atOffset:&offset];
		[_kindPopUpButton removeFromSuperviewWithoutNeedingDisplay];
		_kindPopUpButton = NULL;
	} else {
		offset += 3.0;
		[self _resizeTextField:_kindTextField withTextField:_kindTitleTextField atOffset:&offset];
		point = [_kindTextField frame].origin;
		point.y -= 5.0;
		[_kindPopUpButton setFrameOrigin:point];
		[_kindTextField removeFromSuperviewWithoutNeedingDisplay];
		_kindTextField = NULL;
	}

	// --- resize name
	rect = [_fileTextField frame];
	rect.origin.y = offset + 20.0;
	[_fileTextField setFrame:rect];

	// --- resize icon
	rect = [_iconImageView frame];
	rect.origin.y = offset + 12.0;
	[_iconImageView setFrame:rect];

	// --- resize window
	rect = [[self window] frame];
	rect.size.height = offset + 67.0;
	[[self window] setContentSize:rect.size];
	
	[self showWindow:self];

	[[self connection] removeObserver:self name:WCFileInfoReceivedFileInfo];
}

@end
