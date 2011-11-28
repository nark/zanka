/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import <ZankaAdditions/NSScanner-ZAAdditions.h>
#import <ZankaAdditions/NSString-ZAAdditions.h>

@implementation NSString (ZAStringAdditions)

+ (NSString *)stringWithFormat:(NSString *)format arguments:(va_list)arguments {
	return [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
}



+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding {
	return [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
}



#pragma mark -

+ (NSString *)UUIDString { 
	CFUUIDRef		uuid;
	CFStringRef		string;

	uuid = CFUUIDCreate(NULL);
	string = CFUUIDCreateString(NULL, uuid);
	CFRelease(uuid);

	return [(NSString *)string autorelease];
}



#pragma mark -

- (unsigned int)UTF8StringLength {
	return strlen([self UTF8String]);
}



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



#pragma mark -

- (BOOL)containsSubstring:(NSString *)string {
	return ([self rangeOfString:string].location != NSNotFound);
}
 
 
- (BOOL)containsCharactersFromSet:(NSCharacterSet *)set {
	return ([self rangeOfCharacterFromSet:set].location != NSNotFound);
}



- (BOOL)isComposedOfCharactersFromSet:(NSCharacterSet *)set {
	return ![self containsCharactersFromSet:[set invertedSet]];
}



#pragma mark -

- (NSArray *)componentsSeparatedByCharactersFromSet:(NSCharacterSet *)set {
	NSScanner		*scanner;
	NSMutableArray	*components;
	NSCharacterSet	*invertedSet;
	NSString		*string;

	if([self length] == 0)
		return NULL;

	if(![self containsCharactersFromSet:set])
		return [NSArray arrayWithObject:self];

	scanner = [NSScanner scannerWithString:self];
	components = [NSMutableArray array];
	invertedSet = [set invertedSet];
		
	while(![scanner isAtEnd]) {
		[scanner scanUpToCharactersFromSet:set intoString:NULL];
		[scanner scanUpToCharactersFromSet:invertedSet intoString:&string];

		if([string length] > 0)
			[components addObject:string];
	}

	return components;
}



#pragma mark -

- (NSString *)stringByReplacingOccurencesOfString:(NSString *)target withString:(NSString *)replacement {
	NSMutableString		*string;

	string = [self mutableCopy];

	[string replaceOccurrencesOfString:target
							withString:replacement
							   options:0
								 range:NSMakeRange(0, [string length])];

	return [string autorelease];
}



- (NSString *)stringByReplacingOccurencesOfStrings:(NSArray *)targets withString:(NSString *)replacement {
	NSMutableString		*string;
	NSEnumerator		*enumerator;
	NSString			*target;

	string = [self mutableCopy];
	enumerator = [targets objectEnumerator];

	while((target = [enumerator nextObject])) {
		[string replaceOccurrencesOfString:target
								withString:replacement
								   options:0
									 range:NSMakeRange(0, [string length])];
	}

	return [string autorelease];
}



- (NSString *)stringByRemovingSurroundingWhitespace {
	static NSCharacterSet		*nonWhitespace;
	NSRange						first, last;
	
	if (!nonWhitespace)
		nonWhitespace = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] retain];
	
	first = [self rangeOfCharacterFromSet:nonWhitespace];
	
	if(first.location == NSNotFound)
		return @"";
	
	last = [self rangeOfCharacterFromSet:nonWhitespace options:NSBackwardsSearch];
	
	if(first.location == 0 && last.location == [self length] - 1)
		return self;

	return [self substringWithRange:NSUnionRange(first, last)];
}


#pragma mark -

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



@implementation NSString(ZAStringChecksumming)

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], password[SHA_DIGEST_LENGTH * 2 + 1];
	int						i;
	
	SHA1_Init(&c);
	SHA1_Update(&c, (unsigned char *) [self UTF8String], strlen([self UTF8String]));
	SHA1_Final(sha, &c);
	
	for(i = 0; i < SHA_DIGEST_LENGTH; i++) {
		password[i+i]	= hex[sha[i] >> 4];
		password[i+i+1]	= hex[sha[i] & 0x0F];
	}
	
	password[i+i] = '\0';
	
	return [NSString stringWithCString:(char *) password];
}

@end



@implementation NSString(ZAHumanReadableStringFormatting)

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
		string = [NSSWF:
			NSLocalizedStringFromTableInBundle(@"%u:%0.2u:%0.2u:%0.2u days", NULL, [ZAObject bundle], @"NSString-ZAAdditions: time strings (days, hours, minutes, seconds)"),
			days, hours, minutes, seconds];
	}
	else if(hours > 0) {
		string = [NSSWF:
			NSLocalizedStringFromTableInBundle(@"%0.2u:%0.2u:%0.2u hours", NULL, [ZAObject bundle], @"NSString-ZAAdditions: time strings (hours, minutes, seconds)"),
			hours, minutes, seconds];
	}
	else if(minutes > 0) {
		string = [NSSWF:
			NSLocalizedStringFromTableInBundle(@"%0.2u:%0.2u minutes", NULL, [ZAObject bundle], @"NSString-ZAAdditions: time strings (minutes, seconds)"),
			minutes, seconds];
	}
	else {
		string = [NSSWF:
			NSLocalizedStringFromTableInBundle(@"00:%0.2u seconds", NULL, [ZAObject bundle], @"NSString-ZAAdditions: time string (minutes, seconds)"),
			seconds];
	}

	if(past)
		string = [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ ago", NULL, [ZAObject bundle], @"NSString-ZAAdditions: time string"), string];

	return string;
}



+ (NSString *)humanReadableStringForSize:(unsigned long long)size {
	static NSNumberFormatter	*formatter;
	double						kb, mb, gb, tb, pb;

	if(!formatter) {
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setLocalizesFormat:YES];
		[formatter setFormat:@"###,##0.0"];
	}

	if(size < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%llu bytes", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			size];
	}

	kb = size / 1024;

	if(kb < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ KB", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:kb]]];
	}

	mb = kb / 1024;

	if(mb < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ MB", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:mb]]];
	}

	gb = mb / 1024;

	if(gb < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ GB", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:gb]]];
	}

	tb = gb / 1024;

	if(tb < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ TB", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:tb]]];
	}

	pb = tb / 1024;

	if(pb < 1000) {
		return [NSSWF:NSLocalizedStringFromTableInBundle(@"%@ PB", NULL, [ZAObject bundle], @"NSString-ZAAdditions: size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:pb]]];
	}

	return NULL;
}



+ (NSString *)humanReadableStringWithBytesForSize:(unsigned long long)size {
	static NSNumberFormatter   *formatter;
	NSString					*string;

	string = [NSString humanReadableStringForSize:size];

	if(size > 1024) {
		if(!formatter) {
			formatter = [[NSNumberFormatter alloc] init];
			[formatter setLocalizesFormat:YES];
			[formatter setFormat:@"###,###,###"];
		}

		string = [NSSWF:@"%@ (%@ %@)",
			string,
			[formatter stringForObjectValue:[NSNumber numberWithUnsignedLongLong:size]],
			size == 1
				? NSLocalizedStringFromTableInBundle(@"byte", NULL, [ZAObject bundle], @"NSString-ZAAdditions: 'byte' singular")
				: NSLocalizedStringFromTableInBundle(@"bytes", NULL, [ZAObject bundle], @"NSString-ZAAdditions: 'byte' plural")];
	}

	return string;
}



+ (NSString *)humanReadableStringForBandwidth:(unsigned int)speed {
	if(speed > 0) {
		if(speed <= 3600)
			return NSLocalizedStringFromTableInBundle(@"28.8k Modem", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 4200)
			return NSLocalizedStringFromTableInBundle(@"33.6k Modem", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 7000)
			return NSLocalizedStringFromTableInBundle(@"56k Modem", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 8000)
			return NSLocalizedStringFromTableInBundle(@"64k ISDN", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 16000)
			return NSLocalizedStringFromTableInBundle(@"128k ISDN/DSL", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 32000)
			return NSLocalizedStringFromTableInBundle(@"256k DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 48000)
			return NSLocalizedStringFromTableInBundle(@"384k DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 64000)
			return NSLocalizedStringFromTableInBundle(@"512k DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 96000)
			return NSLocalizedStringFromTableInBundle(@"768k DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 128000)
			return NSLocalizedStringFromTableInBundle(@"1M DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 256000)
			return NSLocalizedStringFromTableInBundle(@"2M DSL/Cable", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 1280000)
			return NSLocalizedStringFromTableInBundle(@"10M LAN", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
		else if(speed <= 12800000)
			return NSLocalizedStringFromTableInBundle(@"100M LAN", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
	}
	
	return NSLocalizedStringFromTableInBundle(@"Unknown", NULL, [ZAObject bundle], @"NSString-ZAAdditions: bandwidth strings");
}

@end



@implementation NSString(ZAWiredVersionStringFormatting)

- (NSString *)wiredVersion {
	NSString		*unknown, *client, *clientVersion, *os, *osVersion;
	NSScanner		*scanner;

	// "Wired Client/1.0 (Darwin; 7.3.0; powerpc) (OpenSSL 0.9.6i Feb 19 2003; CoreFoundation 299.3; AppKit 743.20)"

	unknown = NSLocalizedStringFromTableInBundle(@"Unknown", NULL, [ZAObject bundle], @"NSString-ZAAdditions: unknown Wired client");
	scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:NULL];

	if(![scanner scanUpToString:@"/" intoString:&client])
		return unknown;

	if(![scanner scanString:@"/" intoString:NULL])
		return unknown;

	if(![scanner scanUpToString:@" " intoString:&clientVersion])
		return unknown;

	if(![scanner scanString:@" (" intoString:NULL])
		return unknown;

	if(![scanner scanUpToString:@";" intoString:&os])
		return unknown;

	if(![scanner scanString:@"; " intoString:NULL])
		return unknown;

	if(![scanner scanUpToString:@";" intoString:&osVersion])
		return unknown;

	return [NSSWF:
		NSLocalizedStringFromTableInBundle(@"%@ %@ on %@ %@", NULL, [ZAObject bundle], @"NSString-ZAAdditions: Wired client version (client, client version, os, os version)"),
		client, clientVersion, os, osVersion];
}

@end



@implementation NSAttributedString(ZAAttributedStringAdditions)

+ (id)attributedString {
	return [[[self alloc] initWithString:@""] autorelease];
}



+ (id)attributedStringWithString:(NSString *)string {
	return [[[self alloc] initWithString:string] autorelease];
}



+ (id)attributedStringWithString:(NSString *)string attributes:(NSDictionary *)attributes {
	return [[[self alloc] initWithString:string attributes:attributes] autorelease];
}

@end
