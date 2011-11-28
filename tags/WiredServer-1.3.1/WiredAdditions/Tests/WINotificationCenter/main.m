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

BOOL test1(void);
BOOL test2(void);
BOOL test3(void);
void benchmark1(unsigned int, unsigned int);
void benchmark2(unsigned int, unsigned int);
void benchmark3(unsigned int, unsigned int);
void benchmark4(unsigned int, unsigned int);


id		*storage;


int main(int argc, const char *argv[]) {
	NSAutoreleasePool		*pool;
	WITestStopwatch			*watch;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	printf("-> Running conformance tests\n");
	[WITestConformance test:test1 label:@"WINotificationCenter: verifying postNotificationName:"];
	[WITestConformance test:test2 label:@"WINotificationCenter: verifying removeObserver:"];
	[WITestConformance test:test3 label:@"WINotificationCenter: verifying postNotificationName:object:"];

	watch = [[WITestStopwatch alloc] init];
	[watch start:@"-> Generating objects for performance tests"];
	storage = [WITestStorage storageWithSize:1000];
	[watch stop];

	printf("-> Running performance tests\n");
	benchmark1(10000, 100);
	benchmark2(1000, 500);
	benchmark3(10000, 50);
	benchmark4(20000, 10);

	[pool release];
	
	return 0;
}



static BOOL		WITest1Check;


@interface WITest1Object : WIObject

@end


@implementation WITest1Object

- (void)test:(NSNotification *)notification {
	if([notification object] != self)
		return;
	
	if(![[notification name] isEqualToString:@"test"])
		return;
	
	if(![[[notification userInfo] objectForKey:@"test"] isEqualToString:@"test"])
		return;
	
	WITest1Check = YES;
}

@end


BOOL test1(void) {
	WINotificationCenter	*center;
	WITest1Object			*object;
	
	center = [[WINotificationCenter alloc] init];
	object = [[WITest1Object alloc] init];
	[center addObserver:object selector:@selector(test:) name:@"test" object:NULL];
	[center postNotificationName:@"test" object:object userInfo:[NSDictionary dictionaryWithObject:@"test" forKey:@"test"]];
	[center removeObserver:object];
	[object release];
	[center release];
	
	return WITest1Check;
}



static BOOL		WITest2Check;


@interface WITest2Object : WIObject

@end


@implementation WITest2Object

- (void)test:(NSNotification *)notification {
	WITest2Check = YES;
}

@end

BOOL test2(void) {
	WINotificationCenter	*center;
	WITest2Object			*object;
	
	center = [[WINotificationCenter alloc] init];
	object = [[WITest2Object alloc] init];
	[center addObserver:object selector:@selector(test:) name:@"test" object:NULL];
	[center removeObserver:object];
	[center postNotificationName:@"test" object:NULL];
	[object release];
	[center release];
	
	return !WITest2Check;
}



static BOOL		WITest3Check;


@interface WITest3Object : WIObject

@end


@implementation WITest3Object

- (void)test:(NSNotification *)notification {
	WITest3Check = !WITest3Check;
}

@end


BOOL test3(void) {
	WINotificationCenter	*center;
	WITest3Object			*object;
	
	center = [[WINotificationCenter alloc] init];
	object = [[WITest3Object alloc] init];
	[center addObserver:object selector:@selector(test:) name:@"test" object:object];
	[center postNotificationName:@"test" object:center];
	[center postNotificationName:@"test" object:object];
	[object release];
	[center release];
	
	return WITest3Check;
}



@implementation NSObject(WIBenchmark)

- (void)dummy:(NSNotification *)notification {
}

@end


void benchmark1(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSNotificationCenter	*center1;
	NSNotificationCenter	*center2;
	WITestStopwatch			*watch;
	double					t1;
	unsigned int			i, j;

	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	[watch start:@"NSNotificationCenter: adding/removing observer %u times", loops * n];
	center1 = [[NSNotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[center1 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center1 removeObserver:storage[i]];
		}
	}
	[center1 release];
	t1 = [watch stop];
	
	[watch start:@"WINotificationCenter: adding/removing observer %u times", loops * n];
	center2 = [[WINotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[center2 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center2 removeObserver:storage[i]];
		}
	}
	[center2 release];
	[watch stopAndCompare:t1];
	
	[watch release];
	[pool release];
}



void benchmark2(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSNotificationCenter	*center1;
	NSNotificationCenter	*center2;
	WITestStopwatch			*watch;
	double					t1;
	unsigned int			i, j, k;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	[watch start:@"NSNotificationCenter: adding %u observers, removing, %u times", 10, loops * n];
	center1 = [[NSNotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			for(k = 0; k < 10; k++)
				[center1 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center1 removeObserver:storage[i]];
		}
	}
	[center1 release];
	t1 = [watch stop];
	
	[watch start:@"WINotificationCenter: adding %u observers, removing, %u times", 10, loops * n];
	center2 = [[WINotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			for(k = 0; k < 10; k++)
				[center2 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center2 removeObserver:storage[i]];
		}
	}
	[center2 release];
	[watch stopAndCompare:t1];
	
	[watch release];
	[pool release];
}



void benchmark3(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSNotificationCenter	*center1;
	NSNotificationCenter	*center2;
	NSDictionary			*userInfo;
	WITestStopwatch			*watch;
	double					t1;
	unsigned int			i, j;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	userInfo = [NSDictionary dictionaryWithObject:@"appa" forKey:@"key"];
	
	[watch start:@"NSNotificationCenter: adding observer, notifying, removing, %u times", loops * n];
	center1 = [[NSNotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[center1 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center1 postNotificationName:@"foo" object:NULL userInfo:userInfo];
			[center1 removeObserver:storage[i]];
		}
	}
	[center1 release];
	t1 = [watch stop];
	
	[watch start:@"WINotificationCenter: adding observer, notifying, removing, %u times", loops * n];
	center2 = [[WINotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[center2 addObserver:storage[i] selector:@selector(dummy:) name:@"foo" object:NULL];
			[center2 postNotificationName:@"foo" object:NULL userInfo:userInfo];
			[center2 removeObserver:storage[i]];
		}
	}
	[center2 release];
	[watch stopAndCompare:t1];
	
	[watch release];
	[pool release];
}



void benchmark4(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSNotificationCenter	*center1;
	NSNotificationCenter	*center2;
	NSDictionary			*userInfo;
	WITestStopwatch			*watch;
	NSString				*strings[10];
	double					t1;
	unsigned int			i, j, k;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	userInfo = [NSDictionary dictionaryWithObject:@"value" forKey:@"key"];
	
	for(k = 0; k < 10; k++)
		strings[k] = [NSString stringWithFormat:@"%u", k];
	
	[watch start:@"NSNotificationCenter: add %u observers, notify %u times, remove, %u times", 10, 10, loops * n];
	center1 = [[NSNotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			for(k = 0; k < 10; k++)
				[center1 addObserver:storage[i] selector:@selector(dummy:) name:strings[k] object:NULL];
			for(k = 0; k < 10; k++)
				[center1 postNotificationName:strings[k] object:NULL userInfo:userInfo];
			[center1 removeObserver:storage[i]];
		}
	}
	[center1 release];
	t1 = [watch stop];
	
	[watch start:@"WINotificationCenter: add %u observers, notify %u times, remove, %u times", 10, 10, loops * n];
	center2 = [[WINotificationCenter alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			for(k = 0; k < 10; k++)
				[center2 addObserver:storage[i] selector:@selector(dummy:) name:strings[k] object:NULL];
			for(k = 0; k < 10; k++)
				[center2 postNotificationName:strings[k] object:NULL userInfo:userInfo];
			[center2 removeObserver:storage[i]];
		}
	}
	[center2 release];
	[watch stopAndCompare:t1];
	
	[watch release];
	[pool release];
}
