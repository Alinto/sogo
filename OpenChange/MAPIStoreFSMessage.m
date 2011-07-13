/* MAPIStoreFSMessage.m - this file is part of SOGo
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
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreTypes.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSMessage.h"

#undef DEBUG
#include <mapistore/mapistore_errors.h>

@implementation MAPIStoreFSMessage

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
  properties->aulPropTag = talloc_array (NULL, enum MAPITAGS,
                                         MAPIStoreSupportedPropertiesCount + 8);

  for (count = 0; count < MAPIStoreSupportedPropertiesCount; count++)
    properties->aulPropTag[count] = MAPIStoreSupportedProperties[count];

  /* FIXME (hack): append a few undocumented properties that can be added to
     FAI messages */
  for (count = 0; count < 8; count++)
    properties->aulPropTag[MAPIStoreSupportedPropertiesCount+count] = faiProperties[count];

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;
}

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) propTag
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  id value;
  enum MAPISTATUS rc;
 
  value = [[sogoObject properties] objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
  else
    rc = [super getProperty: data withTag: propTag inMemCtx: memCtx];

  return rc;
}

- (int) getPrSubject: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  /* if we get here, it means that the properties file didn't contain a
     relevant value */
  return [self getEmptyString: data inMemCtx: memCtx];
}

- (int) getPrMessageClass: (void **) data inMemCtx: (TALLOC_CTX *) memCtx
{
  /* if we get here, it means that the properties file didn't contain a
     relevant value */

  *data = [@"IPM.Note" asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getAvailableProperties: (struct SPropTagArray **) propertiesP
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *keys;
  NSUInteger count, max;
  struct SPropTagArray *properties;

  keys = [[sogoObject properties] allKeys];
  max = [keys count];

  properties = talloc_zero (NULL, struct SPropTagArray);
  properties->cValues = max;
  properties->aulPropTag = talloc_array (properties, enum MAPITAGS, max);
  for (count = 0; count < max; count++)
    {
// #if (GS_SIZEOF_LONG == 4)
//   return [NSNumber numberWithUnsignedLong: propTag];
// #elif (GS_SIZEOF_INT == 4)
//   return [NSNumber numberWithUnsignedInt: propTag];
// #else

#if (GS_SIZEOF_LONG == 4)
      properties->aulPropTag[count] = [[keys objectAtIndex: count] unsignedLongValue];
#elif (GS_SIZEOF_INT == 4)
      properties->aulPropTag[count] = [[keys objectAtIndex: count] unsignedIntValue];
#endif
    }

  *propertiesP = properties;

  return MAPISTORE_SUCCESS;  
}

- (void) save
{
  [sogoObject appendProperties: newProperties];
  [sogoObject save];
  [self resetNewProperties];
}

- (NSDate *) creationTime
{
  return [sogoObject creationTime];
}

- (NSDate *) lastModificationTime
{
  return [sogoObject lastModificationTime];
}

@end
