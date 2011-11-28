/* $Id$ */

/*
 *  Copyright (c) 2007-2009 Axel Andersson
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

#import "SPExportJob.h"
#import "SPMovieController.h"
#import "SPPlaylistController.h"
#import "SPSettings.h"
#import "SPShortcutTextField.h"

@implementation SPSettings

- (NSDictionary *)defaults {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO],
			SPPlayMoviesWhenOpened,
		[NSNumber numberWithBool:YES],
			SPSimplifyFilenames,
		[NSNumber numberWithBool:YES],
			SPCheckForUpdate,
		[NSNumber numberWithInt:SPActualSize],
			SPDefaultScaling,
		[NSNumber numberWithInt:4],
			SPFastForwardFactor,
		[NSNumber numberWithInt:SPAlwaysAsk],
			SPResumePlayingBehavior,
		@"",
			SPPreferredSubtitlePattern,
		@"",
			SPPreferredAudioPattern,
		
		[NSString stringWithFormat:@"%C", 0x2190],
			SPShortJumpBackwardShortcut,
		[NSString stringWithFormat:@"%C", 0x2192],
			SPShortJumpForwardShortcut,
		[NSNumber numberWithInt:10],
			SPShortJumpInterval,
		[NSString stringWithFormat:@"%C", 0x2193],
			SPMediumJumpBackwardShortcut,
		[NSString stringWithFormat:@"%C", 0x2191],
			SPMediumJumpForwardShortcut,
		[NSNumber numberWithInt:60],
			SPMediumJumpInterval,
		[NSString stringWithFormat:@"%C", 0x21DF],
			SPLongJumpBackwardShortcut,
		[NSString stringWithFormat:@"%C", 0x21DE],
			SPLongJumpForwardShortcut,
		[NSNumber numberWithInt:300],
			SPLongJumpInterval,
		@"l",
			SPCycleAudioTrackShortcut,
		@"s",
			SPCycleSubtitleTrackShortcut,
		@"a",
			SPCycleAspectRatioShortcut,
		
		[NSNumber numberWithInt:SPPlaylistRepeatOff],
			SPPlaylistRepeat,
		[NSNumber numberWithBool:NO],
			SPPlaylistShuffle,
		
		[NSNumber numberWithBool:NO],
			SPShowInspector,
		[NSNumber numberWithBool:YES],
			SPShowPlaylist,
			
		@"iPhone",
			SPSelectedExportFormat,
		
		NULL];
}

@end
