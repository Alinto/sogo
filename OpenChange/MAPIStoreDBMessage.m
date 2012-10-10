/* MAPIStoreDBMessage.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreContext.h"
#import "MAPIStorePropertySelectors.h"
#import "SOGoMAPIDBMessage.h"

#import "MAPIStoreDBFolder.h"
#import "MAPIStoreDBMessage.h"
#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreDBMessage

+ (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  struct SPropTagArray *properties;
  NSUInteger count;
  enum MAPITAGS faiProperties[] = { 0x68350102, 0x683c0102, 0x683e0102,
                                    0x683f0102, 0x68410003, 0x68420102,
                                    0x68450102, 0x68460003 };

  properties = talloc_zero (memCtx, struct SPropTagArray);
  properties->cValues = MAPIStoreSupportedPropertiesCount + 8;
  properties->aulPropTag = talloc_array (properties, enum MAPITAGS,
                                         MAPIStoreSupportedPropertiesCount + 8);

  for (count = 0; count < MAPIStoreSupportedPropertiesCount; count++)
    properties->aulPropTag[count] = MAPIStoreSupportedProperties[count];

  /* FIXME (hack): append a few undocumented properties that can be added to
     FAI messages */
  for (count = 0; count < 8; count++)
    properties->aulPropTag[MAPIStoreSupportedPropertiesCount+count]
      = faiProperties[count];

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [super initWithSOGoObject: newSOGoObject
                            inContainer: newContainer]))
    {
      [properties release];
      properties = [newSOGoObject properties];
      [properties retain];
    }

  return self;
}

- (uint64_t) objectVersion
{
  NSNumber *versionNbr;
  uint64_t objectVersion;

  [(SOGoMAPIDBMessage *) sogoObject reloadIfNeeded];
  versionNbr = [properties objectForKey: @"version"];
  if (versionNbr)
    objectVersion = (([versionNbr unsignedLongLongValue] >> 16)
                     & 0x0000ffffffffffffLL);
  else
    objectVersion = ULLONG_MAX;

  return objectVersion;
}

- (int) getProperties: (struct mapistore_property_data *) data
             withTags: (enum MAPITAGS *) tags
             andCount: (uint16_t) columnCount
             inMemCtx: (TALLOC_CTX *) memCtx
{
  [sogoObject reloadIfNeeded];

  return [super getProperties: data
                     withTags: tags
                     andCount: columnCount
                     inMemCtx: memCtx];
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  id value;
  int rc;
 
  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (void) addProperties: (NSDictionary *) newNewProperties
{
  [sogoObject reloadIfNeeded];

  [super addProperties: newNewProperties];
}

- (void) save
{
  uint64_t newVersion;

  if ([attachmentKeys count] > 0)
    [properties setObject: attachmentParts forKey: @"attachments"];

  newVersion = [[self context] getNewChangeNumber];
  [properties setObject: [NSNumber numberWithUnsignedLongLong: newVersion]
                 forKey: @"version"];

  [self logWithFormat: @"%d props in dict", [properties count]];

  [sogoObject save];
}

- (BOOL) _messageIsFreeBusy
{
  NSString *msgClass;
  
  /* This is a HACK until we figure out how to determine a message position in
     the mailbox hierarchy.... (missing: folderid and role) */
  msgClass = [properties
               objectForKey: MAPIPropertyKey (PR_MESSAGE_CLASS_UNICODE)];

  return [msgClass isEqualToString: @"IPM.Microsoft.ScheduleData.FreeBusy"];
}

/* TODO: differentiate between the "Own" and "All" cases */
- (BOOL) subscriberCanReadMessage
{
  return [(MAPIStoreFolder *) container subscriberCanReadMessages];
          // || [self _messageIsFreeBusy]);
}

- (BOOL) subscriberCanModifyMessage
{
  return ((isNew
           && [(MAPIStoreFolder *) container subscriberCanCreateMessages])
          || (!isNew
              && [(MAPIStoreFolder *) container subscriberCanModifyMessages]));
          // || [self _messageIsFreeBusy]);
}

- (NSDate *) creationTime
{
  return [sogoObject creationDate];
}

- (NSDate *) lastModificationTime
{
  return [sogoObject lastModified];
}

@end
