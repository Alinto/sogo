/* MAPIStoreObject.m - this file is part of SOGo
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
#import <Foundation/NSTimeZone.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreTypes.h"
#import "MAPIStoreUserContext.h"
#import "NSDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreObject.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreObject

static Class NSExceptionK, MAPIStoreFolderK;

+ (void) initialize
{
  NSExceptionK = [NSExceptionK class];
  MAPIStoreFolderK = [MAPIStoreFolder class];
}

+ (id) mapiStoreObjectInContainer: (MAPIStoreObject *) newContainer
{
  id newObject;

  newObject = [[self alloc] initInContainer: newContainer];
  [newObject autorelease];

  return newObject;
}

- (id) init
{
  if ((self = [super init]))
    {
      classGetters = (IMP *) MAPIStorePropertyGettersForClass (isa);
      parentContainersBag = [NSMutableArray new];
      container = nil;
      properties = [NSMutableDictionary new];
      proxies = [NSMutableArray new];
    }

  // [self logWithFormat: @"-init"];

  return self;
}

- (id) initInContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [self init]))
    {
      ASSIGN (container, newContainer);
    }

  return self;
}

- (void) dealloc
{
  // [self logWithFormat: @"-dealloc"];
  [proxies release];
  [properties release];
  [parentContainersBag release];
  [container release];
  [super dealloc];
}

- (MAPIStoreObject *) container
{
  return container;
}

- (MAPIStoreContext *) context
{
  return (MAPIStoreContext *) [container context];
}

- (MAPIStoreUserContext *) userContext
{
  return [[self context] userContext];
}

- (MAPIStoreMapping *) mapping
{
  return [[self userContext] mapping];
}

- (NSString *) url
{
  NSString *containerURL, *urlName, *format;

  containerURL = (NSString *) [container url];
  if ([containerURL hasSuffix: @"/"])
    format = @"%@%@";
  else
    format = @"%@/%@";

  urlName = [[self nameInContainer]
              stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  return  [NSString stringWithFormat: format, containerURL, urlName];
}

/* helpers */

- (void) addProperties: (NSDictionary *) newNewProperties
{
  [properties addEntriesFromDictionary: newNewProperties];
}

- (NSMutableDictionary *) properties
{
  return properties;
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStorePropertyGetter method = NULL;
  uint16_t propValue;
  SEL methodSel;
  id value;
  int rc = MAPISTORE_ERR_NOT_FOUND;
  NSUInteger count, max;

  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getValue: data forTag: propTag inMemCtx: memCtx];
  else
    {
      propValue = (propTag & 0xffff0000) >> 16;
      methodSel = MAPIStoreSelectorForPropertyGetter (propValue);
      method = (MAPIStorePropertyGetter) classGetters[propValue];
      if (method)
        rc = method (self, methodSel, data, memCtx);
    }

  if (rc == MAPISTORE_ERR_NOT_FOUND)
    {
      max = [proxies count];
      for (count = 0; rc == MAPISTORE_ERR_NOT_FOUND && count < max; count++)
        rc = [[proxies objectAtIndex: count]
               getProperty: data
                   withTag: propTag
                  inMemCtx: memCtx];
    }

  return rc;
}

- (int) getPidTagCreationTime: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self creationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagLastModificationTime: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self lastModificationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (BOOL) canGetProperty: (enum MAPITAGS) propTag
{
  uint16_t propValue;
  BOOL canGetProperty;
  NSUInteger count, max;

  propValue = (propTag >> 16) & 0xffff;

  canGetProperty = (classGetters[propValue]
                    || [properties objectForKey: MAPIPropertyKey (propTag)]);
  max = [proxies count];
  for (count = 0; !canGetProperty && count < max; count++)
    canGetProperty = [[proxies objectAtIndex: count] canGetProperty: propTag];

  return canGetProperty;
}

- (int) getProperties: (struct mapistore_property_data *) data
             withTags: (enum MAPITAGS *) tags
             andCount: (uint16_t) columnCount
             inMemCtx: (TALLOC_CTX *) memCtx
{
  uint16_t count;

  for (count = 0; count < columnCount; count++)
    data[count].error = [self getProperty: &data[count].data
                                  withTag: tags[count]
                                 inMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (void) addProxy: (MAPIStoreObjectProxy *) newProxy
{
  [proxies addObject: newProxy];
}

- (int) addPropertiesFromRow: (struct SRow *) aRow
{
  struct SPropValue *cValue;
  NSUInteger counter;
  NSMutableDictionary *newProperties;
  NSTimeZone *tz;
  NSInteger tzOffset;
  id value;

  tz = nil;

  newProperties = [NSMutableDictionary dictionaryWithCapacity: aRow->cValues];
  for (counter = 0; counter < aRow->cValues; counter++)
    {
      cValue = aRow->lpProps + counter;
      value = NSObjectFromSPropValue (cValue);
      switch (cValue->ulPropTag & 0xffff)
        {
        case PT_STRING8:
        case PT_MV_STRING8:
          [self warnWithFormat:
                  @"attempting to set string property as PR_STRING8: %.8x",
                cValue->ulPropTag];
          break;
        case PT_SYSTIME:
          if (!tz)
            {
              tz = [[self userContext] timeZone];
              tzOffset = -[tz secondsFromGMT];
            }
          value = [value addYear: 0 month: 0 day: 0
                            hour: 0 minute: 0 second: tzOffset];
          [value setTimeZone: tz];
          break;
        }
      [newProperties setObject: value
                        forKey: MAPIPropertyKey (cValue->ulPropTag)];
    }

  [self addProperties: newProperties];

  return MAPISTORE_SUCCESS;
}

- (NSData *) getReplicaKeyFromGlobCnt: (uint64_t) objectCnt
{
  struct mapistore_connection_info *connInfo;
  NSMutableData *replicaKey;
  char buffer[6];
  NSUInteger count;

  connInfo = [[self context] connectionInfo];

  for (count = 0; count < 6; count++)
    {
      buffer[count] = objectCnt & 0xff;
      objectCnt >>= 8;
    }

  replicaKey = [NSMutableData dataWithCapacity: 22];
  [replicaKey appendBytes: &connInfo->replica_guid
                   length: sizeof (struct GUID)];
  [replicaKey appendBytes: buffer length: 6];

  return replicaKey;
}

- (int) getReplicaKey: (void **) data
          fromGlobCnt: (uint64_t) objectCnt
             inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self getReplicaKeyFromGlobCnt: objectCnt] asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* move and copy operations */
- (void) copyPropertiesToObject: (MAPIStoreObject *) newObject
{
  TALLOC_CTX *memCtx;
  struct SPropTagArray *availableProps;
  struct SRow row;
  enum MAPITAGS propTag;
  bool *exclusions;
  NSUInteger count;
  enum mapistore_error error;
  void *data;

  memCtx = talloc_zero (NULL, TALLOC_CTX);

  [self getAvailableProperties: &availableProps inMemCtx: memCtx];

  /* We exclude identity and versioning properties to facilitate copy
     operations. If they need to be set (move operations), the caller will need
     to take care of them. */
  exclusions = talloc_array (memCtx, bool, 65536);
  exclusions[(PidTagRowType >> 16) & 0xffff] = true;
  exclusions[(PidTagInstanceKey >> 16) & 0xffff] = true;
  exclusions[(PidTagInstanceNum >> 16) & 0xffff] = true;
  exclusions[(PidTagInstID >> 16) & 0xffff] = true;
  exclusions[(PidTagAttachNumber >> 16) & 0xffff] = true;
  exclusions[(PidTagFolderId >> 16) & 0xffff] = true;
  exclusions[(PidTagMid >> 16) & 0xffff] = true;
  exclusions[(PidTagSourceKey >> 16) & 0xffff] = true;
  exclusions[(PidTagParentSourceKey >> 16) & 0xffff] = true;
  exclusions[(PidTagParentFolderId >> 16) & 0xffff] = true;
  exclusions[(PidTagChangeKey >> 16) & 0xffff] = true;
  exclusions[(PidTagChangeNumber >> 16) & 0xffff] = true;
  exclusions[(PidTagPredecessorChangeList >> 16) & 0xffff] = true;

  row.cValues = 0;
  row.lpProps = talloc_array (memCtx, struct SPropValue, 65535);

  for (count = 0; count < availableProps->cValues; count++)
    {
      propTag = availableProps->aulPropTag[count];
      if (!exclusions[(propTag >> 16) & 0xffff])
        {
          error = [self getProperty: &data withTag: propTag inMemCtx: memCtx];
          if (error == MAPISTORE_SUCCESS && data)
            {
              set_SPropValue_proptag (row.lpProps + row.cValues, propTag,
                                      data);
              row.cValues++;
            }
        }
    }
  [newObject addPropertiesFromRow: &row];

  talloc_free (memCtx);

}

/* subclasses */
- (NSString *) nameInContainer
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSDate *) creationTime
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSDate *) lastModificationTime
{
  [self subclassResponsibility: _cmd];

  return nil;
}

/* logging */
- (NSString *) loggingPrefix
{
  return [NSString stringWithFormat:@"<%@:%p:%@>",
                   NSStringFromClass (isa), self, [self nameInContainer]];
}

@end
