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

#import "NSMutableAttributedStringAdditions.h"
#import "NSTextViewAdditions.h"

@implementation NSTextView(WCTextScanning)

- (void)setString:(NSString *)string withURL:(BOOL)url withChat:(BOOL)chat {
	NSMutableAttributedString   *attributedString;
	NSRange						range;
	
	attributedString = [[NSMutableAttributedString alloc] initWithString:string];
	range.location = 0;
	range.length = [string length];
	
	[attributedString addAttribute:NSForegroundColorAttributeName value:[self textColor] range:range];
	[attributedString addAttribute:NSFontAttributeName value:[self font] range:range];
	
	if(url)
		[attributedString addURLAttributes];
	
	if(chat)
		[attributedString addChatAttributes];
	
	[[self textStorage] setAttributedString:attributedString];
	
	[attributedString release];
}



- (void)appendString:(NSString *)string withURL:(BOOL)url withChat:(BOOL)chat {
	NSMutableAttributedString   *attributedString;
	NSRange						range;
	
	attributedString = [[NSMutableAttributedString alloc] initWithString:string];
	range.location = 0;
	range.length = [string length];
	
	[attributedString addAttribute:NSForegroundColorAttributeName value:[self textColor] range:range];
	[attributedString addAttribute:NSFontAttributeName value:[self font] range:range];
		
	if(url)
		[attributedString addURLAttributes];
	
	if(chat)
		[attributedString addChatAttributes];
	
	[[self textStorage] appendAttributedString:attributedString];
	
	[attributedString release];
}



- (void)insertString:(NSString *)string atIndex:(unsigned int)index withURL:(BOOL)url withChat:(BOOL)chat {
	NSMutableAttributedString   *attributedString;
	NSRange						range;
	
	attributedString = [[NSMutableAttributedString alloc] initWithString:string];
	range.location = 0;
	range.length = [string length];
	
	[attributedString addAttribute:NSForegroundColorAttributeName value:[self textColor] range:range];
	[attributedString addAttribute:NSFontAttributeName value:[self font] range:range];
	
	if(url)
		[attributedString addURLAttributes];
	
	if(chat)
		[attributedString addChatAttributes];
	
	[[self textStorage] insertAttributedString:attributedString atIndex:index];
	
	[attributedString release];
}

@end