/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

#import "WCConfig.h"
#import "WCSettings.h"

@implementation WCConfig

- (id)init {
	self = [super init];
	
	_config = [[NSMutableDictionary alloc] init];
	_lock = [[NSRecursiveLock alloc] init];
	
	return self;
}



- (id)initWithString:(NSString *)string {
	NSEnumerator	*enumerator;
	NSArray			*pair;
	NSString		*line, *name, *value;
	
	self = [self init];
	
	enumerator = [[string componentsSeparatedByString:@"\n"] objectEnumerator];
	
	while((line = [enumerator nextObject])) {
		if([line hasPrefix:@"#"])
			continue;
		
		pair = [line componentsSeparatedByString:@"="];
		
		if([pair count] == 2) {
			name = [pair objectAtIndex:0];
			value = [pair objectAtIndex:1];
			
			while([name hasSuffix:@" "] || [name hasSuffix:@"\t"])
				name = [name substringToIndex:[name length] - 1];
			
			while([value hasPrefix:@" "] || [value hasPrefix:@"\t"])
				value = [value substringFromIndex:1];
			
			if([_config objectForKey:name])
				[[_config objectForKey:name] addObject:value];
			else
				[_config setObject:[NSMutableArray arrayWithObject:value] forKey:name];
		}
	}
	
	return self;
}



- (id)initWithData:(NSData *)data {
	return [self initWithString:[NSString stringWithData:data encoding:NSUTF8StringEncoding]];
}



- (id)initWithContentsOfFile:(NSString *)file {
	return [self initWithString:[NSString stringWithContentsOfFile:file]];
}



- (id)initWithContentsOfURL:(NSURL *)url {
	return [self initWithString:[NSString stringWithContentsOfURL:url]];
}



- (void)dealloc {
	[_config release];
	[_lock release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)stringForKey:(id)key {
	NSString	*string;
	
	[_lock lock];
	string = [[_config objectForKey:key] objectAtIndex:0];
	[_lock unlock];
	
	return string ? string : @"";
}



- (NSMutableArray *)arrayForKey:(id)key {
	NSMutableArray	*array;
	
	[_lock lock];
	array = [_config objectForKey:key];
	[_lock unlock];
	
	return array ? array : [NSMutableArray array];
}



- (NSString *)pathForKey:(id)key {
	return WCExpandWiredPath([self stringForKey:key]);
}



- (NSImage *)imageForKey:(id)key {
	return [[[NSImage alloc] initWithContentsOfFile:[self pathForKey:key]] autorelease];
}



- (BOOL)boolForKey:(id)key {
	return ([[self stringForKey:key] compare:@"yes" options:NSCaseInsensitiveSearch] == NSOrderedSame);
}



- (int)intForKey:(id)key {
	return [[self stringForKey:key] intValue];
}



- (double)doubleForKey:(id)key {
	return [[self stringForKey:key] doubleValue];
}



- (void)setString:(NSString *)string forKey:(id)key {
	[_lock lock];

	if(string && [string length] > 0) {
		if([_config objectForKey:key])
			[[_config objectForKey:key] replaceObjectAtIndex:0 withObject:string];
		else
			[_config setObject:[NSMutableArray arrayWithObject:string] forKey:key];
	} else {
		[_config removeObjectForKey:key];
	}
	
	[_lock unlock];
}



- (void)setArray:(NSMutableArray *)array forKey:(id)key {
	[_lock lock];
	
	if(array && [array count] > 0)
		[_config setObject:array forKey:key];
	else
		[_config removeObjectForKey:key];
	
	[_lock unlock];
}



- (void)setBool:(BOOL)value forKey:(id)key {
	[self setString:value ? @"yes" : @"no" forKey:key];
}



- (void)setInt:(int)value forKey:(id)key {
	[self setString:[NSSWF:@"%u", value] forKey:key];
}



#pragma mark -

- (BOOL)writeToFile:(NSString *)file {
	NSEnumerator		*enumerator, *valueEnumerator;
	NSMutableString		*string;
	id					key, value;
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:file]) {
		[[NSFileManager defaultManager] createFileAtPath:file
												contents:NULL
											  attributes:NULL];
	}

	string = [NSMutableString string];
	[string appendFormat:WCLS(@"# This file was generated by %@ at %@\n", @"File comment"),
		[[self bundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
		[[NSDate date] fullDateStringWithSeconds:YES]];
	
	enumerator = [[[_config allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
	
	while((key = [enumerator nextObject])) {
		valueEnumerator = [[_config objectForKey:key] objectEnumerator];
		
		while((value = [valueEnumerator nextObject]))
			[string appendFormat:@"%@ = %@\n", key, value];
	}
	
	return [[string dataUsingEncoding:NSUTF8StringEncoding] writeToFile:file atomically:YES];
}



- (BOOL)writeToURL:(NSURL *)url {
	if(![url isFileURL]) {
		NSLog(@"*** [%@ writeToURL:]: remote URLs not supported", self);
		
		return NO;
	}
	
	return [self writeToFile:[url path]];
}

@end
