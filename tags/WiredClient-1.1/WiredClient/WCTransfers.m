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

#import <sys/time.h>
#import <unistd.h>
#import "NSDataAdditions.h"
#import "NSNumberAdditions.h"
#import "NSStringAdditions.h"
#import "WCCache.h"
#import "WCClient.h"
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
	
	// --- get the folder icon
	_folderImage	= [[NSImage imageNamed:@"Folder"] retain];

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
					  selector:@selector(updateTable:)
					  userInfo:NULL
					  repeats:YES];
	[_timer retain];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_timer release];

	[_folderImage release];

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

	// --- set window positions
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Transfers"];

	// --- set up windows from preferences
	[self update];
}



- (void)connectionHasAttached:(NSNotification *)notification {
	if([[notification object] objectAtIndex:0] != _connection)
		return;
		
	// --- set titles when host is resolved
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %C %@",
		[_connection name], 0x2014, NSLocalizedString(@"Transfers", @"Transfers window title")]];

	// --- show window
	if([[WCSettings objectForKey:WCShowTransfers] boolValue])
		[self showWindow:self];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] != _connection)
		return;
		
	// --- remember if we were open at the time of disconnecting
	[WCSettings setObject:[NSNumber numberWithBool:[[self window] isVisible]]
				forKey:WCShowTransfers];

	[_transfersTableView setDataSource:NULL];
	[_timer invalidate];

	[self close];
	[self release];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self update];
}



- (void)transfersShouldStartTransfer:(NSNotification *)notification {
	NSArray				*fields;
	NSEnumerator		*enumerator;
	NSString			*argument, *offset, *hash, *path;
	NSScanner			*scanner;
	WCConnection		*connection;
	WCTransfer			*each, *transfer = NULL;
	unsigned long long	offset_l;
	
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
	
	// --- check if it's one of our special file transfers
	if([path hasPrefix:@"/WIRED"]) {
		if([path isEqualToString:@"/WIRED/banner.png"]) {
			WCFile		*file;

			file = [[WCFile alloc] initWithType:WCFileTypeFile];
			[file setPath:path];
			
			transfer = [[WCTransfer alloc] initWithType:WCTransferTypeDownload];
			[transfer addFile:file];
			[transfer addPath:[NSString temporaryPathWithPrefix:@"banner" suffix:@"png"]];
			[transfer setURL:[NSURL URLWithString:[NSString stringWithFormat:@"wiredtransfer://%@:%d",
				[[_connection URL] host],
				[[[_connection URL] port] intValue] == 0
					? 2001
					: [[[_connection URL] port] intValue] + 1]]];
			
			[[NSFileManager defaultManager] createFileAtPath:[transfer path] contents:NULL attributes:NULL];
			
			[file release];
		}
	} else {
		// --- otherwise we need to loop over all transfers and see if one contains this path
		enumerator	= [_transfers objectEnumerator];
		transfer	= NULL;
		
		while((each = [enumerator nextObject])) {
			if([each containsFileWithPath:path]) {
				transfer = each;
				
				break;
			}
		}
	}
	
	if(!transfer)
		return;

	// --- scan size
	scanner = [NSScanner scannerWithString:offset];
	[scanner scanLongLong:&offset_l];
	
	// --- set values
	[transfer setOffset:offset_l];
	[transfer setTransferred:[transfer offset] + [transfer transferred]];
	[transfer setHash:hash];
	
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
	NSEnumerator	*enumerator;
	NSArray			*fields;
	NSString		*argument, *queue, *path;
	WCConnection	*connection;
	WCTransfer		*each, *transfer;

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
	enumerator	= [_transfers objectEnumerator];
	transfer	= NULL;
	
	while((each = [enumerator nextObject])) {
		if([each containsFileWithPath:path]) {
			transfer = each;
			
			break;
		}
	}

	if(!transfer)
		return;
	
	// --- update queue position
	[transfer setState:WCTransferStateQueued];
	[transfer setQueue:(unsigned int) [queue intValue]];
	
	// --- reload table
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
}



- (void)fileInfoShouldShowInfo:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	NSFileHandle		*fileHandle;
	NSData				*data;
	NSArray				*fields;
	NSString			*argument, *checksum, *path;
	WCConnection		*connection;
	WCTransfer			*each, *transfer;
	unsigned long long	size = 0;

	// --- get parameters
	connection		= [[notification object] objectAtIndex:0];
	argument		= [[notification object] objectAtIndex:1];
	
	if(connection != _connection)
		return;
	
	// --- get checksum
	fields			= [argument componentsSeparatedByString:WCFieldSeparator];
	
	if([fields count] != 6)
		return;

	path			= [fields objectAtIndex:0];
	checksum		= [fields objectAtIndex:5];
	
	// --- now we need to loop over all transfers and see if one contains this path
	enumerator		= [_transfers objectEnumerator];
	transfer		= NULL;
	
	while((each = [enumerator nextObject])) {
		if([each containsFileWithPath:path]) {
			transfer = each;
			
			break;
		}
	}
	
	if(!transfer)
		return;
		
	// --- open local file
	fileHandle = [NSFileHandle fileHandleForReadingAtPath:[transfer path]];
	
	if(!fileHandle) {
		// --- create empty file if it doesn't exist
		if(![[NSFileManager defaultManager] createFileAtPath:[transfer path] contents:NULL attributes:NULL]) {
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
				[_transfersTableView setNeedsDisplay:YES];
				[self tableViewSelectionDidChange:NULL];
				
				return;
			}
		}
	
		// --- get size
		size = [[[NSFileManager defaultManager] fileAttributesAtPath:[transfer path] traverseLink:YES] fileSize];
	}
	
	// --- request transfer information
	[[_connection client] sendCommand:WCGetCommand withArgument:[NSString stringWithFormat:
		@"%@%@%llu", [[transfer file] path], WCFieldSeparator, size]];
}



- (void)filesShouldAddFile:(NSNotification *)notification {
	NSString			*argument, *size, *type, *path, *localPath;
	NSArray				*fields;
	NSScanner			*scanner;
	WCFile				*file;
	WCConnection		*connection;
	unsigned long long  size_l;
	
	if(!_recursiveTransfer)
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

	// --- scan size
	scanner = [NSScanner scannerWithString:size];
	[scanner scanLongLong:&size_l];
	
	// --- allocate a new file and fill out the fields
	file = [[WCFile alloc] initWithType:[type intValue]];
	[file setSize:size_l];
	[file setPath:path];
	
	// --- get the local path
	localPath = [[_recursiveTransfer destination] stringByAppendingPathComponent:
					[path substringFromIndex:[[_recursiveTransfer root] length]]];

	if([file type] == WCFileTypeFile) {
		// --- add the file
		if(![_recursiveTransfer containsFileWithPath:path]) {
			[_recursiveTransfer setSize:[_recursiveTransfer size] + [file size]];
			[_recursiveTransfer addFile:file];
			[_recursiveTransfer addPath:[localPath stringByAppendingPathExtension:@"WiredTransfer"]];
		}
	} else {
		// --- create local directory
		[[NSFileManager defaultManager] createDirectoryAtPath:localPath attributes:NULL];
		
		// --- continue to list
		_recursiveLevel++;
		[[_connection client] sendCommand:WCListCommand withArgument:[file path]];
	}
		
	[file release];
}



- (void)filesShouldCompleteFiles:(NSNotification *)notification {
	WCConnection	*connection;
	
	if(!_recursiveTransfer)
		return;
	
	// --- get objects
	connection	= [[notification object] objectAtIndex:0];
	
	if(connection != _connection)
		return;
		
	if(--_recursiveLevel == 0) {
		// --- stop receiving these notifications
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:WCFilesShouldAddFile
			object:NULL];
	
		[[NSNotificationCenter defaultCenter]
			removeObserver:self
			name:WCFilesShouldCompleteFiles
			object:NULL];
	
		// --- the last recursion has finished, start requesting transfer information

		if([_recursiveTransfer fileCount] == 0) {
			[_transfers removeObject:_recursiveTransfer];
		} else {
			[[_connection client] sendCommand:WCStatCommand withArgument:[[_recursiveTransfer file] path]];
		}
		
		_recursiveTransfer = NULL;
	}
}



#pragma mark -

- (void)update {
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
	[self tableViewSelectionDidChange:NULL];
}



- (void)updateButtons {
	WCTransfer		*transfer;
	int				row;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0) {
		// --- disable
		[_startButton setEnabled:NO];
		[_stopButton setEnabled:NO];

		return;
	}
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];
	
	switch([transfer state]) {
		case WCTransferStateLocallyQueued:
			[_stopButton setEnabled:YES];
			[_startButton setEnabled:YES];
			break;

		case WCTransferStateRunning:
		case WCTransferStateWaiting:
		case WCTransferStateQueued:
			[_stopButton setEnabled:YES];
			[_startButton setEnabled:NO];
			break;
	}
}



- (void)updateTable:(NSTimer *)timer {
	if(_running > 0) {
		[_transfersTableView reloadData];
		[_transfersTableView setNeedsDisplay:YES];
	}
}



#pragma mark -

- (void)download:(WCFile *)file preview:(BOOL)preview {
	NSEnumerator			*enumerator;
	NSString				*destination, *path;
	NSProgressIndicator		*progressIndicator;
	WCTransfer				*each, *transfer;
	BOOL					isDir;
	
	// --- check for existing transfer
	enumerator	= [_transfers objectEnumerator];
	transfer	= NULL;
	
	while((each = [enumerator nextObject])) {
		if([each containsFileWithPath:[file path]]) {
			transfer = each;
			
			break;
		}
	}
	
	if(transfer) {
		[[_connection error] setError:WCApplicationErrorTransferExists];
		[[_connection error] raiseErrorWithArgument:[[transfer file] path]];
		
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
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
		[[_connection error] setError:isDir
			? WCApplicationErrorFolderExists
			: WCApplicationErrorFileExists];
		[[_connection error] raiseErrorWithArgument:path];
		
		return;
	}
	
	// --- create a new progress indicator
	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
	[progressIndicator setUsesThreadedAnimation:YES];
	[progressIndicator setMinValue:0.0]; 
	[progressIndicator setMaxValue:1.0];
	
	// --- create a new transfer object and prepare it
	transfer = [[WCTransfer alloc] initWithType:WCTransferTypeDownload];
	[transfer setState:WCTransferStateWaiting];
	[transfer setProgressIndicator:progressIndicator];
	[transfer setProgressInited:NO];
	[transfer setDestination:destination];
	[transfer setName:[file name]];
	[transfer addFile:file];
	[transfer setURL:[NSURL URLWithString:[NSString stringWithFormat:
		@"wiredtransfer://%@:%d",
		[[_connection URL] host],
		[[[_connection URL] port] intValue] == 0
			? 2001
			: [[[_connection URL] port] intValue] + 1]]];
	
	if([file type] == WCFileTypeFile) {
		[transfer setPreview:preview];
		[transfer setSize:[transfer size] + [file size]];
		[transfer addFile:file];
		[transfer addPath:[path stringByAppendingPathExtension:@"WiredTransfer"]];
	} else {
		[transfer setFolder:YES];
		[transfer setRoot:[[file path] stringByDeletingLastPathComponent]];
		[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:NULL];
	}
	
	// --- add to array
	[_transfers addObject:transfer];
	[_transfersTableView reloadData];

	// --- request now or later
	if([[WCSettings objectForKey:WCQueueTransfers] boolValue] && [_transfers count] > 1)
		[transfer setState:WCTransferStateLocallyQueued];
	else
		[self request:transfer];

	[progressIndicator release];
	[transfer release];
}



- (void)upload:(NSString *)path withDestination:(WCFile *)destination {
	NSProgressIndicator	*progressIndicator;
	WCTransfer			*transfer;
	WCFile				*file;
	
	// --- create a new progress indicator
	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
	[progressIndicator setUsesThreadedAnimation:YES];
	[progressIndicator setMinValue:0.0]; 
	[progressIndicator setMaxValue:1.0];
	
	// --- create a new file object
	file = [[WCFile alloc] init];
	[file setPath:path];

	// --- create a new transfer object
	transfer = [[WCTransfer alloc] initWithType:WCTransferTypeUpload];
	[transfer setState:WCTransferStateWaiting];
	[transfer setProgressIndicator:progressIndicator];
	[transfer setProgressInited:NO];
	[transfer setDestination:[destination path]];
	[transfer setName:[path lastPathComponent]];
	[transfer addFile:file];
	[transfer setURL:[NSURL URLWithString:[NSString stringWithFormat:
		@"wiredtransfer://%@:%d",
		[[_connection URL] host],
		[[[_connection URL] port] intValue] == 0
			? 2001
			: [[[_connection URL] port] intValue] + 1]]];
	
	// --- add to array
	[_transfers addObject:transfer];
	[_transfersTableView reloadData];

	// --- request now or later
	if([[WCSettings objectForKey:WCQueueTransfers] boolValue] && [_transfers count] > 1)
		[transfer setState:WCTransferStateLocallyQueued];
	else
		[self request:transfer];

	[progressIndicator release];
	[file release];
	[transfer release];
}



- (void)request:(WCTransfer *)transfer {
	NSString	*path;
	WCFile		*request;
	
	// --- get file
	request = [[transfer file] retain];
	path = [request path];
	[transfer shiftFiles];
	
	if([transfer type] == WCTransferTypeDownload) {
		if([request type] == WCFileTypeFile) {
			// --- request file information on this file
			[[_connection client] sendCommand:WCStatCommand withArgument:path];
		} else {
			// --- start receiving file listings
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(filesShouldAddFile:)
				name:WCFilesShouldAddFile
				object:NULL];
		
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(filesShouldCompleteFiles:)
				name:WCFilesShouldCompleteFiles
				object:NULL];
		
			// --- save this transfer
			_recursiveTransfer = transfer;
			
			// --- start a recursive listing
			_recursiveLevel = 1;
			[[_connection client] sendCommand:WCListCommand withArgument:path];
		}
	} else {
		NSFileManager	*fileManager;
		NSString		*remote;
		BOOL			isDirectory;

		// --- get file manager
		fileManager = [NSFileManager defaultManager];
		remote = [[transfer destination] stringByAppendingPathComponent:[request lastPathComponent]];
		
		if([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
			NSEnumerator	*enumerator;
			NSArray			*subPaths;
			NSString		*subPath, *localPath, *serverPath;
			
			// --- transfer is folder
			[transfer setFolder:YES];
	
			// --- create folder on server
			[[_connection client] sendCommand:WCFolderCommand withArgument:remote];
	
			// --- loop over directory contents
			subPaths	= [fileManager subpathsAtPath:path];
			enumerator	= [subPaths objectEnumerator];
			
			while((subPath = [enumerator nextObject])) {
				// --- full local path
				localPath = [path stringByAppendingPathComponent:subPath];
				
				// --- full server path
				serverPath = [remote stringByAppendingPathComponent:subPath];
				
				// --- skip invisible files
				if([[localPath lastPathComponent] hasPrefix:@"."])
					continue;
			
				if([fileManager fileExistsAtPath:localPath isDirectory:&isDirectory] && isDirectory) {
					// --- create folder on server
					[[_connection client] sendCommand:WCFolderCommand withArgument:serverPath];
				} else {
					NSFileHandle		*fileHandle;
					NSString			*checksum;
					WCFile				*file;
					unsigned long long	size;
					
					// --- open local file
					fileHandle = [NSFileHandle fileHandleForReadingAtPath:localPath];
					
					if(!fileHandle) {
						[[_connection error] setError:WCApplicationErrorFileNotFound];
						[[_connection error] raiseErrorWithArgument:localPath];
				
						return;
					}
				
					// --- get checksum
					checksum = [[fileHandle readDataOfLength:WCChecksumLength] SHA1];
			
					// --- get size
					size = [[fileManager fileAttributesAtPath:localPath traverseLink:YES] fileSize];
					
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
				}
			}
		} else {
			NSFileHandle		*fileHandle;
			NSString			*checksum;
			WCFile				*file;
			unsigned long long	size;
			
			// --- open local file
			fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
			
			if(!fileHandle) {
				[[_connection error] setError:WCApplicationErrorFileNotFound];
				[[_connection error] raiseErrorWithArgument:path];
		
				return;
			}
		
			// --- get checksum
			checksum = [[fileHandle readDataOfLength:WCChecksumLength] SHA1];
	
			// --- get size
			size = [[fileManager fileAttributesAtPath:path traverseLink:YES] fileSize];
			
			// --- create a file representing the remote side
			file = [[WCFile alloc] initWithType:WCFileTypeFile];
			[file setPath:remote];
			[file setSize:size];
			[file setChecksum:checksum];
			
			// --- add file
			[transfer setSize:[transfer size] + [file size]];
			[transfer addFile:file];
			[transfer addPath:path];
			
			[fileHandle closeFile];
			[file release];
		}
		
		if([transfer fileCount] > 0) {
			// --- request first transfer transfer information
			[[_connection client] sendCommand:WCPutCommand withArgument:[NSString stringWithFormat:
				@"%@%@%llu%@%@",
				[[transfer file] path],
				WCFieldSeparator,
				[[transfer file] size],
				WCFieldSeparator,
				[[transfer file] checksum]]];
		} else {
			// --- we're done, delete
			[_transfers removeObject:transfer];
			
			// --- find a locally queued and start it
			if([_transfers count] > 0) {
				NSEnumerator	*enumerator;
				
				enumerator = [_transfers objectEnumerator];
				
				while((transfer = [enumerator nextObject])) {
					if([transfer state] == WCTransferStateLocallyQueued) {
						[self request:transfer];
						
						break;
					}
				}
			}
		}
	}
	
	[request release];
}



- (void)downloadThread:(id)arg {
	NSAutoreleasePool		*pool, *loopPool;
	NSMutableData			*buffer;
	NSFileHandle			*fileHandle;
	WCTransfer				*transfer;
	WCSecureSocket			*socket = NULL;
	struct timeval			now, lastTime;
	BOOL					running = YES;
	long					elapsed;
	unsigned long long		transferred;
	int						bytes = 0, lastBytes = 0, speed, maxSpeed = 0, shiftStatus;
	
	// --- create a pool
	pool = [[NSAutoreleasePool alloc] init];

	// --- get the transfer
	transfer = (WCTransfer *) arg;
	
	// --- open up a file
	fileHandle = [NSFileHandle fileHandleForWritingAtPath:[transfer path]];
	
	if(!fileHandle) {
		[[_connection error] setError:WCApplicationErrorOpenFailed];
		[[_connection error] raiseErrorWithArgument:[transfer path]];
		
		goto end;
	}
	
	// --- create a socket
	socket = [[WCSecureSocket alloc] initWithConnection:_connection type:WCSocketTypeTransfer];
	
	// --- attempt to connect
	if([socket connectToHost:[[transfer URL] host] port:[[[transfer URL] port] intValue]] < 0) {
		if([[_connection client] banner]) {
			[[NSNotificationCenter defaultCenter]
					postNotificationName:WCServerInfoShouldShowBanner
								  object:[NSArray arrayWithObjects:_connection, @"", NULL]];
		} else {
			[[_connection error] raiseErrorWithArgument:[[transfer URL] host]];
		}
		
		goto end;
	}
	
	// --- send the identification hash to the server
	[socket write:[[NSString stringWithFormat:@"%@ %@%@",
			WCTransferCommand,
			[transfer hash],
			WCMessageSeparator] 
		dataUsingEncoding:NSUTF8StringEncoding]];

	// --- we're now transferring
	[transfer setState:WCTransferStateRunning];
	[transfer setSecure:[socket secure]];
	gettimeofday(&lastTime, NULL);
	_running++;
	transferred = [transfer transferred] - [transfer offset];
	
	// --- might be resuming
	[fileHandle seekToFileOffset:[transfer offset]];
	
	while(running) {
		// --- create secondary pool
		loopPool = [[NSAutoreleasePool alloc] init];
		
		// --- create new buffer
		buffer = [[NSMutableData alloc] init];
		
		// --- check state
		if([transfer state] == WCTransferStateStopped) {
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
		
		// --- update stats
		lastBytes += bytes;
		[transfer setTransferred:[transfer transferred] + bytes];
		[transfer setProgress:(double) [transfer transferred] / (double) [transfer size]];
		
		// --- update speed
		gettimeofday(&now, NULL);
		elapsed = (now.tv_sec - lastTime.tv_sec) * 1000 + (now.tv_usec - lastTime.tv_usec) / 1000;
		speed = (double) 1000 * lastBytes / elapsed;
		[transfer setSpeed:speed];

		// --- deltas under this are not reliable
		if(elapsed > 1000) {
			if(speed > maxSpeed)
				maxSpeed = speed;
		}
		if(elapsed > 60000) {
			// --- update time
			gettimeofday(&lastTime, NULL);
		
			// --- update stats
			[WCStats setObject:[NSNumber numberWithUnsignedLongLong:
						[[WCStats objectForKey:WCStatsDownloaded] unsignedLongLongValue] + lastBytes]
					 forKey:WCStatsDownloaded];

			// --- reset counter
			lastBytes = 0;
		}
next:
		[buffer release];
		[loopPool release];
	}
	
	_running--;
	
	// --- close
	[fileHandle closeFile];
	[socket close];
	
	// --- update stats
	[WCStats setObject:[NSNumber numberWithUnsignedLongLong:
				[[WCStats objectForKey:WCStatsDownloaded] unsignedLongLongValue] + lastBytes]
			 forKey:WCStatsDownloaded];
	
	if([[WCStats objectForKey:WCStatsMaxDownloadSpeed] intValue] < maxSpeed)
		[WCStats setObject:[NSNumber numberWithInt:maxSpeed] forKey:WCStatsMaxDownloadSpeed];

	// --- move and preview
	if([transfer transferred] - transferred == [[transfer file] size]) {
		NSString		*path;
		WCPreview		*preview;
		
		path = [[transfer path] stringByDeletingPathExtension];
		
		// --- move file
		[[NSFileManager defaultManager] movePath:[transfer path] toPath:path handler:NULL];

		// --- preview file
		if([transfer preview]) {
			preview = [(WCPreview *) [WCPreview alloc] initWithConnection:_connection];
			[preview performSelectorOnMainThread:@selector(showPreview:) withObject:path waitUntilDone:NO];
		}
	}
	
	// --- announce special files
	if([[[transfer file] path] hasPrefix:@"/WIRED"]) {
		if([[[transfer file] path] isEqualToString:@"/WIRED/banner.png"]) {
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCServerInfoShouldShowBanner
							  object:[NSArray arrayWithObjects:_connection, [transfer path], NULL]];
		}
	}

	// --- shift transfers
	shiftStatus = [transfer shiftFiles];
	shiftStatus = [transfer shiftPaths];
	
	if([transfer state] == WCTransferStateStopped || shiftStatus == 0) {
		// --- stopped or last file downloaded, clear transfer
		[_transfers removeObject:transfer];
		
		// --- play sound
		if([(NSString *) [WCSettings objectForKey:WCTransferDoneEventSound] length] > 0)
			[[NSSound soundNamed:[WCSettings objectForKey:WCTransferDoneEventSound]] play];
		
		// --- find a locally queued and start it
		if([_transfers count] > 0) {
			NSEnumerator	*enumerator;
			
			enumerator = [_transfers objectEnumerator];
		
			while((transfer = [enumerator nextObject])) {
				if([transfer state] == WCTransferStateLocallyQueued) {
					[self request:transfer];
					
					break;
				}
			}
		}
	} else {
		// --- request transfer information on next file
		[[_connection client] sendCommand:WCStatCommand withArgument:[[transfer file] path]];
	}

	// --- reload table
	[self performSelectorOnMainThread:@selector(update) withObject:NULL waitUntilDone:NO];
	
end:	
	// --- free
	[socket release];
	[pool release];
}



- (void)uploadThread:(id)arg {
	NSAutoreleasePool		*pool, *loopPool;
	NSData					*buffer;
	NSFileHandle			*fileHandle;
	WCTransfer				*transfer;
	WCSecureSocket			*socket = NULL;
	struct timeval			now, lastTime;
	BOOL					running = YES;
	long					elapsed;
	int						bytes = 0, lastBytes = 0, speed, maxSpeed = 0, shiftStatus;
	
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
	
	// --- create a socket
	socket = [[WCSecureSocket alloc] initWithConnection:_connection type:WCSocketTypeTransfer];
	
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

	// --- we're now transferring
	[transfer setState:WCTransferStateRunning];
	[transfer setSecure:[socket secure]];
	gettimeofday(&lastTime, NULL);
	_running++;

	// --- might be resuming
	[fileHandle seekToFileOffset:[transfer offset]];
	
	while(running) {
		// --- create secondary pool
		loopPool = [[NSAutoreleasePool alloc] init];
		
		// --- check state
		if([transfer state] == WCTransferStateStopped) {
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
		
		// --- update stats
		lastBytes += bytes;
		[transfer setTransferred:[transfer transferred] + bytes];
		[transfer setProgress:(double) [transfer transferred] / (double) [transfer size]];

		// --- update speed
		gettimeofday(&now, NULL);
		elapsed = (now.tv_sec - lastTime.tv_sec) * 1000 + (now.tv_usec - lastTime.tv_usec) / 1000;
		speed = (double) 1000 * lastBytes / elapsed;
		[transfer setSpeed:speed];
		
		// --- deltas under this are not reliable
		if(elapsed > 1000) {
			if(speed > maxSpeed)
				maxSpeed = speed;
		}
		if(elapsed > 60000) {
			// --- update time
			gettimeofday(&lastTime, NULL);
			
			// --- update stats
			[WCStats setObject:[NSNumber numberWithUnsignedLongLong:
						[[WCStats objectForKey:WCStatsUploaded] unsignedLongLongValue] + lastBytes]
					 forKey:WCStatsUploaded];

			// --- reset counter
			lastBytes = 0;
		}

next:
		[loopPool release];
	}
	
	_running--;
	
	// --- close
	[fileHandle closeFile];
	[socket close];
	
	// --- update stats
	[WCStats setObject:[NSNumber numberWithUnsignedLongLong:
				[[WCStats objectForKey:WCStatsUploaded] unsignedLongLongValue] + lastBytes]
			 forKey:WCStatsUploaded];
	
	if([[WCStats objectForKey:WCStatsMaxUploadSpeed] intValue] < maxSpeed)
		[WCStats setObject:[NSNumber numberWithInt:maxSpeed] forKey:WCStatsMaxUploadSpeed];

	// --- reload all files affected
	if([transfer transferred] == [transfer size]) {
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCFilesShouldReload
			object:[NSArray arrayWithObjects:_connection, [transfer destination], NULL]];
	}

	// --- shift transfers
	shiftStatus = [transfer shiftFiles];
	shiftStatus = [transfer shiftPaths];
	
	if([transfer state] == WCTransferStateStopped || shiftStatus == 0) {
		// --- stopped or last file uploaded, clear transfer
		[_transfers removeObject:transfer];
		
		// --- play sound
		if([(NSString *) [WCSettings objectForKey:WCTransferDoneEventSound] length] > 0)
			[[NSSound soundNamed:[WCSettings objectForKey:WCTransferDoneEventSound]] play];
		
		// --- find a locally queued and start it
		if([_transfers count] > 0) {
			NSEnumerator	*enumerator;
			
			enumerator = [_transfers objectEnumerator];
		
			while((transfer = [enumerator nextObject])) {
				if([transfer state] == WCTransferStateLocallyQueued) {
					[self request:transfer];
					
					break;
				}
			}
		}
	} else {
		// --- request transfer information on next file
		[[_connection client] sendCommand:WCPutCommand withArgument:[NSString stringWithFormat:
			@"%@%@%llu%@%@",
			[[transfer file] path],
			WCFieldSeparator,
			[[transfer file] size],
			WCFieldSeparator,
			[[transfer file] checksum]]];
	}
	
	// --- skip error
	goto end;
	
error:
	// --- remove transfer
	[_transfers removeObject:transfer];
	
end:	
	// --- reload table
	[self performSelectorOnMainThread:@selector(update) withObject:NULL waitUntilDone:NO];

	// --- free
	[socket release];
	[pool release];
}



#pragma mark -

- (IBAction)start:(id)sender {
	WCTransfer		*transfer;
	int				row;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];
	
	// --- update state
	if([transfer state] == WCTransferStateLocallyQueued)
		[self request:transfer];
	
	// --- update table
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
	[self tableViewSelectionDidChange:NULL];
}



- (IBAction)stop:(id)sender {
	WCTransfer		*transfer;
	int				row;
	
	// --- get row
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];
	
	switch([transfer state]) {
		case WCTransferStateRunning:
		case WCTransferStateStopped:
			// --- let the thread handle deletion
			[transfer setState:WCTransferStateStopped];
			break;
		
		default:
			// --- just remove it
			[_transfers removeObject:transfer];

			// --- reload
			[_transfersTableView reloadData];
			[_transfersTableView setNeedsDisplay:YES];
			[self tableViewSelectionDidChange:NULL];
			break;
	}
}



#pragma mark -

- (int)numberOfRowsInTableView:(NSTableView *)sender {
	return [_transfers count];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self updateButtons];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row {
	NSString		*extension;
	NSImage			*icon;
	WCTransfer		*transfer;
	
	// --- get transfer
	transfer = [_transfers objectAtIndex:row];

	// --- populate columns
	if(tableColumn == _iconTableColumn) {
		if([transfer folder])
			return _folderImage;
		
		extension = [[transfer file] pathExtension];
		icon = [[_connection cache] transferIconForExtension:extension];
		
		if(!icon) {
			icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
			[icon setSize:NSMakeSize(32.0, 32.0)];
			[[_connection cache] setTransferIcon:icon forExtension:extension];
		}

		return icon;
	}
	else if(tableColumn == _infoTableColumn) {
		return transfer;
	}
	
	return NULL;
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

@end