/* $Id$ */

/*
 * Copyright (c) 2000-2006 Axel Andersson
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
- (NSDictionary *)				getCurrentStrings;
- (NSString *)					getCurrentKanaName;
- (void)						setCurrentKanaName:(NSString *)kanaName;
	
- (NSString *)					getRandomKanaName;
- (NSImage *)					getKanaImageByName:(NSString *)kanaName;

- (void)						setCorrect:(int)value;
- (int)							getCorrect;
	
- (void)						setQuestions:(int)value;
- (int)							getQuestions;

@end
