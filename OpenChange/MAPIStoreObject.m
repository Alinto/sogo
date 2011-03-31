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

#import "MAPIStoreFolder.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
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

- (id) init
{
  if ((self = [super init]))
    {
      parentContainersBag = [NSMutableArray new];
      container = nil;
      sogoObject = nil;
      newProperties = [NSMutableDictionary new];
      memCtx =  talloc_size (NULL, 0);
      isNew = NO;
    }

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
  [parentContainersBag release];
  [container release];
  [sogoObject release];
  [newProperties dealloc];
  talloc_free (memCtx);
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

- (void) addActiveTable: (MAPIStoreTable *) activeTable
{
  [self subclassResponsibility: _cmd];
}

- (void) removeActiveTable: (MAPIStoreTable *) activeTable
{
  [self subclassResponsibility: _cmd];
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
{
  NSString *stringValue;
  int rc;
  const char *propName;

  /* TODO: handle unsaved properties */

  rc = MAPISTORE_SUCCESS;
  switch (propTag)
    {
    case PR_DISPLAY_NAME_UNICODE:
      *data = [[sogoObject displayName] asUnicodeInMemCtx: memCtx];
      break;
    case PR_SEARCH_KEY: // TODO
      stringValue = [sogoObject nameInContainer];
      *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
		asBinaryInMemCtx: memCtx];
      break;
    case PR_GENERATE_EXCHANGE_VIEWS: // TODO
      *data = MAPIBoolValue (memCtx, NO);
      break;

    default:
      propName = get_proptag_name (propTag);
      if (!propName)
	propName = "<unknown>";
      [self warnWithFormat:
	      @"unhandled or NULL value: %s (0x%.8x), childKey: %@",
	    propName, propTag, [sogoObject nameInContainer]];
      // if ((propTag & 0x001F) == 0x001F)
      // 	{
      // 	  stringValue = [NSString stringWithFormat: @"fake %s (0x.8x) value",
      // 				  propName, propTag];
      // 	  *data = [stringValue asUnicodeInMemCtx: memCtx];
      // 	  rc = MAPISTORE_SUCCESS;
      // 	}
      // else
      // 	{
	  *data = NULL;
	  rc = MAPISTORE_ERR_NOT_FOUND;
	// }
      break;
    }

  return rc;
}

/* MAPIStoreProperty protocol */
- (int) getProperties: (struct mapistore_property_data *) data
             withTags: (enum MAPITAGS *) tags
             andCount: (uint16_t) columnCount
{
  uint16_t count;

  for (count = 0; count < columnCount; count++)
    data[count].error = [self getProperty: &data[count].data
                                  withTag: tags[count]];


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
- (id) lookupChild: (NSString *) childKey
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) childKeysMatchingQualifier: (EOQualifier *) qualifier
                        andSortOrderings: (NSArray *) sortOrderings
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
