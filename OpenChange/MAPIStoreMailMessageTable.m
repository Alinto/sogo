/* MAPIStoreMailMessageTable.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSRange.h>
#import <NGExtensions/NSObject+Logs.h>
#import <EOControl/EOQualifier.h>
#import <SOGo/NSArray+Utilities.h>

#import <Mailer/NSData+Mail.h>
#import <Mailer/SOGoMailFolder.h>
#import <Mailer/SOGoMailObject.h>

#import "MAPIStoreContext.h"
#import "MAPIStoreMailFolder.h"
#import "MAPIStoreMailMessage.h"
#import "MAPIStoreTypes.h"
#import "NSData+MAPIStore.h"
#import "NSString+MAPIStore.h"

#import "MAPIStoreMailMessageTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_nameid.h>

@implementation MAPIStoreMailMessageTable

static Class MAPIStoreMailMessageK, NSDataK, NSStringK;

+ (void) initialize
{
  MAPIStoreMailMessageK = [MAPIStoreMailMessage class];
  NSDataK = [NSData class];
  NSStringK = [NSString class];
}

+ (Class) childObjectClass
{
  return MAPIStoreMailMessageK;
}

- (id) init
{
  if ((self = [super init]))
    {
      ASSIGN (sortOrderings, [NSArray arrayWithObject: @"ARRIVAL"]);
      fetchedCoreInfos = NO;
    }

  return self;
}

- (void) cleanupCaches
{
  [(MAPIStoreMailFolder *) container synchroniseCache];
  fetchedCoreInfos = NO;
  [super cleanupCaches];
}

- (NSString *) backendIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      [knownProperties setObject: @"DATE"
			  forKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
      [knownProperties setObject: @"DATE"
			  forKey: MAPIPropertyKey (PR_MESSAGE_DELIVERY_TIME)];
      [knownProperties setObject: @"MESSAGE-ID"
			  forKey: MAPIPropertyKey (PR_INTERNET_MESSAGE_ID_UNICODE)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

/* restrictions */

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;
  id value;
  NSNumber *modseq;

  value = NSObjectFromMAPISPropValue (&res->lpProp);
  switch ((uint32_t) res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidLidAppointmentStartWhole:
    case PidLidAppointmentEndWhole:
    case PidLidRecurring:
      [self logWithFormat: @"apt restriction on mail folder?"];
      rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidLidAutoProcessState:
      if ([value intValue] == 0)
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PR_SEARCH_KEY:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case 0x0fff00fb: /* PR_ENTRY_ID in PtyServerId form */
    case 0x0ff600fb:
      /*                                 resProperty: struct mapi_SPropertyRestriction
                                    relop                    : 0x04 (4)
                                    ulPropTag                : UNKNOWN_ENUM_VALUE (0xFF600FB)
                                    lpProp: struct mapi_SPropValue
                                        ulPropTag                : UNKNOWN_ENUM_VALUE (0xFF600FB)
                                        value                    : union mapi_SPropValue_CTR(case 251)
                                        bin                      : SBinary_short cb=21
[0000] 01 01 00 1A 00 00 00 00   00 9C 83 E8 0F 00 00 00   ........ ........
[0010] 00 00 00 00 00                                    ..... */
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidTagConversationKey:
	rc = MAPIRestrictionStateAlwaysFalse;
      break;

    case PidTagChangeNumber:
      {
        modseq = [(MAPIStoreMailFolder *)
                   container modseqFromMessageChangeNumber: value];
        [self logWithFormat: @"change number from oxcfxics: %.16lx", [value unsignedLongLongValue]];
        [self logWithFormat: @"  modseq: %.16lx", [modseq unsignedLongLongValue]];
        if (modseq)
          modseq = [NSNumber numberWithUnsignedLongLong:
                               [modseq unsignedLongLongValue] + 1];
        else
          modseq = [NSNumber numberWithUnsignedLongLong: 0];
        *qualifier = [[EOKeyValueQualifier alloc] initWithKey: @"MODSEQ"
                                                  operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                                  value: modseq];
        [*qualifier autorelease];
        rc = MAPIRestrictionStateNeedsEval;
      }
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
    case PR_MESSAGE_CLASS_UNICODE:
      if ([value isEqualToString: @"IPM.Note"])
	rc = MAPIRestrictionStateAlwaysTrue;
      else
	rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PidTagConversationKey:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateContentRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

- (MAPIRestrictionState) evaluateExistRestriction: (struct mapi_SExistRestriction *) res
				    intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  switch (res->ulPropTag)
    {
    case PR_MESSAGE_CLASS_UNICODE:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    case PR_MESSAGE_DELIVERY_TIME:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PR_CLIENT_SUBMIT_TIME:
      rc = MAPIRestrictionStateAlwaysTrue;
      break;
    case PR_PROCESSED:
      rc = MAPIRestrictionStateAlwaysFalse;
      break;
    default:
      rc = [super evaluateExistRestriction: res intoQualifier: qualifier];
    }

  return rc;
}

/* sorting */

- (NSString *) _sortIdentifierForProperty: (enum MAPITAGS) property
{
  static NSMutableDictionary *knownProperties = nil;

  if (!knownProperties)
    {
      knownProperties = [NSMutableDictionary new];
      /* ARRIVAL, CC */
      [knownProperties setObject: @"DATE"
                          forKey: MAPIPropertyKey (PR_CLIENT_SUBMIT_TIME)];
      [knownProperties setObject: @"DATE"
			  forKey: MAPIPropertyKey (PR_MESSAGE_DELIVERY_TIME)];
      [knownProperties setObject: @"FROM"
                          forKey: MAPIPropertyKey (PR_SENT_REPRESENTING_NAME_UNICODE)];
      [knownProperties setObject: @"SIZE"
                          forKey: MAPIPropertyKey (PR_MESSAGE_SIZE)];
      [knownProperties setObject: @"SIZE"
                          forKey: MAPIPropertyKey (PidLidRemoteTransferSize)];
      [knownProperties setObject: @"SUBJECT"
                          forKey: MAPIPropertyKey (PR_NORMALIZED_SUBJECT_UNICODE)];
      [knownProperties setObject: @"TO"
                          forKey: MAPIPropertyKey (PR_DISPLAY_TO_UNICODE)];
    }

  return [knownProperties objectForKey: MAPIPropertyKey (property)];
}

- (void) setSortOrder: (const struct SSortOrderSet *) set
{
  NSMutableArray *newSortOrderings;
  NSMutableString *newSortOrdering;
  struct SSortOrder *sortOrder;
  NSString *sortIdentifier;
  const char *propName;
  uint16_t count;

  if (set)
    {
      /* TODO: */
      if (set->cCategories > 0)
        [self errorWithFormat: @"we don't handle sort categories yet"];

      newSortOrderings = [NSMutableArray array];

      for (count = 0; count < set->cSorts; count++)
        {
          sortOrder = set->aSort + count;
          sortIdentifier
            = [self _sortIdentifierForProperty: sortOrder->ulPropTag];
          if (sortIdentifier)
            {
              newSortOrdering = [NSMutableString string];
              if (sortOrder->ulOrder == TABLE_SORT_DESCEND)
                [newSortOrdering appendString: @" REVERSE"];
              else if (sortOrder->ulOrder == TABLE_SORT_MAXIMUM_CATEGORY)
                [self errorWithFormat: @"TABLE_SORT_MAXIMUM_CATEGORY is not handled"];
              [newSortOrdering appendFormat: @" %@", sortIdentifier];
              [newSortOrderings addObject: [newSortOrdering substringFromIndex: 1]];
            }
          else
            {
              propName = get_proptag_name (sortOrder->ulPropTag);
              if (!propName)
                propName = "<unknown>";
              [self errorWithFormat:
                      @"sort unhandled for property: %s (0x%.8x)",
                    propName, sortOrder->ulPropTag];
            }
        }
      if ([newSortOrderings count] > 0)
        ASSIGN (sortOrderings, newSortOrderings);
      else
        ASSIGN (sortOrderings, [NSArray arrayWithObject: @"ARRIVAL"]);
      [self logWithFormat: @"new sort orderings: '%@'", sortOrderings];
    }
  else
    ASSIGN (sortOrderings, [NSArray arrayWithObject: @"ARRIVAL"]);

  [self cleanupCaches];
}

- (int) getRow: (struct mapistore_property_data **) dataP
     withRowID: (uint32_t) rowId
  andQueryType: (enum mapistore_query_type) queryType
      inMemCtx: (TALLOC_CTX *) memCtx
{
  if (!fetchedCoreInfos)
    {
      fetchedCoreInfos = YES;
      [(SOGoMailFolder *) [(MAPIStoreMailFolder *) container sogoObject]
         prefetchCoreInfosForMessageKeys: [self restrictedChildKeys]];
    }

 return [super   getRow: dataP withRowID: rowId
           andQueryType: queryType inMemCtx: memCtx];
}

@end
