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

@class TNSub;

@interface TNNode : ZAObject <NSCopying> {
@public
	NSMutableArray		*_children;
	TNNode				*_parent;
	
	TNSub				*_sub;
	
	BOOL				_leaf;
	
	unsigned int		_calls;
	double				_time, _cumulativeTime;
	double				_percent, _cumulativePercent;
}


- (id)initWithParent:(TNNode *)node sub:(TNSub *)sub;

- (BOOL)isEqualToNode:(TNNode *)node;

- (void)addChild:(TNNode *)node;
- (unsigned int)children;
- (TNNode *)childAtIndex:(unsigned int)index;
- (TNNode *)lastChild;
- (unsigned int)indexOfChildWithSub:(TNSub *)sub;
- (TNNode *)parent;
- (BOOL)isLeaf;

- (void)unlink;
- (void)collapse;
- (void)sortUsingSelector:(SEL)selector;

- (NSArray *)nodesMatchingPackage:(NSString *)package;
- (void)discardNodesWithCumulativePercentLessThan:(double)percent;

- (void)addTime:(double)time;
- (void)refreshPercent;

- (TNSub *)sub;
- (NSColor *)color;
- (unsigned int)calls;
- (double)time;
- (double)cumulativeTime;
- (double)percent;
- (double)cumulativePercent;

@end
