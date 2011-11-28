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

#import "WCDashboardController.h"
#import "WCSettings.h"
#import "WCStatusController.h"

static WCStatusController			*sharedStatusController;


@interface WCStatusController(Private)

- (void)_update;
- (void)_updateVersion;
- (void)_updatePid;
- (void)_updateStatus;
- (void)_updateInterface;

@end


@implementation WCStatusController(Private)

- (void)_update {
	if([self isRunning]) {
		[_statusTextField setStringValue:[NSString stringWithFormat:
			WCLS(@"Wired is running since %@", @"Status"),
			[_dateFormatter stringFromDate:_uptime]]];
	} else {
		if([self isAvailable])
			[_statusTextField setStringValue:WCLS(@"Wired is not running", @"Status")];
		else
			[_statusTextField setStringValue:WCLS(@"Wired is not available", @"Status")];
	}
}



- (void)_updateVersion {
	NSTask			*task;
	NSPipe			*pipe;
	NSFileHandle	*fileHandle;
	NSData			*data;
	NSString		*path, *string;
	
	path = WCExpandWiredPath(@"wired");
	
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[_versionTextField setStringValue:[NSSWF:
			WCLS(@"Wired server at %@ not found", @"Version text field error (path)"),
			path]];
		
		return;
	}
	
	if(![[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
		[_versionTextField setStringValue:[NSSWF:
			WCLS(@"Wired server at %@ is not executable", @"Version text field error (path)"),
			path]];
		
		return;
	}
	
	pipe = [NSPipe pipe];
	fileHandle = [pipe fileHandleForReading];
	
	task = [[NSTask alloc] init];
	[task setLaunchPath:path];
	[task setArguments:[NSArray arrayWithObject:@"-v"]];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task launch];
	
	data = [fileHandle readDataToEndOfFile];
	
	if(data && [data length] > 0) {
		string = [NSString stringWithData:data encoding:NSUTF8StringEncoding];
		
		if(string && [string length] > 0) {
			[_versionTextField setStringValue:[string stringByRemovingSurroundingWhitespace]];
			_available = YES;
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WCWiredStatusDidChange
				object:self];
		}
	}
	
	if(![self isAvailable]) {
		[_versionTextField setStringValue:[NSSWF:
			WCLS(@"Wired server at %@ is not executable", @"Version text field error (path)"),
			path]];
	}
	
	[task release];
}



- (void)_updatePid {
	NSString	*pid;
	NSString	*command;
	BOOL		running;
	
	pid = [NSString stringWithContentsOfFile:WCExpandWiredPath(@"wired.pid")];
	
	if(!pid) {
		running = NO;
	} else {
		command = [[NSWorkspace sharedWorkspace] commandForProcessIdentifier:[pid unsignedIntValue]];
		
		if([command isEqualToString:@"wired"]) {
			running = YES;
		} else {
			[[WCDashboardController dashboardController] removeFileAtPath:WCExpandWiredPath(@"wired.pid")];
			
			running = NO;
		}
	}
	
	if(running != _running) {
		_running = running;
		
		[[NSNotificationCenter defaultCenter]
			postNotificationName:WCWiredStatusDidChange
			object:self];
		
		[self performSelectorOnce:@selector(_update) withObject:NULL afterDelay:0.1];
	}
}



- (void)_updateStatus {
	NSString	*status;
	NSDate		*date;
	
	status = [NSString stringWithContentsOfFile:WCExpandWiredPath(@"wired.status")];
	
	if(!status) {
		[_status removeAllObjects];
	} else {
		[_status setArray:[status componentsSeparatedByString:@" "]];
		
		date = [NSDate dateWithTimeIntervalSince1970:[[_status objectAtIndex:0] intValue]];
		
		if(![date isEqualToDate:_uptime]) {
			[_uptime release];
			_uptime = [date retain];

			[self performSelectorOnce:@selector(_update) withObject:NULL afterDelay:0.1];
		}
	}
}



- (void)_updateInterface {
	NSString			*inSpeedString, *outSpeedString;
	NSTimeInterval		interval;
	unsigned long long	inBytes, outBytes;
	unsigned int		inSpeed, outSpeed;
	int					users, downloads, uploads;
	
	users = [[_status objectAtIndex:1] intValue];

	if(_usersGraphView) {
		[_usersData removeObjectAtIndex:0];
		[_usersData addObject:[NSNumber numberWithInt:users]];
		[_usersGraphView setInData:_usersData];
		[_usersGraphView setNeedsDisplay:YES];
		[_usersGraphView setInLabel:[NSSWF:@"%u %@",
			users,
			users == 1
				? WCLS(@"user", @"User singular")
				: WCLS(@"users", @"User plural")]];
	}
	
	downloads = [[_status objectAtIndex:3] unsignedIntValue];
	uploads = [[_status objectAtIndex:5] unsignedIntValue];

	if(_transfersGraphView) {
		[_downloadsData removeObjectAtIndex:0];
		[_downloadsData addObject:[NSNumber numberWithUnsignedInt:downloads]];
		[_uploadsData removeObjectAtIndex:0];
		[_uploadsData addObject:[NSNumber numberWithUnsignedInt:uploads]];
		[_transfersGraphView setInData:_uploadsData];
		[_transfersGraphView setOutData:_downloadsData];
		[_transfersGraphView setNeedsDisplay:YES];
		[_transfersGraphView setInLabel:[NSSWF:@"%u %@",
			uploads,
			uploads == 1
				? WCLS(@"ul", @"Upload singular")
				: WCLS(@"uls", @"Upload plural")]];
		[_transfersGraphView setOutLabel:[NSSWF:@"%u %@",
			downloads,
			downloads == 1
				? WCLS(@"dl", @"Download singular")
				: WCLS(@"dls", @"Download plural")]];
	}
		
	inBytes = [[_status objectAtIndex:8] unsignedLongLongValue];
	outBytes = [[_status objectAtIndex:7] unsignedLongLongValue];
	inSpeed = 0;
	outSpeed = 0;
	
	if(_inBytes > 0 || _outBytes > 0) {
		interval = [WCSettings doubleForKey:WCUpdateInterval];

		if(_inBytes > 0 && inBytes > _inBytes)
			inSpeed = (inBytes - _inBytes) / interval;
		
		if(_outBytes > 0 && outBytes > _outBytes)
			outSpeed = (outBytes - _outBytes) / interval;
	}

	_inBytes = inBytes;
	_outBytes = outBytes;

	inSpeedString = [NSSWF:@"%@/s", [NSString humanReadableStringForSizeInBytes:inSpeed]];
	outSpeedString = [NSSWF:@"%@/s", [NSString humanReadableStringForSizeInBytes:outSpeed]];
		
	if(_bandwidthGraphView) {
		[_inData removeObjectAtIndex:0];
		[_inData addObject:[NSNumber numberWithUnsignedInt:inSpeed]];
		[_outData removeObjectAtIndex:0];
		[_outData addObject:[NSNumber numberWithUnsignedInt:outSpeed]];
		[_bandwidthGraphView setInData:_inData];
		[_bandwidthGraphView setOutData:_outData];
		[_bandwidthGraphView setNeedsDisplay:YES];
		[_bandwidthGraphView setInLabel:[NSSWF:@"%@ %@",
			inSpeedString,
			WCLS(@"in", @"Speed in")]];
		[_bandwidthGraphView setOutLabel:[NSSWF:@"%@ %@",
			outSpeedString,
			WCLS(@"out", @"Speed out")]];
	}

	[_currentUsersTextField setIntValue:users];
	[_totalUsersTextField setStringValue:[_status objectAtIndex:2]];
	[_currentDownloadsTextField setIntValue:downloads];
	[_totalDownloadsTextField setStringValue:[_status objectAtIndex:4]];
	[_currentUploadsTextField setIntValue:uploads];
	[_totalUploadsTextField setStringValue:[_status objectAtIndex:6]];
	[_dataInTextField setStringValue:[NSString humanReadableStringForSizeInBytes:inBytes]];
	[_dataOutTextField setStringValue:[NSString humanReadableStringForSizeInBytes:outBytes]];
	[_dataInPerSecTextField setStringValue:inSpeedString];
	[_dataOutPerSecTextField setStringValue:outSpeedString];
}

@end


@implementation WCStatusController

+ (WCStatusController *)statusController {
	return sharedStatusController;
}



- (id)init {
	self = [super init];
	
	sharedStatusController = self;
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	return self;
}



- (void)awakeFromNib {
	NSNumber	*value;
	int			i;
	
	_status = [[NSMutableArray alloc] init];
	_usersData = [[NSMutableArray alloc] initWithCapacity:WCStatusDataPoints];
	_downloadsData = [[NSMutableArray alloc] initWithCapacity:WCStatusDataPoints];
	_uploadsData = [[NSMutableArray alloc] initWithCapacity:WCStatusDataPoints];
	_inData = [[NSMutableArray alloc] initWithCapacity:WCStatusDataPoints];
	_outData = [[NSMutableArray alloc] initWithCapacity:WCStatusDataPoints];
	
	for(i = 0, value = [NSNumber numberWithInt:0]; i < WCStatusDataPoints; i++) {
		[_usersData addObject:value];
		[_downloadsData addObject:value];
		[_uploadsData addObject:value];
		[_inData addObject:value];
		[_outData addObject:value];
	}
}



- (void)awakeFromController {
	[self _updateVersion];
	[self _update];
	
	_timer = [[NSTimer scheduledTimerWithTimeInterval:[WCSettings doubleForKey:WCUpdateInterval]
											   target:self
											 selector:@selector(statusTimer:)
											 userInfo:NULL
											  repeats:YES] retain];
	[_timer fire];
}



- (void)updateFromController {
	[_timer fire];
}



- (void)dealloc {
	[_dateFormatter release];
	
	[_timer release];

	[_status release];
	[_usersData release];
	[_downloadsData release];
	[_uploadsData release];
	[_inData release];
	[_outData release];

	[super dealloc];
}



#pragma mark -

- (void)statusTimer:(NSTimer *)timer {
	[self _updatePid];
	
	if(_running)
		[self _updateStatus];
	
	if(_running && [_status count] > 0)
		[self _updateInterface];
	
	[_timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:[WCSettings doubleForKey:WCUpdateInterval]]];
}



#pragma mark -

- (BOOL)isRunning {
	return _running;
}



- (BOOL)isAvailable {
	return _available;
}



- (NSArray *)status {
	return [_status count] > 0 ? _status : NULL;
}

@end
