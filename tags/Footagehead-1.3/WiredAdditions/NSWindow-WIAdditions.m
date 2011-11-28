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

#import <WiredAdditions/NSDictionary-WIAdditions.h>
#import <WiredAdditions/NSToolbar-WIAdditions.h>
#import <WiredAdditions/NSWindow-WIAdditions.h>

@implementation NSWindow(WIWindowAdditions)

- (void)setTitle:(NSString *)title withSubtitle:(NSString *)subtitle {
	[self setTitle:[NSSWF:@"%@ %C %@", title, 0x2014, subtitle]];
}



#pragma mark -

- (BOOL)isOnScreen {
	return ([self isVisible] || [self isMiniaturized]);
}



- (float)toolbarHeight {
	NSToolbar	*toolbar;
	
	toolbar = [self toolbar];
	
	if(!toolbar)
		return 0.0;
	
	return [self contentRectForFrameRect:[self frame]].size.height - [[self contentView] frame].size.height;
}



#pragma mark -

- (void)setPropertiesFromDictionary:(NSDictionary *)dictionary {
	[self setPropertiesFromDictionary:dictionary restoreSize:YES visibility:YES];
}



- (void)setPropertiesFromDictionary:(NSDictionary *)dictionary restoreSize:(BOOL)size visibility:(BOOL)visibility {
	NSRect		rect;
	id			object;
	
	if([self toolbar]) {
		object = [dictionary objectForKey:@"_WIWindow_toolbar"];
		
		if(object)
			[[self toolbar] setPropertiesFromDictionary:object];
	}

	object = [dictionary objectForKey:@"_WIWindow_frame"];
	
	if(object) {
		rect = NSRectFromString(object);
		
		if(size)
			[self setFrame:rect display:NO];
		else
			[self setFrameOrigin:rect.origin];
	}

	if(visibility) {
		object = [dictionary objectForKey:@"_WIWindow_isOnScreen"];
		
		if(object) {
			if([object boolValue])
				[self performSelector:@selector(orderFront:) withObject:self afterDelay:0.0];
			else
				[self performSelector:@selector(orderOut:) withObject:self afterDelay:0.0];
		}
		
		object = [dictionary objectForKey:@"_WIWindow_isMiniaturized"];
		
		if(object && [object boolValue])
			[self performSelector:@selector(miniaturize:) withObject:self afterDelay:0.0];
	}
}



- (NSDictionary *)propertiesDictionary {
	NSMutableDictionary		*dictionary;
	
	dictionary = [NSMutableDictionary dictionary];
	
	[dictionary setObject:NSStringFromRect([self frame]) forKey:@"_WIWindow_frame"];
	[dictionary setBool:[self isOnScreen] forKey:@"_WIWindow_isOnScreen"];
	[dictionary setBool:[self isMiniaturized] forKey:@"_WIWindow_isMiniaturized"];
	
	if([self toolbar])
		[dictionary setObject:[[self toolbar] propertiesDictionary] forKey:@"_WIWindow_toolbar"];
	
	return dictionary;
}

@end
