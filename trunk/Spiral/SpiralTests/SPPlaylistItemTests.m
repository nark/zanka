/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPPlaylistItem.h"

@interface SPPlaylistItemTests : SenTestCase

@end



@implementation SPPlaylistItemTests

- (void)testCleanName {
	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"TV_Show.1x05.Episode.Name.DVDRip.AC3.LiMITED.iTALiAN.XVID-Rel3aseGroup.avi"] cleanName],
						 @"TV Show 1x05 Episode Name", @"");
	
	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"TV.Show.S01E05.PDTV.XviD-Rel3aseGroup.[AnotherRel3aseGroup].avi"] cleanName],
						 @"TV Show S01E05", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"TV-Show.S01E05.720p.HDTV.FRENCH.X264-Rel3aseGroup.mkv"] cleanName],
						 @"TV-Show S01E05", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"Movie.[2008].RDQ.DVDRIP.XVID.[Language]-Rel3aseGroup.avi"] cleanName],
						 @"Movie", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"Movie.2008.DVDRip.Xvid.AC3.5.1.Language.Rel3aseGroup.avi"] cleanName],
						 @"Movie Language Rel3aseGroup", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"rel3asegroup-movie-blu720p.mkv"] cleanName],
						 @"rel3asegroup-movie", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"S1-E05.avi"] cleanName],
						 @"S1-E05", @"");
	
	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"Limited.Movie.R5.LINE.XviD-Rel3aseGroup\u2122 {Anything}.avi"] cleanName],
						 @"Limited Movie", @"");
	
	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"TV Show [12x01] Episode Name.Blu-Ray.avi"] cleanName],
						 @"TV Show 12x01 Episode Name", @"");

	STAssertEqualObjects([[SPPlaylistFile itemWithName:@"TV_Show_05.DVD.www.foo.bar.com.avi"] cleanName],
						 @"TV Show 05", @"");
}

@end
