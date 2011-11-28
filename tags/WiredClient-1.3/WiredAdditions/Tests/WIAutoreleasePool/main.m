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
void benchmark1(unsigned int, unsigned int);
void benchmark2(unsigned int, unsigned int);


id		*storage;


int main(int argc, const char *argv[]) {
	NSAutoreleasePool		*pool;
	WITestStopwatch			*watch;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	printf("-> Running conformance tests\n");
	[WITestConformance test:test1 label:@"WIAutoreleasePool: verifying retain count after autorelease"];
	[WITestConformance test:test2 label:@"WIAutoreleasePool: verifying retain count after autorelease, many objects"];

	watch = [[WITestStopwatch alloc] init];
	[watch start:@"-> Generating objects for performance tests"];
	storage = [WITestStorage storageWithSize:1000];
	[watch stop];
	
	printf("-> Running performance tests\n");
	benchmark1(10000, 1000);
	benchmark2(10000, 1000);

	[pool release];
	
	return 0;
}



BOOL test1(void) {
	WIAutoreleasePool	*pool;
	NSObject			*object;
	BOOL				passed;

	pool = [[WIAutoreleasePool alloc] init];
	object = [[[WIObject alloc] init] retain];
	[pool addObject:object];
	[pool release];
	passed = ([object retainCount] == 1);
	[object release];
	
	return passed;
}



BOOL test2(void) {
	WIAutoreleasePool	*pool;
	NSObject			*objects[10];
	BOOL				passed = YES;
	int					i;

	pool = [[WIAutoreleasePool alloc] init];
	for(i = 0; i < 10; i++) {
		objects[i] = [[[WIObject alloc] init] retain];
		[pool addObject:objects[i]];
	}
	[pool release];
	
	for(i = 0; i < 10; i++) {
		if(passed)
			passed = ([objects[i] retainCount] == 1);
		[objects[i] release];
	}
	
	return passed;
}



void benchmark1(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSAutoreleasePool		*pool1;
	WIAutoreleasePool		*pool2;
	WITestStopwatch			*watch;
	double					t1, t2;
	unsigned int			i, j;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	[watch start:@"NSAutoreleasePool: adding %u objects", loops * n];
	pool1 = [[NSAutoreleasePool alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[storage[i] retain];
			[pool1 addObject:storage[i]];
		}
	}
	t1 = [watch stop];
	
	[watch start:@"NSAutoreleasePool: releasing %u objects", loops * n];
	[pool1 release];
	t2 = [watch stop];

	[watch start:@"WIAutoreleasePool: adding %u objects", loops * n];
	pool2 = [[WIAutoreleasePool alloc] init];
	for(j = 0; j < loops; j++) {
		for(i = 0; i < n; i++) {
			[storage[i] retain];
			[pool2 addObject:storage[i]];
		}
	}
	[watch stopAndCompare:t1];
	
	[watch start:@"WIAutoreleasePool: releasing %u objects", loops * n];
	[pool2 release];
	[watch stopAndCompare:t2];
	
	[watch release];
	[pool release];
}



void benchmark2(unsigned int loops, unsigned int n) {
	NSAutoreleasePool		*pool;
	NSAutoreleasePool		*pool1;
	WIAutoreleasePool		*pool2;
	WITestStopwatch			*watch;
	double					t1;
	unsigned int			i, j;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	[watch start:@"NSAutoreleasePool: creating %u pools, adding %u objects to each, releasing", loops, n];
	for(j = 0; j < loops; j++) {
		pool1 = [[NSAutoreleasePool alloc] init];
		for(i = 0; i < n; i++) {
			[storage[i] retain];
			[pool1 addObject:storage[i]];
		}
		[pool1 release];
	}
	t1 = [watch stop];
	
	[watch start:@"WIAutoreleasePool: creating %u pools, adding %u objects to each, releasing", loops, n];
	for(j = 0; j < loops; j++) {
		pool2 = [[WIAutoreleasePool alloc] init];
		for(i = 0; i < n; i++) {
			[storage[i] retain];
			[pool2 addObject:storage[i]];
		}
		[pool2 release];
	}
	[watch stopAndCompare:t1];
	
	[watch release];
	[pool release];
}
