/* MAPIStoreContactsContext.m - this file is part of SOGo
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

#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>

#import <EOControl/EOQualifier.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NSArray+NGCards.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "MAPIStoreMapping.h"
#import "MAPIStoreTypes.h"
#import "NSString+MAPIStore.h"
#import "SOGoGCSFolder+MAPIStore.h"

#import "MAPIStoreContactsContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreContactsContext

+ (NSString *) MAPIModuleName
{
  return @"contacts";
}

+ (void) registerFixedMappings: (MAPIStoreMapping *) mapping
{
  [mapping registerURL: @"sogo://openchange:openchange@contacts/personal/"
                withID: 0x1a0001];
}

- (void) setupModuleFolder
{
  id userFolder;

  userFolder = [SOGoUserFolder objectWithName: [authenticator username]
                                  inContainer: MAPIApp];
  [parentFoldersBag addObject: userFolder];
  [woContext setClientObject: userFolder];

  moduleFolder = [userFolder lookupName: @"Contacts"
                              inContext: woContext
                                acquire: NO];
  [moduleFolder retain];
}


- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
		 matchingQualifier: (EOQualifier *) qualifier
{
  EOQualifier *componentQualifier, *contactsQualifier;

  /* TODO: we need to support vlist as well */
  componentQualifier
    = [[EOKeyValueQualifier alloc] initWithKey: @"c_component"
			      operatorSelector: EOQualifierOperatorEqual
					 value: @"vcard"];
  [componentQualifier autorelease];
  if (qualifier)
    {
      contactsQualifier = [[EOAndQualifier alloc]
			    initWithQualifiers:
			      componentQualifier,
			    qualifier,
			    nil];
      [contactsQualifier autorelease];
    }
  else
    contactsQualifier = componentQualifier;

  return [super getFolderMessageKeys: folder
		   matchingQualifier: contactsQualifier];
}

// - (enum MAPISTATUS) getCommonTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (enum MAPITAGS) proptag
//                            inFolder: (SOGoFolder *) folder
//                             withFID: (uint64_t) fid
// {
//         int rc;

//         rc = MAPI_E_SUCCESS;
//         switch (proptag) {
//         default:
//                 rc = [super getCommonTableChildproperty: data
//                                                   atURL: childURL
//                                                 withTag: proptag
//                                                inFolder: folder
//                                                 withFID: fid];
//         }

//         return rc;
// }

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

- (enum MAPISTATUS) getMessageTableChildproperty: (void **) data
					   atURL: (NSString *) childURL
					 withTag: (enum MAPITAGS) proptag
					inFolder: (SOGoFolder *) folder
					 withFID: (uint64_t) fid
{
  NSString *stringValue;
  id child;
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
    case PR_SUBJECT_UNICODE:
      *data = talloc_strdup (memCtx, "PR_SUBJECT...");
      break;
    case PR_OAB_NAME_UNICODE:
      *data = talloc_strdup (memCtx, "PR_OAB_NAME_UNICODE");
      break;
    case PR_OAB_LANGID:
      /* see http://msdn.microsoft.com/en-us/goglobal/bb895996.asxp */
      /* English US */
      *data = MAPILongValue (memCtx, 0x0409);
      break;

    case PR_TITLE_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [[child vCard] title];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_COMPANY_NAME_UNICODE:
      child = [self lookupObject: childURL];
      /* that's buggy but it's for the demo */
      stringValue = [[[child vCard] org] componentsJoinedByString: @", "];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_DISPLAY_NAME_UNICODE: // Full Name
    case 0x81c2001f: // contact block title name
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: PR_DISPLAY_NAME_UNICODE
                                      inFolder: folder
                                       withFID: fid];
      break;
    case 0x81b0001f: // E-mail
      child = [self lookupObject: childURL];
      stringValue = [[child vCard] preferredEMail];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_BODY_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [[child vCard] note];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

    case PR_OFFICE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [self _phoneOfType: @"work"
                             excluding: @"fax"
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_HOME_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [self _phoneOfType: @"home"
                             excluding: @"fax"
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_MOBILE_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [self _phoneOfType: @"cell"
                             excluding: nil
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;
    case PR_PRIMARY_TELEPHONE_NUMBER_UNICODE:
      child = [self lookupObject: childURL];
      stringValue = [self _phoneOfType: @"pref"
                             excluding: nil
                                inCard: [child vCard]];
      *data = [stringValue asUnicodeInMemCtx: memCtx];
      break;

      // case PR_POSTAL_ADDRESS_UNICODE:
      // case PR_INTERNET_MESSAGE_ID_UNICODE:
      // case PR_CAR_TELEPHONE_NUMBER_UNICODE:
      // case PR_OTHER_TELEPHONE_NUMBER_UNICODE:
      // case PR_BUSINESS_FAX_NUMBER_UNICODE:
      // case PR_HOME_FAX_NUMBER_UNICODE:
      // case PR_COMPANY_MAIN_PHONE_NUMBER_UNICODE:
      // case PR_EMS_AB_GROUP_BY_ATTR_4_UNICODE:
      // case PR_CALLBACK_TELEPHONE_NUMBER_UNICODE:
      // case PR_DEPARTMENT_NAME_UNICODE:
      // case PR_OFFICE2_TELEPHONE_NUMBER_UNICODE:
      // case PR_RADIO_TELEPHONE_NUMBER_UNICODE:
      // case PR_PAGER_TELEPHONE_NUMBER_UNICODE:
      // case PR_PRIMARY_FAX_NUMBER_UNICODE:
      // case PR_TELEX_NUMBER_UNICODE:
      // case PR_ISDN_NUMBER_UNICODE:
      // case PR_ASSISTANT_TELEPHONE_NUMBER_UNICODE:
      // case PR_HOME2_TELEPHONE_NUMBER_UNICODE:
      // case PR_TTYTDD_PHONE_NUMBER_UNICODE:
      // case PR_BUSINESS_HOME_PAGE_UNICODE:
      //         *data = talloc_strdup (memCtx, "[Generic and fake unicode value]");
      //         break;

      // (18:54:45) Wolfgang-: 0x80a7001f (  Business: ) -> don't ask me which "business"
      // (18:55:05) Wolfgang-: 0x809c001f   (  Other: )
      // (18:55:58) Wolfgang-: 0x81b5001f: E-mail  2


      // #define PR_REPLY_TIME                                       PROP_TAG(PT_SYSTIME   , 0x0030) /* 0x00300040 */
      // #define PR_SENSITIVITY                                      PROP_TAG(PT_LONG      , 0x0036) /* 0x00360003 */
      // #define PR_FOLLOWUP_ICON                                    PROP_TAG(PT_LONG      , 0x1095) /* 0x10950003 */
      // #define PR_SEARCH_KEY                                       PROP_TAG(PT_BINARY    , 0x300b) /* 0x300b0102 */
      // #define PR_VIEW_STYLE                                       PROP_TAG(PT_LONG      , 0x6834) /* 0x68340003 */
      // #define PR_VD_VERSION                                       PROP_TAG(PT_LONG      , 0x7007) /* 0x70070003 */

    default:
      rc = [super getMessageTableChildproperty: data
                                         atURL: childURL
                                       withTag: proptag
                                      inFolder: folder
                                       withFID: fid];
    }
        
  return rc;
}

- (id) createMessageInFolder: (id) parentFolder
{
  SOGoContactGCSEntry *newEntry;
  NSString *name;

  name = [NSString stringWithFormat: @"%@.vcf",
                   [SOGoObject globallyUniqueObjectId]];
  newEntry = [SOGoContactGCSEntry objectWithName: name
                                     inContainer: parentFolder];
  [newEntry setIsNew: YES];

  return newEntry;
}

// - (enum MAPISTATUS) getFolderTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (enum MAPITAGS) proptag
//                            inFolder: (SOGoFolder *) folder
//                             withFID: (uint64_t) fid
// {
//   int rc;

//   [self logWithFormat: @"XXXXX unexpected!!!!!!!!!"];
//   rc = MAPI_E_SUCCESS;
//   switch (proptag)
//     {
//     default:
//       rc = [super getFolderTableChildproperty: data
//                                         atURL: childURL
//                                       withTag: proptag
//                                      inFolder: folder
//                                       withFID: fid];
//     }
        
//   return rc;
// }

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (0x81ae001f)];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (0x81b3001f)];
      [knownProperties setObject: @"c_mail"
			  forKey: MAPIPropertyKey (PR_EMS_AB_GROUP_BY_ATTR_2_UNICODE)];
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
    case PR_EMS_AB_RAS_ACCOUNT_UNICODE:
    case 0x81b2001f:
    case PR_EMS_AB_GROUP_BY_ATTR_1_UNICODE:
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
