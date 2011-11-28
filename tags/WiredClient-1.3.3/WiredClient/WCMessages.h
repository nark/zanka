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

@class WCUser;

@interface WCMessages : WCConnectionController {
	IBOutlet WISplitView				*_conversationsSplitView;
	IBOutlet NSView						*_conversationsView;
	IBOutlet NSView						*_messagesView;
	IBOutlet WISplitView				*_messagesSplitView;
	IBOutlet NSView						*_messageListView;
	IBOutlet NSView						*_messageView;

	IBOutlet NSOutlineView				*_conversationsOutlineView;
	IBOutlet NSTableColumn				*_messagesTableColumn;

	IBOutlet WITableView				*_messagesTableView;
	IBOutlet NSTableColumn				*_userTableColumn;
	IBOutlet NSTableColumn				*_timeTableColumn;

	IBOutlet WITextView					*_messageTextView;
	
	IBOutlet NSButton					*_replyButton;
	IBOutlet NSButton					*_clearButton;

	IBOutlet NSPanel					*_replyPanel;
	IBOutlet NSTextField				*_userTextField;
	IBOutlet NSTextView					*_replyTextView;

	IBOutlet NSPanel					*_broadcastPanel;
	IBOutlet NSTextView					*_broadcastTextView;

	NSMutableArray						*_titles;
	NSMutableArray						*_allConversations;
	NSMutableDictionary					*_conversations;
	NSMutableArray						*_allMessages;
	NSMutableArray						*_shownMessages;
	
	WITextFilter						*_messageFilter;
	WITextFilter						*_userFilter;
	NSImage								*_conversationIcon;
	NSUInteger							_unread;
	
	WCUser								*_messageUser;
	
	WIDateFormatter						*_tableDateFormatter;
	WIDateFormatter						*_dialogDateFormatter;
	
	NSString							*_hiddenMessage;
	NSString							*_hiddenBroadcast;
}


#define WCMessagesDidAddMessage			@"WCMessagesDidAddMessage"
#define WCMessagesDidReadMessage		@"WCMessagesDidReadMessage"


+ (id)messagesWithConnection:(WCServerConnection *)connection;

- (void)showPrivateMessageToUser:(WCUser *)user;
- (void)showPrivateMessageToUser:(WCUser *)user message:(NSString *)message;
- (void)showBroadcast:(NSString *)broadcast;
- (NSUInteger)numberOfUnreadMessages;

- (IBAction)broadcast:(id)sender;
- (IBAction)reply:(id)sender;
- (IBAction)clearMessages:(id)sender;

@end
