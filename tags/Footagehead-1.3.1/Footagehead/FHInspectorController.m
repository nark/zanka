/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#import "FHApplicationController.h"
#import "FHBrowserController.h"
#import "FHFile.h"
#import "FHImage.h"
#import "FHInspectorController.h"

@interface FHInspectorController(Private)

- (void)_updateFromFile:(FHFile *)file;
- (void)_updateValuesFromFile:(FHFile *)file;
- (void)_setValue:(NSString *)value forKey:(NSString *)key;
- (void)_relayoutFields;
- (NSTextField *)_textFieldLikeTextField:(NSTextField *)archetypeTextField withStringValue:(NSString *)string;

@end


@implementation FHInspectorController(Private)

- (void)_updateFromFile:(FHFile *)file {
	[_sortedKeys removeAllObjects];
	[_allValues removeAllObjects];
	
	[self _updateValuesFromFile:file];
	[self _relayoutFields];
}



- (void)_updateValuesFromFile:(FHFile *)file {
	NSEnumerator	*enumerator, *dictionaryEnumerator;
	NSDictionary	*properties, *dictionary;
	FHImage			*image;
	NSString		*key, *dictionaryKey, *dictionaryValue;
	
	image = [file image];
	properties = [image properties];
	
	[self _setValue:[file name] forKey:NSLS(@"File Name", @"Inspector label")];

	if(image) {
		[self _setValue:[NSSWF:NSLS(@"%.0fx%.0f", @"'640x480'"), [image size].width, [image size].height]
				 forKey:NSLS(@"Image Size", @"Inspector label")];
	}
	
	if(properties) {
		if([properties floatForKey:(id) kCGImagePropertyDPIHeight] > 0.0) {
			[self _setValue:[NSSWF:@"%.2f", [properties floatForKey:(id) kCGImagePropertyDPIHeight]]
					 forKey:NSLS(@"Image DPI", @"Inspector label")];
		}
		
		[self _setValue:[NSString humanReadableStringForSizeInBytes:[image dataLength]]
				 forKey:NSLS(@"File Size", @"Inspector label")];
		[self _setValue:[properties objectForKey:(id) kCGImagePropertyColorModel]
				 forKey:NSLS(@"Color Model", @"Inspector label")];
		[self _setValue:[properties objectForKey:(id) kCGImagePropertyProfileName]
				 forKey:NSLS(@"Profile Name", @"Inspector label")];
		
		enumerator = [[NSArray arrayWithObjects:
			(id) kCGImagePropertyTIFFDictionary,
			(id) kCGImagePropertyGIFDictionary,
			(id) kCGImagePropertyJFIFDictionary,
			(id) kCGImagePropertyExifDictionary,
			(id) kCGImagePropertyPNGDictionary,
			(id) kCGImagePropertyIPTCDictionary,
			(id) kCGImagePropertyGPSDictionary,
			(id) kCGImagePropertyRawDictionary,
			(id) kCGImagePropertyCIFFDictionary,
			(id) kCGImageProperty8BIMDictionary,
			NULL] objectEnumerator];

		while((key = [enumerator nextObject])) {
			dictionary = [properties objectForKey:key];
			
			if([dictionary count] > 0) {
				[self _setValue:@"-" forKey:@"-"];
				dictionaryEnumerator = [dictionary keyEnumerator];
			
				while((dictionaryKey = [dictionaryEnumerator nextObject])) {
					dictionaryValue = [dictionary objectForKey:dictionaryKey];
					
					[self _setValue:dictionaryValue forKey:dictionaryKey];
				}
			}
		}
	}
}



- (void)_setValue:(NSString *)value forKey:(NSString *)key {
	if(key && value) {
		[_sortedKeys addObject:key];
		[_allValues setObject:value forKey:key];
	}
}



- (void)_relayoutFields {
	NSTextField		*nameTextField, *valueTextField;
	NSView			*contentView;
	NSEnumerator	*enumerator;
	NSString		*key, *value;
	NSRect			windowFrame;
	NSSize			nameSize, valueSize;
	CGFloat			verticalOffset, height;
	
	verticalOffset = 20.0;
	contentView = [[self window] contentView];
	enumerator = [_sortedKeys reverseObjectEnumerator];
	
	[[contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	while((key = [enumerator nextObject])) {
		if([key isEqualToString:@"-"]) {
			verticalOffset += 16.0;
			
			continue;
		}
		
		value = [_allValues objectForKey:key];
		
		nameTextField = [self _textFieldLikeTextField:_nameTextField withStringValue:[key stringByAppendingString:@":"]];
		valueTextField = [self _textFieldLikeTextField:_valueTextField withStringValue:value];
		
		nameSize = [[nameTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [nameTextField frame].size.width, 10000.0)];
		valueSize = [[valueTextField cell] cellSizeForBounds:NSMakeRect(0.0, 0.0, [valueTextField frame].size.width, 10000.0)];
		height = MAX(nameSize.height, valueSize.height);
		
		[nameTextField setFrame:NSMakeRect([nameTextField frame].origin.x, verticalOffset,
										   [nameTextField frame].size.width, height)];
		[valueTextField setFrame:NSMakeRect([valueTextField frame].origin.x, verticalOffset,
											[valueTextField frame].size.width, height)];
		
		[contentView addSubview:nameTextField];
		[contentView addSubview:valueTextField];
		
		verticalOffset += height + 2.0;
	}
	
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



@implementation FHInspectorController

+ (FHInspectorController *)inspectorController {
	static FHInspectorController		*inspectorController;
	
	if(!inspectorController)
		inspectorController = [[[self class] alloc] init];
	
	return inspectorController;
}



- (id)init {
	self = [super initWithWindowNibName:@"Inspector"];
	
	_sortedKeys = [[NSMutableArray alloc] init];
	_allValues = [[NSMutableDictionary alloc] init];
	
	 [[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(browserControllerDidShowFile:)
			   name:FHBrowserControllerDidShowFile];
	
	[(NSPanel *) [self window] setBecomesKeyOnlyIfNeeded:YES];
	
	return self;
}



- (void)dealloc {
	[_nameTextField release];
	[_valueTextField release];

	[_sortedKeys release];
	[_allValues release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[self window] setTitle:NSLS(@"Inspector", @"Inspector")];
	
	[[_nameTextField retain] removeFromSuperview];
	[[_valueTextField retain] removeFromSuperview];
}



#pragma mark -

- (void)browserControllerDidShowFile:(NSNotification *)notification {
	if([[self window] isVisible])
		[self _updateFromFile:[notification object]];
}



#pragma mark -

- (void)showWindow:(id)sender {
	[self _updateFromFile:[[[NSApp delegate] browserController] selectedFile]];
	
	[super showWindow:sender];
}

@end
