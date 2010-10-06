/* MAPIStoreContactsContext.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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


#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NSArray+NGCards.h>

#import <Contacts/SOGoContactGCSEntry.h>
#import <Contacts/SOGoContactGCSFolder.h>

#import "MAPIApplication.h"
#import "MAPIStoreAuthenticator.h"
#import "NSString+MAPIStore.h"
#import "SOGoGCSFolder+MAPIStore.h"

#import "MAPIStoreContactsContext.h"

#undef DEBUG
#include <mapistore/mapistore.h>

static Class SOGoUserFolderK;

@implementation MAPIStoreContactsContext

+ (void) initialize
{
  SOGoUserFolderK = [SOGoUserFolder class];
}

- (void) setupModuleFolder
{
  id userFolder;

  userFolder = [SOGoUserFolderK objectWithName: [authenticator username]
                                   inContainer: MAPIApp];
  [woContext setClientObject: userFolder];
  [userFolder retain]; // LEAK

  moduleFolder = [userFolder lookupName: @"Contacts"
                              inContext: woContext
                                acquire: NO];
  [moduleFolder retain];
}

- (NSArray *) getFolderMessageKeys: (SOGoFolder *) folder
{
  return [(SOGoGCSFolder *) folder componentKeysWithType: @"vcard"];
}

// - (int) getCommonTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (uint32_t) proptag
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

- (int) getMessageTableChildproperty: (void **) data
                               atURL: (NSString *) childURL
                             withTag: (uint32_t) proptag
                            inFolder: (SOGoFolder *) folder
                             withFID: (uint64_t) fid
{
  NSString *stringValue;
  id child;
  int rc;

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
      /* English US */
      *data = MAPILongValue (memCtx, 1033);
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

    case 0x3001001f: // Full Name
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

// - (int) getFolderTableChildproperty: (void **) data
//                               atURL: (NSString *) childURL
//                             withTag: (uint32_t) proptag
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

@end
