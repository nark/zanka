/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Axel Andersson
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

#import <WiredAdditions/WIExceptionHandler.h>

@implementation WIExceptionHandler

+ (id)sharedExceptionHandler {
	static WIExceptionHandler	*sharedExceptionHandler;
	
	if(!sharedExceptionHandler)
		sharedExceptionHandler = [[self alloc] init];
	
	return sharedExceptionHandler;
}



#pragma mark -

- (BOOL)exceptionHandler:(NSExceptionHandler *)exceptionHandler shouldLogException:(NSException *)exception mask:(NSUInteger)mask {
	NSArray			*stacks;
	NSString		*trace;
	FILE			*fp;
	char			buffer[BUFSIZ];
	NSUInteger		i = 0;

	trace = [[exception userInfo] objectForKey:NSStackTraceKey];
	
	if(trace) {
		stacks = [trace componentsSeparatedByString:@"  "];
		fp = popen([[NSSWF:@"/usr/bin/atos -p %d %@", getpid(), trace] UTF8String], "r");
		
		if(fp) {
			while(fgets(buffer, (int) sizeof(buffer), fp) != NULL) {
				NSLog(@"%d%*s%@ in %s",
					  i,
					  i < 10 ? 3 : i < 100 ? 2 : i < 1000 ? 3 : 1,
					  " ",
					  [stacks objectAtIndex:i],
					  buffer);
				
				i++;
			}
			
			pclose(fp);
		} else {
			NSLog(@"*** %@: popen() failed", [self class]);
		}
	} else {
		NSLog(@"*** %@: Exception has no backtrace", [self class]);
	}
	
	return NO;
}



#pragma mark

- (void)enable {
	[self enableWithMask:(NSLogUncaughtExceptionMask |
						  NSLogUncaughtSystemExceptionMask |
						  NSLogUncaughtRuntimeErrorMask |
						  NSLogTopLevelExceptionMask |
						  NSLogOtherExceptionMask)];
}



- (void)enableWithMask:(NSUInteger)mask {
	[[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
	[[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:mask];
}

@end
