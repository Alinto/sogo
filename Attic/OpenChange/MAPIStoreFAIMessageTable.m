/* MAPIStoreFAIMessageTable.m - this file is part of SOGo
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

#import "MAPIStoreFAIMessage.h"
#import "MAPIStoreFolder.h"

#import "MAPIStoreFAIMessageTable.h"

#undef DEBUG
#include <talloc.h>
#include <util/time.h>
#include <mapistore/mapistore.h>

static Class MAPIStoreFAIMessageK = Nil;

@implementation MAPIStoreFAIMessageTable

+ (void) initialize
{
  MAPIStoreFAIMessageK = [MAPIStoreFAIMessage class];
}

+ (Class) childObjectClass
{
  return MAPIStoreFAIMessageK;
}

- (id) init
{
  if ((self = [super init]))
    {
      tableType = MAPISTORE_FAI_TABLE;
    }

  return self;
}

- (NSArray *) childKeys
{
  if (!childKeys)
    {
      childKeys = [(MAPIStoreFolder *)
                    container faiMessageKeysMatchingQualifier: nil
                                             andSortOrderings: sortOrderings];
      [childKeys retain];
    }

  return childKeys;
}

- (NSArray *) restrictedChildKeys
{
  NSArray *keys;

  if (!restrictedChildKeys)
    {
      if (restrictionState != MAPIRestrictionStateAlwaysTrue)
        {
          if (restrictionState == MAPIRestrictionStateNeedsEval)
            keys = [(MAPIStoreFolder *)
                     container faiMessageKeysMatchingQualifier: restriction
                                              andSortOrderings: sortOrderings];
          else
            keys = [NSArray array];
        }
      else
        keys = [self childKeys];

      ASSIGN (restrictedChildKeys, keys);
    }

  return restrictedChildKeys;
}

- (id) lookupChild: (NSString *) childKey
{
  return [(MAPIStoreFolder *) container lookupFAIMessage: childKey];
}

@end
