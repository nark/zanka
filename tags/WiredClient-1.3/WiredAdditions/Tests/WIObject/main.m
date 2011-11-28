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
void benchmark1(unsigned int);
void benchmark2(unsigned int);


int main(int argc, const char *argv[]) {
	NSAutoreleasePool		*pool;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	printf("-> Running conformance tests\n");
	[WITestConformance test:test1 label:@"WIObject: verifying retain count"];
	[WITestConformance test:test2 label:@"WIObject: verifying dealloc"];

	printf("-> Running performance tests\n");
	benchmark1(5000000);
	benchmark2(10000000);

	[pool release];
	
	return 0;
}



BOOL test1(void) {
	WIObject			*object;
	BOOL				passed;

	object = [[WIObject alloc] init];
	passed = ([object retainCount] == 1);
	[object retain];
	if(passed)
		passed = ([object retainCount] == 2);
	[object release];
	if(passed)
		passed = ([object retainCount] == 1);
	[object release];
	
	return passed;
}


static BOOL		WITest2Check;


@interface WITest2Object : WIObject

@end


@implementation WITest2Object

- (void)dealloc {
	WITest2Check = YES;
	
	[super dealloc];
}

@end

BOOL test2(void) {
	WITest2Object		*object;
	
	object = [[WITest2Object alloc] init];
	[object release];
	
	return WITest2Check;
}



void benchmark1(unsigned int count) {
	NSAutoreleasePool	*pool;
	WITestStopwatch		*watch;
	id					object;
	double				t;
	unsigned int		i;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];

	[watch start:@"NSObject: creating/removing %u times", count];
	for(i = 0; i < count; i++) {
		object = [[NSObject alloc] init];
		[object release];
	}
	t = [watch stop];

	[watch start:@"WIObject: creating/removing %u times", count];
	for(i = 0; i < count; i++) {
		object = [[WIObject alloc] init];
		[object release];
	}
	[watch stopAndCompare:t];

	[watch release];
	[pool release];
}



void benchmark2(unsigned int count) {
	NSAutoreleasePool	*pool;
	WITestStopwatch		*watch;
	id					object;
	double				t;
	unsigned int		i;
	
	pool = [[NSAutoreleasePool alloc] init];
	watch = [[WITestStopwatch alloc] init];
	
	[watch start:@"NSObject: retaining/releasing %u times", count];
	object = [[NSObject alloc] init];
	for(i = 0; i < count; i++)
		[[object retain] release];
	[object release];
	t = [watch stop];
	
	[watch start:@"WIObject: retaining/releasing %u times", count];
	object = [[WIObject alloc] init];
	for(i = 0; i < count; i++)
		[[object retain] release];
	[object release];
	[watch stopAndCompare:t];
	
	[watch release];
	[pool release];
}
