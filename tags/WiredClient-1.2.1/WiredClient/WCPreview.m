/* $Id$ */

/*
 *  Copyright (c) 2003-2004 Axel Andersson
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

#import "NSImageAdditions.h"
#import "WCConnection.h"
#import "WCError.h"
#import "WCPDFView.h"
#import "WCPreview.h"
#import "WCSettings.h"

@implementation WCPreview

- (id)initWithConnection:(WCConnection *)connection {
	self = [super initWithWindowNibName:@"Preview"];
	
	// --- get parameters
	_connection = [connection retain];

	// --- load the window
	[self window];
	
	// --- subscribe to this
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(connectionShouldTerminate:)
		name:WCConnectionShouldTerminate
		object:NULL];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	// --- font
	[_textView setFont:[WCSettings archivedObjectForKey:WCTextFont]];

	// --- window positions
	[_textWindow setFrameAutosaveName:@"Text Preview"];
	[_imageWindow setFrameAutosaveName:@"Image Preview"];
	[_pdfWindow setFrameAutosaveName:@"PDF Preview"];
}



- (void)windowWillClose:(NSNotification *)notification {
	[super windowWillClose:notification];

	[self release];
}



- (void)connectionShouldTerminate:(NSNotification *)notification {
	if([notification object] == _connection)
		[self close];
}



#pragma mark -

- (void)showPreview:(NSString *)path {
	NSString		*extension;
	
	// --- get extension
	extension = [[path pathExtension] lowercaseString];

	// --- text by default
	if([extension isEqualToString:@""] ||
	   [[WCPreviewPlainTextExtensions componentsSeparatedByString:@" "] containsObject:extension]) {
		NSString		*text;
		
		// --- load file
		text = [NSString stringWithContentsOfFile:path];
		
		if(!text) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
		
		// --- set text
		[_textView setString:text];

		// --- show window
		[_textWindow setTitleWithRepresentedFilename:path];
		[_textWindow makeKeyAndOrderFront:self];
		[self setWindow:_textWindow];
	}
	else if([[WCPreviewRichTextExtensions componentsSeparatedByString:@" "] containsObject:extension]) {
		NSAttributedString		*rtf;
		NSData					*data;
		
		// --- load file
		data = [NSData dataWithContentsOfFile:path];
		
		if(!data) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
			
		// --- load RTF
		rtf = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
		
		if(!rtf) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
		
		// --- set RTF
		[[_textView textStorage] appendAttributedString:rtf];

		// --- show window
		[_textWindow setTitleWithRepresentedFilename:path];
		[_textWindow makeKeyAndOrderFront:self];
		[self setWindow:_textWindow];

		[rtf release];
	}
	else if([[WCPreviewHTMLExtensions componentsSeparatedByString:@" "] containsObject:extension]) {
		NSAttributedString		*html;
		NSData					*data;
		
		// --- load file
		data = [NSData dataWithContentsOfFile:path];
		
		if(!data) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
			
		// --- load HTML
		html = [[NSAttributedString alloc] initWithHTML:data documentAttributes:NULL];
		
		if(!html) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
		
		// --- set HTML
		[[_textView textStorage] appendAttributedString:html];

		// --- show window
		[_textWindow setTitleWithRepresentedFilename:path];
		[_textWindow makeKeyAndOrderFront:self];
		[self setWindow:_textWindow];

		[html release];
	}
	else if([[WCPreviewImageExtensions componentsSeparatedByString:@" "] containsObject:extension]) {
		NSImage		*image;
		NSSize		size;
		
		// --- load image
		image = [[NSImage alloc] initWithContentsOfFile:path];
		
		if(!image) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
		
		// --- get image size
		size = [image size];
		
		// --- set image
		[_imageView setImage:[image smoothedImage]];
		
		// --- show window
		[_imageWindow setBackgroundColor:[NSColor whiteColor]];
		[_imageWindow setContentSize:size];
		[_imageWindow setMaxSize:[_imageWindow frame].size];
		[_imageWindow center];
		[_imageWindow setTitleWithRepresentedFilename:path];
		[_imageWindow makeKeyAndOrderFront:self];
		[self setWindow:_imageWindow];

		[image release];
	}
	else if([[WCPreviewPDFExtensions componentsSeparatedByString:@" "] containsObject:extension]) {
	    NSPDFImageRep		*pdf;
		NSRect				frame;

		// --- load PDF
		pdf = [NSPDFImageRep imageRepWithContentsOfFile:path];

		if(!pdf) {
			[[_connection error] setError:WCApplicationErrorOpenFailed];
			[[_connection error] raiseErrorWithArgument:path];
			
			[self release];
			return;
		}
		
		// --- get frame
		frame = [pdf bounds];
		frame.size.height *= [pdf pageCount];
		
		// --- set view
		[_pdfView setPDF:pdf];
		[_pdfView setFrame:frame];
		[_pdfView scrollPoint:NSMakePoint(0, frame.size.height)];
		
		// --- show window (18? oh well)
		[_pdfWindow setContentSize:NSMakeSize([pdf bounds].size.width + 18, [pdf bounds].size.height)];
		[_pdfWindow setMaxSize:NSMakeSize([_pdfWindow frame].size.width, frame.size.height)];
		[_pdfWindow center];
		[_pdfWindow setTitleWithRepresentedFilename:path];
		[_pdfWindow makeKeyAndOrderFront:self];
		[self setWindow:_pdfWindow];
	}
	
	[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
}

@end
