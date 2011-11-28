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

#import "NSString-SPAdditions.h"
#import "SPFilenameMetadataGatherer.h"

NSString * const SPFilenameMetadataFilenameKey			= @"SPFilenameMetadataFilenameKey";
NSString * const SPFilenameMetadataTitleKey				= @"SPFilenameMetadataTitleKey";
NSString * const SPFilenameMetadataTVShowSeasonKey		= @"SPFilenameMetadataTVShowSeasonKey";
NSString * const SPFilenameMetadataTVShowEpisodeKey		= @"SPFilenameMetadataTVShowEpisodeKey";

@implementation SPFilenameMetadataGatherer

+ (SPFilenameMetadataGatherer *)sharedGatherer {
	static SPFilenameMetadataGatherer	*gatherer;
	
	if(!gatherer)
		gatherer = [[self alloc] init];
	
	return gatherer;
}



#pragma mark -

- (NSDictionary *)metadataForName:(NSString *)name {
	NSMutableDictionary		*metadata;
	NSMutableString			*title;
	NSString				*pattern, *value;
	NSArray					*patterns;
	NSRange					range;
	NSUInteger				i;
	
	metadata	= [NSMutableDictionary dictionary];
	title		= [[name mutableCopy] autorelease];
	
	// Season & episode, "1x05" & "S0105"
	patterns = [NSArray arrayWithObjects:
		@"(\\d{1,2})x(\\d{1,2})",
		@"S(\\d{1,2})-?E(\\d{1,2})",
		NULL];
	
	for(pattern in patterns) {
		for(i = 3; i > 0; i--) {
			range = [title rangeOfRegex:pattern options:RKLCaseless capture:i - 1];
			
			if(range.location == NSNotFound)
				break;
			
			switch(i - 1) {
				case 1:
				case 2:
					value = [title substringWithRange:range];
					
					if([value hasPrefix:@"0"])
						value = [value substringFromIndex:1];
					
					if([value length] == 0)
						value = @"1";
					
					if(i - 1 == 1) {
						[metadata setObject:[NSNumber numberWithUnsignedInteger:[value unsignedIntegerValue]]
									 forKey:SPFilenameMetadataTVShowSeasonKey];
					} else {
						[metadata setObject:[NSNumber numberWithUnsignedInteger:[value unsignedIntegerValue]]
									 forKey:SPFilenameMetadataTVShowEpisodeKey];
					}
					break;
				
				case 0:
					[title deleteCharactersFromIndex:range.location];
					
					break;
			}
		}
	}
	
	// Episode number without season, "05"
	if(![metadata objectForKey:SPFilenameMetadataTVShowSeasonKey] &&
	   ![metadata objectForKey:SPFilenameMetadataTVShowEpisodeKey]) {
		range = [title rangeOfRegex:@"(?:^|_|-|\\.|\\s|\\(|\\[|\\{)" @"(\\d{2})" @"(?:_|-|\\.|\\s|\\(|\\[|\\{|$)"
							options:RKLCaseless
							capture:1];
			
		if(range.location != NSNotFound) {
			value = [title substringWithRange:range];
			
			if([value hasPrefix:@"0"])
				value = [value substringFromIndex:1];
			
			if([value length] == 0)
				value = @"1";
			
			[metadata setObject:[NSNumber numberWithUnsignedInteger:1]
						 forKey:SPFilenameMetadataTVShowSeasonKey];
			[metadata setObject:[NSNumber numberWithUnsignedInteger:[value unsignedIntegerValue]]
						 forKey:SPFilenameMetadataTVShowEpisodeKey];
			
			[title deleteCharactersFromIndex:range.location];
		}
	}
	
	// Delete "CD1"
	[title replaceOccurrencesOfRegex:@" cd\\d" withString:@"" options:RKLCaseless];
	[title trimCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	// Title without season/episode
	if([title length] == 0 || [title isMatchedByRegex:@"^\\.(\\w|\\d)+$"])
		[metadata setObject:name forKey:SPFilenameMetadataTitleKey];
	else
		[metadata setObject:title forKey:SPFilenameMetadataTitleKey];
	
	// File name
	[metadata setObject:name forKey:SPFilenameMetadataFilenameKey];
	
	return metadata;
}

@end
