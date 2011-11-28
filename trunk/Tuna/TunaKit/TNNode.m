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

#import "TNFunction.h"
#import "TNNode.h"

@interface NSArray(TNDeepMutableCopying)

- (NSMutableArray *)deepMutableCopyWithZone:(NSZone *)zone;

@end


@implementation NSArray(TNDeepMutableCopying)

- (NSMutableArray *)deepMutableCopyWithZone:(NSZone *)zone {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	id				object, copy;
	
	array = [[NSMutableArray allocWithZone:zone] initWithCapacity:[self count]];
	enumerator = [self objectEnumerator];
	
	while((object = [enumerator nextObject])) {
		copy = [object deepMutableCopyWithZone:zone];
		[array addObject:copy];
		[copy release];
	}
	
	return array;
}

@end



@interface TNNode(Private)

- (void)_addNodesMatchingLibrary:(NSString *)library toArray:(NSMutableArray *)array;
- (TNNode *)_nodeMatchingSymbolSubstring:(NSString *)string beforeNode:(TNNode *)beforeNode haveReached:(BOOL *)reached afterNode:(TNNode *)afterNode havePassed:(BOOL *)passed;

@end


@implementation TNNode(Private)

- (void)_addNodesMatchingLibrary:(NSString *)library toArray:(NSMutableArray *)array {
	TNNode			*node;
	NSUInteger		i, count;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		node = [_children objectAtIndex:i];
		
		if([node->_function->_library hasPrefix:library])
			[array addObject:node];
		else
			[node _addNodesMatchingLibrary:library toArray:array];
	}
}



- (TNNode *)_nodeMatchingSymbolSubstring:(NSString *)string beforeNode:(TNNode *)beforeNode haveReached:(BOOL *)reached afterNode:(TNNode *)afterNode havePassed:(BOOL *)passed {
	TNNode			*node;
	NSUInteger		i, count;
	
	if(beforeNode == self) {
		*reached = YES;
		
		return NULL;
	}
	
	if(!afterNode || *passed) {
		if([[_function symbol] rangeOfString:string options:NSCaseInsensitiveSearch].location != NSNotFound)
			return self;
	}
	
	if(afterNode == self)
		*passed = YES;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		node = [[_children objectAtIndex:i] _nodeMatchingSymbolSubstring:string
															  beforeNode:beforeNode
															 haveReached:reached
															   afterNode:afterNode
															  havePassed:passed];
		
		if(node)
			return node;
		
		if(*reached)
			break;
	}
	
	return NULL;
}

@end



@implementation TNNode

- (id)initWithParent:(TNNode *)parent function:(TNFunction *)function {
	self = [super init];
	
	_parent		= parent;
	_function	= [function retain];
	_leaf		= YES;
	_calls		= 1;
	
	return self;
}



- (void)dealloc {
	[_function release];
	[_children release];
	
	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	TNNode			*node;
	NSUInteger		i, count;
	
	node = [[[self class] allocWithZone:zone] init];
	node->_children = [_children deepMutableCopyWithZone:zone];
	node->_parent = _parent;
	
	count = [node->_children count];
	
	for(i = 0; i < count; i++)
		((TNNode *) [node->_children objectAtIndex:i])->_parent = node;
	
	node->_function = [_function copyWithZone:zone];
	
	node->_leaf = _leaf;
	
	node->_calls = _calls;
	node->_percent = _percent;
	node->_cumulativePercent = _cumulativePercent;

	return node;
}



#pragma mark -

- (BOOL)isEqualToNode:(TNNode *)node {
	return (_function == node->_function);
}



- (NSString *)description {
	return [NSSWF:@"%.1f%% %.1f%% %@", _percent, _cumulativePercent, _function];
}



- (NSComparisonResult)compareValue:(TNNode *)node {
	return NSOrderedSame;
}



- (NSComparisonResult)compareCumulativeValue:(TNNode *)node {
	return NSOrderedSame;
}



- (NSComparisonResult)comparePercent:(TNNode *)node {
	if(_percent < node->_percent)
		return (_sortOrder == TNSortAscending) ? NSOrderedAscending : NSOrderedDescending;
	else if(_percent > node->_percent)
		return (_sortOrder == TNSortAscending) ? NSOrderedDescending : NSOrderedAscending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareCumulativePercent:(TNNode *)node {
	if(_cumulativePercent < node->_cumulativePercent)
		return (_sortOrder == TNSortAscending) ? NSOrderedAscending : NSOrderedDescending;
	else if(_cumulativePercent > node->_cumulativePercent)
		return (_sortOrder == TNSortAscending) ? NSOrderedDescending : NSOrderedAscending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareLibrary:(TNNode *)node {
	return [_function->_library compare:node->_function->_library options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareSymbol:(TNNode *)node {
	return [_function->_symbol compare:node->_function->_symbol options:NSCaseInsensitiveSearch];
}



#pragma mark -

- (void)addChild:(TNNode *)node {
	if(!_children)
		_children = (id) CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
		
	CFArrayReplaceValues((CFMutableArrayRef) _children,
						 CFRangeMake(CFArrayGetCount((CFMutableArrayRef) _children), 0),
						 (void *) &node,
						 1);
	
	_leaf = NO;
}



- (NSUInteger)children {
	return [_children count];
}



- (TNNode *)childAtIndex:(NSUInteger)index {
	return [_children objectAtIndex:index];
}



- (id)childWithFunction:(TNFunction *)function {
	TNNode			*node;
	NSUInteger		i, count;
	
	if(_children) {
		count = CFArrayGetCount((CFMutableArrayRef) _children);
		
		for(i = 0; i < count; i++) {
			node = (id) CFArrayGetValueAtIndex((CFMutableArrayRef) _children, i);
			
			if([node->_function isEqualToFunction:function])
				return node;
		}
	}
	
	return NULL;
}



- (id)childWithFunctionIdenticalTo:(TNFunction *)function {
	TNNode			*node;
	NSUInteger		i, count;
	
	if(_children) {
		count = CFArrayGetCount((CFMutableArrayRef) _children);
		
		for(i = 0; i < count; i++) {
			node = (id) CFArrayGetValueAtIndex((CFMutableArrayRef) _children, i);
			
			if(node->_function == function)
				return node;
		}
	}
	
	return NULL;
}



- (TNNode *)childWithHighestCumulativePercent {
	TNNode			*node, *child = NULL;
	NSUInteger		i, count;
	double			percent = 0.0;
	
	if(_children) {
		count = CFArrayGetCount((CFMutableArrayRef) _children);
		
		for(i = 0; i < count; i++) {
			node = (id) CFArrayGetValueAtIndex((CFMutableArrayRef) _children, i);
			
			if(!child || node->_cumulativePercent > percent) {
				child = node;
				percent = child->_cumulativePercent;
			}
		}
	}
	
	return child;
}



- (TNNode *)parent {
	return _parent;
}



- (BOOL)isLeaf {
	return _leaf;
}



#pragma mark -

- (void)joinWithNode:(TNNode *)node {
	TNNode			*child, *subchild;
	NSUInteger		i, count;

	_calls++;
	_percent = (_percent + node->_percent) / 2.0;
	_cumulativePercent = (_cumulativePercent + node->_cumulativePercent) / 2.0;

	count = [node->_children count];

	for(i = 0; i < count; i++) {
		child = [node->_children objectAtIndex:i];
		subchild = [self childWithFunctionIdenticalTo:child->_function];
		
		if(subchild)
			[subchild joinWithNode:child];
		else
			[self addChild:child];
	}
}



- (void)collapse {
	TNNode			*node, *nextNode; 
	NSUInteger		i, j, count;
	
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



- (void)unlink {
	[((TNNode *) _parent)->_children removeObject:self];
}



- (void)sortUsingSelector:(SEL)selector order:(TNSortOrder)order {
	TNNode			*node;
	NSUInteger		i, count;
	
	count = [_children count];
	
	for(i = 0; i < count; i++) {
		node = [_children objectAtIndex:i];
		node->_sortOrder = order;
		[node sortUsingSelector:selector order:order];
	}
	
	[_children sortUsingSelector:selector];
}



#pragma mark -

- (NSArray *)nodesMatchingLibrary:(NSString *)library {
	NSMutableArray	*array;
	
	array = [[NSMutableArray alloc] initWithCapacity:1000];
	[self _addNodesMatchingLibrary:library toArray:array];
	
	return [array autorelease];
}



- (TNNode *)nodeMatchingSymbolSubstring:(NSString *)string beforeNode:(TNNode *)beforeNode {
	BOOL	reached, passed;

	reached = passed = NO;
	
	return [self _nodeMatchingSymbolSubstring:string beforeNode:beforeNode haveReached:&reached afterNode:NULL havePassed:&passed];
}



- (TNNode *)nodeMatchingSymbolSubstring:(NSString *)string afterNode:(TNNode *)afterNode {
	BOOL	reached, passed;

	reached = passed = NO;
	
	return [self _nodeMatchingSymbolSubstring:string beforeNode:NULL haveReached:&reached afterNode:afterNode havePassed:&passed];
}



- (void)discardNodesWithCumulativePercentLessThan:(double)percent {
	TNNode			*node;
	NSUInteger		i, count;
	
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

- (void)refreshPercent {
}



#pragma mark -

- (TNFunction *)function {
	return _function;
}



- (NSColor *)color {
	return [_function color];
}



- (NSUInteger)calls {
	return _calls;
}



- (double)percent {
	return _percent;
}



- (double)cumulativePercent {
	return _cumulativePercent;
}

@end
