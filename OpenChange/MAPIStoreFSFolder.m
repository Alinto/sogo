/* MAPIStoreFSFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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

#include <inttypes.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <NGExtensions/NSObject+Logs.h>

#import "EOQualifier+MAPIFS.h"
#import "MAPIStoreFSMessage.h"
#import "MAPIStoreFSMessageTable.h"
#import "MAPIStoreFolderTable.h"
#import "MAPIStoreTypes.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSFolder.h"

#undef DEBUG
#include <mapistore/mapistore.h>
// #include <mapistore/mapistore_errors.h>
// #include <libmapiproxy.h>
// #include <param.h>

static Class MAPIStoreFSMessageK;

@implementation MAPIStoreFSFolder

+ (void) initialize
{
  MAPIStoreFSMessageK = [MAPIStoreFSMessage class];
}

- (id) initWithURL: (NSURL *) newURL
         inContext: (MAPIStoreContext *) newContext
{
  if ((self = [super initWithURL: newURL
                       inContext: newContext]))
    {
      sogoObject = [SOGoMAPIFSFolder folderWithURL: newURL
                                      andTableType: MAPISTORE_MESSAGE_TABLE];
      [sogoObject retain];
    }

  return self;
}

- (MAPIStoreMessageTable *) messageTable
{
  return [MAPIStoreFSMessageTable tableForContainer: self];
}

- (Class) messageClass
{
  return MAPIStoreFSMessageK;
}

- (NSString *) createFolder: (struct SRow *) aRow
                    withFID: (uint64_t) newFID
{
  NSString *newKey, *urlString;
  SOGoMAPIFSFolder *childFolder;

  newKey = [NSString stringWithFormat: @"0x%.16"PRIx64, (unsigned long long) newFID];

  urlString = [NSString stringWithFormat: @"%@/%@", [self url], newKey];
  childFolder = [SOGoMAPIFSFolder folderWithURL: [NSURL URLWithString: urlString]
                                   andTableType: MAPISTORE_MESSAGE_TABLE];
  [childFolder ensureDirectory];

  return newKey;
}

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIFSMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIFSMessage objectWithName: newKey inContainer: sogoObject];
  newMessage = [MAPIStoreFSMessage mapiStoreObjectWithSOGoObject: fsObject
                                                     inContainer: self];

  
  return newMessage;
}

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  NSArray *allKeys;
  NSMutableArray *keys;
  NSUInteger count, max;
  NSString *messageKey;
  SOGoMAPIFSMessage *message;

  if (sortOrderings)
    [self warnWithFormat: @"sorting is not handled yet"];

  allKeys = [sogoObject toOneRelationshipKeys];
  if (qualifier)
    {
      [self logWithFormat: @"%s: getting restricted keys", __PRETTY_FUNCTION__];
      max = [allKeys count];
      keys = [NSMutableArray arrayWithCapacity: max];
      for (count = 0; count < max; count++)
        {
          messageKey = [allKeys objectAtIndex: count];
          message = [sogoObject lookupName: messageKey
                                inContext: nil
                                acquire: NO];
          if ([qualifier evaluateMAPIFSMessage: message])
            [keys addObject: messageKey];
	}
      [self logWithFormat: @"  resulting keys: $$$%@$$$", keys];
    }
  else
    keys = (NSMutableArray *) allKeys;

  return keys;
}

- (NSArray *) folderKeys
{
  if (!folderKeys)
    ASSIGN (folderKeys, [sogoObject toManyRelationshipKeys]);

  return folderKeys;
}

- (id) lookupChild: (NSString *) childKey
{
  id childObject;
  SOGoMAPIFSFolder *childFolder;

  [self folderKeys];
  if ([folderKeys containsObject: childKey])
    {
      childFolder = [sogoObject lookupName: childKey inContext: nil
                                   acquire: NO];
      childObject = [MAPIStoreFSFolder mapiStoreObjectWithSOGoObject: childFolder
                                                         inContainer: self];
    }
  else
    childObject = [super lookupChild: childKey];

  return childObject;
}

- (MAPIStoreFAIMessageTable *) folderTable
{
  return [MAPIStoreFolderTable tableForContainer: self];
}

- (NSDate *) lastMessageModificationTime
{
  NSUInteger count, max;
  NSDate *date, *fileDate;
  MAPIStoreFSMessage *msg;

  [self messageKeys];

  date = [NSCalendarDate date];
  [self logWithFormat: @"current date: %@", date];

  max = [messageKeys count];
  for (count = 0; count < max; count++)
    {
      msg = [self lookupChild: [messageKeys objectAtIndex: count]];
      fileDate = [msg lastModificationTime];
      if ([date laterDate: fileDate] == fileDate)
        {
          [self logWithFormat: @"current date: %@", date];
          
          date = fileDate;
        }
    }

  return date;
}

@end
