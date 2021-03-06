/* $Id$ */

/*
 *  Copyright (c) 2005-2006 Axel Andersson
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

#import <WiredAdditions/WIReadWriteLock.h>
#import <pthread.h>

@implementation WIReadWriteLock

- (id)init {
	self = [super init];
	
	pthread_rwlock_init(&_lock, NULL);
	
	return self;
}



- (void)dealloc {
	pthread_rwlock_destroy(&_lock);
	
	[super dealloc];
}



#pragma mark -

- (void)lockForReading {
	pthread_rwlock_rdlock(&_lock);
}



- (void)lockForWriting {
	pthread_rwlock_wrlock(&_lock);
}



- (void)unlock {
	pthread_rwlock_unlock(&_lock);
}



- (BOOL)tryLockForReading {
	return (pthread_rwlock_tryrdlock(&_lock) == 0);
}



- (BOOL)tryLockForWriting {
	return (pthread_rwlock_trywrlock(&_lock) == 0);
}

@end
