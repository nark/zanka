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

#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCSearch.h"
#import "WCTransfers.h"

#define WCSearchTypeAudioExtensions		@"aif aiff au mid midi mp3 mp4 wav"
#define WCSearchTypeImageExtensions		@"bmp ico eps jpg jpeg tif tiff gif pict pct png psd sgi tga"
#define WCSearchTypeMovieExtensions		@"avi dv flash mp4 mpg mpg4 mpeg mov rm swf wvm"


@interface WCSearch(Private)

+ (NSSet *)_audioFileTypes;
+ (NSSet *)_imageFileTypes;
+ (NSSet *)_movieFileTypes;

- (id)_initSearchWithConnection:(WCServerConnection *)connection;

@end


@implementation WCSearch(Private)

+ (NSSet *)_audioFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSSet *)_imageFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSSet *)_movieFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



#pragma mark -

- (id)_initSearchWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Search"
								   name:NSLS(@"Search", @"Search window title")
							 connection:connection];

	_receivedFiles = [[NSMutableSet alloc] init];

	[self window];

	[[self connection] addObserver:self
						  selector:@selector(searchReceivedFile:)
							  name:WCSearchReceivedFile];

	[[self connection] addObserver:self
						  selector:@selector(searchCompletedFiles:)
							  name:WCSearchCompletedFiles];
	
	[self retain];

	return self;
}

@end


@implementation WCSearch

+ (id)searchWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initSearchWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_receivedFiles release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_filesTableView setDoubleAction:@selector(open:)];
	
	[super windowDidLoad];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[[self window] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCSearchWindow"] restoreSize:YES visibility:![self isHidden]];
	[_filesTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCSearchTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[self window] propertiesDictionary] forKey:@"WCSearchWindow"];
	[windowTemplate setObject:[_filesTableView propertiesDictionary] forKey:@"WCSearchTableView"];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[_filesTableView setDataSource:NULL];

	[self close];
	[self autorelease];
}



- (void)serverConnectionLoggedIn:(NSNotification *)notification {
	[self windowTemplate];

	[self validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self connection] name] withSubtitle:[self name]];
}



- (void)searchReceivedFile:(NSNotification *)notification {
	WCFile		*file;
	BOOL		add = NO;

	file = [WCFile fileWithListArguments:[[notification userInfo] objectForKey:WCArgumentsKey]];

	if(![_receivedFiles containsObject:file]) {
		switch(_searchType) {
			case WCSearchTypeAny:
				add = YES;
				break;

			case WCSearchTypeFolder:
				if([file type] != WCFileFile)
					add = YES;
				break;

			case WCSearchTypeDocument:
				if([file type] == WCFileFile)
					add = YES;
				break;

			case WCSearchTypeAudio:
				if([[[self class] _audioFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeImage:
				if([[[self class] _imageFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeMovie:
				if([[[self class] _movieFileTypes] containsObject:[file extension]])
					add = YES;
				break;
		}

		if(add) {
			[_receivedFiles addObject:file];

			if([_receivedFiles count] == 10) {
				[_files addObjectsFromArray:[_receivedFiles allObjects]];
				[_receivedFiles removeAllObjects];

				[_filesTableView reloadData];
			}
		}
	}
}



- (void)searchCompletedFiles:(NSNotification *)notification {
	[_progressIndicator stopAnimation:self];
	[_files addObjectsFromArray:[_receivedFiles allObjects]];

	[self updateStatus];
	[self sortFiles];
	
	[_filesTableView reloadData];
	[_filesTableView setNeedsDisplay:YES];
}



#pragma mark -

- (void)validate {
	[_searchButton setEnabled:[[self connection] isConnected]];
	
	[super validate];
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL			selector;
	BOOL		connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(open:))
		return ([[self selectedFile] isFolder] && connected);
	else if(selector == @selector(revealInFiles:))
		return ([self selectedFile] != NULL && connected);
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (IBAction)search:(id)sender {
	if([[_searchTextField stringValue] length] == 0)
		return;
	
	_searchType = [[_kindPopUpButton selectedItem] tag];

	[_receivedFiles removeAllObjects];
	[_files removeAllObjects];
	[_filesTableView reloadData];

	[_statusTextField setStringValue:@""];
	[_progressIndicator startAnimation:self];

	[[self connection] sendCommand:WCSearchCommand withArgument:[_searchTextField stringValue]];
}



- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	if(![[self connection] isConnected])
		return;

	enumerator = [[self selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([file isFolder])
			[WCFiles filesWithConnection:[self connection] path:file];
		else
			[[[self connection] transfers] downloadFile:file];
	}
}



- (IBAction)revealInFiles:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file, *parentFile;

	enumerator = [[self selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		parentFile = [WCFile fileWithDirectory:[[file path] stringByDeletingLastPathComponent]];
		
		[WCFiles filesWithConnection:[self connection] path:parentFile selectPath:[file path]];
	}
}

@end
