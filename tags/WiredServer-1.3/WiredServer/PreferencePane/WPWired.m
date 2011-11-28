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

#import "WCAccountsController.h"
#import "WCConfigController.h"
#import "WCDashboardController.h"
#import "WCLogController.h"
#import "WCSettings.h"
#import "WCStatusController.h"
#import "WPWired.h"

@interface WPWired(Private)

- (void)_save;

@end


@implementation WPWired(Private)

- (void)_save {
	if([_configController saveFromController])
		[_accountsController saveFromController];
}

@end


@implementation WPWired

+ (void)load {
	NSBundle	*bundle, *wiredBundle;
	NSString	*path;
	
	bundle = [NSBundle bundleForClass:[self class]];
	path = [[bundle privateFrameworksPath] stringByAppendingPathComponent:@"WiredAdditions.framework"];
	wiredBundle = [NSBundle bundleWithPath:path];
	
	if(!wiredBundle)
		NSLog(@"Failed to load WiredAdditions.framework from %@", path);
	
	if(![wiredBundle load])
		NSLog(@"Failed to load %@", wiredBundle);
	
	[WCSettings loadWithIdentifier:[bundle bundleIdentifier]];
}



- (void)mainViewDidLoad {
	[_statusController awakeFromController];
	[_logController awakeFromController];
	[_dashboardController awakeFromController];
	[_configController awakeFromController];
	[_accountsController awakeFromController];
}



- (void)didSelect {
}



- (void)didUnselect {
	[self _save];
}



#pragma mark -

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	[self _save];
}



#pragma mark -

- (IBAction)help:(id)sender {
	NSString	*identifier;
	
	identifier = [[_tabView selectedTabViewItem] identifier];
	
	if([identifier isEqualToString:@"Status"]) {
		[[NSWorkspace sharedWorkspace] openURL:
			[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#3.2.1"]];
	}
	else if([identifier isEqualToString:@"Settings"]) {
		[[NSWorkspace sharedWorkspace] openURL:
			[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#3.2.2"]];
	}
	else if([identifier isEqualToString:@"Accounts"]) {
		[[NSWorkspace sharedWorkspace] openURL:
			[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#3.2.3"]];
	}
	else if([identifier isEqualToString:@"Advanced"]) {
		[[NSWorkspace sharedWorkspace] openURL:
			[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#3.2.4"]];
	}
	else if([identifier isEqualToString:@"System"]) {
		[[NSWorkspace sharedWorkspace] openURL:
			[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#3.2.5"]];
	}
}

@end
