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

#import "Controller.h"
#import "Settings.h"
#import "Session.h"
#import "Tutor.h"

@implementation Controller

- (id)init {
	self = [super init];
	
	_tutor = [[Tutor alloc] init];
	
	return self;
}


- (void)dealloc {
	[_tutor release];
	
	[super dealloc];
}

	

#pragma mark -

- (void)awakeFromNib {
	// --- update the settings menu from prefs
	[self updateSettings];
}



/*
	Called when the application receives a shutdown notice, i.e. the user quits.
*/

- (void)applicationWillTerminate:(NSNotification *)notification {
	[Settings setObject:[windowTutor stringWithSavedFrame]
			  forKey:kDefaultsTutorPosition];
}



/*
	Called when the tutor window is about to be closed.
*/

- (void)windowWillClose:(NSNotification *)notification {
	[Settings setObject:[windowTutor stringWithSavedFrame]
			  forKey:kDefaultsTutorPosition];

	[self resetTutor];
}



/*
	Called when the user wrote a char to the text field. Prevents more than
	3 characters from passing through.
*/

- (void)controlTextDidChange:(NSNotification *)notification {
	NSString		*string;
	
	string = [fieldKana stringValue];
	
	if([string length] > 3)
		[fieldKana setStringValue:[string substringToIndex:3]];
}



#pragma mark -


/*
	Opens the tutor window and prepares it.
*/

- (void)openTutor {
	NSArray			*menuItems;
	NSEnumerator	*enumerator;
	NSMenuItem		*menuItem;
	NSString		*windowPosition;
	bool			state = YES;
	
	// --- off by default
	_waitingForUser = NO;

	// --- clear all fields
	[textCorrect setStringValue:@""];
	[textAnswer setStringValue:@""];
	[fieldKana setStringValue:@""];
	[self setImageByKanaName:NULL];
	
	// --- lock down the Settings menu if we should
	if([[Settings objectForKey:kDefaultsLockSettings] boolValue])
		state = NO;
	
	[menuSettings setAutoenablesItems:NO];
	menuItems	= [menuSettings itemArray];
	enumerator	= [menuItems objectEnumerator];
	
	while((menuItem = [enumerator nextObject]))
		[menuItem setEnabled:state];
	
	// --- lock quiz/learning if we're in a limited session
	if([[Settings objectForKey:kDefaultsSession] intValue] == kDefaultsSessionLimited) {
		[Settings setObject:[NSNumber numberWithInt:kDefaultsModeQuiz]
				  forKey:kDefaultsMode];

		[itemQuizMode setState:NSOnState];
		[itemLearningMode setState:NSOffState];

		[itemQuizMode setEnabled:NO];
		[itemLearningMode setEnabled:NO];
	}
	
	// --- select our romanisation system
	[_tutor switchRomanisationStrings:[[Settings objectForKey:kDefaultsRomanisationSystem] intValue]];
	
	// --- update the buttons according to the romanisation system
	[self updateButtonTitles];
	
	// --- update the buttons according to our Lines settings
	[self updateButtons];
	
	// --- set these to 0
	[_tutor setCorrect:0];
	[_tutor setQuestions:0];
	[self updateScore];
	
	// --- move to saved position
	windowPosition = [Settings objectForKey:kDefaultsTutorPosition];
	
	if([windowPosition isEqualTo:@""])
		[windowTutor center];
	else
		[windowTutor setFrameFromString:windowPosition];

	// --- show the window
	[windowTutor makeKeyAndOrderFront:self];

	// --- get a timestamp
	_startTime	= time(NULL);
	_stopTime	= 0;

	// --- install a timer that fires when our time is up if we're in a limited session
	if([[Settings objectForKey:kDefaultsSession] intValue] == kDefaultsSessionLimited &&
	   [[Settings objectForKey:kDefaultsTimeLimit] intValue] > 0) {
		_timer = [NSTimer scheduledTimerWithTimeInterval:[[Settings objectForKey:kDefaultsTimeLimit] intValue]
						  target:self
						  selector:@selector(sessionShouldFinish)
						  userInfo:NULL
						  repeats:NO];
	}
}




/*
	Resets the tutor to its original state, possibly for a new session.
*/

- (void)resetTutor {
	NSArray			*menuItems;
	NSEnumerator	*enumerator;
	NSMenuItem		*menuItem;

	// --- re-enable the settings menu
	menuItems		= [menuSettings itemArray];
	enumerator		= [menuItems objectEnumerator];
	
	while((menuItem = [enumerator nextObject]))
		[menuItem setEnabled:YES];

	// --- kill the timer
	if(_timer) {
		[_timer invalidate];
		
		_timer = NULL;
	}
}




- (void)sessionShouldFinish {
	// --- we don't want to do this if we've already finished
	if([sessionOutlet isDone])
		return;
		
	// --- get a timestamp
	_stopTime = time(NULL);
	_diffTime = _stopTime - _startTime;
	
	// --- close this window
	[windowTutor close];
	
	// --- mark as finished
	[sessionOutlet done];

	// --- open the next
	[sessionOutlet showReport];
}



#pragma mark -

/*
	Called when the user clicks a kana button.
*/

- (IBAction)clickKana:(NSMatrix *)sender {
	NSString		*currentKana, *clickedKana, *infoString;
	NSButton		*clickedButton;

	switch([[Settings objectForKey:kDefaultsMode] intValue]) {
		case kDefaultsModeQuiz:
			// --- if we're waiting for the user to click the mouse and she
			//     clicked a button, confirm this as a click
			if(_waitingForUser) {
				[self userConfirmed];
				
				return;
			}

			// --- update number of questions
			[_tutor setQuestions:[_tutor getQuestions] + 1];
			
			// --- get the name of the selected button and the correct name
			clickedButton	= [sender cellAtRow:[sender selectedRow] column:[sender selectedColumn]];
			clickedKana		= [clickedButton title];
			currentKana		= [_tutor getCurrentKanaName];
			[_tutor setCurrentKanaName:currentKana];
			
			if([clickedKana isEqualToString:[_tutor getExpandedKanaName:currentKana]])
				[self userWasCorrect:clickedKana];
			else
				[self userWasIncorrect:clickedKana];

			// --- update the scoreboard
			[self updateScore];
			break;
		
		case kDefaultsModeLearning:
			// --- get the name of the selected button
			clickedButton	= [sender
								cellAtRow:[sender selectedRow]
								column:[sender selectedColumn]];
			currentKana		= [clickedButton alternateTitle];

			// --- set our internal name to it
			[_tutor setCurrentKanaName:currentKana];
			
			// --- display the correct kana image
			[self setImageByKanaName:currentKana];
			
			// --- and display the name of it, as we're in learning mode
			infoString = [NSString stringWithFormat:@"'%@'",
							[_tutor getExpandedKanaName:currentKana]];
			[textCorrect setTextColor:[NSColor blackColor]];
			[textCorrect setStringValue:infoString];
			break;
	}
	
	// --- drop out if we're done
	if([[Settings objectForKey:kDefaultsKanaLimit] intValue] == [_tutor getQuestions]  &&
	   [[Settings objectForKey:kDefaultsSession] intValue] == kDefaultsSessionLimited)
		[self sessionShouldFinish];
}



/*
	Called when the user clicks the OK button.
*/

- (IBAction)writeKana:(NSButton *)sender {
	NSString	*currentKana, *writtenKana, *infoString;
	NSArray		*keys;

	switch([[Settings objectForKey:kDefaultsMode] intValue]) {
		case kDefaultsModeQuiz:
			// --- if we're waiting for the user to click the mouse and she
			//     clicked a button, confirm this as a click
			if(_waitingForUser) {
				[self userConfirmed];
				
				return;
			}

			// --- update number of questions
			[_tutor setQuestions:[_tutor getQuestions] + 1];
			
			// --- get the name of the selected button and the correct name
			writtenKana = [fieldKana stringValue];
			currentKana = [_tutor getCurrentKanaName];
			[_tutor setCurrentKanaName:currentKana];
			
			if([writtenKana isEqualToString:[_tutor getExpandedKanaName:currentKana]])
				[self userWasCorrect:currentKana];
			else
				[self userWasIncorrect:writtenKana];
			
			// --- update the scoreboard
			[self updateScore];
			break;
		
		case kDefaultsModeLearning:
			// --- get the kana
			writtenKana = [fieldKana stringValue];
			keys = [[_tutor getCurrentStrings] allKeysForObject:writtenKana];
			
			if([keys count] > 0) {
				currentKana = [keys objectAtIndex:0];

				// --- set our internal name to it
				[_tutor setCurrentKanaName:currentKana];
				
				// --- display the correct kana image
				[self setImageByKanaName:currentKana];
				
				// --- and display the name of it, as we're in learning mode
				infoString = [NSString stringWithFormat:@"'%@'", writtenKana];
				[textCorrect setTextColor:[NSColor blackColor]];
				[textCorrect setStringValue:infoString];
			}
			break;
	}
	
	// --- drop out if we're done
	if([[Settings objectForKey:kDefaultsKanaLimit] intValue] == [_tutor getQuestions]  &&
	   [[Settings objectForKey:kDefaultsSession] intValue] == kDefaultsSessionLimited)
		[self sessionShouldFinish];
}



/*
	Increase score, tell the user she was correct, and start on a new kana.
*/

- (void)userWasCorrect:(NSString *)kana {
	NSString		*infoString, *currentKana, *outKana;

	// --- display correct message in green - according to testers,
	//     plain greenColor is a tad too light, so we darken it a bit
	outKana = [_tutor getExpandedKanaName:kana];
	infoString = [NSString stringWithFormat:NSLocalizedString(@"'%@' is correct.", @""), outKana];
	[textCorrect setTextColor:[NSColor colorWithDeviceRed:0.05 green:0.9 blue:0.05 alpha:1.0]];
	[textCorrect setStringValue:infoString];
	
	// --- this should say nothing here
	[textAnswer setStringValue:@""];

	[_tutor setCorrect:[_tutor getCorrect] + 1];
	
	// --- get a random kana name and display its image
	currentKana	= [_tutor getRandomKanaName];
	[_tutor setCurrentKanaName:currentKana];
	[self setImageByKanaName:currentKana];
}



/*
	Tell the user she was incorrect, waiting for her to confirm it if we should.
*/

- (void)userWasIncorrect:(NSString *)kana {
	NSString		*infoString, *currentKana, *outKana;
	
	// --- display incorrect message in red
	[textCorrect setTextColor:[NSColor redColor]];
	
	// --- the user may have written something that isn't even a kana name
	outKana = [_tutor getExpandedKanaName:kana];
	if(!outKana)
		outKana = kana;
	
	// --- tell the user what the correct answer should have been
	infoString = [NSString stringWithFormat:NSLocalizedString(@"The correct answer was '%@'.", @""),
					[_tutor getExpandedKanaName:[_tutor getCurrentKanaName]]];
	[textAnswer setStringValue:infoString];

	if([[Settings objectForKey:kDefaultsMouseDownOnIncorrect] boolValue]) {
		// --- wait for the user to confirm her mistake
		infoString = [NSString stringWithFormat:NSLocalizedString(@"'%@' is incorrect. Click to continue.", @""),
						outKana];
		[textCorrect setStringValue:infoString];

		// --- this will get cleared in userDidMouseDown
		_waitingForUser = YES;
	} else {
		// --- just say that it's incorrect and continue
		infoString = [NSString stringWithFormat:NSLocalizedString(@"'%@' is incorrect.", @""), outKana];
		[textCorrect setStringValue:infoString];

		// --- get a random kana name and display its image
		currentKana	= [_tutor getRandomKanaName];
		[_tutor setCurrentKanaName:currentKana];
		[self setImageByKanaName:currentKana];
	}
}



#pragma mark -

/*
	Called when the user selects "Lines To Test" from the Settings menu.
*/

- (IBAction)openLines:(id)sender {
	int			lines;
	
	// --- get our bit field
	lines = [[Settings objectForKey:kDefaultsLines] intValue];

	// --- mark the checkboxes accordingly
	if(lines & kDefaultsLinesA)
		[linesA setState:NSOnState];
	if(lines & kDefaultsLinesBa)
		[linesBa setState:NSOnState];
	if(lines & kDefaultsLinesDa)
		[linesDa setState:NSOnState];
	if(lines & kDefaultsLinesGa)
		[linesGa setState:NSOnState];
	if(lines & kDefaultsLinesHa)
		[linesHa setState:NSOnState];
	if(lines & kDefaultsLinesKa)
		[linesKa setState:NSOnState];
	if(lines & kDefaultsLinesMa)
		[linesMa setState:NSOnState];
	if(lines & kDefaultsLinesNa)
		[linesNa setState:NSOnState];
	if(lines & kDefaultsLinesPa)
		[linesPa setState:NSOnState];
	if(lines & kDefaultsLinesRa)
		[linesRa setState:NSOnState];
	if(lines & kDefaultsLinesSa)
		[linesSa setState:NSOnState];
	if(lines & kDefaultsLinesTa)
		[linesTa setState:NSOnState];
	if(lines & kDefaultsLinesWa)
		[linesWa setState:NSOnState];
	if(lines & kDefaultsLinesYa)
		[linesYa setState:NSOnState];
	if(lines & kDefaultsLinesZa)
		[linesZa setState:NSOnState];
	
	// --- show the window
	[windowLines center];
	[windowLines makeKeyAndOrderFront:self];
}



/*
	Called when the user clicks the OK button in the Lines dialog.
*/

- (IBAction)linesOK:(NSButton *)sender {
	NSString	*currentKana;
	int			lines = kDefaultsLinesEmpty;
	
	// --- update the bit field
	if([linesA state] == NSOnState)
		lines |= kDefaultsLinesA;
	if([linesBa state] == NSOnState)
		lines |= kDefaultsLinesBa;
	if([linesDa state] == NSOnState)
		lines |= kDefaultsLinesDa;
	if([linesGa state] == NSOnState)
		lines |= kDefaultsLinesGa;
	if([linesHa state] == NSOnState)
		lines |= kDefaultsLinesHa;
	if([linesKa state] == NSOnState)
		lines |= kDefaultsLinesKa;
	if([linesMa state] == NSOnState)
		lines |= kDefaultsLinesMa;
	if([linesNa state] == NSOnState)
		lines |= kDefaultsLinesNa;
	if([linesPa state] == NSOnState)
		lines |= kDefaultsLinesPa;
	if([linesRa state] == NSOnState)
		lines |= kDefaultsLinesRa;
	if([linesSa state] == NSOnState)
		lines |= kDefaultsLinesSa;
	if([linesTa state] == NSOnState)
		lines |= kDefaultsLinesTa;
	if([linesWa state] == NSOnState)
		lines |= kDefaultsLinesWa;
	if([linesYa state] == NSOnState)
		lines |= kDefaultsLinesYa;
	if([linesZa state] == NSOnState)
		lines |= kDefaultsLinesZa;
	
	// --- update the settings
	[Settings setObject:[NSNumber numberWithInt:lines] forKey:kDefaultsLines];
	
	// --- re-initiate the currentStrings dict so we can starting
	//     reducing from from a fresh one
	[_tutor switchRomanisationStrings:
		[[Settings objectForKey:kDefaultsRomanisationSystem] intValue]];
	
	// --- update the Tutor window
	[self updateButtons];
	
	if([[Settings objectForKey:kDefaultsMode] intValue] == kDefaultsModeQuiz) {
		// --- we might have an old kana in the well
		currentKana	= [_tutor getRandomKanaName];
		[_tutor setCurrentKanaName:currentKana];
		[self setImageByKanaName:currentKana];
	}
	
	// --- and close
	[windowLines close];
}



/*
	Called when the user click the "Select All" button in the Lines dialog.
*/

- (IBAction)linesSelectAll:(NSButton *)sender {
	[linesA setState:NSOnState];
	[linesBa setState:NSOnState];
	[linesDa setState:NSOnState];
	[linesGa setState:NSOnState];
	[linesHa setState:NSOnState];
	[linesKa setState:NSOnState];
	[linesMa setState:NSOnState];
	[linesNa setState:NSOnState];
	[linesPa setState:NSOnState];
	[linesRa setState:NSOnState];
	[linesSa setState:NSOnState];
	[linesTa setState:NSOnState];
	[linesWa setState:NSOnState];
	[linesYa setState:NSOnState];
	[linesZa setState:NSOnState];
}





#pragma mark -

/*
	Set up a new quiz/learning.
*/

- (void)start {
	// --- go nuku go
	switch([[Settings objectForKey:kDefaultsMode] intValue]) {
		case kDefaultsModeQuiz:
			[self startNewQuiz];
			break;
		
		case kDefaultsModeLearning:
			[self startNewLearning];
			break;
	}
}



/*
	Set up a new quiz, zero out the score table and kick it off.
*/

- (void)startNewQuiz {
	NSString		*currentKana;
	
	[windowTutor setTitle:NSLocalizedString(@"Nuku - Quiz Mode", @"")];

	// --- clear all fields
	[textCorrect setStringValue:@""];
	[textAnswer setStringValue:@""];
	[fieldKana setStringValue:@""];
	
	// --- set these to 0
	[_tutor setCorrect:0];
	[_tutor setQuestions:0];
	
	// --- display the score
	[self updateScore];

	// --- get a random kana and display it, kicking off the quiz
	currentKana = [_tutor getRandomKanaName];
	[_tutor setCurrentKanaName:currentKana];
	[self setImageByKanaName:currentKana];
}



/*
	Prepare for learning mode, clear score and image out.
*/

- (void)startNewLearning {
	[windowTutor setTitle:NSLocalizedString(@"Nuku - Learning Mode", @"")];

	// --- clear all fields
	[textCorrect setStringValue:@""];
	[textAnswer setStringValue:@""];
	[fieldKana setStringValue:@""];
	[self setImageByKanaName:NULL];
	
	// --- set these to 0
	[_tutor setCorrect:0];
	[_tutor setQuestions:0];
	
	// --- display the score
	[self updateScore];
}



#pragma mark -

/*
	Updates the Settings menu from prefs.
*/

- (void)updateSettings {
	// --- set up initial kana type
	switch([[Settings objectForKey:kDefaultsKanaType] intValue]) {
		case kDefaultsKanaTypeHiragana:
			[itemHiragana setState:NSOnState];
			break;
		
		case kDefaultsKanaTypeKatakana:
			[itemKatakana setState:NSOnState];
			break;
		
		case kDefaultsKanaTypeMixed:
			[itemMixed setState:NSOnState];
			break;
	}
	
	// --- set up initial romanisation system
	switch([[Settings objectForKey:kDefaultsRomanisationSystem] intValue]) {
		case kDefaultsRomanisationSystemHepburn:
			[itemHepburn setState:NSOnState];
			break;
		
		case kDefaultsRomanisationSystemKunreiSiki:
			[itemKunreiSiki setState:NSOnState];
			break;
		
		case kDefaultsRomanisationSystemNihonSiki:
			[itemNihonSiki setState:NSOnState];
			break;
	}
	
	// --- set up initial mode
	switch([[Settings objectForKey:kDefaultsMode] intValue]) {
		case kDefaultsModeQuiz:
			[itemQuizMode setState:NSOnState];
			break;
		
		case kDefaultsModeLearning:
			[itemLearningMode setState:NSOnState];
			break;
	}
}



/*
	Update the scoreboard and set the scores accordingly.
*/

- (void)updateScore {
	int				correct, questions;
	float			percent;
	
	correct			= [_tutor getCorrect];
	questions		= [_tutor getQuestions];
	
	if(questions == 0)
		percent		= 0;
	else
		percent		= ((float) correct / (float) questions) * 100;

	[textScore setStringValue:[NSString stringWithFormat:@"%d/%d", correct, questions]];
	[textPercent setFloatValue:percent];
}



/*
	Update the buttons that have different names between the romanisation systems.
*/

- (void)updateButtonTitles {
	[kanaSi setTitle:[_tutor getExpandedKanaName:[kanaSi alternateTitle]]];
	[kanaZi setTitle:[_tutor getExpandedKanaName:[kanaZi alternateTitle]]];
	[kanaTi setTitle:[_tutor getExpandedKanaName:[kanaTi alternateTitle]]];
	[kanaTu setTitle:[_tutor getExpandedKanaName:[kanaTu alternateTitle]]];
	[kanaDi setTitle:[_tutor getExpandedKanaName:[kanaDi alternateTitle]]];
	[kanaDu setTitle:[_tutor getExpandedKanaName:[kanaDu alternateTitle]]];
	[kanaHu setTitle:[_tutor getExpandedKanaName:[kanaHu alternateTitle]]];
}



/*
	Update the buttons according to the Lines settings.
*/

- (void)updateButtons {
	int				i, j, lines;
	NSButton		*button;
	
	// --- get our bit field
	lines			= [[Settings objectForKey:kDefaultsLines] intValue];
	
	for(i = 0; i < 15; i++) {
		for(j = 0; j < 5; j++) {
			button = [buttonsKana cellAtRow:j column:i];
			
			// --- we store the bit mask in the tag of the button
			if(lines & [button tag])
				[button setEnabled: YES];
			else {
				[_tutor reduceRomanisationStrings:[button alternateTitle]];
				[button setEnabled: NO];
			}
		}
	}
}



#pragma mark -

/*
	Set the image well to display the kana provided.
*/

- (void)setImageByKanaName:(NSString *)kanaName {
	[imageKana setImage:[_tutor getKanaImageByName:kanaName]];
}



/*
	Get a new random kana and clear the waitingForUser flag to determine
	that the user has confirmed.
*/

- (void)userConfirmed {
	NSString		*currentKana;
	
	if(_waitingForUser) {
		// --- clear these
		[textCorrect setStringValue:@""];
		[textAnswer setStringValue:@""];
		
		// --- get a random kana name and display its image
		currentKana	= [_tutor getRandomKanaName];
		[_tutor setCurrentKanaName:currentKana];
		[self setImageByKanaName:currentKana];
		
		_waitingForUser = NO;
	}
}



#pragma mark -

/*
	Called when user switches between quiz and learning mode.
*/

- (IBAction)changeMode:(id)sender {
	// --- store value in settings for later retrieval
	[Settings setObject:[NSNumber numberWithInt:[sender tag]]
			  forKey:kDefaultsMode];
	
	// --- turn off everyone, then turn on the sender
	[itemQuizMode setState:NSOffState];
	[itemLearningMode setState:NSOffState];
	[sender setState:NSOnState];

	switch([[Settings objectForKey:kDefaultsMode] intValue]) {
		case kDefaultsModeQuiz:
			[self startNewQuiz];
			break;
		
		case kDefaultsModeLearning:
			[self startNewLearning];
			break;
	}
}



/*
	Called when user changes kana type.
*/

- (IBAction)changeKanaType:(id)sender {
	// --- store value in settings for later retrieval
	[Settings setObject:[NSNumber numberWithInt:[sender tag]]
			  forKey:kDefaultsKanaType];
	
	// --- turn off everyone, then turn on the sender
	[itemHiragana setState:NSOffState];
	[itemKatakana setState:NSOffState];
	[itemMixed setState:NSOffState];
	[sender setState:NSOnState];
	
	// --- update the image
	[self setImageByKanaName:[_tutor getCurrentKanaName]];
}



/*
	Called when user switches romanisation system.
*/

- (IBAction)changeRomanisationSystem:(id)sender {
	NSString		*currentKana, *infoString;
	
	// --- store value in settings for later retrieval
	[Settings setObject:[NSNumber numberWithInt:[sender tag]]
			  forKey:kDefaultsRomanisationSystem];

	// turn off everyone, then turn on the sender
	[itemHepburn setState:NSOffState];
	[itemKunreiSiki setState:NSOffState];
	[itemNihonSiki setState:NSOffState];
	[sender setState:NSOnState];
	
	// --- update the current strings
	[_tutor switchRomanisationStrings:[sender tag]];
	
	// --- update the current display if we're in learning mode
	currentKana = [_tutor getCurrentKanaName];

	if([[Settings objectForKey:kDefaultsMode] intValue] == kDefaultsModeLearning &&
	   currentKana != NULL) {
		// --- 'kana'
		infoString = [NSString stringWithFormat:@"'%@'",
			[_tutor getExpandedKanaName:currentKana]];
		[textCorrect setStringValue:infoString];
	}
	
	// --- update the button titles
	[self updateButtonTitles];
	
	// --- update the buttons
	[self updateButtons];
}



#pragma mark -

/*
	Get the number of questions.
*/

- (int)getQuestions {
	return [_tutor getQuestions];
}



/*
	Get the number of corrects.
*/

- (int)getCorrect {
	return [_tutor getCorrect];
}



/*
	Get the elapsed time.
*/

- (int)getTime {
	return _diffTime;
}


@end
