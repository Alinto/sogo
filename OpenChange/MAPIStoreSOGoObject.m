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

#import "MAPIStoreSOGoObject.h"

#undef DEBUG
#include <stdbool.h>
#include <talloc.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreSOGoObject

static Class MAPIStoreFolderK;

+ (void) initialize
{
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

- (id) init
{
  if ((self = [super init]))
    {
      sogoObject = nil;
      isNew = NO;
    }

  // [self logWithFormat: @"-init"];

  return self;
}

- (id) initWithSOGoObject: (id) newSOGoObject
              inContainer: (MAPIStoreObject *) newContainer
{
  if ((self = [self initInContainer: newContainer]))
    {
      ASSIGN (sogoObject, newSOGoObject);
    }

  return self;
}

- (void) dealloc
{
  // [self logWithFormat: @"-dealloc"];
  [sogoObject release];
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

- (void) cleanupCaches
{
}

/* helpers */
- (uint64_t) objectId
{
  return [container idForObjectWithKey: [sogoObject nameInContainer]];
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

/* helper getters */
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

/* subclasses */
- (uint64_t) objectVersion
{
  [self subclassResponsibility: _cmd];

  return ULLONG_MAX;
}

/* logging */
- (NSString *) loggingPrefix
{
  return [NSString stringWithFormat:@"<%@:%p:%@>",
                   NSStringFromClass (isa), self, [self nameInContainer]];
}

@end
