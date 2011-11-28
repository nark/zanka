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

@implementation WCError

- (NSString *)localizedDescription {
	if([[self domain] isEqualToString:WCWiredClientErrorDomain]) {
		switch([self code]) {
			case WCWiredClientServerDisconnected:
				return NSLS(@"Server Disconnected", @"WCWiredClientServerDisconnected title");
				break;
				
			case WCWiredClientProtocolMismatch:
				return NSLS(@"Protocol Mismatch", "WCWiredClientProtocolMismatch title");
				break;
				
			case WCWiredClientOpenFailed:
				return NSLS(@"Open Failed", @"Error");
				break;
				
			case WCWiredClientCreateFailed:
				return NSLS(@"Create Failed", @"Error");
				break;
				
			case WCWiredClientFileExists:
				return NSLS(@"File Exists", @"Error");
				break;
				
			case WCWiredClientFolderExists:
				return NSLS(@"Folder Exists", @"Error");
				break;
				
			case WCWiredClientChecksumMismatch:
				return NSLS(@"Checksum Mismatch", @"Error");
				break;
				
			case WCWiredClientTransferExists:
				return NSLS(@"Transfer Exists", @"Error");
				break;
				
			case WCWiredClientTransferWithResourceFork:
				return NSLS(@"Transfer Not Supported", @"Error");
				break;
				
			case WCWiredClientTransferFailed:
				return NSLS(@"Transfer Failed", @"Error");
				break;
				
			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WCWiredErrorDomain]) {
		switch([self code]) {
			case 500:
				return NSLS(@"Server Error", @"Wired Protocol error 500 title");
				break;

			case 501:
				return NSLS(@"Server Error", @"Wired Protocol error 501 title");
				break;

			case 502:
				return NSLS(@"Server Error", @"Wired Protocol error 502 title");
				break;

			case 503:
				return NSLS(@"Server Error", @"Wired Protocol error 503 title");
				break;

			case 510:
				return NSLS(@"Login Failed", @"Wired Protocol error 510 title");
				break;

			case 511:
				return NSLS(@"Banned", @"Wired Protocol error 511 title");
				break;

			case 512:
				return NSLS(@"Client Not Found", @"Wired Protocol error 512 title");
				break;

			case 513:
				return NSLS(@"Account Not found", @"Wired Protocol error 513 title");
				break;

			case 514:
				return NSLS(@"Account Exists", @"Wired Protocol error 514 title");
				break;

			case 515:
				return NSLS(@"Cannot Be Disconnected", @"Wired Protocol error 515 title");
				break;

			case 516:
				return NSLS(@"Permission Denied", @"Wired Protocol error 516 title");
				break;

			case 520:
				return NSLS(@"File or Folder Not Found", @"Wired Protocol error 520 title");
				break;

			case 521:
				return NSLS(@"File or Folder Exists", @"Wired Protocol error 521 title");
				break;

			case 522:
				return NSLS(@"Checksum Mismatch", @"Wired Protocol error 522 title");
				break;

			case 523:
				return NSLS(@"Queue Limit Exceeded", @"Wired Protocol error 523 title");
				break;
			
			default:
				return NSLS(@"Server Error", @"Wired Protocol unknown error title");
				break;
		}
	}
	
	return [super localizedDescription];
}



- (NSString *)localizedFailureReason {
	id		argument;
	
	argument = [[self userInfo] objectForKey:WIArgumentErrorKey];

	if([[self domain] isEqualToString:WCWiredClientErrorDomain]) {
		switch([self code]) {
			case WCWiredClientServerDisconnected:
				return NSLS(@"The server has unexpectedly disconnected.", @"WCWiredClientServerDisconnected description");
				break;
				
			case WCWiredClientProtocolMismatch:
				return NSLS(@"This server uses a newer protocol version than this client supports. Protocol errors may occur during the connection.", "WCWiredClientProtocolMismatch description");
				break;

			case WCWiredClientOpenFailed:
				return [NSSWF:NSLS(@"Could not open the file \"%@\".", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientCreateFailed:
				return [NSSWF:NSLS(@"Could not create the file \"%@\".", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientFileExists:
				return [NSSWF:NSLS(@"The file \"%@\" already exists.", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientFolderExists:
				return [NSSWF:NSLS(@"The folder \"%@\" already exists.", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientChecksumMismatch:
				return [NSSWF:NSLS(@"Could not resume transfer of \"%@\", the checksums do not match.", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientTransferExists:
				return [NSSWF:NSLS(@"You are already transferring \"%@\".", @"Error (path)"),
					argument];
				break;
				
			case WCWiredClientTransferWithResourceFork:
				if([argument isKindOfClass:[NSString class]]) {
					return [NSSWF:NSLS(@"The file \"%@\" has a resource fork, which is not handled by Wired. Only the data part will be uploaded, possibly resulting in a corrupted file. Please use an archiver to ensure the file will be uploaded correctly.", @"Error (path)"),
						argument];
				}
				else if([argument isKindOfClass:[NSNumber class]]) {
					return [NSSWF:NSLS(@"The folder contains %u files with resource forks, which are not handled by Wired. Only the data parts will be uploaded, possibly resulting in corrupted files. Please use an archiver to ensure the files will be uploaded correctly.", @"Error (path)"),
						[argument intValue]];
				}
				break;

			case WCWiredClientTransferFailed:
				return [NSSWF:NSLS(@"The transfer of \"%@\" failed.", @"Error (name)"),
					argument];
				break;
				
			default:
				break;
		}
	}
	else if([[self domain] isEqualToString:WCWiredErrorDomain]) {
		switch([self code]) {
			case 500:
				return NSLS(@"The server failed to process a command. The server administrator can check the log for more information.", @"Wired Protocol error 500 description");
				break;

			case 501:
				return NSLS(@"The server did not recognize a command. This is probably because of an protocol incompatibility between the client and the server.", @"Wired Protocol error 501 description");
				break;

			case 502:
				return NSLS(@"The server has not implemented a command. This is probably because of an protocol incompatibility between the client and the server.", @"Wired Protocol error 502 description");
				break;

			case 503:
				return NSLS(@"The server could not parse a command. This is probably because of an protocol incompatibility between the client and the server.", @"Wired Protocol error 503 description");
				break;

			case 510:
				return NSLS(@"Could not login, the user name and/or password you supplied was rejected.", @"Wired Protocol error 510 description");
				break;

			case 511:
				return NSLS(@"Could not login, you are banned from this server.", @"Wired Protocol error 511 description");
				break;

			case 512:
				return NSLS(@"Could not find the client you referred to. Perhaps that client left before the command could be completed.", @"Wired Protocol error 512 description");
				break;

			case 513:
				return NSLS(@"Could not find the account you referred to. Perhaps someone deleted it.", @"Wired Protocol error 513 description");
				break;

			case 514:
				return NSLS(@"The account you tried to create already exists on the server.", @"Wired Protocol error 514 description");
				break;

			case 515:
				return NSLS(@"The client you tried to disconnect is protected.", @"Wired Protocol error 515 description");
				break;

			case 516:
				return NSLS(@"The command could not be completed due to insufficient privileges.", @"Wired Protocol error 516 description");
				break;

			case 520:
				return NSLS(@"Could not find the file or folder you referred to. Perhaps someone deleted it.", @"Wired Protocol error 520 description");
				break;

			case 521:
				return NSLS(@"Could not create the file or directory, it already exists.", @"Wired Protocol error 521 description");
				break;

			case 522:
				return NSLS(@"Could not start an upload, the checksums do not match.", @"Wired Protocol error 522 description");
				break;

			case 523:
				return NSLS(@"Could not start a transfer, the limit has been exceeded.", @"Wired Protocol error 523 description");
				break;
			
			default:
				return [NSSWF:NSLS(@"An unknown server error occured. The message we got back was: \"%d %@\".", @"Wired Protocol unknown error description (code, message)"),
					[self code], argument];
				break;
		}
	}

	return [[self superclass] instancesRespondToSelector:_cmd] ? [(id) super localizedFailureReason] : NULL;
}


@end
