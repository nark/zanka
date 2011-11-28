/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
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
#import "TNPerlParser.h"
#import "TNProfilerController.h"
#import "TNSessionController.h"

static TNMainController				*TNSharedMainController;

@implementation TNMainController

+ (TNMainController *)mainController {
	return TNSharedMainController;
}



- (void)awakeFromNib {
	NSEnumerator	*enumerator;
	NSBundle		*bundle;
	NSString		*path, *name;
	Class			class;
	
	TNSharedMainController = self;
	
	_parserClasses = [[NSMutableArray alloc] init];
	[_parserClasses addObject:[TNPerlParser class]];
	
	path = [[NSBundle mainBundle] builtInPlugInsPath];
	enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
	
	while((name = [enumerator nextObject])) {
		if([[name pathExtension] isEqualToString:@"tunaPlugin"]) {
			bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:name]];
			
			if([bundle load]) {
				class = NSClassFromString([[bundle infoDictionary] objectForKey:@"TNParserClass"]);
				
				if(class)
					[_parserClasses addObject:class];
			}
		}
	}
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(find:) || selector == @selector(findNext:))
		return [[[NSApp mainWindow] delegate] isKindOfClass:[TNSessionController class]];
	
	return YES;
}



#pragma mark -

- (NSArray *)parserClasses {
	return _parserClasses;
}



#pragma mark -

- (IBAction)newDocument:(id)sender {
	TNProfilerController	*controller;
	
	controller = [[TNProfilerController alloc] init];
	[controller showWindow:self];
	[controller release];
}




- (IBAction)find:(id)sender {
	TNSessionController		*controller;
	
	controller = [[NSApp mainWindow] delegate];
	
	if([controller isKindOfClass:[TNSessionController class]])
		[_findPanel makeKeyAndOrderFront:self];
}



- (IBAction)findNext:(id)sender {
	TNSessionController		*controller;
	
	controller = [[NSApp mainWindow] delegate];
	
	if([controller isKindOfClass:[TNSessionController class]]) {
		if([controller findString:[_findTextField stringValue]])
			[_findPanel close];
	}
}



- (IBAction)releaseNotes:(id)sender {
	NSString		*path;
	
	path = [[self bundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
	
	[[WIReleaseNotesController releaseNotesController]
		setReleaseNotesWithRTF:[NSData dataWithContentsOfFile:path]];
	[[WIReleaseNotesController releaseNotesController] showWindow:self];
}



- (IBAction)manual:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.zankasoftware.com/tuna/manual"]];
}



#pragma mark -

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)application {
	return NO;
}



- (BOOL)applicationOpenUntitledFile:(NSApplication *)application {
	TNProfilerController	*controller;
	
	controller = [[TNProfilerController alloc] init];
	[controller showWindow:self];
	[controller release];
	
	return YES;
}

@end
