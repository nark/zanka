/* $Id: Tutor.m,v 1.6 2003/04/04 16:55:44 morris Exp $ */

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
 
#import "Tutor.h"
#import "Settings.h"

@implementation Tutor

/*
	Our init method.
*/

- (id)init {
	self = [super init];
		
	// --- load all our images
	_hiraganaImages = [self loadImageSet:kPathHiraganaImages];
	_katakanaImages = [self loadImageSet:kPathKatakanaImages];
	
	// --- load our kana names
	[self loadKanaNames];

	// --- seed the random number generator, or we'll have the same sequence
	//     of kana every run
	srandom(time(NULL));
	
	return self;
}



#pragma mark -

/*
	Load a complete image set located at the path "which".
*/

- (NSDictionary *)loadImageSet:(NSString *)which {
	NSBundle				*bundle;
	NSArray					*filePaths;
	NSString				*fileName, *filePath;
	NSEnumerator			*enumerator;
	NSMutableDictionary		*images;
	
	// --- get our bundle
	bundle		= [NSBundle bundleForClass:[self class]];

	// --- load all images
	filePaths	= [[NSBundle mainBundle] pathsForResourcesOfType:@"gif" inDirectory:which];
	images		= [[NSMutableDictionary alloc] initWithCapacity:[filePaths count]];
	enumerator	= [filePaths objectEnumerator];
	
	// --- hiragana images
	while(filePath = [enumerator nextObject]) {
		fileName = [filePath stringByDeletingPathExtension];
		fileName = [fileName lastPathComponent];

		[images setObject:[[NSImage alloc] initWithContentsOfFile:filePath]
				forKey:fileName];
	}
	
	return images;
}



/*
	Load all our romanisation systems.
*/

- (void)loadKanaNames {
	NSBundle			*bundle;
	NSString			*path;
	
	// --- get our bundle
	bundle				= [NSBundle bundleForClass:[self class]];

	// --- now load the files
	path				= [[bundle resourcePath] stringByAppendingPathComponent:kPathRomanisationSystemsHepburn];
	_hepburnStrings		= [[NSDictionary dictionaryWithContentsOfFile:path] retain];
	
	path				= [[bundle resourcePath] stringByAppendingPathComponent:kPathRomanisationSystemsKunreiSiki];
	_kunreiSikiStrings	= [[NSDictionary dictionaryWithContentsOfFile:path] retain];
	
	path				= [[bundle resourcePath] stringByAppendingPathComponent:kPathRomanisationSystemsNihonSiki];
	_nihonSikiStrings	= [[NSDictionary dictionaryWithContentsOfFile:path] retain];
}



#pragma mark -

/*
	Switch the internal set of kana names.
*/

- (void)switchRomanisationStrings:(int)to {
	if(_currentStrings)
		[_currentStrings release];
	
	switch(to) {
		case kDefaultsRomanisationSystemHepburn:
			_currentStrings = [[NSMutableDictionary dictionaryWithDictionary:_hepburnStrings] retain];
			break;
		
		case kDefaultsRomanisationSystemKunreiSiki:
			_currentStrings = [[NSMutableDictionary dictionaryWithDictionary:_kunreiSikiStrings] retain];
			break;
		
		case kDefaultsRomanisationSystemNihonSiki:
			_currentStrings = [[NSMutableDictionary dictionaryWithDictionary:_nihonSikiStrings] retain];
			break;
	}
}



/*
	Remove the string from the set of kana strings.
*/

- (void)reduceRomanisationStrings:(NSString *)which {
	if([which length] > 0)
		[_currentStrings removeObjectForKey:which];
}



#pragma mark -

/*
	Return the name of the kana currently displayed.
*/

- (NSString *)getCurrentKanaName {
	return _currentKana;
}



/*
	Set the name of the kana currently displayed.
*/

- (void)setCurrentKanaName:(NSString *)kanaName {
	_currentKana = kanaName;
}



#pragma mark -

/*
	Return the correctly transliterated kana name for the internal
	kana name provided.
*/

- (NSString *)getExpandedKanaName:(NSString *)fromKana {
	return [_currentStrings objectForKey:fromKana];
}



/*
	Return a random kana name from our pool.
*/

- (NSString *)getRandomKanaName {
	NSArray		*keys;
	NSString	*kana;
	int			count;
	BOOL		found = NO;

	keys = [_currentStrings allKeys];
	count = [keys count];
	
	do {
		kana = [keys objectAtIndex:random() % count];
		
		// --- always force a new kana
		if(![kana isEqualToString:[self getCurrentKanaName]])
			found = YES;
	} while(!found);
	
	return kana;
}



/*
	Return an image for the kana name provided.
*/

- (NSImage *)getKanaImageByName:(NSString *)kanaName {
	switch([[Settings objectForKey:kDefaultsKanaType] intValue]) {
		case kDefaultsKanaTypeHiragana:
			return [_hiraganaImages objectForKey:kanaName];
			break;
		
		case kDefaultsKanaTypeKatakana:
			return [_katakanaImages objectForKey:kanaName];
			break;
		
		case kDefaultsKanaTypeMixed:
			if(random() % 2 == 0)
				return [_hiraganaImages objectForKey:kanaName];
			else
				return [_katakanaImages objectForKey:kanaName];
			break;
	}
	
	return NULL;
}



#pragma mark -

/*
	Set the number of correct guesses the user has made.
*/

- (void)setCorrect:(int)value {
	_correct	= value;
}



/*
	Get the number of correct guesses the user has made.
*/

- (int)getCorrect {
	return _correct;
}



#pragma mark -

/*
	Set the number of questions we've asked the user.
*/

- (void)setQuestions:(int)value {
	_questions = value;
}



/*
	Get the number of questions we've asked the user.
*/

- (int)getQuestions {
	return _questions;
}


@end