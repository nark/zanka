/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

#import "FHURLHandler.h"

enum FHFeedFormat {
	FHFeedUnknown = 0,
	FHFeedRSS,
	FHFeedAtom,
};
typedef enum FHFeedFormat			FHFeedFormat;


@interface FHFeedHandler : FHURLHandler {
	CFXMLTreeRef				_feed;
	CFXMLTreeRef				_contentTree;
	
	FHFeedFormat				_format;

	NSMutableDictionary			*_header;
	NSMutableArray				*_items;
}


+ (Class)handlerForURL:(WIURL *)url;

- (id)initHandlerWithURL:(WIURL *)url feed:(CFXMLTreeRef)feed;
- (id)initHandlerWithURL:(WIURL *)url feed:(CFXMLTreeRef)feed format:(FHFeedFormat)format;

- (NSString *)itemDividerKey;
- (NSString *)itemContentKey;
- (CFXMLTreeRef)contentTree;
- (CFXMLTreeRef)treeWithName:(NSString *)name inTree:(CFXMLTreeRef)tree;
- (NSString *)valueOfTree:(CFXMLTreeRef)tree;

@end
