/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

@class SPPlaylistFile, SPPlaylistFolder, SPPlaylistContainer, SPPlaylistSmartGroup, SPPlaylistRepresentedFile;

@protocol SPPlaylistLoaderDelegate;

@interface SPPlaylistLoader : WIObject {
	id <SPPlaylistLoaderDelegate>		delegate;
	
	BOOL								_delegatePlaylistLoaderIsProcessingWithStatus;
	BOOL								_delegatePlaylistLoaderDidLoadFile;
	BOOL								_delegatePlaylistLoaderDidLoadContentsOfFolder;
	BOOL								_delegatePlaylistLoaderDidLoadMovieDataOfFile;
	BOOL								_delegatePlaylistLoaderDidLoadMovieDataOfItemsInContainer;
	BOOL								_delegatePlaylistLoaderDidLoadMetadataOfFile;
	BOOL								_delegatePlaylistLoaderDidLoadMetadataOfItemsInContainer;
	BOOL								_delegatePlaylistLoaderDidLoadItemsForSmartGroup;
	BOOL								_delegatePlaylistLoaderDidLoadSmartGroup;
}

+ (void)setMovieDataForFile:(SPPlaylistFile *)file movie:(QTMovie *)movie;

- (void)setDelegate:(id <SPPlaylistLoaderDelegate>)delegate;
- (id <SPPlaylistLoaderDelegate>)delegate;

- (void)loadContentsOfFolder:(SPPlaylistFolder *)folder synchronously:(BOOL)synchronously;
- (void)loadMovieDataOfItemsInContainer:(SPPlaylistContainer *)container synchronously:(BOOL)synchronously;
- (void)loadMetadataOfItemsInContainer:(SPPlaylistContainer *)container synchronously:(BOOL)synchronously;
- (void)loadSmartGroup:(SPPlaylistSmartGroup *)smartGroup synchronously:(BOOL)synchronously;

@end


@protocol SPPlaylistLoaderDelegate <NSObject>

@optional

- (void)playlistLoader:(SPPlaylistLoader *)loader isProcessingWithStatus:(NSString *)status;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadFile:(SPPlaylistRepresentedFile *)file;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadContentsOfFolder:(SPPlaylistFolder *)folder;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMovieDataOfFile:(SPPlaylistFile *)file;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMovieDataOfItemsInContainer:(SPPlaylistContainer *)container;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMetadataOfFile:(SPPlaylistFile *)file;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadMetadataOfItemsInContainer:(SPPlaylistContainer *)container;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadItemsForSmartGroup:(SPPlaylistSmartGroup *)smartGroup;
- (void)playlistLoader:(SPPlaylistLoader *)loader didLoadSmartGroup:(SPPlaylistSmartGroup *)smartGroup;

@end
