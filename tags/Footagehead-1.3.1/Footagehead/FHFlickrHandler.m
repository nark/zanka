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

#import "FHFile.h"
#import "FHFlickrHandler.h"
#import "FHHTMLParser.h"

@implementation FHFlickrHandler

- (NSArray *)files {
	NSMutableString	*path;
	NSDictionary	*item;
	NSArray			*links;
	NSString		*content;
	WIURL			*url;
	NSRange			range;
	NSUInteger		i, count;
	
	if(!_files) {
		count = [_items count];
		_files = [[NSMutableArray alloc] initWithCapacity:count];
		
		for(i = 0; i < count; i++) {
			item = [_items objectAtIndex:i];
			content = [item objectForKey:[self itemContentKey]];
			links = [FHHTMLParser imageLinksInHTML:content baseURL:[self URL]];
			
			if([links count] > 0) {
				url = [links objectAtIndex:0];
				path = [[url path] mutableCopy];
				range = [path rangeOfString:@"_m"];
				
				if(range.location != NSNotFound)
					[path deleteCharactersInRange:range];
				
				[url setPath:path];
				[path release];
				
				[_files addObject:[FHFile fileWithURL:url name:[item objectForKey:@"title"] isDirectory:NO]];
				
				_numberOfFiles++;
				_numberOfImages++;
			}
		}
	}
	
	return _files;
}

@end
