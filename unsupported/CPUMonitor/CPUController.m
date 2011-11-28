/* $Id$ */

/*
 *  Copyright (c) 2005-2009 Axel Andersson
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

#import "CPUController.h"
#import "CPUDataSource.h"
#import "CPUExpandedView.h"
#import "CPUFloatingView.h"
#import "CPUPanel.h"
#import "CPUSettings.h"

#define CPUStandardViewWidth			30.0


@implementation CPUController

- (void)awakeFromNib {
	NSImageView		*imageView;
	NSMutableArray  *imageViews;
	NSTimer			*timer;
	NSRect			frame, rect;
	NSPoint			point;
	CGFloat			alpha;
	NSUInteger		i, tag, numberOfCPUs;
	
	[_floatingViewColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUFloatingViewColor]]];
	
	alpha = [CPUSettings floatForKey:CPUFloatingViewAlpha];
	
	if(alpha > 0.75)
		[_floatingViewAlphaMatrix selectCellWithTag:0];
	else if(alpha <= 0.50)
		[_floatingViewAlphaMatrix selectCellWithTag:2];
	else
		[_floatingViewAlphaMatrix selectCellWithTag:1];
	
	[_floatingViewOrientationMatrix selectCellWithTag:[CPUSettings intForKey:CPUFloatingViewOrientation]];
	
	[_expandedViewSystemColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewSystemColor]]];
	[_expandedViewUserColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewUserColor]]];
	[_expandedViewNiceColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewNiceColor]]];
	[_expandedViewBackgroundColorWell setColor:[NSUnarchiver unarchiveObjectWithData:[CPUSettings objectForKey:CPUExpandedViewBackgroundColor]]];
	
	tag = [CPUSettings intForKey:CPUApplicationIconDisplay];
	[_applicationIconMatrix selectCellWithTag:tag];
	
	switch(tag) {
		case CPUApplicationIconStandardView:
			_applicationIconStatus = CPUApplicationIconStandard;
			break;
			
		case CPUApplicationIconExpandedView:
			_applicationIconStatus = CPUApplicationIconExpanded;
			break;
	}

	[_standardPanel setFrameAutosaveName:@"StandardWindow"];
	[_standardPanel setFloatingPanel:YES];
	[_standardPanel setHidesOnDeactivate:NO];
	
	numberOfCPUs = [CPUDataSource dataSource]->_numberOfCPUs;
	
	if(numberOfCPUs > 1) {
		frame = [_standardPanel frame];
		frame.size.width = (numberOfCPUs * CPUStandardViewWidth) + 17.0;
		[_standardPanel setFrame:frame display:NO];
		rect = [_standardPanel contentRectForFrameRect:frame];
		point = [_standardPanel convertScreenToBase:rect.origin];
		
		frame = [_standardBackgroundImageView frame];
		frame.origin.x = 3.0;
		[_standardBackgroundImageView setFrame:frame];
		[_standardImageView setFrame:frame];
		
		imageViews = [[NSMutableArray alloc] initWithCapacity:numberOfCPUs];
		[imageViews addObject:_standardImageView];
		
		for(i = 1; i < numberOfCPUs; i++) {
			frame.origin.x += CPUStandardViewWidth;
			
			imageView = [[NSImageView alloc] initWithFrame:frame];
			[imageView setImage:[NSImage imageNamed:@"StandardViewBackground.tiff"]];
			[_standardBox addSubview:imageView];
			[imageView release];
			
			imageView = [[NSImageView alloc] initWithFrame:frame];
			[imageView setImage:[NSImage imageNamed:@"StandardView07.tiff"]];
			[_standardBox addSubview:imageView];
			[imageViews addObject:imageView];
			[imageView release];
		}
		
		_imageViews = [[NSArray alloc] initWithArray:imageViews];
		[imageViews release];
	} else {
		_imageViews = [[NSArray alloc] initWithObjects:_standardImageView, NULL];
	}
	
	[_expandedPanel setFrameAutosaveName:@"ExpandedWindow"];
	[_expandedPanel setFloatingPanel:YES];
	[_expandedPanel setHidesOnDeactivate:NO];
	
	_applicationIcon = [[NSApp applicationIconImage] copy];
	
	timer = [NSTimer scheduledTimerWithTimeInterval:[CPUSettings doubleForKey:CPUUpdateInterval]
											 target:self
										   selector:@selector(timer:)
										   userInfo:NULL
											repeats:YES];
	
	if([CPUSettings boolForKey:CPUStandardViewShown])
		[_standardPanel makeKeyAndOrderFront:self];
	
	if([CPUSettings boolForKey:CPUFloatingViewShown])
		[self toggleFloatingWindow:self];
	
	if([CPUSettings boolForKey:CPUExpandedViewShown])
		[_expandedPanel makeKeyAndOrderFront:self];
}



- (void)dealloc {
	[_floatingPanel release];
	[_imageViews release];
	[_applicationIcon release];
	
	[super dealloc];
}



#pragma mark -

- (void)applicationWillTerminate:(NSNotification *)notification {
	[CPUSettings setBool:[_standardPanel isVisible] forKey:CPUStandardViewShown];
	[CPUSettings setBool:[_floatingPanel isVisible] forKey:CPUFloatingViewShown];
	[CPUSettings setBool:[_expandedPanel isVisible] forKey:CPUExpandedViewShown];
}



#pragma mark -

- (void)timer:(NSTimer *)timer {
	NSString			*imageName;
	NSImage				*image;
	NSBitmapImageRep	*imageRep;
	CPUDataSource		*dataSource;
	CPUData				*data;
	NSRect				frame;
	CGFloat				width;
	NSUInteger			i, numberOfCPUs, usage;
	
	if([_floatingPanel isVisible])
		[_floatingView setNeedsDisplay:YES];
	
	if([_expandedPanel isVisible])
		[_expandedView refresh];
	
	if([_standardPanel isVisible] || _applicationIconStatus == CPUApplicationIconStandard) {
		dataSource = [CPUDataSource dataSource];
		numberOfCPUs = dataSource->_numberOfCPUs;
		
		for(i = 0; i < numberOfCPUs; i++) {
			data = dataSource->_data[i];
			usage = (data->_user + data->_system + data->_nice) * 19;
			
			switch(usage) {
				default:
				case  0: imageName = @"StandardView00.tiff"; break;
				case  1: imageName = @"StandardView01.tiff"; break;
				case  2: imageName = @"StandardView02.tiff"; break;
				case  3: imageName = @"StandardView03.tiff"; break;
				case  4: imageName = @"StandardView04.tiff"; break;
				case  5: imageName = @"StandardView05.tiff"; break;
				case  6: imageName = @"StandardView06.tiff"; break;
				case  7: imageName = @"StandardView07.tiff"; break;
				case  8: imageName = @"StandardView08.tiff"; break;
				case  9: imageName = @"StandardView09.tiff"; break;
				case 10: imageName = @"StandardView10.tiff"; break;
				case 11: imageName = @"StandardView11.tiff"; break;
				case 12: imageName = @"StandardView12.tiff"; break;
				case 13: imageName = @"StandardView13.tiff"; break;
				case 14: imageName = @"StandardView14.tiff"; break;
				case 15: imageName = @"StandardView15.tiff"; break;
				case 16: imageName = @"StandardView16.tiff"; break;
				case 17: imageName = @"StandardView17.tiff"; break;
				case 18: imageName = @"StandardView18.tiff"; break;
			}
			
			[[_imageViews objectAtIndex:i] setImage:[NSImage imageNamed:imageName]];
		}
	}
	
	switch(_applicationIconStatus) {
		case CPUApplicationIconStandard:
			[_standardBox lockFocus];
			frame = [_standardBox frame];
			width = frame.size.width > 128.0 ? 128.0 : frame.size.width;
			imageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:frame];
			[_standardBox unlockFocus];
			
			image = [[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)];
			[image lockFocus];
			[imageRep drawInRect:NSMakeRect(64.0 - (width / 2.0), 0.0, width, 128.0)];
			[image unlockFocus];
			[NSApp setApplicationIconImage:image];
			[image release];
			[imageRep release];
			break;
			
		case CPUApplicationIconExpanded:
			image = [[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)];
			[image lockFocus];
			[_expandedView drawIconInRect:NSMakeRect(0.0, 0.0, 128.0, 128.0)];
			[image unlockFocus];
			[NSApp setApplicationIconImage:image];
			[image release];
			break;
			
		case CPUApplicationIconResetDefault:
			[NSApp setApplicationIconImage:_applicationIcon];
			_applicationIconStatus = CPUApplicationIconDefault;
			break;
		
		case CPUApplicationIconDefault:
			break;
	}
}



#pragma mark -

- (IBAction)toggleFloatingWindow:(id)sender {
	NSRect		frame, rect;
	BOOL		horizontal;
	
	if(!_floatingPanel) {
		rect = [[NSScreen mainScreen] frame];
		frame = NSMakeRect(rect.origin.x + 200.0, rect.origin.y + rect.size.height - 5.0, 10.0, 10.0);
		horizontal = ([CPUSettings intForKey:CPUFloatingViewOrientation] == CPUFloatingViewHorizontal);
		
		_floatingView = [[CPUFloatingView alloc] initWithFrame:frame isHorizontal:horizontal];
		_floatingPanel = [[CPUPanel alloc] initWithContentRect:[_floatingView frame]
													styleMask:NSBorderlessWindowMask
													  backing:NSBackingStoreBuffered
														defer:YES];
		[_floatingPanel setFrameAutosaveName:@"FloatingWindow"];
		[_floatingPanel setMovableByWindowBackground:YES];
		[_floatingPanel setHidesOnDeactivate:NO];
		[_floatingPanel setHasShadow:NO];
		[_floatingPanel setOpaque:NO];
		[_floatingPanel setAlphaValue:[CPUSettings doubleForKey:CPUFloatingViewAlpha]];
		[_floatingPanel setFloatingPanel:YES];
		[_floatingPanel setLevel:NSMainMenuWindowLevel + 1];
		[_floatingPanel setBackgroundColor:[NSColor clearColor]];
		[_floatingPanel setContentView:_floatingView];
		[_floatingView release];
	}
	
	if([_floatingPanel isVisible])
		[_floatingPanel close];
	else
		[_floatingPanel makeKeyAndOrderFront:self];
}



- (IBAction)clearExpandedWindow:(id)sender {
	[[CPUDataSource dataSource] clearHistory];
	[_expandedView invalidate];
	[_expandedView setNeedsDisplay:YES];
}



- (IBAction)openActivityMonitor:(id)sender {
	[[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor"];
}



- (IBAction)openTop:(id)sender {
	[[NSWorkspace sharedWorkspace] openFile:@"/usr/bin/top"];
}



- (IBAction)changeFloatingView:(id)sender {
	CGFloat		alpha;
	
	[CPUSettings setObject:[NSArchiver archivedDataWithRootObject:[_floatingViewColorWell color]] forKey:CPUFloatingViewColor];
	
	switch([_floatingViewAlphaMatrix selectedTag]) {
		case 0:
		default:
			alpha = 1.0;
			break;
			
		case 1:
			alpha = 0.75;
			break;
			
		case 2:
			alpha = 0.50;
			break;
	}
	
	[CPUSettings setFloat:alpha forKey:CPUFloatingViewAlpha];
	[CPUSettings setInt:[_floatingViewOrientationMatrix selectedTag] forKey:CPUFloatingViewOrientation];
	
	[_floatingView setIsHorizontal:([CPUSettings intForKey:CPUFloatingViewOrientation] == CPUFloatingViewHorizontal)];
	[_floatingPanel setContentSize:[_floatingView frame].size];
	[_floatingPanel setAlphaValue:alpha];
}



- (IBAction)changeExpandedView:(id)sender {
	[CPUSettings setObject:[NSArchiver archivedDataWithRootObject:[_expandedViewSystemColorWell color]] forKey:CPUExpandedViewSystemColor];
	[CPUSettings setObject:[NSArchiver archivedDataWithRootObject:[_expandedViewUserColorWell color]] forKey:CPUExpandedViewUserColor];
	[CPUSettings setObject:[NSArchiver archivedDataWithRootObject:[_expandedViewNiceColorWell color]] forKey:CPUExpandedViewNiceColor];
	[CPUSettings setObject:[NSArchiver archivedDataWithRootObject:[_expandedViewBackgroundColorWell color]] forKey:CPUExpandedViewBackgroundColor];
	
	[_expandedView invalidate];
	[_expandedView setNeedsDisplay:YES];
}



- (IBAction)changeApplicationIcon:(id)sender {
	NSUInteger		tag;
	
	tag = [_applicationIconMatrix selectedTag];
	
	switch(tag) {
		case CPUApplicationIconStandardView:
			_applicationIconStatus = CPUApplicationIconStandard;
			break;
			
		case CPUApplicationIconExpandedView:
			_applicationIconStatus = CPUApplicationIconExpanded;
			break;
			
		case CPUApplicationIconNone:
			if(_applicationIconStatus != CPUApplicationIconDefault)
				_applicationIconStatus = CPUApplicationIconResetDefault;
			break;
	}
	
	[CPUSettings setInt:tag forKey:CPUApplicationIconDisplay];
}



- (IBAction)releaseNotes:(id)sender {
	NSString		*path;
	
	path = [[self bundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
	
	[[WIReleaseNotesController releaseNotesController]
		setReleaseNotesWithRTF:[NSData dataWithContentsOfFile:path]];
	[[WIReleaseNotesController releaseNotesController] showWindow:self];
}

@end
