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
#import "FHGalleryHandler.h"
#import "FHHTMLHandler.h"
#import "FHSettings.h"

@implementation FHHTMLHandler

- (id)initWithURL:(NSURL *)url hint:(int)hint {
	self = [super initWithURL:url hint:hint];
	
	if([[[url path] pathExtension] isEqualToString:@""] && ![[url absoluteString] hasSuffix:@"/"]) {
		[_url release];
		_url = [[NSURL URLWithString:[NSString stringWithFormat:@"%@/", [url absoluteString]]] retain];
	}
	
	_html = [[NSString alloc] initWithContentsOfURL:_url];
	
	if([_html containsSubstring:@"gallery.footer"]) {
		[self release];
		
		return [[FHGalleryHandler alloc] initWithURL:url];
	}

	return self;
}



- (void)dealloc {
	[_html release];
	
	[super dealloc];
}



#pragma mark -

+ (void)load {
	[FHHandler _addHandler:self];
}



+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	NSString		*extension;
	
	if(![url isFileURL]) {
		extension = [[url path] pathExtension]; 
		
		if([extension isEqualToString:@"html"] || [extension isEqualToString:@"htm"])
			return YES;
		else if([extension isEqualToString:@""] && !primary)
			return YES;
	}
	
	return NO;
}



#pragma mark -

- (NSArray *)files {
	NSCharacterSet  *tokenSet;
	NSArray			*types;
	NSString		*token, *link;
	NSScanner		*scanner;
	NSURL			*url;
	FHFile			*file;
	BOOL			isDirectory;
	
	if(_files)
		return _files;
	
	// --- create objects
	_files		= [[NSMutableArray alloc] initWithCapacity:20];
	types		= [NSImage pureImageFileTypes];
	tokenSet	= [NSCharacterSet characterSetWithCharactersInString:@" =\r\n\t\"\'<>"];
	
	// --- select token
	switch([FHSettings intForKey:FHExtract]) {
		case FHExtractImages:
			token = @"SRC";
			break;
		
		case FHExtractLinks:
		default:
			token = @"HREF";
	}
	
	if(_html) {
		// --- create scanner
		scanner = [NSScanner scannerWithString:_html];
		[scanner setCaseSensitive:NO];
		[scanner setCharactersToBeSkipped:tokenSet];
		
		// --- scan HTML
		while(![scanner isAtEnd]) {
			if([scanner scanUpToString:token intoString:NULL]) {
				// --- scan next link
				if(![scanner scanString:token intoString:NULL])
					continue;
				
				if(![scanner scanUpToCharactersFromSet:tokenSet intoString:&link])
					continue;
				
				if([link hasSuffix:@"/"]) {
					// --- is it a dir?
					isDirectory = YES;
				} else {
					// --- is it an image?
					if(![types containsObject:[link pathExtension]]) 
						continue;
					
					_numberOfImages++;

					isDirectory = NO;
				}
				
				// --- create url
				url = [[NSURL URLWithString:link relativeToURL:[self URL]] absoluteURL];
				
				if([[url path] isEqualToString:@"/"])
					continue;

				// --- create file
				file = [[FHFile alloc] initWithURL:url isDirectory:isDirectory];
				[_files addObject:file];
				[file release];
			}
		}
	}
	
	return _files;
}



#pragma mark -

- (NSURL *)parentURL {
	NSString		*string;
	NSRange			range;
	
	string = [_url absoluteString];
	
	while([string hasSuffix:@"/"])
		string = [string substringToIndex:[string length] - 1];
	
	range = [string rangeOfString:@"/" options:NSBackwardsSearch];
	
	if(range.location == NSNotFound)
		return [self URL];
	
	string = [string substringToIndex:range.location + 1];
	
	if([string hasSuffix:@"://"])
		return [self URL];
	
	return [NSURL URLWithString:string];
}

@end
