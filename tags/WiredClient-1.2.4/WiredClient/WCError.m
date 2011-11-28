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

#import "NSThreadAdditions.h"
#import "WCConnection.h"
#import "WCError.h"

@implementation WCError

- (id)initWithConnection:(WCConnection *)connection {
	self = [super init];
	
	// --- get parameters
	_connection = [connection retain];
	
	// --- create lock
	_lock = [[NSLock alloc] init];
	_error = WCUndefinedError;
	
	// --- subscribe to this
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];
	
	return self;
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_connection release];
	[_lock release];

	[super dealloc];
}



#pragma mark -

- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self release];
}



#pragma mark -

- (void)setError:(int)value {
	[_lock lock];
	_error = value;
	[_lock unlock];
}



- (void)raiseError {
	[self raiseErrorInWindow:NULL withArgument:NULL];
}



- (void)raiseErrorInWindow:(NSWindow *)window {
	[self raiseErrorInWindow:window withArgument:NULL];
}



- (void)raiseErrorWithArgument:(NSString *)argument {
	[self raiseErrorInWindow:NULL withArgument:argument];
}



- (void)raiseErrorInWindow:(NSWindow *)window withArgument:(NSString *)argument {
	NSString	*title = NULL, *description = NULL;
	
	[_lock lock];
	
	switch(_error) {
		case WCNoError:
			return;
			break;
			
		// --- connection errors
		case WCConnectionErrorConnectFailed:
			title = NSLocalizedString(@"Connection Failed", @"Connection failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not connect to \"%@\".", @"Connection failed error dialog description (host)"),
				argument];
			break;
		
		case WCConnectionErrorResolveFailed:
			title = NSLocalizedString(@"Resolve Failed", @"Resolve failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not resolve \"%@\".", @"Resolve failed error dialog description (host)"),
				argument];
			break;
		
		case WCConnectionErrorServerDisconnected:
			title = NSLocalizedString(@"Server Disconnected", @"Server disconnected error dialog title");
			description = NSLocalizedString(@"The server has unexpectedly disconnected.", @"Server disconnected error dialog description");
			break;

		case WCConnectionErrorReadFailed:
			title = NSLocalizedString(@"Read Error", @"Read error dialog title");
			description = NSLocalizedString(@"A read error occurred during communication.", @"Read error dialog description");
			break;
		
		case WCConnectionErrorWriteFailed:
			title = NSLocalizedString(@"Write Error", @"Write error dialog title");
			description = NSLocalizedString(@"A write error occurred during communication.", @"Write error dialog description");
			break;
		
		case WCConnectionErrorSSLConnectFailed:
			title = NSLocalizedString(@"SSL Connection Failed", @"SSL connection failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not establish an SSL connection with \"%@\".", @"SSL connection failed error dialog description (host)"),
				argument];

		case WCConnectionErrorSSLFailed:
			title = NSLocalizedString(@"SSL Error", @"SSL error dialog title");
			description = NSLocalizedString(@"An error occured during SSL communication. Perhaps the server is not configured properly.", @"SSL error dialog description");
			break;
		
		case WCConnectionErrorLoginTimeOut:
			title = NSLocalizedString(@"Login Timeout", @"Login timeout error dialog title");
			description = NSLocalizedString(@"Could not complete login due to timeout.", @"Login timeout error dialog description");
			break;
		
		// --- server errors
		case WCServerErrorCommandFailed:
		case WCServerErrorCommandNotImplemented:
			title = NSLocalizedString(@"Server Error", @"Server error dialog title");
			description = NSLocalizedString(@"An internal server error occured. Please contact the server administrator.", @"Server error dialog description");
			break;
			
		case WCServerErrorLoginFailed:
			title = NSLocalizedString(@"Login Failed", @"Login failed error dialog title");
			description = NSLocalizedString(@"Could not login, the user name and/or password you supplied was incorrect.", @"Login failed error dialog description");
			break;
		
		case WCServerErrorBanned:
			title = NSLocalizedString(@"Banned", @"Banned error dialog title");
			description = NSLocalizedString(@"Could not login, you are banned from this server.", @"Banned error dialog description");
			break;
		
		case WCServerErrorClientNotFound:
			title = NSLocalizedString(@"Client Not Found", @"Client not found error dialog title");
			description = NSLocalizedString(@"Could not find the client you referred to. Perhaps that client left before the command could be completed.", @"Client not found error dialog description");
			break;
		
		case WCServerErrorAccountNotFound:
			title = NSLocalizedString(@"Account Not found", @"Account not found error dialog title");
			description = NSLocalizedString(@"Could not find the account you referred to. Perhaps someone deleted it.", @"Account not found error dialog description");
			break;
		
		case WCServerErrorAccountExists:
			title = NSLocalizedString(@"Account Exists", @"Account exists error dialog title");
			description = NSLocalizedString(@"The account you tried to create already exists on the server.", @"Account exists error dialog description");
			break;
		
		case WCServerErrorCannotBeDisconnected:
			title = NSLocalizedString(@"Cannot Be Disconnected", @"Cannot be disconnected error dialog title");
			description = NSLocalizedString(@"The client you tried to disconnect is proteceted. You cannot disconnect that client.", @"Cannot be disconnected error dialog description");
			break;
		
		case WCServerErrorPermissionDenied:
			title = NSLocalizedString(@"Permission Denied", @"Permission denied error dialog title");
			description = NSLocalizedString(@"The command could not be completed due to insufficient privileges.", @"Permission denied error dialog description");
			break;
		
		case WCServerErrorFileNotFound:
			title = NSLocalizedString(@"File or Folder Not Found", @"File not found error dialog title");
			description = NSLocalizedString(@"Could not find the file or folder you referred to. Perhaps someone deleted it.", @"File not found error dialog description");
			break;
		
		case WCServerErrorFileExists:
			title = NSLocalizedString(@"File or Folder Exists", @"File exists error dialog title");
			description = NSLocalizedString(@"Could not create the file or directory, it already exists.", @"File exists error dialog description");
			break;
			
		case WCServerErrorChecksumMismatch:
			title = NSLocalizedString(@"Checksum Mismatch", @"Checksum mismatch error dialog title");
			description = NSLocalizedString(@"Could not start an upload, the checksums do not match.", @"Checksum mismatch error dialog description");
			break;
			
		case WCServerErrorQueueLimitExceeded:
			title = NSLocalizedString(@"Queue Limit Exceeded", @"Queue limit exceeded error dialog title");
			description = NSLocalizedString(@"Could not start a transfer, the limit has been exceeded.", @"Queue limit exceeded error dialog description");
			break;
		
		// --- application errors
		case WCApplicationErrorOpenFailed:
			title = NSLocalizedString(@"Open Failed", @"Open failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not open the file \"%@\".", @"Open failed error dialog description (path)"),
				argument];
			break;

		case WCApplicationErrorCreateFailed:
			title = NSLocalizedString(@"Create Failed", @"Create failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not create the file \"%@\".", @"Create failed error dialog description (path)"),
				argument];
			break;
		
		case WCApplicationErrorFileNotFound:
			break;
		
		case WCApplicationErrorFolderNotFound:
			break;

		case WCApplicationErrorFileExists:
			title = NSLocalizedString(@"File Exists", @"File exists error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"The file \"%@\" already exists.", @"File exists error dialog description (path)"),
				argument];
			break;

		case WCApplicationErrorFolderExists:
			title = NSLocalizedString(@"Folder Exists", @"Folder exists error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"The folder \"%@\" already exists.", @"Folder exists error dialog description (path)"),
				argument];
			break;

		case WCApplicationErrorChecksumMismatch:
			title = NSLocalizedString(@"Checksum Mismatch", @"Checksum mismatch error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"Could not resume transfer of \"%@\", the checksums do not match.", @"Checksum mismatch error dialog description (path)"),
				argument];
			break;

		case WCApplicationErrorTransferExists:
			title = NSLocalizedString(@"Transfer Exists", @"Transfer exists error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"You are already transferring \"%@\".", @"Transfer exists error dialog description (path)"),
				argument];
			break;
		
		case WCApplicationErrorTransferFailed:
			title = NSLocalizedString(@"Transfer Failed", @"Transfer failed error dialog title");
			description = [NSString stringWithFormat:
				NSLocalizedString(@"The transfer of \"%@\" failed.", @"Transfer failed error dialog description (path)"),
				argument];
			break;

		case WCApplicationErrorCannotDownload:
			title = NSLocalizedString(@"Cannot Download", @"Cannot download error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to download files.", @"Cannot download error dialog description");
			break;

		case WCApplicationErrorCannotUpload:
			title = NSLocalizedString(@"Cannot Upload", @"Cannot upload error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to upload files.", @"Cannot upload error dialog description");
			break;
		
		case WCApplicationErrorCannotUploadAnywhere:
			title = NSLocalizedString(@"Cannot Upload Anywhere", @"Cannot upload anywhere error dialog title");
			description = NSLocalizedString(@"You can only upload in Upload and Drop Box folders.", @"Cannot upload error anywhere dialog description");
			break;
		
		case WCApplicationErrorCannotCreateFolders:
			title = NSLocalizedString(@"Cannot Create Folders", "Cannot create folders error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to create folders on the server.", "Cannot create folders error dialog description");
			break;
		
		case WCApplicationErrorCannotDeleteFiles:
			title = NSLocalizedString(@"Cannot Delete", "Cannot delete files error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to delete files.", "Cannot delete files error dialog description");
			break;
		
		case WCApplicationErrorCannotDeleteFolders:
			title = NSLocalizedString(@"Cannot Delete", "Cannot delete folders error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to delete folders.", "Cannot delete folders error dialog description");
			break;
		
		case WCApplicationErrorCannotEditAccounts:
			title = NSLocalizedString(@"Cannot Edit Accounts", "Cannot edit accounts error dialog title");
			description = NSLocalizedString(@"You do not have sufficient privileges to edit accounts.", "Cannot edit accounts error dialog description");
			break;

		case WCApplicationErrorProtocolMismatch:
			title = NSLocalizedString(@"Protocol Mismatch", "Protocol mismatch error dialog title");
			description = NSLocalizedString(@"This server uses a newer protocol version than this client was developed for. Protocol errors may occur during the connection.", "Protocol mismatch error dialog description");
			break;
	}
	
	// --- show error on main thread
	if(title && description) {
		if(window) {
			[self performSelectorOnMainThread:@selector(showSheetInWindow:withTitle:description:)
								   withObject:window
								   withObject:title
								   withObject:description];
		} else {
			[self retain];
			[self performSelectorOnMainThread:@selector(showDialogWithTitle:description:)
								   withObject:title
								   withObject:description];
		}
	}

	// --- reset error
	_error = WCNoError;
	
	[_lock unlock];
}



#pragma mark -

- (void)showSheetInWindow:(NSWindow *)window withTitle:(NSString *)title description:(NSString *)description {
	NSBeginAlertSheet(title, NULL, NULL, NULL, window, NULL, NULL, NULL, NULL, description);
}



- (void)showDialogWithTitle:(NSString *)title description:(NSString *)description {
	NSPanel			*panel;
	NSButtonCell	*cell;

	panel = NSGetAlertPanel(title, description, NSLocalizedString(@"OK", "Button title"), NULL, NULL);
	[panel center];
	[panel makeKeyAndOrderFront:self];

	cell = [panel defaultButtonCell];
	[cell setTarget:self];
	[cell setAction:@selector(OK:)];
}



- (IBAction)OK:(id)sender {
	[[sender window] orderOut:self];
	
	NSReleaseAlertPanel([sender window]);
	
	[self release];
}

@end
