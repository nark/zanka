/* $Id$ */

/*
 *  Copyright (c) 2007 Axel Andersson
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

#import "FHFile.h"
#import "FHSpread.h"

@implementation FHSpread

+ (id)spreadWithLeftFile:(FHFile *)leftFile rightFile:(FHFile *)rightFile {
	return [[[self alloc] initWithLeftFile:leftFile rightFile:rightFile] autorelease];
}



- (id)initWithLeftFile:(FHFile *)leftFile rightFile:(FHFile *)rightFile {
	self = [super init];
	
	_leftFile = [leftFile retain];
	_rightFile = [rightFile retain];

	return self;
}



- (void)dealloc {
	[_leftFile release];
	[_rightFile release];
	
	[super dealloc];
}



#pragma mark -

- (NSString *)name {
	if(_leftFile && _rightFile) {
		return [NSSWF:NSLS(@"%@ & %@", @"'image1.jpg' & 'image2.jpg'"),
			[_leftFile name], [_rightFile name]];
	}
	else if(_leftFile) {
		return [_leftFile name];
	}
	else if(_rightFile) {
		return [_rightFile name];
	}
	
	return NULL;
}



- (FHFile *)leftFile {
	return _leftFile;
}



- (FHFile *)rightFile {
	return _rightFile;
}

@end
