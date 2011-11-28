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

#import "QTTrack-SPAdditions.h"

@implementation QTTrack(SPAdditions)

- (BOOL)isAudioTrack {
	return [[self attributeForKey:QTTrackMediaTypeAttribute] isEqualToString:QTMediaTypeSound];
}



- (BOOL)isVideoTrack {
	return ([[self attributeForKey:QTTrackMediaTypeAttribute] isEqualToString:QTMediaTypeVideo] &&
			![self isSubtitleTrack]);
}



- (BOOL)isSubtitleTrack {
	NSString		*type, *format;
	
	type = [self attributeForKey:QTTrackMediaTypeAttribute];
	format = [self attributeForKey:QTTrackFormatSummaryAttribute];
	
	if([type isEqualToString:QTMediaTypeVideo]) {
		return (([format rangeOfString:@"subtitle" options:NSCaseInsensitiveSearch].location != NSNotFound) ||
				([format rangeOfString:@"vobsub" options:NSCaseInsensitiveSearch].location != NSNotFound));
	}
	
	return NO;
}



#pragma mark -

- (NSString *)shortFormatSummary {
	NSString	*format;
	NSRange		range;
	
	format = [self attributeForKey:QTTrackFormatSummaryAttribute];
	range = [format rangeOfString:@","];
	
	if(range.location != NSNotFound)
		format = [format substringToIndex:range.location];
	
	return format;
}

@end
