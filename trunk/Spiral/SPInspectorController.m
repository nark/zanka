/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "SPDrillController.h"
#import "SPFilenameMetadataGatherer.h"
#import "SPIMDbMetadataGatherer.h"
#import "SPInspectorController.h"
#import "SPMovieController.h"
#import "SPPlayerController.h"
#import "SPPlaylistItem.h"
#import "SPPlaylistController.h"

@interface SPInspectorController(Private)

- (void)_reloadForWindow:(NSWindow *)window;
- (void)_reloadForMovieController:(SPMovieController *)controller;
- (void)_reloadForPlaylistController:(SPPlaylistController *)controller;
- (void)_reloadForPlaylistFile:(SPPlaylistFile *)file;
- (void)_refreshInteractiveAttributesForController:(SPMovieController *)controller;
- (void)_refreshLoadProgressForController:(SPMovieController *)controller;

- (void)_setValue:(NSString *)value forKey:(NSString *)key;
- (void)_relayoutFields;
- (NSTextField *)_textFieldLikeTextField:(NSTextField *)archetypeTextField withStringValue:(NSString *)string;

@end


@implementation SPInspectorController(Private)

- (void)_reloadForWindow:(NSWindow *)window {
	[_sortedKeys removeAllObjects];
	[_allValues removeAllObjects];
	[_metadata removeAllObjects];
	
	[_posterImage release];
	_posterImage = NULL;
	
	if([[window delegate] isKindOfClass:[SPPlayerController class]] ||
	   [[window delegate] isKindOfClass:[SPDrillController class]])
		[self _reloadForMovieController:[[window delegate] movieController]];
	else if([[window delegate] isKindOfClass:[SPPlaylistController class]])
		[self _reloadForPlaylistController:[window delegate]];

	[self _relayoutFields];
}



- (void)_reloadForMovieController:(SPMovieController *)controller {
	NSMutableString		*format, *media;
	NSString			*string;
	QTMovie				*movie;
	QTTrack				*track;
	long long			size;
	
	movie = [controller movie];
	
	if(!movie)
		return;
	
	[self _reloadForPlaylistFile:[controller playlistFile]];

	[self _setValue:[[WIURL URLWithURL:[movie attributeForKey:QTMovieURLAttribute]] humanReadableString]
			 forKey:NSLS(@"Source", @"Inspector label")];
	
	format		= [NSMutableString string];
	media		= [NSMutableString string];
	
	for(track in [movie tracks]) {
		if([track isEnabled]) {
			string = [track attributeForKey:QTTrackFormatSummaryAttribute];
			
			if(string) {
				if([format length] > 0)
					[format appendString:@"\n"];
				
				[format appendString:string];
			}

			string = [track attributeForKey:QTTrackMediaTypeAttribute];
			
			if(string) {
				if([media length] > 0)
					[media appendString:@"\n"];
				
				[media appendString:string];
			}
		}
	}
	
	if([format length] > 0)
		[self _setValue:format forKey:NSLS(@"Format", @"Inspector label")];
	else
		[self _setValue:media forKey:NSLS(@"Format", @"Inspector label")];

	if([controller fps] > 0.1)
		[self _setValue:[NSSWF:@"%.2f", [controller fps]] forKey:NSLS(@"FPS", @"Inspector label")];
	
	size = [[movie attributeForKey:QTMovieDataSizeAttribute] longLongValue];
   
	[self _setValue:[NSString humanReadableStringForSizeInBytes:size]
			 forKey:NSLS(@"Data Size", @"Inspector label")];
	
	[self _setValue:[NSSWF:NSLS(@"%@/s", @"Inspector data rate"),
				[NSString humanReadableStringForSizeInBits:[controller duration] > 0.0 ? (size * 8) / [controller duration] : 0]]
			 forKey:NSLS(@"Data Rate", @"Inspector label")];
	
	[self _setValue:[SPMovieController longStringForTimeInterval:[controller currentTime]]
			 forKey:NSLS(@"Current Time", @"Inspector label")];
	
	[self _setValue:[SPMovieController longStringForTimeInterval:[controller duration]]
			 forKey:NSLS(@"Duration", @"Inspector label")];
	
	if([controller naturalSize].width > 0.0) {
		[self _setValue:[SPMovieController longStringForSize:[controller naturalSize]]
				 forKey:NSLS(@"Normal Size", @"Inspector label")];
		
		string = [SPMovieController longStringForSize:[controller currentSize]];
		
		if([controller scaling] != SPCurrentSize) {
			string = [string stringByAppendingFormat:@" (%@)",
				[[SPMovieController scalingNames] objectAtIndex:[controller scaling]]];
		}
			
		[self _setValue:string forKey:NSLS(@"Current Size", @"Inspector label")];
		
		string = [[SPMovieController aspectRatioNames] objectAtIndex:[controller aspectRatio]];
		
		if([controller aspectRatio] == SPActualAspectRatio) {
			string = [NSSWF:NSLS(@"%@ (%@)", @"Inspector aspect ratio"),
				string,
				[SPMovieController stringForAspectRatioOfSize:[controller currentSize]]];
		}
		
		[self _setValue:string forKey:NSLS(@"Aspect Ratio", @"Inspector label")];
	}
}



- (void)_reloadForPlaylistController:(SPPlaylistController *)controller {
	SPPlaylistFile		*file;
	
	file = [controller selectedFile];
	
	if(!file)
		return;
	
	[self _reloadForPlaylistFile:file];

	[self _setValue:[file path]
			 forKey:NSLS(@"Source", @"Inspector label")];

	[self _setValue:[NSString humanReadableStringForSizeInBytes:[file size]]
			 forKey:NSLS(@"Data Size", @"Inspector label")];

	[self _setValue:[NSSWF:NSLS(@"%@/s", @"Inspector data rate"),
				[NSString humanReadableStringForSizeInBits:[file duration] > 0.0 ? ([file size] * 8) / [file duration] : 0]]
			 forKey:NSLS(@"Data Rate", @"Inspector label")];

	[self _setValue:[SPMovieController longStringForTimeInterval:[file duration]]
			 forKey:NSLS(@"Duration", @"Inspector label")];

	if([file dimensions].width > 0.0) {
		[self _setValue:[SPMovieController longStringForSize:[file dimensions]]
				 forKey:NSLS(@"Normal Size", @"Inspector label")];
	}
}



- (void)_reloadForPlaylistFile:(SPPlaylistFile *)file {
	[_metadata setDictionary:[file metadata]];
	
	_posterImage = [[file posterImage] retain];
	
	if([[_metadata objectForKey:SPIMDbMetadataDirectorsKey] count] == 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataDirectorsKey] objectAtIndex:0]
				 forKey:NSLS(@"Director", @"Inspector label")];
	}
	else if([[_metadata objectForKey:SPIMDbMetadataDirectorsKey] count] > 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataDirectorsKey] componentsJoinedByString:@", "]
				 forKey:NSLS(@"Directors", @"Inspector label")];
	}

	if([[_metadata objectForKey:SPIMDbMetadataWritersKey] count] == 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataWritersKey] objectAtIndex:0]
				 forKey:NSLS(@"Writer", @"Inspector label")];
	}
	else if([[_metadata objectForKey:SPIMDbMetadataWritersKey] count] > 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataWritersKey] componentsJoinedByString:@", "]
				 forKey:NSLS(@"Writers", @"Inspector label")];
	}

	if([[_metadata objectForKey:SPIMDbMetadataCastKey] count] > 0) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataCastKey] componentsJoinedByString:@", "]
				 forKey:NSLS(@"Cast", @"Inspector label")];
	}

	if([[_metadata objectForKey:SPIMDbMetadataCountriesKey] count] == 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataCountriesKey] objectAtIndex:0]
				 forKey:NSLS(@"Country", @"Inspector label")];
	}
	else if([[_metadata objectForKey:SPIMDbMetadataCountriesKey] count] > 1) {
		[self _setValue:[[_metadata objectForKey:SPIMDbMetadataCountriesKey] componentsJoinedByString:@", "]
				 forKey:NSLS(@"Countries", @"Inspector label")];
	}

	if([_metadata objectForKey:SPIMDbTVMetadataEpisodeAirDateKey]) {
		[self _setValue:[_dateFormatter stringFromDate:[_metadata objectForKey:SPIMDbTVMetadataEpisodeAirDateKey]]
				 forKey:NSLS(@"Air Date", @"Inspector label")];
	}
	else if([_metadata objectForKey:SPIMDbMetadataReleaseDateKey]) {
		[self _setValue:[_dateFormatter stringFromDate:[_metadata objectForKey:SPIMDbMetadataReleaseDateKey]]
				 forKey:NSLS(@"Release Date", @"Inspector label")];
	}

	if([_metadata objectForKey:SPIMDbMetadataRatingKey]) {
		[self _setValue:[_ratingFormatter stringFromNumber:[_metadata objectForKey:SPIMDbMetadataRatingKey]]
				 forKey:NSLS(@"Rating", @"Inspector label")];
	}
}



- (void)_refreshInteractiveAttributesForController:(SPMovieController *)controller {
	[[_textFields objectForKey:NSLS(@"Current Time", @"Inspector label")]
		setStringValue:[SPMovieController longStringForTimeInterval:[controller currentTime]]];
}



- (void)_refreshLoadProgressForController:(SPMovieController *)controller {
	QTMovie			*movie;
	long long		size;
	
	movie = [controller movie];
	size = [[movie attributeForKey:QTMovieDataSizeAttribute] longLongValue];
	
	[[_textFields objectForKey:NSLS(@"Data Size", @"Inspector label")]
		setStringValue:[NSString humanReadableStringForSizeInBytes:size]];
	
	[[_textFields objectForKey:NSLS(@"Data Rate", @"Inspector label")]
		setStringValue:[NSSWF:NSLS(@"%@/s", @"Inspector data rate"),
			[NSString humanReadableStringForSizeInBits:[controller duration] > 0.0 ? (size * 8) / [controller duration] : 0]]];
}



#pragma mark -

- (void)_setValue:(NSString *)value forKey:(NSString *)key {
	if(key && value) {
		[_sortedKeys addObject:key];
		[_allValues setObject:value forKey:key];
	}
}



- (void)_relayoutFields {
	NSTextField		*nameTextField, *valueTextField;
	NSView			*contentView;
	NSString		*key, *value;
	NSRect			frame, windowFrame;
	NSSize			nameSize, valueSize;
	CGFloat			verticalOffset, height;
	
	verticalOffset = ([_sortedKeys count] > 0) ? 20.0 : 50.0;
	contentView = [[self window] contentView];
	
	[[contentView subviewsWithTag:0] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	for(key in [_sortedKeys reversedArray]) {
		value			= [_allValues objectForKey:key];
		
		nameTextField	= [self _textFieldLikeTextField:_nameTextField withStringValue:[key stringByAppendingString:@":"]];
		valueTextField	= [self _textFieldLikeTextField:_valueTextField withStringValue:value];
		
		nameSize		= [[nameTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [nameTextField frame].size.width, 10000.0)];
		valueSize		= [[valueTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [valueTextField frame].size.width, 10000.0)];
		height			= WIMax(nameSize.height, valueSize.height);
		
		[nameTextField setFrame:NSMakeRect([nameTextField frame].origin.x, verticalOffset, [nameTextField frame].size.width, height)];
		[valueTextField setFrame:NSMakeRect([valueTextField frame].origin.x, verticalOffset, valueSize.width, height)];
		
		[contentView addSubview:nameTextField];
		[contentView addSubview:valueTextField];
		
		[_textFields setObject:valueTextField forKey:key];
		
		verticalOffset += height + 6.0;
	}
	
	verticalOffset += 6.0;

	[_posterImageView setImage:_posterImage];
	
	if(_posterImage) {
		frame			= [_posterImageView frame];
		
		[_posterImageView setFrame:NSMakeRect(frame.origin.x, verticalOffset, frame.size.width, frame.size.height)];
		
		verticalOffset	+= frame.size.height + 10.0;
	}
	
	value = [_metadata objectForKey:SPIMDbTVMetadataEpisodeTitleKey];

	[_episodeTitleTextField setHidden:([value length] == 0)];
	
	if([value length] > 0) {
		value		= [NSSWF:NSLS(@"Season %@, episode %@: \u201c%@\u201d", @"Inspector label"),
			[_metadata objectForKey:SPFilenameMetadataTVShowSeasonKey],
			[_metadata objectForKey:SPFilenameMetadataTVShowEpisodeKey],
			value];

		[_episodeTitleTextField setStringValue:value];
		
		frame			= [_episodeTitleTextField frame];
		valueSize		= [[_episodeTitleTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [_titleTextField frame].size.width, 10000.0)];
		
		[_episodeTitleTextField setFrame:NSMakeRect(frame.origin.x, verticalOffset, frame.size.width, valueSize.height)];
		
		verticalOffset	+= valueSize.height + 6.0;
	}
	
	value = [_metadata objectForKey:SPIMDbMetadataTitleKey];

	[_titleTextField setHidden:([value length] == 0)];
	
	if([value length] > 0) {
		[_titleTextField setStringValue:value];
		
		frame			= [_titleTextField frame];
		valueSize		= [[_titleTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [_titleTextField frame].size.width, 10000.0)];

		[_titleTextField setFrame:NSMakeRect(frame.origin.x, verticalOffset, frame.size.width, valueSize.height)];
		
		verticalOffset	+= valueSize.height + 6.0;
	}
	
	[_noMovieTextField setHidden:([_sortedKeys count] > 0)];
	
	windowFrame = [[self window] frame];
	height = windowFrame.size.height;
	windowFrame.size.height = verticalOffset + 26.0;
	windowFrame.origin.y -= windowFrame.size.height - height;
	[[self window] setFrame:windowFrame display:YES animate:NO];
}



- (NSTextField *)_textFieldLikeTextField:(NSTextField *)archetypeTextField withStringValue:(NSString *)string {
	NSTextField		*textField;
	
	textField = [[NSTextField alloc] initWithFrame:[archetypeTextField frame]];
	[textField setEditable:[archetypeTextField isEditable]];
	[textField setSelectable:[archetypeTextField isSelectable]];
	[textField setBordered:[archetypeTextField isBordered]];
	[textField setBezelStyle:[archetypeTextField bezelStyle]];
	[textField setFont:[archetypeTextField font]];
	[textField setAlignment:[archetypeTextField alignment]];
	[textField setTextColor:[archetypeTextField textColor]];
	[textField setDrawsBackground:[archetypeTextField drawsBackground]];
	[textField setBackgroundColor:[archetypeTextField backgroundColor]];
	[textField setStringValue:string];
	
	return [textField autorelease];
}

@end



@implementation SPInspectorController

+ (SPInspectorController *)inspectorController {
	static SPInspectorController		*inspectorController;
	
	if(!inspectorController)
		inspectorController = [[[self class] alloc] init];
	
	return inspectorController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Inspector"];
	
	_sortedKeys			= [[NSMutableArray alloc] init];
	_allValues			= [[NSMutableDictionary alloc] init];
	_textFields			= [[NSMutableDictionary alloc] init];
	_metadata			= [[NSMutableDictionary alloc] init];
	
	_dateFormatter		= [[WIDateFormatter alloc] init];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	
	_ratingFormatter	= [[NSNumberFormatter alloc] init];
	[_ratingFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(windowDidBecomeKey:)
			   name:NSWindowDidBecomeKeyNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerOpenedMovie:)
			   name:SPMovieControllerOpenedMovieNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerClosedMovie:)
			   name:SPMovieControllerClosedMovieNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerSizeOrAttributesChanged:)
			   name:SPMovieControllerSizeChangedNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerSizeOrAttributesChanged:)
			   name:SPMovieControllerAttributesChangedNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerInteractiveAttributesChanged:)
			   name:SPMovieControllerInteractiveAttributesChangedNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(movieControllerLoadProgressChanged:)
			   name:SPMovieControllerLoadProgressChangedNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(playlistControllerSelectionDidChange:)
			   name:SPPlaylistControllerSelectionDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(playlistControllerLoadProgressChanged:)
			   name:SPPlaylistControllerLoadProgressChangedNotification];
	
	[(NSPanel *) [self window] setBecomesKeyOnlyIfNeeded:YES];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_nameTextField release];
	[_valueTextField release];

	[_sortedKeys release];
	[_allValues release];
	[_textFields release];
	
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setLevel:NSStatusWindowLevel + 1];

	[self setShouldSaveWindowFrameOriginOnly:YES];
	[self setWindowFrameAutosaveName:@"Inspector"];

	[[_nameTextField retain] removeFromSuperview];
	[[_valueTextField retain] removeFromSuperview];
}



#pragma mark -

- (void)windowDidBecomeKey:(NSNotification *)notification {
	if([[self window] isVisible])
		[self _reloadForWindow:[notification object]];
}



- (void)movieControllerOpenedMovie:(NSNotification *)notification {
	if([[self window] isVisible])
		[self _reloadForWindow:[[[notification object] playerController] window]];
}



- (void)movieControllerClosedMovie:(NSNotification *)notification {
	if([[self window] isVisible])
		[self _reloadForWindow:[NSApp keyWindow]];
}



- (void)movieControllerSizeOrAttributesChanged:(NSNotification *)notification {
	NSWindow		*window;
	
	if([[self window] isVisible]) {
		window = [[[notification object] playerController] window];
		
		if(window == [NSApp keyWindow])
			[self _reloadForWindow:window];
	}
}



- (void)movieControllerInteractiveAttributesChanged:(NSNotification *)notification {
	NSWindow		*window;
	
	if([[self window] isVisible]) {
		window = [[[notification object] playerController] window];
		
		if(window == [NSApp keyWindow])
			[self _refreshInteractiveAttributesForController:[notification object]];
	}
}



- (void)movieControllerLoadProgressChanged:(NSNotification *)notification {
	NSWindow		*window;
	
	if([[self window] isVisible]) {
		window = [[[notification object] playerController] window];
		
		if(window == [NSApp keyWindow])
			[self _refreshLoadProgressForController:[notification object]];
	}
}



- (void)playlistControllerSelectionDidChange:(NSNotification *)notification {
	NSWindow		*window;
	
	if([[self window] isVisible]) {
		window = [[notification object] window];
		
		if(window == [NSApp keyWindow])
			[self _reloadForWindow:window];
	}
}



- (void)playlistControllerLoadProgressChanged:(NSNotification *)notification {
	NSWindow		*window;
	
	if([[self window] isVisible]) {
		window = [[notification object] window];

		if(window == [NSApp keyWindow])
			[self _reloadForWindow:window];
	}
}



#pragma mark -

- (void)showWindow:(id)sender {
	[self _reloadForWindow:[NSApp keyWindow]];
	
	[super showWindow:sender];
}

@end
