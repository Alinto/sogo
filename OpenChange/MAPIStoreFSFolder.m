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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>

#import "EOQualifier+MAPIFS.h"
#import "MAPIStoreFSMessage.h"
#import "MAPIStoreFSMessageTable.h"
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

- (MAPIStoreMessage *) createMessage
{
  MAPIStoreMessage *newMessage;
  SOGoMAPIFSMessage *fsObject;
  NSString *newKey;

  newKey = [NSString stringWithFormat: @"%@.plist",
                     [SOGoObject globallyUniqueObjectId]];
  fsObject = [SOGoMAPIFSMessage objectWithName: newKey inContainer: faiFolder];
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

@end
