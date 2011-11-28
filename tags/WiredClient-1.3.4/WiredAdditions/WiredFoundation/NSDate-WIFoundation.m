/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import <WiredFoundation/NSDate-WIFoundation.h>

@implementation NSDate(WIFoundation)

+ (NSDate *)dateAtStartOfCurrentDay {
	NSDate				*date;
	NSDateComponents	*components;
	
	date = [NSDate date];
	
	components = [[NSCalendar currentCalendar] components:NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit fromDate:date];
	[components setHour:-[components hour]];
	[components setMinute:-[components minute]];
	[components setSecond:-[components second]];
	
	return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
}



+ (NSDate *)dateAtStartOfCurrentWeek {
	NSDate				*date;
	NSDateComponents	*components;
	
	date = [self dateAtStartOfCurrentDay];
	
	components = [[NSCalendar currentCalendar] components:NSWeekdayCalendarUnit fromDate:date];
	[components setWeekday:-[components weekday] + 1];
	
	return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
}



+ (NSDate *)dateAtStartOfCurrentMonth {
	NSDate				*date;
	NSDateComponents	*components;
	
	date = [self dateAtStartOfCurrentDay];
	
	components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:date];
	[components setDay:-[components day] + 1];
	
	return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
}



+ (NSDate *)dateAtStartOfCurrentYear {
	NSDate				*date;
	NSDateComponents	*components;
	
	date = [self dateAtStartOfCurrentMonth];
	
	components = [[NSCalendar currentCalendar] components:NSMonthCalendarUnit fromDate:date];
	[components setMonth:-[components month] + 1];
	
	return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:date options:0];
}



#pragma mark -

- (BOOL)isAtBeginningOfAnyEpoch {
	return ([self isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0.0]] ||
			[self isEqualToDate:[NSDate dateWithTimeIntervalSinceReferenceDate:0.0]]);
}



- (NSDate *)dateByAddingDays:(NSInteger)days {
	NSDateComponents	*components;
	
	components = [[[NSDateComponents alloc] init] autorelease];
	[components setDay:days];
	
	return [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
}

@end
