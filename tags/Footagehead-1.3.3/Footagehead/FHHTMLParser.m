/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "FHHTMLParser.h"
#import "FHImage.h"
#import "FHSettings.h"

@implementation FHHTMLParser

+ (NSArray *)imageLinksInHTML:(NSString *)html baseURL:(WIURL *)baseURL {
	return [self imageLinksInHTML:html baseURL:baseURL type:[FHSettings intForKey:FHHTMLImageType]];
}



+ (NSArray *)imageLinksInHTML:(NSString *)html baseURL:(WIURL *)baseURL type:(int)type {
	NSScanner		*scanner;
	NSMutableArray	*links, *urls;
	NSMutableSet	*set;
	NSCharacterSet	*skipSet;
	NSArray			*tokens;
	NSSet			*types;
	NSString		*token, *link, *path, *extension;
	WIURL			*url;
	NSUInteger		i, count, length;
	
	links	= [NSMutableArray arrayWithCapacity:50];
	length	= [html length];
	skipSet	= [NSCharacterSet characterSetWithCharactersInString:@" =\r\n\t\"\'<>"];
	
	switch(type) {
		case FHHTMLImageOnlyInline:
			tokens = [NSArray arrayWithObject:@"SRC"];
			break;

		case FHHTMLImageOnlyLinks:
			tokens = [NSArray arrayWithObject:@"HREF"];
			break;

		case FHHTMLImageBothInlineAndLinks:
		default:
			tokens = [NSArray arrayWithObjects:@"HREF", @"SRC", nil];
			break;
	}
	
	count = [tokens count];
	
	for(i = 0; i < count; i++) {
		token = [tokens objectAtIndex:i];

		scanner = [[NSScanner alloc] initWithString:html];
		[scanner setCaseSensitive:NO];
		[scanner setCharactersToBeSkipped:skipSet];
		
		while([scanner scanLocation] < length) {
			if([scanner scanUpToString:token intoString:NULL]) {
				if([scanner scanString:token intoString:NULL]) {
					if([scanner scanUpToCharactersFromSet:skipSet intoString:&link])
						[links addObject:link];
				}
			}
		}
		
		[scanner release];
	}
	
	count	= [links count];
	urls	= [NSMutableArray arrayWithCapacity:count];
	set		= [NSMutableSet setWithCapacity:count];
	types	= [NSSet setWithArray:[FHImage imageFileTypes]];
	
	for(i = 0; i < count; i++) {
		link = [links objectAtIndex:i];
		extension = [link pathExtension];
		
		if(![types containsObject:extension]) 
			continue;
		
		if([extension isEqualToString:@"ico"])
			continue;
		
		link = [link stringByReplacingURLPercentEscapes];
		
		if([link containsSubstring:@"://"]) {
			url = [WIURL URLWithString:link];
		} else {
			url = [[baseURL copy] autorelease];
			
			if([link hasPrefix:@"/"]) {
				[url setPath:link];
			} else {
				path = [url path];
				
				if(![path hasSuffix:@"/"])
					path = [path stringByDeletingLastPathComponent];
				
				[url setPath:[path stringByAppendingPathComponent:link]];
			}
		}
		
		if(![set containsObject:url]) {
			[urls addObject:url];
			[set addObject:url];
		}
	}
		
	return urls;
}

@end
