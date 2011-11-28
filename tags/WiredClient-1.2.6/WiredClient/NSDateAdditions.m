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

@implementation NSDate(WCISO8601DateInterpreting)

+ (NSDate *)dateWithISO8601String:(NSString *)string {
	NSString		*date, *time, *offset;
	
	// --- all we need is length
	if([string length] < 25)
		return NULL;
	
	// --- split date/time
	time	= [string substringFromIndex:11];
	date	= [string substringToIndex:10];
	
	// --- split time/offset
	offset	= [time substringFromIndex:8];
	time	= [time substringToIndex:8];
	offset	= [NSString stringWithFormat:@"%@%@",
		[offset substringToIndex:3],
		[offset substringFromIndex:4]];
	
	return [NSDate dateWithString:[NSString stringWithFormat:@"%@ %@ %@", date, time, offset]];
}

@end



#pragma mark -

@implementation NSDate(WCDateLocalization)

- (NSString *)commonDateStringWithSeconds:(BOOL)seconds {
	return [self commonDateStringWithRelative:YES capitalized:YES seconds:seconds];
}



- (NSString *)commonDateStringWithRelative:(BOOL)relative seconds:(BOOL)seconds {
	return [self commonDateStringWithRelative:relative capitalized:YES seconds:seconds];
}



- (NSString *)commonDateStringWithRelative:(BOOL)relative capitalized:(BOOL)capitalized seconds:(BOOL)seconds {
	NSCalendarDate		*calendarDate, *calendarDateToday;
	NSUserDefaults		*defaults;
	NSMutableString		*time;
	NSString			*string, *date, *format;
	NSRange				range;
	BOOL				today = NO, yesterday = NO;
	
	// --- get user defaults
	defaults = [NSUserDefaults standardUserDefaults]; 

	// --- get calendar dates
	if(relative) {
		calendarDate = [self dateWithCalendarFormat:NULL timeZone:NULL];
		calendarDateToday = [NSCalendarDate calendarDate];
		
		if([calendarDate dayOfCommonEra] == [calendarDateToday dayOfCommonEra])
			today = YES;
		else if([calendarDate dayOfCommonEra] == [calendarDateToday dayOfCommonEra] - 1)
			yesterday = YES;
	}
	
	// --- get date format
	date = [defaults objectForKey:NSDateFormatString];
	
	// --- set relative
	if(today || yesterday) {
		if(today)
			date = [[defaults objectForKey:NSThisDayDesignations] objectAtIndex:0];
		else if(yesterday)
			date = [[defaults objectForKey:NSPriorDayDesignations] objectAtIndex:0];
		
		if(capitalized)
			date = [date capitalizedString];
	}
	
	// --- get time format
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];
	
	// --- kill seconds
	if(!seconds) {
		range = [time rangeOfString:@":%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
		
		range = [time rangeOfString:@".%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
	}
	
	// --- get final format
	format = [NSString stringWithFormat:@"%@, %@", date, time];
	string = [self descriptionWithCalendarFormat:format
										timeZone:NULL
										  locale:[defaults dictionaryRepresentation]];
	
	[time release];

	return string;
}



- (NSString *)fullDateStringWithSeconds:(BOOL)seconds {
	NSUserDefaults		*defaults;
	NSMutableString		*time;
	NSString			*string, *format, *date;
	NSRange				range;
	
	// --- get defaults
	defaults = [NSUserDefaults standardUserDefaults]; 
	
	// --- get date
	date = [defaults objectForKey:NSShortDateFormatString];
	
	// --- get time
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];;
	
	// --- fix a bug where the date formats would have 12-hour clocks
	range = [time rangeOfString:@"%H"];
	
	if(range.location != NSNotFound) {
		// --- time has 24-hour clock, adjust our format accordingly
		[time replaceOccurrencesOfString:@"%I"
							  withString:@"%H"
									options:0
								   range:NSMakeRange(0, [time length])];
	}
	
	// --- fix a bug where the date formats would have 24-hour clocks
	range = [time rangeOfString:@"%I"];
	
	if(range.location != NSNotFound) {
		// --- time has 12-hour clock, adjust our format accordingly
		[time replaceOccurrencesOfString:@"%H"
							  withString:@"%I"
								 options:0
								   range:NSMakeRange(0, [time length])];
	}
	
	// --- kill seconds
	if(!seconds) {
		range = [time rangeOfString:@":%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
		
		range = [time rangeOfString:@".%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
	}
	
	// --- get final format
	format = [NSString stringWithFormat:@"%@, %@", date, time];
	string = [self descriptionWithCalendarFormat:format
										timeZone:NULL
										  locale:[defaults dictionaryRepresentation]];
	
	// --- fix bug
	while([string hasSuffix:@" "])
		string = [string substringToIndex:[string length] - 1];
	
	[time release];
	
	return string;
}



- (NSString *)timeStringWithSeconds:(BOOL)seconds {
	NSUserDefaults		*defaults;
	NSMutableString		*time;
	NSString			*string;
	NSRange				range;
	
	// --- get defaults
	defaults = [NSUserDefaults standardUserDefaults]; 
	
	// --- get time
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];;
	
	// --- fix a bug where the date formats would have 12-hour clocks
	range = [time rangeOfString:@"%H"];
	
	if(range.location != NSNotFound) {
		// --- time has 24-hour clock, adjust our format accordingly
		[time replaceOccurrencesOfString:@"%I"
							  withString:@"%H"
								 options:0
								   range:NSMakeRange(0, [time length])];
	}
	
	// --- fix a bug where the date formats would have 24-hour clocks
	range = [time rangeOfString:@"%I"];
	
	if(range.location != NSNotFound) {
		// --- time has 12-hour clock, adjust our format accordingly
		[time replaceOccurrencesOfString:@"%H"
							  withString:@"%I"
								 options:0
								   range:NSMakeRange(0, [time length])];
	}
	
	// --- kill seconds
	if(!seconds) {
		range = [time rangeOfString:@":%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
		
		range = [time rangeOfString:@".%S"];
		
		if(range.location != NSNotFound)
			[time deleteCharactersInRange:range];
	}
	
	// --- get final format
	string = [self descriptionWithCalendarFormat:time
										timeZone:NULL
										  locale:[defaults dictionaryRepresentation]];
	
	// --- fix bug
	while([string hasSuffix:@" "])
		string = [string substringToIndex:[string length] - 1];
	
	[time release];
	
	return string;
}

@end
