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

#import "WCCache.h"

@implementation WCCache

- (id)initWithCount:(unsigned int)count {
	self = [super init];
	
	// --- get parameters
	_count = count;
	
	// --- init dictionaries to hold our caches
	_files			= [[NSMutableDictionary alloc] init];
	_fileIcons		= [[NSMutableDictionary alloc] init];
	_transferIcons  = [[NSMutableDictionary alloc] init];
		
	return self;
}



- (void)dealloc {
	[_files release];
	[_fileIcons release];
	[_transferIcons release];
	
	[super dealloc];
}



#pragma mark -

- (void)setFiles:(NSArray *)files free:(unsigned long long)free forPath:(NSString *)path {
	if([_files count] > _count)
		[_files removeObjectForKey:[[_files allKeys] objectAtIndex:0]];
	
	[_files setObject:[NSArray arrayWithObjects:
			files,
			[NSNumber numberWithUnsignedLongLong:free],
			NULL]
		forKey:path];
}



- (void)dropFilesForPath:(NSString *)path {
	[_files removeObjectForKey:path];
}



- (NSArray *)filesForPath:(NSString *)path free:(unsigned long long *)free {
	*free = [[[_files objectForKey:path] objectAtIndex:1] unsignedLongLongValue];
	
	return [[_files objectForKey:path] objectAtIndex:0];
}



#pragma mark -

- (void)setFileIcon:(NSImage *)icon forExtension:(NSString *)extension {
	if([_fileIcons count] > _count)
		[_fileIcons removeObjectForKey:[[_fileIcons allKeys] objectAtIndex:0]];
	
	[_fileIcons setObject:icon forKey:extension];
}



- (NSImage *)fileIconForExtension:(NSString *)extension {
	return [_fileIcons objectForKey:extension];
}



#pragma mark -

- (void)setTransferIcon:(NSImage *)icon forExtension:(NSString *)extension {
	if([_transferIcons count] > _count)
		[_transferIcons removeObjectForKey:[[_transferIcons allKeys] objectAtIndex:0]];
	
	[_transferIcons setObject:icon forKey:extension];
}



- (NSImage *)transferIconForExtension:(NSString *)extension {
	return [_transferIcons objectForKey:extension];
}

@end
