/* $Id$ */

/*
 *  Copyright (c) 2003-2005 Axel Andersson
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

// --- http://www.mulle-kybernetik.com/artikel/Optimization/opti-3-imp-deluxe.html

#import "ZANotification.h"
#import "ZANotificationCenter.h"
#import "ZAFunctions.h"
#import <objc/objc-runtime.h>
#import <ppc/param.h>
#import <pthread.h>

static Class	concreteNotificationClass;

#define ZANotificationCenterZoneSize \
	((NBPG / sizeof(struct ZANotificationCenterObserver)))

#define ZANotificationCenterStorageBuckets			64


struct ZANotificationCenterObserver {
	id												observer;
	NSString										*name;
	SEL												selector;
	IMP												method;
	id												object;
	
	struct ZANotificationCenterObserver				*next;
	struct ZANotificationCenterObserver				*link;
};
typedef struct ZANotificationCenterObserver			ZANotificationCenterObserver;


struct ZANotificationCenterStorage {
	ZANotificationCenterObserver					*observers[ZANotificationCenterStorageBuckets];
	
	ZANotificationCenterObserver					**chunks;
	unsigned int									chunkCount;
	unsigned int									chunkOffset;

	ZANotificationCenterObserver					*freeList;
	
	pthread_mutex_t									mutex;
};
typedef struct ZANotificationCenterStorage			ZANotificationCenterStorage;


#define ZANSNotificationCenterVars(center) \
	((struct { @defs(NSNotificationCenter) } *) center)

#define ZANSObjectVars(object) \
	((struct { @defs(NSObject) } *) object)


static ZANotificationCenterObserver * _newObserver(ZANotificationCenterStorage *);
static void _addObserver(id, SEL, NSString *, id, ZANotificationCenterStorage *);
static void _postNotification(NSNotification *, NSString *, id, NSDictionary *, ZANotificationCenterStorage *);
static void _removeObserver(id, NSString *, id, ZANotificationCenterStorage *);


@implementation ZANotificationCenter

+ (void)initialize {
	if(!concreteNotificationClass)
		concreteNotificationClass = [ZANotification class];
}



+ (void)activate {
	[self poseAsClass:[NSNotificationCenter class]];
}



+ (NSNotificationCenter *)defaultCenter {
	static NSNotificationCenter		*defaultNotificationCenter;
	
	if(!defaultNotificationCenter)
		defaultNotificationCenter = [[self allocWithZone:NULL] init];
	
	return defaultNotificationCenter;
}



+ (id)alloc {
	return NSAllocateObject(self, 0, NULL);
}



+ (id)allocWithZone:(NSZone *)zone {
	return NSAllocateObject(self, 0, zone);
}



- (id)init {
	ZANotificationCenterStorage		*storage;
	
	storage = (ZANotificationCenterStorage *) malloc(sizeof(ZANotificationCenterStorage));
	memset(storage, 0, sizeof(ZANotificationCenterStorage));
	storage->chunkOffset = ZANotificationCenterZoneSize;
	pthread_mutex_init(&storage->mutex, NULL);
	ZANSNotificationCenterVars(self)->_pad[0] = (void *) storage;
	
	return self;
}



- (id)retain {
	ZAAtomicIncrement((int *) &(ZANSNotificationCenterVars(self)->_pad[1]));
	
	return self;
}



- (unsigned int)retainCount {
	return ((int) ZANSNotificationCenterVars(self)->_pad[1]) + 1;
}



- (void)release {
	if(ZAAtomicDecrement((int *) &(ZANSNotificationCenterVars(self)->_pad[1])) == -1)
		[self dealloc];
}



- (void)dealloc {
	ZANotificationCenterStorage		*storage;
	unsigned int					i;
	
	storage = ZANSNotificationCenterVars(self)->_pad[0];
	
	for(i = 0; i < storage->chunkCount; i++)
		free(storage->chunks[i]);
	
	free(storage->chunks);
	pthread_mutex_destroy(&storage->mutex);
	free(storage);
	
	NSDeallocateObject(self);
	
	if(NO)
		[super dealloc];
}



#pragma mark -

- (void)addObserver:(id)sender selector:(SEL)selector name:(id)name object:(id)object {
	_addObserver(sender, selector, name, object, ZANSNotificationCenterVars(self)->_pad[0]);
}



- (void)postNotification:(NSNotification *)notification {
	_postNotification(notification, NULL, NULL, NULL, ZANSNotificationCenterVars(self)->_pad[0]);
}



- (void)postNotificationName:(NSString *)name object:(id)object {
	ZANotification  *notification;
	
	notification = (ZANotification *) NSAllocateObject(concreteNotificationClass, 0, NSDefaultMallocZone());
	notification->_name = [name copyWithZone:[self zone]];
	notification->_object = [object retain];
	
	_postNotification(notification, name, object, NULL, ZANSNotificationCenterVars(self)->_pad[0]);
	
	[notification->_name release];
	[notification->_object release];

	NSDeallocateObject(notification);
}



- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
	ZANotification  *notification;
	
	notification = (ZANotification *) NSAllocateObject(concreteNotificationClass, 0, NSDefaultMallocZone());
	notification->_name = [name copyWithZone:[self zone]];
	notification->_object = [object retain];
	notification->_userInfo = [userInfo retain];
	
	_postNotification(notification, name, object, userInfo, ZANSNotificationCenterVars(self)->_pad[0]);
	
	[notification->_name release];
	[notification->_object release];
	[notification->_userInfo release];
	
	NSDeallocateObject(notification);
}



- (void)removeObserver:(id)sender {
	_removeObserver(sender, NULL, NULL, ZANSNotificationCenterVars(self)->_pad[0]);
}



- (void)removeObserver:(id)sender name:(NSString *)name object:(id)object {
	_removeObserver(sender, name, object, ZANSNotificationCenterVars(self)->_pad[0]);
}



#pragma mark -

static ZANotificationCenterObserver *_newObserver(ZANotificationCenterStorage *storage) {
	ZANotificationCenterObserver	*observer, *observerBlock;
	size_t							size;
	
	if(!storage->freeList) {
		if(storage->chunkOffset == ZANotificationCenterZoneSize) {
			storage->chunkCount++;
			
			size = storage->chunkCount * sizeof(ZANotificationCenterObserver *);
			storage->chunks = (ZANotificationCenterObserver **)
				realloc(storage->chunks, size);
			
			size = ZANotificationCenterZoneSize * sizeof(ZANotificationCenterObserver);
			storage->chunks[storage->chunkCount - 1] = (ZANotificationCenterObserver *)
				malloc(size);
			
			storage->chunkOffset = 0;
		}
		
		observerBlock = storage->chunks[storage->chunkCount - 1];
		storage->freeList = &observerBlock[storage->chunkOffset++];
		storage->freeList->link = NULL;
	}
	
	observer = storage->freeList;
	storage->freeList = observer->link;

	return observer;
}



static void _addObserver(id sender, SEL selector, NSString *name, id object, ZANotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	ZANotificationCenterObserver	*observer;
	unsigned int					index;
	
	index = [name hash] % ZANotificationCenterStorageBuckets;
	
	pthread_mutex_lock(&storage->mutex);
	
	observer = _newObserver(storage);
	
	observer->observer = sender;
	observer->name = [name copy];
	observer->selector = selector;
	observer->method = class_lookupMethod([sender class], selector);
	observer->object = object;
	observer->next = storage->observers[index];
	
	storage->observers[index] = observer;
	
	pthread_mutex_unlock(&storage->mutex);
}



static void _postNotification(NSNotification *notification, NSString *name, id object, NSDictionary *userInfo, ZANotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	ZANotificationCenterObserver	*observer;
	SEL								equalSelector;
	IMP								equalMethod;
	id								(*objc_msgSend_p)(id, SEL, ...);
	unsigned int					index;
	
	pthread_mutex_unlock(&storage->mutex);
	
	if(!name) {
		name = [notification name];
		object = [notification object];
		userInfo = [notification userInfo];
	}
	
	index = [name hash] % ZANotificationCenterStorageBuckets;
	
	observer = storage->observers[index];
	
	if(observer) {
		objc_msgSend_p = objc_msgSend;
		equalSelector = @selector(isEqualToString:);
		equalMethod = class_lookupMethod([name class], equalSelector);
		
		for(; observer; observer = observer->next) {
			if((*equalMethod)(name, equalSelector, observer->name)) {
				if(!object || !observer->object || observer->object == object)
					(*observer->method)(observer->observer, observer->selector, notification);
			}
		}
	}

	pthread_mutex_unlock(&storage->mutex);
}



static void _removeObserver(id sender, NSString *name, id object, ZANotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	ZANotificationCenterObserver	*observer, *nextObserver, *previousObserver;
	SEL								equalSelector, releaseSelector;
	IMP								equalMethod;
	id								(*objc_msgSend_p)(id, SEL, ...);
	IMP								(*class_lookupMethod_p)(Class, SEL);
	unsigned int					i, index;
	
	class_lookupMethod_p = class_lookupMethod;
	objc_msgSend_p = objc_msgSend;
	releaseSelector = @selector(release);

	pthread_mutex_lock(&storage->mutex);
	
	if(name) {
		equalSelector = @selector(isEqualToString:);
		equalMethod = (*class_lookupMethod_p)([name class], equalSelector);

		index = [name hash] % ZANotificationCenterStorageBuckets;
		previousObserver = NULL;

		for(observer = storage->observers[index]; observer; observer = nextObserver) {
			nextObserver = observer->next;
			
			if(observer->observer == sender) {
				if((!name || (*equalMethod)(name, equalSelector, observer->name)) &&
				   (!object || observer->object == object)) {
					(*objc_msgSend_p)(observer->name, releaseSelector);
					
					if(previousObserver)
						previousObserver->next = observer->next;
					
					if(observer == storage->observers[index])
						storage->observers[index] = observer->next;
					
					observer->link = storage->freeList;
					storage->freeList = observer;
				}
			}
			
			previousObserver = observer;
		}
	} else {
		for(i = 0; i < ZANotificationCenterStorageBuckets; i++) {
			previousObserver = NULL;
			
			for(observer = storage->observers[i]; observer; observer = nextObserver) {
				nextObserver = observer->next;
				
				if(observer->observer == sender) {
					if(!object || observer->object == object) {
						(*objc_msgSend_p)(observer->name, releaseSelector);
						
						if(previousObserver)
							previousObserver->next = observer->next;
						
						if(observer == storage->observers[i])
							storage->observers[i] = observer->next;
						
						observer->link = storage->freeList;
						storage->freeList = observer;
					}
				}
			}
			
			previousObserver = observer;
		}
	}
	
	pthread_mutex_unlock(&storage->mutex);
}

@end
