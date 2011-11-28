/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Daniel Ericsson, Axel Andersson
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

#import "WCFile.h"
#import "WCFiles.h"
#import "WCFilesTableView.h"
#import "WCTransfers.h"

@implementation WCFilesTableView

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination {
	NSEnumerator		*enumerator;
	NSPasteboard		*pasteboard;
	NSMutableArray		*files;
	NSArray				*sources;
	NSString			*path;
	WCFile				*file;
		
	pasteboard	= [NSPasteboard pasteboardWithName:NSDragPboard];
	sources		= [NSUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
	enumerator	= [sources objectEnumerator]; 
	path		= [destination path];
	files		= [[NSMutableArray alloc] initWithCapacity:[sources count]];
				
	while((file = [enumerator nextObject])) {
		if([[[(WCFiles *) [self delegate] connection] transfers] downloadFile:file toFolder:path])
			[files addObject:[file name]];
	}
	
	return [files autorelease];
}

@end
