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

#import "TNPerlNode.h"

@interface TNPerlNode(Private)

- (void)_refreshPercentForTotalTime:(NSTimeInterval)time;

@end


@implementation TNPerlNode(Private)

- (void)_refreshPercentForTotalTime:(NSTimeInterval)time {
	NSUInteger		i, count;
	
	_percent = time > 0.0 ? (_time / time) * 100.0 : 100.0;
	_cumulativePercent = time > 0.0 ? (_cumulativeTime / time) * 100.0 : 100.0;
	
	count = [_children count];
	
	for(i = 0; i < count; i++)
		[[_children objectAtIndex:i] _refreshPercentForTotalTime:time];
}

@end



@implementation TNPerlNode

- (id)copyWithZone:(NSZone *)zone {
	TNPerlNode			*node;
	
	node = [super copyWithZone:zone];
	node->_time = _time;
	node->_cumulativeTime = _cumulativeTime;

	return node;
}



#pragma mark -

- (NSComparisonResult)compareValue:(TNPerlNode *)node {
	if(_time < node->_time)
		return (_sortOrder == TNSortAscending) ? NSOrderedAscending : NSOrderedDescending;
	else if(_time > node->_time)
		return (_sortOrder == TNSortAscending) ? NSOrderedDescending : NSOrderedAscending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareCumulativeValue:(TNPerlNode *)node {
	if(_cumulativeTime < node->_cumulativeTime)
		return (_sortOrder == TNSortAscending) ? NSOrderedAscending : NSOrderedDescending;
	else if(_cumulativeTime > node->_cumulativeTime)
		return (_sortOrder == TNSortAscending) ? NSOrderedDescending : NSOrderedAscending;
	
	return NSOrderedSame;
}



#pragma mark -

- (void)joinWithNode:(TNPerlNode *)node {
	_time += node->_time;
	_cumulativeTime += node->_cumulativeTime;
	
	[super joinWithNode:node];
}



- (void)unlink {
	TNPerlNode		*node;
	
	for(node = (TNPerlNode *) _parent; node != NULL; node = (TNPerlNode *) node->_parent)
		node->_cumulativeTime -= _cumulativeTime;
	
	[super unlink];
}



#pragma mark -

- (void)addTime:(NSTimeInterval)time {
	TNPerlNode		*node;
	
	for(node = self; node != NULL; node = (TNPerlNode *) node->_parent)
		node->_cumulativeTime += time;
	
	_time += time;
}



- (void)refreshPercent {
	NSUInteger			i, count;
	NSTimeInterval		time;
	
	time	= 0.0;
	count	= [_children count];
	
	for(i = 0; i < count; i++)
		time += ((TNPerlNode *) [_children objectAtIndex:i])->_cumulativeTime;
	
	[self _refreshPercentForTotalTime:time];
}



#pragma mark -

- (NSTimeInterval)time {
	return _time;
}



- (NSTimeInterval)cumulativeTime {
	return _cumulativeTime;
}

@end
