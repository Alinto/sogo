/* MAPIStoreActiveTables.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* MAPIStoreActiveTables provides an interface to keep accounting of all
   instances of a given table, independently from its store and context.
   Primary useful for notifications across different connections. */

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "MAPIStoreFolder.h"
#import "MAPIStoreTable.h"

#import "MAPIStoreActiveTables.h"

@interface MAPIStoreActiveTableRecord : NSObject
{
  uint64_t folderId;
  uint8_t tableType;
  MAPIStoreTable *table;
}

+ (id) recordForTable: (MAPIStoreTable *) newTable;
- (id) initWithTable: (MAPIStoreTable *) newTable;

- (MAPIStoreTable *) table;

- (BOOL) exactlyMatchesTable: (MAPIStoreTable *) otherTable;
- (BOOL) matchesFMID: (uint64_t) otherFMid
        andTableType: (uint8_t) otherTableType;
- (BOOL) matchesTable: (MAPIStoreTable *) otherTable;

@end

@implementation MAPIStoreActiveTableRecord : NSObject

+ (id) recordForTable: (MAPIStoreTable *) newTable
{
  MAPIStoreActiveTableRecord *record;

  record = [[self alloc] initWithTable: newTable];
  [record autorelease];

  return record;
}

- (id) init
{
  if ((self = [super init]))
    {
      folderId = 0;
      tableType = 0;
      table = nil;
    }

  return self;
}

- (id) initWithTable: (MAPIStoreTable *) newTable
{
  if ((self = [self init]))
    {
      table = newTable;
      folderId = [[table container] objectId];
      tableType = [table tableType];
    }

  return self;
}

- (MAPIStoreTable *) table
{
  return table;
}

- (BOOL) exactlyMatchesTable: (MAPIStoreTable *) otherTable
{
  return (table == otherTable);
}

- (BOOL) matchesFMID: (uint64_t) otherFMid
        andTableType: (uint8_t) otherTableType
{
  return (tableType == otherTableType
          && folderId == otherFMid);
}

- (BOOL) matchesTable: (MAPIStoreTable *) otherTable
{
  uint64_t otherFMid;
  BOOL rc;

  rc = [self exactlyMatchesTable: otherTable];
  if (!rc)
    {
      otherFMid = [[otherTable container] objectId];
      rc = [self matchesFMID: otherFMid andTableType: [otherTable tableType]];
    }

  return rc;
}

@end

@implementation MAPIStoreActiveTables

+ (id) activeTables
{
  static MAPIStoreActiveTables *activeTables = nil;

  if (!activeTables)
    activeTables = [self new];

  return activeTables;
}

- (id) init
{
  if ((self = [super init]))
    {
      records = [NSMutableArray new];
    }

  return self;
}

- (void) dealloc
{
  [records release];
  [super dealloc];
}

- (void) registerTable: (MAPIStoreTable *) table
{
  MAPIStoreActiveTableRecord *newRecord;

  newRecord = [MAPIStoreActiveTableRecord recordForTable: table];
  [records addObject: newRecord];
}

- (void) unregisterTable: (MAPIStoreTable *) table
{
  MAPIStoreActiveTableRecord *currentRecord;
  NSUInteger count, max;
  BOOL done = NO;

  max = [records count];
  for (count = 0; !done && count < max; count++)
    {
      currentRecord = [records objectAtIndex: count];
      if ([currentRecord exactlyMatchesTable: table])
        {
          [records removeObject: currentRecord];
          done = YES;
        }
    }
}

- (NSArray *) activeTablesForFMID: (uint64_t) fmid
                          andType: (uint8_t) tableType
{
  NSUInteger count, max;
  NSMutableArray *tables;
  MAPIStoreActiveTableRecord *currentRecord;

  tables = [NSMutableArray arrayWithCapacity: 5];

  max = [records count];
  for (count = 0; count < max; count++)
    {
      currentRecord = [records objectAtIndex: count];
      if ([currentRecord matchesFMID: fmid andTableType: tableType])
        [tables addObject: [currentRecord table]];
    }

  return tables;
}

@end
