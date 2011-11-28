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

@interface NSString(ZAStringAdditions)

#ifndef NSNumericSearch
#define NSNumericSearch			64
#endif


+ (NSString *)stringWithFormat:(NSString *)format arguments:(va_list)arguments;
+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;

+ (NSString *)UUIDString;

- (unsigned int)UTF8StringLength;
- (long long)longLongValue;
- (unsigned long long)unsignedLongLongValue;
- (unsigned int)unsignedIntValue;

- (BOOL)containsSubstring:(NSString *)string;
- (BOOL)containsCharactersFromSet:(NSCharacterSet *)set;
- (BOOL)isComposedOfCharactersFromSet:(NSCharacterSet *)characterSet;

- (NSArray *)componentsSeparatedByCharactersFromSet:(NSCharacterSet *)characterSet;

- (NSString *)stringByReplacingOccurencesOfString:(NSString *)target withString:(NSString *)replacement;
- (NSString *)stringByReplacingOccurencesOfStrings:(NSArray *)targets withString:(NSString *)replacement;
- (NSString *)stringByRemovingSurroundingWhitespace;

- (NSString *)stringByAddingURLPercentEscapes;
- (NSString *)stringByReplacingURLPercentEscapes;

@end


@interface NSString(ZAStringChecksumming)

- (NSString *)SHA1;

@end


@interface NSString(ZAHumanReadableStringFormatting)

+ (NSString *)humanReadableStringForTimeInterval:(NSTimeInterval)interval;
+ (NSString *)humanReadableStringForSize:(unsigned long long)size;
+ (NSString *)humanReadableStringWithBytesForSize:(unsigned long long)size;
+ (NSString *)humanReadableStringForBandwidth:(unsigned int)speed;

@end


@interface NSString(ZAWiredVersionStringFormatting)

- (NSString *)wiredVersion;

@end


@interface NSAttributedString(ZAAttributedStringAdditions)

#ifndef NSStrikethroughStyleAttributeName
#define NSStrikethroughStyleAttributeName		@"NSStrikethrough"
#endif

#ifndef NSCursorAttributeName
#define NSCursorAttributeName					@"NSCursor"
#endif

#ifndef NSShadowAttributeName
#define NSShadowAttributeName					@"NSShadow"
#endif


+ (id)attributedString;
+ (id)attributedStringWithString:(NSString *)string;
+ (id)attributedStringWithString:(NSString *)string attributes:(NSDictionary *)attributes;

@end
