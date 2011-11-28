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

#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "NSArrayAdditions.h"
#import "NSURLAdditions.h"
#import "WCClient.h"
#import "WCIconCell.h"
#import "WCMain.h"
#import "WCPreferences.h"
#import "WCSecureSocket.h"
#import "WCSettings.h"
#import "WCTracker.h"
#import "WCTrackers.h"
	 
@implementation WCTrackers

- (id)init {
	self = [super initWithWindowNibName:@"Trackers"];

	// --- initiate our array of trackers
	_trackers = [[NSMutableArray alloc] init];
	
	// --- initiate our rendezvous tracker
	_rendezvousTracker = [[WCTracker alloc] initWithType:WCTrackerTypeRendezvous];
	[_rendezvousTracker setName:@"Rendezvous"];
	
	// --- get the icons
	_rendezvousImage = [[NSImage imageNamed:@"Rendezvous"] retain];

	// --- initiate our rendezvous browser
	_browser = [[NSNetServiceBrowser alloc] init];
	
	// --- start the browser
	[_browser setDelegate:self];
	[_browser searchForServicesOfType:@"_wired._tcp." inDomain:@""];
	
	// --- load the window
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_rendezvousImage release];
	
	[_sortUpImage release];
	[_sortDownImage release];
	
	[_trackers release];
	[_browser release];
	[_rendezvousTracker release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	WCIconCell		*iconCell;
	
	// --- set up our custom cell type for the transfer text
	iconCell = [[WCIconCell alloc] initWithImageWidth:16 whitespace:NO];
	[_nameTableColumn setDataCell:iconCell];
	[iconCell release];
	
	// --- add all our trackers from preferences
	[self updateTrackers];
	
	// --- get the sort images
	_sortUpImage	= [[NSImage imageNamed:@"SortUp"] retain];
	_sortDownImage	= [[NSImage imageNamed:@"SortDown"] retain];
	
	// --- connect on double-click
	[_trackersOutlineView setDoubleAction:@selector(open:)];
	
	// --- always show rendezvous tracker
	[_trackersOutlineView expandItem:_rendezvousTracker];

	// --- window position
	[self setWindowFrameAutosaveName:@"Trackers"];
	[self setShouldCascadeWindows:NO];

	// --- table view position
	[_trackersOutlineView setAutosaveName:@"Trackers"];
	[_trackersOutlineView setAutosaveTableColumns:YES];

	// --- simulate a click on the name column to sort by name
	[self outlineView:_trackersOutlineView shouldSelectTableColumn:_nameTableColumn];

	// --- start off in the table view
	[[self window] makeFirstResponder:_trackersOutlineView];
}



#pragma mark -

- (void)updateTrackers {
	// --- clear all
	[_trackers removeAllObjects];
	
	// --- add rendezvous at top
	[_trackers addObject:_rendezvousTracker];
	
	// --- reload table
	[_trackersOutlineView reloadData];
	[self updateStatus];
}



- (void)updateStatus {
	WCTracker	*tracker;
	int			row, count;
	
	// --- get row
	row = [_trackersOutlineView selectedRow];

	if(row < 0) {
		[_statusTextField setStringValue:@""];
		
		return;
	}
	
	// --- get tracker
	tracker = [_trackersOutlineView itemAtRow:row];
	count	= [[[tracker children] serverFilter:_filter] serverCount];
	
	// --- display status
	switch([tracker type]) {
		case WCTrackerTypeRendezvous:
			[_statusTextField setStringValue:[NSString stringWithFormat:
				NSLocalizedString(@"Rendezvous local service discovery, %d %@", @"Description of Rendezvous tracker (servers, 'server(s)'"),
				count,
				count == 1
					? NSLocalizedString(@"server", @"Server singular")
					: NSLocalizedString(@"servers", @"Server plural")]];
			break;

		case WCTrackerTypeServer:
			[_statusTextField setStringValue:[NSString stringWithFormat:
				@"%@",
				[tracker URL]
					? [[tracker URL] humanReadable]
					: NSLocalizedString(@"Local server via Rendezvous", @"Description of server via Rendezvous tracker")]];
	}
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSURL			*url = NULL;
	WCTracker		*server;
	int				row;
	
	// --- get row
	row = [_trackersOutlineView selectedRow];

	if(row < 0)
		return;
	
	// --- get server
	server = [_trackersOutlineView itemAtRow:row];
	
	if([server URL]) {
		url = [server URL];
	}
	else if([server service]) {
		NSArray				*addresses;
		NSString			*ip;
		struct sockaddr_in	*addr;
		int					port;
	
		// --- get address
		addresses = [[server service] addresses];

		if([addresses count] == 0)
			return;
	
		// --- extract URL
		addr	= (struct sockaddr_in *) [[addresses objectAtIndex:0] bytes];
		ip		= [NSString stringWithCString:(char *) inet_ntoa(addr->sin_addr)];
		port	= ntohs(addr->sin_port);
		url		= [NSURL URLWithString:[NSString stringWithFormat:
					@"wired://%@:%d/", ip, port]];
	}

	// --- connect
	if(url && [[url scheme] isEqualToString:@"wired"]) {
		[WCSharedMain showConnect:url];
		
		if(([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) == 0)
			[WCSharedMain connectWithWindow:self];
	}
}



- (IBAction)search:(id)sender {
	_filter = [_searchTextField stringValue];
	
	[_trackersOutlineView reloadData];
}



#pragma mark -

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	NSArray			*arguments;
	NSString		*name, *description;
	WCTracker		*server;

	// --- resolve service
	[netService setDelegate:self];
	[netService resolve];
	
	// --- split the arguments
	arguments   = [[netService name] componentsSeparatedByString:WCFieldSeparator];
	name		= [arguments objectAtIndex:0];
	description = [arguments objectAtIndex:1];
	
	// --- create server record
	server = [[WCTracker alloc] initWithType:WCTrackerTypeServer];
	[server setName:name];
	[server setDescription:description];
	[server setService:netService];
	[_rendezvousTracker addChild:server];
	[server release];
	
	// --- show if last
	if(!moreComing) {
		[_trackersOutlineView reloadData];
		[self updateStatus];
	}
}



- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing {
	NSEnumerator	*enumerator;
	WCTracker		*each;

	// --- loop over all services and compare the fields
	enumerator = [[_rendezvousTracker children] objectEnumerator];
	
	while((each = [enumerator nextObject])) {
		if([[[each service] name] isEqualToString:[netService name]] &&
		   [[[each service] type] isEqualToString:[netService type]] &&
		   [[[each service] domain] isEqualToString:[netService domain]]) {
			[_rendezvousTracker removeChild:each];
			
			break;
		}
	}
	
	// --- show if last
	if(!moreComing) {
		[_trackersOutlineView reloadData];
		[self updateStatus];
	}
}



- (void)netServiceDidResolveAddress:(NSNetService *)sender {
	// --- stop resolving
	[sender stop];
}



#pragma mark -

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectTableColumn:(NSTableColumn *)tableColumn {
	NSEnumerator	*enumerator;
	NSImage			*sortImage;
	WCTracker		*tracker;
	
	if(_lastTableColumn == tableColumn) {
		// --- invert sorting
		_sortDescending = !_sortDescending;
	} else {
		_sortDescending = NO;
		
		if(_lastTableColumn)
			[_trackersOutlineView setIndicatorImage:NULL inTableColumn:_lastTableColumn];
		
		// --- loop over trackers
		enumerator = [_trackers objectEnumerator];
		
		if(tableColumn == _nameTableColumn) {
			while((tracker = [enumerator nextObject]))
				[[tracker children] sortUsingSelector:@selector(nameSort:)];
		}
		else if(tableColumn == _descriptionTableColumn) {
			while((tracker = [enumerator nextObject]))
				[[tracker children] sortUsingSelector:@selector(descriptionSort:)];
		}

		// --- set the new sorting selector
		_lastTableColumn = tableColumn;
		
		[_trackersOutlineView setHighlightedTableColumn:tableColumn];
	}
	
	// --- set the image for the new column header
	sortImage = _sortDescending ? _sortDownImage : _sortUpImage;
	[_trackersOutlineView setIndicatorImage:sortImage inTableColumn:tableColumn];
	[_trackersOutlineView reloadData];

	return NO;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(WCTracker *)item {	
	if([item type] != WCTrackerTypeServer)
		return YES;

	return NO;
}



- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(WCTracker *)item {
	if(!item)
		return [_trackers count];
	
	return [[[item children] serverFilter:_filter] count];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(WCTracker *)item {
	if(!item)
		return [_trackers objectAtIndex:index];
	
	return [[[item children] serverFilter:_filter] objectAtIndex:_sortDescending
				? [[item children] count] - index - 1
				: (unsigned int) index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(WCTracker *)item {
	if(tableColumn == _nameTableColumn) {
		NSString	*string;
		NSImage		*image = NULL;
		
		if([item type] == WCTrackerTypeRendezvous)
			image = _rendezvousImage;

		string = [item name];

		return [NSArray arrayWithObjects:string, image, NULL];
	}
	else if(tableColumn == _descriptionTableColumn && [item type] == WCTrackerTypeServer) {
		return [item description];
	}
	
	return NULL;
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	// --- update status field
	[self updateStatus];
}

@end
