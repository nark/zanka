/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "NSAlert-WCAdditions.h"
#import "WCPreferences.h"
#import "WCTracker.h"
#import "WCTrackerConnection.h"
#import "WCTrackers.h"

@interface WCTrackers(Private)

- (void)_update;
- (void)_updateStatus;
- (void)_updateTrackers;
- (WCTracker *)_trackerAtIndex:(NSUInteger)index;
- (WCTracker *)_itemAtIndex:(NSUInteger)index;
- (WCTracker *)_itemAtIndex:(NSUInteger)index inTracker:(WCTracker *)tracker;
- (WCTracker *)_selectedTracker;
- (void)_sortTrackers;
- (void)_openTracker:(WCTracker *)tracker;

@end


@implementation WCTrackers(Private)

- (void)_update {
	[_trackersOutlineView setUsesAlternatingRowBackgroundColors:[[WCSettings settings] boolForKey:WCTrackersAlternateRows]];
	[_trackersOutlineView setNeedsDisplay:YES];
}



- (void)_updateStatus {
	WCTracker	*tracker;
	NSUInteger	count;

	tracker = [self _selectedTracker];
	
	if(!tracker) {
		[_statusTextField setStringValue:@""];
		
		return;
	}

	count = [tracker numberOfServersMatchingFilter:_filter];

	switch([tracker type]) {
		case WCTrackerBonjour:
			[_statusTextField setStringValue:[NSSWF:
				NSLS(@"Bonjour local service discovery %C %lu %@", @"Description of Bonjour tracker ('-', servers, 'server(s)'"),
				0x2014,
				count,
				count == 1
					? NSLS(@"server", @"Server singular")
					: NSLS(@"servers", @"Server plural")]];
			break;

		case WCTrackerTracker:
			[_statusTextField setStringValue:[NSSWF:
				@"%@ %C %lu %@",
				[tracker name],
				0x2014,
				count,
				count == 1
					? NSLS(@"server", @"Server singular")
					: NSLS(@"servers", @"Server plural")]];
			break;

		case WCTrackerCategory:
			[_statusTextField setStringValue:[NSSWF:
				@"%@ %C %lu %@",
				[tracker name],
				0x2014,
				count,
				count == 1
					? NSLS(@"server", @"Server singular")
					: NSLS(@"servers", @"Server plural")]];
			break;

		case WCTrackerServer:
			[_statusTextField setStringValue:[NSSWF:
				@"%@ %C %@",
				[tracker name],
				0x2014,
				[tracker netService]
					? NSLS(@"Local server via Bonjour", @"Description of server via Bonjour tracker")
					: [[tracker URL] humanReadableString]]];
			break;
	}
}



- (void)_updateTrackers {
	NSEnumerator		*enumerator;
	NSDictionary		*bookmark;
	
	[_trackers removeAllObjects];
	[_trackers addObject:_bonjourTracker];
	
	enumerator = [[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectEnumerator];
	
	while((bookmark = [enumerator nextObject]))
		[_trackers addObject:[WCTracker trackerWithBookmark:bookmark]];
	
	[_trackersOutlineView reloadData];
}



- (WCTracker *)_trackerAtIndex:(NSUInteger)index {
	return [_trackers objectAtIndex:index];
}



- (WCTracker *)_itemAtIndex:(NSUInteger)index {
	return [_trackersOutlineView itemAtRow:index];
}



- (WCTracker *)_itemAtIndex:(NSUInteger)index inTracker:(WCTracker *)tracker {
	NSArray			*children;
	NSUInteger		i;
	
	children = [tracker childrenMatchingFilter:_filter];
	i = ([_trackersOutlineView sortOrder] == WISortDescending)
		? [children count] - index - 1
		: index;
	
	return [children objectAtIndex:i];
}



- (WCTracker *)_selectedTracker {
	NSInteger		row;
	
	row = [_trackersOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_trackersOutlineView itemAtRow:row];
}



- (void)_sortTrackers {
	NSEnumerator	*enumerator;
	NSTableColumn   *tableColumn;
	WCTracker		*tracker;
	SEL				selector;
	
	tableColumn = [_trackersOutlineView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		selector = @selector(compareName:);
	else if(tableColumn == _usersTableColumn)
		selector = @selector(compareUsers:);
	else if(tableColumn == _speedTableColumn)
		selector = @selector(compareSpeed:);
	else if(tableColumn == _guestTableColumn)
		selector = @selector(compareGuest:);
	else if(tableColumn == _downloadTableColumn)
		selector = @selector(compareDownload:);
	else if(tableColumn == _filesTableColumn)
		selector = @selector(compareFiles:);
	else if(tableColumn == _sizeTableColumn)
		selector = @selector(compareSize:);
	else if(tableColumn == _descriptionTableColumn)
		selector = @selector(compareDescription:);
	else
		selector = @selector(compareName:);
	
	enumerator = [_trackers objectEnumerator];
	
	while((tracker = [enumerator nextObject]))
		[tracker sortChildrenUsingSelector:selector];
}



- (void)_openTracker:(WCTracker *)tracker {
	WCTrackerConnection		*connection;

	[tracker removeAllChildren];
	[tracker setState:WCTrackerLoading];
	
	[_progressIndicator startAnimation:self];
	
	connection = [WCTrackerConnection trackerConnectionWithURL:[tracker URL] tracker:tracker];

	[connection addObserver:self
				   selector:@selector(connectionDidClose:)
					   name:WCConnectionDidClose];

	[connection addObserver:self
				   selector:@selector(connectionDidTerminate:)
					   name:WCConnectionDidTerminate];

	[connection addObserver:self
				   selector:@selector(connectionReceivedError:)
					   name:WCConnectionReceivedError];

	[connection addObserver:self
				   selector:@selector(trackersReceivedCategory:)
					   name:WCTrackersReceivedCategory];
	
	[connection addObserver:self
				   selector:@selector(trackersCompletedCategories:)
					   name:WCTrackersCompletedCategories];
	
	[connection addObserver:self
				   selector:@selector(trackersReceivedServer:)
					   name:WCTrackersReceivedServer];
	
	[connection addObserver:self
				   selector:@selector(trackersCompletedServers:)
					   name:WCTrackersCompletedServers];
	
	[connection connect];
}

@end


@implementation WCTrackers

+ (WCTrackers *)trackers {
	static id	sharedTrackers;

	if(!sharedTrackers)
		sharedTrackers = [[self alloc] init];

	return sharedTrackers;
}



- (id)init {
	self = [super initWithWindowNibName:@"Trackers"];

	_trackers = [[NSMutableArray alloc] init];

	_filter = [[NSMutableString alloc] init];
	
	_browser = [[NSNetServiceBrowser alloc] init];
	[_browser setDelegate:self];
	[_browser searchForServicesOfType:WCBonjourName inDomain:@""];
	
	_bonjourTracker = [[WCTracker bonjourTracker] retain];

	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(trackerBookmarksDidChange:)
			   name:WCTrackerBookmarksDidChange];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_trackers release];
	[_browser release];
	[_filter release];
	
	[_bonjourTracker release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WIIconCell		*iconCell;

	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Trackers"];
	
	iconCell = [[WIIconCell alloc] init];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];

	[_searchField setRecentsAutosaveName:@"Trackers"];

	[_trackersOutlineView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[_trackersOutlineView setTarget:self];
	[_trackersOutlineView setDoubleAction:@selector(open:)];
	[_trackersOutlineView setAutoresizesOutlineColumn:NO];
	[_trackersOutlineView setAllowsUserCustomization:YES];
	[_trackersOutlineView setAutosaveName:@"Trackers"];
	[_trackersOutlineView setAutosaveTableColumns:YES];

	[self _update];
	[self _updateTrackers];
	[self _updateStatus];

	[_trackersOutlineView expandItem:_bonjourTracker];

	[[self window] makeFirstResponder:_trackersOutlineView];
}



- (void)connectionDidClose:(NSNotification *)notification {
	WCError		*error;
	
	error = [[notification userInfo] objectForKey:WCErrorKey];
	
	if(!error)
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientServerDisconnected];
	
	[[error alert] beginSheetModalForWindow:[self window]];
	
	[_progressIndicator stopAnimation:self];
	
	[[notification object] terminate];
}



- (void)connectionDidTerminate:(NSNotification *)notification {
	NSLog(@"terminated");
	[[[notification object] tracker] setState:WCTrackerIdle];
	
	[_progressIndicator stopAnimation:self];
}



- (void)connectionReceivedError:(NSNotification *)notification {
	WCTrackerConnection	*connection;
	WCError				*error;

	connection = [notification object];
	error = [[notification userInfo] objectForKey:WCErrorKey];
	
	[[error alert] beginSheetModalForWindow:[self window]];
	
	[connection terminate];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)trackerBookmarksDidChange:(NSNotification *)notification {
	[self _updateTrackers];
	[self _updateStatus];
}



- (void)trackersReceivedCategory:(NSNotification *)notification {
	NSArray			*fields;
	NSString		*category;
	WCTracker		*tracker;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	category	= [fields safeObjectAtIndex:0];
	tracker		= [[[notification object] tracker] categoryForPath:[category stringByDeletingLastPathComponent]];
	
	[tracker addChild:[WCTracker trackerCategoryWithName:[category lastPathComponent]]];
}



- (void)trackersCompletedCategories:(NSNotification *)notification {
}



- (void)trackersReceivedServer:(NSNotification *)notification {
	NSString		*category;
	NSArray			*fields;
	WCTracker		*tracker;

	fields		= [[notification userInfo] objectForKey:WCArgumentsKey];
	category	= [fields safeObjectAtIndex:0];
	tracker		= [[[notification object] tracker] categoryForPath:category];

	[tracker addChild:[WCTracker trackerServerWithArguments:fields]];
}



- (void)trackersCompletedServers:(NSNotification *)notification {
	WCTrackerConnection	*connection;

	connection = [notification object];
	
	NSLog(@"%@ terminate", connection);
	[connection terminate];

	[self _sortTrackers];

	[_trackersOutlineView expandItem:[connection tracker]];

	[self _updateStatus];
}



#pragma mark -

- (IBAction)open:(id)sender {
	WIAddress			*address;
	WIError				*error;
	WIURL				*url;
	WCTracker			*tracker;
	WCServerConnection	*connection;

	tracker = [self _selectedTracker];
	
	if([tracker type] == WCTrackerServer) {
		url = [tracker URL];
		
		if(!url && [tracker netService]) {
			address = [WIAddress addressWithNetService:[tracker netService] error:&error];
			
			if(address)
				url = [WIURL URLWithScheme:@"wired" host:[address string] port:[address port]];
			else
				[[error alert] beginSheetModalForWindow:[self window] modalDelegate:NULL didEndSelector:NULL contextInfo:NULL];
		}
		
		if(url) {
			if([[url scheme] isEqualToString:@"wired"]) {
				connection = [WCServerConnection serverConnectionWithURL:url];
				
				[connection showWindow:self];
				
				if(([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) == 0)
					[connection connect];
			}
		}
	}
}



- (IBAction)search:(id)sender {
	[_filter setString:[_searchField stringValue]];
	[_trackersOutlineView reloadData];
}



#pragma mark -

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	[netService setDelegate:self];
	[netService resolveWithTimeout:5.0];

	[_bonjourTracker addChild:[WCTracker bonjourServerWithNetService:netService]];

	if(!moreComing) {
		[_trackersOutlineView reloadData];
		
		[self _updateStatus];
	}
}



- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	NSEnumerator	*enumerator;
	WCTracker		*server;

	enumerator = [_bonjourTracker childEnumerator];

	while((server = [enumerator nextObject])) {
		if([[server netService] isEqualToNetService:netService]) {
			[_bonjourTracker removeChild:server];

			break;
		}
	}

	if(!moreComing) {
		[_trackersOutlineView reloadData];
		
		[self _updateStatus];
	}
}



- (void)netServiceDidResolveAddress:(NSNetService *)netService {
	[netService stop];
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		return [_trackers count];

	return [[item childrenMatchingFilter:_filter] count];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		return [self _trackerAtIndex:index];

	return [self _itemAtIndex:index inTracker:item];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	WCTracker	*tracker;
	
	tracker = item;
	
	if(tableColumn == _nameTableColumn)
		return [tracker nameWithNumberOfServersMatchingFilter:_filter];
	
	if([tracker type] == WCTrackerServer && ![tracker netService]) {
		if(tableColumn == _usersTableColumn)
			return [NSSWF:@"%lu", [tracker users]];
		else if(tableColumn == _speedTableColumn)
			return [NSString humanReadableStringForBandwidth:[tracker speed]];
		else if(tableColumn == _guestTableColumn)
			return [tracker guest] ? NSLS(@"Yes", @"'Yes'") : NSLS(@"No", @"'No'");
		else if(tableColumn == _downloadTableColumn)
			return [tracker download] ? NSLS(@"Yes", @"'Yes'") : NSLS(@"No", @"'No'");
		else if(tableColumn == _filesTableColumn)
			return [NSSWF:@"%lu", [tracker files]];
		else if(tableColumn == _sizeTableColumn)
			return [NSString humanReadableStringForSizeInBytes:[tracker size]];
		else if(tableColumn == _descriptionTableColumn)
			return [tracker serverDescription];
	}

	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	WCTracker	*tracker;
	
	tracker = item;
	
	if(tableColumn == _nameTableColumn)
		[cell setImage:[tracker icon]];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	if([(WCTracker *) item type] != WCTrackerServer)
		return YES;
	
	return NO;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
	WCTracker		*tracker;
	
	tracker = item;
	
	if([tracker type] == WCTrackerTracker && [tracker state] == WCTrackerIdle) {
		[self _openTracker:tracker];
			
		return NO;
	}
	
	return YES;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn {
	[_trackersOutlineView setHighlightedTableColumn:tableColumn];
	[self _sortTrackers];
	[_trackersOutlineView reloadData];
	
	return NO;
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[self _updateStatus];
}



- (void)outlineViewShouldCopyInfo:(NSOutlineView *)outlineView {
	NSPasteboard	*pasteboard;
	NSString		*string;
	WCTracker		*tracker;

	tracker = [self _selectedTracker];

	if([tracker URL])
		string = [[tracker URL] string];
	else
		string = [tracker name];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
	[pasteboard setString:string forType:NSStringPboardType];
}



- (NSString *)outlineView:(NSOutlineView *)outlineView stringValueByItem:(id)item {
	return [item name];
}

@end
