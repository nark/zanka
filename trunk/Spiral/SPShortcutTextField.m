/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

#import "SPShortcutTextField.h"
#import "SPShortcutTextView.h"

@interface SPShortcutTextField(Private)

+ (NSString *)_stringForModifierFlags:(NSUInteger)modifierFlags;
+ (NSString *)_stringForKeyCode:(unsigned short)keyCode;

- (void)_initShortcutTextField;

@end


@implementation SPShortcutTextField(Private)

+ (NSString *)_stringForModifierFlags:(NSUInteger)modifierFlags {
	NSMutableString		*string;
	
	string = [NSMutableString string];
	
	if(modifierFlags & NSControlKeyMask)
		[string appendFormat:@"%C", 0x2303];

	if(modifierFlags & NSAlternateKeyMask)
		[string appendFormat:@"%C", 0x2325];
	
	if(modifierFlags & NSShiftKeyMask)
		[string appendFormat:@"%C", 0x21E7];

	if(modifierFlags & NSCommandKeyMask)
		[string appendFormat:@"%C", 0x2318];

	return string;
}



+ (NSString *)_stringForKeyCode:(unsigned short)keyCode {
	static NSDictionary		*unmappedKeys;
	static UInt32			deadKeyState;
	NSString				*string;
	TISInputSourceRef		inputSource;
	UCKeyboardLayout		*keyboardLayout;
	UniChar					unicodeString[4];
	UniCharCount			length;
	
	if(!unmappedKeys) {
		unmappedKeys = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSString stringWithFormat:@"%C", 0x21A9],	[NSNumber numberWithUnsignedShort:36],
			[NSString stringWithFormat:@"%C", 0x21E5],	[NSNumber numberWithUnsignedShort:48],
			@"Space",									[NSNumber numberWithUnsignedShort:49],
			[NSString stringWithFormat:@"%C", 0x232B],	[NSNumber numberWithUnsignedShort:51],
			[NSString stringWithFormat:@"%C", 0x238B],	[NSNumber numberWithUnsignedShort:53],
			[NSString stringWithFormat:@"%C", 0x2327],	[NSNumber numberWithUnsignedShort:71],
			[NSString stringWithFormat:@"%C", 0x2324],	[NSNumber numberWithUnsignedShort:76],
			@"F5",										[NSNumber numberWithUnsignedShort:96],
			@"F6",										[NSNumber numberWithUnsignedShort:97],
			@"F7",										[NSNumber numberWithUnsignedShort:98],
			@"F3",										[NSNumber numberWithUnsignedShort:99],
			@"F8",										[NSNumber numberWithUnsignedShort:100],
			@"F9",										[NSNumber numberWithUnsignedShort:101],
			@"F11",										[NSNumber numberWithUnsignedShort:103],
			@"F13",										[NSNumber numberWithUnsignedShort:105],
			@"F14",										[NSNumber numberWithUnsignedShort:107],
			@"F10",										[NSNumber numberWithUnsignedShort:109],
			@"F12",										[NSNumber numberWithUnsignedShort:111],
			@"F15",										[NSNumber numberWithUnsignedShort:113],
			[NSString stringWithFormat:@"%C", 0x2196],	[NSNumber numberWithUnsignedShort:115],
			[NSString stringWithFormat:@"%C", 0x21DE],	[NSNumber numberWithUnsignedShort:116],
			[NSString stringWithFormat:@"%C", 0x2326],	[NSNumber numberWithUnsignedShort:117],
			@"F4",										[NSNumber numberWithUnsignedShort:118],
			[NSString stringWithFormat:@"%C", 0x2198],	[NSNumber numberWithUnsignedShort:119],
			@"F2",										[NSNumber numberWithUnsignedShort:120],
			[NSString stringWithFormat:@"%C", 0x21DF],	[NSNumber numberWithUnsignedShort:121],
			@"F1",										[NSNumber numberWithUnsignedShort:122],
			[NSString stringWithFormat:@"%C", 0x2190],	[NSNumber numberWithUnsignedShort:123],
			[NSString stringWithFormat:@"%C", 0x2192],	[NSNumber numberWithUnsignedShort:124],
			[NSString stringWithFormat:@"%C", 0x2193],	[NSNumber numberWithUnsignedShort:125],
			[NSString stringWithFormat:@"%C", 0x2191],	[NSNumber numberWithUnsignedShort:126],
			NULL];
	}
	
	string = [unmappedKeys objectForKey:[NSNumber numberWithUnsignedShort:keyCode]];
	
	if(!string) {
		inputSource		= TISCopyCurrentKeyboardLayoutInputSource();
		keyboardLayout	= (UCKeyboardLayout *) CFDataGetBytePtr(TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData));
		
		UCKeyTranslate(keyboardLayout,
					   keyCode,
					   kUCKeyActionDisplay,
					   0,
					   LMGetKbdType(),
					   kUCKeyTranslateNoDeadKeysBit,
					   &deadKeyState,
					   4,
					   &length,
					   unicodeString);
		
		string = [NSString stringWithCharacters:unicodeString length:1];
		
		CFRelease(inputSource);
	}
	
	return string;
}



#pragma mark -

- (void)_initShortcutTextField {
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(controlTextDidChange:)
			   name:NSControlTextDidChangeNotification];
}

@end



@implementation SPShortcutTextField

+ (NSString *)stringForModifierFlags:(NSUInteger)modifierFlags keyCode:(unsigned short)keyCode {
	return [[self _stringForModifierFlags:modifierFlags] stringByAppendingString:[self _stringForKeyCode:keyCode]];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initShortcutTextField];
	
	return self;
}



- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	
	[self _initShortcutTextField];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (void)controlTextDidChange:(NSNotification *)notification {
	if([notification object] == self)
		[[self target] performSelector:[self action] withObject:self];
}

@end
