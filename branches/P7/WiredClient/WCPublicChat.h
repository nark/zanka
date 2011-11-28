/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

@class WCPublicChatController, WCServerConnection;

@interface WCPublicChat : WIWindowController {
	IBOutlet NSTabView					*_chatTabView;

	IBOutlet NSTextField				*_noConnectionTextField;
	
	PSMTabBarControl					*_tabBarControl;
	
	NSMutableDictionary					*_chatControllers;
	NSMutableDictionary					*_chatActivity;
}

+ (id)publicChat;

- (NSString *)saveDocumentMenuItemTitle;

- (IBAction)saveDocument:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)reconnect:(id)sender;
- (IBAction)serverInfo:(id)sender;
- (IBAction)files:(id)sender;
- (IBAction)administration:(id)sender;
- (IBAction)settings:(id)sender;
- (IBAction)monitor:(id)sender;
- (IBAction)log:(id)sender;
- (IBAction)accounts:(id)sender;
- (IBAction)banlist:(id)sender;
- (IBAction)console:(id)sender;
- (IBAction)getInfo:(id)sender;
- (IBAction)saveChat:(id)sender;
- (IBAction)setTopic:(id)sender;
- (IBAction)broadcast:(id)sender;

- (IBAction)addBookmark:(id)sender;

- (IBAction)nextConnection:(id)sender;
- (IBAction)previousConnection:(id)sender;

- (void)addChatController:(WCPublicChatController *)chatController;
- (void)selectChatController:(WCPublicChatController *)chatController;
- (WCPublicChatController *)selectedChatController;
- (WCPublicChatController *)chatControllerForConnectionIdentifier:(NSString *)identifier;
- (NSArray *)chatControllers;

@end
