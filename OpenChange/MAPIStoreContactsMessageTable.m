/* MAPIStoreContactsMessageTable.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>

#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactGCSEntry.h>

#import "MAPIStoreTypes.h"
#import "NSCalendarDate+MAPIStore.h"
#import "NSArray+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsMessageTable.h"

#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreContactsMessageTable

- (EOQualifier *) componentQualifier
{
  static EOQualifier *componentQualifier = nil;

  /* TODO: we need to support vlist as well */
  if (!componentQualifier)
    componentQualifier
      = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
				operatorSelector: EOQualifierOperatorEqual
					   value: @"vcard"];

  return componentQualifier;
}

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

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) proptag
{
  NSString *stringValue, *stringValue2;
  SOGoContactGCSEntry *child;
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
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] title];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_COMPANY_NAME_UNICODE:
    case PR_DEPARTMENT_NAME_UNICODE:
      {
	NSArray *values;
	
	child = [self lookupChild: childKey];
	values = [[child vCard] org];
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
      rc = [super getChildProperty: data
        		    forKey: childKey
        		   withTag: PR_DISPLAY_NAME_UNICODE];
      break;
    case PidLidFileUnderId: 
      *data = MAPILongValue (memCtx, 0xffffffff);
      break;

    case PidLidEmail1OriginalDisplayName:
    case PidLidEmail1DisplayName:
      child = [self lookupChild: childKey];
      vCard = [child vCard];
      stringValue = [vCard fn];
      stringValue2 = [vCard preferredEMail];
      *data = [[NSString stringWithFormat: @"%@ <%@>",
                         stringValue, stringValue2]
                asUnicodeInMemCtx: memCtx];
      break;

    case PidLidEmail1EmailAddress:
    case PR_ACCOUNT_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] preferredEMail];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_CONTACT_EMAIL_ADDRESSES_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] preferredEMail];
      *data = [[NSArray arrayWithObject: stringValue]
                asArrayOfUnicodeStringsInCtx: memCtx];
      break;

    case PR_EMS_AB_TARGET_ADDRESS_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] preferredEMail];
      *data = [[NSString stringWithFormat: @"SMTP:%@", stringValue]
                asUnicodeInMemCtx: memCtx];
      break;

    case PR_SEARCH_KEY: // TODO
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] preferredEMail];
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
	
	card = [[self lookupChild: childKey] vCard];
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
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] note];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_OFFICE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"tel" ofType: @"work"
		     excluding: @"fax"
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_HOME_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"tel" ofType: @"home"
		     excluding: @"fax"
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_MOBILE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"tel" ofType: @"cell"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_PRIMARY_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"tel" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
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

	child = [self lookupChild: childKey];
	
	element = [self _element: @"url" ofType: type
			excluding: nil
			inCard: [child vCard]];
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
      child = [self lookupChild: childKey];
      stringValue = [[[child vCard] uniqueChildWithTag: @"x-aim"] value: 0];
      
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    //
    // We don't handle 0x00000003 - The Other Address is the mailing address.
    // See: http://msdn.microsoft.com/en-us/library/cc815430.aspx
    //
    case PidLidPostalAddressId:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
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
      child = [self lookupChild: childKey];
      element = [self _element: @"label" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_POST_OFFICE_BOX_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_STREET_ADDRESS_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 2];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_LOCALITY_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 3];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_STATE_OR_PROVINCE_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 4];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_POSTAL_CODE_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 5];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_COUNTRY_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 6];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    // case PidLidAddressCountryCode:

    case PidLidWorkAddress:
      child = [self lookupChild: childKey];
      element = [self _element: @"label" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidLidWorkAddressPostOfficeBox:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressStreet:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 2];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressCity:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 3];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressState:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 4];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressPostalCode:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 5];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PidLidWorkAddressCountry:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"work"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 6];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    // PidTagNickname
    case PR_NICKNAME_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] nickname];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
      
    case PR_BIRTHDAY:
      {
	NSCalendarDate *dateValue;

	child = [self lookupChild: childKey];

	stringValue = [[child vCard] bday];
	
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
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: proptag];
    }
        
  return rc;
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (PidLidEmail1EmailAddress)];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (PidLidEmail2EmailAddress)];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (PidLidEmail3EmailAddress)];
      [knownProperties setObject: @"c_cn"
			  forKey: MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Contact"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PidLidEmail1AddressType:
    case PidLidEmail2AddressType:
    case PidLidEmail3AddressType:
      if ([value isEqualToString: @"SMTP"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
      
    default:
      rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

@end
