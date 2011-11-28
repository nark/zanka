/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import "WCPreferences.h"
#import "WCPreview.h"

#define WCPreviewPlainTextExtensions	@"1 2 3 4 5 6 7 8 9 c cc cgi conf css diff h in java log m patch pem php pl plist pod rb s sh status strings tcl text txt xml"
#define WCPreviewRTFExtensions			@"rtf"
#define WCPreviewHTMLExtensions			@"htm html shtm shtml"
#define WCPreviewPDFExtensions			@"pdf"
#define WCPreviewNFOExtensions			@"nfo"
#define WCPreviewImageExtensions		@"bmp eps jpg jpeg tif tiff gif pict pct png"

@interface WCPreview(Private)

- (id)_initPreviewWithConnection:(WCServerConnection *)connection path:(NSString *)path error:(WCError **)error;

- (void)_update;

- (BOOL)_openFileAtPath:(NSString *)path error:(WCError **)error;

@end


@implementation WCPreview(Private)

- (id)_initPreviewWithConnection:(WCServerConnection *)connection path:(NSString *)path error:(WCError **)error {
	self = [super initWithWindowNibName:@"Preview" connection:connection];
	
	_path = [path retain];

	[self setReleasedWhenClosed:YES];
	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];
	
	if(![self _openFileAtPath:_path error:error]) {
		[self release];
		
		return NULL;
	}
	
	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Preview"];
	[self showWindow:self];
	
	[self retain];

	return self;
}



#pragma mark -

- (void)_update {
	[_textView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCPreviewFont]]];
	[_textView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCPreviewTextColor]]];
	[_textView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCPreviewBackgroundColor]]];
}



#pragma mark -

- (BOOL)_openFileAtPath:(NSString *)path error:(WCError **)error {
	NSString			*extension;
	NSStringEncoding	encoding;

	extension = [[path pathExtension] lowercaseString];

	if([[WCPreview textFileTypes] containsObject:extension] || [extension isEqualToString:@""]) {
		NSString	*text;
 
		text = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:NULL];

		if(!text) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
			
			return NO;
		}

		[_textView setString:text];
		[_textWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_textWindow];
	}
	else if([[WCPreview RTFFileTypes] containsObject:extension]) {
		NSAttributedString	*rtf;
		NSData				*data;

		data = [NSData dataWithContentsOfFile:path];

		if(!data) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];

			return NO;
		}

		rtf = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];

		if(!rtf) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];

			return NO;
		}

		[[_textView textStorage] setAttributedString:rtf];
		[_textWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_textWindow];

		[rtf release];
	}
	else if([[WCPreview HTMLFileTypes] containsObject:extension]) {
		NSData				*data;

		data = [NSData dataWithContentsOfFile:path];

		if(!data) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];

			return NO;
		}

		[[_htmlView mainFrame] loadData:data MIMEType:NULL textEncodingName:NULL baseURL:NULL];

		[_htmlWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_htmlWindow];
	}
	else if([[WCPreview PDFFileTypes] containsObject:extension]) {
		NSPDFImageRep	*pdf;
		NSRect			rect, frame;
		NSSize			size;

		pdf = [NSPDFImageRep imageRepWithContentsOfFile:path];

		if(!pdf) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];

			return NO;
		}

		size = [pdf bounds].size;
		rect = NSMakeRect(0, 0, size.width, size.height);
		frame = [NSWindow frameRectForContentRect:rect styleMask:[_pdfWindow styleMask]];
		size.height += 1.0;
		frame.size.height += 1.0;

		[_pdfView setPDF:pdf];
		[_pdfWindow setContentSize:size];
		[_pdfWindow setMaxSize:NSMakeSize(frame.size.width, frame.size.height * [pdf pageCount])];
		[_pdfWindow setMinSize:frame.size];
		[_pdfWindow center];
		[_pdfWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_pdfWindow];
	}
	else if([[WCPreview NFOFileTypes] containsObject:extension]) {
		NSString			*nfo;
		NSData				*data;
		NSStringEncoding	encoding;
		
		data = [NSData dataWithContentsOfFile:path];
		
		if(!data) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
			
			return NO;
		}
		
		encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatinUS);
		nfo = [NSString stringWithData:data encoding:encoding];
		
		if(!nfo) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];
			
			return NO;
		}
		
		[_textView setString:nfo];
		[_textView setHorizontallyResizable:NO];
		[_textView setFrameSize:NSMakeSize(1e7, [_textView frame].size.height)];
		[_textWindow setContentSize:NSMakeSize(550, 550)];
		[_textWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_textWindow];
	}
	else if([[WCPreview imageFileTypes] containsObject:extension]) {
		NSImage		*image;
		NSRect		rect;
		NSSize		size, minSize, maxSize;

		image = [[NSImage alloc] initWithContentsOfFile:path];

		if(!image) {
			*error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientOpenFailed argument:path];

			return NO;
		}

		minSize = [_imageWindow minSize];
		rect = NSMakeRect(0, 0, minSize.width, minSize.height);
		minSize = [NSWindow contentRectForFrameRect:rect styleMask:[_imageWindow styleMask]].size;
		
		if(size.width < minSize.width)
			size.width = minSize.width;
		if(size.height < minSize.height)
			size.height = minSize.height;
		
		size = [image size];
		rect = NSMakeRect(0, 0, size.width, size.height);
		maxSize = [NSWindow frameRectForContentRect:rect styleMask:[_imageWindow styleMask]].size;

		[_imageView setImage:image];
		[_imageWindow setBackgroundColor:[NSColor whiteColor]];
		[_imageWindow setContentSize:size];
		[_imageWindow setMaxSize:maxSize];
		[_imageWindow center];
		[_imageWindow setTitleWithRepresentedFilename:path];
		[self setWindow:_imageWindow];

		[image release];
	}
	
	return YES;
}

@end


@implementation WCPreview

+ (BOOL)canInitWithExtension:(NSString *)extension {
	return [extension isEqualToString:@""] || [[self allFileTypes] containsObject:extension];
}



+ (NSArray *)allFileTypes {
	static NSMutableArray		*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[self textFileTypes]];
		[extensions addObjectsFromArray:[self RTFFileTypes]];
		[extensions addObjectsFromArray:[self HTMLFileTypes]];
		[extensions addObjectsFromArray:[self PDFFileTypes]];
		[extensions addObjectsFromArray:[self NFOFileTypes]];
		[extensions addObjectsFromArray:[self imageFileTypes]];
	}

	return extensions;
}



+ (NSArray *)textFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewPlainTextExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewPlainTextExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)RTFFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewRTFExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewRTFExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)HTMLFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewHTMLExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewHTMLExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)PDFFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewPDFExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewPDFExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSArray *)NFOFileTypes {
	static NSMutableArray	*extensions;
	
	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewNFOExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewNFOExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}
	
	return extensions;
}



+ (NSArray *)imageFileTypes {
	static NSMutableArray	*extensions;

	if(!extensions) {
		extensions = [[NSMutableArray alloc] init];
		[extensions addObjectsFromArray:[[WCPreviewImageExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCPreviewImageExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



#pragma mark -

+ (id)previewWithConnection:(WCServerConnection *)connection path:(NSString *)path error:(WCError **)error {
	return [[[self alloc] _initPreviewWithConnection:connection path:path error:error] autorelease];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[[NSFileManager defaultManager] removeFileAtPath:_path handler:NULL];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self _update];
	
	[super windowDidLoad];
}



- (void)connectionWillTerminate:(NSNotification *)notification {
	[super connectionWillTerminate:notification];

	[self close];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}

@end
