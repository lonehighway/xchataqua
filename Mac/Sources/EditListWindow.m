/* X-Chat Aqua
 * Copyright (C) 2002 Steve Green
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA */

/* EditListWindow.m
 * Correspond to fe-gtk: xchat/src/fe-gtk/editlist.*
 */

#include "cfgfiles.h"

#import "AquaChat.h"
#import "EditListWindow.h"

@interface EditListItem : NSObject
{
    NSString *name;
    NSString *command;
}

@property (nonatomic, retain) NSString *name, *command;

@end

@implementation EditListItem
@synthesize name, command;

+ (EditListItem *) itemWithName:(NSString *)aName command:(NSString *)aCommand
{
    EditListItem *item = [[self alloc] init];
    if ( item != nil ) {
        item.name = aName;
        item.command = aCommand;
    }
    return [item autorelease];
}

- (void) dealloc
{
    self.name = nil;
    self.command = nil;
    
    [super dealloc];
}

- (NSComparisonResult) sort:(EditListItem *) other
{
    return [name compare:other->name];
}

@end

#pragma mark -

@implementation EditListWindow
@synthesize help;

- (void) dealloc
{
    [target release];
    [filename release];
    [items release];
    
    [super dealloc];
}

- (void) awakeFromNib
{
    self->items = [[NSMutableArray alloc] init];
    [self center];
}

- (void)setTarget:(id)aTarget didCloseSelector:(SEL)selector {
    [aTarget release];
    self->target = [aTarget retain];
    self->didCloseSelector = selector;
}

- (void) loadDataFromList:(GSList **)aSlist filename:(NSString *)aFilename
{    
    self->slist = aSlist;
    [self->filename release];
    self->filename = [aFilename copy];
    
    [items removeAllObjects];
    
    for (GSList *list = *slist; list; list = list->next)
    {
        struct popup *pop = (struct popup *) list->data;
        [items addObject:[EditListItem itemWithName:@(pop->name) command:@(pop->cmd)]];
    }
    
    [itemTableView reloadData];
}

#pragma mark IBActions

- (void) addItem:(id)sender
{
    [items insertObject:[EditListItem itemWithName:NSLocalizedStringFromTable(@"*NEW*", @"xchat", @"") command:NSLocalizedStringFromTable(@"EDIT ME", @"xchat", @"")] atIndex:0];
    [itemTableView reloadData];
    [itemTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [itemTableView editColumn:0 row:0 withEvent:nil select:YES];
}

- (void) removeItem:(id)sender
{
    [itemTableView abortEditing];
    NSInteger row = [itemTableView selectedRow];
    
    if (row < 0) return;
    
    [items removeObjectAtIndex:row];
    [itemTableView reloadData];
    
    isEdited = YES;
}

- (void) saveToFile:(id)sender {
    int fh = xchat_open_file ((char *)[filename UTF8String], O_TRUNC | O_WRONLY | O_CREAT, 0600, XOF_DOMODE);
    if (fh == -1 ) return;
    
    char buf[512];
    for (EditListItem *item in items) {
        snprintf(buf, sizeof(buf), "NAME %s\nCMD %s\n\n", [[item name] UTF8String], [[item command] UTF8String]);
        write(fh, buf, strlen(buf));
    }
    close(fh);
    
    list_free(slist);
    list_loadconf((char *)[filename UTF8String], slist, 0);
    
    [target performSelector:didCloseSelector];
    [self close];
}

- (void) showHelp:(id)sender
{
    if ( help != NULL ) {
        fe_message (help, FE_MSG_INFO);
    }
    else {
        // FIXME: in real, it is implemented but no help message. fix message needed.
        [SGAlert alertWithString:NSLocalizedStringFromTable(@"Not implemented (yet)", @"xchataqua", @"Alert message when a feature not implemented yet is tried") andWait:false];
    }
}

- (void) sortList:(id)sender
{
    [items sortUsingSelector:@selector(sort:)];
    [itemTableView reloadData];
}

#pragma mark NSTableView delegate

#define DATA_ARRAY items
#    include "UtilityTableViewDragAndDrop.inc.m"
#undef DATA_ARRAY

#pragma mark NSTableView dataSource

- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [items count];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger) rowIndex
{
    EditListItem *item = items[rowIndex];
    
    switch ([[aTableView tableColumns] indexOfObjectIdenticalTo:aTableColumn])
    {
        case 0: return [item name];
        case 1: return [item command];
    }
    
    dassert(NO);
    return @"";
}

- (void) tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    EditListItem *item = items[rowIndex];
    
    switch ([[aTableView tableColumns] indexOfObjectIdenticalTo:aTableColumn])
    {
        case 0: [item setName:anObject]; break;
        case 1: [item setCommand:anObject]; break;
    }
    
    isEdited = YES;
}

#pragma mark -
#pragma mark didCloseSelector

// TODO: rewrite to remove ugly implementation
+ (void) setupUserlistButtons {
    [AquaChat forEachSessionOnServer:NULL performSelector:@selector(setupUserlistButtons)];
}

@end

