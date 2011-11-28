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

#import <WiredAdditions/WIAutoreleasePool.h>
#import <WiredAdditions/WIFunctions.h>
#import <machine/param.h>
#import <pthread.h>

#define WIAutoreleasePoolArraySize \
	((NBPG - sizeof(unsigned int) - sizeof(void *)) / sizeof(void *))

#define WIAutoreleasePoolstackStorageBuckets		64
#define WIAutoreleasePoolstackInitialSize			4
#define WIAutoreleasePoolstackStorageInitialSize	4
#define WIAutoreleasePoolClassCacheSize				16


struct WIAutoreleasePoolArray {
	NSObject										*objects[WIAutoreleasePoolArraySize];
	unsigned int									length;
	
	struct WIAutoreleasePoolArray					*next;
};
typedef struct WIAutoreleasePoolArray				WIAutoreleasePoolArray;


struct WIAutoreleasePoolstack {
	WIAutoreleasePool								**pools;
	unsigned int									size;
	unsigned int									length;
	
	pthread_t										thread;
};
typedef struct WIAutoreleasePoolstack				WIAutoreleasePoolstack;


struct WIAutoreleasePoolstackStorage {
	WIAutoreleasePoolstack							**stacks[WIAutoreleasePoolstackStorageBuckets];
	unsigned int									sizes[WIAutoreleasePoolstackStorageBuckets];
	unsigned int									lengths[WIAutoreleasePoolstackStorageBuckets];

	pthread_mutex_t									mutex;
};
typedef struct WIAutoreleasePoolstackStorage		WIAutoreleasePoolstackStorage;


#define WINSAutoreleasePoolVars(pool) \
	((struct { @defs(NSAutoreleasePool) } *) pool)

#define WINSObjectVars(object) \
	((struct { @defs(NSObject) } *) object)


static WIAutoreleasePoolstackStorage				storage;


static inline pthread_t _thread(void);
static void _addPool(WIAutoreleasePool *);
static void _addPoolstack(WIAutoreleasePoolstack *);
static void _addPoolToPoolstack(WIAutoreleasePool *, WIAutoreleasePoolstack *);
static WIAutoreleasePoolstack * _poolstack(unsigned int *);
static WIAutoreleasePool * _pool(void);
static void _removePool(WIAutoreleasePool *);
static void _removePoolstack(WIAutoreleasePoolstack *, unsigned int);

void _WIAutoreleaseObject(id);
void _WIAutoreleaseNoPool(id);
void _WIPopAutoreleasePool(WIAutoreleasePool *);


@implementation WIAutoreleasePool

+ (void)activate {
	[self poseAsClass:[NSAutoreleasePool class]];
	
	WIReplaceSelectorInClass([NSObject class], @selector(autorelease), @selector(WI_autorelease));

	pthread_mutex_init(&storage.mutex, NULL);
}



+ (id)alloc {
	return NSAllocateObject(self, 0, NULL);
}



+ (id)allocWithZone:(NSZone *)zone {
	return NSAllocateObject(self, 0, zone);
}



- (id)init {
	WIAutoreleasePoolArray		*array;

	_addPool(self);
	
	array = (WIAutoreleasePoolArray *) malloc(sizeof(WIAutoreleasePoolArray));
	memset(array, 0, sizeof(WIAutoreleasePoolArray));
	WINSAutoreleasePoolVars(self)->_token = (void *) array;
	
	return self;
}



- (id)retain {
	WIAtomicIncrement((int *) &(WINSAutoreleasePoolVars(self)->_reserved));
	
	return self;
}



- (unsigned int)retainCount {
	return ((int) WINSAutoreleasePoolVars(self)->_reserved) + 1;
}



- (void)release {
	if(WIAtomicDecrement((int *) &(WINSAutoreleasePoolVars(self)->_reserved)) == -1)
		[self dealloc];
}



- (void)dealloc {
	WIAutoreleasePoolArray		*array, *nextArray;
	
	_removePool(self);
	_WIPopAutoreleasePool(self);
	
	array = WINSAutoreleasePoolVars(self)->_token;
	
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
	_WIAutoreleaseObject(object);
}



- (void)addObject:(id)object {
	_WIAutoreleaseObject(object);
}



#pragma mark -

static inline pthread_t _thread(void) {
	static pthread_t	(*pthread_self_p)();
	
	if(!pthread_self_p)
		pthread_self_p = pthread_self;
	
	return (*pthread_self_p)();
}



static void _addPool(WIAutoreleasePool *pool) {
	WIAutoreleasePoolstack		*stack;
	
	stack = _poolstack(NULL);
	
	if(!stack) {
		stack = malloc(sizeof(WIAutoreleasePoolstack));
		memset(stack, 0, sizeof(WIAutoreleasePoolstack));
		stack->thread = _thread();
		
		_addPoolstack(stack);
	}
	
	_addPoolToPoolstack(pool, stack);
}



static void _addPoolstack(WIAutoreleasePoolstack *stack) {
	unsigned int		index, size, length;
	
	index = ((unsigned long) _thread()) % WIAutoreleasePoolstackStorageBuckets;
	
	pthread_mutex_lock(&storage.mutex);
	
	size = storage.sizes[index];
	length = storage.lengths[index];
	
	if(length >= size) {
		size += size;
		
		if(size < WIAutoreleasePoolstackStorageInitialSize)
			size = WIAutoreleasePoolstackStorageInitialSize;
		
		storage.stacks[index] = realloc(storage.stacks[index],
										size * sizeof(WIAutoreleasePoolstack));
		storage.sizes[index] = size;
	}
	
	storage.stacks[index][length] = stack;
	storage.lengths[index] = ++length;

	pthread_mutex_unlock(&storage.mutex);
}



static void _addPoolToPoolstack(WIAutoreleasePool *pool, WIAutoreleasePoolstack *stack) {
	if(stack->length >= stack->size) {
		stack->size += stack->size;
		
		if(stack->size < WIAutoreleasePoolstackInitialSize)
			stack->size = WIAutoreleasePoolstackInitialSize;
		
		stack->pools = realloc(stack->pools, stack->size * sizeof(WIAutoreleasePool *));
	}
	
	stack->pools[stack->length] = pool;
	stack->length++;
}



static WIAutoreleasePool * _pool(void) {
	WIAutoreleasePoolstack		*stack;
	
	stack = _poolstack(NULL);
	
	if(!stack)
		return NULL;
	
	return stack->pools[stack->length - 1];
}



static WIAutoreleasePoolstack * _poolstack(unsigned int *stackIndex) {
	WIAutoreleasePoolstack		**stacks, *stack;
	pthread_t					thread;
	unsigned int				i, index, length;
	
	thread = _thread();
	index = ((unsigned long) thread) % WIAutoreleasePoolstackStorageBuckets;
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



static void _removePool(WIAutoreleasePool *pool) {
	WIAutoreleasePoolstack		*stack;
	WIAutoreleasePool			*p;
	unsigned int				i, breakIndex, stackIndex;
	
	stack = _poolstack(&stackIndex);
	
	if(!stack) {
		NSLog(@"*** WIAutoreleasePool: Orphaned pool in thread %p", _thread());
		
		return;
	}

	breakIndex = 0;
	
	for(i = stack->length - 1; i >= 0; --i) {
		p = stack->pools[i];
		
		if(p == pool) {
			stack->length	= i;
			breakIndex		= i;
		
			break;
		}
		
		[p release];
	}
	
	if(breakIndex == 0)
		_removePoolstack(stack, stackIndex);
}



static void _removePoolstack(WIAutoreleasePoolstack *stack, unsigned int stackIndex) {
	WIAutoreleasePoolstack		**stacks;
	unsigned int				index, length;

	index = ((unsigned long) _thread()) % WIAutoreleasePoolstackStorageBuckets;

	pthread_mutex_lock(&storage.mutex);
	
	length = storage.lengths[index] - 1;
	stacks = storage.stacks[index];
	stacks[stackIndex] = NULL;
	storage.lengths[index] = length;
	
	if(stackIndex < length) {
		memcpy(&stacks[stackIndex], &stacks[stackIndex + 1],
			   sizeof(WIAutoreleasePoolstack **) * length - 1);
	}

	if(stack->pools)
		free(stack->pools);

	free(stack);
	
	pthread_mutex_unlock(&storage.mutex);
}



#pragma mark -

void _WIAutoreleaseObject(id object) {
	WIAutoreleasePool			*pool;
	WIAutoreleasePoolArray		*array, *newArray;

	pool = _pool();
	
	if(!pool) {
		_WIAutoreleaseNoPool(object);
		
		return;
	}
	
	array = WINSAutoreleasePoolVars(pool)->_token;
	
	if(array->length >= WIAutoreleasePoolArraySize) {
		newArray = malloc(sizeof(WIAutoreleasePoolArray));
		memset(newArray, 0, sizeof(WIAutoreleasePoolArray));
		newArray->next = array;
		
		array = newArray;
		WINSAutoreleasePoolVars(pool)->_token = (void *) array;
	}
	
	array->objects[array->length] = object;
	array->length++;
}



void _WIAutoreleaseNoPool(id object) {
	NSLog(@"*** _WIAutoreleasePoolNoPool(): Object %p autoreleased with no pool in place in thread %p - just leaking",
		  object, _thread());
}



void _WIPopAutoreleasePool(WIAutoreleasePool *pool) {
	extern IMP					class_lookupMethod(Class, SEL);
	static IMP					(*class_lookupMethod_p)(Class, SEL);
	IMP							methods[WIAutoreleasePoolClassCacheSize];
	Class						classes[WIAutoreleasePoolClassCacheSize];
	WIAutoreleasePoolArray		*array;
	NSObject					**objects, *object;
	Class						class;
	SEL							selector;
	unsigned int				i, length, index;
	
	if(!class_lookupMethod_p)
		class_lookupMethod_p = class_lookupMethod;

	selector = @selector(release);
	array = WINSAutoreleasePoolVars(pool)->_token;
	memset(classes, 0, sizeof(classes));
	
	for(; array; array = array->next) {
		length = array->length;
		objects = array->objects;
		
		for(i = 0; i < length; i++) {
			object = *objects++;
			class = WINSObjectVars(object)->isa;
			index = ((unsigned long) class >> 4) & (WIAutoreleasePoolClassCacheSize - 1);
			
			if(classes[index] != class) {
				methods[index] = (*class_lookupMethod_p)(class, selector);
				classes[index] = class;
			}
			
			(*methods[index])(object, selector);
		}
	}
}

@end



@implementation NSObject(WIAutoreleasePool)

- (id)WI_autorelease {
	_WIAutoreleaseObject(self);
	
	return self;
}

@end
