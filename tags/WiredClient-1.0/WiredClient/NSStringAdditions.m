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

#import <openssl/sha.h>
#import "NSStringAdditions.h"

@implementation NSString(WCChecksum)

- (NSString *)SHA1 {
	SHA_CTX					c;
	static unsigned char	hex[] = "0123456789abcdef";
	unsigned char			sha[SHA_DIGEST_LENGTH], password[SHA_DIGEST_LENGTH * 2 + 1];
	int						i;

	// --- calculate the checksum
	SHA1_Init(&c);
	SHA1_Update(&c, (unsigned char *) [self cString], [self length]);
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



- (NSString *)versionString {
	NSString	*version;
	NSArray		*fields;
	NSRange		range;
	
	version = [NSString stringWithString:self];
	range = [version rangeOfString:@" ("];
	
	if(range.location != NSNotFound) {
		version = [version substringToIndex:range.location];
		fields = [version componentsSeparatedByString:@"/"];
		version = [NSString stringWithFormat:@"%@ %@", [fields objectAtIndex:0], [fields objectAtIndex:1]];
	}
	
	return version;
}

@end