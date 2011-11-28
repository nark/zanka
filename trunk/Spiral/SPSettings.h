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

#define SPPlayMoviesWhenOpened			@"SPPlayMoviesWhenOpened"
#define SPDefaultScaling				@"SPDefaultScaling"
#define SPFastForwardFactor				@"SPFastForwardFactor"
#define SPResumePlayingBehavior			@"SPResumePlayingBehavior"
#define SPPreferredAudioPattern			@"SPPreferredAudioPattern"
#define SPPreferredSubtitlePattern		@"SPPreferredSubtitlePattern"
#define SPCheckForUpdate				@"SPCheckForUpdate"
#define SPSimplifyFilenames				@"SPSimplifyFilenames"

#define SPShortJumpBackwardShortcut		@"SPShortJumpBackwardShortcut"
#define SPShortJumpForwardShortcut		@"SPShortJumpForwardShortcut"
#define SPShortJumpInterval				@"SPShortJumpInterval"
#define SPMediumJumpBackwardShortcut	@"SPMediumJumpBackwardShortcut"
#define SPMediumJumpForwardShortcut		@"SPMediumJumpForwardShortcut"
#define SPMediumJumpInterval			@"SPMediumJumpInterval"
#define SPLongJumpBackwardShortcut		@"SPLongJumpBackwardShortcut"
#define SPLongJumpForwardShortcut		@"SPLongJumpForwardShortcut"
#define SPLongJumpInterval				@"SPLongJumpInterval"
#define SPCycleAudioTrackShortcut		@"SPCycleAudioTrackShortcut"
#define SPCycleSubtitleTrackShortcut	@"SPCycleSubtitleTrackShortcut"
#define SPCycleAspectRatioShortcut		@"SPCycleAspectRatioShortcut"

#define SPPlaylist						@"SPPlaylist"
#define SPPlaylistRepeat				@"SPPlaylistRepeat"
#define SPPlaylistShuffle				@"SPPlaylistShuffle"

#define SPRepresentedFiles				@"SPRepresentedFiles"
#define SPRecentPlaylist				@"SPRecentPlaylist"

#define SPMobileRemoteIdentifier		@"SPMobileRemoteIdentifier"
#define SPMobileRemotePasswords			@"SPMobileRemotePasswords"

#define SPSelectedExportFormat			@"SPSelectedExportFormat"

#define SPOpenFile						@"SPOpenFile"

#define SPShowInspector					@"SPShowInspector"
#define SPShowPlaylist					@"SPShowPlaylist"

@interface SPSettings : WISettings

@end
