/*
 * Copyright © 2000-2002 Axel Andersson
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
 
#import "Settings.h"

@implementation Settings

static NSUserDefaults			*defaults;
static NSMutableDictionary		*settings;

/*
	Our init method.
*/

- (id)init {
	[super init];
	
	settings = [[self preferencesFromUserDefaults] retain];
	
	return self;
}



#pragma mark -

/*
	Return the value for the key provided. This can be called from wherever,
	as we use a static global.
*/

+ (id)objectForKey:(id)key {
    return [settings objectForKey:key];
}


/*
	Set the value for the key provided to the object provided.
*/

+ (void)setObject:(id)object forKey:(NSString *)key {
	[settings setObject:object forKey:key];
	[defaults setObject:object forKey:key];
} 



#pragma mark -

/*
	Return a default set of preferences.
*/

- (NSDictionary *)getDefaultValues {
    return [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSNumber numberWithInt:kDefaultsKanaTypeHiragana], kDefaultsKanaType,
			[NSNumber numberWithInt:kDefaultsRomanisationSystemHepburn], kDefaultsRomanisationSystem,
			[NSNumber numberWithInt:kDefaultsModeQuiz], kDefaultsMode,
			[NSNumber numberWithInt:kDefaultsLinesAll], kDefaultsLines,
			@"", kDefaultsTutorPosition,
			[NSNumber numberWithBool:YES], kDefaultsMouseDownOnIncorrect,
			[NSNumber numberWithBool:NO], kDefaultsLockSettings,
			[NSNumber numberWithInt:kDefaultsSessionFree], kDefaultsSession,
			[NSNumber numberWithInt:0], kDefaultsTimeLimit,
			[NSNumber numberWithInt:0], kDefaultsKanaLimit,
			NULL];
}



/*
	Macro to get an int from the defaults system and store it as an NSNumber
	in our preferences.
*/

#define getIntDefault(name) \
	defaultsObject = [defaults objectForKey:name]; \
	\
	if(defaultsObject) { \
		[dictionary setObject:[NSNumber numberWithInt:[defaults integerForKey:name]] forKey:name]; \
		[defaults setObject:[NSNumber numberWithInt:[defaults integerForKey:name]] forKey:name]; \
	} else { \
		[dictionary setObject:[defaultValues objectForKey:name] forKey:name]; \
		[defaults setObject:[defaultValues objectForKey:name] forKey:name]; \
	}



/*
	Macro to get a string from the defaults system and store it as an NSString
	in our preferences.
*/

#define getStringDefault(name) \
	defaultsObject = [defaults objectForKey:name]; \
	\
	if(defaultsObject) { \
		[dictionary setObject:[defaults stringForKey:name] forKey:name]; \
		[defaults setObject:[defaults stringForKey:name] forKey:name]; \
	} else { \
		[dictionary setObject:[defaultValues objectForKey:name] forKey:name]; \
		[defaults setObject:[defaultValues objectForKey:name] forKey:name]; \
	}



/*
	Macro to get a bool from the defaults system and store it as an NSNumber
	in our preferences.
*/

#define getBoolDefault(name) \
	defaultsObject = [defaults objectForKey:name]; \
	\
	if(defaultsObject) { \
		[dictionary setObject:[NSNumber numberWithBool:[defaults integerForKey:name]] forKey:name]; \
		[defaults setObject:[NSNumber numberWithBool:[defaults integerForKey:name]] forKey:name]; \
	} else { \
		[dictionary setObject:[defaultValues objectForKey:name] forKey:name]; \
		[defaults setObject:[defaultValues objectForKey:name] forKey:name]; \
	}


/*
	Build our preferences from the defaults system.
*/

- (NSMutableDictionary *)preferencesFromUserDefaults {
	NSMutableDictionary	*dictionary;
	NSDictionary		*defaultValues;
	id					defaultsObject;

	defaults			= [NSUserDefaults standardUserDefaults];
	dictionary			= [NSMutableDictionary dictionaryWithCapacity:6];
	defaultValues		= [self getDefaultValues];
	
	getIntDefault(kDefaultsMode);
	getIntDefault(kDefaultsKanaType);
	getIntDefault(kDefaultsRomanisationSystem);
	getIntDefault(kDefaultsLines);
	getIntDefault(kDefaultsSession);
	getIntDefault(kDefaultsTimeLimit);
	getIntDefault(kDefaultsKanaLimit);
	
	getStringDefault(kDefaultsTutorPosition);
	
	getBoolDefault(kDefaultsMouseDownOnIncorrect);
	getBoolDefault(kDefaultsLockSettings);

	return dictionary;
}

@end
