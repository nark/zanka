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

#import "FHCache.h"
#import "FHFeedHandler.h"
#import "FHHTMLHandler.h"
#import "FHImage.h"
#import "FHImageHandler.h"
#import "FHURLHandler.h"

@implementation FHURLHandler

+ (BOOL)handlesURL:(WIURL *)url isPrimary:(BOOL)primary {
	return (!primary && ![url isFileURL]);
}



#pragma mark -

+ (id)alloc {
	if([self isEqual:[FHURLHandler class]])
		return [FHPlaceholderURLHandler alloc];

	return [super alloc];
}



+ (id)allocWithZone:(NSZone *)zone {
	if([self isEqual:[FHURLHandler class]])
		return [FHPlaceholderURLHandler allocWithZone:zone];
	
	return [super allocWithZone:zone];
}

@end



@implementation FHPlaceholderURLHandler

+ (Class)handler {
	return [FHURLHandler class];
}



- (id)initHandlerWithURL:(WIURL *)url {
	NSMutableURLRequest	*request;
	NSURLResponse		*response;
	NSData				*data;
	NSString			*mime;
	NSZone				*zone;
	id					handler;
	
	zone = [self zone];
	[self release];

	if([[[url path] pathExtension] isEqualToString:@""]) {
		if(![[url string] hasSuffix:@"/"])
			url = [WIURL URLWithString:[[url string] stringByAppendingString:@"/"]];
	}

	request = [NSMutableURLRequest requestWithURL:[url URL]];
	[request setValue:[[url URLByDeletingLastPathComponent] string] forHTTPHeaderField:@"Referer"];
		
	data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
	
	if(!data)
		return NULL;

	mime = [response MIMEType];
	
	if([mime isEqualToString:@"text/html"]) {
		NSString			*text, *encodingName;
		NSStringEncoding	nsEncoding;
		CFStringEncoding	cfEncoding;
		
		nsEncoding = NSISOLatin1StringEncoding;
		encodingName = [response textEncodingName];
		
		if(encodingName) {
			cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef) encodingName);
			
			if(cfEncoding != kCFStringEncodingInvalidId)
				nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
		}
		
		text = [NSString stringWithData:data encoding:nsEncoding];

		return [[FHHTMLHandler allocWithZone:zone] initHandlerWithURL:url HTML:text];
	}
	else if([mime containsSubstring:@"xml"]) {
		CFXMLTreeRef	feed;
		Class			class;
		
		feed = CFXMLTreeCreateFromData(kCFAllocatorDefault, (CFDataRef) data,
									   NULL, kCFXMLParserSkipWhitespace,
									   kCFXMLNodeCurrentVersion);

		if(feed) {
			class = [FHFeedHandler handlerForURL:url];
			
			if([mime isEqualToString:@"text/xml"])
				handler = [[class allocWithZone:zone] initHandlerWithURL:url feed:feed];
			else if([mime isEqualToString:@"application/rss+xml"])
				handler = [[class allocWithZone:zone] initHandlerWithURL:url feed:feed format:FHFeedRSS];
			else
				handler = NULL;
			
			CFRelease(feed);
			
			return handler;
		}
	}
	else if([mime hasPrefix:@"image/"]) {
		FHImage	  *image, *thumbnail;
		
		image = [[[FHImage alloc] initImageWithData:data] autorelease];
		thumbnail = [[FHCache cache] thumbnailForURL:url withData:data];
		
		return [[FHImageHandler allocWithZone:zone] initHandlerWithURL:url image:image thumbnail:thumbnail];
	}
	
	return NULL;
}

@end
