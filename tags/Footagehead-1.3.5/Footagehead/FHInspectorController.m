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

#import "FHApplicationController.h"
#import "FHBrowserController.h"
#import "FHFile.h"
#import "FHImage.h"
#import "FHInspectorController.h"

@interface FHInspectorController(Private)

- (void)_updateFromFile:(FHFile *)file;
- (void)_updateValuesFromFile:(FHFile *)file;
- (void)_setValue:(NSString *)value forKey:(NSString *)key;
//- (void)_relayoutFields;
//- (NSTextField *)_textFieldLikeTextField:(NSTextField *)archetypeTextField withStringValue:(NSString *)string;

@end


@implementation FHInspectorController(Private)

- (void)_updateFromFile:(FHFile *)file {
	[_sortedKeys removeAllObjects];
	[_allValues removeAllObjects];
	
	[self _updateValuesFromFile:file];
	
	[_inspectorTableView reloadData];
//	[self _relayoutFields];
}



- (void)_updateValuesFromFile:(FHFile *)file {
	NSEnumerator	*enumerator, *dictionaryEnumerator;
	NSDictionary	*properties, *dictionary;
	FHImage			*image;
	NSString		*key, *dictionaryKey;
	id				dictionaryValue;
	
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
		
		[self _setValue:[NSString humanReadableStringForSizeInBytes:image ? [image dataLength] : 0]
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
					
					if([dictionaryValue isKindOfClass:[NSArray class]])
						dictionaryValue = [dictionaryValue componentsJoinedByString:@", "];
					
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
	
	return self;
}



- (void)dealloc {
	[_sortedKeys release];
	[_allValues release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Inspector"];

	[[self window] setTitle:NSLS(@"Inspector", @"Inspector")];
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


#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_sortedKeys count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString		*key;
	
	key = [_sortedKeys objectAtIndex:row];
	
	if([key isEqualToString:@"-"])
		return @"";

	if(tableColumn == _nameTableColumn)
		return key;
	else if(tableColumn == _valueTableColumn)
		return [_allValues objectForKey:key];
	
	return NULL;
}

@end
