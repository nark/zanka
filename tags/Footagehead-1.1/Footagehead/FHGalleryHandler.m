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
#import "FHFile.h"
#import "FHGalleryHandler.h"
#import "FHHandler.h"
#import "FHSettings.h"

@implementation FHGalleryHandler

+ (void)load {
	[FHHandler _addHandler:self withHint:FHHandlerHintGallery];
}



- (id)initWithURL:(NSURL *)url hint:(int)hint {
	self = [super initWithURL:url hint:hint];
	
	if([self hint] == FHHandlerHintNone) {
		if([[[url path] lastPathComponent] isEqualToString:@"albums"]) {
			if(![[url absoluteString] hasSuffix:@"/"])
				_url = [[NSURL URLWithString:[NSString stringWithFormat:
					@"%@/", [url absoluteString]]] retain];
			else
				_url = [url retain];
		} else {
			if(![[url absoluteString] hasSuffix:@"/"])
				_url = [[NSURL URLWithString:[NSString stringWithFormat:
					@"%@/albums/", [url absoluteString]]] retain];
			else
				_url = [[NSURL URLWithString:[NSString stringWithFormat:
					@"%@albums/", [url absoluteString]]] retain];
		}
		
		_albumdb = [[NSString alloc] initWithContentsOfURL:
			[NSURL URLWithString:@"albumdb.dat" relativeToURL:_url]];
	} else {
		if(![[url absoluteString] hasSuffix:@"/"])
			_url = [[NSURL URLWithString:[NSString stringWithFormat:
				@"%@/", [url absoluteString]]] retain];
		else
			_url = [url retain];

		_photos = [[NSString alloc] initWithContentsOfURL:
			[NSURL URLWithString:@"photos.dat" relativeToURL:_url]];
	}
	
	return self;
}



- (void)dealloc {
	[_albumdb release];
	[_photos release];
	
	[super dealloc];
}



#pragma mark -

+ (BOOL)_isHandlerForURL:(NSURL *)url primary:(BOOL)primary {
	return NO;
}



#pragma mark -

- (NSArray *)files {
	NSArray			*types;
	NSString		*filename, *name, *type;
	NSScanner		*scanner;
	FHFile			*file;
	
	if(_files)
		return _files;
	
	// --- create objects
	_files		= [[NSMutableArray alloc] initWithCapacity:20];
	types		= [NSImage pureImageFileTypes];
	
	if(_albumdb) {
		scanner = [NSScanner scannerWithString:_albumdb];

		while(![scanner isAtEnd]) {
			// --- find image name
			if([scanner scanUpToString:@";s:" intoString:NULL]) {
				if([scanner isAtEnd])
					break;
				
				[scanner setScanLocation:[scanner scanLocation] + 3];
				[scanner scanUpToString:@"\"" intoString:NULL];
				[scanner setScanLocation:[scanner scanLocation] + 1];
				[scanner scanUpToString:@"\"" intoString:&name];
			}
			
			// --- create file
			file = [[FHFile alloc] initWithURL:[NSURL URLWithString:name relativeToURL:[self URL]]
								   isDirectory:YES
										  hint:FHHandlerHintGallery];
			[_files addObject:file];
			[file release];
		}
	}
	else if(_photos) {
		scanner = [NSScanner scannerWithString:_photos];

		while(![scanner isAtEnd]) {
			// --- find image name
			if([scanner scanUpToString:@"s:5:\"image\";O:5:\"image\":12:{s:4:\"name\";" intoString:NULL]) {
				if([scanner isAtEnd])
					break;
				
				[scanner setScanLocation:[scanner scanLocation] + 39];
				[scanner scanUpToString:@"\"" intoString:NULL];
				[scanner setScanLocation:[scanner scanLocation] + 1];
				[scanner scanUpToString:@"\"" intoString:&name];
			}
			
			// --- find image type
			if([scanner scanUpToString:@"s:4:\"type\";s:" intoString:NULL]) {
				if([scanner isAtEnd])
					break;
				
				[scanner setScanLocation:[scanner scanLocation] + 13];
				[scanner scanUpToString:@"\"" intoString:NULL];
				[scanner setScanLocation:[scanner scanLocation] + 1];
				[scanner scanUpToString:@"\"" intoString:&type];
			}
			
			// --- insert
			if([types containsObject:type]) {
				filename = [NSString stringWithFormat:@"%@.%@", name, type];
				file = [[FHFile alloc] initWithURL:[NSURL URLWithString:filename relativeToURL:[self URL]]
									   isDirectory:NO];
				[_files addObject:file];
				[file release];
				
				_numberOfImages++;
			}
		}
	}
	
	return _files;
}



- (BOOL)isLocal {
	return NO;
}



#pragma mark -

- (NSURL *)parentURL {
	NSString	*string;
	NSRange		range;
	
	if(_hint != FHHandlerHintNone) {
		string = [[self URL] absoluteString];
		string = [string substringToIndex:[string length] - 1];
		
		range = [string rangeOfString:@"/" options:NSBackwardsSearch];
		
		if(range.location != NSNotFound)
			string = [string substringToIndex:range.location];

		range = [string rangeOfString:@"/" options:NSBackwardsSearch];
		
		if(range.location != NSNotFound)
			string = [string substringToIndex:range.location + 1];
		
		return [NSURL URLWithString:string];
	}

	return [self URL];
}



- (NSArray *)displayURLComponents {
	NSString		*string;
	NSRange			range;

	if(_hint != FHHandlerHintNone) {
		return [NSArray arrayWithObjects:
			[[self parentURL] absoluteString],
			[[self URL] absoluteString],
			NULL];
	}

	string = [[self URL] absoluteString];
	string = [string substringToIndex:[string length] - 1];

	range = [string rangeOfString:@"/" options:NSBackwardsSearch];
	
	if(range.location != NSNotFound)
		string = [string substringToIndex:range.location + 1];

	return [NSArray arrayWithObject:string];
}



- (NSArray *)fullURLComponents {
	if(_hint != FHHandlerHintNone) {
		return [NSArray arrayWithObjects:
			[self parentURL],
			[self URL],
			NULL];
	}
	
	return [NSArray arrayWithObject:_url];
}

@end
