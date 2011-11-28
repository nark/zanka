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
#import "NSStringAdditions.h"
#import "WCConnection.h"
#import "WCStats.h"

@implementation WCStats

NSMutableDictionary			*stats;
NSDate						*date;
NSLock						*lock;


- (id)init {
	self = [super init];
	
	// --- create stats
	stats = [[NSMutableDictionary alloc] initWithContentsOfFile:[WCStatsPath stringByStandardizingPath]];

	// --- create empty if the plist hasn't been created
	if(!stats)
		stats = [[NSMutableDictionary alloc] init];
	
	// --- zero out elements that hasn't been created
	if(![stats objectForKey:WCStatsDownloaded])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsDownloaded];

	if(![stats objectForKey:WCStatsMaxDownloadSpeed])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsMaxDownloadSpeed];

	if(![stats objectForKey:WCStatsUploaded])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsUploaded];

	if(![stats objectForKey:WCStatsMaxUploadSpeed])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsMaxUploadSpeed];

	if(![stats objectForKey:WCStatsChat])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsChat];

	if(![stats objectForKey:WCStatsOnline])
		[stats setObject:[NSNumber numberWithInt:0] forKey:WCStatsOnline];
	
	return self;
}



#pragma mark -

+ (id)objectForKey:(id)key {
	id						object;
	unsigned long long		seconds;

	[lock lock];
	
	if([key isEqualToString:WCStatsOnline]) {
		// --- add the time we've counted so far
		seconds = [[stats objectForKey:WCStatsOnline] longLongValue];
		seconds += (unsigned long long) [[NSDate date] timeIntervalSinceDate:date];

		object = [NSNumber numberWithUnsignedLongLong:seconds];
	} else {
		object = [stats objectForKey:key];
	}
	
	[lock unlock];
	
	return object;
}



+ (unsigned int)unsignedIntForKey:(id)key {
	return [[WCStats objectForKey:key] unsignedIntValue];
}



+ (unsigned long long)unsignedLongLongForKey:(id)key {
	return [[WCStats objectForKey:key] unsignedLongLongValue];
}



+ (void)setObject:(id)object forKey:(id)key {
	[lock lock];
	[stats setObject:object forKey:key];
	[lock unlock];
}



+ (void)setUnsignedInt:(unsigned int)number forKey:(id)key {
	[WCStats setObject:[NSNumber numberWithUnsignedInt:number] forKey:key];
}



+ (void)setUnsignedLongLong:(unsigned long long)number forKey:(id)key {
	[WCStats setObject:[NSNumber numberWithUnsignedLongLong:number] forKey:key];
}



#pragma mark -

+ (NSString *)stats {
	NSString		*string;
	
	[lock lock];

	string = [NSString stringWithFormat:NSLocalizedString(@"%@ downloaded, %@/s max download speed, %@ uploaded, %@/s max upload speed, %@ chat, %@ online", @"Stats message"),
		[NSString humanReadableStringForSize:
			[[self objectForKey:WCStatsDownloaded] unsignedLongLongValue]],
		[NSString humanReadableStringForSize:
			[[self objectForKey:WCStatsMaxDownloadSpeed] unsignedLongLongValue]],
		[NSString humanReadableStringForSize:
			[[self objectForKey:WCStatsUploaded] unsignedLongLongValue]],
		[NSString humanReadableStringForSize:
			[[self objectForKey:WCStatsMaxUploadSpeed] unsignedLongLongValue]],
		[NSString humanReadableStringForSize:
			[[self objectForKey:WCStatsChat] unsignedLongLongValue]],
		[NSString humanReadableStringForTimeInterval:[[self objectForKey:WCStatsOnline] doubleValue]]];

	[lock unlock];
	
	return string;
}



+ (void)startCounting {
	[lock lock];
	
	// --- start counting if we're not already
	if(!date)
		date = [[NSDate date] retain];

	[lock unlock];
}



+ (void)stopCounting {
	unsigned long long		seconds;

	[lock lock];
	
	// --- add the time spent connected
	if(date) {
		seconds = [[stats objectForKey:WCStatsOnline] longLongValue];
		seconds += (unsigned long long) [[NSDate date] timeIntervalSinceDate:date];
		[stats setObject:[NSNumber numberWithUnsignedLongLong:seconds] forKey:WCStatsOnline];

		[date release];
		date = NULL;
	}

	[lock unlock];
}



+ (void)save {
	unsigned long long		seconds;

	[lock lock];
	
	// --- add the time spent connected
	if(date) {
		seconds = [[stats objectForKey:WCStatsOnline] longLongValue];
		seconds += (unsigned long long) [[NSDate date] timeIntervalSinceDate:date];
		[stats setObject:[NSNumber numberWithUnsignedLongLong:seconds] forKey:WCStatsOnline];
		
		// --- reset date
		[date release];
		date = [[NSDate date] retain];
	}

	// --- write out
	[stats writeToFile:[WCStatsPath stringByStandardizingPath] atomically:YES];

	[lock unlock];
}

@end
