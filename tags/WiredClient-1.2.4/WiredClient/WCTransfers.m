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

#import "NSDataAdditions.h"
#import "NSFileManagerAdditions.h"
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "NSThreadAdditions.h"
#import "WCCache.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCPreview.h"
#import "WCSecureSocket.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCSettings.h"
#import "WCStats.h"
#import "WCTableView.h"
#import "WCTransfer.h"
#import "WCTransferCell.h"
#import "WCTransfers.h"

@implementation WCTransfers

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Transfers"];
	
	// --- get parameters
	_connection		= [connection retain];
	
	// --- init our array of transfers
	_transfers		= [[NSMutableArray alloc] init];
	
	// --- init lock
	_lock			= [[NSLock alloc] init];
	
	// --- get the folder icon
	_folderImage	= [[NSImage imageNamed:@"Folder"] retain];
	_lockedImage	= [[NSImage imageNamed:@"Locked"] retain];
	_unlockedImage	= [[NSImage imageNamed:@"Unlocked"] retain];

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
		   selector:@selector(connectionServerInfoDidChange:)
			   name:WCConnectionServerInfoDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(connectionShouldTerminate:)
			   name:WCConnectionShouldTerminate
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(transfersShouldStartTransfer:)
			   name:WCTransfersShouldStartTransfer
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(transfersShouldUpdateQueue:)
			   name:WCTransfersShouldUpdateQueue
			 object:NULL];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(fileInfoShouldShowInfo:)
			   name:WCFileInfoShouldShowInfo
			 object:NULL];
	
	// --- update table view
	_timer = [NSTimer scheduledTimerWithTimeInterval:0.33
					  target:self
					  selector:@selector(updateTimer:)
					  userInfo:NULL
					  repeats:YES];
	[_timer retain];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_lock release];
	[_timer release];

	[_folderImage release];
	[_lockedImage release];
	[_unlockedImage release];

	[_transfers release];
	[_connection release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSImageCell		*imageCell;
	WCTransferCell	*transferCell;
	
	// --- set up the icon column for images
	imageCell = [[NSImageCell alloc] init];
	[_iconTableColumn setDataCell:imageCell];
	[imageCell release];
	
	// --- set up our custom cell type for the transfer text
	transferCell = [[WCTransferCell alloc] init];
	[_infoTableColumn setDataCell:transferCell];
	[transferCell release];
	
	// --- set key actions
	[_transfersTableView setDoubleAction:@selector(start:)];
	[_transfersTableView setEscapeAction:@selector(stop:)];
	[_transfersTableView setDeleteAction:@selector(remove:)];
	

	// --- we're doing drag'n'drop
	[_transfersTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]];

	// --- set window positions
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Transfers"];

	// --- set up windows from preferences
	[self update];
	[self updateButtons];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
		
	// --- show window
	if([WCSettings boolForKey:WCShowTransfers])
		[self showWindow:self];
}



- (void)connectionServerInfoDidChange:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
	
	// --- window title
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Transfers", @"Transfers window title")]];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	if([notification object] != _connection)
		return;
	
	// --- clear running transfers
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer state] == WCTransferStateRunning)
			[transfer setState:WCTransferStateStopping];
	}

	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				   forKey:WCShowTransfers];

	[_transfersTableView setDataSource:NULL];
	[_timer invalidate];

	[self close];
	[self release];
}



- (BOOL)connectionShouldHandleError:(int)error {
	WCTransfer		*transfer;
	
	// --- ignore errors while recursively uploading
	if(_recursiveUpload)
		return YES;
	
	if(error == 520 || error == 521 || error == 522 || error == 523) {
		// --- remove from listing
		[_transfers removeObject:_transfer];
		[_transfersTableView reloadData];
		_transfer = NULL;
	
		// --- find a locally queued transfer
		transfer = [self transferWithState:WCTransferStateLocallyQueued];

		// --- start it
		if(transfer)
			[self request:transfer];
	}
	
	return NO;
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
	[self updateButtons];
}



- (void)transfersShouldStartTransfer:(NSNotification *)notification {
	NSArray				*fields;
	NSString			*argument, *offset, *hash, *path;
	WCConnection		*connection;
	WCTransfer			*transfer;
	
	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- separate the fields
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	path		= [fields objectAtIndex:0];
	offset		= [fields objectAtIndex:1];
	hash		= [fields objectAtIndex:2];
	
	// --- otherwise loop over all transfers and see if one contains this path
	transfer	= [self transferWithPath:path];
	
	if(!transfer)
		return;
	
	// --- set values
	[[transfer file] setOffset:[offset unsignedLongLongValue]];
	[transfer setOffset:[transfer offset] + [[transfer file] offset]];
	[transfer setHash:hash];
	
	if([[transfer file] transferred] == 0) {
		[[transfer file] setTransferred:[[transfer file] offset]];
		[transfer setTransferred:[[transfer file] offset] + [transfer transferred]];
	}

	// --- fork a thread
	if([transfer type] == WCTransferTypeDownload)
		[NSThread detachNewThreadSelector:@selector(downloadThread:) toTarget:self withObject:transfer];
	else
		[NSThread detachNewThreadSelector:@selector(uploadThread:) toTarget:self withObject:transfer];
	
	// --- play sound
	if([(NSString *) [WCSettings objectForKey:WCTransferStartedEventSound] length] > 0)
		[[NSSound soundNamed:[WCSettings objectForKey:WCTransferStartedEventSound]] play];
}



- (void)transfersShouldUpdateQueue:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*argument, *queue, *path;
	WCConnection	*connection;
	WCTransfer		*transfer;

	// --- get parameters
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get checksum
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	path		= [fields objectAtIndex:0];
	queue		= [fields objectAtIndex:1];
	
	// --- get transfer
	transfer	= [self transferWithPath:path];

	if(!transfer)
		return;
	
	// --- update queue position
	[transfer setState:WCTransferStateQueued];
	[transfer setQueue:[queue unsignedIntValue]];
	
	// --- reload table
	[_transfersTableView setNeedsDisplay:YES];
}



- (void)fileInfoShouldShowInfo:(NSNotification *)notification {
	NSFileHandle		*fileHandle;
	NSData				*data;
	NSArray				*fields;
	NSString			*argument, *path, *size, *checksum;
	WCConnection		*connection;
	WCTransfer			*transfer;
	unsigned long long	offset = 0;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get checksum
	fields		= [argument componentsSeparatedByString:WCFieldSeparator];
	path		= [fields objectAtIndex:0];
	size		= [fields objectAtIndex:2];
	checksum	= [fields objectAtIndex:5];
	
	// --- get transfer
	transfer	= [self transferWithPath:path];
	
	if(!transfer)
		return;
	
	// --- update transfer
	[[transfer file] setSize:[size unsignedLongLongValue]];
	
	// --- open local file
	fileHandle = [NSFileHandle fileHandleForReadingAtPath:[transfer path]];
	
	if(!fileHandle) {
		// --- create empty file if it doesn't exist
		if(![NSFileManager createFileAtPath:[transfer path]]) {
			[[_connection error] setError:WCApplicationErrorCreateFailed];
			[[_connection error] raiseErrorWithArgument:[transfer path]];
			
			return;
		}
	} else {
		// --- get checksum of first megabyte
		data = [fileHandle readDataOfLength:WCChecksumLength];
		[fileHandle closeFile];
		
		if([data length] >= WCChecksumLength) {
			if(![checksum isEqualToString:[data SHA1]]) {
				// --- raise an error
				[[_connection error] setError:WCApplicationErrorChecksumMismatch];
				[[_connection error] raiseErrorWithArgument:[[transfer file] path]];
	
				// --- delete from queue
				[_transfers removeObject:transfer];
	
				// --- reload
				[_transfersTableView reloadData];
				[self updateButtons];
				
				return;
			}
		}
	
		// --- get offset
		offset = [NSFileManager fileSizeAtPath:[transfer path]];
	}
	
	// --- request transfer information
	[_connection sendCommand:WCGetCommand
				withArgument:[[transfer file] path]
				withArgument:[NSString stringWithFormat:@"%llu", offset]
				  withSender:self];
}



- (void)downloadShouldAddFile:(NSNotification *)notification {
	NSString			*argument, *size, *type, *path, *root, *localPath;
	NSArray				*fields;
	WCFile				*file;
	WCConnection		*connection;
	
	if(!_recursiveDownload)
		return;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;

	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	path	= [fields objectAtIndex:0];
	type	= [fields objectAtIndex:1];
	size	= [fields objectAtIndex:2];

	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:[size unsignedLongLongValue]];
	[file setPath:path];
	
	// --- get the local path
	root = [[_recursiveDownload root] stringByDeletingLastPathComponent];
	localPath = [[_recursiveDownload destination] stringByAppendingPathComponent:
		[path substringFromIndex:[root length]]];

	if([file type] == WCFileTypeFile) {
		// --- add the file
		if(![_recursiveDownload containsPairWithPath:path]) {
			[_recursiveDownload setSize:[_recursiveDownload size] + [file size]];

			if([NSFileManager fileExistsAtPath:localPath]) {
				[_recursiveDownload setTransferred:[_recursiveDownload transferred] + [file size]];
			} else {
				[_recursiveDownload addFile:file];
				[_recursiveDownload addPath:[localPath 
					stringByAppendingPathExtension:@"WiredTransfer"]];
			}
		}
	} else {
		// --- create local directory
		[NSFileManager createDirectoryAtPath:localPath];
		
		// --- add to list of folders
		[_recursiveDownload addFolder:[file path]];
	}
		
	[file release];
}



- (void)downloadShouldCompleteFiles:(NSNotification *)notification {
	WCConnection	*connection;
	WCTransfer		*transfer;
	NSString		*path;
	
	if(!_recursiveDownload)
		return;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	
	if(connection != _connection)
		return;
	
	// --- are there more folders that need to be listed
	if([_recursiveDownload folderCount] > 0) {
		// --- shift the first path
		path = [[_recursiveDownload folder] retain];
		[_recursiveDownload shiftFolders];
		
		// --- list that folder and get back here later
		[_connection sendCommand:WCListCommand withArgument:path withSender:self];

		// --- release
		[path release];
	} else {
		// --- stop receiving these notifications
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:WCFilesShouldAddFile
					object:NULL];
		
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:WCFilesShouldCompleteFiles
					object:NULL];
		
		if([_recursiveDownload fileCount] == 0) {
			// --- if no files were found, we're done
			[_recursiveDownload setState:WCTransferStateFinished];
			
			// --- remove from listing
			if([WCSettings boolForKey:WCRemoveTransfers])
				[_transfers removeObject:_recursiveDownload];

			[_transfersTableView reloadData];

			// --- find a locally queued transfer and start that
			transfer = [self transferWithState:WCTransferStateLocallyQueued];
			
			if(transfer)
				[self request:transfer];
		} else {
			// --- start requesting transfer information on the first file
			_transfer = _recursiveDownload;
			[_connection sendCommand:WCStatCommand
						withArgument:[[_recursiveDownload file] path]
						  withSender:self];
		}
		
		_recursiveDownload = NULL;
	}
}



- (void)uploadShouldAddFile:(NSNotification *)notification {
	NSString			*argument, *size, *type, *path;
	NSArray				*fields;
	WCFile				*file;
	WCConnection		*connection;
	
	if(!_recursiveUpload)
		return;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	argument	= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- separate the fields
	fields	= [argument componentsSeparatedByString:WCFieldSeparator];
	path	= [fields objectAtIndex:0];
	type	= [fields objectAtIndex:1];
	size	= [fields objectAtIndex:2];
	
	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:[size unsignedLongLongValue]];
	[file setPath:path];
	
	if([file type] == WCFileTypeFile) {
		// --- remove the file
		if([_recursiveUpload containsPairWithPath:path]) {
			[_recursiveUpload setTransferred:[_recursiveUpload transferred] + [file size]];
			[_recursiveUpload removePairWithPath:path];
		}
	} else {
		// --- add to list of folders
		[_recursiveDownload addFolder:[file path]];
	}
	
	[file release];
}



- (void)uploadShouldCompleteFiles:(NSNotification *)notification {
	WCConnection	*connection;
	WCTransfer		*transfer;
	NSString		*path;
	
	if(!_recursiveUpload)
		return;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	
	if(connection != _connection)
		return;
	
	// --- are there more folders that need to be listed
	if([_recursiveDownload folderCount] > 0) {
		// --- shift the first path
		path = [[_recursiveDownload folder] retain];
		[_recursiveDownload shiftFolders];
		
		// --- list that folder and get back here later
		[_connection sendCommand:WCListCommand withArgument:path withSender:self];
		
		// --- release
		[path release];
	} else {
		// --- stop receiving these notifications
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:WCFilesShouldAddFile
					object:NULL];
		
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
					  name:WCFilesShouldCompleteFiles
					object:NULL];
		
		if([_recursiveUpload fileCount] == 0) {
			// --- if no files were found, we're done
			[_recursiveUpload setState:WCTransferStateFinished];
			
			// --- remove from listing
			if([WCSettings boolForKey:WCRemoveTransfers])
				[_transfers removeObject:_recursiveUpload];

			[_transfersTableView reloadData];

			// --- find a locally queued transfer and start that
			transfer = [self transferWithState:WCTransferStateLocallyQueued];
			
			if(transfer)
				[self request:transfer];
		} else {
			// --- start requesting transfer information on the first file
			_transfer = _recursiveUpload;
			[_connection sendCommand:WCPutCommand
						withArgument:[[_recursiveUpload file] path]
						withArgument:[NSString stringWithFormat:@"%llu", [[_recursiveUpload file] size]]
						withArgument:[[_recursiveUpload file] checksum]
						  withSender:self];
		}
		
		_recursiveUpload = NULL;
	}
}



#pragma mark -

- (void)update {
}



- (void)updateTable {
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
}



- (void)updateButtons {
	WCTransfer		*transfer;
	int				row;
	BOOL			optionKey;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0) {
		// --- get keys
		optionKey = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);

		// --- disable
		[_startButton setEnabled:NO];
		[_stopButton setEnabled:NO];
		[_removeButton setEnabled:optionKey];
	} else {
		// --- get transfer
		transfer = [_transfers objectAtIndex:row];
		
		switch([transfer state]) {
			case WCTransferStateLocallyQueued:
			case WCTransferStateStopped:
				[_startButton setEnabled:YES];
				[_stopButton setEnabled:NO];
				break;

			case WCTransferStateRunning:
				[_startButton setEnabled:NO];
				[_stopButton setEnabled:YES];
				break;
			
			case WCTransferStateWaiting:
			case WCTransferStateQueued:
			case WCTransferStateStopping:
			case WCTransferStateRemoving:
			case WCTransferStateFinished:
				[_startButton setEnabled:NO];
				[_stopButton setEnabled:NO];
				break;
		}

		[_removeButton setEnabled:YES];
	}
}



- (void)updateTimer:(NSTimer *)timer {
	if(_running > 0) {
		NSRect  rect;
		int		i, count;
		
		for(i = 0, count = [_transfers count]; i < count; i++) {
			if([(WCTransfer *) [_transfers objectAtIndex:i] state] == WCTransferStateRunning) {
				rect = [_transfersTableView rectOfRow:i];
				[_transfersTableView setNeedsDisplayInRect:rect];
			}
		}
	}
}



#pragma mark -

- (WCTransfer *)transferWithPath:(NSString *)path {
	NSEnumerator		*enumerator;
	WCTransfer			*each, *transfer = NULL;

	enumerator = [_transfers objectEnumerator];

	while((each = [enumerator nextObject])) {
		if([each state] != WCTransferStateFinished &&
		   [each containsPairWithPath:path]) {
			transfer = each;
			
			break;
		}
	}
	
	return transfer;
}



- (WCTransfer *)transferWithState:(WCTransferState)state {
	NSEnumerator		*enumerator;
	WCTransfer			*each, *transfer = NULL;
	
	enumerator = [_transfers objectEnumerator];
	
	while((each = [enumerator nextObject])) {
		if([each state] == state) {
			transfer = each;
			
			break;
		}
	}
	
	return transfer;
}



- (unsigned int)transfersCount {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;
	unsigned int		count = 0;
	
	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer state] != WCTransferStateFinished)
			count++;
	}
	
	return count;
}



- (void)removeTransfer:(WCTransfer *)transfer {
	[_transfers removeObject:transfer];
	[_transfersTableView reloadData];
}



#pragma mark -

- (void)download:(WCFile *)file preview:(BOOL)preview {
	NSString			*destination, *path;
	WCTransfer			*transfer;
	BOOL				isDirectory;
	
	// --- check for existing transfer
	if([self transferWithPath:[file path]]) {
		[[_connection error] setError:WCApplicationErrorTransferExists];
		[[_connection error] raiseErrorWithArgument:[file lastPathComponent]];
		
		return;
	}
	
	// --- get the local path
	if(preview) {
		destination	= @"/tmp";
		path		= [destination stringByAppendingPathComponent:[file lastPathComponent]];
	} else {
		destination	= [WCSettings objectForKey:WCDownloadFolder];
		path		= [destination stringByAppendingPathComponent:[file lastPathComponent]];
	}
	
	// --- check for existing file
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] &&
	   !isDirectory) {
		[[_connection error] setError:WCApplicationErrorFileExists];
		[[_connection error] raiseErrorWithArgument:path];
		
		return;
	}
	
	// --- create a new transfer object and prepare it
	transfer = [[WCTransfer alloc] initWithType:WCTransferTypeDownload];
	[transfer setState:WCTransferStateWaiting];
	[transfer setDestination:destination];
	[transfer setName:[file name]];
	[transfer setURL:[NSURL URLWithString:[NSString stringWithFormat:
		@"wired://%@:%d/",
		[[_connection URL] host],
		[[_connection URL] port]
			? [[[_connection URL] port] intValue] + 1
			: 2001]]];

	if([file type] == WCFileTypeFile) {
		[transfer setIsPreview:preview];
		[transfer setSize:[file size]];

		[transfer addFile:file];
		[transfer addPath:[path stringByAppendingPathExtension:@"WiredTransfer"]];
		
		[file setTransferred:0];
	} else {
		[transfer setIsFolder:YES];
		[transfer setRoot:[file path]];

		[NSFileManager createDirectoryAtPath:path];
	}
	
	// --- add to array
	[_transfers addObject:transfer];
	[_transfersTableView reloadData];
	
	// --- bring window to front
	[self showWindow:self];

	// --- request now or later
	if([self transfersCount] > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferStateLocallyQueued];
	else
		[self request:transfer];

	[transfer release];
}



- (void)upload:(NSString *)path withDestination:(WCFile *)destination {
	NSDirectoryEnumerator   *enumerator;
	NSFileHandle			*fileHandle;
	NSString				*eachPath, *remotePath, *localPath, *serverPath;
	NSString				*checksum;
	WCTransfer				*transfer;
	WCFile					*file;
	unsigned long long		size;
	
	// --- create a new transfer object
	transfer = [[WCTransfer alloc] initWithType:WCTransferTypeUpload];
	[transfer setState:WCTransferStateWaiting];
	[transfer setDestination:[destination path]];
	[transfer setName:[path lastPathComponent]];
	[transfer setURL:[NSURL URLWithString:[NSString stringWithFormat:
		@"wired://%@:%d/",
		[[_connection URL] host],
		[[_connection URL] port]
			? [[[_connection URL] port] intValue] + 1
			: 2001]]];
		
	// --- get remote path
	remotePath = [[destination path] stringByAppendingPathComponent:[path lastPathComponent]];
	
	if([NSFileManager directoryExistsAtPath:path]) {
		// --- set as directory
		[transfer setIsFolder:YES];
		[transfer setRoot:path];

		// --- save this transfer
		_recursiveUpload = _transfer = transfer;
		
		// --- create initial directory on server
		[_connection sendCommand:WCFolderCommand
					withArgument:remotePath
					  withSender:self];
	}
	
	// --- get enumerator
	enumerator = [NSFileManager enumeratorWithFileAtPath:path];
	
	while((eachPath = [enumerator nextObject])) {
		// --- skip invisibles
		if([[eachPath lastPathComponent] hasPrefix:@"."])
			continue;
		
		// --- get full paths
		if([transfer isFolder]) {
			localPath = [[transfer root] stringByAppendingPathComponent:eachPath];
			serverPath = [remotePath stringByAppendingPathComponent:eachPath];
		} else {
			localPath = eachPath;
			serverPath = remotePath;
		}
		
		if(![NSFileManager directoryExistsAtPath:localPath]) {
			// --- open local file
			fileHandle = [NSFileHandle fileHandleForReadingAtPath:localPath];
			
			if(!fileHandle) {
				[[_connection error] setError:WCApplicationErrorFileNotFound];
				[[_connection error] raiseErrorWithArgument:localPath];
				
				continue;
			}
			
			// --- get checksum
			checksum = [[fileHandle readDataOfLength:WCChecksumLength] SHA1];
			
			// --- get size
			size = [NSFileManager fileSizeAtPath:localPath];
			
			// --- create a file representing the remote side
			file = [[WCFile alloc] initWithType:WCFileTypeFile];
			[file setPath:serverPath];
			[file setSize:size];
			[file setChecksum:checksum];
			
			// --- add file
			[transfer setSize:[transfer size] + [file size]];
			[transfer addFile:file];
			[transfer addPath:localPath];
			
			[fileHandle closeFile];
			[file release];
		} else {
			// --- create folder on server
			[_connection sendCommand:WCFolderCommand
						withArgument:serverPath
						  withSender:self];
		}
	}
	
	// --- add to array
	[_transfers addObject:transfer];
	[_transfersTableView reloadData];

	// --- bring window to front
	[self showWindow:self];

	// --- request now or later
	if([self transfersCount] > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferStateLocallyQueued];
	else
		[self request:transfer];

	// --- clean up
	[transfer release];
}



- (void)request:(WCTransfer *)transfer {
	if([transfer type] == WCTransferTypeDownload) {
		if(![transfer isFolder] || [transfer state] == WCTransferStateStopped) {
			// --- request file information on this file
			_transfer = transfer;
			[_connection sendCommand:WCStatCommand
						withArgument:[[transfer file] path]
						  withSender:self];
		} else {
			// --- start receiving file listings
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(downloadShouldAddFile:)
				name:WCFilesShouldAddFile
				object:NULL];
		
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(downloadShouldCompleteFiles:)
				name:WCFilesShouldCompleteFiles
				object:NULL];
		
			// --- save this transfer
			_recursiveDownload = _transfer = transfer;
			
			// --- start a recursive listing
			[_connection sendCommand:WCListCommand
						withArgument:[transfer root]
						  withSender:self];
		}
	} else {
		if(![transfer isFolder] || [transfer state] == WCTransferStateStopped) {
			// --- request file information on this file
			_transfer = transfer;
			NSLog(@"start = %@", _transfer);
			[_connection sendCommand:WCPutCommand
						withArgument:[[transfer file] path]
						withArgument:[NSString stringWithFormat:@"%llu", [[transfer file] size]]
						withArgument:[[transfer file] checksum]
						  withSender:self];
		} else {
			// --- start receiving file listings
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				   selector:@selector(uploadShouldAddFile:)
					   name:WCFilesShouldAddFile
					 object:NULL];
			
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				   selector:@selector(uploadShouldCompleteFiles:)
					   name:WCFilesShouldCompleteFiles
					 object:NULL];
			
			// --- start a recursive listing
			[_connection sendCommand:WCListCommand
						withArgument:[[transfer destination] stringByAppendingPathComponent:
											[[transfer root] lastPathComponent]]
						  withSender:self];
		}
	}
}



- (void)downloadThread:(id)arg {
	NSAutoreleasePool		*pool, *loopPool;
	NSMutableData			*buffer;
	NSFileHandle			*fileHandle = NULL;
	NSString				*ciphers, *path;
	WCTransfer				*transfer;
	WCSecureSocket			*socket = NULL;
	WCPreview				*preview;
	struct timeval			tv;
	double					now, lastSpeed, lastStats;
	unsigned int			speed, maxSpeed;
	int						bytes, speedBytes, statsBytes;
	BOOL					running = YES;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];

	// --- get the transfer
	transfer = (WCTransfer *) arg;
	
	// --- open up a file
	fileHandle = [NSFileHandle fileHandleForWritingAtPath:[transfer path]];
	
	if(!fileHandle) {
		[[_connection error] setError:WCApplicationErrorOpenFailed];
		[[_connection error] raiseErrorWithArgument:[transfer path]];
		
		goto error;
	}
	
	// --- might be resuming
	[fileHandle seekToFileOffset:[[transfer file] offset]];
	
	// --- select ciphers
	if([WCSettings boolForKey:WCEncryptTransfers])
		ciphers = [WCSettings objectForKey:WCSSLTransferCiphers];
	else
		ciphers = [WCSettings objectForKey:WCSSLNullTransferCiphers];
	
	// --- create a socket
	socket = [[WCSecureSocket alloc] initWithConnection:_connection];
	[socket setCiphers:ciphers];
	[socket setLocking:NO];
	[socket setNoDelay:NO];
	
	// --- attempt to connect
	if([socket connectToHost:[[transfer URL] host] port:[[[transfer URL] port] intValue]] < 0) {
		[[_connection error] raiseErrorWithArgument:[[transfer URL] host]];
		
		goto error;
	}
	
	// --- send the identification hash to the server
	[socket write:[[NSString stringWithFormat:@"%@ %@%@",
			WCTransferCommand,
			[transfer hash],
			WCMessageSeparator] 
		dataUsingEncoding:NSUTF8StringEncoding]];

	// --- get current time
	gettimeofday(&tv, NULL);
	now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
	
	// --- set initial values
	lastSpeed = lastStats = now;
	speedBytes = statsBytes = maxSpeed = 0;

	// --- we're now transferring
	[transfer setState:WCTransferStateRunning];
	[transfer setIsSecure:[socket isSecure]];

	// --- reload table
	[self performSelectorOnMainThread:@selector(updateTable)];
	[self performSelectorOnMainThread:@selector(updateButtons)];
	
	// --- protect running
	[_lock lock];
	_running++;
	[_lock unlock];

	while(running) {
		// --- create secondary pool
		loopPool = [[NSAutoreleasePool alloc] init];
		
		// --- create new buffer
		buffer = [[NSMutableData alloc] init];
		
		// --- check state
		if([transfer state] == WCTransferStateStopping ||
		   [transfer state] == WCTransferStateRemoving) {
			// --- break loop
			running = NO;

			goto next;
		} else {
			// --- read data
			bytes = [socket read:buffer];
			
			if(bytes == 0) {
				// --- EOF;
				running = NO;
				
				goto next;
			}

			if(bytes < 0) {
				// --- download failed
				running = NO;

				[[_connection error] setError:WCApplicationErrorTransferFailed];
				[[_connection error] raiseErrorWithArgument:[transfer name]];

				goto next;
			}
		}

		// --- write data
		[fileHandle writeData:buffer];
		
		// --- get current time
		gettimeofday(&tv, NULL);
		now = tv.tv_sec + ((double) tv.tv_usec / 1000000);

		// --- update bytes
		[transfer setTransferred:[transfer transferred] + bytes];
		[[transfer file] setTransferred:[[transfer file] transferred] + bytes];
		speedBytes += bytes;
		statsBytes += bytes;

		// --- update speed
		speed = speedBytes / (now - lastSpeed);
		[transfer setSpeed:speed];
		
		// --- update speed
		if(now - lastSpeed > 30.0) {
			/* update max speed */
			if(speed > maxSpeed)
				maxSpeed = speed;
			
			/* reset */
			speedBytes = 0;
			lastSpeed = now;
		}

		// --- update stats
		if(now - lastStats > 5.0) {
			// --- update stats
			[WCStats setUnsignedLongLong:statsBytes + [WCStats unsignedLongLongForKey:WCStatsDownloaded]
								  forKey:WCStatsDownloaded];

			// --- reset
			statsBytes = 0;
			lastStats = now;
		}
		
next:
		[buffer release];
		[loopPool release];
	}
	
	// --- update stats
	if(statsBytes > 0) {
		[WCStats setUnsignedLongLong:statsBytes + [WCStats unsignedLongLongForKey:WCStatsDownloaded]
							  forKey:WCStatsDownloaded];
	}
	
	if([WCStats unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[WCStats setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	// --- protect running
	[_lock lock];
	_running--;
	[_lock unlock];
	
	// --- close
	[fileHandle closeFile];
	[socket close];

	// --- did this file finish?
	if([[transfer file] transferred] == [[transfer file] size]) {
		// --- get new local path
		path = [[transfer path] stringByDeletingPathExtension];
	
		// --- rename file
		[NSFileManager movePath:[transfer path] toPath:path];
	
		// --- shift transfer
		[transfer shiftFiles];
		[transfer shiftPaths];
		
		// --- was this the last file?
		if([transfer fileCount] == 0) {
			// --- set done
			[transfer setState:WCTransferStateFinished];

			// --- clear transfer if settings say so
			if([WCSettings boolForKey:WCRemoveTransfers])
				[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];
			
			// --- play sound
			if([(NSString *) [WCSettings objectForKey:WCTransferDoneEventSound] length] > 0)
				[[NSSound soundNamed:[WCSettings objectForKey:WCTransferDoneEventSound]] play];

			// --- preview file
			if([transfer isPreview]) {
				preview = [(WCPreview *) [WCPreview alloc] initWithConnection:_connection];
				[preview performSelectorOnMainThread:@selector(showPreview:) withObject:path];
			}

			// --- find the next locally queued transfer
			transfer = [self transferWithState:WCTransferStateLocallyQueued];
			
			if(transfer)
				[self request:transfer];
		} else {
			// --- request transfer information on next file
			_transfer = transfer;
			[_connection sendCommand:WCStatCommand
						withArgument:[[transfer file] path]
						  withSender:self];
		}
	} else {
		// --- mark stopped
		if([transfer state] == WCTransferStateStopping)
			[transfer setState:WCTransferStateStopped];
		else if([transfer state] == WCTransferStateRemoving)
			[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];

		// --- find the next locally queued transfer
		transfer = [self transferWithState:WCTransferStateLocallyQueued];
		
		if(transfer)
			[self request:transfer];
	}
		
	// --- skip error
	goto end;
	
error:
	// --- remove transfer
	[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];
	
end:
	// --- reload table
	[self performSelectorOnMainThread:@selector(updateTable)];
	[self performSelectorOnMainThread:@selector(updateButtons)];

	// --- free
	[socket release];
	[pool release];
}



- (void)uploadThread:(id)arg {
	NSAutoreleasePool		*pool, *loopPool;
	NSData					*buffer;
	NSFileHandle			*fileHandle = NULL;
	NSString				*ciphers;
	WCTransfer				*transfer;
	WCSecureSocket			*socket = NULL;
	struct timeval			tv;
	double					now, lastSpeed, lastStats;
	unsigned int			speed, maxSpeed;
	int						bytes, speedBytes, statsBytes;
	BOOL					running = YES;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];

	// --- get the transfer
	transfer = (WCTransfer *) arg;
	
	// --- open up a file
	fileHandle = [NSFileHandle fileHandleForReadingAtPath:[transfer path]];
	
	if(!fileHandle) {
		[[_connection error] setError:WCApplicationErrorOpenFailed];
		[[_connection error] raiseErrorWithArgument:[transfer path]];
		
		goto error;
	}
	
	// --- might be resuming
	[fileHandle seekToFileOffset:[[transfer file] offset]];
	
	// --- select ciphers
	if([WCSettings boolForKey:WCEncryptTransfers])
		ciphers = [WCSettings objectForKey:WCSSLTransferCiphers];
	else
		ciphers = [WCSettings objectForKey:WCSSLNullTransferCiphers];
	
	// --- create a socket
	socket = [[WCSecureSocket alloc] initWithConnection:_connection];
	[socket setCiphers:ciphers];
	[socket setLocking:NO];
	[socket setNoDelay:NO];
	
	// --- attempt to connect
	if([socket connectToHost:[[transfer URL] host] port:[[[transfer URL] port] intValue]] < 0) {
		[[_connection error] raiseErrorWithArgument:[[transfer URL] host]];
		
		goto error;
	}
	
	// --- send the identification hash to the server
	[socket write:[[NSString stringWithFormat:@"%@ %@%@",
						WCTransferCommand,
						[transfer hash],
						WCMessageSeparator] 
					dataUsingEncoding:NSUTF8StringEncoding]];

	// --- get current time
	gettimeofday(&tv, NULL);
	now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
	
	// --- set initial values
	lastSpeed = lastStats = now;
	speedBytes = statsBytes = maxSpeed = 0;
	
	// --- we're now transferring
	[transfer setState:WCTransferStateRunning];
	[transfer setIsSecure:[socket isSecure]];

	// --- reload table
	[self performSelectorOnMainThread:@selector(updateTable)];
	[self performSelectorOnMainThread:@selector(updateButtons)];
	
	// --- protect running
	[_lock lock];
	_running++;
	[_lock unlock];
	
	while(running) {
		// --- create secondary pool
		loopPool = [[NSAutoreleasePool alloc] init];
		
		// --- check state
		if([transfer state] == WCTransferStateStopping ||
		   [transfer state] == WCTransferStateRemoving) {
			// --- break loop
			running = NO;
			
			goto next;
		} else {
			// --- read data
			buffer = [fileHandle readDataOfLength:8192];
			
			if([buffer length] == 0) {
				// --- EOF;
				running = NO;
				
				goto next;
			}
		}
		
		// --- write data
		bytes = [socket write:buffer];
		
		if(bytes <= 0) {
			running = NO;
			
			if(bytes < 0) {
				// --- download failed
				[[_connection error] setError:WCApplicationErrorTransferFailed];
				[[_connection error] raiseErrorWithArgument:[transfer name]];
			}
			
			goto next;
		}

		// --- get current time
		gettimeofday(&tv, NULL);
		now = tv.tv_sec + ((double) tv.tv_usec / 1000000);
		
		// --- update bytes
		[transfer setTransferred:[transfer transferred] + bytes];
		[[transfer file] setTransferred:[[transfer file] transferred] + bytes];
		speedBytes += bytes;
		statsBytes += bytes;
		
		// --- update speed
		speed = speedBytes / (now - lastSpeed);
		[transfer setSpeed:speed];
		
		// --- update speed
		if(now - lastSpeed > 30.0) {
			/* update max speed */
			if(speed > maxSpeed)
				maxSpeed = speed;
			
			/* reset */
			speedBytes = 0;
			lastSpeed = now;
		}
		
		// --- update stats
		if(now - lastStats > 5.0) {
			// --- update stats
			[WCStats setUnsignedLongLong:statsBytes + [WCStats unsignedLongLongForKey:WCStatsUploaded]
								  forKey:WCStatsUploaded];
			
			// --- reset
			statsBytes = 0;
			lastStats = now;
		}
		
next:
		[loopPool release];
	}
	
	// --- protect running
	[_lock lock];
	_running--;
	[_lock unlock];
	
	// --- close
	[fileHandle closeFile];
	[socket close];
	
	// --- update stats
	if(statsBytes > 0) {
		[WCStats setUnsignedLongLong:statsBytes + [WCStats unsignedLongLongForKey:WCStatsUploaded]
							  forKey:WCStatsUploaded];
	}
	
	if([WCStats unsignedIntForKey:WCStatsMaxUploadSpeed] < maxSpeed)
		[WCStats setUnsignedInt:maxSpeed forKey:WCStatsMaxUploadSpeed];

	// --- did this file finish?
	if([[transfer file] transferred] == [[transfer file] size]) {
		// --- shift transfer
		[transfer shiftFiles];
		[transfer shiftPaths];
		
		// --- was this the last file?
		if([transfer fileCount] == 0) {
			// --- set done
			[transfer setState:WCTransferStateFinished];
			
			// --- clear transfer if settings say so
			if([WCSettings boolForKey:WCRemoveTransfers])
				[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];
			
			// --- play sound
			if([(NSString *) [WCSettings objectForKey:WCTransferDoneEventSound] length] > 0)
				[[NSSound soundNamed:[WCSettings objectForKey:WCTransferDoneEventSound]] play];
			
			// --- find the next locally queued transfer
			transfer = [self transferWithState:WCTransferStateLocallyQueued];
			
			if(transfer)
				[self request:transfer];
		} else {
			// --- request transfer information on next file
			_transfer = transfer;
			[_connection sendCommand:WCPutCommand
						withArgument:[[transfer file] path]
						withArgument:[NSString stringWithFormat:@"%llu", [[transfer file] size]]
						withArgument:[[transfer file] checksum]
						  withSender:self];
		}
	} else {
		// --- mark stopped
		if([transfer state] == WCTransferStateStopping)
			[transfer setState:WCTransferStateStopped];
		else if([transfer state] == WCTransferStateRemoving)
			[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];
		
		// --- find the next locally queued transfer
		transfer = [self transferWithState:WCTransferStateLocallyQueued];
		
		if(transfer)
			[self request:transfer];
	}
	
	// --- skip error
	goto end;
	
error:
	// --- remove transfer
	[self performSelectorOnMainThread:@selector(removeTransfer:) withObject:transfer];
	
end:	
	// --- reload table
	[self performSelectorOnMainThread:@selector(updateTable)];
	[self performSelectorOnMainThread:@selector(updateButtons)];

	// --- free
	[socket release];
	[pool release];
}



#pragma mark -

- (IBAction)start:(id)sender {
	int		row;
	
	// --- obey the button
	if(![_startButton isEnabled])
		return;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- request transfer
	[self request:[_transfers objectAtIndex:row]];
}



- (IBAction)stop:(id)sender {
	WCTransfer		*transfer;
	int				row;
	
	// --- obey the button
	if(![_stopButton isEnabled])
		return;

	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];
	
	// --- let the thread handle deletion
	[transfer setState:WCTransferStateStopping];
	
	// --- update table
	[_transfersTableView setNeedsDisplay:YES];
	[self updateButtons];
}



- (IBAction)remove:(id)sender {
	WCTransfer		*transfer;
	int				row;
	
	// --- obey the button
	if(![_removeButton isEnabled])
		return;

	if([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
		// --- loop over finished transfers
		while((transfer = [self transferWithState:WCTransferStateFinished]))
			[_transfers removeObject:transfer];
		
		// --- reload
		[_transfersTableView reloadData];
		[self updateButtons];
	} else {
		// --- get row
		row = [_transfersTableView selectedRow];
		
		if(row < 0)
			return;
		
		// --- get transfer
		transfer = [_transfers objectAtIndex:row];
		
		switch([transfer state]) {
			case WCTransferStateRunning:
				// --- let the thread handle deletion
				[transfer setState:WCTransferStateRemoving];
				break;
				
			default:
				// --- just remove it
				[_transfers removeObject:transfer];
				
				// --- reload
				[_transfersTableView reloadData];
				[self updateButtons];
				break;
		}
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_transfers count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSString		*extension;
	NSImage			*icon;
	WCTransfer		*transfer;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];

	// --- populate columns
	if(tableColumn == _iconTableColumn) {
		if([transfer isFolder])
			return _folderImage;
		
		extension = [[transfer name] pathExtension];
		icon = [[_connection cache] transferIconForExtension:extension];
		
		if(!icon) {
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
			[icon setSize:NSMakeSize(32.0, 32.0)];
			[[_connection cache] setTransferIcon:icon forExtension:extension];
		}

		return icon;
	}
	else if(tableColumn == _infoTableColumn) {
		if([transfer state] != WCTransferStateRunning) {
			return [NSArray arrayWithObject:transfer];
		} else {
			return [NSArray arrayWithObjects:
				transfer,
				[transfer isSecure]
					? _lockedImage
					: _unlockedImage,
				NULL];
		}
	}

	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}



- (void)tableViewFlagsDidChange:(NSTableView *)tableView {
	[self updateButtons];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	NSString		*string;
	WCTransfer		*transfer;
	int				row;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];
	
	// --- create status string
	string = [NSString stringWithFormat:@"%@ - %@", [transfer name], [transfer status]];
	
	// --- put it on the pasteboard
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:string forType:NSStringPboardType];
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation {
	// --- only accept drops in between rows
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;
	
	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCTransfer		*transfer;
	NSString		*string;
	int				row;
	
	// --- get row
	row = [[items objectAtIndex:0] intValue];
	
	if(row < 0)
		return NO;
	
	// --- get transfers
	transfer = [_transfers objectAtIndex:row];
	
	// --- create status string
	string = [NSString stringWithFormat:@"%@ - %@", [transfer name], [transfer status]];

	// --- put in pasteboard
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]
					   owner:NULL];
	[pasteboard setString:[NSString stringWithFormat:@"%d", row] forType:WCTransferPboardType];
	[pasteboard setString:string forType:NSStringPboardType];
	
	return YES;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	WCTransfer		*transfer;
	int				fromRow, toRow;
	
	// --- get pasteboard
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	if([types containsObject:WCTransferPboardType]) {
		// --- get source row
		fromRow = [[pasteboard stringForType:WCTransferPboardType] intValue];
		
		// --- get destination row
		toRow = row <= fromRow ? row : row - 1;
		
		if(toRow != fromRow) {
			// --- get source transfer
			transfer = [[_transfers objectAtIndex:fromRow] retain];
			
			// --- remove from original position and re-insert at destination
			[_transfers removeObjectAtIndex:fromRow];
			[_transfers insertObject:transfer atIndex:toRow];
			
			// --- done with transfer
			[transfer release];
			
			// --- reload
			[_transfersTableView reloadData];
			
			return YES;
		}
	}
	
	return NO;
}

@end
