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

#import <WiredAdditions/WITypes.h>

@class _WITableViewManager;

@interface WIOutlineView : NSOutlineView {
	_WITableViewManager			*_tableViewManager;
}


- (void)selectRowWithStringValue:(NSString *)string;
- (void)selectRowWithStringValue:(NSString *)string options:(unsigned int)options;

- (IBAction)showViewOptions:(id)sender;
- (NSArray *)allTableColumns;
- (void)includeTableColumn:(NSTableColumn *)tableColumn;
- (void)includeTableColumnWithIdentifier:(NSString *)identifier;
- (void)excludeTableColumn:(NSTableColumn *)tableColumn;
- (void)excludeTableColumnWithIdentifier:(NSString *)identifier;
- (void)setHighlightedTableColumn:(NSTableColumn *)tableColumn sortOrder:(WISortOrder)sortOrder;
- (WISortOrder)sortOrder;

- (void)setAllowsUserCustomization:(BOOL)value;
- (BOOL)allowsUserCustomization;
- (void)setDefaultTableColumnIdentifiers:(NSArray *)columns;
- (NSArray *)defaultTableColumnIdentifiers;
- (void)setDefaultHighlightedTableColumnIdentifier:(NSString *)identifier;
- (NSString *)defaultHighlightedTableColumnIdentifier;
- (void)setDefaultSortOrder:(WISortOrder)order;
- (WISortOrder)defaultSortOrder;
- (void)setUpAction:(SEL)action;
- (SEL)upAction;
- (void)setDownAction:(SEL)action;
- (SEL)downAction;
- (void)setBackAction:(SEL)action;
- (SEL)backAction;
- (void)setForwardAction:(SEL)action;
- (SEL)forwardAction;
- (void)setEscapeAction:(SEL)action;
- (SEL)escapeAction;
- (void)setDeleteAction:(SEL)action;
- (SEL)deleteAction;
- (void)setFont:(NSFont *)font;
- (NSFont *)font;

@end


@interface NSObject(WIOutlineViewDelegate)

- (NSString *)outlineView:(NSOutlineView *)outlineView stringValueForRow:(int)row;
- (void)outlineViewShouldCopyInfo:(NSOutlineView *)outlineView;
- (void)outlineViewFlagsDidChange:(NSOutlineView *)outlineView;

@end
