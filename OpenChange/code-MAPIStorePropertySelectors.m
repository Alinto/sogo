/* code-MAPIStorePropertySelectors.m - this file is part of SOGo
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

#import <Foundation/NSMapTable.h>
#import <NGExtensions/NGLogger.h>

#undef DEBUG
#include <mapistore/mapistore.h>

const MAPIStorePropertyGetter *
MAPIStorePropertyGettersForClass (Class klass)
{
  static NSMapTable *classesTable = nil;
  MAPIStorePropertyGetter *getters;
  MAPIStorePropertyGetter getter;
  uint16_t count, idx;
  SEL currentSel;
  
  if (!classesTable)
    classesTable = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
                                     NSNonOwnedPointerMapValueCallBacks,
                                     0);

  getters = NSMapGet (classesTable, klass);
  if (!getters)
    {
      getters = NSZoneCalloc (NULL, 65536, sizeof (MAPIStorePropertyGetter));
      NSMapInsert (classesTable, klass, getters);
      for (count = 0; count < 65535; count++)
        {
          idx = MAPIStorePropertyGettersIdx[count];
          if (idx != 0xffff && !getters[count])
            {
              currentSel = MAPIStorePropertyGetterSelectors[idx];
              if ([klass instancesRespondToSelector: currentSel])
                {
                  getter = (MAPIStorePropertyGetter)
                    [klass instanceMethodForSelector: currentSel];
                  if (getter)
                    getters[count] = getter;
                }
            }
        }
    }

  return getters;
}

SEL MAPIStoreSelectorForPropertyGetter (uint16_t propertyId)
{
  return ((MAPIStorePropertyGettersIdx[propertyId] != 0xffff)
          ? MAPIStorePropertyGetterSelectors[MAPIStorePropertyGettersIdx[propertyId]]
          : NULL);
}
