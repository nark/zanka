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

#import <ZankaAdditions/NSWorkspace-ZAAdditions.h>

@implementation NSWorkspace(ZAWorkspaceAdditions)

- (NSNumber *)processIdentifierOfCommand:(NSString *)processName {
	struct kinfo_proc	*procs = NULL;
	const char			*name;
	size_t				size;
	pid_t				pid = 0;
	int					i, entries;
	int					mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
	
	if(sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
		NSLog(@"sysctl: %s", strerror(errno));
		
		goto end;
	}
	
	entries = size / sizeof(struct kinfo_proc);
	procs = (struct kinfo_proc *) malloc(size);
	
	if(sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
		NSLog(@"sysctl: %s", strerror(errno));
		
		goto end;
	}
	
	name = [processName UTF8String];
	
	for(i = 0; i < entries; i++) {
		if(strcmp(procs[i].kp_proc.p_comm, name) == 0) {
			pid = procs[i].kp_proc.p_pid;
			
			goto end;
		}
	}

end:
	if(procs)
		free(procs);
	
	return pid ? [NSNumber numberWithInt:pid] : NULL;
}



#pragma mark -

- (void)addAutoLaunchedApplication:(NSString *)path hide:(BOOL)hide {
	NSUserDefaults			*defaults;
	NSEnumerator			*enumerator;
	NSMutableDictionary		*domain;
	NSMutableArray			*applications;
	NSDictionary			*application;
	BOOL					found = NO;

	defaults = [NSUserDefaults standardUserDefaults];
	domain = [[[defaults persistentDomainForName:@"loginwindow"] mutableCopy] autorelease];
	
	if(!domain)
		domain = [NSMutableDictionary dictionary];

	applications = [[[domain objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy] autorelease];
	
	if(!applications)
		applications = [NSMutableArray array];
	
	enumerator = [applications objectEnumerator];
	
	while((application = [enumerator nextObject])) {
		if([[application objectForKey:@"Path"] isEqualToString:path]) {
			found = YES;
			
			break;
		}
	}
	
	if(!found) {
		[applications addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:hide], @"Hide",
			path,							@"Path",
			NULL]];
		[domain setObject:applications forKey:@"AutoLaunchedApplicationDictionary"];
		
		[defaults removePersistentDomainForName:@"loginwindow"];
		[defaults setPersistentDomain:domain forName:@"loginwindow"];
		[defaults synchronize];
	}
}



- (void)removeAutoLaunchedApplication:(NSString *)path {
	NSUserDefaults			*defaults;
	NSEnumerator			*enumerator;
	NSMutableDictionary		*domain;
	NSMutableArray			*applications;
	NSDictionary			*application;
	int						i = 0, index = -1;

	defaults = [NSUserDefaults standardUserDefaults];
	domain = [[[defaults persistentDomainForName:@"loginwindow"] mutableCopy] autorelease];
	
	if(!domain)
		domain = [NSMutableDictionary dictionary];

	applications = [[[domain objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy] autorelease];
	
	if(!applications)
		applications = [NSMutableArray array];
	
	enumerator = [applications objectEnumerator];
	
	while((application = [enumerator nextObject])) {
		if([[application objectForKey:@"Path"] isEqualToString:path]) {
			index = i;
			
			break;
		}
		
		i++;
	}
	
	if(index >= 0) {
		[applications removeObjectAtIndex:index];
		[domain setObject:applications forKey:@"AutoLaunchedApplicationDictionary"];
		
		[defaults removePersistentDomainForName:@"loginwindow"];
		[defaults setPersistentDomain:domain forName:@"loginwindow"];
		[defaults synchronize];
	}
}

@end
