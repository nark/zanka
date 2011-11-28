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

#include "config.h"

#include <stdio.h>
#include <errno.h>
#include <string.h>

#ifdef WI_PTHREADS
#include <pthread.h>
#endif

#include <wired/wi-assert.h>
#include <wired/wi-date.h>
#include <wired/wi-lock.h>
#include <wired/wi-string.h>
#include <wired/wi-runtime.h>

#include "wi-private.h"

struct _wi_lock {
	wi_runtime_base_t					base;
	
#ifdef WI_PTHREADS
	pthread_mutex_t						mutex;
#endif
};


static void								_wi_lock_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_lock_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_lock_runtime_class = {
	"wi_lock_t",
	_wi_lock_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



struct _wi_recursive_lock {
	wi_runtime_base_t					base;

#ifdef WI_PTHREADS
	pthread_mutex_t						mutex;
#endif
};


static void								_wi_recursive_lock_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_recursive_lock_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_recursive_lock_runtime_class = {
	"wi_recursive_lock_t",
	_wi_recursive_lock_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



struct _wi_rwlock {
	wi_runtime_base_t					base;
	
#ifdef WI_PTHREADS
	pthread_rwlock_t					rwlock;
#endif
};


static void								_wi_rwlock_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_rwlock_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_rwlock_runtime_class = {
	"wi_rwlock_t",
	_wi_rwlock_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};



struct _wi_condition_lock {
	wi_runtime_base_t					base;

#ifdef WI_PTHREADS
	pthread_mutex_t						mutex;
	pthread_cond_t						cond;
#endif
	
	int									condition;
};


static void								_wi_condition_lock_dealloc(wi_runtime_instance_t *);


static wi_runtime_id_t					_wi_condition_lock_runtime_id = WI_RUNTIME_ID_NULL;
static wi_runtime_class_t				_wi_condition_lock_runtime_class = {
	"wi_condition_lock_t",
	_wi_condition_lock_dealloc,
	NULL,
	NULL,
	NULL,
	NULL
};


void wi_lock_register(void) {
	_wi_lock_runtime_id = wi_runtime_register_class(&_wi_lock_runtime_class);
	_wi_recursive_lock_runtime_id = wi_runtime_register_class(&_wi_recursive_lock_runtime_class);
	_wi_rwlock_runtime_id = wi_runtime_register_class(&_wi_rwlock_runtime_class);
	_wi_condition_lock_runtime_id = wi_runtime_register_class(&_wi_condition_lock_runtime_class);
}



void wi_lock_initialize(void) {
}



#pragma mark -

wi_runtime_id_t wi_lock_runtime_id(void) {
	return _wi_lock_runtime_id;
}



#pragma mark -

wi_lock_t * wi_lock_alloc(void) {
	return wi_runtime_create_instance(_wi_lock_runtime_id, sizeof(wi_lock_t));
}



wi_lock_t * wi_lock_init(wi_lock_t *lock) {
#ifdef WI_PTHREADS
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&lock->mutex, &attr);
	pthread_mutexattr_destroy(&attr);
#endif
	
	return lock;
}



#pragma mark -

static void _wi_lock_dealloc(wi_runtime_instance_t *instance) {
#ifdef WI_PTHREADS
	wi_lock_t		*lock = (wi_lock_t *) instance;

	pthread_mutex_destroy(&lock->mutex);
#endif
}



#pragma mark -

void wi_lock_lock(wi_lock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_mutex_lock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_lock: %s", strerror(err));
#endif
}



wi_boolean_t wi_lock_trylock(wi_lock_t *lock) {
#ifdef WI_PTHREADS
	return (pthread_mutex_trylock(&lock->mutex) == 0);
#else
	return true;
#endif
}



void wi_lock_unlock(wi_lock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_mutex_unlock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_unlock: %s", strerror(err));
#endif
}



#pragma mark -

wi_runtime_id_t wi_recursive_lock_runtime_id(void) {
	return _wi_recursive_lock_runtime_id;
}



#pragma mark -

wi_recursive_lock_t * wi_recursive_lock_alloc(void) {
	return wi_runtime_create_instance(_wi_recursive_lock_runtime_id, sizeof(wi_recursive_lock_t));
}



wi_recursive_lock_t * wi_recursive_lock_init(wi_recursive_lock_t *lock) {
#ifdef WI_PTHREADS
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&lock->mutex, &attr);
	pthread_mutexattr_destroy(&attr);
#endif

	return lock;
}



#pragma mark -

static void _wi_recursive_lock_dealloc(wi_runtime_instance_t *instance) {
#ifdef WI_PTHREADS
	wi_recursive_lock_t		*lock = (wi_recursive_lock_t *) instance;
	
	pthread_mutex_destroy(&lock->mutex);
#endif
}



#pragma mark -

void wi_recursive_lock_lock(wi_recursive_lock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_mutex_lock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_lock: %s", strerror(err));
#endif
}



wi_boolean_t wi_recursive_lock_trylock(wi_recursive_lock_t *lock) {
#ifdef WI_PTHREADS
	return (pthread_mutex_trylock(&lock->mutex) == 0);
#else
	return true;
#endif
}



void wi_recursive_lock_unlock(wi_recursive_lock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_mutex_unlock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_unlock: %s", strerror(err));
#endif
}



#pragma mark -

wi_runtime_id_t wi_rwlock_runtime_id(void) {
	return _wi_rwlock_runtime_id;
}



#pragma mark -

wi_rwlock_t * wi_rwlock_alloc(void) {
	return wi_runtime_create_instance(_wi_rwlock_runtime_id, sizeof(wi_rwlock_t));
}



wi_rwlock_t * wi_rwlock_init(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	pthread_rwlock_init(&lock->rwlock, NULL);
#endif
	
	return lock;
}



#pragma mark -

static void _wi_rwlock_dealloc(wi_runtime_instance_t *instance) {
#ifdef WI_PTHREADS
	wi_rwlock_t		*lock = (wi_rwlock_t *) instance;
	
	pthread_rwlock_destroy(&lock->rwlock);
#endif
}



#pragma mark -

void wi_rwlock_wrlock(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_rwlock_wrlock(&lock->rwlock);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_rwlock_wrlock: %s", strerror(err));
#endif
}



wi_boolean_t wi_rwlock_trywrlock(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	return (pthread_rwlock_trywrlock(&lock->rwlock) == 0);
#else
	return true;
#endif
}



void wi_rwlock_rdlock(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_rwlock_rdlock(&lock->rwlock);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_rwlock_rdlock: %s", strerror(err));
#endif
}



wi_boolean_t wi_rwlock_tryrdlock(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	return (pthread_rwlock_tryrdlock(&lock->rwlock) == 0);
#else
	return true;
#endif
}



void wi_rwlock_unlock(wi_rwlock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_rwlock_unlock(&lock->rwlock);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_rwlock_unlock: %s", strerror(err));
#endif
}



#pragma mark -

wi_runtime_id_t wi_condition_lock_runtime_id(void) {
	return _wi_condition_lock_runtime_id;
}



#pragma mark -

wi_condition_lock_t * wi_condition_lock_alloc(void) {
	return wi_runtime_create_instance(_wi_condition_lock_runtime_id, sizeof(wi_condition_lock_t));
}



wi_condition_lock_t * wi_condition_lock_init(wi_condition_lock_t *lock) {
	return wi_condition_lock_init_with_condition(lock, 0);
}



wi_condition_lock_t * wi_condition_lock_init_with_condition(wi_condition_lock_t *lock, int condition) {
#ifdef WI_PTHREADS
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&lock->mutex, &attr);
	pthread_mutexattr_destroy(&attr);

	pthread_cond_init(&lock->cond, NULL);
#endif
	
	lock->condition = condition;

	return lock;
}



#pragma mark -

static void _wi_condition_lock_dealloc(wi_runtime_instance_t *instance) {
#ifdef WI_PTHREADS
	wi_condition_lock_t		*lock = (wi_condition_lock_t *) instance;
	
	pthread_mutex_destroy(&lock->mutex);
	pthread_cond_destroy(&lock->cond);
#endif
}



#pragma mark -

void wi_condition_lock_lock(wi_condition_lock_t *lock) {
#ifdef WI_PTHREADS
	pthread_mutex_lock(&lock->mutex);
#endif
}



wi_boolean_t wi_condition_lock_lock_when_condition(wi_condition_lock_t *lock, int condition, wi_time_interval_t time) {
#ifdef WI_PTHREADS
	struct timespec		ts;
	int					err;
	
	err = pthread_mutex_lock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_lock: %s", strerror(err));
	
	if(lock->condition != condition) {
		if(time > 0.0) {
			ts = wi_dtots(time);

			do {
				err = pthread_cond_timedwait(&lock->cond, &lock->mutex, &ts);

				if(err != 0 && err != ETIMEDOUT)
					WI_ASSERT(0, "pthread_cond_wait: %s", strerror(err));
			} while(lock->condition != condition && err != ETIMEDOUT);

			if(err == ETIMEDOUT)
				return false;
		} else {
			do {
				err = pthread_cond_wait(&lock->cond, &lock->mutex);
				
				if(err != 0)
					WI_ASSERT(0, "pthread_cond_wait: %s", strerror(err));
			} while(lock->condition != condition);
		}
	}
	
	return true;
#else
	return false;
#endif
}



wi_boolean_t wi_condition_lock_trylock(wi_condition_lock_t *lock) {
#ifdef WI_PTHREADS
	return (pthread_mutex_trylock(&lock->mutex) == 0);
#else
	return true;
#endif
}



wi_boolean_t wi_condition_lock_trylock_when_condition(wi_condition_lock_t *lock, int condition) {
#ifdef WI_PTHREADS
	if(!wi_condition_lock_trylock(lock))
		return false;
	
	if(lock->condition == condition) {
		return true;
	} else {
		wi_condition_lock_unlock(lock);
		
		return false;
	}
#else
	return true;
#endif
}



void wi_condition_lock_unlock(wi_condition_lock_t *lock) {
#ifdef WI_PTHREADS
	int		err;
	
	err = pthread_cond_broadcast(&lock->cond);

	if(err != 0)
		WI_ASSERT(0, "pthread_cond_broadcast: %s", strerror(err));

	err = pthread_mutex_unlock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_unlock: %s", strerror(err));
#endif
}



void wi_condition_lock_unlock_with_condition(wi_condition_lock_t *lock, int condition) {
#ifdef WI_PTHREADS
	int		err;
#endif
	
	lock->condition = condition;
	
#ifdef WI_PTHREADS
	err = pthread_cond_broadcast(&lock->cond);

	if(err != 0)
		WI_ASSERT(0, "pthread_cond_broadcast: %s", strerror(err));
	
	err = pthread_mutex_unlock(&lock->mutex);
	
	if(err != 0)
		WI_ASSERT(0, "pthread_mutex_unlock: %s", strerror(err));
#endif
}



int wi_condition_lock_condition(wi_condition_lock_t *lock) {
	return lock->condition;
}
