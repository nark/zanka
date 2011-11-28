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

#import "FHFile.h"
#import "FHSlideshowController.h"
#import "FHSlideshowWindow.h"
#import "FHImageLoader.h"
#import "FHImageView.h"
#import "FHHandler.h"
#import "FHSettings.h"

@implementation FHSlideshowController

- (id)initWithImageLoader:(FHImageLoader *)imageLoader index:(NSUInteger)index images:(NSUInteger)images {
	self = [super initWithWindowNibName:@"Slideshow"];
	
	_index = index;
	_images = images;
	
	[self setImageLoader:imageLoader];

	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderReceivedImageData:)
			   name:FHImageLoaderReceivedImageData];

	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderDidLoadImage:)
			   name:FHImageLoaderDidLoadImage];
	
	[self updateSpreads];

	[self retain];
	[self window];
	
	return self;
}



- (void)dealloc {
	[_slideshowWindow release];
	[_timer release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSScreen			*screen;
	NSColor				*color;
	FHFile				*file;
	NSRect				frame;
	NSUInteger			index;
	
	index = [FHSettings intForKey:FHFullscreenScreen];
		
	if(index >= [[NSScreen screens] count])
		index = 0;
		
	screen = [[NSScreen screens] objectAtIndex:index];
	
	frame = [screen frame];
	frame.origin.x = frame.origin.y = 0.0;

	_slideshowWindow = [[FHSlideshowWindow alloc]
		initWithContentRect:frame
				  styleMask:NSBorderlessWindowMask
					backing:NSBackingStoreBuffered
					  defer:YES
					 screen:screen];

#ifndef FHConfigurationDebug
	[_slideshowWindow setLevel:NSScreenSaverWindowLevel];
#endif
	
	[_slideshowWindow setDelegate:self];
	[_slideshowWindow setReleasedWhenClosed:NO];
	[_slideshowWindow setTitle:[[self window] title]];
	[[_slideshowWindow contentView] addSubview:_imageView];
	[[_slideshowWindow contentView] addSubview:_labelTextField];
	
	switch([FHSettings intForKey:FHFullscreenBackground]) {
		default:
		case FHFullscreenBackgroundBlack:	color = [NSColor blackColor];	break;
		case FHFullscreenBackgroundGray:	color = [NSColor grayColor];	break;
		case FHFullscreenBackgroundWhite:	color = [NSColor whiteColor];	break;
	}
	
	if([color whiteComponent] < 0.5)
		[_labelTextField setTextColor:[NSColor whiteColor]];
	else
		[_labelTextField setTextColor:[NSColor blackColor]];
	
	[_slideshowWindow setBackgroundColor:color];
	[_imageView setBackgroundColor:color];
	[_imageView setImageScaling:[FHSettings intForKey:FHImageScalingMethod]];
	
	file = [self selectedFile];
	
	[self showFile:[self selectedFile]];
	[self startLoadingImageForFile:file atIndex:[self selectedIndex]];
	
	if([FHSettings boolForKey:FHFullscreenAutoSwitch]) {
		_timer = [[NSTimer scheduledTimerWithTimeInterval:[FHSettings intForKey:FHFullscreenAutoSwitchTime]
												   target:self
												 selector:@selector(switchTimer:)
												 userInfo:NULL
												  repeats:YES] retain];
		NSLog(@"created %@ with interval %d", _timer, [FHSettings intForKey:FHFullscreenAutoSwitchTime]);
	}
}



- (void)windowWillClose:(NSNotification *)notification {
	if([notification object] == _slideshowWindow) {
		[_timer invalidate];
	
		[self autorelease];
	}
}



#pragma mark -

- (void)showSlideshowWindow:(id)sender {
	[_slideshowWindow makeKeyAndOrderFront:sender];
}



#pragma mark -

- (NSArray *)files {
	return [_imageLoader files];
}



- (NSUInteger)selectedIndex {
	return _index;
}



- (void)selectFileAtIndex:(NSUInteger)index {
	FHFile		*file;

	_index = index;
	
	[_timer setFireDate:[NSDate distantFuture]];

	file = [self selectedFile];

	[self showFile:file];
	[self startLoadingImageForFile:file atIndex:_index];
}



- (void)showFile:(FHFile *)file {
	[super showFile:file];
	
	[_timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:
		[FHSettings intForKey:FHFullscreenAutoSwitchTime]]];
}



- (void)updateFileStatus {
	NSArray			*files;
	FHFile			*file;
	NSUInteger		i, count, index;
	
	file = [self selectedFile];
	files = [self files];
	count = [files count];

	for(i = index = 0; i < count; i++) {
		if(![[files objectAtIndex:i] isDirectory])
			index++;
		
		if([files objectAtIndex:i] == file)
			break;
	}
	
	[_labelTextField setStringValue:[NSSWF:NSLS(@"%@ \u2014 %u/%u", @"'image.jpg - 1/10'"),
		[file name],
		index,
		_images]];
}



#pragma mark -

- (void)switchTimer:(NSTimer *)timer {
	[self nextImage:self];
}



#pragma mark -

- (void)slideshow:(id)sender {
	[_slideshowWindow close];
}

@end
