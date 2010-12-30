/* MAPIStoreFSMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc
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
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSObject+Logs.h>

#import "EOQualifier+MAPIFS.h"
#import "MAPIStoreTypes.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSMessageTable.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"
#import "NSValue+MAPIStore.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreFSMessageTable

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  NSDictionary *properties;
  SOGoMAPIFSMessage *child;
  uint16_t valueType;
  id value;
  int rc;

  rc = MAPI_E_SUCCESS;

  child = [self lookupChild: childKey];
  properties = [child properties];
  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    {
      // [self logWithFormat: @"property %.8x found", propTag];
      valueType = (propTag & 0xffff);
      switch (valueType)
	{
	case PT_NULL:
	  *data = NULL;
	  break;
	case PT_SHORT:
	  *data = [value asShortInMemCtx: memCtx];
	  break;
	case PT_LONG:
	  *data = [value asLongInMemCtx: memCtx];
	  break;
	case PT_BOOLEAN:
	  *data = [value asBooleanInMemCtx: memCtx];
	  break;
	case PT_DOUBLE:
	  *data = [value asDoubleInMemCtx: memCtx];
	  break;
	case PT_UNICODE:
	case PT_STRING8:
	  *data = [value asUnicodeInMemCtx: memCtx];
	  break;
	case PT_SYSTIME:
	  *data = [value asFileTimeInMemCtx: memCtx];
	  break;
	case PT_BINARY:
	  *data = [value asShortBinaryInMemCtx: memCtx];
	  break;
	case PT_CLSID:
	  *data = [value asGUIDInMemCtx: memCtx];
	  break;

	default:
	  [self errorWithFormat: @"object type not handled: %d (0x%.4x)",
		valueType, valueType];
	  *data = NULL;
	  rc = MAPI_E_NO_SUPPORT;
	}
    }
  else
    rc = [super getChildProperty: data forKey: childKey withTag: propTag];

  return rc;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  return [NSString stringWithFormat: @"%@", MAPIPropertyKey (property)];
}

- (NSArray *) childKeys
{
  return [folder toOneRelationshipKeys];
}

- (NSArray *) restrictedChildKeys
{
  NSMutableArray *keys;
  NSArray *allKeys;
  NSUInteger count, max;
  NSString *messageKey;

  allKeys = [self cachedChildKeys];
  if (restrictionState == MAPIRestrictionStateAlwaysTrue)
    keys = (NSMutableArray *) allKeys;
  else if (restrictionState == MAPIRestrictionStateAlwaysFalse)
    keys = (NSMutableArray *) [NSArray array];
  else
    {
      [self logWithFormat: @"%s: getting restricted keys", __PRETTY_FUNCTION__];
      max = [allKeys count];
      keys = [NSMutableArray arrayWithCapacity: max];
      if (restrictionState == MAPIRestrictionStateNeedsEval)
	{
	  for (count = 0; count < max; count++)
	    {
	      messageKey = [allKeys objectAtIndex: count];
	      if ([restriction evaluateMAPIFSMessage: 
				 [folder lookupName: messageKey
					 inContext: nil
					 acquire: NO]])
		[keys addObject: messageKey];
	    }
	}
      [self logWithFormat: @"  resulting keys: $$$%@$$$", keys];
    }

  return keys;
}

@end
