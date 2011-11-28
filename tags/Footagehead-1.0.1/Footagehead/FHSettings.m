/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

#import "FHSettings.h"

@implementation FHSettings

NSUserDefaults				*defaults;
NSMutableDictionary			*settings;


+ (void)create {
	NSDictionary	*defaultValues;
	NSString		*key;
	NSEnumerator	*enumerator;
	id				object;
	
	// --- create objects
	defaults		= [NSUserDefaults standardUserDefaults];
	settings		= [[NSMutableDictionary alloc] init];
	
	// --- create default values
	defaultValues	= [NSDictionary dictionaryWithObjectsAndKeys:
		[[NSURL fileURLWithPath:NSHomeDirectory()] absoluteString],
			FHOpenURL,
		[NSNumber numberWithInt:0],
			FHScreen,
		[NSNumber numberWithBool:YES],
			FHSmooth,
		NULL];

	// --- loop over keys
	enumerator = [defaultValues keyEnumerator];
	
	while((key = [enumerator nextObject])) {
		object = [defaults objectForKey:key];

		if(object) {
			// --- get object from user defaults
			[settings setObject:object forKey:key];
		} else {
			// --- get object from default values
			[settings setObject:[defaultValues objectForKey:key] forKey:key];
			[defaults setObject:[defaultValues objectForKey:key] forKey:key];
		}
	}
}



+ (void)destroy {
	[settings release];
}



#pragma mark -

+ (id)objectForKey:(id)key {
	return [settings objectForKey:key];
}



+ (id)archivedObjectForKey:(id)key {
	return [NSUnarchiver unarchiveObjectWithData:[settings objectForKey:key]];
}



+ (void)setObject:(id)object forKey:(id)key {
	[defaults setObject:object forKey:key];
	[settings setObject:object forKey:key];

	[[NSUserDefaults standardUserDefaults] synchronize];
}



+ (void)setArchivedObject:(id)object forKey:(id)key {
	[defaults setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];
	[settings setObject:[NSArchiver archivedDataWithRootObject:object] forKey:key];

	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end
