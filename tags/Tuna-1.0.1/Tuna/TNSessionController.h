/* $Id$ */

/*
 *  Copyright (c) 2005 Axel Andersson
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

enum TNStatsDisplayMode {
	TNStatsDisplayValue				= 0,
	TNStatsDisplayPercent			= 1
};
typedef enum TNStatsDisplayMode		TNStatsDisplayMode;


@class TNTree;

@interface TNSessionController : WIWindowController {
	IBOutlet NSTextField			*_dataMiningTextField;
	
	IBOutlet WIOutlineView			*_treeOutlineView;
	IBOutlet NSTableColumn			*_selfTableColumn;
	IBOutlet NSTableColumn			*_totalTableColumn;
	IBOutlet NSTableColumn			*_packageTableColumn;
	IBOutlet NSTableColumn			*_subTableColumn;
	
	IBOutlet NSTextField			*_weightTextField;
	
	IBOutlet NSPanel				*_infoPanel;
	IBOutlet NSTextField			*_versionTextField;
	IBOutlet NSTextField			*_frequencyTextField;
	IBOutlet NSTextField			*_userTimeTextField;
	IBOutlet NSTextField			*_systemTimeTextField;
	IBOutlet NSTextField			*_wallclockTimeTextField;
	
	TNTree							*_tree;
	
	TNStatsDisplayMode				_statsDisplayMode;
	BOOL							_colorByPackage;
}


- (id)initWithTree:(TNTree *)tree;

- (IBAction)statsDisplayMode:(id)sender;
- (IBAction)colorByPackage:(id)sender;
- (IBAction)hideWeight:(id)sender;
- (IBAction)hideWeightPercent:(id)sender;

@end
