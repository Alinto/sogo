/* SOGoCacheGCSObject+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#include "MAPIStoreTypes.h"

#include "SOGoCacheGCSObject+MAPIStore.h"

@implementation SOGoCacheGCSObject (MAPIStore)

- (Class) mapistoreMessageClass
{
  NSString *className, *mapiMsgClass;

  switch (objectType)
    {
    case MAPIMessageCacheObject:
      mapiMsgClass = [properties
                       objectForKey: MAPIPropertyKey (PidTagMessageClass)];
      if (mapiMsgClass)
        {
          if ([mapiMsgClass isEqualToString: @"IPM.StickyNote"])
            className = @"MAPIStoreNotesMessage";
          else
            className = @"MAPIStoreDBMessage";
          //[self logWithFormat: @"PidTagMessageClass = '%@', returning '%@'",
          //      mapiMsgClass, className];
        }
      else
        {
          //[self warnWithFormat: @"PidTagMessageClass is not set, falling back"
          //      @" to 'MAPIStoreDBMessage'"];
          className = @"MAPIStoreDBMessage";
        }
      break;
    case MAPIFAICacheObject:
      className = @"MAPIStoreFAIMessage";
      break;
    default:
      [NSException raise: @"MAPIStoreIOException"
                  format: @"message class should not be queried for objects"
                   @" of type '%d'", objectType];
    }

  return NSClassFromString (className);
}

@end
