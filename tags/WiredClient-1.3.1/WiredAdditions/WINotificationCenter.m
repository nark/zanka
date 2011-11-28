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

// --- http://www.mulle-kybernetik.com/artikel/Optimization/opti-3-imp-deluxe.html

#import "WINotification.h"
#import "WINotificationCenter.h"
#import "WIFunctions.h"
#import <objc/objc-runtime.h>
#import <machine/param.h>
#import <pthread.h>

static Class	concreteNotificationClass;

#define WINotificationCenterZoneSize \
	((NBPG / sizeof(struct WINotificationCenterObserver)))

#define WINotificationCenterStorageBuckets			64


struct WINotificationCenterObserver {
	id												observer;
	NSString										*name;
	SEL												selector;
	IMP												method;
	id												object;
	
	struct WINotificationCenterObserver				*next;
	struct WINotificationCenterObserver				*link;
};
typedef struct WINotificationCenterObserver			WINotificationCenterObserver;


struct WINotificationCenterStorage {
	WINotificationCenterObserver					*observers[WINotificationCenterStorageBuckets];
	
	WINotificationCenterObserver					**chunks;
	unsigned int									chunkCount;
	unsigned int									chunkOffset;

	WINotificationCenterObserver					*freeList;
	
	pthread_mutex_t									mutex;
};
typedef struct WINotificationCenterStorage			WINotificationCenterStorage;


#define WINSNotificationCenterVars(center) \
	((struct { @defs(NSNotificationCenter) } *) center)

#define WINSObjectVars(object) \
	((struct { @defs(NSObject) } *) object)


static WINotificationCenterObserver * _newObserver(WINotificationCenterStorage *);
static void _addObserver(id, SEL, NSString *, id, WINotificationCenterStorage *);
static void _postNotification(NSNotification *, NSString *, id, NSDictionary *, WINotificationCenterStorage *);
static void _removeObserver(id, NSString *, id, WINotificationCenterStorage *);


@implementation WINotificationCenter

+ (void)initialize {
	if(!concreteNotificationClass)
		concreteNotificationClass = [WINotification class];
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
	WINotificationCenterStorage		*storage;
	
	storage = (WINotificationCenterStorage *) malloc(sizeof(WINotificationCenterStorage));
	memset(storage, 0, sizeof(WINotificationCenterStorage));
	storage->chunkOffset = WINotificationCenterZoneSize;
	pthread_mutex_init(&storage->mutex, NULL);
	WINSNotificationCenterVars(self)->_pad[0] = (void *) storage;
	
	return self;
}



- (id)retain {
	WIAtomicIncrement((int *) &(WINSNotificationCenterVars(self)->_pad[1]));
	
	return self;
}



- (unsigned int)retainCount {
	return ((int) WINSNotificationCenterVars(self)->_pad[1]) + 1;
}



- (void)release {
	if(WIAtomicDecrement((int *) &(WINSNotificationCenterVars(self)->_pad[1])) == -1)
		[self dealloc];
}



- (void)dealloc {
	WINotificationCenterStorage		*storage;
	unsigned int					i;
	
	storage = WINSNotificationCenterVars(self)->_pad[0];
	
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
	_addObserver(sender, selector, name, object, WINSNotificationCenterVars(self)->_pad[0]);
}



- (void)postNotification:(NSNotification *)notification {
	_postNotification(notification, NULL, NULL, NULL, WINSNotificationCenterVars(self)->_pad[0]);
}



- (void)postNotificationName:(NSString *)name object:(id)object {
	WINotification  *notification;
	
	notification = (WINotification *) NSAllocateObject(concreteNotificationClass, 0, NSDefaultMallocZone());
	notification->_name = [name copyWithZone:[self zone]];
	notification->_object = [object retain];
	
	_postNotification(notification, name, object, NULL, WINSNotificationCenterVars(self)->_pad[0]);
	
	[notification->_name release];
	[notification->_object release];

	NSDeallocateObject(notification);
}



- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo {
	WINotification  *notification;
	
	notification = (WINotification *) NSAllocateObject(concreteNotificationClass, 0, NSDefaultMallocZone());
	notification->_name = [name copyWithZone:[self zone]];
	notification->_object = [object retain];
	notification->_userInfo = [userInfo retain];
	
	_postNotification(notification, name, object, userInfo, WINSNotificationCenterVars(self)->_pad[0]);
	
	[notification->_name release];
	[notification->_object release];
	[notification->_userInfo release];
	
	NSDeallocateObject(notification);
}



- (void)removeObserver:(id)sender {
	_removeObserver(sender, NULL, NULL, WINSNotificationCenterVars(self)->_pad[0]);
}



- (void)removeObserver:(id)sender name:(NSString *)name object:(id)object {
	_removeObserver(sender, name, object, WINSNotificationCenterVars(self)->_pad[0]);
}



#pragma mark -

static WINotificationCenterObserver *_newObserver(WINotificationCenterStorage *storage) {
	WINotificationCenterObserver	*observer, *observerBlock;
	size_t							size;
	
	if(!storage->freeList) {
		if(storage->chunkOffset == WINotificationCenterZoneSize) {
			storage->chunkCount++;
			
			size = storage->chunkCount * sizeof(WINotificationCenterObserver *);
			storage->chunks = (WINotificationCenterObserver **)
				realloc(storage->chunks, size);
			
			size = WINotificationCenterZoneSize * sizeof(WINotificationCenterObserver);
			storage->chunks[storage->chunkCount - 1] = (WINotificationCenterObserver *)
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



static void _addObserver(id sender, SEL selector, NSString *name, id object, WINotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	WINotificationCenterObserver	*observer;
	unsigned int					index;
	
	index = [name hash] % WINotificationCenterStorageBuckets;
	
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



static void _postNotification(NSNotification *notification, NSString *name, id object, NSDictionary *userInfo, WINotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	WINotificationCenterObserver	*observer;
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
	
	index = [name hash] % WINotificationCenterStorageBuckets;
	
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



static void _removeObserver(id sender, NSString *name, id object, WINotificationCenterStorage *storage) {
	extern IMP						class_lookupMethod(Class, SEL);
	WINotificationCenterObserver	*observer, *nextObserver, *previousObserver;
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

		index = [name hash] % WINotificationCenterStorageBuckets;
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
		for(i = 0; i < WINotificationCenterStorageBuckets; i++) {
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
