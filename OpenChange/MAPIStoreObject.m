/* MAPIStoreObject.m - this file is part of SOGo
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

+ (id) mapiStoreObjectWithSOGoObject: (id) newSOGoObject
                         inContainer: (MAPIStoreObject *) newContainer
{
  id newObject;

  newObject = [[self alloc] initWithSOGoObject: newSOGoObject
                                   inContainer: newContainer];
  [newObject autorelease];

  return newObject;
}

+ (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  struct SPropTagArray *properties;
  const MAPIStorePropertyGetter *classGetters;
  NSUInteger count;
  enum MAPITAGS propTag;
  uint16_t propValue;

  properties = talloc_zero (memCtx, struct SPropTagArray);
  properties->aulPropTag = talloc_array (properties, enum MAPITAGS,
                                         MAPIStoreSupportedPropertiesCount);
  classGetters = MAPIStorePropertyGettersForClass (self);
  for (count = 0; count < MAPIStoreSupportedPropertiesCount; count++)
    {
      propTag = MAPIStoreSupportedProperties[count];
      propValue = (propTag & 0xffff0000) >> 16;
      if (classGetters[propValue])
        {
          properties->aulPropTag[properties->cValues] = propTag;
          properties->cValues++;
        }
    }

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;
}

- (id) init
{
  if ((self = [super init]))
    {
      classGetters = (IMP *) MAPIStorePropertyGettersForClass (isa);
      parentContainersBag = [NSMutableArray new];
      container = nil;
      sogoObject = nil;
      properties = [NSMutableDictionary new];
      isNew = NO;
    }

  [self logWithFormat: @"-init"];

  return self;
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [self init]))
    {
      ASSIGN (sogoObject, newSOGoObject);
      ASSIGN (container, newContainer);
    }

  return self;
}

- (void) dealloc
{
  [self logWithFormat: @"-dealloc"];
  [sogoObject release];
  [properties release];
  [parentContainersBag release];
  [container release];
  [super dealloc];
}

- (void) setIsNew: (BOOL) newIsNew
{
  isNew = newIsNew;
}

- (BOOL) isNew
{
  return isNew;
}

- (id) sogoObject
{
  return sogoObject;
}

- (MAPIStoreObject *) container
{
  return container;
}

- (NSString *) nameInContainer
{
  return [sogoObject nameInContainer];
}

- (MAPIStoreContext *) context
{
  return [container context];
}

- (MAPIStoreUserContext *) userContext
{
  return [[self context] userContext];
}

- (MAPIStoreMapping *) mapping
{
  return [[self userContext] mapping];
}

- (void) cleanupCaches
{
}

/* helpers */
- (uint64_t) objectId
{
  uint64_t objectId;

  if ([container isKindOfClass: MAPIStoreFolderK])
    objectId = [(MAPIStoreFolder *) container
               idForObjectWithKey: [sogoObject nameInContainer]];
  else
    {
      [self errorWithFormat: @"%s: container is not a folder", __PRETTY_FUNCTION__];
      objectId = (uint64_t) -1;
    }
 
  return objectId;
}

- (NSString *) url
{
  NSString *containerURL, *format;

  containerURL = [container url];
  if ([containerURL hasSuffix: @"/"])
    format = @"%@%@";
  else
    format = @"%@/%@";

  return  [NSString stringWithFormat: format,
                    containerURL, [self nameInContainer]];
}

- (void) addProperties: (NSDictionary *) newNewProperties
{
  [properties addEntriesFromDictionary: newNewProperties];
}

- (NSDictionary *) properties
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

  return rc;
}

/* helper getters */
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

/* getters */
- (int) getPidTagDisplayName: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject displayName] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagSearchKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [sogoObject nameInContainer];
  *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagGenerateExchangeViews: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagParentSourceKey: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getReplicaKey: data fromGlobCnt: [container objectId] >> 16
                    inMemCtx: memCtx];
}

- (int) getPidTagSourceKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getReplicaKey: data fromGlobCnt: [self objectId] >> 16
                    inMemCtx: memCtx];
}

- (uint64_t) objectVersion
{
  [self subclassResponsibility: _cmd];

  return ULLONG_MAX;
}

- (int) getPidTagChangeKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  uint64_t obVersion;

  obVersion = [self objectVersion];
  if (obVersion == ULLONG_MAX)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    rc = [self getReplicaKey: data fromGlobCnt: obVersion
                    inMemCtx: memCtx];

  return rc;
}

- (int) getPidTagChangeNumber: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc;
  uint64_t obVersion;

  obVersion = [self objectVersion];
  if (obVersion == ULLONG_MAX)
    rc = MAPISTORE_ERR_NOT_FOUND;
  else
    {
      *data = MAPILongLongValue (memCtx, ((obVersion << 16)
                                          | 0x0001));
      rc = MAPISTORE_SUCCESS;
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

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSUInteger count;
  struct SPropTagArray *availableProps;
  enum MAPITAGS propTag;

  availableProps = talloc_zero (memCtx, struct SPropTagArray);
  availableProps->aulPropTag = talloc_array (availableProps, enum MAPITAGS,
                                             MAPIStoreSupportedPropertiesCount);
  for (count = 0; count < MAPIStoreSupportedPropertiesCount; count++)
    {
      propTag = MAPIStoreSupportedProperties[count];
      if ([self canGetProperty: propTag])
        {
          availableProps->aulPropTag[availableProps->cValues] = propTag;
          availableProps->cValues++;
        }
    }

  *propertiesP = availableProps;

  return MAPISTORE_SUCCESS;  
}

- (BOOL) canGetProperty: (enum MAPITAGS) propTag
{
  uint16_t propValue;

  propValue = (propTag & 0xffff0000) >> 16;

  return (classGetters[propValue]
          || [properties objectForKey: MAPIPropertyKey (propTag)]);
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

/* subclasses */
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
