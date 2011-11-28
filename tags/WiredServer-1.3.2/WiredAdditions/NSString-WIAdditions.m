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

#import <WiredAdditions/NSScanner-WIAdditions.h>
#import <WiredAdditions/NSString-WIAdditions.h>

@implementation NSString (WIStringAdditions)

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

	return [(NSString *) string autorelease];
}



#pragma mark -

- (NSUInteger)UTF8StringLength {
	return strlen([self UTF8String]);
}



#if MAC_OS_X_VERSION_10_5 > MAC_OS_X_VERSION_MAX_ALLOWED

- (NSInteger)integerValue {
	return [self intValue];
}



- (long long)longLongValue {
	NSScanner		*scanner;
	long long		longLongValue;

	if([self length] < 10) {
		return [self intValue];
	} else {
		scanner = [[NSScanner alloc] initWithString:self];

		if(![scanner scanLongLong:&longLongValue])
			longLongValue = 0;

		[scanner release];

		return longLongValue;
	}
}

#endif



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
 

- (BOOL)containsSubstring:(NSString *)string options:(unsigned int)options {
	return ([self rangeOfString:string options:options].location != NSNotFound);
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
		(CFStringRef) self, CFSTR("#"), NULL, kCFStringEncodingUTF8);
	
	return [string autorelease];
}



- (NSString *)stringByAddingURLPercentEscapesToAllCharacters {
	NSString	*string;
	
	string = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
		(CFStringRef) self, NULL, NULL, kCFStringEncodingUTF8);
	
	return [string autorelease];
}



- (NSString *)stringByReplacingURLPercentEscapes {
	NSString	*string;
	
	string = (NSString *) CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,
		(CFStringRef) self, CFSTR(""));
	
	return [string autorelease];
}



#pragma mark -

- (NSString *)stringByApplyingFilter:(WITextFilter *)filter {
	NSMutableString	*string;
	
	string = [self mutableCopy];
	[string applyFilter:filter];
	
	return [string autorelease];
}

@end



@implementation NSString(WIStringChecksumming)

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], password[SHA_DIGEST_LENGTH * 2 + 1];
	NSUInteger				i;
	
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



@implementation NSString(WIHumanReadableStringFormatting)

+ (NSString *)humanReadableStringForTimeInterval:(NSTimeInterval)interval {
	NSString		*string;
	NSUInteger		days, hours, minutes, seconds;
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
			WILS(@"%lu:%0.2lu:%0.2lu:%0.2lu days", @"NSString-WIAdditions: time strings (days, hours, minutes, seconds)"),
			days, hours, minutes, seconds];
	}
	else if(hours > 0) {
		string = [NSSWF:
			WILS(@"%0.2lu:%0.2lu:%0.2lu hours", @"NSString-WIAdditions: time strings (hours, minutes, seconds)"),
			hours, minutes, seconds];
	}
	else if(minutes > 0) {
		string = [NSSWF:
			WILS(@"%0.2lu:%0.2lu minutes", @"NSString-WIAdditions: time strings (minutes, seconds)"),
			minutes, seconds];
	}
	else {
		string = [NSSWF:
			WILS(@"00:%0.2lu seconds", @"NSString-WIAdditions: time string (minutes, seconds)"),
			seconds];
	}

	if(past)
		string = [NSSWF:WILS(@"%@ ago", @"NSString-WIAdditions: time string"), string];

	return string;
}



+ (NSString *)humanReadableStringForSizeInBytes:(unsigned long long)size {
	static NSNumberFormatter	*formatter;
	double						kb, mb, gb, tb, pb;

	if(!formatter) {
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setLocalizesFormat:YES];
		[formatter setFormat:@"###,##0.0"];
	}

	if(size < 1000) {
		return [NSSWF:WILS(@"%llu bytes", @"NSString-WIAdditions: byte size strings"),
			size];
	}

	kb = (double) size / 1024.0;

	if(kb < 1000) {
		return [NSSWF:WILS(@"%@ KB", @"NSString-WIAdditions: byte size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:kb]]];
	}

	mb = (double) kb / 1024.0;

	if(mb < 1000) {
		return [NSSWF:WILS(@"%@ MB", @"NSString-WIAdditions: byte size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:mb]]];
	}

	gb = (double) mb / 1024.0;

	if(gb < 1000) {
		return [NSSWF:WILS(@"%@ GB", @"NSString-WIAdditions: byte size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:gb]]];
	}

	tb = (double) gb / 1024.0;

	if(tb < 1000) {
		return [NSSWF:WILS(@"%@ TB", @"NSString-WIAdditions: byte size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:tb]]];
	}

	pb = (double) tb / 1024.0;

	if(pb < 1000) {
		return [NSSWF:WILS(@"%@ PB", @"NSString-WIAdditions: byte size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:pb]]];
	}

	return NULL;
}



+ (NSString *)humanReadableStringForSizeInBytes:(unsigned long long)size withBytes:(BOOL)bytes {
	static NSNumberFormatter   *formatter;
	NSString					*string;

	string = [NSString humanReadableStringForSizeInBytes:size];

	if(size > 1024 && bytes) {
		if(!formatter) {
			formatter = [[NSNumberFormatter alloc] init];
			[formatter setLocalizesFormat:YES];
			[formatter setFormat:@"###,###,###"];
		}

		string = [NSSWF:@"%@ (%@ %@)",
			string,
			[formatter stringForObjectValue:[NSNumber numberWithUnsignedLongLong:size]],
			size == 1
				? WILS(@"byte", @"NSString-WIAdditions: 'byte' singular")
				: WILS(@"bytes", @"NSString-WIAdditions: 'byte' plural")];
	}

	return string;
}



+ (NSString *)humanReadableStringForSizeInBits:(unsigned long long)size {
	static NSNumberFormatter	*formatter;
	double						kb, mb, gb, tb, pb;
	
	if(!formatter) {
		formatter = [[NSNumberFormatter alloc] init];
		[formatter setLocalizesFormat:YES];
		[formatter setFormat:@"###,##0.0"];
	}
	
	if(size < 1000) {
		return [NSSWF:WILS(@"%llu bits", @"NSString-WIAdditions: bit size strings"),
			size];
	}
	
	kb = (double) size / 1024.0;
	
	if(kb < 1000) {
		return [NSSWF:WILS(@"%@ kbit", @"NSString-WIAdditions: bit size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:kb]]];
	}
	
	mb = (double) kb / 1024.0;
	
	if(mb < 1000) {
		return [NSSWF:WILS(@"%@ Mbit", @"NSString-WIAdditions: bit size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:mb]]];
	}
	
	gb = (double) mb / 1024.0;
	
	if(gb < 1000) {
		return [NSSWF:WILS(@"%@ Gbit", @"NSString-WIAdditions: bit size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:gb]]];
	}
	
	tb = (double) gb / 1024.0;
	
	if(tb < 1000) {
		return [NSSWF:WILS(@"%@ Tbit", @"NSString-WIAdditions: bit size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:tb]]];
	}
	
	pb = (double) tb / 1024.0;
	
	if(pb < 1000) {
		return [NSSWF:WILS(@"%@ Pbit", @"NSString-WIAdditions: bit size strings"),
			[formatter stringForObjectValue:[NSNumber numberWithDouble:pb]]];
	}
	
	return NULL;
}



+ (NSString *)humanReadableStringForBandwidth:(NSUInteger)speed {
	if(speed > 0) {
		if(speed <= 3600)
			return WILS(@"28.8k Modem", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 4200)
			return WILS(@"33.6k Modem", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 7000)
			return WILS(@"56k Modem", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 8000)
			return WILS(@"64k ISDN", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 16000)
			return WILS(@"128k ISDN/DSL", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 32000)
			return WILS(@"256k DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 48000)
			return WILS(@"384k DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 64000)
			return WILS(@"512k DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 96000)
			return WILS(@"768k DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 128000)
			return WILS(@"1M DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 256000)
			return WILS(@"2M DSL/Cable", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 1280000)
			return WILS(@"10M LAN", @"NSString-WIAdditions: bandwidth strings");
		else if(speed <= 12800000)
			return WILS(@"100M LAN", @"NSString-WIAdditions: bandwidth strings");
	}
	
	return WILS(@"Unknown", @"NSString-WIAdditions: bandwidth strings");
}

@end



@implementation NSString(WIWiredVersionStringFormatting)

- (NSString *)wiredVersion {
	NSString			*unknown, *client, *clientVersion, *os, *osVersion, *arch;
	NSScanner			*scanner;
	const NXArchInfo	*info;

	// "Wired Client/1.0 (Darwin; 7.3.0; powerpc) (OpenSSL 0.9.6i Feb 19 2003; CoreFoundation 299.3; AppKit 743.20)"

	unknown = WILS(@"Unknown", @"NSString-WIAdditions: unknown Wired client");
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

	if(![scanner scanString:@"; " intoString:NULL])
		return unknown;

	if(![scanner scanUpToString:@")" intoString:&arch])
		return unknown;

	if([arch isEqualToString:@"powerpc"])
		arch = @"ppc";
	
	info = NXGetArchInfoFromName([arch UTF8String]);
	
	if(info)
		arch = [NSSWF:@"%s", info->description];

	return [NSSWF:
		WILS(@"%@ %@ on %@ %@ (%@)", @"NSString-WIAdditions: Wired client version (client, client version, os, os version, architecture)"),
		client, clientVersion, os, osVersion, arch];
}

@end



@implementation NSMutableString(WIMutableStringAdditions)

- (void)applyFilter:(WITextFilter *)filter {
	[filter performSelector:@selector(filter:) withObject:self];
}

@end



@implementation NSAttributedString(WIAttributedStringAdditions)

+ (id)attributedString {
	return [[[self alloc] initWithString:@""] autorelease];
}



+ (id)attributedStringWithString:(NSString *)string {
	return [[[self alloc] initWithString:string] autorelease];
}



+ (id)attributedStringWithString:(NSString *)string attributes:(NSDictionary *)attributes {
	return [[[self alloc] initWithString:string attributes:attributes] autorelease];
}



#pragma mark -

- (NSAttributedString *)attributedStringByApplyingFilter:(WITextFilter *)filter {
	NSMutableAttributedString	*string;
	
	string = [self mutableCopy];
	[string applyFilter:filter];
	
	return [string autorelease];
}



- (NSAttributedString *)attributedStringByReplacingAttachmentsWithStrings {
	NSMutableAttributedString	*string;
	
	string = [self mutableCopy];
	[string replaceAttachmentsWithStrings];
	
	return [string autorelease];
}

@end



@implementation NSMutableAttributedString(WIMutableAttributedStringAdditions)

- (void)applyFilter:(WITextFilter *)filter {
	[filter performSelector:@selector(filter:) withObject:self];
}



- (void)replaceAttachmentsWithStrings {
	NSString		*string, *markerString;
	id				attachment;
	NSRange			range, searchRange;
	
	if(![self containsAttachments])
		return;
	
	markerString			= [NSString stringWithFormat:@"%C", NSAttachmentCharacter];
	searchRange.location	= 0;
	searchRange.length		= [self length];
	
	while((range = [[self string] rangeOfString:markerString options:NSLiteralSearch range:searchRange]).location != NSNotFound) {
		attachment = [self attribute:NSAttachmentAttributeName
							 atIndex:range.location
					  effectiveRange:nil];
		
		string = NULL;
		
		if([attachment respondsToSelector:@selector(string)])
			string = [attachment performSelector:@selector(string)];
		
		if(!string)
			string = @"<<attachment>>";
		
		[self removeAttribute:NSAttachmentAttributeName range:range];
		[self replaceCharactersInRange:range withString:string];
		
		searchRange.location	= range.location + [string length];
		searchRange.length		= [self length] - searchRange.location;
	}
}

@end
