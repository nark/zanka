/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "FHPreferencesController.h"
#import "FHSettings.h"

@interface FHPreferencesController(Private)

- (void)_setExternalEditor:(NSString *)path;

@end


@implementation FHPreferencesController(Private)

- (void)_setExternalEditor:(NSString *)path {
	NSImage		*image;
	
	image = [[NSWorkspace sharedWorkspace] iconForFile:path];
	[image setSize:NSMakeSize(16.0, 16.0)];
	
	[_externalEditorMenuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:path]];
	[_externalEditorMenuItem setImage:image];
	[_externalEditorMenuItem setRepresentedObject:path];
}

@end



@implementation FHPreferencesController

+ (FHPreferencesController *)preferencesController {
	static FHPreferencesController		*preferencesController;
	
	if(!preferencesController)
		preferencesController = [[[self class] alloc] init];
	
	return preferencesController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Preferences"];
	
	[self window];
	
	return self;
}



#pragma mark -

- (void)windowDidLoad {
	NSString		*externalEditor;
	
	[_backgroundColorColorWell setColor:WIColorFromString([FHSettings objectForKey:FHBackgroundColor])];
	
	externalEditor = [FHSettings objectForKey:FHExternalEditor];
	
	if(externalEditor)
		[self _setExternalEditor:externalEditor];
	else
		[self _setExternalEditor:@"/Applications/Preview.app"];
	
	[[self window] center];
}



#pragma mark -

- (IBAction)backgroundColor:(id)sender {
	[FHSettings setObject:WIStringFromColor([_backgroundColorColorWell color]) forKey:FHBackgroundColor];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:FHPreferencesDidChangeNotification];
}



- (IBAction)externalEditor:(id)sender {
	[FHSettings setObject:[_externalEditorPopUpButton representedObjectOfSelectedItem] forKey:FHExternalEditor];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:FHPreferencesDidChangeNotification];
}



- (IBAction)otherExternalEditor:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setTitle:NSLS(@"Select Editor", @"External editor dialog title")];
	[openPanel setPrompt:NSLS(@"Select", @"External editor dialog button title")];
	
	if([openPanel runModalForDirectory:@"/Applications" file:NULL types:[NSArray arrayWithObject:@"app"]] == NSOKButton) {
		[self _setExternalEditor:[openPanel filename]];
		
		[_externalEditorPopUpButton selectItem:_externalEditorMenuItem];
		
		[self externalEditor:self];
	} else {
		[_externalEditorPopUpButton selectItemAtIndex:0];
	}
}

@end
