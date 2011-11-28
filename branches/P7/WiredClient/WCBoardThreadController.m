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

#import "WCAccount.h"
#import "WCApplicationController.h"
#import "WCBoard.h"
#import "WCBoardPost.h"
#import "WCBoards.h"
#import "WCBoardThread.h"
#import "WCBoardThreadController.h"
#import "WCChatController.h"
#import "WCFile.h"
#import "WCFiles.h"

@interface WCBoardThreadController(Private)

- (void)_reloadDataAndScrollToCurrentPosition:(BOOL)scrollToCurrentPosition selectPost:(WCBoardPost *)selectPost;

- (NSString *)_HTMLStringWithReadPostIDs:(NSSet **)readPostIDs;
- (NSString *)_HTMLStringForPost:(id)post writable:(BOOL)writable;

@end


@implementation WCBoardThreadController(Private)

- (void)_reloadDataAndScrollToCurrentPosition:(BOOL)scrollToCurrentPosition selectPost:(WCBoardPost *)selectPost {
	NSSet			*readPostIDs;
	NSString		*html;
	
	if(scrollToCurrentPosition)
		_previousVisibleRect = [[[[[_threadWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	else
		_previousVisibleRect = NSZeroRect;
	
	[_selectPost release];
	_selectPost = [selectPost retain];
	
	if(_thread) {
		html			= [self _HTMLStringWithReadPostIDs:&readPostIDs];
	} else {
		html			= @"";
		readPostIDs		= NULL;
	}
	
	[[_threadWebView mainFrame] loadHTMLString:html baseURL:[NSURL fileURLWithPath:[[self bundle] resourcePath]]];
	
	if([readPostIDs count] > 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification object:readPostIDs];
}




#pragma mark -

- (NSString *)_HTMLStringWithReadPostIDs:(NSSet **)readPostIDs {
	NSEnumerator		*enumerator;
	NSMutableSet		*set;
	NSMutableString		*html, *string;
	WCBoardPost			*post;
	BOOL				writable, isKeyWindow;
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
	[html replaceOccurrencesOfString:@"<? title ?>" withString:[_thread subject]];
	[html replaceOccurrencesOfString:@"<? fontname ?>" withString:[_font fontName]];
	[html replaceOccurrencesOfString:@"<? fontsize ?>" withString:[NSSWF:@"%.0fpx", [_font pointSize]]];
	[html replaceOccurrencesOfString:@"<? textcolor ?>" withString:[NSSWF:@"#%.6x", [_textColor HTMLValue]]];
	[html replaceOccurrencesOfString:@"<? backgroundcolor ?>" withString:[NSSWF:@"#%.6x", [_backgroundColor HTMLValue]]];

	isKeyWindow		= ([NSApp keyWindow] == [_threadWebView window]);
	set				= [NSMutableSet set];
	enumerator		= [[_thread posts] objectEnumerator];
	writable		= [_board isWritable];
	
	if([_thread text]) {
		[html appendString:[self _HTMLStringForPost:_thread writable:writable]];

		while((post = [enumerator nextObject])) {
			[html appendString:[self _HTMLStringForPost:post writable:writable]];
			
			if(isKeyWindow) {
				[post setUnread:NO];
				
				[set addObject:[post postID]];
			}
		}
		
		if(isKeyWindow) {
			[_thread setUnread:NO];
			
			[set addObject:[_thread threadID]];
		}
		
		string = [[_replyTemplate mutableCopy] autorelease]; 
		
		if([[[_thread connection] account] boardAddPosts] && writable) 
			[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@""]; 
		else 
			[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@"disabled=\"disabled\""]; 
		
		[string replaceOccurrencesOfString:@"<? replystring ?>" withString:NSLS(@"Post Reply", @"Post reply button title")]; 
		
		[html appendString:string]; 
	}
	
	[html appendString:_footerTemplate];
	
	if(readPostIDs)
		*readPostIDs = set;
	
	return html;
}



- (NSString *)_HTMLStringForPost:(id)post writable:(BOOL)writable {
	NSEnumerator		*enumerator;
	NSDictionary		*theme, *regexs;
	NSMutableString		*string, *text, *regex;
	NSString			*substring, *smiley, *path, *icon, *smileyBase64String;
	WCAccount			*account;
	NSRange				range;
	BOOL				own;
	
	theme		= [post theme];
	account		= [(WCServerConnection *) [post connection] account];
	text		= [[[post text] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"&" withString:@"&#38;"];
	[text replaceOccurrencesOfString:@"<" withString:@"&#60;"];
	[text replaceOccurrencesOfString:@">" withString:@"&#62;"];
	[text replaceOccurrencesOfString:@"\"" withString:@"&#34;"];
	[text replaceOccurrencesOfString:@"\'" withString:@"&#39;"];
	[text replaceOccurrencesOfString:@"\n" withString:@"\n<br />\n"];

	[text replaceOccurrencesOfRegex:@"\\[code\\](.+?)\\[/code\\]"
						 withString:@"<blockquote><pre>$1</pre></blockquote>"
							options:RKLCaseless | RKLDotAll];
	
	while([text replaceOccurrencesOfRegex:@"<pre>(.*?)\\[+(.*?)</pre>"
							   withString:@"<pre>$1&#91;$2</pre>"
								  options:RKLCaseless | RKLDotAll] > 0)
		;
	
	while([text replaceOccurrencesOfRegex:@"<pre>(.*?)\\]+(.*?)</pre>"
							   withString:@"<pre>$1&#93;$2</pre>"
								  options:RKLCaseless | RKLDotAll] > 0)
		;
	
	while([text replaceOccurrencesOfRegex:@"<pre>(.*?)<br />\n(.*?)</pre>"
							   withString:@"<pre>$1$2</pre>"
								  options:RKLCaseless | RKLDotAll] > 0)
		;
	
	if([theme boolForKey:WCThemesShowSmileys]) {
		regexs		= [WCChatController smileyRegexs];
		enumerator	= [regexs keyEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			regex				= [regexs objectForKey:smiley];
			path				= [[WCApplicationController sharedController] pathForSmiley:smiley];
			smileyBase64String	= [_smileyBase64Strings objectForKey:smiley];
			
			if(!smileyBase64String) {
				smileyBase64String = [[[NSImage imageWithContentsOfFile:path] TIFFRepresentation] base64EncodedString];
				
				[_smileyBase64Strings setObject:smileyBase64String forKey:smiley];
			}
			
			[text replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)%@(\\s|$)", regex]
								 withString:[NSSWF:@"$1<img src=\"data:image/tiff;base64,%@\" alt=\"%@\" />$2",
												smileyBase64String, smiley]
									options:RKLCaseless | RKLMultiline];
		}
	}
	
	[text replaceOccurrencesOfRegex:@"\\[b\\](.+?)\\[/b\\]"
						 withString:@"<b>$1</b>"
							options:RKLCaseless | RKLDotAll];
	[text replaceOccurrencesOfRegex:@"\\[u\\](.+?)\\[/u\\]"
						 withString:@"<u>$1</u>"
							options:RKLCaseless | RKLDotAll];
	[text replaceOccurrencesOfRegex:@"\\[i\\](.+?)\\[/i\\]"
						 withString:@"<i>$1</i>"
							options:RKLCaseless | RKLDotAll];
	[text replaceOccurrencesOfRegex:@"\\[color=(.+?)\\](.+?)\\[/color\\]"
						 withString:@"<span style=\"color: $1\">$2</span>"
							options:RKLCaseless | RKLDotAll];
	[text replaceOccurrencesOfRegex:@"\\[center\\](.+?)\\[/center\\]"
						 withString:@"<div class=\"center\">$1</div>"
							options:RKLCaseless | RKLDotAll];
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:@"\\[url]wiredp7://(/.+?)\\[/url\\]" options:RKLCaseless capture:0];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:[text rangeOfRegex:@"\\[url]wiredp7://(/.+?)\\[/url\\]" options:RKLCaseless capture:1]];
			
			[text replaceCharactersInRange:range withString:
				[NSSWF:@"<img src=\"data:image/tiff;base64,%@\" /> <a href=\"wiredp7://%@\">%@</a>",
					_fileLinkBase64String, substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	[text replaceOccurrencesOfRegex:@"\\[url=(.+?)\\](.+?)\\[/url\\]"
						 withString:@"<a href=\"$1\">$2</a>"
							options:RKLCaseless];
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:@"\\[url](.+?)\\[/url\\]" options:RKLCaseless capture:0];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:[text rangeOfRegex:@"\\[url](.+?)\\[/url\\]" options:RKLCaseless capture:1]];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	[text replaceOccurrencesOfRegex:@"\\[email=(.+?)\\](.+?)\\[/email\\]"
						 withString:@"<a href=\"mailto:$1\">$2</a>"
							options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[email](.+?)\\[/email\\]"
						 withString:@"<a href=\"mailto:$1\">$1</a>"
							options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[img](.+?)\\[/img\\]"
						 withString:@"<img src=\"$1\" alt=\"\" />"
							options:RKLCaseless];

	[text replaceOccurrencesOfRegex:@"\\[quote=(.+?)\\](.+?)\\[/quote\\]"
						 withString:[NSSWF:@"<blockquote><b>%@</b><br />$2</blockquote>", NSLS(@"$1 wrote:", @"Board quote (nick)")]
							options:RKLCaseless | RKLDotAll];

	[text replaceOccurrencesOfRegex:@"\\[quote\\](.+?)\\[/quote\\]"
						 withString:@"<blockquote>$1</blockquote>"
							options:RKLCaseless | RKLDotAll];
	
	string = [[_postTemplate mutableCopy] autorelease];

	[string replaceOccurrencesOfString:@"<? from ?>" withString:[post nick]];

	if([post isUnread]) {
		[string replaceOccurrencesOfString:@"<? unreadimage ?>"
								withString:[NSSWF:@"<img class=\"postunread\" src=\"data:image/tiff;base64,%@\" />",
												_unreadPostBase64String]];
	} else {
		[string replaceOccurrencesOfString:@"<? unreadimage ?>"
								withString:@""];
	}
	
	[string replaceOccurrencesOfString:@"<? postdate ?>" withString:[_dateFormatter stringFromDate:[post postDate]]];
	
	if([post editDate])
		[string replaceOccurrencesOfString:@"<? editdate ?>" withString:[_dateFormatter stringFromDate:[post editDate]]];
	else
		[string replaceOccurrencesOfString:@"<div class=\"posteditdate\"><? editdate ?></div>" withString:@""];
	
	icon = (NSString *) [post icon];
	
	if([icon length] > 0) {
		[string replaceOccurrencesOfString:@"<? icon ?>"
								withString:[NSSWF:@"data:image/tiff;base64,%@", icon]];
	} else {
		[string replaceOccurrencesOfString:@"<? icon ?>"
								withString:[NSSWF:@"data:image/tiff;base64,%@", _defaultIconBase64String]];
	}

	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	
	if([post isKindOfClass:[WCBoardThread class]])
		[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post threadID]];
	else
		[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post postID]];
	
	if([account boardAddPosts] && writable)
		[string replaceOccurrencesOfString:@"<? quotedisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? quotedisabled ?>" withString:@"disabled=\"disabled\""];
	
	if([post isKindOfClass:[WCBoardThread class]])
		own = [post isOwnThread];
	else
		own = [post isOwnPost];
	
	if(([account boardEditAllThreadsAndPosts] || ([account boardEditOwnThreadsAndPosts] && own)) && writable)
		[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@"disabled=\"disabled\""];

	if(([account boardDeleteAllThreadsAndPosts] || ([account boardDeleteOwnThreadsAndPosts] && own)) && writable)
		[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@"disabled=\"disabled\""];

	[string replaceOccurrencesOfString:@"<? quotestring ?>" withString:NSLS(@"Quote", @"Quote post button title")];
	[string replaceOccurrencesOfString:@"<? editstring ?>" withString:NSLS(@"Edit", @"Edit post button title")];
	[string replaceOccurrencesOfString:@"<? deletestring ?>" withString:NSLS(@"Delete", @"Delete post button title")];
	
	return string;
}

@end



@implementation WCBoardThreadController

- (id)init {
	self = [super init];
	
	_headerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"PostHeader" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_footerTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"PostFooter" ofType:@"html"]
													   encoding:NSUTF8StringEncoding
														  error:NULL];
	_replyTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"PostReply" ofType:@"html"]
													  encoding:NSUTF8StringEncoding
														 error:NULL];
	_postTemplate		= [[NSString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"Post" ofType:@"html"]
													 encoding:NSUTF8StringEncoding
														error:NULL];
	
	[_headerTemplate replaceOccurrencesOfString:@"<? fromstring ?>" withString:NSLS(@"From", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? postdatestring ?>" withString:NSLS(@"Post Date", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? editdatestring ?>" withString:NSLS(@"Edit Date", @"Post header")];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_fileLinkBase64String		= [[[[NSImage imageNamed:@"FileLink"] TIFFRepresentation] base64EncodedString] retain];
	_unreadPostBase64String		= [[[[NSImage imageNamed:@"UnreadPost"] TIFFRepresentation] base64EncodedString] retain];
	_defaultIconBase64String	= [[[[NSImage imageNamed:@"DefaultIcon"] TIFFRepresentation] base64EncodedString] retain];
	
	_smileyBase64Strings		= [[NSMutableDictionary alloc] init];
	
	return self;
}



- (void)dealloc {
	[_thread release];
	
	[_headerTemplate release];
	[_footerTemplate release];
	[_replyTemplate release];
	[_postTemplate release];
	
	[_fileLinkBase64String release];
	[_unreadPostBase64String release];
	[_defaultIconBase64String release];
	
	[_font release];
	[_textColor release];
	[_backgroundColor release];
	
	[_dateFormatter release];
	
	[_selectPost release];
	
	[super dealloc];
}



#pragma mark -

- (void)webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame {
	if(_previousVisibleRect.size.height > 0.0)
		[[[[_threadWebView mainFrame] frameView] documentView] scrollRectToVisible:_previousVisibleRect];

	if(_selectPost) {
		[_threadWebView stringByEvaluatingJavaScriptFromString:[NSSWF:@"window.location.hash='%@';", [_selectPost postID]]];
		
		[_selectPost release];
		_selectPost = NULL;
	}
}



- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
	[windowObject setValue:[WCBoards boards] forKey:@"Boards"];
}



- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
	NSString			*path;
	WIURL				*url;
	WCFile				*file;
	BOOL				handled = NO;
	
	if([[action objectForKey:WebActionNavigationTypeKey] unsignedIntegerValue] == WebNavigationTypeOther) {
		[listener use];
	} else {
		[listener ignore];
		
		url = [WIURL URLWithURL:[action objectForKey:WebActionOriginalURLKey]];
		
		if([[url scheme] isEqualToString:@"wired"] || [[url scheme] isEqualToString:@"wiredp7"]) {
			if([[url host] length] == 0) {
				if([[_thread connection] isConnected]) {
					path = [[url path] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
					
					if([path hasSuffix:@"/"]) {
						while([path hasSuffix:@"/"] && [path length] > 1)
							path = [path substringToIndex:[path length] - 1];
						
						file = [WCFile fileWithDirectory:path connection:[_thread connection]];
						
						[WCFiles filesWithConnection:[_thread connection] file:file];
					} else {
						file = [WCFile fileWithDirectory:[path stringByDeletingLastPathComponent] connection:[_thread connection]];
						
						[WCFiles filesWithConnection:[_thread connection]
												file:file
										  selectFile:[WCFile fileWithFile:path connection:[_thread connection]]];
					}
				}
				
				handled = YES;
			}
		}
		
		if(!handled)
			[[NSWorkspace sharedWorkspace] openURL:[action objectForKey:WebActionOriginalURLKey]];
	}
}



- (NSArray *)webView:(WebView *)webView contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return NULL;
}



#pragma mark -

- (void)setBoard:(WCBoard *)board {
	[board retain];
	[_board release];
	
	_board = board;
}



- (WCBoard *)board {
	return _board;
}



- (void)setThread:(WCBoardThread *)thread {
	[thread retain];
	[_thread release];
	
	_thread = thread;
}



- (WCBoardThread *)thread {
	return _thread;
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

- (WebView *)threadWebView {
	return _threadWebView;
}



- (NSString *)HTMLString {
	return [self _HTMLStringWithReadPostIDs:NULL];
}



#pragma mark -

- (void)reloadData {
	[self _reloadDataAndScrollToCurrentPosition:NO selectPost:NULL];
}



- (void)reloadDataAndScrollToCurrentPosition {
	[self _reloadDataAndScrollToCurrentPosition:YES selectPost:NULL];
}



- (void)reloadDataAndSelectPost:(WCBoardPost *)selectPost {
	[self _reloadDataAndScrollToCurrentPosition:NO selectPost:selectPost];
}

@end
