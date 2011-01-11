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
  NSString *stringValue;
  SOGoContactGCSEntry *child;
  CardElement *element;
  uint32_t longValue;
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
      child = [self lookupChild: childKey];
      /* that's buggy but it's for the demo */
      stringValue = [[[child vCard] org] componentsJoinedByString: @", "];
      if (!stringValue)
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_SUBJECT_UNICODE:
    case PR_DISPLAY_NAME_UNICODE: // Full Name
    case PidLidFileUnder: // contact block title name
      rc = [super getChildProperty: data
			    forKey: childKey
			   withTag: PR_DISPLAY_NAME_UNICODE];
      break;
    case PidLidEmail1OriginalDisplayName: // E-mail
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] preferredEMail];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_BODY_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [[child vCard] note];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_OFFICE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      element = [self _element: @"phone" ofType: @"work"
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
      element = [self _element: @"phone" ofType: @"home"
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
      element = [self _element: @"phone" ofType: @"cell"
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
      element = [self _element: @"phone" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if (element)
	stringValue = [element value: 0];
      else
	stringValue = @"";
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidLidEmail1AddressType:
    case PidLidEmail2AddressType:
    case PidLidEmail3AddressType:
      *data = [@"SMTP" asUnicodeInMemCtx: memCtx];
      break;

    case PidLidPostalAddressId:
      child = [self lookupChild: childKey];
      element = [self _element: @"adr" ofType: @"pref"
		     excluding: nil
			inCard: [child vCard]];
      if ([element hasAttribute: @"type"
		    havingValue: @"home"])
	longValue = 1;
      else if ([element hasAttribute: @"type"
			 havingValue: @"work"])
	longValue = 2;
      else
	longValue = 0;
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
