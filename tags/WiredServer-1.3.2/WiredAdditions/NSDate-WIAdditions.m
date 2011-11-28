/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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



@implementation NSCalendarDate(WICalendarDateAdditions)

+ (id)dateAtStartOfCurrentDay {
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



+ (id)dateAtStartOfCurrentWeek {
	NSCalendarDate		*date;
	NSInteger			dayOfWeek;

	date = [self dateAtStartOfCurrentDay];
	dayOfWeek = [date dayOfWeek];
	
	return [date dateByAddingDays:(dayOfWeek == 0) ? -6 : -dayOfWeek + 1];
}



+ (id)dateAtStartOfCurrentMonth {
	NSCalendarDate		*date;
	
	date = [NSCalendarDate calendarDate];
	
	return [NSCalendarDate dateWithYear:[date yearOfCommonEra]
								  month:[date monthOfYear]
									day:1
								   hour:0
								 minute:0
								 second:0
							   timeZone:[NSTimeZone systemTimeZone]];
}



+ (id)dateAtStartOfCurrentYear {
	NSCalendarDate		*date;
	
	date = [NSCalendarDate calendarDate];
	
	return [NSCalendarDate dateWithYear:[date yearOfCommonEra]
								  month:1
									day:1
								   hour:0
								 minute:0
								 second:0
							   timeZone:[NSTimeZone systemTimeZone]];
}



- (NSCalendarDate *)dateByAddingDays:(NSInteger)days {
	return [self dateByAddingYears:0 months:0 days:days hours:0 minutes:0 seconds:0];
}

@end
