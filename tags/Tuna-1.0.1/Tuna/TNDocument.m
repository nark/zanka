/* $Id$ */

/*
 *  Copyright (c) 2005 Axel Andersson
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

#import "TNDocument.h"
#import "TNParser.h"
#import "TNSessionController.h"
#import "TNTree.h"

@implementation TNDocument

+ (unsigned int)session {
	static unsigned int		session;
	
	return ++session;
}



#pragma mark -

- (void)dealloc {
	[_string release];
	[_tree release];

	[super dealloc];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(saveDocument:))
		return ([self fileName] == NULL);
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (void)makeWindowControllers {
	TNSessionController		*controller;
	
	controller = [[TNSessionController alloc] initWithTree:_tree];
	[self addWindowController:controller];
	[controller release];
}



- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)type {
	_string = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	
	if(!_string)
		return NO;
	
	if(![_string hasPrefix:@"#fOrTyTwO"])
		return NO;
	
	_tree = [TNParser parseWithString:_string];
	
	if(_tree)
		_session = [[self class] session];
	
	return (_tree != NULL);
}



- (NSData *)dataRepresentationOfType:(NSString *)type {
	return [_string dataUsingEncoding:NSISOLatin1StringEncoding];
}



- (NSString *)displayName {
	if([self fileName])
		return [super displayName];
	
	return [NSSWF:@"%@ %u", NSLS(@"Session", @"Window title"), _session];
}

@end
