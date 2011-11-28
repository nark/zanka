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

#import "NSDocumentController-TNAdditions.h"
#import "TNDocument.h"
#import "TNProfilerController.h"
#import "TNSettings.h"

@interface TNProfilerController(Private)

- (void)_updateButtons;
- (void)_success;
- (void)_error;

@end


@implementation TNProfilerController(Private)

- (void)_updateButtons {
	[_scriptComboBox setEnabled:!_started];
	[_setButton setEnabled:!_started];
	[_argumentsComboBox setEnabled:!_started];
	
	if(_started) {
		[_launchButton setTitle:NSLS(@"Stop", @"Launch/Stop button title")];
		[_progressIndicator startAnimation:self];
	} else {
		[_launchButton setTitle:NSLS(@"Launch", @"Launch/Stop button title")];
		[_progressIndicator stopAnimation:self];
	}
}



- (void)_success {
	TNDocument			*document;
	NSMutableArray		*scripts, *arguments;
	NSString			*path;
	
	path = [_path stringByAppendingPathComponent:@"tmon.out"];
	document = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"Tuna Session" fromFile:path];
	
	if(document) {
		[document updateChangeCount:NSChangeDone];
		[document showWindows];
		[document retain];
		
		scripts = [[[TNSettings settings] objectForKey:TNScriptsHistory] mutableCopy];
		
		if(![scripts containsObject:[_scriptComboBox stringValue]]) {
			[scripts insertObject:[_scriptComboBox stringValue] atIndex:0];
			
			if([scripts count] > 5)
				[scripts removeLastObject];
			
			[[TNSettings settings] setObject:scripts forKey:TNScriptsHistory];
		}
		
		[scripts release];
		
		arguments = [[[TNSettings settings] objectForKey:TNArgumentsHistory] mutableCopy];

		if(![arguments containsObject:[_argumentsComboBox stringValue]]) {
			[arguments insertObject:[_argumentsComboBox stringValue] atIndex:0];
			
			if([arguments count] > 5)
				[arguments removeLastObject];
			
			[[TNSettings settings] setObject:arguments forKey:TNArgumentsHistory];
		}
		
		[arguments release];
		
		[self close];
	} else {
		NSBeginAlertSheet(NSLS(@"Couldn't Open Session", @"Error dialog title"),
						  @"OK",
						  NULL,
						  NULL,
						  [self window],
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NSLS(@"Tuna could not open the session just written.", @"Error dialog description"));
	}
}



- (void)_error {
	NSFileHandle	*fileHandle;
	NSData			*data;
	NSString		*string;
	
	fileHandle	= [_pipe fileHandleForReading];
	data		= [fileHandle availableData];
	string		= [NSString stringWithData:data encoding:NSISOLatin1StringEncoding];
	
	NSBeginAlertSheet(NSLS(@"Couldn't Profile Script", @"Error dialog title"),
					  @"OK",
					  NULL,
					  NULL,
					  [self window],
					  NULL,
					  NULL,
					  NULL,
					  NULL,
					  NSLS(@"Tuna could not profile the script, because of Perl errors:\n\n%@", @"Error dialog description (errors)"),
					  string);
}

@end



@implementation TNProfilerController

- (id)init {
	self = [super initWithWindowNibName:@"Profiler"];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(taskDidTerminate:)
			   name:NSTaskDidTerminateNotification
			 object:NULL];
	
	_path = [[NSFileManager temporaryPathWithPrefix:@"Tuna"] retain];
	[[NSFileManager defaultManager] createDirectoryAtPath:_path];
	
	[self retain];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_task release];
	[_pipe release];
	
	[[NSFileManager defaultManager] removeFileAtPath:_path handler:NULL];
	[_path release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] center];
    [self setShouldCascadeWindows:YES];
    [self setWindowFrameAutosaveName:@"Profiler"];
	
	[_scriptComboBox addItemsWithObjectValues:[[TNSettings settings] objectForKey:TNScriptsHistory]];
	[_argumentsComboBox addItemsWithObjectValues:[[TNSettings settings] objectForKey:TNArgumentsHistory]];
}




- (void)windowWillClose:(NSNotification *)notification {
	if(_task) {
		[_task terminate];
		[_task release];
		_task = NULL;
	}

	[self autorelease];
}



- (void)taskDidTerminate:(NSNotification *)notification {
	if([notification object] == _task) {
		if([_task terminationStatus] == 0)
			[self _success];
		else if(_started)
			[self _error];
		
		_started = NO;

		[_task release];
		_task = NULL;
		
		[_pipe release];
		_pipe = NULL;
		
		[self _updateButtons];
	}
}



- (void)setPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void  *)contextInfo {
	if(returnCode == NSOKButton)
		[_scriptComboBox setStringValue:[[openPanel filename] stringByAbbreviatingWithTildeInPath]];
}



#pragma mark -

- (IBAction)set:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:[NSArray arrayWithObjects:@"pl", @"PL", NULL]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(setPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (IBAction)launch:(id)sender {
	NSString		*script, *argument;
	NSMutableArray	*arguments;
	NSArray			*components;
	NSUInteger		i, count;
	
	if(_started) {
		[_task terminate];
	} else {
		script = [[_scriptComboBox stringValue] stringByStandardizingPath];
		
		if([script length] == 0) {
			NSBeep();
			
			return;
		}
		
		arguments = [NSMutableArray arrayWithObjects:@"-d:DProf", script, NULL];
		components = [[_argumentsComboBox stringValue] componentsSeparatedByCharactersFromSet:
			[NSCharacterSet whitespaceCharacterSet]];
		
		count = [components count];
		
		for(i = 0; i < count; i++) {
			argument = [components objectAtIndex:i];
			
			if([argument hasPrefix:@"~"])
				argument = [argument stringByExpandingTildeInPath];
			
			[arguments addObject:argument];
		}
		
		_pipe = [[NSPipe alloc] init];
		_task = [[NSTask alloc] init];
		[_task setLaunchPath:@"/usr/bin/perl"];
		[_task setCurrentDirectoryPath:_path];
		[_task setStandardError:_pipe];
		[_task setArguments:arguments];
		[_task launch];
	}

	_started = !_started;
	
	[self _updateButtons];
}



- (IBAction)cancel:(id)sender {
	[self close];
}

@end
