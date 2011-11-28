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

#import <ZankaAdditions/ZAAutoreleasePool.h>
#import <ZankaAdditions/ZAFunctions.h>
#import <ppc/param.h>
#import <pthread.h>

#define ZAAutoreleasePoolArraySize \
	((NBPG - sizeof(unsigned int) - sizeof(void *)) / sizeof(void *))

#define ZAAutoreleasePoolstackStorageBuckets		64
#define ZAAutoreleasePoolstackInitialSize			4
#define ZAAutoreleasePoolstackStorageInitialSize	4
#define ZAAutoreleasePoolClassCacheSize				16


struct ZAAutoreleasePoolArray {
	NSObject										*objects[ZAAutoreleasePoolArraySize];
	unsigned int									length;
	
	struct ZAAutoreleasePoolArray					*next;
};
typedef struct ZAAutoreleasePoolArray				ZAAutoreleasePoolArray;


struct ZAAutoreleasePoolstack {
	ZAAutoreleasePool								**pools;
	unsigned int									size;
	unsigned int									length;
	
	pthread_t										thread;
};
typedef struct ZAAutoreleasePoolstack				ZAAutoreleasePoolstack;


struct ZAAutoreleasePoolstackStorage {
	ZAAutoreleasePoolstack							**stacks[ZAAutoreleasePoolstackStorageBuckets];
	unsigned int									sizes[ZAAutoreleasePoolstackStorageBuckets];
	unsigned int									lengths[ZAAutoreleasePoolstackStorageBuckets];

	pthread_mutex_t									mutex;
};
typedef struct ZAAutoreleasePoolstackStorage		ZAAutoreleasePoolstackStorage;


#define ZANSAutoreleasePoolVars(pool) \
	((struct { @defs(NSAutoreleasePool) } *) pool)

#define ZANSObjectVars(object) \
	((struct { @defs(NSObject) } *) object)


static ZAAutoreleasePoolstackStorage				storage;


static inline pthread_t _thread(void);
static void _addPool(ZAAutoreleasePool *);
static void _addPoolstack(ZAAutoreleasePoolstack *);
static void _addPoolToPoolstack(ZAAutoreleasePool *, ZAAutoreleasePoolstack *);
static ZAAutoreleasePoolstack * _poolstack(unsigned int *);
static ZAAutoreleasePool * _pool(void);
static void _removePool(ZAAutoreleasePool *);
static void _removePoolstack(ZAAutoreleasePoolstack *, unsigned int);

void _ZAAutoreleaseObject(id);
void _ZAAutoreleaseNoPool(id);
void _ZAPopAutoreleasePool(ZAAutoreleasePool *);


@implementation ZAAutoreleasePool

+ (void)activate {
	[self poseAsClass:[NSAutoreleasePool class]];
	
	ZAReplaceSelectorInClass([NSObject class], @selector(autorelease), @selector(ZA_autorelease));

	pthread_mutex_init(&storage.mutex, NULL);
}



+ (id)alloc {
	return NSAllocateObject(self, 0, NULL);
}



+ (id)allocWithZone:(NSZone *)zone {
	return NSAllocateObject(self, 0, zone);
}



- (id)init {
	ZAAutoreleasePoolArray		*array;

	_addPool(self);
	
	array = (ZAAutoreleasePoolArray *) malloc(sizeof(ZAAutoreleasePoolArray));
	memset(array, 0, sizeof(ZAAutoreleasePoolArray));
	ZANSAutoreleasePoolVars(self)->_token = (void *) array;
	
	return self;
}



- (id)retain {
	ZAAtomicIncrement((int *) &(ZANSAutoreleasePoolVars(self)->_reserved));
	
	return self;
}



- (unsigned int)retainCount {
	return ((int) ZANSAutoreleasePoolVars(self)->_reserved) + 1;
}



- (void)release {
	if(ZAAtomicDecrement((int *) &(ZANSAutoreleasePoolVars(self)->_reserved)) == -1)
		[self dealloc];
}



- (void)dealloc {
	ZAAutoreleasePoolArray		*array, *nextArray;
	
	_removePool(self);
	_ZAPopAutoreleasePool(self);
	
	array = ZANSAutoreleasePoolVars(self)->_token;
	
	for(; array; array = nextArray) {
		nextArray = array->next;
		free(array);
	}
	
	NSDeallocateObject(self);
	
	if(NO)
		[super dealloc];
}



#pragma mark -

+ (void)addObject:(id)object {
	_ZAAutoreleaseObject(object);
}



- (void)addObject:(id)object {
	_ZAAutoreleaseObject(object);
}



#pragma mark -

static inline pthread_t _thread(void) {
	static pthread_t	(*pthread_self_p)();
	
	if(!pthread_self_p)
		pthread_self_p = pthread_self;
	
	return (*pthread_self_p)();
}



static void _addPool(ZAAutoreleasePool *pool) {
	ZAAutoreleasePoolstack		*stack;
	
	stack = _poolstack(NULL);
	
	if(!stack) {
		stack = malloc(sizeof(ZAAutoreleasePoolstack));
		memset(stack, 0, sizeof(ZAAutoreleasePoolstack));
		stack->thread = _thread();
		
		_addPoolstack(stack);
	}
	
	_addPoolToPoolstack(pool, stack);
}



static void _addPoolstack(ZAAutoreleasePoolstack *stack) {
	unsigned int		index, size, length;
	
	index = ((unsigned long) _thread()) % ZAAutoreleasePoolstackStorageBuckets;
	
	pthread_mutex_lock(&storage.mutex);
	
	size = storage.sizes[index];
	length = storage.lengths[index];
	
	if(length >= size) {
		size += size;
		
		if(size < ZAAutoreleasePoolstackStorageInitialSize)
			size = ZAAutoreleasePoolstackStorageInitialSize;
		
		storage.stacks[index] = realloc(storage.stacks[index],
										size * sizeof(ZAAutoreleasePoolstack));
		storage.sizes[index] = size;
	}
	
	storage.stacks[index][length] = stack;
	storage.lengths[index] = ++length;

	pthread_mutex_unlock(&storage.mutex);
}



static void _addPoolToPoolstack(ZAAutoreleasePool *pool, ZAAutoreleasePoolstack *stack) {
	if(stack->length >= stack->size) {
		stack->size += stack->size;
		
		if(stack->size < ZAAutoreleasePoolstackInitialSize)
			stack->size = ZAAutoreleasePoolstackInitialSize;
		
		stack->pools = realloc(stack->pools, stack->size * sizeof(ZAAutoreleasePool *));
	}
	
	stack->pools[stack->length] = pool;
	stack->length++;
}



static ZAAutoreleasePool * _pool(void) {
	ZAAutoreleasePoolstack		*stack;
	
	stack = _poolstack(NULL);
	
	if(!stack)
		return NULL;
	
	return stack->pools[stack->length - 1];
}



static ZAAutoreleasePoolstack * _poolstack(unsigned int *stackIndex) {
	ZAAutoreleasePoolstack		**stacks, *stack;
	pthread_t					thread;
	unsigned int				i, index, length;
	
	thread = _thread();
	index = ((unsigned long) thread) % ZAAutoreleasePoolstackStorageBuckets;
	stacks = storage.stacks[index];
	length = storage.lengths[index];
	
	for(i = 0; i < length; i++) {
		stack = *stacks++;
		
		if(stack->thread == thread) {
			if(stackIndex)
				*stackIndex = i;
			
			return stack;
		}
	}
	
	return NULL;
}



static void _removePool(ZAAutoreleasePool *pool) {
	ZAAutoreleasePoolstack		*stack;
	ZAAutoreleasePool			*p;
	unsigned int				i, offset, stackIndex;
	
	stack = _poolstack(&stackIndex);
	
	if(!stack) {
		NSLog(@"*** ZAAutoreleasePool: Orphaned pool in thread %p", _thread());
		
		return;
	}
	
	for(i = stack->length - 1, offset = 0; i >= 0; --i) {
		p = stack->pools[i];
		
		if(p == pool) {
			stack->length = i;
			offset = 0;
		
			break;
		}
		
		[p release];
	}
	
	if(offset == 0)
		_removePoolstack(stack, stackIndex);
}



static void _removePoolstack(ZAAutoreleasePoolstack *stack, unsigned int stackIndex) {
	ZAAutoreleasePoolstack		**stacks;
	unsigned int				index, length;

	index = ((unsigned long) _thread()) % ZAAutoreleasePoolstackStorageBuckets;

	pthread_mutex_lock(&storage.mutex);
	
	length = storage.lengths[index] - 1;
	stacks = storage.stacks[index];
	stacks[stackIndex] = NULL;
	storage.lengths[index] = length;
	
	if(stackIndex < length) {
		memcpy(&stacks[stackIndex], &stacks[stackIndex + 1],
			   sizeof(ZAAutoreleasePoolstack **) * length - 1);
	}
	
	pthread_mutex_unlock(&storage.mutex);
}



#pragma mark -

void _ZAAutoreleaseObject(id object) {
	ZAAutoreleasePool			*pool;
	ZAAutoreleasePoolArray		*array, *newArray;

	pool = _pool();
	
	if(!pool) {
		_ZAAutoreleaseNoPool(object);
		
		return;
	}
	
	array = ZANSAutoreleasePoolVars(pool)->_token;
	
	if(array->length >= ZAAutoreleasePoolArraySize) {
		newArray = malloc(sizeof(ZAAutoreleasePoolArray));
		memset(newArray, 0, sizeof(ZAAutoreleasePoolArray));
		newArray->next = array;
		
		array = newArray;
		ZANSAutoreleasePoolVars(pool)->_token = (void *) array;
	}
	
	array->objects[array->length] = object;
	array->length++;
}



void _ZAAutoreleaseNoPool(id object) {
	NSLog(@"*** _ZAAutoreleasePoolNoPool(): Object %p autoreleased with no pool in place in thread %p - just leaking",
		  object, _thread());
}



void _ZAPopAutoreleasePool(ZAAutoreleasePool *pool) {
	extern IMP					class_lookupMethod(Class, SEL);
	static IMP					(*class_lookupMethod_p)(Class, SEL);
	IMP							methods[ZAAutoreleasePoolClassCacheSize];
	Class						classes[ZAAutoreleasePoolClassCacheSize];
	ZAAutoreleasePoolArray		*array;
	NSObject					**objects, *object;
	Class						class;
	SEL							selector;
	unsigned int				i, length, index;
	
	if(!class_lookupMethod_p)
		class_lookupMethod_p = class_lookupMethod;

	selector = @selector(release);
	array = ZANSAutoreleasePoolVars(pool)->_token;
	memset(classes, 0, sizeof(classes));
	
	for(; array; array = array->next) {
		length = array->length;
		objects = array->objects;
		
		for(i = 0; i < length; i++) {
			object = *objects++;
			class = ZANSObjectVars(object)->isa;
			index = ((unsigned long) class >> 4) & (ZAAutoreleasePoolClassCacheSize - 1);
			
			if(classes[index] != class) {
				methods[index] = (*class_lookupMethod_p)(class, selector);
				classes[index] = class;
			}
			
			(*methods[index])(object, selector);
		}
	}
}

@end



@implementation NSObject(ZAAutoreleasePool)

- (id)ZA_autorelease {
	_ZAAutoreleaseObject(self);
	
	return self;
}

@end
