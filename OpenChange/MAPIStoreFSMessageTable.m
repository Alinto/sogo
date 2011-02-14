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
#import "NSObject+MAPIStore.h"
#import "SOGoMAPIFSFolder.h"
#import "SOGoMAPIFSMessage.h"

#import "MAPIStoreFSMessageTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreFSMessageTable

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) propTag
{
  NSDictionary *properties;
  SOGoMAPIFSMessage *child;
  id value;
  enum MAPISTATUS rc;

  child = [self lookupChild: childKey];
  properties = [child properties];
  value = [properties objectForKey: MAPIPropertyKey (propTag)];
  if (value)
    rc = [value getMAPIValue: data forTag: propTag inMemCtx: memCtx];
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
