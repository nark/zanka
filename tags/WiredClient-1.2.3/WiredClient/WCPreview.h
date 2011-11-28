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

#import "WCWindowController.h"

@class WCPDFView;

@interface WCPreview : WCWindowController {
    IBOutlet NSWindow					*_textWindow;
    IBOutlet NSTextView					*_textView;

    IBOutlet NSWindow					*_imageWindow;
    IBOutlet NSImageView				*_imageView;

	IBOutlet NSWindow					*_pdfWindow;
	IBOutlet WCPDFView					*_pdfView;
}


#define WCPreviewPlainTextExtensions	@"1 2 3 4 5 6 7 8 9 c cc cgi conf css diff h in java log m patch pem php pl plist rb s sh status strings tcl text txt xml"
#define WCPreviewRichTextExtensions		@"rtf"
#define WCPreviewHTMLExtensions			@"htm html shtm shtml"
#define WCPreviewImageExtensions		@"bmp eps jpg jpeg tif tiff gif pict pct png"
#define WCPreviewPDFExtensions			@"pdf"

#define WCPreviewAllExtensions			WCPreviewPlainTextExtensions @" " \
										WCPreviewRichTextExtensions @" " \
										WCPreviewHTMLExtensions @" " \
										WCPreviewImageExtensions @" " \
										WCPreviewPDFExtensions


- (id)									initWithConnection:(WCConnection *)connection;

- (void)								showPreview:(NSString *)path;

@end
