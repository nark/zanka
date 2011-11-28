/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

#import "FHFeedHandler.h"
#import "FHFlickrHandler.h"
#import "FHFile.h"
#import "FHHTMLParser.h"

enum FHFeedParseMode {
	FHFeedParseHeader,
	FHFeedParseItems,
};
typedef enum FHFeedParseMode		FHFeedParseMode;


@interface FHFeedHandler(Private)

- (void)_parse;
- (void)_parseImageHeaderInTree:(CFXMLTreeRef)imageTree;

@end


@implementation FHFeedHandler(Private)

- (void)_parse {
	NSMutableDictionary		*items;
	NSString				*dividerKey, *name, *itemName;
	CFXMLTreeRef			contentTree, tree, itemTree;
	CFXMLNodeRef			node, itemNode;
	FHFeedParseMode			mode;
	NSUInteger				i, count, j, itemCount;
	
	contentTree = [self contentTree];
	dividerKey = [self itemDividerKey];
	count = CFTreeGetChildCount(contentTree);
	mode = FHFeedParseHeader;

	_header = [[NSMutableDictionary alloc] initWithCapacity:10];
	_items = [[NSMutableArray alloc] initWithCapacity:count];

	for(i = 0; i < count; i++) {
		tree = CFTreeGetChildAtIndex(contentTree, i);
		node = CFXMLTreeGetNode(tree);
		name = (NSString *) CFXMLNodeGetString(node);
		
		if([name isEqualToString:dividerKey])
			mode = FHFeedParseItems;
		
		if(mode == FHFeedParseHeader) {
			if([name isEqualTo:@"image"])
				[self _parseImageHeaderInTree:tree];
			
			[_header setObject:[self valueOfTree:tree] forKey:name];
		}
		else if(mode == FHFeedParseItems) {
			itemCount = CFTreeGetChildCount(tree);
			items = [[NSMutableDictionary alloc] initWithCapacity:itemCount];
			
			for(j = 0; j < itemCount; j++) {
				itemTree = CFTreeGetChildAtIndex(tree, j);
				itemNode = CFXMLTreeGetNode(itemTree);
				itemName = (NSString *) CFXMLNodeGetString(itemNode);
				
				[items setObject:[self valueOfTree:itemTree] forKey:itemName];
			}
			
			[_items addObject:items];
			[items release];
		}
	}
}



- (void)_parseImageHeaderInTree:(CFXMLTreeRef)imageTree {
	NSString		*name;
	CFXMLTreeRef	tree;
	CFXMLNodeRef	node;
	NSUInteger		i, count;
	
	count = CFTreeGetChildCount(imageTree);
		
	for(i = 0; i < count; i++) {
		tree = CFTreeGetChildAtIndex(imageTree, i);
		node = CFXMLTreeGetNode(tree);
		name = (NSString *) CFXMLNodeGetString(node);
		
		[_header setObject:[self valueOfTree:tree] forKey:[@"image" stringByAppendingString:name]];
	}
}

@end


@implementation FHFeedHandler

+ (Class)handlerForURL:(WIURL *)url {
	NSString	*host;
	
	host = [url host];
	
	if([host hasSuffix:@"flickr.com"])
		return [FHFlickrHandler class];
	
	return self;
}



#pragma mark -

- (id)initHandlerWithURL:(WIURL *)url feed:(CFXMLTreeRef)feed {
	CFXMLNodeRef	node;
	NSString		*name;
	FHFeedFormat	format;
	
	format = FHFeedUnknown;
	
	if(CFTreeGetChildCount(feed) >= 2) {
		node = CFXMLTreeGetNode(CFTreeGetChildAtIndex(feed, 1));
		name = (NSString *) CFXMLNodeGetString(node);
	
		if([name isEqualToString:@"rss"])
			format = FHFeedRSS;
		else if([name isEqualToString:@"feed"])
			format = FHFeedAtom;
	}

	return [self initHandlerWithURL:url feed:feed format:format];
}



- (id)initHandlerWithURL:(WIURL *)url feed:(CFXMLTreeRef)feed format:(FHFeedFormat)format {
	CFXMLTreeRef	rssTree;
	
	self = [super initHandlerWithURL:url];
	
	_feed = (CFXMLTreeRef) CFRetain(feed);
	_format = format;

	if(_format == FHFeedRSS) {
		rssTree = [self treeWithName:@"rss" inTree:_feed];
		
		if(!rssTree)
			rssTree = [self treeWithName:@"rdf:RDF" inTree:_feed];
		
		if(!rssTree) {
			[self release];
			
			return NULL;
		}
		
		_contentTree = [self treeWithName:@"channel" inTree:rssTree];
		
		if(!_contentTree)
			_contentTree = [self treeWithName:@"rss:channel" inTree:rssTree];
		
		if(!_contentTree) {
			[self release];
			
			return NULL;
		}
	}
	
	[self _parse];
		
	return self;
}



- (void)dealloc {
	CFRelease(_feed);
	
	[super dealloc];
}



#pragma mark -

- (NSString *)itemDividerKey {
	switch(_format) {
		case FHFeedUnknown:
			return NULL;
			break;

		case FHFeedRSS:
			return @"item";
			break;

		case FHFeedAtom:
			return @"entry";
			break;
	}
	
	return NULL;
}



- (NSString *)itemContentKey {
	switch(_format) {
		case FHFeedUnknown:
			return NULL;
			break;

		case FHFeedRSS:
			return @"description";
			break;

		case FHFeedAtom:
			return @"content";
			break;
	}
	
	return NULL;
}



- (CFXMLTreeRef)contentTree {
	return _contentTree;
}



- (CFXMLTreeRef)treeWithName:(NSString *)name inTree:(CFXMLTreeRef)tree {
	NSString		*itemName;
	CFXMLTreeRef	itemTree;
	CFXMLNodeRef	node;
	NSUInteger		i, count;
	
	count = CFTreeGetChildCount(tree);
	
	for(i = 0; i < count; i++) {
		itemTree	= CFTreeGetChildAtIndex(tree, i);
		node		= CFXMLTreeGetNode(itemTree);
		itemName	= (NSString *) CFXMLNodeGetString(node);
		
		if([itemName isEqualToString:name])
			return itemTree;
	}
	
	return NULL;
}



- (NSString *)valueOfTree:(CFXMLTreeRef)tree {
	NSMutableString		*value;
	NSString			*name;
	CFXMLNodeRef		node;
	NSUInteger			i, count;
	
	value = [NSMutableString string];
	count = CFTreeGetChildCount(tree);
	
	for(i = 0; i < count; i++) {
		node = CFXMLTreeGetNode(CFTreeGetChildAtIndex(tree, i));
		name = (NSString *) CFXMLNodeGetString(node);
		
		if(name) {
			if(CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeEntityReference) {
				if([name isEqualToString:@"lt"])
					name = @"<";
				else if([name isEqualToString:@"gt"])
					name = @">";
				else if([name isEqualToString:@"quot"])
					name = @"\"";
				else if([name isEqualToString:@"amp"])
					name = @"&";
			}
						
			[value appendString:name];
		}
	}
	
	return value;
}



#pragma mark -

- (NSArray *)files {
	NSDictionary	*item;
	NSArray			*links;
	NSString		*content;
	NSUInteger		i, count, j, linkCount;
	
	if(!_files) {
		count = [_items count];
		_files = [[NSMutableArray alloc] initWithCapacity:count];
		
		for(i = 0; i < count; i++) {
			item = [_items objectAtIndex:i];
			content = [item objectForKey:[self itemContentKey]];
			links = [FHHTMLParser imageLinksInHTML:content baseURL:[self URL]];
			
			for(j = 0, linkCount = [links count]; j < linkCount; j++) {
				[_files addObject:[FHFile fileWithURL:[links objectAtIndex:j] isDirectory:NO]];
				
				_numberOfFiles++;
				_numberOfImages++;
			}
		}
	}
	
	return _files;
}



- (BOOL)hasParent {
	return NO;
}



- (NSArray *)stringComponents {
	return [NSArray arrayWithObject:[_header objectForKey:@"title"]];
}



- (NSArray *)URLComponents {
	return [NSArray arrayWithObject:[self URL]];
}

@end
