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

#import "SPQTMovieView.h"

@implementation SPQTMovieView

- (void)setDelegate:(id <SPQTMovieViewDelegate>)aDelegate {
	delegate = aDelegate;
}



- (id <SPQTMovieViewDelegate>)delegate {
	return delegate;
}



#pragma mark -

- (void)scrollWheel:(id)sender {
	if([[self delegate] respondsToSelector:@selector(movieView:didReceiveEvent:)])
		[[self delegate] movieView:self didReceiveEvent:[NSApp currentEvent]];
}



- (void)keyDown:(id)sender {
	if([[self delegate] respondsToSelector:@selector(movieView:didReceiveEvent:)])
		[[self delegate] movieView:self didReceiveEvent:[NSApp currentEvent]];
}



- (void)mouseDown:(id)sender {
	if([[self delegate] respondsToSelector:@selector(movieView:didReceiveEvent:)])
		[[self delegate] movieView:self didReceiveEvent:[NSApp currentEvent]];
}



- (NSMenu *)menuForEvent:(NSEvent *)event {
	if([[self delegate] respondsToSelector:@selector(movieView:menuForEvent:)])
		return [[self delegate] movieView:self menuForEvent:event];
	
	return [super menuForEvent:event];
}

@end
