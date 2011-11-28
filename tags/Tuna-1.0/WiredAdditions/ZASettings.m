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

#import <ZankaAdditions/ZASettings.h>

@interface ZASettings(Private)

- (id)				objectForKey:(id)key;
- (void)			setObject:(id)object forKey:(id)key;

@end


@implementation ZASettings

+ (ZASettings *)settings {
	static id sharedSettings;

	if(!sharedSettings)
		sharedSettings = [[self alloc] init];

	return sharedSettings;
}



+ (NSDictionary *)defaults {
	return [NSDictionary dictionary];
}



- (id)init {
	NSUserDefaults	*defaults;
	NSDictionary	*defaultValues;
	NSString		*key;
	NSEnumerator	*enumerator;
	id				object;

	self = [super init];

	_settings = [[NSMutableDictionary alloc] init];
	_lock = [[NSRecursiveLock alloc] init];

	defaultValues = [[self class] defaults];
	defaults = [NSUserDefaults standardUserDefaults];
	enumerator = [defaultValues keyEnumerator];

	while((key = [enumerator nextObject])) {
		object = [defaults objectForKey:key];

		if(!object) {
			object = [defaultValues objectForKey:key];

			if([object isKindOfPropertyListSerializableClass])
				[defaults setObject:object forKey:key];
			else
				[defaults setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];
		}

		if([object isKindOfClass:[NSData class]]) {
			object = [NSUnarchiver unarchiveObjectWithData:object];

			if(object)
				[_settings setObject:object forKey:key];
		}
		else {
			[_settings setObject:object forKey:key];
		}
	}

	return self;
}



#pragma mark -

- (id)objectForKey:(id)key {
	id		object;

	[_lock lock];
	object = [_settings objectForKey:key];
	[_lock unlock];

	return object;
}



- (void)setObject:(id)object forKey:(id)key {
	NSUserDefaults		*defaults;

	defaults = [NSUserDefaults standardUserDefaults];

	if([object isKindOfPropertyListSerializableClass])
		[defaults setObject:object forKey:key];
	else
		[defaults setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];

	[_lock lock];
	[_settings setObject:object forKey:key];
	[_lock unlock];

	[defaults performSelectorOnce:@selector(synchronize) withObject:NULL afterDelay:0.1];
}



#pragma mark -

+ (id)objectForKey:(id)key {
	return [[self settings] objectForKey:key];
}



+ (NSString *)stringForKey:(id)key {
	return [[self settings] objectForKey:key];
}



+ (BOOL)boolForKey:(id)key {
	return [[[self settings] objectForKey:key] boolValue];
}



+ (int)intForKey:(id)key {
	return [[[self settings] objectForKey:key] intValue];
}



+ (float)floatForKey:(id)key {
	return [[[self settings] objectForKey:key] floatValue];
}




+ (double)doubleForKey:(id)key {
	return [[[self settings] objectForKey:key] doubleValue];
}



+ (void)setObject:(id)object forKey:(id)key {
	[[self settings] setObject:object forKey:key];
}



+ (void)setBool:(BOOL)value forKey:(id)key {
	[[self settings] setObject:[NSNumber numberWithBool:value] forKey:key];
}



+ (void)setInt:(int)value forKey:(id)key {
	[[self settings] setObject:[NSNumber numberWithInt:value] forKey:key];
}



+ (void)setFloat:(float)value forKey:(id)key {
	[[self settings] setObject:[NSNumber numberWithFloat:value] forKey:key];
}



+ (void)setDouble:(double)value forKey:(id)key {
	[[self settings] setObject:[NSNumber numberWithDouble:value] forKey:key];
}

@end
