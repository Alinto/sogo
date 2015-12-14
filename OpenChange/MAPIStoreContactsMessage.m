/* MAPIStoreContactsMessage.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Ludovic Marcotte <lmarcotte@inverse.ca>
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardPhoto.h>
#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NSString+NGCards.h>
#import <Contacts/SOGoContactGCSEntry.h>
#import <Mailer/NSString+Mail.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/SOGoUserManager.h>

#import "MAPIStoreAttachment.h"
#import "MAPIStoreContactsAttachment.h"
#import "MAPIStoreContactsFolder.h"
#import "MAPIStoreContext.h"
#import "MAPIStorePropertySelectors.h"
#import "MAPIStoreSamDBUtils.h"
#import "MAPIStoreTypes.h"
#import "NSArray+MAPIStore.h"
#import "NSDate+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSObject+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsMessage.h"

#undef DEBUG
#include <stdbool.h>
#include <gen_ndr/exchange.h>
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>
#include <mapistore/mapistore_nameid.h>

@implementation SOGoContactGCSEntry (MAPIStoreExtension)

- (Class) mapistoreMessageClass
{
  return [MAPIStoreContactsMessage class];
}

@end

@implementation MAPIStoreContactsMessage

- (id) init
{
  if ((self = [super init]))
    {
      fetchedAttachments = NO;
    }

  return self;
}

// TODO: this should be combined with the version found
//       in UIxContactEditor.m
- (CardElement *) _elementWithTag: (NSString *) tag
                           ofType: (NSString *) type
                          forCard: (NGVCard *) card
{
  NSArray *elements;
  CardElement *element;

  elements = [card childrenWithTag: tag
                      andAttribute: @"type" havingValue: type];
  if ([elements count] > 0)
    element = [elements objectAtIndex: 0];
  else
    {
      element = [CardElement new];
      [element autorelease];
      [element setTag: tag];
      [element addType: type];
      [card addChild: element];
    }

  return element;
}

- (int) getPidTagIconIndex: (void **) data // TODO
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  /* see http://msdn.microsoft.com/en-us/library/cc815472.aspx */
  *data = MAPILongValue (memCtx, 0x00000200);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAlternateRecipientAllowed: (void **) data
                                  inMemCtx: (TALLOC_CTX *) memCtx

{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagMessageFlags: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, MSGFLAG_READ);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDeleteAfterSubmit: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx

{
  return [self getNo: data inMemCtx: memCtx];
}

- (int) getPidTagMessageClass: (void **) data
                     inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = talloc_strdup (memCtx, "IPM.Contact");

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagSendInternetEncoding: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00065001);

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagNormalizedSubject: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidTagDisplayName: data inMemCtx: memCtx];
}

- (int) getPidLidFileUnder: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *surName, *givenName, *middleName;
  NSMutableString *fileUnder;
  CardElement *n;

  n = [[sogoObject vCard] n];
  surName = [n flattenedValueAtIndex: 0
                              forKey: @""];
  fileUnder = [surName mutableCopy];
  [fileUnder autorelease];
  [fileUnder appendString: @","];
  givenName = [n flattenedValueAtIndex: 1
                              forKey: @""];
  if ([givenName length] > 0)
    [fileUnder appendFormat: @" %@", givenName];
  middleName = [n flattenedValueAtIndex: 2
                                 forKey: @""];
  if ([middleName length] > 0)
    [fileUnder appendFormat: @" %@", middleName];

  *data = [fileUnder asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidFileUnderId: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  *data = MAPILongValue (memCtx, 0x00008017); /* what ol2003 sets */

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagAccount: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail1EmailAddress: data inMemCtx: memCtx];
}

- (int) getPidTagContactEmailAddresses: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  if (!stringValue)
    stringValue = @"";
  *data = [[NSArray arrayWithObject: stringValue]
            asMVUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagEmsAbTargetAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[NSString stringWithFormat: @"SMTP:%@", stringValue]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagSearchKey: (void **) data // TODO
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] preferredEMail];
  *data = [[stringValue dataUsingEncoding: NSASCIIStringEncoding]
            asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMailPermission: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getYes: data inMemCtx: memCtx];
}

- (int) getPidTagBody: (void **) data
             inMemCtx: (TALLOC_CTX *) memCtx
{
  int rc = MAPISTORE_SUCCESS;
  NSString *stringValue;

  stringValue = [[sogoObject vCard] note];
  if ([stringValue length] > 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagSensitivity: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getLongZero: data inMemCtx: memCtx];
}

// ---------------------------------------------------------
// Contact Name Properties [MS-OXOCNTC 2.2.1.1]
// ---------------------------------------------------------

- (int) getPidTagNickname: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] nickname];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagGeneration: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] firstChildWithTag: @"n"]
                  flattenedValueAtIndex: 4
                                 forKey: @""];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagSurname: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] firstChildWithTag: @"n"]
                  flattenedValueAtIndex: 0
                                 forKey: @""];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagMiddleName: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] firstChildWithTag: @"n"]
                  flattenedValueAtIndex: 2
                                 forKey: @""];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagGivenName: (void **) data
                  inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] firstChildWithTag: @"n"]
                  flattenedValueAtIndex: 1
                                 forKey: @""];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDisplayNamePrefix: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] firstChildWithTag: @"n"]
                  flattenedValueAtIndex: 3
                                 forKey: @""];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

// -------------------------------------------------------
// Electronic Address Properties [MS-OXOCNTC 2.2.1.2]
// -------------------------------------------------------

enum {  // [MS-OXOCNTC] 2.2.1.2.11
    AddressBookProviderEmailValueEmail1 = 0,
    AddressBookProviderEmailValueEmail2,
    AddressBookProviderEmailValueEmail3,
    AddressBookProviderEmailValueBusinessFax,
    AddressBookProviderEmailValueHomeFax,
    AddressBookProviderEmailValuePrimaryFax
};

/*
  Fetch Email1, Email2 and Email3 values from the vcard.
  Returns nil if not found
*/
- (NSString *) _fetchEmailAddress: (NSUInteger) position
{
  NSMutableArray *emails;
  NSString *email, *stringValue = nil;
  NGVCard *card;
  NSUInteger count, max;

  card = [sogoObject vCard];

  if (position == 1)
    // Predefined email
    return [card preferredEMail];

  emails = [NSMutableArray array];
  [emails addObjectsFromArray: [card childrenWithTag: @"email"]];
  [emails removeObjectsInArray: [card childrenWithTag: @"email"
                                         andAttribute: @"type"
                                          havingValue: @"pref"]];
  max = [emails count];
  for (count = 0; !stringValue && count < max; count++)
    {
      email = [[emails objectAtIndex: count] flattenedValuesForKey: @""];

      if ([email caseInsensitiveCompare: [card preferredEMail]] != NSOrderedSame)
        {
          position--;
          if (position == 1)
            stringValue = email;
        }
    }

  return stringValue;
}

/*
  Store on *data the given email (position)
  It can return MAPISTORE_ERR_NOT_FOUND if the email doesn't exist
*/
- (int) _getPidLidEmailAddress: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
                    atPosition: (NSUInteger) position
{
  NSString *email;

  email = [self _fetchEmailAddress: position];
  if (!email) return MAPISTORE_ERR_NOT_FOUND;

  *data = [email asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1EmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailAddress: data inMemCtx: memCtx atPosition: 1];
}

- (int) getPidLidEmail2EmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailAddress: data inMemCtx: memCtx atPosition: 2];
}

- (int) getPidLidEmail3EmailAddress: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailAddress: data inMemCtx: memCtx atPosition: 3];
}

- (int) getPidLidEmail1OriginalDisplayName: (void **) data
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail1EmailAddress: data inMemCtx: memCtx];
}

- (int) getPidLidEmail2OriginalDisplayName: (void **) data
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail2EmailAddress: data inMemCtx: memCtx];
}

- (int) getPidLidEmail3OriginalDisplayName: (void **) data
                                  inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self getPidLidEmail3EmailAddress: data inMemCtx: memCtx];
}

- (int) getPidLidEmail1AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  if (![self _fetchEmailAddress: 1]) return MAPISTORE_ERR_NOT_FOUND;

  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidLidEmail2AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  if (![self _fetchEmailAddress: 2]) return MAPISTORE_ERR_NOT_FOUND;

  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

- (int) getPidLidEmail3AddressType: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  if (![self _fetchEmailAddress: 3]) return MAPISTORE_ERR_NOT_FOUND;

  return [self getSMTPAddrType: data inMemCtx: memCtx];
}

/*
  Store on *data a string with the display name for the given email (position)
  It can return MAPISTORE_ERR_NOT_FOUND if the email doesn't exist
*/
- (int) _getPidLidEmailDisplayName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
                        atPosition: (NSUInteger) position
{
  NGVCard *vCard;
  NSString *fn, *email;

  email = [self _fetchEmailAddress: position];
  if (!email) return MAPISTORE_ERR_NOT_FOUND;

  vCard = [sogoObject vCard];
  fn = [vCard fn];

  *data = [[NSString stringWithFormat: @"%@ (%@)", fn, email]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1DisplayName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailDisplayName: data inMemCtx: memCtx atPosition: 1];
}

- (int) getPidLidEmail2DisplayName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailDisplayName: data inMemCtx: memCtx atPosition: 2];
}

- (int) getPidLidEmail3DisplayName: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailDisplayName: data inMemCtx: memCtx atPosition: 3];
}

/*
  Return an entry id (either one-off or addressbook entry) for the given email
  It can return nil if the email doesn't exist
*/
- (NSData *) _buildEntryIdForEmail: (NSUInteger) position
{
  NSString *email, *username;
  NSData *data;
  SOGoUserManager *mgr;
  NSDictionary *contactInfos;

  email = [self _fetchEmailAddress: position];
  if (!email) return nil;

  // Try to figure out if this email is from local domain
  mgr = [SOGoUserManager sharedUserManager];
  contactInfos = [mgr contactInfosForUserWithUIDorEmail: email];
  if (contactInfos)
    {
      username = [contactInfos objectForKey: @"sAMAccountName"];
      data = MAPIStoreInternalEntryId ([[self context] connectionInfo], username);
    }
  else
    data = MAPIStoreExternalEntryId ([[sogoObject vCard] fn], email);

  return data;
}
/*
  Store on *data an entryId for the given email (position)
  It can return MAPISTORE_ERR_NOT_FOUND if the email doesn't exist
*/
- (int) _getPidLidEmailOriginalEntryId: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
                            atPosition: (NSUInteger) position
{
  NSData *value;

  value = [self _buildEntryIdForEmail: position];
  if (!value) return MAPISTORE_ERR_NOT_FOUND;

  *data = [value asBinaryInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidEmail1OriginalEntryId: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailOriginalEntryId: data
                                     inMemCtx: memCtx
                                   atPosition: 1];
}

- (int) getPidLidEmail2OriginalEntryId: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailOriginalEntryId: data
                                     inMemCtx: memCtx
                                   atPosition: 2];
}

- (int) getPidLidEmail3OriginalEntryId: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getPidLidEmailOriginalEntryId: data
                                     inMemCtx: memCtx
                                   atPosition: 3];
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
        stringValue = [ce flattenedValueAtIndex: pos forKey: @""];
    }

  if (!stringValue)
    stringValue = @"";

  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagBusinessFaxNumber: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"fax" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

/*
  [MS-OXOCNTC] 2.2.1.2.11
  https://msdn.microsoft.com/en-us/library/ee158427%28v=exchg.80%29.aspx
*/
- (NSArray *) _buildAddressBookProviderEmailList
{
  NSMutableArray *list = [[NSMutableArray alloc] init];
  NSArray *elements;

  // Is there a fax number?
  elements = [[[sogoObject vCard] childrenWithTag: @"tel"]
               cardElementsWithAttribute: @"type"
                             havingValue: @"fax"];
  if ([elements count] > 0)
    [list addObject: [NSNumber numberWithInteger: AddressBookProviderEmailValueBusinessFax]];

  // How many different email addresses?
  if ([self _fetchEmailAddress: 1])
    [list addObject: [NSNumber numberWithInteger: AddressBookProviderEmailValueEmail1]];
  else
    return list;
  if ([self _fetchEmailAddress: 2])
    [list addObject: [NSNumber numberWithInteger: AddressBookProviderEmailValueEmail2]];
  else
    return list;
  if ([self _fetchEmailAddress: 3])
    [list addObject: [NSNumber numberWithInteger: AddressBookProviderEmailValueEmail3]];

  return list;
}

- (int) getPidLidAddressBookProviderArrayType: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  // [MS-OXOCNTC] 2.2.1.2.12
  // https://msdn.microsoft.com/en-us/library/ee218011%28v=exchg.80%29.aspx
  uint32_t value = 0;
  NSArray *emailList = [self _buildAddressBookProviderEmailList];

  for (NSNumber *maskValue in emailList)
    value |= 1 << [maskValue intValue];

  *data = MAPILongValue (memCtx, value);

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidAddressBookProviderEmailList: (void **) data
                                     inMemCtx: (TALLOC_CTX *) memCtx
{
  NSArray *emailList = [self _buildAddressBookProviderEmailList];

  *data = [emailList asMVLongInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

// ---------------------------------------------------------
// Physical Address Properties [MS-OXOCNTC 2.2.1.3]
// ---------------------------------------------------------

// Home Address

- (int) getPidTagHomeAddressStreet: (void **) data
                          inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 2 inData: data inMemCtx: memCtx];
}

- (int) getPidTagHomeAddressCity: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 3 inData: data inMemCtx: memCtx];
}

- (int) getPidTagHomeAddressStateOrProvince: (void **) data
                                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 4 inData: data inMemCtx: memCtx];
}

- (int) getPidTagHomeAddressPostalCode: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 5 inData: data inMemCtx: memCtx];
}
- (int) getPidTagHomeAddressCountry: (void **) data
                           inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 6 inData: data inMemCtx: memCtx];
}

- (int) getPidTagHomeAddressPostOfficeBox: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"home" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidLidHomeAddress: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"label" ofType: @"home" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

// Work Address

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

- (int) getPidLidWorkAddressPostOfficeBox: (void **) data
                                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidLidWorkAddress: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"label" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

// Mailing Address

- (int) getPidTagStreetAddress: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 2 inData: data inMemCtx: memCtx];
}

- (int) getPidTagLocality: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 3 inData: data inMemCtx: memCtx];
}

- (int) getPidTagStateOrProvince: (void **) data
                        inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 4 inData: data inMemCtx: memCtx];
}

- (int) getPidTagPostalCode: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 5 inData: data inMemCtx: memCtx];
}

- (int) getPidTagCountry: (void **) data
                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 6 inData: data inMemCtx: memCtx];
}

- (int) getPidTagPostOfficeBox: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"adr" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagPostalAddress: (void **) data
                      inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"label" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
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

// -------------------------------------------------------
// Telephone Properties [MS-OXOCNTC 2.2.1.4]
// -------------------------------------------------------

- (int) getPidTagPagerTelephoneNumber: (void **) data
                             inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"pager" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagBusinessTelephoneNumber: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"work" excluding: @"fax"
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagHomeTelephoneNumber: (void **) data
                            inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"home" excluding: @"fax"
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagPrimaryTelephoneNumber: (void **) data
                               inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"pref" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagMobileTelephoneNumber: (void **) data
                              inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"tel" ofType: @"cell" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

// ---------------------------------------------------------
// Event Properties [MS-OXOCNTC 2.2.1.5]
// ---------------------------------------------------------

- (int) getPidTagBirthday: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[sogoObject vCard] bday];
  if ([stringValue length] != 0)
    {
      dateValue = [NSCalendarDate dateWithString: stringValue
                                  calendarFormat: @"%Y-%m-%d"];
      //dateValue = [dateValue addYear: 0 month: 0 day: 1 hour: 0 minute: 0 second: 0];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagWeddingAnniversary: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSCalendarDate *dateValue;
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-ms-anniversary"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    {
      dateValue = [NSCalendarDate dateWithString: stringValue
                                  calendarFormat: @"%Y-%m-%d"];
      *data = [dateValue asFileTimeInMemCtx: memCtx];
    }
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

// ---------------------------------------------------------
// Professional Properties [MS-OXOCNTC 2.2.1.6]
// ---------------------------------------------------------

- (int) getPidTagTitle: (void **) data
              inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[sogoObject vCard] title];
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagCompanyName: (void **) data
                    inMemCtx: (TALLOC_CTX *) memCtx
{
  CardElement *org;

  org = [[sogoObject vCard] org];
  *data = [[org flattenedValueAtIndex: 0 forKey: @""]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagDepartmentName: (void **) data
                       inMemCtx: (TALLOC_CTX *) memCtx
{
  CardElement *org;

  org = [[sogoObject vCard] org];
  *data = [[org flattenedValueAtIndex: 1 forKey: @""]
            asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidTagOfficeLocation: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-ms-office"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagManagerName: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-ms-manager"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagAssistant: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-ms-assistant"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagProfession: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[sogoObject vCard] role];
  if (stringValue)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

// ---------------------------------------------------------
// Contact Photo Properties [MS-OXOCNTC 2.2.1.8]
// ---------------------------------------------------------

- (void) _fetchAttachmentParts
{
  NGVCardPhoto *photo;
  MAPIStoreContactsAttachment *attachment;
  NSString *encoding;

  photo = (NGVCardPhoto *) [[sogoObject vCard] firstChildWithTag: @"photo"];
  if (photo)
    {
      encoding = [[photo value: 0 ofAttribute: @"encoding"] uppercaseString];
      if ([encoding isEqualToString: @"B"]
          || [encoding isEqualToString: @"BASE64"])
        {
          attachment = [MAPIStoreContactsAttachment
                         mapiStoreObjectInContainer: self];
          [attachment setAID: 0];
          [attachment setPhoto: photo];
          [attachmentParts setObject: attachment forKey: @"photo"];
        }
    }

  fetchedAttachments = YES;
}

- (int) getPidLidHasPicture: (void **) data
                   inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!fetchedAttachments)
    [self _fetchAttachmentParts];

  *data = MAPIBoolValue (memCtx, ([attachmentParts count] > 0));

  return MAPISTORE_SUCCESS;
}

- (NSArray *) attachmentKeysMatchingQualifier: (EOQualifier *) qualifier
                             andSortOrderings: (NSArray *) sortOrderings
{
  if (!fetchedAttachments)
    [self _fetchAttachmentParts];

  return [super attachmentKeysMatchingQualifier: qualifier
                               andSortOrderings: sortOrderings];
}

- (id) lookupAttachment: (NSString *) childKey
{
  if (!fetchedAttachments)
    [self _fetchAttachmentParts];

  return [attachmentParts objectForKey: childKey];
}

- (void) _updatePhotoInVCard: (NGVCard *) card
              fromProperties: (NSDictionary *) attachmentProps
{
  NSString *photoExt, *photoType, *content;
  CardElement *photo;

  if ([[attachmentProps
             objectForKey: MAPIPropertyKey (PR_ATTACHMENT_CONTACTPHOTO)]
        boolValue])
    {
      photoExt = [[attachmentProps
                        objectForKey: MAPIPropertyKey (PR_ATTACH_EXTENSION_UNICODE)]
                   uppercaseString];
      if ([photoExt isEqualToString: @".JPG"])
        photoType = @"JPEG";
      else if ([photoExt isEqualToString: @".PNG"])
        photoType = @"PNG";
      else if ([photoExt isEqualToString: @".BMP"])
        photoType = @"BMP";
      else if ([photoExt isEqualToString: @".GIF"])
        photoType = @"GIF";
      else
        photoType = nil;

      content = [[attachmentProps
                    objectForKey: MAPIPropertyKey (PR_ATTACH_DATA_BIN)]
                  stringByEncodingBase64];
      if (photoType && content)
        {
          photo = [card uniqueChildWithTag: @"photo"];
          [photo setValue: 0 ofAttribute: @"type"
                       to: photoType];
          [photo setValue: 0 ofAttribute: @"encoding"
                       to: @"b"];
          [photo setSingleValue: [content stringByReplacingString: @"\n"
                                                       withString: @""]
                        atIndex: 0 forKey: @""];
        }
    }
}

// ---------------------------------------------------------
// Other Properties [MS-OXOCNTC 2.2.1.10]
// ---------------------------------------------------------

- (int) getPidTagSpouseName: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-ms-spouse"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidLidInstantMessagingAddress: (void **) data
                                inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"x-aim"]
                  flattenedValuesForKey: @""];
  if (!stringValue)
    stringValue = @"";
  *data = [stringValue asUnicodeInMemCtx: memCtx];

  return MAPISTORE_SUCCESS;
}

- (int) getPidLidFreeBusyLocation: (void **) data
                 inMemCtx: (TALLOC_CTX *) memCtx
{
  NSString *stringValue;
  int rc = MAPISTORE_SUCCESS;

  stringValue = [[[sogoObject vCard] uniqueChildWithTag: @"fburl"]
                  flattenedValuesForKey: @""];
  if ([stringValue length] != 0)
    *data = [stringValue asUnicodeInMemCtx: memCtx];
  else
    rc = MAPISTORE_ERR_NOT_FOUND;

  return rc;
}

- (int) getPidTagPersonalHomePage: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"url" ofType: @"home" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

- (int) getPidTagBusinessHomePage: (void **) data
                         inMemCtx: (TALLOC_CTX *) memCtx
{
  return [self _getElement: @"url" ofType: @"work" excluding: nil
                     atPos: 0 inData: data inMemCtx: memCtx];
}

// ---------------------------------------------------------

- (BOOL) subscriberCanReadMessage
{
  return [[self activeUserRoles] containsObject: SOGoRole_ObjectViewer];
}

- (BOOL) subscriberCanModifyMessage
{
  NSArray *roles;

  roles = [self activeUserRoles];

  return ((isNew
           && [roles containsObject: SOGoRole_ObjectCreator])
          || (!isNew && [roles containsObject: SOGoRole_ObjectEditor]));
}

- (void) saveDistList:(TALLOC_CTX *) memCtx
{
  [self warnWithFormat: @"IPM.DistList messages are ignored"];
}

- (void) saveContact:(TALLOC_CTX *) memCtx
{
  NSArray *elements, *units;
  CardElement *element;
  NGVCard *newCard;
  MAPIStoreAttachment *attachment;
  int postalAddressId;
  id value;

  [self logWithFormat: @"setMAPIProperties: %@", properties];

  newCard = [sogoObject vCard];
  [newCard setTag: @"vcard"];
  [newCard setVersion: @"3.0"];
  [newCard setProdID: @"-//Inverse inc.//OpenChange+SOGo//EN"];
  [newCard setProfile: @"vCard"];

  // Decomposed fullname
  [newCard setNWithFamily: [properties objectForKey: MAPIPropertyKey(PR_SURNAME_UNICODE)]
                    given: [properties objectForKey: MAPIPropertyKey(PR_GIVEN_NAME_UNICODE)]
               additional: [properties objectForKey: MAPIPropertyKey(PR_MIDDLE_NAME_UNICODE)]
                 prefixes: [properties objectForKey: MAPIPropertyKey(PR_DISPLAY_NAME_PREFIX_UNICODE)]
                 suffixes: [properties objectForKey: MAPIPropertyKey(PR_GENERATION_UNICODE)]];

  //
  // display name
  //
  value = [properties objectForKey: MAPIPropertyKey(PR_DISPLAY_NAME_UNICODE)];
  if (value)
    [newCard setFn: value];

  //
  // email addresses handling
  //
  elements = [newCard childrenWithTag: @"email"];
  value = [properties objectForKey: MAPIPropertyKey(PidLidEmail1EmailAddress)];
  if (value)
    {
      if ([elements count] > 0)
        [[elements objectAtIndex: 0] setSingleValue: value forKey: @""];
      else
        [newCard addEmail: value
                    types: [NSArray arrayWithObject: @"pref"]];
    }
  value = [properties objectForKey: MAPIPropertyKey (PidLidEmail2EmailAddress)];
  if (value)
    {
      if ([elements count] > 1)
        [[elements objectAtIndex: 1] setSingleValue: value forKey: @""];
      else
        [newCard addEmail: value types: nil];
    }
  value = [properties objectForKey: MAPIPropertyKey (PidLidEmail3EmailAddress)];
  if (value)
    {
      if ([elements count] > 2)
        [[elements objectAtIndex: 2] setSingleValue: value forKey: @""];
      else
        [newCard addEmail: value types: nil];
    }

  //
  // work postal addresses handling
  //
  // Possible values for PidLidPostalAddressId are:
  //
  // 0x00000000 - No address is selected as the Mailing Address.
  // 0x00000001 - The Home Address is the Mailing Address.
  // 0x00000002 - The Work Address is the Mailing Address
  // 0x00000003 - The Other Address is the Mailing Address.
  //
  //
  postalAddressId = [[properties objectForKey: MAPIPropertyKey (PidLidPostalAddressId)]
                      intValue];

  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddress)];
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
      [element setSingleValue: value forKey: @""];
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
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressPostOfficeBox)];
  if (value)
    [element setSingleValue: value atIndex: 0 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressStreet)];
  if (value)
    [element setSingleValue: value atIndex: 2 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressCity)];
  if (value)
    [element setSingleValue: value atIndex: 3 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressState)];
  if (value)
    [element setSingleValue: value atIndex: 4 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressPostalCode)];
  if (value)
    [element setSingleValue: value atIndex: 5 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PidLidWorkAddressCountry)];
  if (value)
    [element setSingleValue: value atIndex: 6 forKey: @""];

  //
  // home postal addresses handling
  //
  value = [properties objectForKey: MAPIPropertyKey(PidLidHomeAddress)];
  if ([value length])
    {
      elements = [newCard childrenWithTag: @"label"
                             andAttribute: @"type"
                              havingValue: @"home"];
      if ([elements count] > 0)
        element = [elements objectAtIndex: 0];
      else
        {
          element = [CardElement elementWithTag: @"label"];
          [element addAttribute: @"type" value: @"home"];
          [newCard addChild: element];
        }
      if (postalAddressId == 1)
        {
          [element removeValue: @"pref"
                 fromAttribute: @"type"];
          [element addAttribute: @"type"
                          value: @"pref"];
        }
      [element setSingleValue: value forKey: @""];
    }

  elements = [newCard childrenWithTag: @"adr"
                         andAttribute: @"type"
                          havingValue: @"home"];
  if ([elements count] > 0)
    element = [elements objectAtIndex: 0];
  else
    {
      element = [CardElement elementWithTag: @"adr"];
      [element addAttribute: @"type" value: @"home"];
      [newCard addChild: element];
    }
  if (postalAddressId == 1)
    [element addAttribute: @"type" value: @"pref"];

  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_ADDRESS_POST_OFFICE_BOX_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 0 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey( PR_HOME_ADDRESS_STREET_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 2 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_ADDRESS_CITY_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 3 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_ADDRESS_STATE_OR_PROVINCE_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 4 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_ADDRESS_POSTAL_CODE_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 5 forKey: @""];
  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_ADDRESS_COUNTRY_UNICODE)];
  if (value)
    [element setSingleValue: value atIndex: 6 forKey: @""];


  //
  // telephone numbers: work, home, fax, pager and mobile
  //
  element = [self _elementWithTag: @"tel"  ofType: @"work"  forCard: newCard];
  value = [properties objectForKey: MAPIPropertyKey(PR_OFFICE_TELEPHONE_NUMBER_UNICODE)];
  if (value)
    [element setSingleValue: value forKey: @""];

  element = [self _elementWithTag: @"tel"  ofType: @"home"  forCard: newCard];
  value = [properties objectForKey: MAPIPropertyKey(PR_HOME_TELEPHONE_NUMBER_UNICODE)];
  if (value)
    [element setSingleValue: value forKey: @""];

  element = [self _elementWithTag: @"tel"  ofType: @"fax"  forCard: newCard];
  value = [properties objectForKey: MAPIPropertyKey(PR_BUSINESS_FAX_NUMBER_UNICODE)];
  if (value)
    [element setSingleValue: value forKey: @""];

  element = [self _elementWithTag: @"tel"  ofType: @"pager"  forCard: newCard];
  value = [properties objectForKey: MAPIPropertyKey(PR_PAGER_TELEPHONE_NUMBER_UNICODE)];
  if (value)
    [element setSingleValue: value forKey: @""];

  element = [self _elementWithTag: @"tel"  ofType: @"cell"  forCard: newCard];
  value = [properties objectForKey: MAPIPropertyKey(PR_MOBILE_TELEPHONE_NUMBER_UNICODE)];
  if (value)
    [element setSingleValue: value forKey: @""];


  //
  // job title, profession, nickname, company name, deparment, work url, im address/screen name and birthday
  //
  value = [properties objectForKey: MAPIPropertyKey(PR_TITLE_UNICODE)];
  if (value)
    [newCard setTitle: value];

  value = [properties objectForKey: MAPIPropertyKey(PR_PROFESSION_UNICODE)];
  if (value)
    {
      [newCard setRole: value];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_NICKNAME_UNICODE)];
  if (value)
    [newCard setNickname: value];

  value = [properties objectForKey: MAPIPropertyKey(PR_DEPARTMENT_NAME_UNICODE)];
  if (value)
    units = [NSArray arrayWithObject: value];
  else
    units = nil;

  value = [properties objectForKey: MAPIPropertyKey(PR_COMPANY_NAME_UNICODE)];
  if (value)
    [newCard setOrg: value  units: units];

  value = [properties objectForKey: MAPIPropertyKey(PR_BUSINESS_HOME_PAGE_UNICODE)];
  if (value)
    {
      [[self _elementWithTag: @"url"  ofType: @"work"  forCard: newCard]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PidLidInstantMessagingAddress)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-aim"]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_BIRTHDAY)];
  if (value)
    {
      [newCard setBday: [value descriptionWithCalendarFormat: @"%Y-%m-%d"]];
    }

  //
  // wedding anniversary, spouse's name, manager's name, assistant's name, office location, freebusy location
  //
  value = [properties objectForKey: MAPIPropertyKey(PidTagWeddingAnniversary)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-ms-anniversary"]
        setSingleValue: [value descriptionWithCalendarFormat: @"%Y-%m-%d"]
                forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_SPOUSE_NAME_UNICODE)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-ms-spouse"]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_MANAGER_NAME_UNICODE)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-ms-manager"]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_ASSISTANT_UNICODE)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-ms-assistant"]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PR_OFFICE_LOCATION_UNICODE)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"x-ms-office"]
        setSingleValue: value forKey: @""];
    }

  value = [properties objectForKey: MAPIPropertyKey(PidLidFreeBusyLocation)];
  if (value)
    {
      [[newCard uniqueChildWithTag: @"fburl"]
        setSingleValue: value forKey: @""];
    }

  /* photo */
  if ([attachmentParts count] > 0)
    {
      attachment = [[attachmentParts allValues] objectAtIndex: 0];
      [self _updatePhotoInVCard: newCard
                 fromProperties: [attachment properties]];
    }

  /* Note */
  value = [properties objectForKey: MAPIPropertyKey (PR_BODY_UNICODE)];
  if (!value)
    {
      value = [properties objectForKey: MAPIPropertyKey (PR_HTML)];
      if (value)
        {
          value = [[NSString alloc] initWithData: value
                                        encoding: NSUTF8StringEncoding];
          [value autorelease];
          value = [value htmlToText];
        }
    }
  if (value)
    [newCard setNote: value];

  //
  // we save the new/modified card
  //
  [sogoObject saveComponent: newCard];

  [self updateVersions];
}

- (void) save:(TALLOC_CTX *) memCtx
{
  NSString *messageClass = [properties objectForKey: MAPIPropertyKey(PR_MESSAGE_CLASS_UNICODE)];
  if ([messageClass isEqualToString: @"IPM.DistList"])
    [self saveDistList: memCtx];
  else
    [self saveContact: memCtx];
}

@end
