//
//  EntityDataTableView.m
//  CoreDataUtil
//
//  Created by Laurie Caires on 6/6/12.
//  Copyright (c) 2012 mFluent LLC. All rights reserved.
//

#import "EntityDataTableView.h"
#import "MFLMainWindowController.h"
#import "MFLTextTableCellView.h"

@implementation EntityDataTableView

- (NSInteger)getRightClickedCol
{
    return rightClickedCol;
}

- (NSInteger)getRightClickedRow
{
    return rightClickedRow;
}

- (void)rightMouseDown:(NSEvent *)theEvent {
    NSPoint eventLocation = [theEvent locationInWindow];
    eventLocation = [self convertPoint:eventLocation fromView:nil];
    rightClickedRow = [self rowAtPoint:eventLocation];
    rightClickedCol = [self columnAtPoint:eventLocation];

    // get currently selected rows
    NSIndexSet* indexSet = [self selectedRowIndexes];
    //NSLog(@"Right clicked at row:%d, col:%d, point:%@, selected:%d", (int)rightClickedRow, (int)rightClickedCol, NSStringFromPoint(eventLocation), (int)indexSet.firstIndex);

    // if user right-clicks on a non-selected row, select that row
    if (![indexSet containsIndex:(NSUInteger)rightClickedRow]) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)rightClickedRow] byExtendingSelection:NO];
    }

    // now, show menu for newly selected row
    [super rightMouseDown:theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    NSMenu *menu = nil;
    
    NSIndexSet* indexSet = [self selectedRowIndexes];
    if (indexSet != nil && [indexSet firstIndex] != NSNotFound) {
        menu = [[NSMenu alloc] init];
        NSMenuItem* copyRowItem = [[NSMenuItem alloc] initWithTitle:@"Copy Plain" action:@selector(copy:) keyEquivalent:@""];
        [copyRowItem setKeyEquivalentModifierMask:0];
        [copyRowItem setKeyEquivalentModifierMask:NSCommandKeyMask];
        [menu addItem:copyRowItem]; 
        
        copyRowItem = [[NSMenuItem alloc] initWithTitle:@"Copy Formated" action:@selector(copyFormatted:) keyEquivalent:@"C"];
        [copyRowItem setKeyEquivalentModifierMask:0];
        [copyRowItem setKeyEquivalentModifierMask:NSCommandKeyMask];
        [menu addItem:copyRowItem];

        // if only 1 row selected, offer 'copy cell' option
        if (indexSet.count == 1) {
            copyRowItem = [[NSMenuItem alloc] initWithTitle:@"Copy Cell" action:@selector(copyCell:) keyEquivalent:@"C"];
            [copyRowItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
            [menu addItem:copyRowItem];
        }
    }
    
    return menu;
}

/**
 Copy the single selected row from the table. 
 The elements are separated by newlines, as text (!{NSStringPboardType}), 
 and by tabs, as tabular text (!NSTabularTextPboardType).
 
 **/
- (void) copySelectedRow: (BOOL) escapeSpecialChars {
    int selectedRow = (int)[self selectedRow]-1;
    int	numberOfRows = (int)[self numberOfRows];
    
    NSLog(@"Selected Row: %d, Total Rows: %d", selectedRow, numberOfRows);
    
    NSIndexSet* indexSet = [self selectedRowIndexes];
    if (indexSet != nil && [indexSet firstIndex] != NSNotFound) {
        NSPasteboard	*pb = [NSPasteboard generalPasteboard];
        NSMutableString *tabsBuf = [NSMutableString string];
        NSMutableString *textBuf = [NSMutableString string];
        
        NSArray *tableColumns = [self tableColumns];
        NSLog(@"Columns: %@", tableColumns);
        
        for (NSTableColumn* columnName in tableColumns) {
            [textBuf appendFormat:@"%@\t", [columnName identifier] ];
            [tabsBuf appendFormat:@"%@\t", [columnName identifier]];
        }
        
        [textBuf appendFormat:@"\n"];
        [tabsBuf appendFormat:@"\n"];

        // Step through and copy data from each of the selected rows
        NSUInteger currentIndex = [indexSet firstIndex];
        while (currentIndex != NSNotFound) {

            NSEnumerator *enumerator = [tableColumns objectEnumerator];
            NSTableColumn *col;
            MFLMainWindowController* dataSource = (MFLMainWindowController*)[self dataSource];
            while (nil != (col = [enumerator nextObject]) ) {
                id columnValue = [dataSource getValueObjFromDataRows:self: currentIndex: col];
                NSString *columnString = @"";
                if (nil != columnValue) {
                    if ([columnValue isKindOfClass:[NSManagedObject class]]) {
                        columnString = [[columnValue entity] name];
                    } else if ([columnValue isKindOfClass:[NSArray class]]) {
                        columnString = [NSString stringWithFormat:@"NSArray[%ld]", [columnValue count]];
                    } else if ([columnValue isKindOfClass:[NSSet class]]) {
                        columnString = [NSString stringWithFormat:@"NSSet[%ld]", [columnValue count]];
                    } else {
                        
                        columnString = [columnValue description];
                    }
                }
                
                if (columnString == nil) {
                    columnString = @"";
                }
                
                if (escapeSpecialChars) {
                    // Escape CR and TAB like SQLPro:
                    //    http://code.google.com/p/sequel-pro/source/browse/branches/app-store/Source/SPCopyTable.m?r=3592#239
                    columnString = [[columnString stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"];
                }
                
                [tabsBuf appendFormat:@"%@\t",columnString];
                [textBuf appendFormat:@"%@\t",columnString];
            }
            
            [textBuf appendFormat:@"\n"];
            [tabsBuf appendFormat:@"\n"];
            // delete the last tab. (But don't delete the last CR)
            if ([tabsBuf length]) {
                [tabsBuf deleteCharactersInRange:NSMakeRange([tabsBuf length]-1, 1)];
            }
            
            // Next Index
            currentIndex = [indexSet indexGreaterThanIndex: currentIndex];
        }
        [pb declareTypes:@[NSStringPboardType] owner:nil];
        [pb setString:[NSString stringWithString:textBuf] forType:NSStringPboardType];
    }
}

- (IBAction) copy:(id)sender
{
    NSLog(@"Copy Selected entityDataTable items. [%@]", sender);
    [self copySelectedRow:NO];
}

- (IBAction) copyFormatted:(id)sender
{
    NSLog(@"copyFormated Selected entityDataTable items. [%@]", sender);
    [self copySelectedRow:YES];
}

- (IBAction) copyCell:(id)sender {
    MFLTextTableCellView *cell = [self viewAtColumn:rightClickedCol row:rightClickedRow makeIfNecessary:NO];
    NSLog(@"copyCell: r:%d, c:%d, %@", (int)rightClickedRow, (int)rightClickedCol, cell.text);

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:@[NSStringPboardType] owner:nil];
    [pb setString:cell.text forType:NSStringPboardType];
}

@end
