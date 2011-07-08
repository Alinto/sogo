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

#import "MAPIStoreContactsMessage.h"
#import "MAPIStoreTypes.h"
#import "NSDate+MAPIStore.h"
#import "NSArray+MAPIStore.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreContactsMessageTable.h"

#include <mapistore/mapistore_nameid.h>

static Class MAPIStoreContactsMessageK;

@implementation MAPIStoreContactsMessageTable

+ (void) initialize
{
  MAPIStoreContactsMessageK = [MAPIStoreContactsMessage class];
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
			  forKey: MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE)];
      [knownProperties setObject: @"c_cn"
			  forKey: MAPIPropertyKey (PidLidFileUnder)];
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
  switch ((uint32_t) res->ulPropTag)
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
                          forKey: MAPIPropertyKey (PR_DISPLAY_NAME_UNICODE)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

@end
