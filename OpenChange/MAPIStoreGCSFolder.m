/* MAPIStoreGCSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLContentStore/GCSFolder.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreGCSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreGCSFolder

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      ASSIGN (versionsMessage,
              [SOGoMAPIFSMessage objectWithName: @"versions.plist"
                                    inContainer: propsFolder]);
    }

  return self;
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [super initWithSOGoObject: newSOGoObject inContainer: newContainer]))
    {
      ASSIGN (versionsMessage,
              [SOGoMAPIFSMessage objectWithName: @"versions.plist"
                                    inContainer: propsFolder]);
    }

  return self;
}

- (void) dealloc
{
  [versionsMessage release];
  [super dealloc];
}

- (NSArray *) messageKeysMatchingQualifier: (EOQualifier *) qualifier
                          andSortOrderings: (NSArray *) sortOrderings
{
  static NSArray *fields = nil;
  NSArray *records;
  EOQualifier *componentQualifier, *fetchQualifier;
  GCSFolder *ocsFolder;
  EOFetchSpecification *fs;
  NSArray *keys;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  componentQualifier = [self componentQualifier];
  if (qualifier)
    {
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers:
                           componentQualifier,
                         qualifier,
                         nil];
      [fetchQualifier autorelease];
    }
  else
    fetchQualifier = componentQualifier;

  ocsFolder = [sogoObject ocsFolder];
  fs = [EOFetchSpecification
         fetchSpecificationWithEntityName: [ocsFolder folderName]
                                qualifier: fetchQualifier
                            sortOrderings: sortOrderings];
  records = [ocsFolder fetchFields: fields fetchSpecification: fs];
  keys = [records objectsForKey: @"c_name"
                 notFoundMarker: nil];

  return keys;
}

- (NSDate *) lastMessageModificationTime
{
  NSNumber *ti;
  NSDate *value = nil;

  ti = [[versionsMessage properties]
         objectForKey: @"SyncLastSynchronisationDate"];
  if (ti)
    value = [NSDate dateWithTimeIntervalSince1970: [ti doubleValue]];
  else
    value = [NSDate date];

  [self logWithFormat: @"lastMessageModificationTime: %@", value];

  return value;
}

/* synchronisation */

/* Tree:
{
  SyncLastModseq = x;
  SyncLastSynchronisationDate = x; ** not updated until something changed
  Messages = {
    MessageKey = {
      Version = x;
      Modseq = x;
      Deleted = b;
    };
    ...
  };
  VersionMapping = {
    Version = MessageKey;
    ...
  }
}
*/

- (BOOL) synchroniseCache
{
  BOOL rc = YES, foundChange = NO;
  uint64_t newChangeNum;
  NSNumber *ti, *changeNumber, *lastModificationDate, *cName, *cVersion, *cLastModified;
  EOFetchSpecification *fs;
  EOQualifier *searchQualifier, *fetchQualifier;
  NSUInteger count, max;
  NSArray *fetchResults;
  NSDictionary *result;
  NSMutableDictionary *currentProperties, *messages, *mapping, *messageEntry;
  NSCalendarDate *now;
  GCSFolder *ocsFolder;
  static NSArray *fields = nil;
  static EOSortOrdering *sortOrdering = nil;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", @"c_lastmodified",
               nil];

  if (!sortOrdering)
    {
      sortOrdering = [EOSortOrdering sortOrderingWithKey: @"c_lastmodified"
                                                selector: EOCompareAscending];
      [sortOrdering retain];
    }

  now = [NSCalendarDate date];

  currentProperties = [[versionsMessage properties] mutableCopy];
  if (!currentProperties)
    currentProperties = [NSMutableDictionary new];
  [currentProperties autorelease];
  messages = [currentProperties objectForKey: @"Messages"];
  if (!messages)
    {
      messages = [NSMutableDictionary new];
      [currentProperties setObject: messages forKey: @"Messages"];
      [messages release];
    }
  mapping = [currentProperties objectForKey: @"VersionMapping"];
  if (!mapping)
    {
      mapping = [NSMutableDictionary new];
      [currentProperties setObject: mapping forKey: @"VersionMapping"];
      [mapping release];
    }

  lastModificationDate = [currentProperties objectForKey: @"SyncLastModificationDate"];
  if (lastModificationDate)
    {
      searchQualifier = [[EOKeyValueQualifier alloc]
                                initWithKey: @"c_lastmodified"
                           operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                      value: lastModificationDate];
      fetchQualifier = [[EOAndQualifier alloc]
                         initWithQualifiers:
                           searchQualifier, [self componentQualifier], nil];
      [fetchQualifier autorelease];
      [searchQualifier release];
    }
  else
    fetchQualifier = [self componentQualifier];

  ocsFolder = [sogoObject ocsFolder];
  fs = [EOFetchSpecification
             fetchSpecificationWithEntityName: [ocsFolder folderName]
                                    qualifier: fetchQualifier
                                sortOrderings: [NSArray arrayWithObject: sortOrdering]];
  fetchResults = [ocsFolder fetchFields: fields fetchSpecification: fs];
  max = [fetchResults count];
  if (max > 0)
    {
      for (count = 0; count < max; count++)
        {
          result = [fetchResults objectAtIndex: count];
          cName = [result objectForKey: @"c_name"];
          cVersion = [result objectForKey: @"c_version"];
          cLastModified = [result objectForKey: @"c_lastmodified"];

          messageEntry = [messages objectForKey: cName];
          if (!messageEntry)
            {
              messageEntry = [NSMutableDictionary new];
              [messages setObject: messageEntry forKey: cName];
              [messageEntry release];
            }
          if (![[messageEntry objectForKey: @"c_version"]
                 isEqual: cVersion])
            {
              foundChange = YES;

              newChangeNum = [[self context] getNewChangeNumber];
              changeNumber = [NSNumber numberWithUnsignedLongLong: newChangeNum];

              [messageEntry setObject: cLastModified forKey: @"c_lastmodified"];
              [messageEntry setObject: cVersion forKey: @"c_version"];
              [messageEntry setObject: changeNumber forKey: @"version"];

              [mapping setObject: cLastModified forKey: changeNumber];

              if (!lastModificationDate
                  || ([lastModificationDate compare: cLastModified]
                      == NSOrderedAscending))
                lastModificationDate = cLastModified;
            }
        }

      if (foundChange)
        {
          ti = [NSNumber numberWithDouble: [now timeIntervalSince1970]];
          [currentProperties setObject: ti
                                forKey: @"SyncLastSynchronisationDate"];
          [currentProperties setObject: lastModificationDate
                                forKey: @"SyncLastModificationDate"];
          [versionsMessage appendProperties: currentProperties];
          [versionsMessage save];
        }
    }

  return rc;
}
 
- (NSNumber *) lastModifiedFromMessageChangeNumber: (NSNumber *) changeNum
{
  NSDictionary *mapping;
  NSNumber *modseq;

  mapping = [[versionsMessage properties] objectForKey: @"VersionMapping"];
  modseq = [mapping objectForKey: changeNum];

  return modseq;
}

- (NSNumber *) changeNumberForMessageWithKey: (NSString *) messageKey
{
  NSDictionary *messages;
  NSNumber *changeNumber;

  messages = [[versionsMessage properties] objectForKey: @"Messages"];
  changeNumber = [[messages objectForKey: messageKey]
                   objectForKey: @"version"];

  return changeNumber;
}

- (NSArray *) getDeletedKeysFromChangeNumber: (uint64_t) changeNum
                                       andCN: (NSNumber **) cnNbr
                                 inTableType: (uint8_t) tableType
{
  NSArray *deletedKeys, *deletedCNames, *records;
  NSNumber *changeNumNbr, *lastModified;
  NSString *cName;
  NSDictionary *versionProperties;
  NSMutableDictionary *messages, *mapping;
  uint64_t newChangeNum = 0;
  EOAndQualifier *fetchQualifier;
  EOKeyValueQualifier *cDeletedQualifier, *cLastModifiedQualifier;
  EOFetchSpecification *fs;
  GCSFolder *ocsFolder;
  NSUInteger count, max;

  if (tableType == MAPISTORE_MESSAGE_TABLE)
    {
      deletedKeys = [NSMutableArray array];

      changeNumNbr = [NSNumber numberWithUnsignedLongLong: changeNum];
      lastModified = [self lastModifiedFromMessageChangeNumber: changeNumNbr];
      if (lastModified)
        {
          versionProperties = [versionsMessage properties];
          messages = [versionProperties objectForKey: @"Messages"];

          ocsFolder = [sogoObject ocsFolder];
          cLastModifiedQualifier = [[EOKeyValueQualifier alloc]
                                           initWithKey: @"c_lastmodified"
                                      operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                                 value: lastModified];
          cDeletedQualifier = [[EOKeyValueQualifier alloc]
                                           initWithKey: @"c_deleted"
                                      operatorSelector: EOQualifierOperatorEqual
                                                 value: [NSNumber numberWithInt: 1]];
          fetchQualifier = [[EOAndQualifier alloc] initWithQualifiers:
                                                     cLastModifiedQualifier,
                                                   cDeletedQualifier,
                                                   nil];
          [fetchQualifier autorelease];
          [cLastModifiedQualifier release];
          [cDeletedQualifier release];

          fs = [EOFetchSpecification
                 fetchSpecificationWithEntityName: [ocsFolder folderName]
                                        qualifier: fetchQualifier
                                    sortOrderings: nil];
          records = [ocsFolder
                               fetchFields: [NSArray arrayWithObject: @"c_name"]
                        fetchSpecification: fs
                             ignoreDeleted: NO];
          deletedCNames = [records objectsForKey: @"c_name" notFoundMarker: nil];
          max = [deletedCNames count];
          if (max > 0)
            {
              mapping = [versionProperties objectForKey: @"VersionsMapping"];
              for (count = 0; count < max; count++)
                {
                  cName = [deletedCNames objectAtIndex: count];
                  if ([messages objectForKey: cName])
                    {
                      [messages removeObjectForKey: cName];
                      [(NSMutableArray *) deletedKeys addObject: cName];
                      newChangeNum = [[self context] getNewChangeNumber];
                    }
                }
              if (newChangeNum)
                {
                  changeNumNbr
                    = [NSNumber numberWithUnsignedLongLong: newChangeNum];
                  [mapping setObject: lastModified forKey: changeNumNbr];
                  *cnNbr = changeNumNbr;
                  [versionsMessage save];
                }
            }
        }
    }
  else
    deletedKeys = [super getDeletedKeysFromChangeNumber: changeNum
                                                  andCN: cnNbr
                                            inTableType: tableType];

  return deletedKeys;
}

/* subclasses */

- (EOQualifier *) componentQualifier
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
