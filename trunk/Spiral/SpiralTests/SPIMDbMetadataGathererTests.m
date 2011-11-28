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

#import "SPIMDbMetadataGatherer.h"
#import "SPIMDbMetadataMatch.h"

@interface SPIMDbMetadataGathererTests : SenTestCase

@end



@implementation SPIMDbMetadataGathererTests

- (void)testMetadata {
	NSDictionary				*metadata;
	NSArray						*matches, *correctMetadata;
	NSImage						*image;
	NSError						*error;
	SPIMDbMetadataGatherer		*gatherer;
	SPIMDbMetadataMatch			*match;
	
	// Test multiple matches
	gatherer		= [SPIMDbMetadataGatherer sharedGatherer];
	matches			= [gatherer matchesForName:@"Star Wars" error:&error];

	STAssertNotNil(matches, @"%@", error);
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars (1977)"
																   URLString:@"http://www.imdb.com/title/tt0076759/"]],
				 @"");
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars: Episode V - The Empire Strikes Back (1980)"
																   URLString:@"http://www.imdb.com/title/tt0080684/"]],
				 @"");
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars: Episode VI - Return of the Jedi (1983)"
																   URLString:@"http://www.imdb.com/title/tt0086190/"]],
				 @"");
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars: Episode I - The Phantom Menace (1999)"
																   URLString:@"http://www.imdb.com/title/tt0120915/"]],
				 @"");
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars: Episode II - Attack of the Clones (2002)"
																   URLString:@"http://www.imdb.com/title/tt0121765/"]],
				 @"");
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Star Wars: Episode III - Revenge of the Sith (2005)"
																   URLString:@"http://www.imdb.com/title/tt0121766/"]],
				 @"");
	
	// Test metadata of first match
	metadata			= [gatherer metadataForMatch:[matches objectAtIndex:0] error:&error];

	STAssertNotNil(metadata, @"%@", error);
	
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataTitleKey"], @"Star Wars", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataRatingKey"], [NSNumber numberWithDouble:8.8], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataDirectorsKey"], [NSArray arrayWithObject:@"George Lucas"], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataWritersKey"], [NSArray arrayWithObject:@"George Lucas"], @"");
	
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataReleaseDateKey"],
		[[[NSLocale localeWithLocaleIdentifier:@"en_US"] objectForKey:NSLocaleCalendar] dateFromComponents:
			[NSDateComponents dateComponentsWithYear:1977 month:12 day:16 hour:0 minute:0 second:0]],
		@"");
	
	correctMetadata = [NSArray arrayWithObjects:
		@"Action",
		@"Adventure",
		@"Fantasy",
		@"Sci-Fi",
		NULL];
	
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataGenresKey"], correctMetadata, @"");
	 
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataPlotKey"],
		@"Luke Skywalker leaves his home planet, teams up with other rebels, and tries to save Princess Leia from the evil clutches of Darth Vader.", @"");
	
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataCountriesKey"], [NSArray arrayWithObject:@"USA"], @"");

	correctMetadata = [NSArray arrayWithObjects:
		@"Mark Hamill",
		@"Harrison Ford",
		@"Carrie Fisher",
		@"Peter Cushing",
		@"Alec Guinness",
		@"Anthony Daniels",
		@"Kenny Baker",
		@"Peter Mayhew",
		@"David Prowse",
		@"James Earl Jones",
		NULL];

	STAssertEqualObjects([metadata objectForKey:@"SPIMDbMetadataCastKey"], correctMetadata, @"");
	
	// Test poster image of first match
	image = [gatherer posterImageForMatch:[matches objectAtIndex:0] error:&error];

	STAssertNotNil(image, @"%@", error);
	STAssertTrue([[image representations] count] > 0, @"");
	STAssertTrue([[[image representations] objectAtIndex:0] isKindOfClass:[NSBitmapImageRep class]], @"");
	STAssertEquals([[[image representations] objectAtIndex:0] pixelsWide], 347, @"");
	STAssertEquals([[[image representations] objectAtIndex:0] pixelsHigh], 525, @"");
	
	// Test single match
	matches  = [gatherer matchesForName:@"Det sjunde inseglet" error:&error];
	
	STAssertNotNil(matches, @"%@", error);
	STAssertTrue([matches containsObject:[SPIMDbMetadataMatch matchWithTitle:@"Det sjunde inseglet (1957)"
																   URLString:@"http://www.imdb.com/title/tt0050976/"]],
				 @"");
	
	// Test no match
	matches = [gatherer matchesForName:@"XXXXXXXXXXXXXXXXXXX" error:&error];
	
	STAssertNotNil(matches, @"%@", error);
	STAssertEqualObjects(matches, [NSArray array], @"");
	
	// Test TV metadata
	match			= [SPIMDbMetadataMatch matchWithTitle:@"\"House M.D.\" (2004)"
												URLString:@"http://www.imdb.com/title/tt0412142/"];
	metadata		= [gatherer TVMetadataForMatch:match season:1 episode:1 error:&error];
	
	STAssertNotNil(metadata, @"%@", error);
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbTVMetadataEpisodeTitleKey"], @"Pilot", @"");
	
	STAssertEqualObjects([metadata objectForKey:@"SPIMDbTVMetadataEpisodeAirDateKey"],
		[[[NSLocale localeWithLocaleIdentifier:@"en_US"] objectForKey:NSLocaleCalendar] dateFromComponents:
			[NSDateComponents dateComponentsWithYear:2004 month:11 day:16 hour:0 minute:0 second:0]],
		@"");

	STAssertEqualObjects([metadata objectForKey:@"SPIMDbTVMetadataEpisodePlotKey"],
		@"Young kindergarten teacher Rebecca Adler collapses in her classroom after uncontrolled gibberish slips out of her mouth while she is about to teach students.", @"");
	
	// Test poster image for item with no IMP Awards URL
	match			= [SPIMDbMetadataMatch matchWithTitle:@"Battlestar Galactica: Razor (2007) (TV)"
												URLString:@"http://www.imdb.com/title/tt0991178/"];
	image			= [gatherer posterImageForMatch:match error:&error];
	
	STAssertNotNil(image, @"%@", error);
	STAssertTrue([[image representations] count] > 0, @"");
	STAssertTrue([[[image representations] objectAtIndex:0] isKindOfClass:[NSBitmapImageRep class]], @"");
	STAssertEquals([[[image representations] objectAtIndex:0] pixelsWide], 240, @"");
	STAssertEquals([[[image representations] objectAtIndex:0] pixelsHigh], 340, @"");
}

@end
