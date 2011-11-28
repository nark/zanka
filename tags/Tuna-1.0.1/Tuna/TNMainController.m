/* $Id$ */

/*
 *  Copyright (c) 2005 Axel Andersson
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

#import "TNMainController.h"
#import "TNProfilerController.h"

@implementation TNMainController

- (IBAction)newDocument:(id)sender {
	TNProfilerController	*controller;
	
	controller = [[TNProfilerController alloc] init];
	[controller showWindow:self];
}




- (IBAction)releaseNotes:(id)sender {
	NSAttributedString	*string;
	NSString			*path;

	if([[_releaseNotesTextView string] length] == 0) {
		path = [[self bundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
		string = [[NSAttributedString alloc] initWithRTF:[NSData dataWithContentsOfFile:path]
									  documentAttributes:NULL];
		
		[_releaseNotesTextView setAttributedString:string];
		[string release];
	}
	
	[_releaseNotesWindow makeKeyAndOrderFront:self];
}



- (IBAction)manual:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.zankasoftware.com/tuna/manual"]];
}



#pragma mark -

- (BOOL)applicationOpenUntitledFile:(NSApplication *)application {
	TNProfilerController	*controller;
	
	controller = [[TNProfilerController alloc] init];
	[controller showWindow:self];
	
	return YES;
}

@end
