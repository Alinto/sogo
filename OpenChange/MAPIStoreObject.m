/* MAPIStoreObject.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <NGExtensions/NSObject+Logs.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreFolder.h"
#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreTypes.h"
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

  properties = talloc_zero(memCtx, struct SPropTagArray);
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
      mapiRetainCount = 0;
      classGetters = (IMP *) MAPIStorePropertyGettersForClass (isa);
      parentContainersBag = [NSMutableArray new];
      container = nil;
      sogoObject = nil;
      newProperties = [NSMutableDictionary new];
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
  [newProperties release];
  [parentContainersBag release];
  [container release];
  [super dealloc];
}

- (void) setMAPIRetainCount: (uint32_t) newCount
{
  mapiRetainCount = newCount;
}

- (uint32_t) mapiRetainCount
{
  return mapiRetainCount;
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

- (id) context
{
  return [container context];
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

- (NSTimeZone *) ownerTimeZone
{
  NSString *owner;
  SOGoUserDefaults *ud;
  NSTimeZone *tz;
  WOContext *woContext;

  woContext = [[self context] woContext];
  owner = [sogoObject ownerInContext: woContext];
  ud = [[SOGoUser userWithLogin: owner] userDefaults];
  tz = [ud timeZone];

  return tz;
}

- (void) addNewProperties: (NSDictionary *) newNewProperties
{
  [newProperties addEntriesFromDictionary: newNewProperties];
}

- (NSDictionary *) newProperties
{
  return newProperties;
}

- (void) resetNewProperties
{
  [newProperties removeAllObjects];
}

- (int) getProperty: (void **) data
            withTag: (enum MAPITAGS) propTag
           inMemCtx: (TALLOC_CTX *) memCtx
{
  MAPIStorePropertyGetter method = NULL;
  uint16_t propValue;
  SEL methodSel;
  const char *propName;
  int rc = MAPISTORE_ERR_NOT_FOUND;

  propValue = (propTag & 0xffff0000) >> 16;
  methodSel = MAPIStoreSelectorForPropertyGetter (propValue);

  method = (MAPIStorePropertyGetter) classGetters[propValue];
  if (method)
    rc = method (self, methodSel, data, memCtx);
  else
    {
      *data = NULL;
      
      if (methodSel)
        {
          propName = get_proptag_name (propTag);
          if (!propName)
            propName = "<unknown>";
          // [self warnWithFormat:
          //         @"unimplemented selector (%@) for %s (0x%.8x)",
          //       NSStringFromSelector (methodSel), propName, propTag];
        }
      // else
      //   [self warnWithFormat: @"unsupported property tag: 0x%.8x", propTag];
    }

  return rc;
}

/* helper getters */
- (int) getReplicaKey: (void **) data
          fromGlobCnt: (uint64_t) objectCnt
             inMemCtx: (TALLOC_CTX *) memCtx
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
  [replicaKey appendBytes: buffer
                   length: 6];
  *data = [replicaKey asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

/* getters */
- (int) getPrDisplayName: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[sogoObject displayName] asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrSearchKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [sogoObject nameInContainer];
  *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrGenerateExchangeViews: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPrParentSourceKey: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getReplicaKey: data fromGlobCnt: [container objectId] >> 16
                    inMemCtx: memCtx];
}

- (int) getPrSourceKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getReplicaKey: data fromGlobCnt: [self objectId] >> 16
                    inMemCtx: memCtx];
}

- (uint64_t) objectVersion
{
  uint32_t lmTime;

  lmTime = (uint32_t) [[self lastModificationTime] timeIntervalSince1970];
  if (lmTime < 0x4dbb2dbe) /* oc_version_time */
    lmTime = 0x4dbb2dbe;

  return ((([self objectId] & 0xffff000000000000LL) >> 16)
          | (exchange_globcnt((uint64_t) lmTime - 0x4dbb2dbe) >> 16));
}

- (int) getPrChangeKey: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getReplicaKey: data fromGlobCnt: [self objectVersion]
                    inMemCtx: memCtx];
}

- (int) getPrChangeNum: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongLongValue (memCtx, ([self objectVersion] << 16) | 0x0001);

  return MAPISTORE_SUCCESS;
}

- (int) getPrCreationTime: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self creationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrLastModificationTime: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = [[self lastModificationTime] asFileTimeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [isa getAvailableProperties: propertiesP inMemCtx: memCtx];
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

- (int) setProperties: (struct SRow *) aRow
{
  struct SPropValue *cValue;
  NSUInteger counter;

  for (counter = 0; counter < aRow->cValues; counter++)
    {
      cValue = aRow->lpProps + counter;
      [newProperties setObject: NSObjectFromSPropValue (cValue)
                        forKey: MAPIPropertyKey (cValue->ulPropTag)];
    }

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

- (id) lookupChild: (NSString *) childKey
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  return nil;
}

@end
