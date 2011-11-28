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

@class WCStatusController;

@interface WCDashboardController : NSObject {
	IBOutlet WCStatusController			*_statusController;
	
	IBOutlet NSButton					*_startButton;
	IBOutlet NSButton					*_restartButton;
	IBOutlet NSButton					*_reloadButton;
	IBOutlet NSButton					*_registerButton;
	IBOutlet NSButton					*_indexButton;
	
	IBOutlet SFAuthorizationView		*_authorizationView;
	
	BOOL								_authorized;
}


#define WCAuthorizationStatusDidChange	@"WCAuthorizationStatusDidChange"


+ (WCDashboardController *)dashboardController;

- (void)awakeFromController;

- (NSArray *)launchArguments;

- (BOOL)isAuthorized;
- (BOOL)launchTaskWithPath:(NSString *)path arguments:(NSArray *)arguments;
- (BOOL)createFileAtPath:(NSString *)path;
- (BOOL)movePath:(NSString *)fromPath toPath:(NSString *)toPath;
- (BOOL)removeFileAtPath:(NSString *)path;
- (BOOL)changeOwnerOfPath:(NSString *)path toUser:(NSString *)user group:(NSString *)group;

- (IBAction)start:(id)sender;
- (IBAction)restart:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)registerWithTracker:(id)sender;
- (IBAction)indexFiles:(id)sender;

@end
