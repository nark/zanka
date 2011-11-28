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

#import "SPFilenameMetadataGatherer.h"

@interface SPFilenameMetadataGathererTests : SenTestCase

@end



@implementation SPFilenameMetadataGathererTests

- (void)testMetadata {
	NSDictionary				*metadata;
	SPFilenameMetadataGatherer	*gatherer;
	
	gatherer = [SPFilenameMetadataGatherer sharedGatherer];
	
	metadata = [gatherer metadataForName:@"TV_Show.1x05.Episode.Name.DVDRip.AC3.LiMITED.iTALiAN.XVID-Rel3aseGroup.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"TV_Show.", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:1], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");
	
	metadata = [gatherer metadataForName:@"TV.Show.S01E05.PDTV.XviD-Rel3aseGroup.[AnotherRel3aseGroup].avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"TV.Show.", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:1], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");
	
	metadata = [gatherer metadataForName:@"TV-Show.S01E05.720p.HDTV.X264-Rel3aseGroup.mkv"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"TV-Show.", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:1], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");
	
	metadata = [gatherer metadataForName:@"Movie.[2008].RDQ.DVDRIP.XVID.[Language]-Rel3aseGroup.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"Movie.[2008].RDQ.DVDRIP.XVID.[Language]-Rel3aseGroup.avi", @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"], @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"], @"");
	
	metadata = [gatherer metadataForName:@"Movie.2008.DVDRip.Xvid.AC3.5.1.Language.Rel3aseGroup.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"Movie.2008.DVDRip.Xvid.AC3.5.1.Language.Rel3aseGroup.avi", @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"], @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"], @"");
	
	metadata = [gatherer metadataForName:@"rel3asegroup-movie-blu720p.mkv"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"rel3asegroup-movie-blu720p.mkv", @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"], @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"], @"");
	
	metadata = [gatherer metadataForName:@"S1-E05.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"S1-E05.avi", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:1], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");
	
	metadata = [gatherer metadataForName:@"Limited.Movie.R5.LINE.XviD-Rel3aseGroup\u2122 {Anything}.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"Limited.Movie.R5.LINE.XviD-Rel3aseGroup\u2122 {Anything}.avi", @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"], @"");
	STAssertNil([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"], @"");
	
	metadata = [gatherer metadataForName:@"TV Show [10x05] Episode Name.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"TV Show [", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:10], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");

	metadata = [gatherer metadataForName:@"TV_Show_05.DVD.avi"];
	
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTitleKey"],
						 @"TV_Show_", @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowSeasonKey"],
						 [NSNumber numberWithUnsignedInteger:1], @"");
	STAssertEqualObjects([metadata objectForKey:@"SPFilenameMetadataTVShowEpisodeKey"],
						 [NSNumber numberWithUnsignedInteger:5], @"");
}

@end
