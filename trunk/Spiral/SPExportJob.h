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

@class SPPlaylistExportItem;

@protocol SPExportJobDelegate;

@interface SPExportJob : WIObject {
	id <SPExportJobDelegate>			delegate;
	
	NSString							*_path;
	NSString							*_file;
	NSDictionary						*_format;
	NSString							*_audioPattern;
	NSString							*_subtitlePattern;
	NSDictionary						*_metadata;
	
	SPPlaylistExportItem				*_playlistItem;
	
	NSProgressIndicator					*_progressIndicator;
	
	NSTask								*_exportTask;
	NSTask								*_metadataTask;
	NSTask								*_xattrTask;
	
	BOOL								_started;
	NSTimeInterval						_startTime;
	BOOL								_stopping;
	NSString							*_status;
	double								_loadTracksPercent;
	double								_exportPercent;
}

+ (id)exportJobWithPath:(NSString *)path file:(NSString *)file format:(NSDictionary *)format;

- (void)setDelegate:(id <SPExportJobDelegate>)delegate;
- (id <SPExportJobDelegate>)delegate;
- (void)setPlaylistItem:(SPPlaylistExportItem *)playlistItem;
- (SPPlaylistExportItem *)playlistItem;
- (void)setAudioPattern:(NSString *)audioPattern;
- (NSString *)audioPattern;
- (void)setSubtitlePattern:(NSString *)subtitlePattern;
- (NSString *)subtitlePattern;
- (void)setMetadata:(NSDictionary *)metadata;
- (NSDictionary *)metadata;
- (NSString *)name;
- (NSString *)status;
- (NSProgressIndicator *)progressIndicator;

- (void)start;
- (void)stop;

@end


@protocol SPExportJobDelegate <NSObject>

@optional

- (void)exportJobProgressed:(SPExportJob *)job;
- (void)exportJobCompleted:(SPExportJob *)job;
- (void)exportJobStopped:(SPExportJob *)job;
- (void)exportJob:(SPExportJob *)job failedWithError:(NSError *)error;

@end
