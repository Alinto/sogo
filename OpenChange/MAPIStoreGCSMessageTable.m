/* MAPIStoreGCSMessageTable.m - this file is part of SOGo
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
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLContentStore/GCSFolder.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreTypes.h"
#import "MAPIStoreGCSFolder.h"

#import "MAPIStoreGCSMessageTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreGCSMessageTable

- (void) cleanupCaches
{
  [(MAPIStoreGCSFolder *) container synchroniseCache];
  [super cleanupCaches];
}

- (struct mapi_SPropertyRestriction *) _fixedDatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
                                                            inMemCtx: (TALLOC_CTX *) memCtx
{
  struct mapi_SPropertyRestriction *translatedRes;
  NSCalendarDate *dateValue;
  int32_t longDate;

  translatedRes = talloc (memCtx, struct mapi_SPropertyRestriction);
  translatedRes->ulPropTag = (res->ulPropTag & 0xffff0000) | PT_LONG;
  translatedRes->relop = res->relop;
  dateValue = NSObjectFromMAPISPropValue (&res->lpProp);
  longDate = (int32_t) [dateValue timeIntervalSince1970];
  translatedRes->lpProp.ulPropTag = translatedRes->ulPropTag;
  translatedRes->lpProp.value.l = longDate;

  return translatedRes;
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  static SEL operators[] = { EOQualifierOperatorLessThan,
			     EOQualifierOperatorLessThanOrEqualTo,
			     EOQualifierOperatorGreaterThan,
			     EOQualifierOperatorGreaterThanOrEqualTo,
			     EOQualifierOperatorEqual,
			     EOQualifierOperatorNotEqual,
			     EOQualifierOperatorContains };
  SEL operator;
  id value;
  NSString *property;
  NSNumber *lastModified;
  MAPIRestrictionState rc;
  TALLOC_CTX *memCtx = NULL;

  if (res->ulPropTag == PidTagChangeNumber)
    {
      value = NSObjectFromMAPISPropValue (&res->lpProp);
      lastModified = [(MAPIStoreGCSFolder *)
                       container lastModifiedFromMessageChangeNumber: value];
      [self logWithFormat: @"change number from oxcfxics: %.16lx", [value unsignedLongLongValue]];
      [self logWithFormat: @"  c_lastmodified: %@", lastModified];
      if (lastModified)
        {
          *qualifier = [[EOKeyValueQualifier alloc] initWithKey: @"c_lastmodified"
                                               operatorSelector: EOQualifierOperatorGreaterThanOrEqualTo
                                                          value: lastModified];
          [*qualifier autorelease];
          rc = MAPIRestrictionStateNeedsEval;
        }
      else
        rc = MAPIRestrictionStateAlwaysTrue;
    }
  else
    {
      property = [self backendIdentifierForProperty: res->ulPropTag];
      if (property)
        {
          if (res->relop < 7)
            operator = operators[res->relop];
          else
            {
              operator = NULL;
              [NSException raise: @"MAPIStoreRestrictionException"
                          format: @"unhandled operator type number %d", res->relop];
            }

          if ((res->ulPropTag & 0xffff) == PT_SYSTIME)
            {
              memCtx = talloc_zero (NULL, TALLOC_CTX);
              res = [self _fixedDatePropertyRestriction: res
                                               inMemCtx: memCtx];
            }

          value = NSObjectFromMAPISPropValue (&res->lpProp);
          if ((res->ulPropTag & 0xffff) == PT_UNICODE)
            {
              property = [NSString stringWithFormat: @"UPPER(%@)", property];
              value = [value uppercaseString];
            }

          *qualifier = [[EOKeyValueQualifier alloc] initWithKey: property
                                               operatorSelector: operator
                                                          value: value];
          [*qualifier autorelease];
          if (memCtx)
            talloc_free (memCtx);

          rc = MAPIRestrictionStateNeedsEval;
        }
      else
        {
          [self warnUnhandledProperty: res->ulPropTag
                           inFunction: __FUNCTION__];
          rc = MAPIRestrictionStateAlwaysFalse;
        }
    }

  return rc;
}

/* sorting */

- (EOSortOrdering *) _sortOrderingFromSortOrder: (struct SSortOrder *) sortOrder
{
  EOSortOrdering *newSortOrdering = nil;
  NSString *sortIdentifier;
  SEL orderSelector = NULL;
  const char *propName;

  sortIdentifier = [self sortIdentifierForProperty: sortOrder->ulPropTag];
  if (sortIdentifier)
    {
      if ((sortOrder->ulPropTag & 0xffff) == PT_UNICODE
          || (sortOrder->ulPropTag & 0xffff) == PT_STRING8)
        {
          if (sortOrder->ulOrder == TABLE_SORT_ASCEND)
            orderSelector = EOCompareCaseInsensitiveAscending;
          else if (sortOrder->ulOrder == TABLE_SORT_DESCEND)
            orderSelector = EOCompareCaseInsensitiveDescending;
          else if (sortOrder->ulOrder == TABLE_SORT_MAXIMUM_CATEGORY)
            {
              orderSelector = EOCompareCaseInsensitiveAscending;
              [self errorWithFormat:
                      @"TABLE_SORT_MAXIMUM_CATEGORY is not handled"];
            }
        }
      else
        {
          if (sortOrder->ulOrder == TABLE_SORT_ASCEND)
            orderSelector = EOCompareAscending;
          else if (sortOrder->ulOrder == TABLE_SORT_DESCEND)
            orderSelector = EOCompareDescending;
          else if (sortOrder->ulOrder == TABLE_SORT_MAXIMUM_CATEGORY)
            {
              orderSelector = EOCompareAscending;
              [self errorWithFormat:
                      @"TABLE_SORT_MAXIMUM_CATEGORY is not handled"];
            }
        }
      if (orderSelector)
        newSortOrdering = [EOSortOrdering sortOrderingWithKey: sortIdentifier
                                                     selector: orderSelector];
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

  return newSortOrdering;
}

- (void) setSortOrder: (const struct SSortOrderSet *) set
{
  NSMutableArray *newSortOrderings;
  EOSortOrdering *sortOrdering;
  uint16_t count;

  if (set)
    {
      newSortOrderings = [NSMutableArray arrayWithCapacity: set->cSorts];

      /* TODO: */
      if (set->cCategories > 0)
        [self errorWithFormat: @"we don't handle sort categories yet"];

      for (count = 0; count < set->cSorts; count++)
        {
          sortOrdering = [self _sortOrderingFromSortOrder: set->aSort + count];
          if (sortOrdering)
            [newSortOrderings addObject: sortOrdering];
        }
    }
  else
    newSortOrderings = nil;

  ASSIGN (sortOrderings, newSortOrderings);
  [self cleanupCaches];

  [self logWithFormat: @"new sort orderings: %@", sortOrderings];
}

/* subclasses */
- (NSString *) sortIdentifierForProperty: (enum MAPITAGS) property
{
  [self subclassResponsibility: _cmd];

  return nil;
}

@end
