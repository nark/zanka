/* $Id: Session.m,v 1.6 2003/04/04 16:55:44 morris Exp $ */

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
 
#import "Session.h"
#import "Settings.h"
#import "Controller.h"

@implementation Session

- (id)init {
	self = [super init];
	
	_settings = [[Settings alloc] init];
	
	return self;
}



- (void)dealloc {
	[_settings release];
	
	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	// --- start with a new session
	[self newSession:self];
}



/*
	Called when the user enters text in the comment box. Prevents more than 255
	characters from passing through.
*/

- (void)textDidChange:(NSNotification *)notification {
	NSString		*string;
	
	string = [viewText string];
	
	if([string length] > 255)
		[viewText setString:[string substringToIndex:255]];
}



#pragma mark-

/*
	Opens a new session window and sets the controls from prefs.
*/

- (IBAction)newSession:(id)sender {
	_done = NO;
	
	// --- set our default session
	switch([[Settings objectForKey:kDefaultsSession] intValue]) {
		case kDefaultsSessionFree:
			// --- disable these in the free mode
			[fieldTime setEnabled:false];
			[fieldKana setEnabled:false];
			
			[stepperTime setEnabled:false];
			[stepperKana setEnabled:false];

			[selectSession selectItemAtIndex:
				[selectSession indexOfItemWithTag:kDefaultsSessionFree]];
			break;
		
		case kDefaultsSessionLimited:
			[selectSession selectItemAtIndex:
				[selectSession indexOfItemWithTag:kDefaultsSessionLimited]];
			break;
	}
	
	// --- set these from prefs
	if([[Settings objectForKey:kDefaultsMouseDownOnIncorrect] boolValue])
		[boxAwait setState:NSOnState];
	if([[Settings objectForKey:kDefaultsLockSettings] boolValue])
		[boxLock setState:NSOnState];
	
	[stepperTime setIntValue:[[Settings objectForKey:kDefaultsTimeLimit] intValue]];
	[self stepTime:stepperTime];
	[stepperKana setIntValue:[[Settings objectForKey:kDefaultsKanaLimit] intValue]];
	[self stepKana:stepperKana];
	
	// --- show the session window
	[windowSession center];
	[windowSession makeKeyAndOrderFront:self];
}



/*
	Starts off a new session.
*/

- (IBAction)start:(id)sender {
	// --- save all settings in prefs
	[Settings setObject:[NSNumber numberWithInt:[[selectSession selectedItem] tag]]
			  forKey:kDefaultsSession];

	[Settings setObject:[NSNumber numberWithBool:[boxAwait state]]
			  forKey:kDefaultsMouseDownOnIncorrect];

	[Settings setObject:[NSNumber numberWithBool:[boxLock state]]
			  forKey:kDefaultsLockSettings];

	[Settings setObject:[NSNumber numberWithInt:[stepperTime intValue]]
			  forKey:kDefaultsTimeLimit];

	[Settings setObject:[NSNumber numberWithInt:[stepperKana intValue]]
			  forKey:kDefaultsKanaLimit];
	
	// --- close the session window
	[windowSession close];
	
	// --- open the tutor and start off whatever we're doing
	[controllerOutlet openTutor];
	[controllerOutlet start];
}



#pragma mark -

/*
	Called when the user switches session type in the popup menu.
*/

- (IBAction)switchType:(id)sender {
	// --- determine selected item and what to do with it
	switch([[sender selectedItem] tag]) {
		case kDefaultsSessionFree:
			[fieldTime setEnabled:false];
			[fieldKana setEnabled:false];
			
			[stepperTime setEnabled:false];
			[stepperKana setEnabled:false];
			break;
		
		case kDefaultsSessionLimited:
			[fieldTime setEnabled:YES];
			[fieldKana setEnabled:YES];
			
			[stepperTime setEnabled:YES];
			[stepperKana setEnabled:YES];

			[fieldTime selectText:self];
			break;
	}
}



/*
	Called when the user has entered a value in the time box, convert it to seconds
	and store in the stepper.
*/

- (IBAction)enterTime:(id)sender {
	NSArray		*values;
	int			minutes, seconds, result;
	
	values		= [[sender stringValue] componentsSeparatedByString:@":"];
	minutes		= [[values objectAtIndex:0] intValue];
	seconds		= [[values objectAtIndex:1] intValue];
	result		= seconds + (minutes * 60);
	
	[stepperTime setIntValue:result];
}



/*
	Called when the user has entered a value in the kana box, store in the stepper.
*/

- (IBAction)enterKana:(id)sender {
	[stepperKana takeIntValueFrom:sender];
}



/*
	Called when the user clicks the time stepper.
*/

- (IBAction)stepTime:(id)sender {
	int		value, minutes, seconds;
	
	value	= [sender intValue];
	minutes	= value / 60;
	seconds	= value - (minutes * 60);
	
	[fieldTime setStringValue:[NSString stringWithFormat:@"%d:%d", minutes, seconds]];
}



/*
	Called when the user clicks the kana stepper.
*/

- (IBAction)stepKana:(id)sender {
	[fieldKana takeIntValueFrom:sender];
}



#pragma mark -

/*
	Show our report card window.
*/

- (void)showReport {
	int			answered, total, missed, correct, incorrect;
	int			time, minutes, seconds;
	float		percent;
	
	// --- get the result values
	answered	= [controllerOutlet getQuestions];
	total		= [[Settings objectForKey:kDefaultsKanaLimit] intValue];
	missed		= total - answered;
	
	if(missed < 0)
		missed	= 0;
	
	correct		= [controllerOutlet getCorrect];
	incorrect	= answered - correct;

	if(total == 0)
		percent	= 0;
	else
		percent	= ((float) correct / (float) total) * 100;
	
	time		= [controllerOutlet getTime];
	minutes		= time / 60;
	seconds		= time - (minutes * 60);

	// --- set the result values
	[reportAnswered setIntValue:answered];
	[reportMissed setIntValue:missed];
	[reportCorrect setIntValue:correct];
	[reportIncorrect setIntValue:incorrect];
	[reportPercent setStringValue:[NSString stringWithFormat:@"%.1f%%", percent]];
	[reportTime setStringValue:[NSString stringWithFormat:@"%d:%d", minutes, seconds]];

	// --- show the window
	[windowReport center];
	[windowReport makeKeyAndOrderFront:self];
}




/*
	Called when the user clicks Print or selects Print from the File menu. Prints
	our special content view.
*/

- (IBAction)print:(id)sender {
	if([windowReport isKeyWindow])
		[viewPrint print:self];
	else
		[[NSApp keyWindow] print:self];
}



#pragma mark -

/*
	Return whether the session has finished or not.
*/

- (BOOL)isDone {
	return _done;
}



/*
	Mark the session as finished.
*/

- (void)done {
	_done = YES;
}

@end
