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

#import <WiredAdditions/NSApplication-WIAdditions.h>
#import <WiredAdditions/NSObject-WIAdditions.h>
#import <WiredAdditions/NSTextView-WIAdditions.h>
#import <WiredAdditions/WIApplication.h>

@interface WIApplication(Private)

- (NSString *)_terminationDelayStringValue;

@end


@implementation WIApplication(Private)

- (void)_terminationDelayTimer:(NSTimer *)timer {
	_terminationDelay--;
	
	if(_terminationDelay > 0.0) {
		[[[[[NSApp keyWindow] contentView] subviews] objectAtIndex:2] setStringValue:
			[self _terminationDelayStringValue]];
	} else {
		[NSApp abortModal];
		[timer invalidate];
	}
}



- (NSString *)_terminationDelayStringValue {
	return [NSSWF:WILS(@"If you do nothing, %@ will quit automatically in %.0f seconds.",
					   @"WIApplication: termination delay panel (application, timeout)"),
		[self name],
		_terminationDelay];
}

@end



@implementation WIApplication

+ (void)load {
	wi_initialize();
}



- (void)finishLaunching {
	NSArray			*arguments;
	const char		**argv;
	int				i, argc;
	
	arguments	= [[NSProcessInfo processInfo] arguments];
	argc		= [arguments count];
	argv		= malloc(argc);
	
	for(i = 0; i < argc; i++)
		argv[i] = [[arguments objectAtIndex:i] UTF8String];
	
	wi_load(argc, argv);
	free(argv);

	wi_log_stderr = true;
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WI_applicationDidBecomeActive:)
			   name:NSApplicationDidBecomeActiveNotification
			 object:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(_WI_applicationDidResignActive:)
			   name:NSApplicationDidResignActiveNotification
			 object:NULL];
	
	if([[self delegate] respondsToSelector:@selector(applicationDidChangeActiveStatus:)]) {
		[[NSNotificationCenter defaultCenter]
			addObserver:[self delegate]
			   selector:@selector(applicationDidChangeActiveStatus:)
				   name:WIApplicationDidChangeActiveNotification
				 object:NULL];
	}
	
	[super finishLaunching];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
				  name:NSApplicationDidBecomeActiveNotification
				object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:self
				  name:NSApplicationDidResignActiveNotification
				object:NULL];

	[[NSNotificationCenter defaultCenter]
		removeObserver:[self delegate]
				  name:WIApplicationDidChangeActiveNotification
				object:NULL];
	
	[_releaseNotesWindow release];
	
	[super dealloc];
}



#pragma mark -

- (void)_WI_applicationDidBecomeActive:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WIApplicationDidChangeActiveNotification
		object:self];
}



- (void)_WI_applicationDidResignActive:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter]
		postNotificationName:WIApplicationDidChangeActiveNotification
		object:self];
}



#pragma mark -

- (void)sendEvent:(NSEvent *)event {
	switch([event type]) {
		case NSFlagsChanged:
			[super sendEvent:event];
			
			[[NSNotificationCenter defaultCenter]
				postNotificationName:WIApplicationDidChangeFlagsNotification
				object:event];
			break;
			
		default:
			[super sendEvent:event];
			break;
	}
}



#pragma mark -

- (NSApplicationTerminateReply)runTerminationDelayPanelWithTimeInterval:(NSTimeInterval)delay {
	NSPanel		*panel;
	NSTimer		*timer;
	int			result;
	
	_terminationDelay = delay;

	timer = [NSTimer timerWithTimeInterval:1.0
									target:self
								  selector:@selector(_terminationDelayTimer:)
								  userInfo:NULL
								   repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];

	panel = NSGetAlertPanel(WILS(@"Are you sure you want to quit?", @"WIApplication: termination delay panel"),
							[self _terminationDelayStringValue],
							WILS(@"Quit", @"WIApplication: termination delay panel"),
							WILS(@"Cancel", @"WIApplication: termination delay panel"),
							NULL);
	result = [self runModalForWindow:panel];
	NSReleaseAlertPanel(panel);
	
	[timer invalidate];
	
	if(result == NSAlertDefaultReturn || result == NSRunAbortedResponse)
		return NSTerminateNow;
	
	return NSTerminateCancel;
}



#pragma mark -

- (IBAction)orderFrontReleaseNotesWindow:(id)sender {
	NSAttributedString	*string;
	NSString			*path;
	
	if(!_releaseNotesWindow) {
		[NSBundle loadNibFile:[[WIObject bundle] pathForResource:@"ReleaseNotes" ofType:@"nib"]
			externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"]
					 withZone:NULL];

		path = [[NSBundle mainBundle] pathForResource:@"ReleaseNotes" ofType:@"rtf"];
		string = [[NSAttributedString alloc] initWithRTF:[NSData dataWithContentsOfFile:path]
									  documentAttributes:NULL];
		
		
		[_releaseNotesTextView setAttributedString:string];
		[string release];
	}
	
	[_releaseNotesWindow makeKeyAndOrderFront:self];
}

@end
