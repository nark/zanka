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
 
#define kDefaultsSession							@"Session Type"
#define kDefaultsSessionFree							0
#define kDefaultsSessionLimited							1

#define kDefaultsMode								@"Mode"
#define kDefaultsModeQuiz								0
#define kDefaultsModeLearning							1

#define kDefaultsKanaType							@"Kana Type"
#define kDefaultsKanaTypeHiragana						0
#define kDefaultsKanaTypeKatakana						1
#define kDefaultsKanaTypeMixed							2

#define kDefaultsRomanisationSystem					@"Romanisation System"
#define kDefaultsRomanisationSystemHepburn				0
#define kDefaultsRomanisationSystemKunreiSiki			1
#define kDefaultsRomanisationSystemNihonSiki			2

#define kDefaultsLines								@"Lines To Test"
#define kDefaultsLinesEmpty								0x0000
#define kDefaultsLinesA									0x0001
#define kDefaultsLinesKa								0x0002
#define kDefaultsLinesGa								0x0004
#define kDefaultsLinesSa								0x0008
#define kDefaultsLinesZa								0x0010
#define kDefaultsLinesTa								0x0020
#define kDefaultsLinesDa								0x0040
#define kDefaultsLinesNa								0x0080
#define kDefaultsLinesHa								0x0100
#define kDefaultsLinesBa								0x0200
#define kDefaultsLinesPa								0x0400
#define kDefaultsLinesMa								0x0800
#define kDefaultsLinesYa								0x1000
#define kDefaultsLinesRa								0x2000
#define kDefaultsLinesWa								0x4000
#define kDefaultsLinesAll								0x7FFF

#define kDefaultsTutorPosition						@"Tutor Window Position"
#define kDefaultsMouseDownOnIncorrect				@"Await Mouse Click on Incorrect"
#define kDefaultsLockSettings						@"Lock Settings Menu"
#define kDefaultsTimeLimit							@"Time Limit"
#define kDefaultsKanaLimit							@"Kana Limit"


@interface Settings : NSObject {
}


+ (id)						objectForKey:(id)key;
+ (void)					setObject:(id)object forKey:(NSString *)key;

- (NSDictionary *)			getDefaultValues;
- (NSMutableDictionary *)	preferencesFromUserDefaults;

@end
	