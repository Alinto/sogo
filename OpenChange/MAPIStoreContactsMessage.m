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
#import <Foundation/NSCalendarDate.h>
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
#import "NSDate+MAPIStore.h"
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
              inMemCtx: (TALLOC_CTX *) memCtx
{
  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  *data = MAPILongValue (memCtx, 0x00000200);

  return MAPISTORE_SUCCESS;
}

- (int) getPrMessageClass: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Contact");

  return MAPISTORE_SUCCESS;
}

- (int) getPrOabName: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "PR_OAB_NAME_UNICODE");

  return MAPISTORE_SUCCESS;
}

- (int) getPrOabLangid: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  /* see http://msdn.microsoft.com/en-us/goglobal/bb895996.asxp */
  /* English US */
  *data = MAPILongValue (memCtx, 0x0409);

  return MAPISTORE_SUCCESS;
}

- (int) getPrTitle: (void **) data
          inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] title];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrCompanyName: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
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
                   inMemCtx: (TALLOC_CTX *) memCtx
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
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00065001);

  return MAPISTORE_SUCCESS;
}

- (int) getPrSubject: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrDisplayName: data inMemCtx: memCtx];
}

- (int) getPidLidFileUnder: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPrDisplayName: data inMemCtx: memCtx];
}

- (int) getPidLidFileUnderId: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0xffffffff);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1DisplayName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
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
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail1DisplayName: data inMemCtx: memCtx];
}

- (int) getPidLidEmail1EmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrAccount: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail1EmailAddress: data inMemCtx: memCtx];
}

- (int) getPrContactEmailAddresses: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
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
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[NSString stringWithFormat: @"SMTP:%@", stringValue]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrSearchKey: (void **) data // TODO
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrMailPermission: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidLidEmail2EmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
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
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail2EmailAddress: data inMemCtx: memCtx];
}
    
- (int) getPrBody: (void **) data
         inMemCtx: (TALLOC_CTX *) memCtx
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
           inMemCtx: (TALLOC_CTX *) memCtx
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
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"work" excluding: @"fax"
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrHomeTelephoneNumber: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"home" excluding: @"fax"
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrMobileTelephoneNumber: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"cell" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrPrimaryTelephoneNumber: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrBusinessHomePage: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"url" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrPersonalHomePage: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"url" ofType: @"home" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidLidEmail1AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidLidEmail2AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidLidEmail3AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidLidInstantMessagingAddress: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
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
                        inMemCtx: (TALLOC_CTX *) memCtx
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
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"label" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrPostOfficeBox: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPrStreetAddress: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 2 inData: data inMemCtx: memCtx];
}

- (int) getPrLocality: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 3 inData: data inMemCtx: memCtx];
}

- (int) getPrStateOrProvince: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 4 inData: data inMemCtx: memCtx];
}

- (int) getPrPostalCode: (void **) data
               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 5 inData: data inMemCtx: memCtx];
}

- (int) getPrCountry: (void **) data
            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 6 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddress: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"label" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressPostOfficeBox: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressStreet: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 2 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressCity: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 3 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressState: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 4 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressPostalCode: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 5 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddressCountry: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 6 inData: data inMemCtx: memCtx];
}

- (int) getPrNickname: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] nickname];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPrBirthday: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
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
    [element addAttribute: @"type" value: @"pref"];
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
