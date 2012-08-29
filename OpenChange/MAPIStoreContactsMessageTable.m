/* MAPIStoreContactsMessageTable.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc
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

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <EOControl/EOQualifier.h>
#import <NGMail/NGMailAddress.h>
#import <NGMail/NGMailAddressParser.h>
#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NGVCard.h>

#import <Contacts/SOGoContactGCSEntry.h>

#import "MAPIStoreContactsMessage.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSArray+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsMessageTable.h"

#include <mapistore/mapistore_nameid.h>

static Class MAPIStoreContactsMessageK, NGMailAddressK, NSDataK, NSStringK;

@implementation MAPIStoreContactsMessageTable

+ (void) initialize
{
  MAPIStoreContactsMessageK = [MAPIStoreContactsMessage class];
  NSDataK = [NSData class];
  NSStringK = [NSString class];
  NGMailAddressK = [NGMailAddress class];
}

+ (Class) childObjectClass
{
  return MAPIStoreContactsMessageK;
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
			  forKey: MAPIPropertyKey (PidLidFileUnder)];
      [knownProperties setObject: @"c_cn"
                          forKey: MAPIPropertyKey (PidTagDisplayName)];
      [knownProperties setObject: @"c_cn"
			  forKey: MAPIPropertyKey (PidTagSubject)]; 
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  EOAndQualifier *andQualifier;
  EOKeyValueQualifier *fullNameQualifier, *emailQualifier;
  NSString *fullName, *email;
  SEL operator;
  id value, ngAddress;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch ((uint32_t) res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Contact"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PR_SENSITIVITY:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PidLidAddressBookProviderArrayType:
    case PidLidAddressBookProviderEmailList:
      /* FIXME: this is a hack. We should return a real qualifier here */
      rc = MAPIRestrictionStateAlwaysTrue;
      break;

    case PidLidEmail1OriginalDisplayName:
    case PidLidEmail2OriginalDisplayName:
    case PidLidEmail3OriginalDisplayName:
      rc = MAPIRestrictionStateAlwaysFalse;
      value = NSObjectFromMAPISPropValue (&res->lpProp);
      if (value && [value isKindOfClass: NSStringK])
        {
          rc = MAPIRestrictionStateNeedsEval;
          ngAddress = [[NGMailAddressParser mailAddressParserWithString: value]
                      parse];
          if ([ngAddress isKindOfClass: NGMailAddressK])
            {
              operator = [self operatorFromRestrictionOperator: res->relop];
              fullName = [ngAddress displayName];
              email = [ngAddress address];
              emailQualifier = [[EOKeyValueQualifier alloc]
                                       initWithKey: @"c_mail"
                                  operatorSelector: operator
                                             value: email];
              if ([fullName length] > 0)
                {
                  fullNameQualifier = [[EOKeyValueQualifier alloc]
                                              initWithKey: @"c_cn"
                                         operatorSelector: operator
                                                    value: fullName];
                  andQualifier = [[EOAndQualifier alloc]
                                              initWithQualifiers:
                                     emailQualifier, fullNameQualifier, nil];
                  [fullNameQualifier release];
                  [emailQualifier release];
                  *qualifier = andQualifier;
                }
              else
                *qualifier = emailQualifier;
              [*qualifier autorelease];
            }
        }
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

- (MAPIRestrictionState) evaluateContentRestriction: (struct mapi_SContentRestriction *) res
				      intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  if ([value isKindOfClass: NSDataK])
    {
      value = [[NSString alloc] initWithData: value
				    encoding: NSUTF8StringEncoding];
      [value autorelease];
    }
  else if (![value isKindOfClass: NSStringK])
    [NSException raise: @"MAPIStoreTypeConversionException"
		format: @"unhandled content restriction for class '%@'",
		 NSStringFromClass ([value class])];

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE: /* FIXME: should make use of c_component here */
      if ([value isEqualToString: @"IPM.Contact"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateContentRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

/* sorting */

- (NSString *) sortIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"c_cn"
                          forKey: MAPIPropertyKey (PidLidFileUnder)];
      [knownProperties setObject: @"c_cn"
                          forKey: MAPIPropertyKey (PidTagDisplayName)];
      [knownProperties setObject: @"c_cn"
			  forKey: MAPIPropertyKey (PidTagSubject)];
      [knownProperties setObject: @"c_cn"
			  forKey: MAPIPropertyKey (PidTagNormalizedSubject)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
