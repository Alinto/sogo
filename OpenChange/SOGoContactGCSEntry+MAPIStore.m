/* SOGoContactGCSEntry+MAPIStore.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/NGVCard.h>

#import "SOGoContactGCSEntry+MAPIStore.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>

@implementation SOGoContactGCSEntry (MAPIStoreMessage)

#if (GS_SIZEOF_LONG == 4)
static inline NSNumber *
MAPIPropertyNumber (unsigned long propTag)
{
  return [NSNumber numberWithUnsignedLong: propTag];
}
#elif (GS_SIZEOF_INT == 4)
static inline NSNumber *
MAPIPropertyNumber (unsigned int propTag)
{
  return [NSNumber numberWithUnsignedInt: propTag];
}
#else
#error No suitable type for 4 bytes integers
#endif

- (void) setMAPIProperties: (NSDictionary *) properties
{
  NGVCard *newCard, *oldCard;
  id value;

  [self logWithFormat: @"setMAPIProperties: %@", properties];

  oldCard = [self vCard];
  if (isNew)
    newCard = oldCard;
  else
    {
      newCard = [NGVCard new];
      [newCard setUid: [oldCard uid]];
      ASSIGN (card, newCard);
      [newCard release];
    }
  [newCard setTag: @"vcard"];
  [newCard setVersion: @"3.0"];
  [newCard setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
  [newCard setProfile: @"vCard"];

  value = [properties
            objectForKey: MAPIPropertyNumber (PR_DISPLAY_NAME_UNICODE)];
  if (!value)
    value = [properties
              objectForKey: MAPIPropertyNumber (PR_DISPLAY_NAME)];
  if (!value)
    value = [properties
              objectForKey: MAPIPropertyNumber (PR_DISPLAY_NAME)];
  if (value)
    [newCard setFn: value];

  value = [properties objectForKey: MAPIPropertyNumber (0x81b0001f)];
  if (value)
    [newCard addEmail: value types: nil];

  [self save];
}

@end
