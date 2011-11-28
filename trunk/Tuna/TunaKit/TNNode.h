/* $Id$ */

/*
 *  Copyright (c) 2005-2008 Axel Andersson
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

@class TNFunction;

enum _TNSortOrder {
	TNSortAscending,
	TNSortDescending
};
typedef enum _TNSortOrder		TNSortOrder;

@interface TNNode : NSObject <NSCopying> {
@public
	NSMutableArray				*_children;
	id							_parent;
	
	TNFunction					*_function;
	
	BOOL						_leaf;
	TNSortOrder					_sortOrder;
	
	NSUInteger					_calls;
	double						_percent, _cumulativePercent;
}

- (id)initWithParent:(TNNode *)node function:(TNFunction *)function;

- (BOOL)isEqualToNode:(TNNode *)node;

- (NSComparisonResult)compareValue:(TNNode *)node;
- (NSComparisonResult)compareCumulativeValue:(TNNode *)node;
- (NSComparisonResult)comparePercent:(TNNode *)node;
- (NSComparisonResult)compareCumulativePercent:(TNNode *)node;
- (NSComparisonResult)compareLibrary:(TNNode *)node;
- (NSComparisonResult)compareSymbol:(TNNode *)node;

- (void)addChild:(TNNode *)node;
- (NSUInteger)children;
- (TNNode *)childAtIndex:(NSUInteger)index;
- (id)childWithFunction:(TNFunction *)function;
- (id)childWithFunctionIdenticalTo:(TNFunction *)function;
- (TNNode *)childWithHighestCumulativePercent;
- (TNNode *)parent;
- (BOOL)isLeaf;

- (void)joinWithNode:(TNNode *)node;
- (void)unlink;
- (void)collapse;
- (void)sortUsingSelector:(SEL)selector order:(TNSortOrder)order;

- (NSArray *)nodesMatchingLibrary:(NSString *)library;
- (TNNode *)nodeMatchingSymbolSubstring:(NSString *)string beforeNode:(TNNode *)beforeNode;
- (TNNode *)nodeMatchingSymbolSubstring:(NSString *)string afterNode:(TNNode *)afterNode;
- (void)discardNodesWithCumulativePercentLessThan:(double)percent;

- (void)refreshPercent;

- (TNFunction *)function;
- (NSColor *)color;
- (NSUInteger)calls;
- (double)percent;
- (double)cumulativePercent;

@end
