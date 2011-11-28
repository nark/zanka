/* $Id$ */

/*
 *  Copyright (c) 2006 Axel Andersson
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

#import <WiredAdditions/WISearchField.h>

@interface WISearchField(Private)

- (void)_initSearchField;

@end


@implementation WISearchField(Private)

- (void)_initSearchField {
	[[self cell] setSearchMenuTemplate:[[self class] defaultSearchMenuTemplate]];
}

@end


@implementation WISearchField

+ (NSMenu *)defaultSearchMenuTemplate {
	NSMenu			*menu;
	NSMenuItem		*item;
	
	menu = [[NSMenu alloc] initWithTitle:@""];
	
	item = [[NSMenuItem alloc] initWithTitle:WILS(@"Recent Searches", @"Default search menu template item")
									  action:NULL
							   keyEquivalent:@""];
	[item setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[menu addItem:item];
	[item release];

	item = [[NSMenuItem alloc] initWithTitle:WILS(@"No Recent Searches", @"Default search menu template item")
									  action:NULL
							   keyEquivalent:@""];
	[item setTag:NSSearchFieldNoRecentsMenuItemTag];
	[menu addItem:item];
	[item release];

	item = [[NSMenuItem alloc] initWithTitle:@"Searches"
									  action:NULL
							   keyEquivalent:@""];
	[item setTag:NSSearchFieldRecentsMenuItemTag];
	[menu addItem:item];
	[item release];
	
	item = [NSMenuItem separatorItem];
	[item setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[menu addItem:item];

	item = [[NSMenuItem alloc] initWithTitle:WILS(@"Clear Recent Searches", @"Default search menu template item")
									  action:NULL
							   keyEquivalent:@""];
	[item setTag:NSSearchFieldClearRecentsMenuItemTag];
	[menu addItem:item];
	[item release];

	return [menu autorelease];
}



#pragma mark -

- (id)initWithFrame:(NSRect)frame {
	if((self = [super initWithFrame:frame]))
		[self _initSearchField];
	
	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	if((self = [super initWithCoder:coder]))	
		[self _initSearchField];
	
	return self;
}

@end
