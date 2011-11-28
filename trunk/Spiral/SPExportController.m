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

#import "SPExportCell.h"
#import "SPExportController.h"
#import "SPExportJob.h"
#import "SPPlaylistItem.h"
#import "SPSettings.h"

@implementation SPExportController

+ (SPExportController *)exportController {
	static SPExportController		*exportController;
	
	if(!exportController)
		exportController = [[[self class] alloc] init];
	
	return exportController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Export"];
	
	_formats	= [[NSMutableArray alloc] initWithContentsOfFile:
		[[NSBundle mainBundle] pathForResource:@"ExportFormats" ofType:@"plist"]];
	_jobs		= [[NSMutableArray alloc] init];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[_formats release];
	[_jobs release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSDictionary	*format;
	id				cell;
	
	cell = [[SPExportCell alloc] init];
	[_jobTableColumn setDataCell:cell];
	[cell release];
	
	cell = [[NSButtonCell alloc] init];
	[cell setBordered:NO];
	[cell setImage:[NSImage imageNamed:@"StopExport"]];
	[cell setAlternateImage:[NSImage imageNamed:@"StopExportPressed"]];
	[cell setHighlightsBy:NSContentsCellMask];
	[cell setTarget:self];
	[cell setAction:@selector(stop:)];
	[_stopTableColumn setDataCell:cell];
	[cell release];
	
	for(format in _formats) {
		[_formatPopUpButton addItem:[NSMenuItem itemWithTitle:[format objectForKey:@"Name"]
														image:[NSImage imageNamed:[format objectForKey:@"Image"]]]];
	}

	[_formatPopUpButton selectItemWithTitle:[[SPSettings settings] objectForKey:SPSelectedExportFormat]];
	
	if([_formatPopUpButton indexOfSelectedItem] == -1)
		[_formatPopUpButton selectItemAtIndex:0];
}



- (void)exportJobProgressed:(SPExportJob *)job {
	[_exportsTableView display];
}



- (void)exportJobCompleted:(SPExportJob *)job {
	[[job progressIndicator] removeFromSuperview];

	[_jobs removeObject:job];
	
	[_exportsTableView reloadData];

	if([_jobs count] == 0)
		[self close];
}



- (void)exportJobStopped:(SPExportJob *)job {
	[[job progressIndicator] removeFromSuperview];

	[_jobs removeObject:job];
	
	[_exportsTableView reloadData];

	if([_jobs count] == 0)
		[self close];
}



- (void)exportJob:(SPExportJob *)job failedWithError:(NSError *)error {
	[_jobs removeObject:job];
	
	[[job progressIndicator] removeFromSuperview];

	[_exportsTableView reloadData];
	
	if([_jobs count] == 0)
		[self close];
	
	[[error alert] runModal];
}



#pragma mark -

- (void)stop:(id)sender {
	SPExportJob		*job;
	
	job = [_jobs objectAtIndex:[[_exportsTableView selectedRowIndexes] firstIndex]];
	
	[job stop];
}



#pragma mark -

- (NSArray *)exportFormats {
	return _formats;
}



- (NSDictionary *)exportFormatWithName:(NSString *)name {
	NSDictionary	*format;
	
	for(format in [self exportFormats]) {
		if([name isEqualToString:[format objectForKey:@"Name"]])
			return format;
	}
	
	return NULL;
}



#pragma mark -

- (void)beginSavePanelForWindow:(NSWindow *)window movie:(QTMovie *)movie playlistFile:(SPPlaylistFile *)playlistFile audioPattern:(NSString *)audioPattern subtitlePattern:(NSString *)subtitlePattern {
	NSSavePanel		*savePanel;
	
	_path				= [[playlistFile resolvedPath] retain];
	_audioPattern		= [audioPattern retain];
	_subtitlePattern	= [subtitlePattern retain];
	_playlistFile		= [playlistFile retain];
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView:_exportView];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"mp4"]];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setPrompt:NSLS(@"Export", @"Export panel button title")];
	
	[savePanel beginSheetForDirectory:[_path stringByDeletingLastPathComponent]
								 file:[[_path lastPathComponent] stringByReplacingPathExtensionWithExtension:@"mp4"]
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)savePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString			*format;
	SPExportJob			*job;

	if(returnCode == NSOKButton) {
		format = [_formatPopUpButton titleOfSelectedItem];
		
		job = [SPExportJob exportJobWithPath:_path
										file:[savePanel filename]
									  format:[self exportFormatWithName:format]];
		[job setDelegate:self];
		[job setAudioPattern:_audioPattern];
		[job setSubtitlePattern:_subtitlePattern];
		[job setMetadata:[_playlistFile metadata]];
		[_jobs addObject:job];
		[job start];
		
		[_exportsTableView reloadData];
		
		[self showWindow:self];
	
		[[SPSettings settings] setObject:format forKey:SPSelectedExportFormat];
	}
	
	[_audioPattern release];
	_audioPattern = NULL;
	
	[_subtitlePattern release];
	_subtitlePattern = NULL;
	
	[_path release];
	_path = NULL;
	
	[_playlistFile release];
	_playlistFile = NULL;
}



- (NSUInteger)numberOfExports {
	return [_jobs count];
}



- (void)stopAllExports {
	[_jobs makeObjectsPerformSelector:@selector(stop)];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_jobs count];
	
	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSImage			*image;
	SPExportJob		*job;
	
	if(tableColumn == _iconTableColumn) {
		image = [NSImage imageNamed:@"mpeg4"];
		[image setSize:NSMakeSize(32.0, 32.0)];
		return image;
	}
	else if(tableColumn == _jobTableColumn) {
		job = [_jobs objectAtIndex:row];
		
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[job name],					WCExportCellNameKey,
			[job status],				WCExportCellStatusKey,
			[job progressIndicator],	WCExportCellProgressKey,
			NULL];
	}
		
	return NULL;
}

@end
