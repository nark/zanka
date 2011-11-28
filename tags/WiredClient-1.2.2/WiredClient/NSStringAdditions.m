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

#import "NSStringAdditions.h"

@implementation NSString(WCStringChecksumming)

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], password[SHA_DIGEST_LENGTH * 2 + 1];
	int						i;

	// --- calculate the checksum
	SHA1_Init(&c);
	SHA1_Update(&c, (unsigned char *) [self UTF8String], strlen([self UTF8String]));
	SHA1_Final(sha, &c);

	// --- map into hexademical characters
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		password[i+i]	= hex[sha[i] >> 4];
		password[i+i+1]	= hex[sha[i] & 0x0F];
	}
		
	// --- terminate
	password[i+i] = '\0';
	
	// --- return an autoreleased NSString of it
	return [NSString stringWithCString:(char *) password];
}

@end



@implementation NSString (WCStringConvenience)

- (unsigned int)UTF8StringLength {
	return strlen([self UTF8String]);
}

@end



@implementation NSString(WCStringFormatting)

- (long long)longLongValue {
    NSScanner		*scanner;
    long long		longLongValue;
	
	scanner = [[NSScanner alloc] initWithString:self];
	
	if(![scanner scanLongLong:&longLongValue])
		longLongValue = 0;
	
	[scanner release];
	
	return longLongValue;
}



- (unsigned long long)unsignedLongLongValue {
	return (unsigned long long) [self longLongValue];
}



- (unsigned int)unsignedIntValue {
	return (unsigned int) [self intValue];
}

@end




@implementation NSString(WCHumanReadableFormatting)

+ (NSString *)humanReadableStringForTimeInterval:(NSTimeInterval)interval {
	NSString		*string;
	unsigned int	days, hours, minutes, seconds;
	BOOL			past = NO;
	
	interval = rint(interval);
	
	if(interval < 0) {
		past = YES;
		interval = -interval;
	}
	
	days = interval / 86400;
	interval -= days * 86400;
	
	hours = interval / 3600;
	interval -= hours * 3600;
	
	minutes = interval / 60;
	interval -= minutes * 60;
	
	seconds = interval;
	
	if(days > 0) {
		string = [NSString stringWithFormat:
			NSLocalizedString(@"%u:%0.2u:%0.2u:%0.2u days", "Time strings (days, hours, minutes, seconds)"),
			days, hours, minutes, seconds];
	}
	else if(hours > 0) {
		string = [NSString stringWithFormat:
			NSLocalizedString(@"%0.2u:%0.2u:%0.2u hours", "Time strings (hours, minutes, seconds)"),
			hours, minutes, seconds];
	}
	else if(minutes > 0) {
		string = [NSString stringWithFormat:
			NSLocalizedString(@"%0.2u:%0.2u minutes", "Time strings (minutes, seconds)"),
			minutes, seconds];
	}
	else {
		string = [NSString stringWithFormat:
			NSLocalizedString(@"00:%0.2u seconds", @"Time string (minutes, seconds)"),
			seconds];
	}
	
	if(past)
		string = [NSString stringWithFormat:NSLocalizedString(@"%@ ago", @"Time string"), string];
	
	return string;
}



+ (NSString *)humanReadableStringForSize:(unsigned long long)size {
	NSNumberFormatter	*formatter;
    double				kb, mb, gb, tb, pb;
	
	// --- localize floats
	formatter = [[[NSNumberFormatter alloc] init] autorelease];
	[formatter setLocalizesFormat:YES];
	[formatter setFormat:@"###,##0.0"];
	
	// --- switch sizes
	if(size < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%llu bytes", "Size strings"),
			size];
	}
	
	kb = size / 1024;
	
	if(kb < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ KB", "Size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:kb]]];
	}
	
	mb = kb / 1024;
	
	if(mb < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ MB", "Size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:mb]]];
	}
	
	gb = mb / 1024;
	
	if(gb < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ GB", "Size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:gb]]];
	}
	
	tb = gb / 1024;
	
	if(tb < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ TB", "Size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:tb]]];
	}
	
	pb = tb / 1024;
	
	if(pb < 1000) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@ PB", "Size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:pb]]];
	}
	
	return NULL;
}



+ (NSString *)humanReadableStringWithBytesForSize:(unsigned long long)size {
	NSNumberFormatter   *formatter;
	NSString			*string;
	
	string = [NSString humanReadableStringForSize:size];
	
	if(size > 1024) {
		// --- localize number
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setLocalizesFormat:YES];
		[formatter setFormat:@"###,###,###"];
		
		// --- create string
		string = [NSString stringWithFormat:@"%@ (%@ %@)",
			string,
			[formatter stringForObjectValue:[NSNumber numberWithUnsignedLongLong:size]],
			size == 1
				? NSLocalizedString(@"byte", @"Byte singular")
				: NSLocalizedString(@"bytes", @"Byte plural")];
		
		[formatter release];
	}

	return string;
}

@end



@implementation NSString(WCClientVersionFormatting)

- (NSString *)clientVersion {
	NSString		*unknown, *client, *clientVersion, *os, *osVersion;
	NSScanner		*scanner;
	
	// --- example of a version string:
	//     Wired Client/1.0 (Darwin; 7.3.0; powerpc)
	//     (OpenSSL 0.9.6i Feb 19 2003; CoreFoundation 299.3; AppKit 743.20)
	
	// --- create scanner
	unknown = NSLocalizedString(@"Unknown", @"Unknown client");
	scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:NULL];
	
	// --- scan client
	if(![scanner scanUpToString:@"/" intoString:&client])
		return unknown;
	
	// --- skip /
	if(![scanner scanString:@"/" intoString:NULL])
		return unknown;
	
	// --- scan client version number
	if(![scanner scanUpToString:@" " intoString:&clientVersion])
		return unknown;
	
	// --- skip (
	if(![scanner scanString:@" (" intoString:NULL])
		return unknown;

	// --- scan os
	if(![scanner scanUpToString:@";" intoString:&os])
		return unknown;
	
	// --- skip ;
	if(![scanner scanString:@"; " intoString:NULL])
		return unknown;
	
	// --- scan os version number
	if(![scanner scanUpToString:@";" intoString:&osVersion])
		return unknown;
	
	return [NSString stringWithFormat:
		NSLocalizedString(@"%@ %@ on %@ %@",
						  @"Client version (client, client version, os, os version)"),
		client, clientVersion, os, osVersion];
}

@end



@implementation NSString(WCURLFormatting)

- (NSString *)stringByAddingURLPercentEscapes {
	NSString	*string;
	
	string = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
		(CFStringRef) self, CFSTR(""), CFSTR("@:"), kCFStringEncodingUTF8);
		
	return [string autorelease];
}



- (NSString *)stringByReplacingURLPercentEscapes {
	NSString	*string;
	
	string = (NSString *) CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,
		(CFStringRef) self, CFSTR(""));

	return [string autorelease];
}

@end