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

#import "SPApplicationController.h"
#import "SPExportJob.h"
#import "SPFilenameMetadataGatherer.h"
#import "SPPlaylistItem.h"
#import "SPSettings.h"

@interface SPExportJob(Private)

- (id)_initWithPath:(NSString *)path file:(NSString *)file format:(NSDictionary *)format;

- (void)_startExportTask;
- (void)_startMetadataTask;
- (void)_startXattrTask;

- (NSError *)_errorWithFailureReason:(NSString *)reason;

@end


@implementation SPExportJob(Private)

- (id)_initWithPath:(NSString *)path file:(NSString *)file format:(NSDictionary *)format {
	self = [super init];
	
	_path					= [path retain];
	_file					= [file retain];
	_format					= [format retain];
	
	_audioPattern			= [[[SPSettings settings] objectForKey:SPPreferredAudioPattern] retain];
	_subtitlePattern		= [[[SPSettings settings] objectForKey:SPPreferredSubtitlePattern] retain];
	
	_progressIndicator		= [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)];

	[_progressIndicator setIndeterminate:YES];
	[_progressIndicator setUsesThreadedAnimation:YES];
	[_progressIndicator setMinValue:0.0];
	[_progressIndicator setMaxValue:1.0];

	return self;
}



#pragma mark -

- (void)_startExportTask {
	NSMutableArray		*arguments;
	NSDictionary		*attributes;
	NSError				*error;
	
	[_progressIndicator setIndeterminate:YES];
	
	attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[_file stringByDeletingLastPathComponent]
																  error:&error];
	
	if(!attributes) {
		if([delegate respondsToSelector:@selector(exportJob:failedWithError:)])
			[delegate exportJob:self failedWithError:error];
		
		return;
	}

	arguments = [NSMutableArray arrayWithObjects:
		@"-i",
		_path,
		@"-o",
		_file,
		@"-f",
		[_format objectForKey:@"Name"],
		@"-p",
		[[NSBundle mainBundle] bundlePath],
		NULL];
	
	if([_audioPattern length] > 0) {
		[arguments addObject:@"-a"];
		[arguments addObject:_audioPattern];
	}
	
	if([_subtitlePattern length] > 0) {
		[arguments addObject:@"-s"];
		[arguments addObject:_subtitlePattern];
	}

	_exportTask = [[NSTask alloc] init];
	[_exportTask setLaunchPath:[[self bundle] pathForResource:@"SpiralExporter" ofType:@""]];
	[_exportTask setArguments:arguments];
	[_exportTask setStandardOutput:[NSPipe pipe]];
	[_exportTask setStandardError:[_exportTask standardOutput]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(exportFileHandleReadCompletion:) 
			   name:NSFileHandleReadCompletionNotification 
			 object:[[_exportTask standardOutput] fileHandleForReading]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(exportTaskDidTerminate:) 
			   name:NSTaskDidTerminateNotification 
			 object:_exportTask];
	
	[[[_exportTask standardOutput] fileHandleForReading] readInBackgroundAndNotify];
	
	[_exportTask launch];
}



- (void)_startMetadataTask {
	NSMutableArray		*arguments;
	BOOL				isTVShow;
	
	[_progressIndicator setIndeterminate:YES];
	
	arguments = [NSMutableArray arrayWithObjects:
		_file,
		@"--overWrite",
		@"--encodingTool",
		[NSApp name],
		NULL];
	
	isTVShow = NO;
	
	if([_metadata objectForKey:SPFilenameMetadataFilenameKey]) {
		[arguments addObject:@"--title"];
		[arguments addObject:[[_metadata objectForKey:SPFilenameMetadataFilenameKey] description]];
	}
	
	if([_metadata objectForKey:SPFilenameMetadataTVShowSeasonKey]) {
		[arguments addObject:@"--TVSeasonNum"];
		[arguments addObject:[[_metadata objectForKey:SPFilenameMetadataTVShowSeasonKey] description]];
		
		isTVShow = YES;
	}

	if([_metadata objectForKey:SPFilenameMetadataTVShowEpisodeKey]) {
		[arguments addObject:@"--TVEpisodeNum"];
		[arguments addObject:[[_metadata objectForKey:SPFilenameMetadataTVShowEpisodeKey] description]];
		
		isTVShow = YES;
	}
	
	if(isTVShow && [_metadata objectForKey:SPFilenameMetadataTitleKey]) {
		[arguments addObject:@"--TVShowName"];
		[arguments addObject:[[_metadata objectForKey:SPFilenameMetadataTitleKey] description]];
	}
	
	[arguments addObject:@"--stik"];
	[arguments addObject:isTVShow ? @"TV Show" : @"Movie"];
	
	_metadataTask = [[NSTask alloc] init];
	[_metadataTask setLaunchPath:[[self bundle] pathForResource:@"AtomicParsley" ofType:@""]];
	[_metadataTask setArguments:arguments];
	[_metadataTask setStandardOutput:[NSPipe pipe]];
	[_metadataTask setStandardError:[_metadataTask standardOutput]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(postExportFileHandleReadCompletion:) 
			   name:NSFileHandleReadCompletionNotification 
			 object:[[_metadataTask standardOutput] fileHandleForReading]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(postExportTaskDidTerminate:) 
			   name:NSTaskDidTerminateNotification 
			 object:_metadataTask];
	
	[[[_metadataTask standardOutput] fileHandleForReading] readInBackgroundAndNotify];
	
	[_metadataTask launch];
}



- (void)_startXattrTask {
	NSMutableArray		*arguments;
	
	[_progressIndicator setIndeterminate:YES];
	
	arguments = [NSMutableArray arrayWithObjects:
		@"-d",
		@"com.apple.FinderInfo",
		_file,
		NULL];
	
	_xattrTask = [[NSTask alloc] init];
	[_xattrTask setLaunchPath:@"/usr/bin/xattr"];
	[_xattrTask setArguments:arguments];
	[_xattrTask setStandardOutput:[NSPipe pipe]];
	[_xattrTask setStandardError:[_xattrTask standardOutput]];

	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(postExportFileHandleReadCompletion:) 
			   name:NSFileHandleReadCompletionNotification 
			 object:[[_xattrTask standardOutput] fileHandleForReading]];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		   selector:@selector(postExportTaskDidTerminate:) 
			   name:NSTaskDidTerminateNotification 
			 object:_xattrTask];
	
	[[[_xattrTask standardOutput] fileHandleForReading] readInBackgroundAndNotify];
	
	[_xattrTask launch];
}



#pragma mark -

- (NSError *)_errorWithFailureReason:(NSString *)reason {
	NSMutableDictionary		*userInfo;
	
	userInfo = [NSMutableDictionary dictionary];
	
	[userInfo setObject:[NSSWF:NSLS(@"Could not export \u201c%@\u201d", @"Export error (file)"), [self name]]
				 forKey:NSLocalizedDescriptionKey];
	[userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
	
	return [NSError errorWithDomain:SPSpiralErrorDomain code:SPSpiralExportFailed userInfo:userInfo];
}

@end



@implementation SPExportJob

+ (id)exportJobWithPath:(NSString *)path file:(NSString *)file format:(NSDictionary *)format {
	return [[[self alloc] _initWithPath:path file:file format:format] autorelease];
}



#pragma mark -

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_path release];
	[_file release];
	[_format release];
	[_audioPattern release];
	[_subtitlePattern release];
	[_metadata release];
	
	[_exportTask release];
	[_metadataTask release];
	[_xattrTask release];
	
	[_progressIndicator release];
	
	[super dealloc];
}



#pragma mark -

- (void)exportFileHandleReadCompletion:(NSNotification *)notification {
	NSError			*error;
	NSData			*data;
	NSString		*string, *line, *message;
	NSArray			*array;
	
    data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	if([data length] > 0) {
		string = [[NSString stringWithData:data encoding:NSUTF8StringEncoding]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		for(line in [string componentsSeparatedByString:@"\n"]) {
			array = [line componentsSeparatedByString:@":"];
			
			if([array count] > 0) {
				message = [array objectAtIndex:0];
				
				if([message isEqualToString:@"STATUS"] && [array count] == 2) {
					[_status release];
					_status = [[array objectAtIndex:1] retain];

					if([delegate respondsToSelector:@selector(exportJobProgressed:)])
						[delegate exportJobProgressed:self];
				}
				else if([message isEqualToString:@"LOADTRACKS"] && [array count] == 2) {
					_loadTracksPercent = [[array objectAtIndex:1] doubleValue];
					
					if([delegate respondsToSelector:@selector(exportJobProgressed:)])
						[delegate exportJobProgressed:self];
				}
				else if([message isEqualToString:@"EXPORT"] && [array count] == 2) {
					_exportPercent = [[array objectAtIndex:1] doubleValue];
					
					if(_startTime == 0.0) {
						_startTime = [NSDate timeIntervalSinceReferenceDate];
						[_progressIndicator setIndeterminate:NO];
					}

					[_progressIndicator setDoubleValue:_exportPercent / 100.0];
					
					if([delegate respondsToSelector:@selector(exportJobProgressed:)])
						[delegate exportJobProgressed:self];
				}
				else if([message isEqualToString:@"COMPLETE"]) {
					[[NSNotificationCenter defaultCenter]
						removeObserver:self
								  name:NSTaskDidTerminateNotification
								object:_exportTask];
					
					if([_format boolForKey:@"SetiTunesMetadata"]) {
						[_status release];
						_status = NSLS(@"Setting iTunes metadata...", @"Export status");
						
						if([delegate respondsToSelector:@selector(exportJobProgressed:)])
							[delegate exportJobProgressed:self];
						
						[self _startMetadataTask];
					}
					
					if([_format boolForKey:@"ClearResourceFork"]) {
						[_status release];
						_status = NSLS(@"Clearing resource fork...", @"Export status");
						
						if([delegate respondsToSelector:@selector(exportJobProgressed:)])
							[delegate exportJobProgressed:self];
						
						[self _startXattrTask];
					}
				}
				else if([message isEqualToString:@"ERROR"] && [array count] == 2) {
					[[NSNotificationCenter defaultCenter]
						removeObserver:self
								  name:NSTaskDidTerminateNotification
								object:_exportTask];

					if([delegate respondsToSelector:@selector(exportJob:failedWithError:)]) {
						error = [self _errorWithFailureReason:[array objectAtIndex:1]];
						
						[delegate exportJob:self failedWithError:error];
					}
				}
			}
		}
		
		// There's a bug in QuickTime where exports fail with error -9459 if the display
		// dims while exporting.
		UpdateSystemActivity(UsrActivity);
		
		[[notification object] readInBackgroundAndNotify];
	}
}



- (void)exportTaskDidTerminate:(NSNotification *)notification {
	NSError			*error;
	
	if(_stopping) {
		if([delegate respondsToSelector:@selector(exportJobStopped:)])
			[delegate exportJobStopped:self];
	}
	else if([_exportTask terminationStatus] != 0) {
		if([delegate respondsToSelector:@selector(exportJob:failedWithError:)]) {
			error = [self _errorWithFailureReason:NSLS(@"Exporter terminated for an unknown reason.", @"Export error")];
			
			[delegate exportJob:self failedWithError:error];
		}
	}
}



- (void)postExportFileHandleReadCompletion:(NSNotification *)notification {
	NSData			*data;
	NSString		*string;
	
    data = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
	
	if([data length] > 0) {
		string = [[NSString stringWithData:data encoding:NSUTF8StringEncoding]
			stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSLog(@"*** %@: %@", [self class], string);
		
		[[notification object] readInBackgroundAndNotify];
	}
}



- (void)postExportTaskDidTerminate:(NSNotification *)notification {
	if([delegate respondsToSelector:@selector(exportJobCompleted:)])
		[delegate exportJobCompleted:self];
}



#pragma mark -

- (void)setDelegate:(id <SPExportJobDelegate>)aDelegate {
	delegate = aDelegate;
}



- (id <SPExportJobDelegate>)delegate {
	return delegate;
}



- (void)setPlaylistItem:(SPPlaylistExportItem *)playlistItem {
	_playlistItem = playlistItem;
}



- (SPPlaylistExportItem *)playlistItem {
	return _playlistItem;
}
	


- (void)setAudioPattern:(NSString *)audioPattern {
	[audioPattern retain];
	[_audioPattern release];
	
	_audioPattern = audioPattern;
}



- (NSString *)audioPattern {
	return _audioPattern;
}



- (void)setSubtitlePattern:(NSString *)subtitlePattern {
	[subtitlePattern retain];
	[_subtitlePattern release];
	
	_subtitlePattern = subtitlePattern;
}



- (NSString *)subtitlePattern {
	return _subtitlePattern;
}



- (void)setMetadata:(NSDictionary *)metadata {
	[metadata retain];
	[_metadata release];
	
	_metadata = metadata;
}



- (NSDictionary *)metadata {
	return _metadata;
}



- (NSString *)name {
	return [_file lastPathComponent];
}



- (NSString *)status {
	NSTimeInterval		elapsedTime, remainingTime;
	
	if(!_status)
		return NSLS(@"Waiting...", @"Export status");
	
	if(_exportPercent > 0.0 && _exportPercent < 100.0) {
		elapsedTime		= [NSDate timeIntervalSinceReferenceDate] - _startTime;
		remainingTime	= (100.0 - _exportPercent) * (elapsedTime / _exportPercent);
		
		return [NSSWF:@"%@ \u2014 %.0f%% \u2014 %@", _status, _exportPercent, [NSString humanReadableStringForTimeInterval:remainingTime]];
	}
	else if(_loadTracksPercent < 100.0) {
		return [NSSWF:@"%@ \u2014 %.0f%%", _status, _loadTracksPercent];
	}
	
	return _status;
}



- (NSProgressIndicator *)progressIndicator {
	return _progressIndicator;
}



#pragma mark -

- (void)start {
	if(!_started) {
		[self _startExportTask];
		
		_started = YES;
	}
}



- (void)stop {
	_stopping = YES;
	
	[_exportTask terminate];
	[_metadataTask terminate];
	[_xattrTask terminate];
}

@end
