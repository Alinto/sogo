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

- (NSString *) _phoneOfType: (NSString *) aType
                  excluding: (NSString *) aTypeToExclude
                     inCard: (NGVCard *) card
{
  NSArray *elements;
  NSArray *phones;
  NSString *phone;

  phones = [card childrenWithTag: @"tel"];

  elements = [phones cardElementsWithAttribute: @"type"
                                   havingValue: aType];

  phone = nil;

  if ([elements count] > 0)
    {
      CardElement *ce;
      int i;

      for (i = 0; i < [elements count]; i++)
	{
	  ce = [elements objectAtIndex: i];
	  phone = [ce value: 0];

	  if (!aTypeToExclude)
	    break;
	  
	  if (![ce hasAttribute: @"type" havingValue: aTypeToExclude])
	    break;

	  phone = nil;
	}
    }

  if (!phone)
    phone = @"";

  return phone;
}

- (enum MAPISTATUS) getChildProperty: (void **) data
			      forKey: (NSString *) childKey
			     withTag: (enum MAPITAGS) proptag
{
  NSString *stringValue;
  SOGoContactGCSEntry *child;
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
      stringValue = [self _phoneOfType: @"work"
                             excluding: @"fax"
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_HOME_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [self _phoneOfType: @"home"
                             excluding: @"fax"
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_MOBILE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [self _phoneOfType: @"cell"
                             excluding: nil
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_PRIMARY_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupChild: childKey];
      stringValue = [self _phoneOfType: @"pref"
                             excluding: nil
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PidLidEmail1AddressType:
    case PidLidEmail2AddressType:
    case PidLidEmail3AddressType:
      *data = [@"SMTP" asUnicodeInMemCtx: memCtx];
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
