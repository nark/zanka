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

#import "NSAlert-WCAdditions.h"
#import "WCCache.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCPreferences.h"
#import "WCPreview.h"
#import "WCServer.h"
#import "WCServerInfo.h"
#import "WCStats.h"
#import "WCTransfer.h"
#import "WCTransferCell.h"
#import "WCTransfers.h"

static inline NSTimeInterval _WCTransfersTimeInterval(void) {
	struct timeval		tv;

	gettimeofday(&tv, NULL);

	return tv.tv_sec + ((double) tv.tv_usec / 1000000.0);
}


@interface WCTransfers(Private)

- (id)_initTransfersWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_reload;
- (void)_validate;

- (void)_presentError:(WCError *)error;

- (WCTransfer *)_selectedTransfer;
- (WCTransfer *)_unfinishedTransferWithPath:(NSString *)path;
- (WCTransfer *)_transferWithState:(WCTransferState)state;
- (WCTransfer *)_transferWithState:(WCTransferState)state type:(WCTransferType)type;
- (NSUInteger)_numberOfWorkingTransfersWithType:(WCTransferType)type;
- (NSString *)_checksumForPath:(NSString *)path;

- (void)_requestNextTransfer;
- (void)_requestTransfer:(WCTransfer *)transfer;
- (void)_requestDownload:(WCTransfer *)transfer first:(BOOL)first;
- (void)_requestUpload:(WCTransfer *)transfer first:(BOOL)first;
- (void)_startTransfer:(WCTransfer *)transfer;
- (void)_finishTransfer:(WCTransfer *)transfer;

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination preview:(BOOL)preview;
- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination;

- (void)_runDownload:(WCTransfer *)transfer;
- (void)_runUpload:(WCTransfer *)transfer;

@end


@implementation WCTransfers(Private)

- (id)_initTransfersWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Transfers"
								   name:NSLS(@"Transfers", @"Transfers window title")
							 connection:connection];

	_transfers		= [[NSMutableArray alloc] init];

	_lock			= [[NSLock alloc] init];

	_folderImage	= [[NSImage imageNamed:@"Folder"] retain];
	_lockedImage	= [[NSImage imageNamed:@"Locked"] retain];
	_unlockedImage	= [[NSImage imageNamed:@"Unlocked"] retain];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[self connection] addObserver:self
						  selector:@selector(transfersReceivedTransferStart:)
							  name:WCTransfersReceivedTransferStart];

	[[self connection] addObserver:self
						  selector:@selector(transfersReceivedQueueUpdate:)
							  name:WCTransfersReceivedQueueUpdate];

	_timer = [NSTimer scheduledTimerWithTimeInterval:0.33
					  target:self
					  selector:@selector(updateTimer:)
					  userInfo:NULL
					  repeats:YES];
	[_timer retain];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_update {
	if([WCSettings boolForKey:WCTransfersShowProgressBar]) {
		[_transfersTableView setRowHeight:46.0];
		[[_infoTableColumn dataCell] setDrawsProgressIndicator:YES];
	} else {
		[_transfersTableView setRowHeight:34.0];
		[[_infoTableColumn dataCell] setDrawsProgressIndicator:NO];
	}
	
	[_transfersTableView setUsesAlternatingRowBackgroundColors:[WCSettings boolForKey:WCTransfersAlternateRows]];

	[_transfersTableView setNeedsDisplay:YES];
}



- (void)_reload {
	[_transfersTableView reloadData];
	[_transfersTableView setNeedsDisplay:YES];
}



- (void)_validate {
	WCTransfer		*transfer;
	NSInteger		row;
	BOOL			optionKey;

	row = [_transfersTableView selectedRow];

	if(row < 0) {
		optionKey = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);

		[_startButton setEnabled:NO];
		[_stopButton setEnabled:NO];
		[_removeButton setEnabled:optionKey];
		[_revealInFinderButton setEnabled:NO];
	} else {
		transfer = [_transfers objectAtIndex:row];

		switch([transfer state]) {
			case WCTransferLocallyQueued:
			case WCTransferStopped:
			case WCTransferDisconnected:
				[_startButton setEnabled:[[self connection] isConnected]];
				[_stopButton setEnabled:NO];
				break;

			case WCTransferRunning:
				[_startButton setEnabled:NO];
				[_stopButton setEnabled:YES];
				break;

			case WCTransferWaiting:
			case WCTransferQueued:
			case WCTransferStopping:
			case WCTransferRemoving:
			case WCTransferFinished:
			case WCTransferListing:
				[_startButton setEnabled:NO];
				[_stopButton setEnabled:NO];
				break;
		}

		[_removeButton setEnabled:YES];
		[_revealInFinderButton setEnabled:([transfer type] == WCTransferDownload && ![transfer isPreview])];
	}
}



#pragma mark -

- (void)_presentError:(WCError *)error {
	if(![[self window] isVisible])
		[self showWindow:self];
	
	[[self connection] triggerEvent:WCEventsError info1:error];

	[[error alert] beginSheetModalForWindow:[self window]];
}



#pragma mark -

- (WCTransfer *)_selectedTransfer {
	NSInteger		row;
	
	row = [_transfersTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_transfers objectAtIndex:row];
}



- (WCTransfer *)_unfinishedTransferWithPath:(NSString *)path {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] != WCTransferFinished) {
			if([transfer isFolder]) {
				if([[transfer virtualPath] isEqualToString:path] ||
				   [path hasPrefix:[[transfer virtualPath] stringByAppendingString:@"/"]])
					return transfer;
			} else {
				if([transfer containsFile:[WCFile fileWithPath:path]])
					return transfer;
			}
		}
	}

	return NULL;
}



- (WCTransfer *)_transferWithState:(WCTransferState)state {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] == state)
			return transfer;
	}

	return NULL;
}



- (WCTransfer *)_transferWithState:(WCTransferState)state type:(WCTransferType)type {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] == state && [transfer type] == type)
			return transfer;
	}

	return NULL;
}



- (NSUInteger)_numberOfWorkingTransfersWithType:(WCTransferType)type {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;
	NSUInteger			count = 0;

	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer type] == type && [transfer isWorking])
			count++;
	}

	return count;
}



- (NSString *)_checksumForPath:(NSString *)path {
	NSFileHandle		*fileHandle;
	
	fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	if(!fileHandle)
		return NULL;
	
	return [[fileHandle readDataOfLength:WCTransfersChecksumLength] SHA1];
}



#pragma mark -

- (void)_requestNextTransfer {
	WCTransfer		*transfer = NULL;
	NSUInteger		downloads, uploads;
	
	if(![WCSettings boolForKey:WCQueueTransfers]) {
		transfer	= [self _transferWithState:WCTransferLocallyQueued];
	} else {
		downloads	= [self _numberOfWorkingTransfersWithType:WCTransferDownload];
		uploads		= [self _numberOfWorkingTransfersWithType:WCTransferUpload];
		
		if(downloads == 0 && uploads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued];
		else if(downloads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued type:WCTransferDownload];
		else if(uploads == 0)
			transfer = [self _transferWithState:WCTransferLocallyQueued type:WCTransferUpload];
		
	}

	if(transfer)
		[self _requestTransfer:transfer];
}



- (void)_requestTransfer:(WCTransfer *)transfer {
	NSString		*path;
	
	if([transfer type] == WCTransferDownload) {
		if(![transfer isFolder] || [transfer state] == WCTransferStopped ||
		   [transfer state] == WCTransferDisconnected) {
			[self _requestDownload:transfer first:YES];
		} else {
			if(_receivingFileLists == 0) {
				[[self connection] addObserver:self
									  selector:@selector(downloadsReceivedFile:)
										  name:WCFilesReceivedFile];
				
				[[self connection] addObserver:self
									  selector:@selector(downloadsCompletedFiles:)
										  name:WCFilesCompletedFiles];
			}
			
			_receivingFileLists++;
			
			[transfer setState:WCTransferListing];
			
			_listing++;
			
			[[self connection] sendCommand:WCListRecursiveCommand withArgument:[transfer folderPath]];
		}
	} else {
		if(![transfer isFolder] || [transfer state] == WCTransferStopped ||
		   [transfer state] == WCTransferDisconnected) {
			[self _requestUpload:transfer first:YES];
		} else {
			if(_receivingFileLists == 0) {
				[[self connection] addObserver:self
									  selector:@selector(uploadsReceivedFile:)
										  name:WCFilesReceivedFile];
				
				[[self connection] addObserver:self
									  selector:@selector(uploadsCompletedFiles:)
										  name:WCFilesCompletedFiles];
			}
				
			_receivingFileLists++;
			
			[transfer setState:WCTransferListing];
			
			path = [[transfer destinationPath] stringByAppendingPathComponent:
				[[transfer folderPath] lastPathComponent]];
			
			[[self connection] sendCommand:WCListRecursiveCommand withArgument:path];
		}
	}
}



- (void)_requestDownload:(WCTransfer *)transfer first:(BOOL)first {
	if(_receivingFileInfo == 0) {
		[[self connection] addObserver:self
							  selector:@selector(fileInfoReceivedFileInfo:)
								  name:WCFileInfoReceivedFileInfo];
	}

	_receivingFileInfo++;
	
	if(first) {
		[transfer setOffsetAtStart:[transfer offset]];
		[transfer setTransferredFilesAtStart:[transfer transferredFiles]];
	}
	
	[transfer setRequestTime:[NSDate timeIntervalSinceReferenceDate]];

	[[self connection] sendCommand:WCStatCommand
					  withArgument:[[transfer firstFile] path]];
}



- (void)_requestUpload:(WCTransfer *)transfer first:(BOOL)first {
	[transfer setRequestTime:[NSDate timeIntervalSinceReferenceDate]];

	if(first) {
		[transfer setOffsetAtStart:[transfer offset]];
		[transfer setTransferredFilesAtStart:[transfer transferredFiles]];
	}

	[[self connection] sendCommand:WCPutCommand
					  withArgument:[[transfer firstFile] path]
					  withArgument:[NSSWF:@"%llu", [[transfer firstFile] size]]
					  withArgument:[self _checksumForPath:[transfer firstPath]]];
}



- (void)_startTransfer:(WCTransfer *)transfer {
	[WNThread detachNewThreadSelector:@selector(transferThread:) toTarget:self withObject:transfer];

	[[self connection] triggerEvent:WCEventsTransferStarted info1:transfer];
}



- (void)_finishTransfer:(WCTransfer *)transfer {
	NSString			*path, *newPath;
	NSDictionary		*dictionary;
	NSTimeInterval		interval;
	WCFile				*file;
	WCPreview			*preview;
	WCError				*error;
	NSUInteger			files;
	BOOL				next = YES;
	
	file = [[transfer firstFile] retain];
	path = [[transfer firstPath] retain];
	
	interval = [NSDate timeIntervalSinceReferenceDate] - [transfer requestTime];
	
	if([transfer averageRequestTime] > 0.0) {
		files = [transfer transferredFiles] - [transfer transferredFilesAtStart];
		[transfer setAverageRequestTime:(([transfer averageRequestTime] * files) + interval) / (files + 1)];
	} else {
		[transfer setAverageRequestTime:interval];
	}
	
	if([file transferred] == [file size]) {
		if([transfer type] == WCTransferDownload) {
			newPath = [path stringByDeletingPathExtension];
			
			[[NSFileManager defaultManager] movePath:path toPath:newPath];
			[transfer setLocalPath:newPath];
		}
		
		[transfer setTransferredFiles:[transfer transferredFiles] + 1];

		[transfer removeFirstFile];
		[transfer removeFirstPath];
		
		if([transfer numberOfFiles] == 0) {
			[transfer setState:WCTransferFinished];
			[[transfer progressIndicator] setDoubleValue:1.0];
			
			_running--;

			if([WCSettings boolForKey:WCRemoveTransfers])
				[_transfers removeObject:transfer];

			[_transfersTableView reloadData];

			[self _validate];

			[[self connection] triggerEvent:WCEventsTransferFinished info1:transfer];
			
			if([transfer type] == WCTransferDownload) {
				if([transfer isPreview]) {
					preview = [WCPreview previewWithConnection:[self connection] path:[path stringByDeletingPathExtension] error:&error];
					
					if(!preview)
						[self _presentError:error];
				}
			} else {
				dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
					[transfer destinationPath],	WCFilePathKey,
					path,						WCFileSelectPathKey,
					NULL];
				
				[[self connection] postNotificationName:WCFilesShouldReload
												 object:[self connection]
											   userInfo:dictionary];
			}
		} else {
			if([transfer type] == WCTransferDownload)
				[self _requestDownload:transfer first:NO];
			else
				[self _requestUpload:transfer first:NO];

			next = NO;
		}
	} else {
		if([transfer state] == WCTransferStopping)
			[transfer setState:WCTransferStopped];
		else if([transfer state] == WCTransferRemoving)
			[_transfers removeObject:transfer];
		
		_running--;

		[_transfersTableView reloadData];
		
		[self _validate];
	}

	if(next)
		[self _requestNextTransfer];
	
	[file release];
	[path release];
}



#pragma mark -

- (BOOL)_downloadFile:(WCFile *)file toFolder:(NSString *)destination preview:(BOOL)preview {
	NSAlert				*alert;
	NSString			*path;
	WIURL				*url;
	WCTransfer			*transfer;
	WCError				*error;
	BOOL				isDirectory;
	NSUInteger			count;

	if([self _unfinishedTransferWithPath:[file path]]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:[file path]];
		[self _presentError:error];
		
		return NO;
	}

	path = [destination stringByAppendingPathComponent:[file name]];
	
	if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
		if(!(isDirectory && [file isFolder])) {
			alert = [NSAlert alertWithMessageText:NSLS(@"File Exists", @"Transfers overwrite alert title")
									defaultButton:NSLS(@"Cancel", @"Transfers overwrite alert button")
								  alternateButton:NSLS(@"Overwrite", @"Transfers overwrite alert button")
									  otherButton:NULL
						informativeTextWithFormat:[NSSWF:NSLS(@"The file \"%@\" already exists. Overwrite?", @"Transfers overwrite alert title"), path]];
			
			if([alert runModal] == NSAlertDefaultReturn)
				return NO;
			
			[[NSFileManager defaultManager] removeFileAtPath:path];
		}
	}

	url = [[[[self connection] URL] copy] autorelease];;
	[url setPort:([url port] > 0) ? [url port] + 1 : WCTransferPort];
	
	transfer = [WCTransfer downloadTransfer];
	[transfer setDestinationPath:destination];
	[transfer setName:[file name]];
	[transfer setURL:url];
	[transfer setPreview:preview];
	
	if([file type] == WCFileFile) {
		[transfer setSize:[file size]];
		[transfer addFile:[[file copy] autorelease]];

		if(![path hasSuffix:WCTransfersFileExtension])
			path = [path stringByAppendingPathExtension:WCTransfersFileExtension];

		[transfer addPath:path];
		[transfer setLocalPath:path];
	} else {
		[transfer setFolder:YES];
		[transfer setFolderPath:[file path]];
		[transfer setLocalPath:path];
		[transfer setVirtualPath:[file path]];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:path];
	}
	
	[_transfers addObject:transfer];
	
	count = [self _numberOfWorkingTransfersWithType:WCTransferDownload];

	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	return YES;
}



- (BOOL)_uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	NSEnumerator		*enumerator;
	NSString			*eachPath, *remotePath, *localPath, *serverPath, *resourceForkPath = NULL;
	WIURL				*url;
	WCTransfer			*transfer;
	WCFile				*file;
	WCError				*error;
	NSUInteger			count;
	BOOL				isDirectory, hasResourceFork;
	
	remotePath = [[destination path] stringByAppendingPathComponent:[path lastPathComponent]];

	if([self _unfinishedTransferWithPath:remotePath]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferExists argument:remotePath];
		[self _presentError:error];
		
		return NO;
	}

	url = [[[[self connection] URL] copy] autorelease];;
	[url setPort:([url port] > 0) ? [url port] + 1 : WCTransferPort];
	
	transfer = [WCTransfer uploadTransfer];
	[transfer setDestinationPath:[destination path]];
	[transfer setName:[path lastPathComponent]];
	[transfer setURL:url];
	
	if([[NSFileManager defaultManager] directoryExistsAtPath:path]) {
		[[self connection] ignoreError:521];
		[[self connection] sendCommand:WCFolderCommand withArgument:remotePath];
		
		[transfer setFolder:YES];
		[transfer setFolderPath:path];
		[transfer setVirtualPath:remotePath];
		
		[transfer setState:WCTransferListing];
		
		_listing++;
	}
	
	enumerator = [[NSFileManager defaultManager] enumeratorWithFileAtPath:path];
	count = 0;

	while((eachPath = [enumerator nextObject])) {
		if([[eachPath lastPathComponent] hasPrefix:@"."])
			continue;

		if([transfer isFolder]) {
			localPath	= [[transfer folderPath] stringByAppendingPathComponent:eachPath];
			serverPath	= [remotePath stringByAppendingPathComponent:eachPath];
		} else {
			localPath	= eachPath;
			serverPath	= remotePath;
		}

		if([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory hasResourceFork:&hasResourceFork]) {
			if(isDirectory) {
				[[self connection] sendCommand:WCFolderCommand withArgument:serverPath];
			} else {
				file = [WCFile fileWithPath:serverPath];
				[file setSize:[[NSFileManager defaultManager] fileSizeAtPath:localPath]];
				
				[transfer setSize:[transfer size] + [file size]];
				[transfer addFile:file];
				[transfer addPath:localPath];
				[transfer setTotalFiles:[transfer totalFiles] + 1];
			}
			
			if(hasResourceFork) {
				resourceForkPath = localPath;
				count++;
			}
		}
	}
	
	if(count > 0 && [WCSettings boolForKey:WCCheckForResourceForks]) {
		if(count == 1)
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferWithResourceFork argument:resourceForkPath];
		else
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferWithResourceFork argument:[NSNumber numberWithInt:count]];
		
		[self _presentError:error];
	}
	
	[_transfers addObject:transfer];
	
	count = [self _numberOfWorkingTransfersWithType:WCTransferUpload];
	
	if(count == 1)
		[self showWindow:self];
	
	if(count > 1 && [WCSettings boolForKey:WCQueueTransfers])
		[transfer setState:WCTransferLocallyQueued];
	else
		[self _requestTransfer:transfer];
	
	[_transfersTableView reloadData];
	
	return YES;
}



#pragma mark -

- (void)_runDownload:(WCTransfer *)transfer {
	NSAutoreleasePool		*pool = NULL;
	NSProgressIndicator		*progressIndicator;
	NSFileHandle			*fileHandle;
	NSString				*path;
	WNAddress				*address;
	WNSocketContext			*context;
	WNSocket				*socket;
	WCFile					*file;
	WCError					*error;
	WCTransferState			state;
	SSL						*ssl;
	NSTimeInterval			time, speedTime, statsTime;
	char					buffer[8192];
	double					percent, speed, maxSpeed;
	NSUInteger				i = 0;
	int						fd, bytes, speedBytes, statsBytes;
	
	progressIndicator = [transfer progressIndicator];
	file = [transfer firstFile];
	path = [transfer firstPath];

	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		if(![[NSFileManager defaultManager] createFileAtPath:path]) {
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientCreateFailed argument:path];
			[self _presentError:error];
			
			return;
		}
	}
	
	fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
	
	if(!fileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
		[self _presentError:error];
		
		return;
	}
	
	[fileHandle seekToEndOfFile];
	
	context = [WNSocketContext socketContextForClient];
	
	if([WCSettings boolForKey:WCEncryptTransfers])
		[context setSSLCiphers:[WCSettings objectForKey:WCSSLTransferCiphers]];
	else
		[context setSSLCiphers:[WCSettings objectForKey:WCSSLNullTransferCiphers]];
	
	address = [WNAddress addressWithString:[[transfer URL] host] error:&error];
	
	if(!address) {
		[self _presentError:error];
		
		return;
	}
	
	[address setPort:[[transfer URL] port]];

	socket = [[[WNSocket alloc] initWithAddress:address type:WNSocketTCP] autorelease];
	[socket setInteractive:NO];
	
	if(![socket connectWithContext:context timeout:30.0 error:&error]) {
		[self _presentError:error];
		
		return;
	}
	
	[socket writeString:[NSSWF:@"%@ %@%@", WCTransferCommand, [transfer hash], WCMessageSeparator]
			   encoding:NSUTF8StringEncoding
				timeout:30.0
				  error:&error];
	
	state = [transfer state];
	
	if(state != WCTransferRunning && state != WCTransferStopping && state != WCTransferRemoving) {
		[transfer setState:WCTransferRunning];
		
		_running++;
		
		[self performSelectorOnMainThread:@selector(_validate)];
	}

	[transfer setSecure:([socket cipherBits] > 0)];
	
	speedTime = statsTime = time = _WCTransfersTimeInterval();
	speedBytes = statsBytes = maxSpeed = 0;
	
	fd = [fileHandle fileDescriptor];
	ssl = [socket SSL];
	
	while(YES) {
		if(!pool)
			pool = [[NSAutoreleasePool alloc] init];
		
		if([transfer state] == WCTransferStopping || [transfer state] == WCTransferRemoving)
			break;

		bytes = SSL_read(ssl, buffer, sizeof(buffer));

		if(bytes <= 0) {
			if(bytes == 0) {
				if(transfer->_transferred < transfer->_size)
					[transfer setState:WCTransferDisconnected];
			} else {
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
				[self _presentError:error];
			}

			break;
		}

		bytes = write(fd, buffer, bytes);

		if(bytes <= 0) {
			if(bytes < 0) {
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
				[self _presentError:error];
			}

			break;
		}

		transfer->_transferred += bytes;
		file->_transferred += bytes;
		speedBytes += bytes;
		statsBytes += bytes;
		percent = transfer->_transferred / (double) transfer->_size;
		
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
		
		time = _WCTransfersTimeInterval();

		speed = speedBytes / (time - speedTime);
		transfer->_speed = speed;

		if(time - speedTime > 30.0) {
			if(speed > maxSpeed)
				maxSpeed = speed;

			speedBytes = 0;
			speedTime = time;
		}

		if(time - statsTime > 10.0) {
			[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

			statsBytes = 0;
			statsTime = time;
		}
		
		if(++i % 100 == 0) {
			[pool release];
			pool = NULL;
		}
	}
	
	[pool release];

	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsDownloaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxDownloadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxDownloadSpeed];
	
	[socket close];
	
	[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
}



- (void)_runUpload:(WCTransfer *)transfer {
	NSAutoreleasePool		*pool = NULL;
	NSProgressIndicator		*progressIndicator;
	NSFileHandle			*fileHandle;
	NSString				*path;
	WNAddress				*address;
	WNSocketContext			*context;
	WNSocket				*socket;
	WCFile					*file;
	WCError					*error;
	WCTransferState			state;
	SSL						*ssl;
	NSTimeInterval			time, speedTime, statsTime;
	char					buffer[8192];
	double					percent, speed, maxSpeed;
	NSUInteger				i = 0;
	int						fd, bytes, speedBytes, statsBytes, err;
	
	progressIndicator = [transfer progressIndicator];
	file = [transfer firstFile];
	path = [transfer firstPath];

	fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	if(!fileHandle) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
		[self _presentError:error];
		
		return;
	}
	
	[fileHandle seekToFileOffset:[file offset]];
	
	context = [WNSocketContext socketContextForClient];
	
	if([WCSettings boolForKey:WCEncryptTransfers])
		[context setSSLCiphers:[WCSettings objectForKey:WCSSLTransferCiphers]];
	else
		[context setSSLCiphers:[WCSettings objectForKey:WCSSLNullTransferCiphers]];
	
	address = [WNAddress addressWithString:[[transfer URL] host] error:&error];
	
	if(!address) {
		[self _presentError:error];
		
		return;
	}
	
	[address setPort:[[transfer URL] port]];

	socket = [[[WNSocket alloc] initWithAddress:address type:WNSocketTCP] autorelease];
	[socket setInteractive:NO];
	
	if(![socket connectWithContext:context timeout:30.0 error:&error]) {
		[self _presentError:error];
		
		return;
	}
	
	[socket writeString:[NSSWF:@"%@ %@%@", WCTransferCommand, [transfer hash], WCMessageSeparator]
			   encoding:NSUTF8StringEncoding
				timeout:30.0
				  error:&error];
	
	state = [transfer state];
	
	if(state != WCTransferRunning && state != WCTransferStopping && state != WCTransferRemoving) {
		[transfer setState:WCTransferRunning];
		
		_running++;

		[self performSelectorOnMainThread:@selector(_validate)];
	}

	[transfer setSecure:([socket cipherBits] > 0)];
	
	speedTime = statsTime = time = _WCTransfersTimeInterval();
	speedBytes = statsBytes = maxSpeed = 0;
	
	fd = [fileHandle fileDescriptor];
	ssl = [socket SSL];
	
	while(YES) {
		if(!pool)
			pool = [[NSAutoreleasePool alloc] init];

		if([transfer state] == WCTransferStopping || [transfer state] == WCTransferRemoving)
			break;

		bytes = read(fd, buffer, sizeof(buffer));

		if(bytes <= 0) {
			if(bytes < 0) {
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
				[self _presentError:error];
			}

			break;
		}

		bytes = SSL_write(ssl, buffer, bytes);

		if(bytes <= 0) {
			err = SSL_get_error(ssl, bytes);

			if(bytes == 0 || err == SSL_ERROR_ZERO_RETURN || (err == SSL_ERROR_SYSCALL && errno == EPIPE)) {
				if(transfer->_transferred < transfer->_size)
					[transfer setState:WCTransferDisconnected];
			} else {
				error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientTransferFailed argument:[transfer name]];
				[self _presentError:error];
			}

			break;
		}

		transfer->_transferred += bytes;
		file->_transferred += bytes;
		speedBytes += bytes;
		statsBytes += bytes;
		percent = transfer->_transferred / (double) transfer->_size;
		
		if(percent == 1.00 || percent - [progressIndicator doubleValue] >= 0.001)
			[progressIndicator setDoubleValue:percent];
		
		time = _WCTransfersTimeInterval();

		speed = speedBytes / (time - speedTime);
		transfer->_speed = speed;

		if(time - speedTime > 30.0) {
			if(speed > maxSpeed)
				maxSpeed = speed;

			speedBytes = 0;
			speedTime = time;
		}

		if(time - statsTime > 10.0) {
			[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsUploaded];

			statsBytes = 0;
			statsTime = time;
		}

		if(++i % 100 == 0) {
			[pool release];
			pool = NULL;
		}
	}

	[pool release];

	if(statsBytes > 0)
		[[WCStats stats] addUnsignedLongLong:statsBytes forKey:WCStatsUploaded];

	if([[WCStats stats] unsignedIntForKey:WCStatsMaxUploadSpeed] < maxSpeed)
		[[WCStats stats] setUnsignedInt:maxSpeed forKey:WCStatsMaxUploadSpeed];
	
	[socket close];
	
	[self performSelectorOnMainThread:@selector(_finishTransfer:) withObject:transfer];
}

@end


@implementation WCTransfers

+ (id)transfersWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initTransfersWithConnection:connection] autorelease];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_lock release];
	[_timer release];

	[_folderImage release];
	[_lockedImage release];
	[_unlockedImage release];

	[_transfers release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSImageCell		*imageCell;
	WCTransferCell	*transferCell;

	imageCell = [[NSImageCell alloc] init];
	[_iconTableColumn setDataCell:imageCell];
	[imageCell release];

	transferCell = [[WCTransferCell alloc] init];
	[_infoTableColumn setDataCell:transferCell];
	[transferCell release];

	[_transfersTableView setDoubleAction:@selector(start:)];
	[_transfersTableView setEscapeAction:@selector(stop:)];
	[_transfersTableView setDeleteAction:@selector(remove:)];

	[_transfersTableView registerForDraggedTypes:
		[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]];

	[self _update];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCTransfersWindow"] restoreSize:YES visibility:![self isHidden]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCTransfersWindow"];
}



- (void)connectionDidClose:(NSNotification *)notification {
	[self _validate];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;
	
	enumerator = [_transfers objectEnumerator];

	while((transfer = [enumerator nextObject])) {
		if([transfer state] == WCTransferListing || [transfer state] == WCTransferRunning)
			[transfer setState:WCTransferStopping];
	}

	[_timer invalidate];

	[self close];
	[self autorelease];
	
	[super connectionWillTerminate:notification];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	WCTransfer			*transfer;

	[self windowTemplate];

	enumerator = [_transfers objectEnumerator];
	
	while((transfer = [enumerator nextObject])) {
		if([transfer state] == WCTransferDisconnected)
			[self _requestTransfer:transfer];
	}
	
	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
		
	[self _validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)transfersReceivedTransferStart:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*offset, *hash, *path;
	WCTransfer		*transfer;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	path		= [fields safeObjectAtIndex:0];
	offset		= [fields safeObjectAtIndex:1];
	hash		= [fields safeObjectAtIndex:2];
	
	transfer	= [self _unfinishedTransferWithPath:path];
	
	if(!transfer)
		return;
	
	[[transfer firstFile] setOffset:[offset unsignedLongLongValue]];
	[transfer setOffset:[transfer offset] + [[transfer firstFile] offset]];
	[transfer setHash:hash];
	
	if([[transfer firstFile] transferred] == 0) {
		[[transfer firstFile] setTransferred:[[transfer firstFile] offset]];
		[transfer setTransferred:[[transfer firstFile] offset] + [transfer transferred]];
	}

	[self _startTransfer:transfer];
}



- (void)transfersReceivedQueueUpdate:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*queue, *path;
	WCTransfer		*transfer;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	path		= [fields safeObjectAtIndex:0];
	queue		= [fields safeObjectAtIndex:1];

	transfer	= [self _unfinishedTransferWithPath:path];

	if(!transfer)
		return;

	[transfer setState:WCTransferQueued];
	[transfer setQueuePosition:[queue unsignedIntValue]];

	[_transfersTableView setNeedsDisplay:YES];
}



- (void)fileInfoReceivedFileInfo:(NSNotification *)notification {
	NSString		*checksum = NULL;
	WCFile			*file;
	WCTransfer		*transfer;
	WCError			*error;
	
	file		= [WCFile fileWithInfoArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	transfer	= [self _unfinishedTransferWithPath:[file path]];
	
	if(!transfer)
		return;
	
	if([[NSFileManager defaultManager] fileSizeAtPath:[transfer firstPath]] >= WCTransfersChecksumLength)
		checksum = [self _checksumForPath:[transfer firstPath]];
	
	if(checksum && ![checksum isEqualToString:[file checksum]]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientChecksumMismatch argument:[transfer firstPath]];
		[self _presentError:error];

		[_transfers removeObject:transfer];
		[_transfersTableView reloadData];
	} else {
		[[transfer firstFile] setSize:[file size]];
		[[transfer firstFile] setOffset:[[NSFileManager defaultManager] fileSizeAtPath:[transfer firstPath]]];

		[[self connection] sendCommand:WCGetCommand
						  withArgument:[[transfer firstFile] path]
						  withArgument:[NSSWF:@"%llu", [[transfer firstFile] offset]]];
	}
	
	if(--_receivingFileInfo == 0)
		[[self connection] removeObserver:self name:WCFileInfoReceivedFileInfo];
}



- (void)downloadsReceivedFile:(NSNotification *)notification {
	NSString		*rootPath, *localPath;
	WCTransfer		*transfer;
	WCFile			*file;
	
	file		= [WCFile fileWithListArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	transfer	= [self _unfinishedTransferWithPath:[file path]];
	
	if(!transfer)
		return;
	
	rootPath = [[transfer folderPath] stringByDeletingLastPathComponent];
	localPath = [[transfer destinationPath] stringByAppendingPathComponent:
		[[file path] substringFromIndex:[rootPath length]]];

	if([file type] == WCFileFile) {
		[transfer setSize:[transfer size] + [file size]];
		[transfer setTotalFiles:[transfer totalFiles] + 1];
		
		if([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
			[transfer setTransferred:[transfer transferred] + [file size]];
			[transfer setTransferredFiles:[transfer transferredFiles] + 1];
		} else {
			[transfer addFile:file];
			
			if(![localPath hasSuffix:WCTransfersFileExtension])
				localPath = [localPath stringByAppendingPathExtension:WCTransfersFileExtension];

			[transfer addPath:localPath];
		}
	} else {
		[[NSFileManager defaultManager] createDirectoryAtPath:localPath];
	}
}



- (void)downloadsCompletedFiles:(NSNotification *)notification {
	NSString		*path, *free;
	NSArray			*fields;
	WCTransfer		*transfer;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	path		= [fields safeObjectAtIndex:0];
	free		= [fields safeObjectAtIndex:1];
	
	transfer	= [self _unfinishedTransferWithPath:path];
	
	if(!transfer)
		return;
	
	_listing--;
	
	if([transfer numberOfFiles] > 0) {
		[self _requestDownload:transfer first:YES];
	} else {
		if([WCSettings boolForKey:WCRemoveTransfers]) {
			[_transfers removeObject:transfer];
		} else {
			[transfer setState:WCTransferFinished];
			[[transfer progressIndicator] setDoubleValue:1.0];
		}

		[_transfersTableView reloadData];

		[self _requestNextTransfer];
	}

	if(--_receivingFileLists == 0) {
		[[self connection] removeObserver:self name:WCFilesReceivedFile];
		[[self connection] removeObserver:self name:WCFilesCompletedFiles];
	}
}



- (void)uploadsReceivedFile:(NSNotification *)notification {
	WCTransfer		*transfer;
	WCFile			*file;
	
	file		= [WCFile fileWithListArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];
	transfer	= [self _unfinishedTransferWithPath:[file path]];
	
	if(!transfer)
		return;
	
	if([file type] == WCFileFile) {
		if([transfer containsFile:file]) {
			[transfer setTransferred:[transfer transferred] + [file size]];
			[transfer setTransferredFiles:[transfer transferredFiles] + 1];
			[transfer removeFile:file];
		}
	}
}



- (void)uploadsCompletedFiles:(NSNotification *)notification {
	NSString		*path, *free;
	NSArray			*fields;
	WCTransfer		*transfer;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	path		= [fields safeObjectAtIndex:0];
	free		= [fields safeObjectAtIndex:1];
	transfer	= [self _unfinishedTransferWithPath:path];
	
	if(!transfer)
		return;
	
	_listing--;
	
	if([transfer numberOfFiles] > 0) {
		[self _requestUpload:transfer first:YES];
	} else {
		if([WCSettings boolForKey:WCRemoveTransfers]) {
			[_transfers removeObject:transfer];
		} else {
			[transfer setState:WCTransferFinished];
			[[transfer progressIndicator] setDoubleValue:1.0];
		}

		[_transfersTableView reloadData];

		[self _requestNextTransfer];
	}
	
	if(--_receivingFileLists == 0) {
		[[self connection] removeObserver:self name:WCFilesReceivedFile];
		[[self connection] removeObserver:self name:WCFilesCompletedFiles];
	}
}



#pragma mark -

- (void)transferThread:(id)arg {
	NSAutoreleasePool		*pool;
	WCTransfer				*transfer = arg;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	if([transfer type] == WCTransferDownload)
		[self _runDownload:transfer];
	else
		[self _runUpload:transfer];
	
	[pool release];
}



- (void)updateTimer:(NSTimer *)timer {
	NSRect				rect;
	WCTransferState		state;
	NSUInteger			i, count;
	
	if(_running > 0 || _listing > 0) {
		count = [_transfers count];
		
		for(i = 0; i < count; i++) {
			state = [(WCTransfer *) [_transfers objectAtIndex:i] state];

			if(state == WCTransferListing || state == WCTransferRunning) {
				rect = [_transfersTableView frameOfCellAtColumn:1 row:i];

				[_transfersTableView setNeedsDisplayInRect:rect];
			}
		}
	}
}



#pragma mark -

- (BOOL)downloadFile:(WCFile *)file {
	return [self _downloadFile:file toFolder:[[WCSettings objectForKey:WCDownloadFolder] stringByStandardizingPath] preview:NO];
}



- (BOOL)downloadFile:(WCFile *)file toFolder:(NSString *)destination {
	return [self _downloadFile:file toFolder:destination preview:NO];
}



- (BOOL)previewFile:(WCFile *)file {
	return [self _downloadFile:file toFolder:NSTemporaryDirectory() preview:YES];
}



- (BOOL)uploadPath:(NSString *)path toFolder:(WCFile *)destination {
	return [self _uploadPath:path toFolder:destination];
}



#pragma mark -

- (IBAction)start:(id)sender {
	if(![_startButton isEnabled])
		return;

	[self _requestTransfer:[self _selectedTransfer]];
}



- (IBAction)stop:(id)sender {
	if(![_stopButton isEnabled])
		return;

	[[self _selectedTransfer] setState:WCTransferStopping];

	[_transfersTableView setNeedsDisplay:YES];

	[self _validate];
}



- (IBAction)remove:(id)sender {
	WCTransfer		*transfer;

	if(![_removeButton isEnabled])
		return;

	if([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) {
		while((transfer = [self _transferWithState:WCTransferFinished]))
			[_transfers removeObject:transfer];

	} else {
		transfer = [self _selectedTransfer];
		
		if([transfer state] == WCTransferRunning)
			[transfer setState:WCTransferRemoving];
		else
			[_transfers removeObject:transfer];
	}

	[_transfersTableView setNeedsDisplay:YES];
	[_transfersTableView reloadData];
	
	[self _validate];
}



- (IBAction)revealInFinder:(id)sender {
    [[NSWorkspace sharedWorkspace] selectFile:[[self _selectedTransfer] localPath] inFileViewerRootedAtPath:NULL];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_transfers count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSImage			*icon;
	WCTransfer		*transfer;

	transfer = [_transfers objectAtIndex:row];

	if(tableColumn == _iconTableColumn) {
		return [transfer icon];
	}
	else if(tableColumn == _infoTableColumn) {
		icon = [transfer isSecure] ? _lockedImage : _unlockedImage;
	
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[transfer name],				WCTransferCellNameKey,
			[transfer status],				WCTransferCellStatusKey,
			icon,							WCTransferCellIconKey,
			[transfer progressIndicator],	WCTransferCellProgressKey,
			NULL];
	}

	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)tableViewFlagsDidChange:(NSTableView *)tableView {
	[self _validate];
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	NSString		*string;
	WCTransfer		*transfer;

	transfer = [self _selectedTransfer];
	
	if(!transfer)
		return;

	string = [NSSWF:@"%@ - %@", [transfer name], [transfer status]];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:string forType:NSStringPboardType];
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCTransfer		*transfer;
	NSString		*string;
	NSInteger		row;

	row = [[items objectAtIndex:0] integerValue];

	if(row < 0)
		return NO;

	transfer = [_transfers objectAtIndex:row];

	string = [NSSWF:@"%@ - %@", [transfer name], [transfer status]];

	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, WCTransferPboardType, NULL]
					   owner:NULL];
	[pasteboard setString:[NSSWF:@"%ld", row] forType:WCTransferPboardType];
	[pasteboard setString:string forType:NSStringPboardType];

	return YES;
}



- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSPasteboard	*pasteboard;
	NSArray			*types;
	NSInteger		fromRow;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];

	if([types containsObject:WCTransferPboardType]) {
		fromRow = [[pasteboard stringForType:WCTransferPboardType] integerValue];
		[_transfers moveObjectAtIndex:fromRow toIndex:row];
		[_transfersTableView reloadData];

		return YES;
	}

	return NO;
}

@end
