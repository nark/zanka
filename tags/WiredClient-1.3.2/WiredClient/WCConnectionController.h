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

@interface WCConnectionController : WIWindowController {
	NSString				*_name;
	NSString				*_identifier;
	WCServerConnection		*_connection;
	NSMutableDictionary		*_windowTemplate;
	
	BOOL					_hidden;
	BOOL					_wasVisible;
	BOOL					_releasedWhenClosed;
}


- (id)initWithWindowNibName:(NSString *)windowNibName connection:(WCServerConnection *)connection;
- (id)initWithWindowNibName:(NSString *)windowNibName name:(NSString *)name connection:(WCServerConnection *)connection;

- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate;
- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate;
- (void)connectionWillTerminate:(NSNotification *)notification;
- (void)connectionDidTerminate:(NSNotification *)notification;
- (void)serverConnectionShouldHide:(NSNotification *)notification;
- (void)serverConnectionShouldUnhide:(NSNotification *)notification;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setConnection:(WCServerConnection *)connection;
- (WCServerConnection *)connection;
- (void)setReleasedWhenClosed:(BOOL)value;
- (BOOL)isReleasedWhenClosed;
- (NSDictionary *)windowTemplate;
- (BOOL)isHidden;

- (BOOL)beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo;
- (BOOL)validateAction:(SEL)selector;

- (IBAction)disconnect:(id)sender;
- (IBAction)reconnect:(id)sender;
- (IBAction)serverInfo:(id)sender;
- (IBAction)chat:(id)sender;
- (IBAction)news:(id)sender;
- (IBAction)messages:(id)sender;
- (IBAction)files:(id)sender;
- (IBAction)transfers:(id)sender;
- (IBAction)accounts:(id)sender;
- (IBAction)postNews:(id)sender;
- (IBAction)broadcast:(id)sender;

- (IBAction)search:(id)sender;

- (IBAction)addBookmark:(id)sender;

- (IBAction)console:(id)sender;

@end
