/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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

@class WPAccountManager, WPConfigManager, WPExportManager, WPLogManager, WPWiredManager;
@class WPPortChecker;

@interface WPPreferencePane : NSPreferencePane {
	IBOutlet NSTextField				*_versionTextField;
	IBOutlet NSButton					*_installButton;
	IBOutlet NSProgressIndicator		*_installProgressIndicator;

	IBOutlet NSImageView				*_statusImageView;
	IBOutlet NSTextField				*_statusTextField;
	IBOutlet NSButton					*_startButton;
	IBOutlet NSProgressIndicator		*_startProgressIndicator;
	IBOutlet NSButton					*_launchAutomaticallyButton;

	IBOutlet NSTableView				*_logTableView;
	IBOutlet NSTableColumn				*_logTableColumn;
	IBOutlet NSButton					*_openLogButton;
	
	IBOutlet NSPopUpButton				*_filesPopUpButton;
	IBOutlet NSMenuItem					*_filesMenuItem;
	
	IBOutlet NSTextField				*_portTextField;
	IBOutlet NSImageView				*_portStatusImageView;
	IBOutlet NSTextField				*_portStatusTextField;
	IBOutlet NSButton					*_mapPortAutomaticallyButton;
	IBOutlet NSButton					*_checkPortAgainButton;
	
	IBOutlet NSTextField				*_accountStatusTextField;
	IBOutlet NSImageView				*_accountStatusImageView;
	IBOutlet NSButton					*_setPasswordForAdminButton;
	IBOutlet NSButton					*_createNewAdminUserButton;
	
	IBOutlet NSButton					*_exportSettingsButton;
	IBOutlet NSButton					*_importSettingsButton;
	
	IBOutlet NSPanel					*_passwordPanel;
	IBOutlet NSSecureTextField			*_newPasswordTextField;
	IBOutlet NSSecureTextField			*_verifyPasswordTextField;
	IBOutlet NSTextField				*_passwordMismatchTextField;

	WPAccountManager					*_accountManager;
	WPConfigManager						*_configManager;
	WPExportManager						*_exportManager;
	WPLogManager						*_logManager;
	WPWiredManager						*_wiredManager;
	
	WPPortChecker						*_portChecker;
	WPPortCheckerStatus					_portCheckerStatus;
	NSUInteger							_portCheckerPort;
	
	SUUpdater							*_updater;
	
	NSImage								*_greenDropImage;
	NSImage								*_redDropImage;
	NSImage								*_grayDropImage;
	
	WIDateFormatter						*_dateFormatter;
	NSMutableArray						*_logLines;
	NSMutableArray						*_logRows;
	NSDictionary						*_logAttributes;
}

- (IBAction)install:(id)sender;
- (IBAction)uninstall:(id)sender;
- (IBAction)releaseNotes:(id)sender;
- (IBAction)checkForUpdate:(id)sender;

- (IBAction)start:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)launchAutomatically:(id)sender;

- (IBAction)openLog:(id)sender;
- (IBAction)crashReports:(id)sender;

- (IBAction)other:(id)sender;

- (IBAction)port:(id)sender;
- (IBAction)mapPortAutomatically:(id)sender;
- (IBAction)checkPortAgain:(id)sender;

- (IBAction)setPasswordForAdmin:(id)sender;
- (IBAction)createNewAdminUser:(id)sender;
- (IBAction)submitPasswordSheet:(id)sender;

- (IBAction)exportSettings:(id)sender;
- (IBAction)importSettings:(id)sender;

@end
