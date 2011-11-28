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

#import "TNNode.h"
#import "TNSub.h"

@interface TNNode(Private)

- (void)joinWithNode:(TNNode *)node;

- (void)addNodesMatchingPackage:(NSString *)package toArray:(NSMutableArray *)array;

- (void)refreshPercentForTotalTime:(double)time;

@end



@implementation TNNode

- (id)initWithParent:(TNNode *)parent sub:(TNSub *)sub {
	self = [super init];
	
	_parent		= parent;
	_sub		= [sub retain];
	_leaf		= YES;
	_calls		= 1;
	
	return self;
}



- (void)dealloc {
	[_sub release];
	[_children release];
	
	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	TNNode			*node;
	unsigned int	i, count;
	
	node = [[TNNode allocWithZone:zone] init];
	node->_children = [_children deepMutableCopyWithZone:zone];
	node->_parent = _parent;
	
	count = [node->_children count];
	
	for(i = 0; i < count; i++)
		((TNNode *) [node->_children objectAtIndex:i])->_parent = node;
	
	node->_sub = [_sub copyWithZone:zone];
	
	node->_leaf = _leaf;
	
	node->_calls = _calls;
	node->_time = _time;
	node->_cumulativeTime = _cumulativeTime;
	node->_percent = _percent;
	node->_cumulativePercent = _cumulativePercent;

	return node;
}



#pragma mark -

- (BOOL)isEqualToNode:(TNNode *)node {
	return [_sub isEqualToSub:node->_sub];
}



- (NSString *)description {
	return [NSSWF:@"%.1f%% %.1f%% %@", _percent, _cumulativePercent, _sub];
}



- (NSComparisonResult)compareTime:(TNNode *)node {
	if(_time < node->_time)
		return NSOrderedAscending;
	else if(_time > node->_time)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareCumulativeTime:(TNNode *)node {
	if(_cumulativeTime < node->_cumulativeTime)
		return NSOrderedAscending;
	else if(_cumulativeTime > node->_cumulativeTime)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)comparePercent:(TNNode *)node {
	if(_percent < node->_percent)
		return NSOrderedAscending;
	else if(_percent > node->_percent)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareCumulativePercent:(TNNode *)node {
	if(_cumulativePercent < node->_cumulativePercent)
		return NSOrderedAscending;
	else if(_cumulativePercent > node->_cumulativePercent)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)comparePackage:(TNNode *)node {
	return [_sub->_package compare:node->_sub->_package options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareSub:(TNNode *)node {
	return [_sub->_name compare:node->_sub->_name options:NSCaseInsensitiveSearch];
}



#pragma mark -

- (void)addChild:(TNNode *)childNode {
	if(!_children)
		_children = [[NSMutableArray alloc] initWithCapacity:100];

	[_children addObject:childNode];
	_leaf = NO;
}



- (unsigned int)children {
	return [_children count];
}



- (TNNode *)childAtIndex:(unsigned int)index {
	return [_children objectAtIndex:index];
}



- (TNNode *)lastChild {
	return [_children lastObject];
}



- (unsigned int)indexOfChildWithSub:(TNSub *)sub {
	unsigned int	i, count;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		if(((TNNode *) [_children objectAtIndex:i])->_sub == sub)
			return i;
	}
	
	return NSNotFound;
}



- (TNNode *)parent {
	return _parent;
}



- (BOOL)isLeaf {
	return _leaf;
}



#pragma mark -

- (void)collapse {
	TNNode			*node, *nextNode; 
	unsigned int	i, j, count;
	
	count = [_children count];

	for(i = 0; i < count; i++) {
		node = [_children objectAtIndex:i];
		
		if(i < count - 1) {
			for(j = i + 1; j < count; j++) {
				nextNode = [_children objectAtIndex:j]; 
			
				if([node isEqualToNode:nextNode]) {
					[node joinWithNode:nextNode];
					
					[_children removeObjectAtIndex:j];

					count--;
					j--;
				}
			}
		}

		[node collapse];
	}
}



- (void)joinWithNode:(TNNode *)node {
	TNNode			*child;
	unsigned int	i, count, index;

	_calls++;
	_time += node->_time;
	_cumulativeTime += node->_cumulativeTime;
	_percent = (_percent + node->_percent) / 2.0;
	_cumulativePercent = (_cumulativePercent + node->_cumulativePercent) / 2.0;

	count = [node->_children count];

	for(i = 0; i < count; i++) {
		child = [node->_children objectAtIndex:i];
		index = [self indexOfChildWithSub:child->_sub];

		if(index == NSNotFound)
			[self addChild:child];
		else
			[[_children objectAtIndex:index] joinWithNode:child];
	}
}



- (void)unlink {
	TNNode		*node;
	
	for(node = _parent; node != NULL; node = node->_parent)
		node->_cumulativeTime -= _cumulativeTime;

	[_parent->_children removeObject:self];
}



- (void)sortUsingSelector:(SEL)selector {
	unsigned int	i, count;
	
	[_children sortUsingSelector:selector];
	
	count = [_children count];
	
	for(i = 0; i < count; i++)
		[[_children objectAtIndex:i] sortUsingSelector:selector];
}



#pragma mark -

- (NSArray *)nodesMatchingPackage:(NSString *)package {
	NSMutableArray	*array;
	
	array = [[NSMutableArray alloc] initWithCapacity:1000];
	[self addNodesMatchingPackage:package toArray:array];
	
	return [array autorelease];
}



- (void)addNodesMatchingPackage:(NSString *)package toArray:(NSMutableArray *)array {
	TNNode			*node;
	unsigned int	i, count;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		node = [_children objectAtIndex:i];
		
		if([node->_sub->_package hasPrefix:package])
			[array addObject:node];
		else
			[node addNodesMatchingPackage:package toArray:array];
	}
}



- (void)discardNodesWithCumulativePercentLessThan:(double)percent {
	TNNode			*node;
	unsigned int	i, count;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		node = [_children objectAtIndex:i];
		
		if(node->_cumulativePercent < percent) {
			[_children removeObjectAtIndex:i];
			
			count--;
			i--;
		} else {
			[node discardNodesWithCumulativePercentLessThan:percent];
		}
	}
}



#pragma mark -

- (void)addTime:(double)time {
	TNNode		*node;
	
	for(node = self; node != NULL; node = node->_parent)
		node->_cumulativeTime += time;
	
	_time += time;
}



- (void)refreshPercent {
	unsigned int	i, count;
	double			time;
	
	time	= 0.0;
	count	= [_children count];
	
	for(i = 0; i < count; i++)
		time += ((TNNode *) [_children objectAtIndex:i])->_cumulativeTime;
	
	[self refreshPercentForTotalTime:time];
}



- (void)refreshPercentForTotalTime:(double)time {
	unsigned int	i, count;
	
	_percent = time > 0.0 ? (_time / time) * 100.0 : 100.0;
	_cumulativePercent = time > 0.0 ? (_cumulativeTime / time) * 100.0 : 100.0;
	
	count = [_children count];
	
	for(i = 0; i < count; i++)
		[[_children objectAtIndex:i] refreshPercentForTotalTime:time];
}



#pragma mark -

- (TNSub *)sub {
	return _sub;
}



- (NSColor *)color {
	return [_sub color];
}



- (unsigned int)calls {
	return _calls;
}



- (double)time {
	return _time;
}



- (double)cumulativeTime {
	return _cumulativeTime;
}



- (double)percent {
	return _percent;
}



- (double)cumulativePercent {
	return _cumulativePercent;
}

@end
