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

#import "TNSub.h"

@implementation TNSub

- (id)initWithPackage:(NSString *)package name:(NSString *)name color:(NSColor *)color {
	self = [super init];
	
	_package	= [package retain];
	_name		= [name retain];
	_color		= [color retain];
	
	return self;
}



- (void)dealloc {
	[_package release];
	[_name release];
	[_color release];
	
	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	return [self retain];
}



#pragma mark -

- (BOOL)isEqualToSub:(TNSub *)sub {
	return (self == sub);
}



- (NSString *)description {
	return [NSSWF:@"%@::%@", _package, _name];
}



#pragma mark -

- (NSString *)package {
	return _package;
}



- (NSString *)name {
	return _name;
}



- (NSColor *)color {
	return _color;
}

@end
