/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

#import "NSImageAdditions.h"
#import "NSStringAdditions.h"
#import "FHFile.h"
#import "FHRangeHandler.h"

@implementation FHRangeHandler

- (id)initWithURL:(NSURL *)url hint:(int)hint {
	NSMutableString		*mutableString;
	NSString			*string, *start, *stop, *token;
	NSScanner			*scanner;
	NSRange				range;
	unsigned int		i, startNumber, stopNumber;
	int					length;
	
	self = [super initWithURL:url hint:hint];
	
	// --- create list of links
	_links = [[NSMutableArray alloc] initWithCapacity:20];
	
	// --- extract regexp
	string = [[[self URL] absoluteString] stringByReplacingURLPercentEscapes];
	scanner = [NSScanner scannerWithString:string];
	
	if(![scanner scanUpToString:@"[" intoString:NULL])
		return self;
	
	range.location = [scanner scanLocation];
	
	if(![scanner scanString:@"[" intoString:NULL])
		return self;

	if(![scanner scanUpToString:@"-" intoString:&start])
		return self;

	if(![scanner scanString:@"-" intoString:NULL])
		return self;

	if(![scanner scanUpToString:@"]" intoString:&stop])
		return self;
	
	range.length = [scanner scanLocation] - range.location + 1;

	// --- create format string
	mutableString = [NSMutableString stringWithString:string];
	[mutableString replaceCharactersInRange:range withString:@"%@"];
	
	// --- get length
	length = [start length];
	
	if([start isEntirelyComposedOfCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]]) {
		// --- treat as a numeric sequence and preserve padding
		startNumber = [start unsignedIntValue];
		stopNumber = [stop unsignedIntValue];
		
		for(i = startNumber; i <= stopNumber; i++) {
			token = [NSString stringWithFormat:@"%0.*u", length, i];
			[_links addObject:[NSString stringWithFormat:mutableString, token]];
		}
	}

	return self;
}



- (void)dealloc {
	[_links release];
	
	[super dealloc];
}



#pragma mark -

+ (void)load {
	[FHHandler _addHandler:self];
}



+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	NSString		*string;
	
	if(![url isFileURL]) {
		string = [url path];
		
		if(([string containsSubstring:@"["] && [string containsSubstring:@"]"]) ||
		   ([string containsSubstring:@"%5B"] && [string containsSubstring:@"%5D"]))
			return YES;
	}
	
	return NO;
}



#pragma mark -

- (NSArray *)files {
	NSEnumerator	*enumerator;
	NSArray			*types;
	NSString		*link;
	FHFile			*file;
	
	// --- check for existing
	if(_files)
		return _files;
	
	// --- create arrays
	_files		= [[NSMutableArray alloc] initWithCapacity:20];
	types		= [NSImage pureImageFileTypes];
	enumerator  = [_links objectEnumerator];
	
	while((link = [enumerator nextObject])) {
		// --- is it an image?
		if(![types containsObject:[link pathExtension]]) 
			continue;

		// --- bump number of images
		_numberOfImages++;
		
		// --- create file
		file = [[FHFile alloc] initWithURL:[NSURL URLWithString:link relativeToURL:[self URL]]
							   isDirectory:NO];
		[_files addObject:file];
		[file release];
	}
	
	return _files;
}

@end
