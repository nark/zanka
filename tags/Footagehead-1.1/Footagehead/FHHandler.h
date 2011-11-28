/* $Id$ */

/*
 *  Copyright © 2003-2004 Axel Andersson
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

@interface FHHandler : NSObject {
	NSMutableArray				*_files;
	NSMutableArray				*_images;
	NSURL						*_url;
	unsigned int				_numberOfImages;
	unsigned int				_hint;
}


#define FHHandlerHintNone		0
#define FHHandlerHintGallery	1


- (id)							initWithURL:(NSURL *)url;
- (id)							initWithURL:(NSURL *)url hint:(int)hint;

+ (void)						_addHandler:(Class)class;
+ (void)						_addHandler:(Class)class withHint:(int)hint;
+ (BOOL)						_isHandlerForURL:(NSURL *)url primary:(BOOL)primary;
+ (BOOL)						_handlesURLAsDirectory:(NSURL *)url;
- (BOOL)						_URLIsDirectory:(NSURL *)url;

- (NSArray *)					files;
- (NSArray *)					images;
- (unsigned int)				numberOfImages;
- (BOOL)						isLocal;
- (unsigned int)				hint;

- (NSURL *)						URL;
- (NSURL *)						parentURL;
- (NSURL *)						relativeURL;
- (NSArray *)					displayURLComponents;
- (NSArray *)					fullURLComponents;

@end
