/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#import <WiredAdditions/WIDateFormatter.h>

@implementation WIDateFormatter

- (void)setNaturalLanguageStyle:(WIDateFormatterNaturalLanguageStyle)style {
	_naturalLanguageStyle = style;
}



- (WIDateFormatterNaturalLanguageStyle)naturalLanguageStyle {
	return _naturalLanguageStyle;
}



#pragma mark -

- (NSString *)stringFromDate:(NSDate *)date {
	NSString				*timeString, *dateString;
	NSDateFormatterStyle	style;
	NSInteger				day, today;
	
	if(_naturalLanguageStyle == WIDateFormatterNoNaturalLanguageStyle)
		return [super stringFromDate:date];
	
	day = [[date dateWithCalendarFormat:NULL timeZone:NULL] dayOfCommonEra];
	today = [[NSCalendarDate calendarDate] dayOfCommonEra];
	
	if(day == today)
		dateString = WILS(@"today", @"WIDateFormatter: this day");
	else if(day == today - 1)
		dateString = WILS(@"yesterday", @"WIDateFormatter: prior day");
	else if(day == today + 1)
		dateString = WILS(@"tomorrow", @"WIDateFormatter: next day");
	else
		return [super stringFromDate:date];
	
	if(_naturalLanguageStyle == WIDateFormatterCapitalizedNaturalLanguageStyle)
		dateString = [dateString capitalizedString];
	else
		dateString = [dateString lowercaseString];
	
	style = [self dateStyle];
	[self setDateStyle:NSDateFormatterNoStyle];
	timeString = [super stringFromDate:date];
	[self setDateStyle:style];
	
	return [NSSWF:@"%@ %@", dateString, timeString];
}

@end
