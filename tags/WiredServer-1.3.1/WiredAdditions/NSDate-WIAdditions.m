/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import <WiredAdditions/NSDate-WIAdditions.h>

@implementation NSDate(WIDateAdditions)

+ (id)dateWithISO8601String:(NSString *)string {
	return [[[self alloc] initWithISO8601String:string] autorelease];
}



- (id)initWithISO8601String:(NSString *)string {
	NSMutableString		*mutableString;
	
	if([string length] != 25)
		return NULL;
	
	mutableString = [string mutableCopy];
	[mutableString replaceCharactersInRange:NSMakeRange(10, 1) withString:@" "];
	[mutableString insertString:@" " atIndex:19];
	[mutableString deleteCharactersInRange:NSMakeRange(23, 1)];
	
	self = [self initWithString:mutableString];
	
	[mutableString release];
	
	return self;
}

@end



@implementation NSDate(WIDateLocalization)

- (NSString *)commonDateStringWithSeconds:(BOOL)seconds {
	return [self commonDateStringWithSeconds:seconds relative:YES capitalized:YES];
}



- (NSString *)commonDateStringWithSeconds:(BOOL)seconds relative:(BOOL)relative {
	return [self commonDateStringWithSeconds:seconds relative:relative capitalized:YES];
}



- (NSString *)commonDateStringWithSeconds:(BOOL)seconds relative:(BOOL)relative capitalized:(BOOL)capitalized {
	NSCalendarDate		*calendarDate, *calendarDateToday;
	NSUserDefaults		*defaults;
	NSMutableString		*time;
	NSString			*string, *date, *format;
	NSRange				range;
	BOOL				today = NO, yesterday = NO;
	
	defaults = [NSUserDefaults standardUserDefaults];
	
	if(relative) {
		calendarDate = [self dateWithCalendarFormat:NULL timeZone:NULL];
		calendarDateToday = [NSCalendarDate calendarDate];
		
		if([calendarDate dayOfCommonEra] == [calendarDateToday dayOfCommonEra])
			today = YES;
		else if([calendarDate dayOfCommonEra] == [calendarDateToday dayOfCommonEra] - 1)
			yesterday = YES;
	}
	
	date = [defaults objectForKey:NSDateFormatString];
	
	if(today || yesterday) {
		if(today)
			date = [[defaults objectForKey:NSThisDayDesignations] objectAtIndex:0];
		else if(yesterday)
			date = [[defaults objectForKey:NSPriorDayDesignations] objectAtIndex:0];
		
		if(capitalized)
			date = [date capitalizedString];
	}
	
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];
	
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
	format = [NSSWF:@"%@, %@", date, time];
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
	
	defaults = [NSUserDefaults standardUserDefaults];
	date = [defaults objectForKey:NSShortDateFormatString];
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];
	
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
	
	format = [NSSWF:@"%@, %@", date, time];
	string = [self descriptionWithCalendarFormat:format
										timeZone:NULL
										  locale:[defaults dictionaryRepresentation]];
	
	// --- fix bug where extraneous space characters would be left at the end
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
	
	defaults = [NSUserDefaults standardUserDefaults];
	time = [[defaults objectForKey:NSTimeFormatString] mutableCopy];
	
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
	
	string = [self descriptionWithCalendarFormat:time
										timeZone:NULL
										  locale:[defaults dictionaryRepresentation]];
	
	// --- fix bug where extraneous space characters would be left at the end
	while([string hasSuffix:@" "])
		string = [string substringToIndex:[string length] - 1];
	
	[time release];
	
	return string;
}

@end



@implementation NSCalendarDate(WICalendarDateAdditions)

+ (id)dateAtMidnight {
	NSCalendarDate		*date;

	date = [NSCalendarDate calendarDate];
	
	return [NSCalendarDate dateWithYear:[date yearOfCommonEra]
								  month:[date monthOfYear]
									day:[date dayOfMonth]
								   hour:0
								 minute:0
								 second:0
							   timeZone:[NSTimeZone systemTimeZone]];
}



- (NSCalendarDate *)dateByAddingDays:(int)days {
	return [self dateByAddingYears:0 months:0 days:days hours:0 minutes:0 seconds:0];
}

@end
