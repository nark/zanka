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

#import "WCIcons.h"

@implementation WCIcons

static NSMutableDictionary		*icons;


- (id)init {
	self = [super init];
	
	// --- load initial icons
	[WCIcons reloadIcons];
		
	// --- subscribe to these
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(iconsShouldReload:)
			   name:WCIconsShouldReload
			 object:NULL];
	
	return self;
}



#pragma mark -

- (void)iconsShouldReload:(NSNotification *)notification {
	[WCIcons reloadIcons];
}



#pragma mark -

+ (void)reloadIcons {
	NSEnumerator			*enumerator, *imageEnumerator;
	NSDirectoryEnumerator   *fileEnumerator;
	NSDictionary			*dictionary;
	NSString				*path, *iconsPath, *file, *key;
	
	// --- initiate a dictionary to store all icons in
	[icons release];
	icons = [[NSMutableDictionary alloc] init];
	
	// --- load all icons
	enumerator	= [NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES) objectEnumerator];
	
	while((path = [enumerator nextObject])) {
		// --- full path to each directory of icons
		iconsPath = [path stringByAppendingPathComponent:WCIconsPath];
		
		// --- get an enumerator for that directory
		fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:iconsPath];
		
		if(fileEnumerator) {
			while((file = [fileEnumerator nextObject])) {
				// --- skip non-icons
				if(![file hasSuffix:@".WiredIcons"])
					continue;
				
				// --- load contents
				dictionary = [NSDictionary dictionaryWithContentsOfFile:[iconsPath stringByAppendingPathComponent:file]];
				
				if(dictionary) {
					imageEnumerator = [dictionary keyEnumerator];
					
					// --- decode all icons to NSImage and add to dictionary
					while((key = [imageEnumerator nextObject])) {
						[icons setObject:[NSUnarchiver unarchiveObjectWithData:[dictionary objectForKey:key]]
								  forKey:[NSNumber numberWithInt:[key intValue]]];
					}
				}
			}
		}
	}
}



#pragma mark -

+ (id)objectForKey:(id)key {
	return [icons objectForKey:key];
}



+ (NSDictionary *)icons {
	return icons;
}

@end
