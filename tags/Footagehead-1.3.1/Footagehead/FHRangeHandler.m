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

#import "NSImage-FHAdditions.h"
#import "FHFile.h"
#import "FHRangeHandler.h"

@interface FHRangeHandler(Private)

+ (NSArray *)_getLinksForURL:(WIURL *)url;

@end


@implementation FHRangeHandler(Private)

+ (NSArray *)_getLinksForURL:(WIURL *)url {
	NSMutableArray	*links;
	NSArray			*array;
	NSString		*string, *prefix, *suffix, *rangeString;
	NSRange			searchRange, prefixRange, suffixRange;
	NSUInteger		i, length, start, stop;
	
	string = [url humanReadableString];
	searchRange = NSMakeRange(0, [string length]);
	
	while(searchRange.location < searchRange.location + searchRange.length) {
		prefixRange = [string rangeOfString:@"[" options:0 range:searchRange];
		
		if(prefixRange.location == NSNotFound)
			break;
		
		searchRange.length -= prefixRange.location - searchRange.location + 1;
		searchRange.location = prefixRange.location + 1;
		
		prefix = [string substringWithRange:NSMakeRange(0, prefixRange.location)];

		suffixRange = [string rangeOfString:@"]" options:0 range:searchRange];

		if(suffixRange.location == NSNotFound)
			continue;

		suffix = [string substringWithRange:NSMakeRange(suffixRange.location + 1, [string length] - suffixRange.location - 1)];
		
		rangeString = [string substringWithRange:NSMakeRange(prefixRange.location + 1, suffixRange.location - prefixRange.location - 1)];
		array = [rangeString componentsSeparatedByString:@"-"];
		
		if([array count] != 2)
			continue;

		start = [[array objectAtIndex:0] unsignedIntValue];
		stop = [[array objectAtIndex:1] unsignedIntValue];
		
		if(start == 0 && stop == 0)
			continue;

		links = [NSMutableArray arrayWithCapacity:stop - start + 1];
		length = [[array objectAtIndex:0] length];

		for(i = start; i <= stop; i++)
			[links addObject:[NSSWF:@"%@%0.*u%@", prefix, length, i, suffix]];

		return links;
	}
	
	return NULL;
}

@end


@implementation FHRangeHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	if(primary && ![url isFileURL]) {
		if(![[NSImage FHImageFileTypes] containsObject:[url pathExtension]]) 
			return NO;

		if(![self _getLinksForURL:url])
			return NO;
		
		return YES;
	}
		
	return NO;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url {
	self = [super initHandlerWithURL:url];
	
	_links = [[[self class] _getLinksForURL:url] retain];
	
	if(!_links) {
		[self release];
		
		return NULL;
	}
	
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
	
	if(!_files) {
		_files = [[NSMutableArray alloc] initWithCapacity:[_links count]];
			
		enumerator = [_links objectEnumerator];
		
		while((link = [enumerator nextObject])) {
			[_files addObject:[FHFile fileWithURL:[WIURL URLWithString:link] isDirectory:NO]];
			
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
