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

#import "NSURLAdditions.h"

@implementation NSURL(WCHumanReadableFormatting)

- (NSString *)humanReadableURL {
	NSMutableString		*string;
	
	// --- create string
	string = [[NSMutableString alloc] init];
	[string appendFormat:@"%@://", [self scheme], [self host]];
	
	// --- add user
	if(![[self user] isEqualToString:@"guest"] && [[self user] length] != 0)
		[string appendFormat:@"%@:@", [self user]];
	
	// --- add host
	[string appendString:[self host]];
	
	// --- add port
	if([self port]) {
		if(([[self scheme] isEqualToString:@"wired"] && [[self port] intValue] != 2000) ||
		   ([[self scheme] isEqualToString:@"wiredtracker"] && [[self port] intValue] != 2002))
			[string appendFormat:@":%@", [self port]];
	}
	
	// --- add path
	if([self path])
		[string appendString:[self path]];
	else
		[string appendString:@"/"];

	return [string autorelease];
}

@end



@implementation NSURL(WCURLInterpretation)

+ (NSURL *)URLWithLooseString:(NSString *)string {
	NSString		*scheme = NULL;
	NSRange			range, range2;
	unsigned int	length;
	BOOL			found = NO;
	
	// --- get string length
	length = [string length];
	
	if(!found) {
		// --- contains "://", but not in beginning or end
		range = [string rangeOfString:@"://"];
		
		if(range.location != NSNotFound && range.location != 0 &&
		   range.location + range.length != length)
			found = YES;
	}
	
	if(!found) {
		// --- contains "@", but not in beginning or end
		range = [string rangeOfString:@"@"];
		
		if(range.location != NSNotFound && range.location != 0 &&
		   range.location + range.length != length) {
			// --- contains "." somewhere after the "@", but not last
			range2 = [string rangeOfString:@"."];
			
			if(range2.location != NSNotFound && range2.location > range.location &&
			   range2.location + range2.length != length) {
				scheme = @"mailto:";

				found = YES;
			}
		}
	}
	
	if(!found) {
		// --- begins with "www."
		if([string hasPrefix:@"www."]) {
			// --- contains "." somewhere after "www."
			range2 = [[string substringFromIndex:4] rangeOfString:@"."];
			
			if(range2.location != NSNotFound) {
				scheme = @"http://";
				
				found = YES;
			}
		}
		// --- begins with "wired."
		else if([string hasPrefix:@"wired."]) {
			// --- contains "." somewhere after "wired."
			range2 = [[string substringFromIndex:6] rangeOfString:@"."];
			
			
			if(range2.location != NSNotFound) {
				scheme = @"wired://";
			
				found = YES;
			}
		}
	}
	
	if(found) {
		if(scheme)
			return [NSURL URLWithString:[scheme stringByAppendingString:string]];
		else
			return [NSURL URLWithString:string];
	}
	
	return NULL;
}

@end
