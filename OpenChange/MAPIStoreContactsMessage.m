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
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreContactsMessage

- (CardElement *) _element: (NSString *) elementTag
		    ofType: (NSString *) aType
		 excluding: (NSString *) aTypeToExclude
		    inCard: (NGVCard *) card
{
  NSArray *elements;
  CardElement *ce, *found;
  NSUInteger count, max;

  found = nil;

  elements = [[card childrenWithTag: elementTag]
	       cardElementsWithAttribute: @"type"
			     havingValue: aType];
  max = [elements count];
  for (count = 0; !found && count < max; count++)
    {
      ce = [elements objectAtIndex: count];
      if (!aTypeToExclude
	  || ![ce hasAttribute: @"type" havingValue: aTypeToExclude])
	found = ce;
    }

  return found;
}

- (enum MAPISTATUS) getProperty: (void **) data
                        withTag: (enum MAPITAGS) proptag
{
  NSString *stringValue, *stringValue2;
  CardElement *element;
  uint32_t longValue;
  NGVCard *vCard;
  enum MAPISTATUS rc;

  rc = MAPI_E_SUCCESS;
  switch (proptag)
    {
    case PR_ICON_INDEX: // TODO
      /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
      *data = MAPILongValue (memCtx, 0x00000200);
      break;
    case PR_MESSAGE_CLASS_UNICODE:
      *data = talloc_strdup (memCtx, "IPM.Contact");
      break;
      // case PR_VD_NAME_UNICODE:
      //         *data = talloc_strdup (memCtx, "PR_VD_NAME_UNICODE");
      //         break;
      // case PR_EMS_AB_DXA_REMOTE_CLIENT_UNICODE: "Home:" ???
      //         *data = talloc_strdup (memCtx, "PR_EMS...");
      //         break;
    case PR_OAB_NAME_UNICODE:
      *data = talloc_strdup (memCtx, "PR_OAB_NAME_UNICODE");
      break;
    case PR_OAB_LANGID:
      /* see http://msdn.microsoft.com/en-us/goglobal/bb895996.asxp */
      /* English US */
      *data = MAPILongValue (memCtx, 0x0409);
      break;

    case PR_TITLE_UNICODE:
      stringValue = [[sogoObject vCard] title];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_COMPANY_NAME_UNICODE:
    case PR_DEPARTMENT_NAME_UNICODE:
      {
	NSArray *values;
	
	values = [[sogoObject vCard] org];
	stringValue = nil;

	if (proptag == PR_COMPANY_NAME_UNICODE && [values count] > 0)
	  stringValue = [values objectAtIndex: 0];
	else if (proptag == PR_DEPARTMENT_NAME_UNICODE && [values count] > 1)
	  stringValue = [values objectAtIndex: 1];
	
	if (!stringValue)
	  stringValue = @"";
	*data = [stringValue asUnicodeInMemCtx: memCtx];
      }
      break;

    case PR_SEND_INTERNET_ENCODING:
      *data = MAPILongValue (memCtx, 0x00065001);
      break;

    case PR_SUBJECT_UNICODE:
    case PR_DISPLAY_NAME_UNICODE: // Full Name
    case PidLidFileUnder: // contact block title name
      rc = [super getProperty: data
                      withTag: PR_DISPLAY_NAME_UNICODE];
      break;
    case PidLidFileUnderId: 
      *data = MAPILongValue (memCtx, 0xffffffff);
      break;

    case PidLidEmail1OriginalDisplayName:
    case PidLidEmail1DisplayName:
      vCard = [sogoObject vCard];
      stringValue = [vCard fn];
      stringValue2 = [vCard preferredEMail];
      *data = [[NSString stringWithFormat: @"%@ <%@>",
                         stringValue, stringValue2]
                asUnicodeInMemCtx: memCtx];
      break;

    case PidLidEmail1EmailAddress:
    case PR_ACCOUNT_UNICODE:
      stringValue = [[sogoObject vCard] preferredEMail];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_CONTACT_EMAIL_ADDRESSES_UNICODE:
      stringValue = [[sogoObject vCard] preferredEMail];
      *data = [[NSArray arrayWithObject: stringValue]
                asArrayOfUnicodeStringsInCtx: memCtx];
      break;

    case PR_EMS_AB_TARGET_ADDRESS_UNICODE:
      stringValue = [[sogoObject vCard] preferredEMail];
      *data = [[NSString stringWithFormat: @"SMTP:%@", stringValue]
                asUnicodeInMemCtx: memCtx];
      break;

    case PR_SEARCH_KEY: // TODO
      stringValue = [[sogoObject vCard] preferredEMail];
      *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
		asBinaryInMemCtx: memCtx];
      break;

    case PR_MAIL_PERMISSION:
         *data = MAPIBoolValue (memCtx, YES);
         break;

    //
    // TODO - same logic as -secondaryEmail in UI/Contacts/UIxContactView.m
    // We should eventually merge that in order to not duplicate the code.
    // We should also eventually handle PidLidEmail3OriginalDisplayName in
    // SOGo, Thunderbird, etc.
    //
    case PidLidEmail2EmailAddress:
    case PidLidEmail2OriginalDisplayName: // Other email
      {
	NSMutableArray *emails;
	NSString *email;
	NGVCard *card;
	
	emails = [NSMutableArray array];
	stringValue = nil;
	
	card = [sogoObject vCard];
	[emails addObjectsFromArray: [card childrenWithTag: @"email"]];
	[emails removeObjectsInArray: [card childrenWithTag: @"email"
					    andAttribute: @"type"
					    havingValue: @"pref"]];

	if ([emails count] > 0)
	  {
	    int i;
	    
	    for (i = 0; i < [emails count]; i++)
	      {
		email = [[emails objectAtIndex: i] value: 0];
		
		if ([email caseInsensitiveCompare: [card preferredEMail]] != NSOrderedSame)
		  {
		    stringValue = email;
		    break;
		  }
	      }
	  }
	
	if (!stringValue)
	  stringValue = @"";

	*data = [stringValue asUnicodeInMemCtx: memCtx];
      }
      break;
      
    // FIXME: this property does NOT work
    case PR_BODY_UNICODE:
      stringValue = [[sogoObject vCard] note];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_OFFICE_TELEPHONE_NUMBER_UNICODE:
      element = [self _element: @"tel" ofType: @"work"
		     excluding: @"fax"
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_HOME_TELEPHONE_NUMBER_UNICODE:
      element = [self _element: @"tel" ofType: @"home"
		     excluding: @"fax"
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_MOBILE_TELEPHONE_NUMBER_UNICODE:
      element = [self _element: @"tel" ofType: @"cell"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_PRIMARY_TELEPHONE_NUMBER_UNICODE:
      element = [self _element: @"tel" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_BUSINESS_HOME_PAGE_UNICODE:
    case PR_PERSONAL_HOME_PAGE_UNICODE:
      {
	NSString *type;

	type = (proptag == PR_BUSINESS_HOME_PAGE_UNICODE ? @"work" : @"home");
	element = [self _element: @"url" ofType: type
			excluding: nil
			inCard: [sogoObject vCard]];
	if (element)
	  stringValue = [element value: 0];
	else
	  stringValue = @"";
	*data = [stringValue asUnicodeInMemCtx: memCtx];
      }
      break;
      
    case PidLidEmail1AddressType:
    case PidLidEmail2AddressType:
    case PidLidEmail3AddressType:
      *data = [@"SMTP" asUnicodeInMemCtx: memCtx];
      break;
      
    case PidLidInstantMessagingAddress:
      stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-aim"] value: 0];
      
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    //
    // We don't handle 0x00000003 - The Other Address is the mailing address.
    // See: http://msdn.microsoft.com/en-us/library/cc815430.aspx
    //
    case PidLidPostalAddressId:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if ([element hasAttribute: @"type"
		    havingValue: @"home"])
	longValue = 1; // The Home Address is the mailing address. 
      else if ([element hasAttribute: @"type"
			 havingValue: @"work"])
	longValue = 2; // The Work Address is the mailing address.
      else
	longValue = 0; // No address is selected as the mailing address.
      *data = MAPILongValue (memCtx, longValue);
      break;

      /* preferred address */
    case PR_POSTAL_ADDRESS_UNICODE:
      element = [self _element: @"label" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_POST_OFFICE_BOX_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_STREET_ADDRESS_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 2];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_LOCALITY_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 3];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_STATE_OR_PROVINCE_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 4];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_POSTAL_CODE_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 5];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_COUNTRY_UNICODE:
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 6];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    // case PidLidAddressCountryCode:

    case PidLidWorkAddress:
      element = [self _element: @"label" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidLidWorkAddressPostOfficeBox:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressStreet:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 2];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressCity:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 3];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressState:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 4];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressPostalCode:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 5];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressCountry:
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [sogoObject vCard]];
      if (element)
	stringValue = [element value: 6];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    // PidTagNickname
    case PR_NICKNAME_UNICODE:
      stringValue = [[sogoObject vCard] nickname];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
      
    case PR_BIRTHDAY:
      {
	NSCalendarDate *dateValue;

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
	  rc = MAPI_E_NOT_FOUND;
      }
      break;

    default:
      rc = [super getProperty: data withTag: proptag];
    }
        
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
