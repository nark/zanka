/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSDateAdditions.h"

@implementation NSDate(WCLocalizedDate)

+ (NSDate *)dateWithISO8601String:(NSString *)string {
	NSString		*date, *time, *offset;
	
	// --- split date/time
	time	= [string substringFromIndex:11];
	date	= [string substringToIndex:10];
	
	// --- split time/offset
	offset	= [time substringFromIndex:8];
	time	= [time substringToIndex:8];
	offset	= [NSString stringWithFormat:@"%@%@", [offset substringToIndex:3], [offset substringFromIndex:4]];
	
	return [NSDate dateWithString:[NSString stringWithFormat:@"%@ %@ %@", date, time, offset]];
}



#pragma mark -

- (NSString *)localizedDateWithFormat:(NSString *)format {
	NSUserDefaults		*defaults;
	NSMutableString		*mutable;
	NSString			*string, *time;
	NSRange				range;
	
	// --- get user defaults
	defaults	= [NSUserDefaults standardUserDefaults]; 

	// --- get format
	mutable		= [[defaults objectForKey:format] mutableCopy];
	time		= [defaults objectForKey:NSTimeFormatString];
	
	// --- fix a bug where the date formats would have 12-hour clocks
	range		= [time rangeOfString:@"%H"];
		
	if(range.location != NSNotFound) {
		// --- time has 24-hour clock, adjust our format accordingly
		[mutable replaceOccurrencesOfString:@"%I" withString:@"%H"
									options:0 range:NSMakeRange(0, [mutable length])];
	}

	// --- fix a bug where the date formats would have 24-hour clocks
	range		= [time rangeOfString:@"%I"];
	
	if(range.location != NSNotFound) {
		// --- time has 12-hour clock, adjust our format accordingly
		[mutable replaceOccurrencesOfString:@"%H" withString:@"%I"
									options:0 range:NSMakeRange(0, [mutable length])];
	}
	
	// --- get localized date
	string		= [self descriptionWithCalendarFormat:mutable
											 timeZone:NULL
											   locale:[defaults dictionaryRepresentation]];
	
	// --- fix bug
	if([[string substringFromIndex:[string length] - 1] isEqualToString:@" "])
		string = [string substringToIndex:[string length] - 1];

	[mutable release];
	
	return string;
}

@end
