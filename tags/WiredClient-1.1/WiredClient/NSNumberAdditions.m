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

#import "NSNumberAdditions.h"

@implementation NSNumber(WCHumanReadable)

- (NSString *)humanReadableSize {
	NSString			*string;
	NSNumberFormatter	*formatter;
	NSArray				*prefixes;
	unsigned long long	bytes;
	unsigned int		power = 0;
	double				value;
	
	// --- get number
	bytes = [self unsignedLongLongValue];
	
	// --- localize floats
	formatter = [[NSNumberFormatter alloc] init];
	[formatter setLocalizesFormat:YES];
	[formatter setFormat:@"###,##0.0"];

	// --- SI prefixes
	prefixes = [NSArray arrayWithObjects:@"",
		NSLocalizedString(@"K", @"10^3 prefix"),
		NSLocalizedString(@"M", @"10^6 prefix"),
		NSLocalizedString(@"G", @"10^9 prefix"),
		NSLocalizedString(@"T", @"10^12 prefix"),
		NSLocalizedString(@"P", @"10^15 prefix"),
		NSLocalizedString(@"E", @"10^18 prefix"),
		NULL];
	
	// --- figure out which prefix to do
	while(bytes > pow(1024, ++power))
		;
		
	value = (double) bytes / pow(1024, --power);
	
	if(power == 0) {
		// --- no floating point for bytes
		string = [NSString stringWithFormat:@"%d %@",
			(unsigned int) value,
			(unsigned int) value == 1
				? NSLocalizedString(@"byte", @"Byte singular")
				: NSLocalizedString(@"bytes", @"Byte plural")];
	} else {
		string = [NSString stringWithFormat:@"%@ %@%@",
			[formatter stringForObjectValue:[NSNumber numberWithDouble:value]],
			[prefixes objectAtIndex:power],
			NSLocalizedString(@"B", @"Abbreviation of 'bytes'")];
	}
	
	[formatter release];
	
	return string;
}



- (NSString *)humanReadableSizeWithBytes {
	NSNumberFormatter	*formatter;
	NSString			*string;
	
	if([self unsignedIntValue] <= 1024) {
		// --- just get bytes
		string = [self humanReadableSize];
	} else {
		// --- localize number
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setLocalizesFormat:YES];
		[formatter setFormat:@"###,###,###"];
		
		// --- create string
		string = [NSString stringWithFormat:@"%@ (%@ %@)",
			[self humanReadableSize],
			[formatter stringForObjectValue:self],
			[self unsignedIntValue] == 1
				? NSLocalizedString(@"byte", @"Byte singular")
				: NSLocalizedString(@"bytes", @"Byte plural")];
		
		[formatter release];
	}

	return string;
}



- (NSString *)humanReadableTime {
	NSString			*string;
	unsigned int		days, hours, minutes, seconds;
	unsigned long long	time;
	
	time = [self longLongValue];
	
	days = time / 86400;
	time = time % 86400;
			
	hours = time / 3600;
	time = time % 3600;
			
	minutes = time / 60;
	time = time % 60;
			
	seconds = time;

	if(days > 0) {
		string = [NSString stringWithFormat:@"%u:%0.2u:%0.2u:%0.2u %@", days, hours, minutes, seconds, NSLocalizedString(@"days", "Time strings")];
	}
	else if(hours > 0) {
		string = [NSString stringWithFormat:@"%0.2u:%0.2u:%0.2u %@", hours, minutes, seconds, NSLocalizedString(@"hours", "Time strings")];
	}
	else if(minutes > 0) {
		string = [NSString stringWithFormat:@"%0.2u:%0.2u %@", minutes, seconds, NSLocalizedString(@"minutes", "Time strings")];
	}
	else {
		string = [NSString stringWithFormat:@"00:%0.2u %@", seconds, NSLocalizedString(@"seconds", "Time strings")];
	}
	
	return string;
}

@end



@implementation NSNumber(WCBandwidth)

- (NSString *)bandwidth {
	unsigned int	speed;
	
	speed = [self unsignedIntValue];
	
	if(speed > 0) {
		if(speed <= 3600)
			return NSLocalizedString(@"28.8k Modem", "Bandwidth");
		else if(speed <= 4200)
			return NSLocalizedString(@"33.6k Modem", "Bandwidth");
		else if(speed <= 7000)
			return NSLocalizedString(@"56k Modem", "Bandwidth");
		else if(speed <= 8000)
			return NSLocalizedString(@"64k ISDN", "Bandwidth");
		else if(speed <= 16000)
			return NSLocalizedString(@"128k ISDN/DSL", "Bandwidth");
		else if(speed <= 32000)
			return NSLocalizedString(@"256k DSL/Cable", "Bandwidth");
		else if(speed <= 48000)
			return NSLocalizedString(@"384k DSL/Cable", "Bandwidth");
		else if(speed <= 64000)
			return NSLocalizedString(@"512k DSL/Cable", "Bandwidth");
		else if(speed <= 96000)
			return NSLocalizedString(@"768k DSL/Cable", "Bandwidth");
		else if(speed <= 128000)
			return NSLocalizedString(@"1M DSL/Cable", "Bandwidth");
		else if(speed <= 256000)
			return NSLocalizedString(@"2M DSL/Cable", "Bandwidth");
		else if(speed <= 1280000)
			return NSLocalizedString(@"10M LAN", "Bandwidth");
		else if(speed <= 12800000)
			return NSLocalizedString(@"100M LAN", "Bandwidth");
	}
	
	return NSLocalizedString(@"Unknown", "Bandwidth");
}

@end
