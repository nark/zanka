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
#import "FHImage.h"
#import "FHImageLoader.h"
#import "FHImageView.h"
#import "FHSettings.h"
#import "FHSpread.h"
#import "FHWindowController.h"

@implementation FHWindowController

- (id)initWithWindowNibName:(NSString *)nibName {
	self = [super initWithWindowNibName:nibName];
	
	_spreads = [[NSMutableDictionary alloc] init];
	
	return self;
}



- (void)dealloc {
	[[_imageLoader notificationCenter] removeObserver:self];
	
	[_spreads release];

	[super dealloc];
}



#pragma mark -

- (void)imageLoaderReceivedImageData:(NSNotification *)notification {
	FHFile		*file;
	
	file = [notification object];
	
	if(file == [self selectedFile]) {
		[_progressIndicator setIndeterminate:NO];
		[_progressIndicator setDoubleValue:[file percentReceived]];
		[_progressIndicator animate:self];
	}
}



- (void)imageLoaderDidLoadImage:(NSNotification *)notification {
	FHFile		*file;
	
	file = [notification object];
	
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone) {
		if(file == [self selectedFile])
			[self showFile:file];
	} else {
		if([self spreadForFile:file] == [self selectedSpread])
			[self showFile:file];
	}
}



#pragma mark -

- (void)setImageLoader:(FHImageLoader *)imageLoader {
	[[_imageLoader notificationCenter] removeObserver:self];

	[imageLoader retain];
	[_imageLoader release];
	
	_imageLoader = imageLoader;
	
	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderReceivedImageData:)
			   name:FHImageLoaderReceivedImageData];

	[[_imageLoader notificationCenter]
		addObserver:self
		   selector:@selector(imageLoaderDidLoadImage:)
			   name:FHImageLoaderDidLoadImage];
}



- (FHImageLoader *)imageLoader {
	return _imageLoader;
}



#pragma mark -

- (NSArray *)files {
	return NULL;
}



- (FHFile *)fileAtIndex:(NSUInteger)index {
	return [[self files] objectAtIndex:index];
}



- (NSArray *)filesAtIndexes:(NSIndexSet *)indexes {
	return [[self files] objectsAtIndexes:indexes];
}



- (FHFile *)selectedFile {
	NSUInteger		index;
	
	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NULL;
	
	return [self fileAtIndex:index];
}



- (NSUInteger)selectedIndex {
	return NSNotFound;
}



- (void)selectFileAtIndex:(NSUInteger)index {
}



- (void)startLoadingImageForFile:(FHFile *)file atIndex:(NSUInteger)index {
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone || index == 0) {
		[_imageLoader startLoadingImageAtIndex:index];
	} else {
		if(file == [[self spreadForFile:file] rightFile])
			index--;

		[_imageLoader startLoadingImageAtIndex:index];
	}
}



- (void)showFile:(FHFile *)file {
	FHSpread	*spread;
	FHFile		*leftFile, *rightFile;
	FHImage		*image, *leftImage, *rightImage;
	double		percentReceived;
	BOOL		success;
	
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone) {
		if([file isLoaded]) {
			[_progressIndicator setHidden:YES];
			[_progressIndicator setDoubleValue:0.0];

			image = [file image];
			success = (image && [image size].width > 0.0);
			
			if(success)
				[_imageView setImage:image];
			else
				[_imageView setImage:[FHImage imageNamed:@"Error"]];
		} else {
			if(file && ![[file URL] isFileURL]) {
				percentReceived = [file percentReceived];

				[_progressIndicator setHidden:NO];
				[_progressIndicator setIndeterminate:!(percentReceived > 0.0)];
				[_progressIndicator setDoubleValue:percentReceived];
			} else {
				[_progressIndicator setHidden:YES];
				[_progressIndicator setDoubleValue:0.0];
			}

			[_imageView setImage:NULL];
		}
	} else {
		spread		= [self spreadForFile:file];
		leftFile	= [spread leftFile];
		leftImage	= [leftFile image];
		rightFile	= [spread rightFile];
		rightImage	= [rightFile image];
		
		if(leftImage || rightImage) {
			success = ([leftImage size].width > 0.0 || [rightImage size].width > 0.0);
			
			if(success) {
				if([FHSettings boolForKey:FHSpreadRightToLeft])
					[_imageView setLeftImage:rightImage rightImage:leftImage];
				else
					[_imageView setLeftImage:leftImage rightImage:rightImage];
			} else {
				[_imageView setImage:[FHImage imageNamed:@"Error"]];
			}
		} else {
			if(leftFile && rightFile && ![[leftFile URL] isFileURL] && ![[rightFile URL] isFileURL]) {
				percentReceived = ([leftFile percentReceived] + [rightFile percentReceived]) / 2.0;
				
				[_progressIndicator setHidden:NO];
				[_progressIndicator setIndeterminate:!(percentReceived > 0.0)];
				[_progressIndicator setDoubleValue:percentReceived];
			}
			
			[_imageView setImage:NULL];
		}
	}

	[self updateFileStatus];
}



- (void)updateFileStatus {
}



- (FHSpread *)spreadForFile:(FHFile *)file {
	return [_spreads objectForKey:[file URL]];
}



- (FHSpread *)selectedSpread {
	return [self spreadForFile:[self selectedFile]];
}



- (void)updateSpreads {
	NSArray			*files;
	FHSpread		*spread;
	FHFile			*leftFile, *rightFile;
	NSUInteger		i, count;
	
	[_spreads removeAllObjects];
	
	files = [self files];
	i = 0;
	count = [files count];
	
	if(count > 0) {
		if([FHSettings intForKey:FHSpreadMode] == FHSpreadOddPages) {
			leftFile = [files objectAtIndex:i];
			spread = [FHSpread spreadWithLeftFile:leftFile rightFile:NULL];
			[_spreads setObject:spread forKey:[leftFile URL]];
			i++;
		}

		for(; i < count; i += 2) {
			leftFile = [files objectAtIndex:i];
			rightFile = (i + 1 < count) ? [files objectAtIndex:i + 1] : NULL;

			spread = [FHSpread spreadWithLeftFile:leftFile rightFile:rightFile];
			
			if(leftFile)
				[_spreads setObject:spread forKey:[leftFile URL]];
			
			if(rightFile)
				[_spreads setObject:spread forKey:[rightFile URL]];
		}
	}
}



#pragma mark -

- (BOOL)firstFile:(id)sender {
	if([[self files] count] == 0)
		return NO;
	
	[self selectFileAtIndex:0];
	
	return YES;
}



- (BOOL)lastFile:(id)sender {
	NSUInteger		count;

	count = [[self files] count];
	
	if(count == 0)
		return NO;
	
	[self selectFileAtIndex:count - 1];
	
	return YES;
}



- (BOOL)previousFile:(id)sender {
	NSUInteger	index, newIndex;
	
	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NO;
	
	newIndex = index - 1;
	
	if((NSInteger) newIndex < 0)
		return NO;
	
	if([FHSettings intForKey:FHSpreadMode] != FHSpreadNone) {
		if(![[self fileAtIndex:index] isDirectory] &&
		   ![[self fileAtIndex:newIndex] isDirectory])
			newIndex--;
	}
	
	if((NSInteger) newIndex < 0)
		return NO;
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



- (BOOL)nextFile:(id)sender {
	NSUInteger	index, newIndex;
	
	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NO;
	
	newIndex = index + 1;
	
	if(newIndex >= [[self files] count])
		return NO;
	
	if([FHSettings intForKey:FHSpreadMode] != FHSpreadNone) {
		if(![[self fileAtIndex:index] isDirectory] &&
		   ![[self fileAtIndex:newIndex] isDirectory])
			newIndex++;
	}
	
	if(newIndex >= [[self files] count])
		return NO;
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



- (BOOL)previousImage:(id)sender {
	NSArray			*files;
	NSUInteger		i, count, start, index, newIndex;
	
	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NO;
	
	files = [self files];
	count = [files count];
	newIndex = NSNotFound;
	
	if(index > 0) {
		if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone)
			start = index - 1;
		else
			start = index - 2;
		
		i = start;
		
		do {
			if(![[files objectAtIndex:i] isDirectory]) {
				newIndex = i;
				
				break;
			}
		} while(--i != 0);
	}
	
	if(newIndex == NSNotFound)
		return NO;
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



- (BOOL)nextImage:(id)sender {
	NSArray			*files;
	NSUInteger		i, count, start, index, newIndex;

	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NO;
	
	files = [self files];
	count = [files count];
	
	if(index == count - 1)
		return NO;
	
	newIndex = NSNotFound;
	
	if([FHSettings intForKey:FHSpreadMode] == FHSpreadNone)
		start = index + 1;
	else
		start = index + 2;
	
	if(start < count) {
		for(i = start; i < count; i++) {
			if(![[files objectAtIndex:i] isDirectory]) {
				newIndex = i;
				
				break;
			}
		}
	}
	
	if(newIndex == NSNotFound)
		return NO;
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



- (BOOL)previousPage:(id)sender {
	NSArray			*files;
	NSUInteger		i, count, step, index, newIndex;
	
	index = [self selectedIndex];
	
	if(index == 0 || index == NSNotFound)
		return NO;
	
	files = [self files];
	count = [files count];
	newIndex = 0;
	step = (double) count / 10.0;
	step = WIClamp(step, 2, 10);
	
	if([FHSettings intForKey:FHSpreadMode] != FHSpreadNone && step % 2 != 0)
		step++;
	
	if(index > step) {
		for(i = index - step; i > 0; i--) {
			if(![[files objectAtIndex:i] isDirectory]) {
				newIndex = i;
				
				break;
			}
		}
		
		newIndex = index - step;
	}
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



- (BOOL)nextPage:(id)sender {
	NSArray			*files;
	NSUInteger		i, count, step, index, newIndex;
	
	index = [self selectedIndex];
	
	if(index == NSNotFound)
		return NO;
	
	files = [self files];
	count = [files count];
	
	if(index == count - 1)
		return NO;
	
	newIndex = count - 1;
	step = (double) count / 10.0;
	step = WIClamp(step, 2, 10);
	
	if([FHSettings intForKey:FHSpreadMode] != FHSpreadNone && step % 2 != 0)
		step++;

	if(index + step < count) {
		for(i = index + step; i < count; i++) {
			if(![[files objectAtIndex:i] isDirectory]) {
				newIndex = i;
				
				break;
			}
		}
		
		newIndex = index + step;
	}
	
	[self selectFileAtIndex:newIndex];
	
	return YES;
}



#pragma mark -

- (void)scalingMode:(id)sender {
	FHImageScaling		scaling;

	scaling = [sender tag];
	
	[_imageView setImageScaling:scaling];
	
	[FHSettings setInt:scaling forKey:FHImageScalingMethod];

	[[NSNotificationCenter defaultCenter] postNotificationName:FHWindowControllerChangedScalingMode object:_imageView];
}



- (void)spreadMode:(id)sender {
	[FHSettings setInt:[sender tag] forKey:FHSpreadMode];
	
	[self updateSpreads];
	
	[self showFile:[self selectedFile]];

	[[NSNotificationCenter defaultCenter] postNotificationName:FHWindowControllerChangedSpreadMode object:_imageView];
}



- (void)spreadRightToLeft:(id)sender {
	BOOL	value;
	
	value = ![FHSettings boolForKey:FHSpreadRightToLeft];
	
	[FHSettings setBool:value forKey:FHSpreadRightToLeft];
	
	[sender setState:value ? NSOnState : NSOffState];

	[self showFile:[self selectedFile]];
}



- (void)rotateRight:(id)sender {
	float		rotation;
	
	rotation = [_imageView imageRotation];
	
	if(rotation == 270.0)
		rotation = 0.0;
	else
		rotation += 90.0;
	
	[_imageView setImageRotation:rotation];

	[FHSettings setFloat:rotation forKey:FHImageRotation];
}



- (void)rotateLeft:(id)sender {
	float		rotation;
	
	rotation = [_imageView imageRotation];
	
	if(rotation == 0.0)
		rotation = 270.0;
	else
		rotation -= 90.0;
	
	[_imageView setImageRotation:rotation];
	
	[FHSettings setFloat:rotation forKey:FHImageRotation];
}

@end
