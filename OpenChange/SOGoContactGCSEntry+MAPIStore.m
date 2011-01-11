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
  NSArray *elements;
  CardElement *element;
  int postalAddressId;
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

  postalAddressId = [[properties objectForKey: MAPIPropertyKey (PidLidPostalAddressId)]
		      intValue];

  /* Work address */
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddress)];
  if ([value length])
    {
      elements = [newCard childrenWithTag: @"label"
			     andAttribute: @"type"
			      havingValue: @"work"];
      if ([elements count] > 0)
	{
	  element = [elements objectAtIndex: 0];
	  [element setValues: nil];
	}
      else
	{
	  element = [CardElement elementWithTag: @"label"];
	  [element addAttribute: @"type" value: @"work"];
	  [card addChild: element];
	}
      if (postalAddressId == 2)
	[element addAttribute: @"type"
			value: @"pref"];
      [element setValue: 0 to: value];
    }

  elements = [newCard childrenWithTag: @"adr"
			  andAttribute: @"type"
			   havingValue: @"work"];
  if ([elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      [element setValues: nil];
    }
  else
    {
      element = [CardElement elementWithTag: @"adr"];
      [element addAttribute: @"type" value: @"work"];
      [card addChild: element];
    }
  if (postalAddressId == 2)
    [element addAttribute: @"type"
                value: @"pref"];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostOfficeBox)];
  if (value)
    [element setValue: 0 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressStreet)];
  if (value)
    [element setValue: 2 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressCity)];
  if (value)
    [element setValue: 3 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressState)];
  if (value)
    [element setValue: 4 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostalCode)];
  if (value)
    [element setValue: 5 to: value];
  value = [properties objectForKey: MAPIPropertyKey (PidLidWorkAddressCountry)];
  if (value)
    [element setValue: 6 to: value];

  ASSIGN (content, [newCard versitString]);
}

@end
