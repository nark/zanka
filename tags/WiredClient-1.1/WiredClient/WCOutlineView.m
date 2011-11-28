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

#import "WCOutlineView.h"

@implementation WCOutlineView

- (NSMenu *)menuForEvent:(NSEvent *)event {
	int			row;
	
	row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:NULL]];
	
	if(row >= 0) {
		[self selectRow:row byExtendingSelection:NO]; 

		return [super menuForEvent:event];
	}
	
	return NULL;
}



- (void)keyDown:(NSEvent *)event {
	unichar		key;
	
	// --- get key
	key = [[event characters] characterAtIndex:0];

	// --- double-click on enter/return
	if(key == NSEnterCharacter || key == NSCarriageReturnCharacter)
		[super doCommandBySelector:[super doubleAction]];
	else
		[super keyDown:event];
}



- (void)copy:(id)sender {
	if([[self delegate] conformsToProtocol:@protocol(WCOutlineViewInfoCopying)])
		[[self delegate] outlineViewShouldCopyInfo:self];
}



- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local {
	if(local)
		return NSDragOperationEvery;
	
	return NSDragOperationGeneric;
}

@end
