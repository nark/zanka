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
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"

@interface WCFileInfo(Private)

+ (NSString *)_stringForFolderCount:(WIFileOffset)count;

- (id)_initFileInfoWithConnection:(WCServerConnection *)connection files:(NSArray *)files;

- (void)_validate;

- (void)_showFileInfo;
- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(CGFloat *)offset;

@end


@implementation WCFileInfo(Private)

+ (NSString *)_stringForFolderCount:(WIFileOffset)count {
	return [NSSWF:
		NSLS(@"%llu %@", @"File info folder size (count, 'item(s)'"),
		count,
		count == 1
			? NSLS(@"item", @"Item singular")
			: NSLS(@"items", @"Item plural")];
}



#pragma mark -

- (id)_initFileInfoWithConnection:(WCServerConnection *)connection files:(NSArray *)files {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	self = [super initWithWindowNibName:@"FileInfo" connection:connection];

	_files = [files retain];
	_info = [[NSMutableArray alloc] init];

	[self setReleasedWhenClosed:YES];
	[self window];

	[[self connection] addObserver:self
						  selector:@selector(fileInfoReceivedFileInfo:)
							  name:WCFileInfoReceivedFileInfo];

	enumerator = [_files objectEnumerator];
	
	while((file = [enumerator nextObject]))
		[[self connection] sendCommand:WCStatCommand withArgument:[file path]];
	
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

- (void)_showFileInfo {
	NSEnumerator	*enumerator;
	WCFile			*file;
	NSRect			rect;
	NSPoint			point;
	CGFloat			offset, height;
	NSUInteger		folders, files;
	WIFileOffset	fileSize, folderSize;
	
	[_fileTextField setEditable:[[[self connection] account] alterFiles]];
	[_kindPopUpButton setEnabled:
		[[self connection] protocol] >= 1.1 && [[[self connection] account] alterFiles]];
	[_commentTextField setEditable:
		[[self connection] protocol] >= 1.1 && [[[self connection] account] alterFiles]];
	
	if([_info count] == 1) {
		offset = 84.0;
		file = [_info objectAtIndex:0];
	
		// --- set fields
		[_iconImageView setImage:[file iconWithWidth:32.0]];
		[_fileTextField setStringValue:[file name]];
		[_kindTextField setStringValue:[file kind]];
		[_kindPopUpButton selectItemWithTag:[file type]];
		[_whereTextField setStringValue:[[file path] stringByDeletingLastPathComponent]];
		[_createdTextField setStringValue:[_dateFormatter stringFromDate:[file creationDate]]];
		[_modifiedTextField setStringValue:[_dateFormatter stringFromDate:[file modificationDate]]];
		[_checksumTextField setStringValue:[file checksum]];
		[_commentTextField setStringValue:[file comment]];
		
		if([file type] == WCFileFile) {
			[_sizeTextField setStringValue:
				[NSString humanReadableStringForSizeInBytes:[file size] withBytes:YES]];
		} else {
			[_sizeTextField setStringValue:
				[[self class] _stringForFolderCount:[file size]]];
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
	} else {
		offset = 22.0;
		
		// --- set fields
		[_iconImageView setImage:[NSImage imageNamed:@"MultipleItems"]];
		
		folders = files = 0;
		fileSize = folderSize = 0;
		enumerator = [_info objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			if([file type] == WCFileFile) {
				files++;
				fileSize += [file size];
			} else {
				folders++;
				folderSize += [file size];
			}
		}
		
		[_fileTextField setStringValue:[[self class] _stringForFolderCount:files + folders]];
		[_fileTextField setEditable:NO];
		[_fileTextField setBordered:NO];
		[_fileTextField setDrawsBackground:NO];
		[_kindTextField setStringValue:[(WCFile *) [_info lastObject] kind]];
		[_whereTextField setStringValue:[[[_info lastObject] path] stringByDeletingLastPathComponent]];
		
		if(files > 0 && folders > 0) {
			 [_sizeTextField setStringValue:[NSSWF:@"%@, %@",
				[[self class] _stringForFolderCount:folderSize],
				[NSString humanReadableStringForSizeInBytes:fileSize withBytes:YES]]];
		}
		else if(files > 0) {
			[_sizeTextField setStringValue:
				[NSString humanReadableStringForSizeInBytes:fileSize withBytes:YES]];
		}
		else if(folders > 0) {
			[_sizeTextField setStringValue:
				[[self class] _stringForFolderCount:folderSize]];
		}
		
		// --- remove fields
		[_createdTextField removeFromSuperviewWithoutNeedingDisplay];
		[_createdTitleTextField removeFromSuperviewWithoutNeedingDisplay];
		[_modifiedTextField removeFromSuperviewWithoutNeedingDisplay];
		[_modifiedTitleTextField removeFromSuperviewWithoutNeedingDisplay];
		[_checksumTextField removeFromSuperviewWithoutNeedingDisplay];
		[_checksumTitleTextField removeFromSuperviewWithoutNeedingDisplay];
		[_commentTextField removeFromSuperviewWithoutNeedingDisplay];
		[_commentTitleTextField removeFromSuperviewWithoutNeedingDisplay];

		// --- resize fields
		[self _resizeTextField:_whereTextField withTextField:_whereTitleTextField atOffset:&offset];
		[self _resizeTextField:_sizeTextField withTextField:_sizeTitleTextField atOffset:&offset];
		
		// --- resize kind
		if(folders == 0) {
			[_kindTextField removeFromSuperviewWithoutNeedingDisplay];
			[_kindTitleTextField removeFromSuperviewWithoutNeedingDisplay];
			[_kindPopUpButton removeFromSuperviewWithoutNeedingDisplay];
		} else {
			offset += 3.0;
			[self _resizeTextField:_kindTextField withTextField:_kindTitleTextField atOffset:&offset];
			point = [_kindTextField frame].origin;
			point.y -= 5.0;
			[_kindPopUpButton setFrameOrigin:point];
			[_kindPopUpButton insertItemWithTitle:NSLS(@"Don't Change", @"File info folder type popup title") atIndex:0];
			[_kindPopUpButton selectItemAtIndex:0];
			[_kindTextField removeFromSuperviewWithoutNeedingDisplay];
		}
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
	height = rect.size.height;
	rect.size.height = offset + 84.0;
	rect.origin.y -= rect.size.height - height;
	[[self window] setFrame:rect display:YES];
	
	[self showWindow:self];
}



- (void)_resizeTextField:(NSTextField *)textField withTextField:(NSTextField *)titleTextField atOffset:(CGFloat *)offset {
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


@implementation WCFileInfo

+ (id)fileInfoWithConnection:(WCServerConnection *)connection file:(WCFile *)file {
	return [[[self alloc] _initFileInfoWithConnection:connection files:[NSArray arrayWithObject:file]] autorelease];
}



+ (id)fileInfoWithConnection:(WCServerConnection *)connection files:(NSArray *)files {
	return [[[self alloc] _initFileInfoWithConnection:connection files:files] autorelease];
}



- (void)dealloc {
	[_files release];
	[_info release];
	[_dateFormatter release];

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
	
	if([_files count] == 1) {
		[[self window] setTitle:[NSSWF:
			NSLS(@"%@ Info", @"File info window title (filename)"), [[_files objectAtIndex:0] name]]];
	} else {
		[[self window] setTitle:
			NSLS(@"Multiple Items Info", @"File info window title for multiple files")];
	}
	
	[self setShouldCascadeWindows:YES];
	[self setShouldSaveWindowFrameOriginOnly:YES];
	[self setWindowFrameAutosaveName:@"FileInfo"];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];

	_fieldFrame = [_kindTextField frame];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	NSEnumerator	*enumerator;
	NSDictionary	*dictionary;
	NSString		*parentPath, *path;
	WCFile			*file;
	BOOL			reload = NO;

	parentPath = [[[_files objectAtIndex:0] path] stringByDeletingLastPathComponent];
	path = NULL;

	if([[self window] isOnScreen] && [[[self connection] account] alterFiles] && [[self connection] isConnected]) {
		// --- compare the existing type with the one in the menu
		enumerator = [_info objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			if([file isFolder] && [_kindPopUpButton tagOfSelectedItem] > 0 &&
			   [file type] != (WCFileType) [_kindPopUpButton tagOfSelectedItem]) {
				if([[self connection] protocol] >= 1.1) {
					[[self connection] sendCommand:WCTypeCommand
									  withArgument:[file path]
									  withArgument:[NSSWF:@"%u", [_kindPopUpButton tagOfSelectedItem]]];
					
					reload = YES;
				}
			}
		}
		
		if([_info count] == 1) {
			file = [_info objectAtIndex:0];
			path = [parentPath stringByAppendingPathComponent:[_fileTextField stringValue]];
			
			// --- compare the existing file name with the one in the text field
			if(![[file name] isEqualToString:[_fileTextField stringValue]]) {
				[[self connection] sendCommand:WCMoveCommand
								  withArgument:[file path]
								  withArgument:path];
				
				reload = YES;
			}
			
			// --- compare the existing comment with the one in the text field
			if(![[file comment] isEqualToString:[_commentTextField stringValue]]) {
				if([[self connection] protocol] >= 1.1) {
					[[self connection] sendCommand:WCCommentCommand
									  withArgument:path
									  withArgument:[_commentTextField stringValue]];
				}
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
	[super connectionWillTerminate:notification];

	[self close];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self _validate];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSControl		*control;
	WCFileType		type;
	
	control = [notification object];
	
	if(control == _fileTextField) {
		type = [WCFile folderTypeForString:[_fileTextField stringValue]];
		
		if(type == WCFileUploads || type == WCFileDropBox)
			[_kindPopUpButton selectItemWithTag:type];
	}
}



- (void)fileInfoReceivedFileInfo:(NSNotification *)notification {
	NSEnumerator	*enumerator;
	WCFile			*file, *eachFile;

	file = [WCFile fileWithInfoArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	enumerator = [_files objectEnumerator];

	while((eachFile = [enumerator nextObject])) {
		if([[file path] isEqualToString:[eachFile path]]) {
			[_info addObject:file];
			
			break;
		}
	}
	
	if([_info count] == [_files count]) {
		[self _showFileInfo];

		[[self connection] removeObserver:self name:WCFileInfoReceivedFileInfo];
	}
}

@end
