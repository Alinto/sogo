/* MAPIStoreContactsMessage.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/NGVCard.h>
#import <NGCards/NSArray+NGCards.h>
#import <SOGo/SOGoUserDefaults.h>
#import <Contacts/SOGoContactGCSEntry.h>

#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreTypes.h"
#import "NSArray+MAPIStore.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreContactsMessage

- (int) getPrIconIndex: (void **) data // TODO
{
  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  *data = MAPILongValue (memCtx, 0x00000200);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
{
  *data = talloc_strdup (memCtx, "IPM.Contact");

  return MAPISTORE_SUCCESS;
}

- (int) getPrOabName: (void **) data
{
  *data = talloc_strdup (memCtx, "PR_OAB_NAME_UNICODE");

  return MAPISTORE_SUCCESS;
}

- (int) getPrOabLangid: (void **) data
{
  /* see http://msdn.microsoft.com/en-us/goglobal/bb895996.asxp */
  /* English US */
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPrTitle: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] title];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrCompanyName: (void **) data
{
  NSArray *values;
  NSString *stringValue;
  
  values = [[sogoObject vCard] org];
  stringValue = nil;
    
  if ([values count] > 0)
    stringValue = [values objectAtIndex: 0];
  else
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrDepartmentName: (void **) data
{
  NSArray *values;
  NSString *stringValue;
  
  values = [[sogoObject vCard] org];
  stringValue = nil;

  if ([values count] > 1)
    stringValue = [values objectAtIndex: 1];
  else
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrSendInternetEncoding: (void **) data
{
  *data = MAPILongValue (memCtx, 0x00065001);

  return MAPISTORE_SUCCESS;
}

- (int) getPrSubject: (void **) data
{
  return [self getPrDisplayName: data];
}

- (int) getPidLidFileUnder: (void **) data
{
  return [self getPrDisplayName: data];
}

- (int) getPidLidFileUnderId: (void **) data
{
  *data = MAPILongValue (memCtx, 0xffffffff);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1DisplayName: (void **) data
{
  NGVCard *vCard;
  NSString *fn, *email;

  vCard = [sogoObject vCard];
  fn = [vCard fn];
  email = [vCard preferredEMail];
  *data = [[NSString stringWithFormat: @"%@ <%@>", fn, email]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1OriginalDisplayName: (void **) data
{
  return [self getPidLidEmail1DisplayName: data];
}

- (int) getPidLidEmail1EmailAddress: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccount: (void **) data
{
  return [self getPidLidEmail1EmailAddress: data];
}

- (int) getPrContactEmailAddresses: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  if (!stringValue)
    stringValue = @"";
  *data = [[NSArray arrayWithObject: stringValue]
            asArrayOfUnicodeStringsInCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrEmsAbTargetAddress: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[NSString stringWithFormat: @"SMTP:%@", stringValue]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrSearchKey: (void **) data // TODO
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMailPermission: (void **) data
{
  return [self getYes: data];
}

- (int) getPidLidEmail2EmailAddress: (void **) data
{
  NSMutableArray *emails;
  NSString *email, *stringValue;
  NGVCard *card;
  NSUInteger count, max;
    
  emails = [NSMutableArray array];
  stringValue = nil;
    
  card = [sogoObject vCard];
  [emails addObjectsFromArray: [card childrenWithTag: @"email"]];
  [emails removeObjectsInArray: [card childrenWithTag: @"email"
                                         andAttribute: @"type"
                                          havingValue: @"pref"]];

  max = [emails count];
  for (count = 0; !stringValue && count < max; count++)
    {
      email = [[emails objectAtIndex: count] value: 0];
      
      if ([email caseInsensitiveCompare: [card preferredEMail]] != NSOrderedSame)
        stringValue = email;
    }

  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail2OriginalDisplayName: (void **) data // Other email
{
  return [self getPidLidEmail2EmailAddress: data];
}
    
- (int) getPrBody: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] note];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) _getElement: (NSString *) elementTag
             ofType: (NSString *) aType
          excluding: (NSString *) aTypeToExclude
              atPos: (NSUInteger) pos
             inData: (void **) data
{
  NSArray *elements;
  CardElement *ce;
  NSUInteger count, max;
  NGVCard *vCard;
  NSString *stringValue;

  stringValue = nil;

  vCard = [sogoObject vCard];
  elements = [[vCard childrenWithTag: elementTag]
	       cardElementsWithAttribute: @"type"
			     havingValue: aType];
  max = [elements count];
  for (count = 0; !stringValue && count < max; count++)
    {
      ce = [elements objectAtIndex: count];
      if (!aTypeToExclude
	  || ![ce hasAttribute: @"type" havingValue: aTypeToExclude])
        stringValue = [ce value: pos];
    }

  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrOfficeTelephoneNumber: (void **) data
{
  return [self _getElement: @"tel" ofType: @"work" excluding: @"fax"
                     atPos: 0 inData: data];
}

- (int) getPrHomeTelephoneNumber: (void **) data
{
  return [self _getElement: @"tel" ofType: @"home" excluding: @"fax"
                     atPos: 0 inData: data];
}

- (int) getPrMobileTelephoneNumber: (void **) data
{
  return [self _getElement: @"tel" ofType: @"cell" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPrPrimaryTelephoneNumber: (void **) data
{
  return [self _getElement: @"tel" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPrBusinessHomePage: (void **) data
{
  return [self _getElement: @"url" ofType: @"work" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPrPersonalHomePage: (void **) data
{
  return [self _getElement: @"url" ofType: @"home" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPidLidEmail1AddressType: (void **) data
{
  return [self getSMTPAddrType: data];
}

- (int) getPidLidEmail2AddressType: (void **) data
{
  return [self getSMTPAddrType: data];
}

- (int) getPidLidEmail3AddressType: (void **) data
{
  return [self getSMTPAddrType: data];
}

- (int) getPidLidInstantMessagingAddress: (void **) data
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-aim"]
                  value: 0];
  if (!stringValue)
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidPostalAddressId: (void **) data
{
  NSArray *elements;
  CardElement *element;
  uint32_t longValue = 0;
  NGVCard *vCard;

  vCard = [sogoObject vCard];
  elements = [[vCard childrenWithTag: @"adr"]
	       cardElementsWithAttribute: @"type"
			     havingValue: @"pref"];
  if ([elements count] > 0)
    {
      element = [elements objectAtIndex: 0];
      if ([element hasAttribute: @"type"
                    havingValue: @"home"])
        longValue = 1; // The Home Address is the mailing address.
      else if ([element hasAttribute: @"type"
                         havingValue: @"work"])
        longValue = 2; // The Work Address is the mailing address.
    }
  *data = MAPILongValue (memCtx, longValue);
  
  return MAPISTORE_SUCCESS;
}

- (int) getPrPostalAddress: (void **) data
{
  return [self _getElement: @"label" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPrPostOfficeBox: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPrStreetAddress: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 2 inData: data];
}

- (int) getPrLocality: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 3 inData: data];
}

- (int) getPrStateOrProvince: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 4 inData: data];
}

- (int) getPrPostalCode: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 5 inData: data];
}

- (int) getPrCountry: (void **) data
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 6 inData: data];
}

- (int) getPidLidWorkAddress: (void **) data
{
  return [self _getElement: @"label" ofType: @"work" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPidLidWorkAddressPostOfficeBox: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 0 inData: data];
}

- (int) getPidLidWorkAddressStreet: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 2 inData: data];
}

- (int) getPidLidWorkAddressCity: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 3 inData: data];
}

- (int) getPidLidWorkAddressState: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 4 inData: data];
}

- (int) getPidLidWorkAddressPostalCode: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 5 inData: data];
}

- (int) getPidLidWorkAddressCountry: (void **) data
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 6 inData: data];
}

- (int) getPrNickname: (void **) data
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] nickname];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrBirthday: (void **) data
{
  NSCalendarDate *dateValue;
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;
    
  stringValue = [[sogoObject vCard] bday];
  if (stringValue)
    {
      dateValue = [NSCalendarDate dateWithString: stringValue
                                  calendarFormat: @"%Y-%m-%d"];
      // FIXME: We add a day, otherwise Outlook 2003 will display at day earlier
      dateValue = [dateValue addYear: 0 month: 0 day: 1 hour: 0 minute: 0 second: 0];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;
  
  return rc;
}

- (void) save
{
  NGVCard *newCard;
  NSArray *elements;
  CardElement *element;
  int postalAddressId;
  id value;

  [self logWithFormat: @"setMAPIProperties: %@", newProperties];

  newCard = [sogoObject vCard];
  [newCard setTag: @"vcard"];
  [newCard setVersion: @"3.0"];
  [newCard setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
  [newCard setProfile: @"vCard"];

  value = [newProperties
            objectForKey: MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE)];
  if (value)
    [newCard setFn: value];

  elements = [newCard childrenWithTag: @"email"];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidEmail1EmailAddress)];
  if (value)
    {
      if ([elements count] > 0)
	[[elements objectAtIndex: 0] setValue: 0 to: value];
      else
	[newCard addEmail: value
		    types: [NSArray arrayWithObject: @"pref"]];
    }
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidEmail2EmailAddress)];
  if (value)
    {
      if ([elements count] > 1)
	[[elements objectAtIndex: 1] setValue: 0 to: value];
      else
	[newCard addEmail: value types: nil];
    }
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidEmail3EmailAddress)];
  if (value)
    {
      if ([elements count] > 2)
	[[elements objectAtIndex: 2] setValue: 0 to: value];
      else
	[newCard addEmail: value types: nil];
    }

  postalAddressId = [[newProperties objectForKey: MAPIPropertyKey (PidLidPostalAddressId)]
		      intValue];

  /* Work address */
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddress)];
  if ([value length])
    {
      elements = [newCard childrenWithTag: @"label"
			     andAttribute: @"type"
			      havingValue: @"work"];
      if ([elements count] > 0)
	element = [elements objectAtIndex: 0];
      else
	{
	  element = [CardElement elementWithTag: @"label"];
	  [element addAttribute: @"type" value: @"work"];
	  [newCard addChild: element];
	}
      if (postalAddressId == 2)
	{
	  [element removeValue: @"pref"
		 fromAttribute: @"type"];
	  [element addAttribute: @"type"
			  value: @"pref"];
	}
      [element setValue: 0 to: value];
    }

  elements = [newCard childrenWithTag: @"adr"
			 andAttribute: @"type"
			  havingValue: @"work"];
  if ([elements count] > 0)
    element = [elements objectAtIndex: 0];
  else
    {
      element = [CardElement elementWithTag: @"adr"];
      [element addAttribute: @"type" value: @"work"];
      [newCard addChild: element];
    }
  if (postalAddressId == 2)
    [element addAttribute: @"type"
		    value: @"pref"];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostOfficeBox)];
  if (value)
    [element setValue: 0 to: value];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressStreet)];
  if (value)
    [element setValue: 2 to: value];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressCity)];
  if (value)
    [element setValue: 3 to: value];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressState)];
  if (value)
    [element setValue: 4 to: value];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressPostalCode)];
  if (value)
    [element setValue: 5 to: value];
  value = [newProperties objectForKey: MAPIPropertyKey (PidLidWorkAddressCountry)];
  if (value)
    [element setValue: 6 to: value];

  [sogoObject saveContentString: [newCard versitString]];
}

@end
