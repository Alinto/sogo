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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/NGVCard.h>

#include <mapistore/mapistore_nameid.h>

#import "MAPIStoreTypes.h"

#import "SOGoContactGCSEntry+MAPIStore.h"

@implementation SOGoContactGCSEntry (MAPIStoreMessage)

- (void) setMAPIProperties: (NSDictionary *) properties
{
  NGVCard *newCard, *oldCard;
  NSArray *addresses;
  CardElement *adr;
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
            objectForKey: MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE)];
  if (value)
    [newCard setFn: value];

  value = [properties objectForKey: MAPIPropertyKey (PidLidEmail1EmailAddress)];
  if (value)
    [newCard addEmail: value types: nil];

  /* Work address */
  addresses = [newCard childrenWithTag: @"adr"
			  andAttribute: @"type"
			   havingValue: @"work"];
  if ([addresses count] > 0)
    {
      adr = [addresses objectAtIndex: 0];
      [adr setValues: nil];
    }
  else
    {
      adr = [CardElement elementWithTag: @"adr"];
      [adr addAttribute: @"type" value: @"work"];
      [card addChild: adr];
    }

  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostOfficeBox)];
  if (value)
    [adr setValue: 0 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressStreet)];
  if (value)
    [adr setValue: 2 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressCity)];
  if (value)
    [adr setValue: 3 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressState)];
  if (value)
    [adr setValue: 4 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostalCode)];
  if (value)
    [adr setValue: 5 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressCountry)];
  if (value)
    [adr setValue: 6 to: value];

  ASSIGN (content, [newCard versitString]);
}

@end
