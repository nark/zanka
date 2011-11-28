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

#import <WiredAdditions/NSPopUpButton-WIAdditions.h>

@implementation NSPopUpButton(WIPopUpButtonAdditions)

- (void)addItem:(NSMenuItem *)item {
	[[self menu] addItem:item];
}



- (void)insertItem:(NSMenuItem *)item atIndex:(unsigned int)index {
	[[self menu] insertItem:item atIndex:index];
}



- (void)removeItem:(NSMenuItem *)item {
	[[self menu] removeItem:item];
}



#pragma mark -

#if ! MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_3
- (BOOL)selectItemWithTag:(int)tag {
	int		index;
	
	index = [self indexOfItemWithTag:tag];
	
	if(index >= 0) {
		[self selectItemAtIndex:index];
		
		return YES;
	}
	
	return NO;
}
#endif



- (int)tagOfSelectedItem {
	return [[self selectedItem] tag];
}



- (NSMenuItem *)itemWithTag:(int)tag {
	return (NSMenuItem *) [[self menu] itemWithTag:tag];
}



#pragma mark -

- (id)representedObjectOfSelectedItem {
	return [[self selectedItem] representedObject];
}

@end