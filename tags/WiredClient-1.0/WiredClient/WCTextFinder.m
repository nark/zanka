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

#import "WCMain.h"
#import "WCTextFinder.h"

@implementation WCTextFinder

- (id)init {
	self = [super initWithWindowNibName:@"TextFinder"];
	
	// --- load the window
	[self window];
	
	return self;
}



#pragma mark -

- (void)windowDidLoad {
	// --- window position
	[self setWindowFrameAutosaveName:@"TextFinder"];
	[self setShouldCascadeWindows:NO];
}



#pragma mark -

- (void)setResponder:(NSResponder *)value {
	_responder = value;
}



#pragma mark -

- (IBAction)next:(id)sender {
	NSString		*string;
	NSRange			range;
	BOOL			again = NO;

	// --- get string and selection
	string	= [[(NSTextView *) _responder textStorage] string];
	range	= [(NSTextView *) _responder selectedRange];
	
	if(range.length == 0) {
		// --- search entire range
		range = NSMakeRange(0, [string length]);
	} else {
		// --- we have a previous search selected
		if([[string substringWithRange:range] isEqualToString:[_findTextField stringValue]])
			range = NSMakeRange(range.location + 1, [string length] - range.location - 1);
		
		again = YES;
	}
	
	// --- find string
	range = [string rangeOfString:[_findTextField stringValue]
						  options:NSCaseInsensitiveSearch
							range:range];
	
	// --- select range
	if(range.length > 0) {
		[(NSTextView *) _responder setSelectedRange:range];
		[(NSTextView *) _responder scrollRangeToVisible:range];
		
		return;
	}
	
	// --- search again on entire range
	if(again) {
		// --- find string
		range = [string rangeOfString:[_findTextField stringValue]
							  options:NSCaseInsensitiveSearch
								range:NSMakeRange(0, [string length])];
		
		// --- select range
		if(range.length > 0) {
			[(NSTextView *) _responder setSelectedRange:range];
			[(NSTextView *) _responder scrollRangeToVisible:range];
		}
	}
}



- (IBAction)previous:(id)sender {
	NSString		*string;
	NSRange			range;
	BOOL			again = NO;

	// --- get string and selection
	string	= [[(NSTextView *) _responder textStorage] string];
	range	= [(NSTextView *) _responder selectedRange];
	
	if(range.length == 0) {
		// --- search entire range
		range = NSMakeRange(0, [string length]);
	} else {
		// --- we have a previous search selected
		if([[string substringWithRange:range] isEqualToString:[_findTextField stringValue]])
			range = NSMakeRange(0, range.location);
		
		again = YES;
	}
	
	// --- find string
	range = [string rangeOfString:[_findTextField stringValue]
					options:NSCaseInsensitiveSearch | NSBackwardsSearch
					range:range];
	
	// --- select range
	if(range.length > 0) {
		[(NSTextView *) _responder setSelectedRange:range];
		[(NSTextView *) _responder scrollRangeToVisible:range];
		
		return;
	}
	
	// --- search again on entire range
	if(again) {
		// --- find string
		range = [string rangeOfString:[_findTextField stringValue]
							  options:NSCaseInsensitiveSearch | NSBackwardsSearch
								range:NSMakeRange(0, [string length])];
		
		// --- select range
		if(range.length > 0) {
			[(NSTextView *) _responder setSelectedRange:range];
			[(NSTextView *) _responder scrollRangeToVisible:range];
		}
	}
}



- (void)useSelectionForFind {
	NSString		*string;
	NSRange			range;
	
	// --- get string and selection
	string	= [[(NSTextView *) _responder textStorage] string];
	range	= [(NSTextView *) _responder selectedRange];
	
	// --- set selected substring and show panel
	if(range.length > 0) {
		[_findTextField setStringValue:[string substringWithRange:range]];
		[self showWindow:self];
	}
}



- (void)jumpToSelection {
	NSRange			range;
	
	// --- get selection
	range = [(NSTextView *) _responder selectedRange];
	
	// --- scroll to selection
	if(range.length > 0)
		[(NSTextView *) _responder scrollRangeToVisible:range];
}

@end
