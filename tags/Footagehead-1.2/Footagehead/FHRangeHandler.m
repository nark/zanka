/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "NSImage-FHAdditions.h"
#import "FHFile.h"
#import "FHRangeHandler.h"

@implementation FHRangeHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	NSString		*string;
	
	if(primary && ![url isFileURL]) {
		string = [url path];
		
		if(![[NSImage FHImageFileTypes] containsObject:[string pathExtension]]) 
			return NO;

		if(([string containsSubstring:@"["] && [string containsSubstring:@"]"]) ||
		   ([string containsSubstring:@"%5B"] && [string containsSubstring:@"%5D"]))
			return YES;
	}
		
	return NO;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	NSArray			*array;
	NSString		*string, *preString, *postString, *rangeString;
	NSRange			preRange, postRange;
	unsigned int	i, length, start, stop;
	
	self = [super initHandlerWithURL:url];
	
	string = [[self URL] humanReadableString];
	
	preRange = [string rangeOfString:@"["];
	preString = [string substringWithRange:NSMakeRange(0, preRange.location)];
	
	postRange = [string rangeOfString:@"]"];
	postString = [string substringWithRange:NSMakeRange(postRange.location + 1, [string length] - postRange.location - 1)];

	rangeString = [string substringWithRange:NSMakeRange(preRange.location + 1, postRange.location - preRange.location - 1)];
	
	array = [rangeString componentsSeparatedByString:@"-"];
	
	if([array count] != 2) {
		[self release];

		return NULL;
	}
	
	start = [[array objectAtIndex:0] unsignedIntValue];
	stop = [[array objectAtIndex:1] unsignedIntValue];
	
	if(start == 0 && stop == 0) {
		[self release];

		return NULL;
	}
	
	_links = [[NSMutableArray alloc] initWithCapacity:stop - start + 1];
	length = [(NSString *) [array objectAtIndex:0] length];

	for(i = start; i <= stop; i++)
		[_links addObject:[NSSWF:@"%@%0.*u%@", preString, length, i, postString]];
	
	return self;
}



- (void)dealloc {
	[_links release];
	
	[super dealloc];
}



#pragma mark -

- (NSArray *)files {
	NSEnumerator	*enumerator;
	NSString		*link;
	FHFile			*file;
	unsigned int	i = 0;
	
	if(!_files) {
		_files = [[NSMutableArray alloc] initWithCapacity:[_links count]];
			
		enumerator = [_links objectEnumerator];
		
		while((link = [enumerator nextObject])) {
			file = [[FHFile alloc] initWithURL:[WIURL URLWithString:link] isDirectory:NO index:i++];
			[_files addObject:file];
			[file release];
			
			_numberOfFiles++;
			_numberOfImages++;
		}
	}
	
	return _files;
}



- (BOOL)hasParent {
	return NO;
}

@end
