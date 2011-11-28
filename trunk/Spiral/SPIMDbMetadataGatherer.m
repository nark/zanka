/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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

/*
 * SapphireMovieImporter.m
 * Sapphire
 *
 * Created by Patrick Merrill on Sep. 10, 2007.
 * Copyright 2007 Sapphire Development Team and/or www.nanopi.net
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 3 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "NSString-SPAdditions.h"
#import "SPIMDbMetadataGatherer.h"
#import "SPIMDbMetadataMatch.h"

NSString * const SPIMDbMetadataTitleKey				= @"SPIMDbMetadataTitleKey";
NSString * const SPIMDbMetadataRatingKey			= @"SPIMDbMetadataRatingKey";
NSString * const SPIMDbMetadataDirectorsKey			= @"SPIMDbMetadataDirectorsKey";
NSString * const SPIMDbMetadataWritersKey			= @"SPIMDbMetadataWritersKey";
NSString * const SPIMDbMetadataReleaseDateKey		= @"SPIMDbMetadataReleaseDateKey";
NSString * const SPIMDbMetadataGenresKey			= @"SPIMDbMetadataGenresKey";
NSString * const SPIMDbMetadataPlotKey				= @"SPIMDbMetadataPlotKey";
NSString * const SPIMDbMetadataCountriesKey			= @"SPIMDbMetadataCountriesKey";
NSString * const SPIMDbMetadataCastKey				= @"SPIMDbMetadataCastKey";

NSString * const SPIMDbTVMetadataEpisodeTitleKey	= @"SPIMDbTVMetadataEpisodeTitleKey";
NSString * const SPIMDbTVMetadataEpisodeAirDateKey	= @"SPIMDbTVMetadataEpisodeAirDateKey";
NSString * const SPIMDbTVMetadataEpisodePlotKey		= @"SPIMDbTVMetadataEpisodePlotKey";

@interface SPIMDbMetadataGatherer(Private)

- (NSArray *)_objectsInElement:(NSXMLElement *)document forXQuery:(NSString *)query error:(NSError **)error;

- (NSImage *)_IMPAwardsPosterImageForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error;
- (WIURL *)_IMPAwardsPosterLinkForURL:(WIURL *)url error:(NSError **)error;

- (NSImage *)_IMDbPosterImageForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error;
- (WIURL *)_IMDbPosterLinkForURL:(WIURL *)url error:(NSError **)error;

- (NSError *)_genericParseError;

@end


@implementation SPIMDbMetadataGatherer(Private)

- (NSArray *)_objectsInElement:(NSXMLElement *)element forXQuery:(NSString *)query error:(NSError **)error {
	NSArray			*objects;
	
	objects = [element objectsForXQuery:query error:error];
	
	if([objects count] == 0) {
		if(objects && error)
			*error = [self _genericParseError];
		
		return NULL;
	}
	
	return objects;
}



#pragma mark -

- (NSImage *)_IMPAwardsPosterImageForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error {
	NSMutableArray		*imageURLs;
	NSArray				*objects;
	NSXMLDocument		*document;
	NSXMLElement		*rootElement;
	NSData				*data;
	NSImage				*image;
	NSString			*string;
	WIURL				*url, *imageURL;
	id					object;
	
	// URL from "/posters/" page on IMDb to IMP Awards
	url = [self _IMPAwardsPosterLinkForURL:[match URL] error:error];
	
	if(!url)
		return NULL;
	
	document = [[[NSXMLDocument alloc] initWithContentsOfURL:[url URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	
	if(!document)
		return NULL;
	
	rootElement = [document rootElement];
	
	[url setPath:[[url path] stringByDeletingLastPathComponent]];
	
	// Image candidates
	objects = [self _objectsInElement:rootElement forXQuery:@"//img/@src" error:error];
	
	if(!objects)
		return NULL;
	
	imageURLs = [NSMutableArray array];
	
	for(object in objects) {
		// Try just shown poster
		string = [[object stringValue] stringByMatching:@"posters/(.+)" capture:1];
		
		if(string) {
			imageURL = [[url copy] autorelease];
			
			[imageURL setPath:[[imageURL path] stringByAppendingPathComponent:[NSSWF:@"posters/%@", string]]];
			
			[imageURLs addObject:imageURL];
		}
	}
	
	for(object in objects) {
		// Try first in thumbs list
		string = [[object stringValue] stringByMatching:@"thumbs/imp_(.+)" capture:1];
		
		if(string) {
			imageURL = [[url copy] autorelease];
			
			[imageURL setPath:[[imageURL path] stringByAppendingPathComponent:[NSSWF:@"posters/%@", string]]];
			
			[imageURLs addObject:imageURL];
		}
	}
	
	for(imageURL in imageURLs) {
		// Download data
		data = [NSData dataWithContentsOfURL:[imageURL URL] options:0 error:error];
		
		if(data) {
			image = [NSImage imageWithData:data];
			
			if(image)
				return image;
		}
	}
	
	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}



- (WIURL *)_IMPAwardsPosterLinkForURL:(WIURL *)url error:(NSError **)error {
	NSArray				*objects;
	NSXMLDocument		*document;
	NSXMLElement		*rootElement;
	NSString			*string;
	WIURL				*postersURL;
	id					object;
	
	postersURL		= [[url copy] autorelease];
	
	[postersURL setPath:[[postersURL path] stringByAppendingPathComponent:@"posters"]];
	
	document		= [[[NSXMLDocument alloc] initWithContentsOfURL:[postersURL URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	rootElement		= [document rootElement];
	objects			= [self _objectsInElement:rootElement forXQuery:@"//ul/li/a/@href" error:error];
	
	if(!objects)
		return NULL;
	
	for(object in objects) {
		string = [object stringValue];
		
		if([string containsSubstring:@"impawards.com" options:NSCaseInsensitiveSearch])
			return [WIURL URLWithString:string];
	}
	
	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}



#pragma mark -

- (NSImage *)_IMDbPosterImageForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error {
	NSMutableArray		*imageURLs;
	NSArray				*objects;
	NSXMLDocument		*document;
	NSXMLElement		*rootElement;
	NSData				*data;
	NSImage				*image;
	WIURL				*url, *imageURL;
	id					object;
	
	// URL to IMDb's own poster page
	url = [self _IMDbPosterLinkForURL:[match URL] error:error];
	
	if(!url)
		return NULL;
	
	document = [[[NSXMLDocument alloc] initWithContentsOfURL:[url URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	
	if(!document)
		return NULL;
	
	rootElement = [document rootElement];
	
	// Image candidates
	objects = [self _objectsInElement:rootElement forXQuery:@"//img/@src" error:error];
	
	if(!objects)
		return NULL;
	
	imageURLs = [NSMutableArray array];
	
	for(object in objects) {
		// Find images
		if([[object stringValue] containsSubstring:@"ia.media-imdb.com/images"])
			[imageURLs addObject:[WIURL URLWithString:[object stringValue]]];
	}
	
	for(imageURL in imageURLs) {
		// Download data
		data = [NSData dataWithContentsOfURL:[imageURL URL] options:0 error:error];
		
		if(data) {
			image = [NSImage imageWithData:data];
			
			if(image)
				return image;
		}
	}
	
	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}



- (WIURL *)_IMDbPosterLinkForURL:(WIURL *)url error:(NSError **)error {
	NSArray				*objects;
	NSXMLDocument		*document;
	NSXMLElement		*rootElement;
	NSString			*string;
	id					object;
	
	document		= [[[NSXMLDocument alloc] initWithContentsOfURL:[url URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	rootElement		= [document rootElement];
	objects			= [self _objectsInElement:rootElement forXQuery:@"//a/@href" error:error];
	
	if(!objects)
		return NULL;
	
	for(object in objects) {
		string = [[object stringValue] stringByMatching:@"primary-photo/media/(rm\\d+)" capture:1];
		
		if(string)
			return [WIURL URLWithString:[NSSWF:@"http://www.imdb.com/media/%@/", string]];
	}
	
	if(error)
		*error = [self _genericParseError];
		
	return NULL;
}

	
	
#pragma mark -

- (NSError *)_genericParseError {
	return [NSError errorWithDomain:@"SPIMDBMetadataGatherer"
							   code:1
						   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
									NSLS(@"Could not parse IMDb data", @"Error title"),
										NSLocalizedDescriptionKey,
									NSLS(@"Encountered unexpected data. Please contact Zanka Software about this error.", @"Error title"),
										NSLocalizedFailureReasonErrorKey,
									NULL]];
}

@end



@implementation SPIMDbMetadataGatherer

+ (SPIMDbMetadataGatherer *)sharedGatherer {
	static SPIMDbMetadataGatherer	*gatherer;
	
	if(!gatherer)
		gatherer = [[self alloc] init];
	
	return gatherer;
}



- (id)init {
	self = [super init];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setDateFormat:@"dd LLLL yyyy"];
	[_dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];

	return self;
}



- (void)dealloc {
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (NSArray *)matchesForName:(NSString *)name error:(NSError **)error {
	NSMutableArray		*matches;
	NSXMLDocument		*document;
	NSXMLElement		*rootElement;
	NSArray				*objects, *linkObjects;
	NSString			*pageTitle, *string;
	NSMutableString		*title;
	WIURL				*url;
	id					object;
	NSRange				range;
	
	matches		= [NSMutableArray array];
	url			= [WIURL URLWithString:[NSSWF:@"http://www.imdb.com/find?s=tt&q=%@", name]];
	document	= [[[NSXMLDocument alloc] initWithContentsOfURL:[url URL]
														options:NSXMLDocumentTidyHTML
														  error:error] autorelease];
	
	if(!document)
		return NULL;
	
	rootElement = [document rootElement];
	
	// Page title
	objects = [self _objectsInElement:rootElement forXQuery:@"//title" error:error];
	
	if(!objects)
		return NULL;
	
	pageTitle = [[objects objectAtIndex:0] stringValue];
	
	if([pageTitle isEqualToString:@"IMDb Title Search"]) {
		// Multiple matches / no matches
		objects = [rootElement objectsForXQuery:@"//td[starts-with(a/@href,'/title')]" error:error];
		
		if(!objects)
			return NULL;
		
		if([objects count] == 0)
			return [NSArray array];
		
		for(object in objects) {
			linkObjects = [self _objectsInElement:object forXQuery:@".//a/@href" error:error];
			
			if(!linkObjects)
				return NULL;
			
			// URL to match
			url = [WIURL URLWithString:@"http://www.imdb.com/"];
			
			[url setPath:[[linkObjects objectAtIndex:0] stringValue]];
			
			// Title to match, removing "aka" titles, non-breaking spaces, "(V)" and others
			title = [[[object stringValue] mutableCopy] autorelease];
			
			[title replaceOccurrencesOfString:@"\u00A0" withString:@" "];
			[title trimCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[title replaceOccurrencesOfString:@")aka \"" withString:@")\naka \""];
			
			range = [title rangeOfString:@"\n"];
			
			if(range.location != NSNotFound)
				[title deleteCharactersFromIndex:range.location];
			
			range = [title rangeOfString:@" (V)"];
			
			if(range.location != NSNotFound)
				[title deleteCharactersInRange:range];
			
			[title replaceOccurrencesOfString:@"  " withString:@" "];
			
			[title replaceOccurrencesOfRegex:@"^\"(.+)\" (\\(.+\\))$" withString:@"$1 $2"];
			
			if([title length] == 0)
				continue;
			
			// Skip video games
			if([title containsSubstring:@"(VG)"])
				continue;
			
			[matches addObject:[SPIMDbMetadataMatch matchWithTitle:title URL:url]];
			
			if([matches count] == 10)
				break;
		}
		
		return matches;
	} else {
		// Single match
		objects = [self _objectsInElement:rootElement forXQuery:@"//a[@class='tn15more inline']/@href" error:error];
		
		if(!objects)
			return NULL;
		
		for(object in objects) {
			// URL to match
			string = [[object stringValue] stringByMatching:@"tt\\d+"];
			
			if(string) {
				url = [WIURL URLWithString:@"http://www.imdb.com/"];
				
				[url setPath:[NSSWF:@"/title/%@/", string]];

				[matches addObject:[SPIMDbMetadataMatch matchWithTitle:pageTitle URL:url]];
				
				return matches;
			}
		}
	}
	
	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}



- (NSDictionary *)metadataForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error {
	NSMutableDictionary		*metadata;
	NSMutableArray			*array;
	NSXMLDocument			*document;
	NSXMLElement			*rootElement;
	NSString				*string, *value, *name;
	NSArray					*objects;
	NSDate					*date;
	id						object;
	
	metadata = [NSMutableDictionary dictionary];
	document = [[[NSXMLDocument alloc] initWithContentsOfURL:[[match URL] URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	
	if(!document)
		return NULL;
	
	rootElement = [document rootElement];
	
	// Page title, removing " (YYYY)"
	objects = [self _objectsInElement:rootElement forXQuery:@"//title" error:error];
	
	if(!objects)
		return NULL;
	
	string = [[[objects objectAtIndex:0] stringValue] stringByReplacingOccurrencesOfRegex:@"\"(.+)\"" withString:@"$1"];

	[match setTitle:string];
	
	string = [string stringByReplacingOccurrencesOfRegex:@"^(.+?) \\(\\d{4}.*\\)" withString:@"$1"];
	
	[metadata setObject:string forKey:SPIMDbMetadataTitleKey];
		
	// Rating, "8.4"
	objects = [self _objectsInElement:rootElement forXQuery:@"(//b | //h5)/string()" error:error];
	
	for(object in objects) {
		string = [object stringByMatching:@"(\\d\\.\\d)/10" capture:1];
		
		if(string) {
			[metadata setObject:[NSNumber numberWithDouble:[string doubleValue]] forKey:SPIMDbMetadataRatingKey];
			
			break;
		}
	}
	
	// Overview
	objects = [self _objectsInElement:rootElement forXQuery:@"//div[@class='info']" error:error];
	
	for(object in objects) {
		string = [object stringValue];
		
		if([string length] > 0) {
			// Directors
			value = [string stringByMatching:@"Director(.*?):\n(.+)" options:RKLDotAll capture:2];
			
			if(value) {
				array = [NSMutableArray array];
				
				for(name in [value componentsSeparatedByString:@"\n"]) {
					if([name length] > 0 && ![name isEqualToString:@"more"])
						[array addObject:name];
				}
				
				if([array count] > 0)
					[metadata setObject:array forKey:SPIMDbMetadataDirectorsKey];

				continue;
			}
			
			// Writers
			value = [string stringByMatching:@"Writer(.*?):\n(.+)" options:RKLDotAll capture:2];
			
			if(value) {
				array = [NSMutableArray array];
				
				for(name in [value componentsSeparatedByString:@"\n"]) {
					name = [name stringByMatching:@"(.+?) \\(" capture:1];
					
					if([name length] > 0 && ![name isEqualToString:@"more"] && ![array containsObject:name])
						[array addObject:name];
				}
				
				if([array count] > 0)
					[metadata setObject:array forKey:SPIMDbMetadataWritersKey];
				
				continue;
			}
			
			// Release date
			value = [string stringByMatching:@"Release Date:\n(.+?) \\(" capture:1];
			
			if(value) {
				date = [_dateFormatter dateFromString:value];
				
				if(date)
					[metadata setObject:date forKey:SPIMDbMetadataReleaseDateKey];
				
				continue;	
			}
			
			// Genres
			value = [string stringByMatching:@"Genre:\n(.+?) See more" capture:1];
			
			if(value) {
				array = [NSMutableArray array];

				for(name in [value componentsSeparatedByString:@" | "]) {
					if([name length] > 0)
						[array addObject:name];
				}
				
				if([array count] > 0)
					[metadata setObject:array forKey:SPIMDbMetadataGenresKey];

				continue;
			}
			
			// Plot
			value = [string stringByMatching:@"Plot:\n(.+?) (Full summary|Full synopsis|\\|)" capture:1];
			
			if([value length] > 0)
				[metadata setObject:value forKey:SPIMDbMetadataPlotKey];
			
			// Countries
			value = [string stringByMatching:@"Country:\n(.+)" capture:1];
			
			if(value) {
				array = [NSMutableArray array];
				
				for(name in [value componentsSeparatedByString:@" | "]) {
					if([name length] > 0)
						[array addObject:name];
				}
				
				if([array count] > 0)
					[metadata setObject:array forKey:SPIMDbMetadataCountriesKey];
			}
		}
	}
	
	// Cast
	array = [NSMutableArray array];
	objects = [self _objectsInElement:rootElement forXQuery:@"//div[@class='info-content block']/table[@class='cast']/tr/td/a" error:error];
	
	for(object in objects) {
		name = [object stringValue];
		
		if([name length] > 0) {
			if([[[object attributeForName:@"href"] stringValue] containsSubstring:@"/name/" options:NSCaseInsensitiveSearch]) {
				[array addObject:name];
				
				if([array count] == 10)
					break;
			}
		}
	}
	
	if([array count] > 0)
		[metadata setObject:array forKey:SPIMDbMetadataCastKey];
	
	return metadata;
}



- (NSDictionary *)TVMetadataForMatch:(SPIMDbMetadataMatch *)match season:(NSUInteger)season episode:(NSUInteger)episode error:(NSError **)error {
	NSMutableDictionary		*metadata;
	NSArray					*objects, *childObjects, *valueObjects;
	NSXMLDocument			*document;
	NSXMLElement			*rootElement;
	NSString				*value;
	NSDate					*date;
	WIURL					*url;
	id						object, childObject;
	
	url			= [WIURL URLWithString:[NSSWF:@"%@episodes", [[match URL] string]]];
	metadata	= [NSMutableDictionary dictionary];
	document	= [[[NSXMLDocument alloc] initWithContentsOfURL:[url URL] options:NSXMLDocumentTidyHTML error:error] autorelease];
	
	if(!document)
		return NULL;
	
	rootElement = [document rootElement];
	
	// Table of episodes
	objects = [self _objectsInElement:rootElement forXQuery:@"//table[@cellspacing='0' and @cellpadding='0']" error:error];
	
	if(!objects)
		return NULL;
	
	for(object in objects) {
		// Episode title
		childObjects = [self _objectsInElement:object forXQuery:@".//h3" error:error];
		
		for(childObject in childObjects) {
			value = [[childObject stringValue]
				stringByMatching:[NSSWF:@"Season %u, Episode %u: (.+)", season, episode] capture:1];
			
			if([value length] == 0)
				continue;
			
			[metadata setObject:value forKey:SPIMDbTVMetadataEpisodeTitleKey];
				
			// Episode air date
			valueObjects = [self _objectsInElement:object forXQuery:@".//strong" error:error];
			
			if([valueObjects count] == 1) {
				date = [_dateFormatter dateFromString:[[valueObjects objectAtIndex:0] stringValue]];
				
				if(date)
					[metadata setObject:date forKey:SPIMDbTVMetadataEpisodeAirDateKey];
			}
			
			// Episode plot
			valueObjects = [[object stringValue] componentsSeparatedByString:@"\n"];
			
			if([valueObjects count] >= 4) {
				[metadata setObject:[[valueObjects objectAtIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
							 forKey:SPIMDbTVMetadataEpisodePlotKey];
			}
			
			return metadata;
		}
	}

	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}



- (NSImage *)posterImageForMatch:(SPIMDbMetadataMatch *)match error:(NSError **)error {
	NSImage				*image;
	
	image = [self _IMPAwardsPosterImageForMatch:match error:error];
	
	if(image)
		return image;
	
	image = [self _IMDbPosterImageForMatch:match error:error];
	
	if(image)
		return image;
	
	if(error)
		*error = [self _genericParseError];
	
	return NULL;
}

@end
