/* $Id$ */

/*
 *  Copyright (c) 2003-2006 Axel Andersson
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

@interface NSArray(WIArrayAdditions)

- (NSString *)stringAtIndex:(unsigned int)index;
- (id)safeObjectAtIndex:(unsigned int)index;

- (int)indexOfString:(NSString *)string;
- (int)indexOfString:(NSString *)string options:(int)options;
- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string options:(int)options;
- (NSArray *)stringsMatchingString:(NSString *)string;
- (NSArray *)stringsMatchingString:(NSString *)string options:(int)options;
- (void)makeObjectsPerformSelector:(SEL)selector withObject:(id)object1 withObject:(id)object2;
- (void)makeObjectsPerformSelector:(SEL)selector withBool:(BOOL)value;
- (NSArray *)subarrayFromIndex:(unsigned int)index;
- (NSArray *)reversedArray;

- (NSNumber *)minimumNumber;
- (NSNumber *)maximumNumber;

@end


@interface NSMutableArray(WIMutableArrayAdditions)

- (void)moveObjectAtIndex:(unsigned int)from toIndex:(unsigned int)to;
- (void)reverse;

@end
