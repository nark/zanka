/* $Id: Controller.h,v 1.5 2003/04/04 16:49:55 morris Exp $ */

/*
 * Copyright © 2000-2003 Axel Andersson
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

@class Tutor, Session;

@interface Controller : NSObject {
	IBOutlet Session				*sessionOutlet;
	
	IBOutlet NSWindow				*windowTutor;
	IBOutlet NSWindow				*windowLines;
		
	IBOutlet NSMenu					*menuSettings;
	
	IBOutlet NSMatrix				*buttonsKana;
	IBOutlet NSTextField			*fieldKana;
	IBOutlet NSImageView			*imageKana;
	IBOutlet NSTextField			*textAnswer;
	IBOutlet NSTextField			*textCorrect;
	IBOutlet NSTextField			*textPercent;
	IBOutlet NSTextField			*textScore;

	IBOutlet NSMenuItem				*itemQuizMode;
	IBOutlet NSMenuItem				*itemLearningMode;
	IBOutlet NSMenuItem				*itemHiragana;
	IBOutlet NSMenuItem				*itemKatakana;
	IBOutlet NSMenuItem				*itemMixed;
	IBOutlet NSMenuItem				*itemHepburn;
	IBOutlet NSMenuItem				*itemKunreiSiki;
	IBOutlet NSMenuItem				*itemNihonSiki;

	IBOutlet NSButtonCell			*kanaDi;
	IBOutlet NSButtonCell			*kanaDu;
	IBOutlet NSButtonCell			*kanaHu;
	IBOutlet NSButtonCell			*kanaSi;
    IBOutlet NSButtonCell			*kanaTi;
    IBOutlet NSButtonCell			*kanaTu;
    IBOutlet NSButtonCell			*kanaZi;

	IBOutlet NSButton				*linesA;
    IBOutlet NSButton				*linesBa;
    IBOutlet NSButton				*linesDa;
    IBOutlet NSButton				*linesGa;
    IBOutlet NSButton				*linesHa;
    IBOutlet NSButton				*linesKa;
    IBOutlet NSButton				*linesMa;
    IBOutlet NSButton				*linesNa;
    IBOutlet NSButton				*linesPa;
    IBOutlet NSButton				*linesRa;
    IBOutlet NSButton				*linesSa;
    IBOutlet NSButton				*linesTa;
    IBOutlet NSButton				*linesWa;
	IBOutlet NSButton				*linesYa;
    IBOutlet NSButton				*linesZa;
	
	Tutor							*_tutor;
	NSTimer							*_timer;
	
	int								_startTime, _stopTime, _diffTime;
	bool							_waitingForUser;
}


- (void)							openTutor;
- (void)							resetTutor;
- (void)							sessionShouldFinish;

- (IBAction)						clickKana:(NSMatrix *)sender;
- (IBAction)						writeKana:(NSButton *)sender;
- (void)							userWasCorrect:(NSString *)kana;
- (void)							userWasIncorrect:(NSString *)kana;

- (IBAction)						openLines:(id)sender;
- (IBAction)						linesOK:(NSButton *)sender;
- (IBAction)						linesSelectAll:(NSButton *)sender;

- (void)							start;
- (void)							startNewQuiz;
- (void)							startNewLearning;

- (void)							updateSettings;
- (void)							updateScore;
- (void)							updateButtonTitles;
- (void)							updateButtons;

- (void)							setImageByKanaName:(NSString *)kanaName;
- (void)							userConfirmed;

- (IBAction)						changeMode:(id)sender;
- (IBAction)						changeKanaType:(id)sender;
- (IBAction)						changeRomanisationSystem:(id)sender;

- (int)								getQuestions;
- (int)								getCorrect;
- (int)								getTime;

@end
