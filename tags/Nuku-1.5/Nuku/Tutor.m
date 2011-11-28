/*
 * Copyright © 2000-2002 Axel Andersson
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
	hiraganaImages	= [self loadImageSet:kPathHiraganaImages];
	katakanaImages	= [self loadImageSet:kPathKatakanaImages];
	
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
	bundle				= [NSBundle bundleForClass:[self class]];

	// --- load all images
	filePaths			= [bundle pathsForResourcesOfType:@"gif" inDirectory:which];
	images				= [[NSMutableDictionary alloc] initWithCapacity:[filePaths count]];
	enumerator			= [filePaths objectEnumerator];
	
	// --- hiragana images
	while(filePath = [enumerator nextObject]) {
		fileName = [filePath stringByDeletingPathExtension];
		fileName = [fileName lastPathComponent];

		[images
			setObject:[[NSImage alloc] initWithContentsOfFile:filePath]
			forKey:fileName];
	}
	
	return images;
}



/*
	Load all our romanisation systems.
*/

- (void)loadKanaNames {
	NSBundle			*bundle;
	NSString			*dirPath, *filePath;
	
	// --- get our bundle
	bundle				= [NSBundle bundleForClass:[self class]];

	// --- locate the images
	dirPath				= [[bundle resourcePath] stringByAppendingPathComponent:kPathRomanisationSystems];
	
	// --- now load the files
	filePath			= [dirPath stringByAppendingPathComponent:kPathRomanisationSystemsHepburn];
	hepburnStrings		= [[NSDictionary dictionaryWithContentsOfFile:filePath] retain];
	
	filePath			= [dirPath stringByAppendingPathComponent:kPathRomanisationSystemsKunreiSiki];
	kunreiSikiStrings	= [[NSDictionary dictionaryWithContentsOfFile:filePath] retain];
	
	filePath			= [dirPath stringByAppendingPathComponent:kPathRomanisationSystemsNihonSiki];
	nihonSikiStrings	= [[NSDictionary dictionaryWithContentsOfFile:filePath] retain];
}



#pragma mark -

/*
	Switch the internal set of kana names and reduce it according to our lines mask.
*/

- (void)switchRomanisationStrings:(int)to {
	if(currentStrings)
		[currentStrings release];
	
	switch(to) {
		case kDefaultsRomanisationSystemHepburn:
			currentStrings = [[NSMutableDictionary dictionaryWithDictionary:hepburnStrings] retain];
			break;
		
		case kDefaultsRomanisationSystemKunreiSiki:
			currentStrings = [[NSMutableDictionary dictionaryWithDictionary:kunreiSikiStrings] retain];
			break;
		
		case kDefaultsRomanisationSystemNihonSiki:
			currentStrings = [[NSMutableDictionary dictionaryWithDictionary:nihonSikiStrings] retain];
			break;
	}
}



/*
	
*/

- (void)reduceRomanisationStrings:(NSString *)which {
	if([which length] > 0)
		[currentStrings removeObjectForKey:which];
}



#pragma mark -

/*
	Return the name of the kana currently displayed.
*/

- (NSString *)getCurrentKanaName {
	return currentKana;
}



/*
	Set the name of the kana currently displayed.
*/

- (void)setCurrentKanaName:(NSString *)kanaName {
	currentKana = kanaName;
}



#pragma mark -

/*
	Return the correctly transliterated kana name for the internal
	kana name provided.
*/

- (NSString *)getExpandedKanaName:(NSString *)fromKana {
	return [currentStrings objectForKey:fromKana];
}



/*
	Return a random kana name from our pool.
*/

- (NSString *)getRandomKanaName {
	NSArray		*keys;
	NSString	*kana;
	int			rand;
	bool		found = false;

	keys		= [currentStrings allKeys];
	
	do {
		rand	= random() % [keys count];
		kana	= [keys objectAtIndex:rand];
		
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
			return [hiraganaImages objectForKey:kanaName];
		
		case kDefaultsKanaTypeKatakana:
			return [katakanaImages objectForKey:kanaName];
		
		case kDefaultsKanaTypeMixed:
			if(random() % 2 == 0)
				return [hiraganaImages objectForKey:kanaName];
			else
				return [katakanaImages objectForKey:kanaName];
	}
	
	return NULL;
}



#pragma mark -

/*
	Set the number of correct guesses the user has made.
*/

- (void)setCorrect:(int)value {
	correct	= value;
}



/*
	Get the number of correct guesses the user has made.
*/

- (int)getCorrect {
	return correct;
}



#pragma mark -

/*
	Set the number of questions we've asked the user.
*/

- (void)setQuestions:(int)value {
	questions = value;
}



/*
	Get the number of questions we've asked the user.
*/

- (int)getQuestions {
	return questions;
}


@end
