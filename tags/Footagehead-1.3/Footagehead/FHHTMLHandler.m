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
#import "FHHTMLHandler.h"
#import "FHHTMLParser.h"
#import "FHSettings.h"

@interface FHHTMLHandler(Private)

- (int)_HTMLImageType;
- (BOOL)_shouldIncludeURL:(WIURL *)url;

@end


@implementation FHHTMLHandler(Private)

- (int)_HTMLImageType {
	if(_type == FHHTMLHandler4chan)
		return FHHTMLImageOnlyLinks;
	
	return [FHSettings intForKey:FHHTMLImageType];
}



- (BOOL)_shouldIncludeURL:(WIURL *)url {
	if(_type == FHHTMLHandler4chan)
		return ![[url path] containsSubstring:@"src.cgi"];
	
	return YES;
}

@end



@implementation FHHTMLHandler

+ (Class)handlerForURL:(WIURL *)url {
	return self;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url HTML:(NSString *)html {
	NSString	*host;
	
	self = [super initHandlerWithURL:url];
	
	_html = [html retain];
	
	host = [url host];
	
	if([host hasSuffix:@"4chan.org"])
		_type = FHHTMLHandler4chan;
	else
		_type = FHHTMLHandlerGeneric;
	
	return self;
}



- (void)dealloc {
	[_html release];
	
	[super dealloc];
}



#pragma mark -

- (NSArray *)files {
	NSArray			*links;
	WIURL			*url;
	NSUInteger		i, count;
	
	if(!_files) {
		links = [FHHTMLParser imageLinksInHTML:_html baseURL:[self URL] type:[self _HTMLImageType]];
		count = [links count];
		
		_files = [[NSMutableArray alloc] initWithCapacity:count];
		
		for(i = 0; i < count; i++) {
			url = [links objectAtIndex:i];
			
			if([self _shouldIncludeURL:url]) {
				[_files addObject:[FHFile fileWithURL:url isDirectory:NO]];
				
				_numberOfFiles++;
				_numberOfImages++;
			}
		}
	}
	
	return _files;
}

@end
