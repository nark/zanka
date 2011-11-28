/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

extern NSString * const WIFileIcon;
extern NSString * const WIFileSize;
extern NSString * const WIFileKind;
extern NSString * const WIFileCreationDate;
extern NSString * const WIFileModificationDate;


@interface WITreeView : NSControl {
	IBOutlet NSView					*_detailView;
	IBOutlet NSImageView			*_iconImageView;
	IBOutlet NSView					*_attributesView;
	IBOutlet NSTextField			*_nameTextField;
	IBOutlet NSTextField			*_kindTextField;
	IBOutlet NSTextField			*_sizeTextField;
	IBOutlet NSTextField			*_createdTextField;
	IBOutlet NSTextField			*_modifiedTextField;

	id								delegate;
	id								dataSource;
	
	id								_target;
	NSMutableArray					*_views;
	NSString						*_rootPath;
	NSString						*_path;
	SEL								_doubleAction;
	
	NSDragOperation					_draggingSourceOperationMaskForLocal;
	NSDragOperation					_draggingSourceOperationMaskForNonLocal;
	
	WIDateFormatter					*_dateFormatter;
	
	NSTimer							*_scrollingTimer;
	NSPoint							_scrollingPoint;
	
	BOOL							_selectingProgrammatically;
	BOOL							_reloadingData;
	BOOL							_inChangedPath;
	BOOL							_inChangedSelection;
}

- (void)setDelegate:(id)delegate;
- (id)delegate;
- (void)setDataSource:(id)dataSource;
- (id)dataSource;
- (void)setRootPath:(NSString *)path;
- (NSString *)rootPath;
- (void)setDoubleAction:(SEL)doubleAction;
- (SEL)doubleAction;

- (void)setDraggingSourceOperationMask:(NSDragOperation)mask forLocal:(BOOL)isLocal;

- (NSString *)selectedPath;
- (NSArray *)selectedPaths;

- (void)selectPath:(NSString *)path;
- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extendingSelection;

- (void)reloadData;

@end


@interface NSObject(WITreeViewDataSource)

- (NSUInteger)treeView:(WITreeView *)tree numberOfItemsForPath:(NSString *)path;
- (NSString *)treeView:(WITreeView *)tree nameForRow:(NSUInteger)row inPath:(NSString *)path;
- (BOOL)treeView:(WITreeView *)tree isPathExpandable:(NSString *)path;
- (NSDictionary *)treeView:(WITreeView *)tree attributesForPath:(NSString *)path;

@end



@interface NSObject(WITreeViewDelegate)

- (void)treeView:(WITreeView *)tree changedPath:(NSString *)path;
- (void)treeView:(WITreeView *)tree willDisplayCell:(id)cell forPath:(NSString *)path;
- (NSColor *)treeView:(WITreeView *)tree labelColorForPath:(NSString *)path;

- (BOOL)treeView:(WITreeView *)treeView writePaths:(NSArray *)paths toPasteboard:(NSPasteboard *)pasteboard;
- (NSDragOperation)treeView:(WITreeView *)treeView validateDrop:(id <NSDraggingInfo>)info proposedPath:(NSString *)path;
- (BOOL)treeView:(WITreeView *)treeView acceptDrop:(id <NSDraggingInfo>)info path:(NSString *)path;
- (NSArray *)treeView:(WITreeView *)treeView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedPaths:(NSArray *)paths;

- (void)treeViewShouldCopyInfo:(WITreeView *)treeView;

@end
