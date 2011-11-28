/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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

#import "WCApplicationController.h"
#import "WCChatController.h"
#import "WCConversation.h"
#import "WCConversationController.h"
#import "WCMessage.h"
#import "WCMessages.h"

@interface WCConversationController(Private)

- (NSString *)_HTMLStringForMessage:(WCMessage *)message icon:(NSString *)icon;
- (NSString *)_HTMLStringForStatus:(NSString *)status;

@end


@implementation WCConversationController(Private)

- (NSString *)_HTMLStringForMessage:(WCMessage *)message icon:(NSString *)icon {
	NSEnumerator		*enumerator;
	NSDictionary		*theme, *regexs;
	NSMutableString		*string, *text;
	NSString			*smiley, *path, *regex, *substring;
	NSRange				range;
	
	theme		= [message theme];
	text		= [[[message message] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"&" withString:@"&#38;"];
	[text replaceOccurrencesOfString:@"<" withString:@"&#60;"];
	[text replaceOccurrencesOfString:@">" withString:@"&#62;"];
	[text replaceOccurrencesOfString:@"\"" withString:@"&#34;"];
	[text replaceOccurrencesOfString:@"\'" withString:@"&#39;"];
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController URLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController schemelessURLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"http://%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController mailtoURLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"mailto:%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	if([theme boolForKey:WCThemesShowSmileys]) {
		regexs			= [WCChatController smileyRegexs];
		enumerator		= [regexs keyEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			regex		= [regexs objectForKey:smiley];
			path		= [[WCApplicationController sharedController] pathForSmiley:smiley];
		
			[text replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)%@(\\s|$)", regex]
								 withString:[NSSWF:@"$1<img src=\"%@\" alt=\"%@\" />$2", path, smiley]
									options:RKLCaseless | RKLMultiline];
		}
	}

	[text replaceOccurrencesOfString:@"\n" withString:@"<br />\n"];
	
	string = [[_messageTemplate mutableCopy] autorelease];
	
	if([message direction] == WCMessageTo)
		[string replaceOccurrencesOfString:@"<? direction ?>" withString:@"to"];
	else
		[string replaceOccurrencesOfString:@"<? direction ?>" withString:@"from"];
	
	[string replaceOccurrencesOfString:@"<? nick ?>" withString:[message nick]];
	[string replaceOccurrencesOfString:@"<? time ?>" withString:[_messageTimeDateFormatter stringFromDate:[message date]]];
	[string replaceOccurrencesOfString:@"<? server ?>" withString:[message connectionName]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	
	if(icon)
		[string replaceOccurrencesOfString:@"<? icon ?>" withString:[NSSWF:@"data:image/tiff;base64,%@", icon]];
	else
		[string replaceOccurrencesOfString:@"<? icon ?>" withString:@"DefaultIcon.tiff"];
	
	return string;
}



- (NSString *)_HTMLStringForStatus:(NSString *)status {
	NSMutableString		*string;
	
	string = [[_statusTemplate mutableCopy] autorelease];
	
	[string replaceOccurrencesOfString:@"<? status ?>" withString:status];
	
	return string;
}

@end


@implementation WCConversationController

- (id)init {
	self = [super init];
	
	_headerTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageHeader" ofType:@"html"]
													   encoding:NSUTF8StringEncoding
														  error:NULL];
	_footerTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageFooter" ofType:@"html"]
													   encoding:NSUTF8StringEncoding
														  error:NULL];
	_messageTemplate	= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"Message" ofType:@"html"]
													   encoding:NSUTF8StringEncoding
														  error:NULL];
	_statusTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageStatus" ofType:@"html"]
													   encoding:NSUTF8StringEncoding
														  error:NULL];
	
	_messageStatusDateFormatter = [[WIDateFormatter alloc] init];
	[_messageStatusDateFormatter setTimeStyle:NSDateFormatterNoStyle];
	[_messageStatusDateFormatter setDateStyle:NSDateFormatterLongStyle];
	
	_messageTimeDateFormatter = [[WIDateFormatter alloc] init];
	[_messageTimeDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	return self;
}



- (void)dealloc {
	[_conversation release];
	
	[_headerTemplate release];
	[_footerTemplate release];
	[_messageTemplate release];
	[_statusTemplate release];
	
	[_font release];
	[_textColor release];
	[_backgroundColor release];
	
	[_messageStatusDateFormatter release];
	[_messageTimeDateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame {
	NSRect		rect;
	
	rect = [[[[[_conversationWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y = [[[[_conversationWebView mainFrame] frameView] documentView] frame].size.height;
	[[[[_conversationWebView mainFrame] frameView] documentView] scrollRectToVisible:rect];
}



- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
	if([[action objectForKey:WebActionNavigationTypeKey] unsignedIntegerValue] == WebNavigationTypeOther) {
		[listener use];
	} else {
		[listener ignore];
		
		[[NSWorkspace sharedWorkspace] openURL:[action objectForKey:WebActionOriginalURLKey]];
	}
}



- (NSArray *)webView:(WebView *)webView contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return NULL;
}



#pragma mark -

- (void)setConversation:(WCConversation *)conversation {
	[conversation retain];
	[_conversation release];
	
	_conversation = conversation;
}



- (WCConversation *)conversation {
	return _conversation;
}



- (void)setFont:(NSFont *)font {
	[font retain];
	[_font release];
	
	_font = font;
}



- (NSFont *)font {
	return _font;
}



- (void)setTextColor:(NSColor *)textColor {
	[textColor retain];
	[_textColor release];
	
	_textColor = textColor;
}



- (NSColor *)textColor {
	return _textColor;
}



- (void)setBackgroundColor:(NSColor *)backgroundColor {
	[backgroundColor retain];
	[_backgroundColor release];
	
	_backgroundColor = backgroundColor;
}



- (NSColor *)backgroundColor {
	return _backgroundColor;
}



#pragma mark -

- (WebView *)conversationWebView {
	return _conversationWebView;
}



#pragma mark -

- (void)reloadData {
	NSEnumerator			*enumerator;
	NSMutableString			*html;
	NSMutableDictionary		*icons;
	NSCalendar				*calendar;
	NSDateComponents		*components;
	NSString				*icon;
	WCMessage				*message;
	NSInteger				day;
	BOOL					changedUnread = NO, isKeyWindow;
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
	[html replaceOccurrencesOfString:@"<? fontname ?>" withString:[_font fontName]];
	[html replaceOccurrencesOfString:@"<? fontsize ?>" withString:[NSSWF:@"%.0fpx", [_font pointSize]]];
	[html replaceOccurrencesOfString:@"<? textcolor ?>" withString:[NSSWF:@"#%.6x", [_textColor HTMLValue]]];
	[html replaceOccurrencesOfString:@"<? backgroundcolor ?>" withString:[NSSWF:@"#%.6x", [_backgroundColor HTMLValue]]];

	if(_conversation && ![_conversation isExpandable]) {
		isKeyWindow = ([NSApp keyWindow] == [_conversationWebView window]);
		
		if([_conversation numberOfMessages] == 0) {
			[html appendString:[self _HTMLStringForStatus:[_messageStatusDateFormatter stringFromDate:[NSDate date]]]];
		} else {
			calendar		= [NSCalendar currentCalendar];
			day				= -1;
			icons			= [NSMutableDictionary dictionary];
			enumerator		= [[_conversation messages] objectEnumerator];
			
			while((message = [enumerator nextObject])) {
				components = [calendar components:NSDayCalendarUnit fromDate:[message date]];
				
				if([components day] != day) {
					[html appendString:[self _HTMLStringForStatus:[_messageStatusDateFormatter stringFromDate:[message date]]]];
					
					day = [components day];
				}
				
				icon = [icons objectForKey:[NSNumber numberWithInt:[[message user] userID]]];
				
				if(!icon) {
					icon = [[[[message user] icon] TIFFRepresentation] base64EncodedString];
					
					if(icon)
						[icons setObject:icon forKey:[NSNumber numberWithInt:[[message user] userID]]];
				}
				
				[html appendString:[self _HTMLStringForMessage:message icon:icon]];
				
				if([message isUnread] && isKeyWindow) {
					[message setUnread:NO];
					
					changedUnread = YES;
				}
			}
		}
		
		if([_conversation isUnread] && isKeyWindow) {
			[_conversation setUnread:NO];
			
			changedUnread = YES;
		}
	}
	
	[html appendString:_footerTemplate];
	
	[[_conversationWebView mainFrame] loadHTMLString:html baseURL:[NSURL fileURLWithPath:[[self bundle] resourcePath]]];
	
	if(changedUnread)
		[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
}

@end
