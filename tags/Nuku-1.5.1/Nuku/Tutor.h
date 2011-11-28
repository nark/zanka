/* $Id: Tutor.h,v 1.5 2003/04/04 16:49:55 morris Exp $ */

/*
 * Copyright � 2000-2003 Axel Andersson
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
 
#import <Cocoa/Cocoa.h>

#define kPathHiraganaImages							@"Hiragana"
#define kPathKatakanaImages							@"Katakana"

#define kPathRomanisationSystemsHepburn				@"Hepburn.plist"
#define kPathRomanisationSystemsKunreiSiki			@"KunreiSiki.plist"
#define kPathRomanisationSystemsNihonSiki			@"NihonSiki.plist"


@interface Tutor : NSObject {
	NSString					*_currentKana;
	
	NSMutableDictionary			*_hiraganaImages;
	NSMutableDictionary			*_katakanaImages;
	
	NSMutableDictionary			*_currentStrings;
	NSDictionary				*_hepburnStrings;
	NSDictionary				*_kunreiSikiStrings;
	NSDictionary				*_nihonSikiStrings;
	
	int							_correct;
	int							_questions;
}


- (NSMutableDictionary *)		loadImageSet:(NSString *)which;
- (void)						loadKanaNames;

- (void)						switchRomanisationStrings:(int)to;
- (void)						reduceRomanisationStrings:(NSString *)which;

- (NSString *)					getExpandedKanaName:(NSString*)fromKana;

- (NSString *)					getCurrentKanaName;
- (void)						setCurrentKanaName:(NSString *)kanaName;
	
- (NSString *)					getRandomKanaName;
- (NSImage *)					getKanaImageByName:(NSString *)kanaName;

- (void)						setCorrect:(int)value;
- (int)							getCorrect;
	
- (void)						setQuestions:(int)value;
- (int)							getQuestions;

@end
