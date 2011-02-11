/* MAPIStoreGCSMessageTable.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSObject+Logs.h>

#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOQualifier.h>
#import <EOControl/EOSortOrdering.h>
#import <GDLContentStore/GCSFolder.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoGCSFolder.h>

#import "MAPIStoreTypes.h"

#import "MAPIStoreGCSMessageTable.h"

#undef DEBUG
#include <mapistore/mapistore.h>

@implementation MAPIStoreGCSMessageTable

- (id) init
{
  if ((self = [super init]))
    {
      sortOrderings = nil;
    }

  return self;
}

- (void) dealloc
{
  [sortOrderings release];
  [super dealloc];
}

- (NSArray *) _childKeysUsingRestrictions: (BOOL) useRestrictions
{
  static NSArray *fields = nil;
  NSArray *records;
  EOQualifier *componentQualifier, *fetchQualifier;
  GCSFolder *ocsFolder;
  EOFetchSpecification *fs;
  NSArray *keys;

  if (!fields)
    fields = [[NSArray alloc]
	       initWithObjects: @"c_name", @"c_version", nil];

  componentQualifier = [self componentQualifier];

  if (useRestrictions
      && restrictionState != MAPIRestrictionStateAlwaysTrue)
    {
      if (restrictionState == MAPIRestrictionStateNeedsEval)
	{
	  fetchQualifier = [[EOAndQualifier alloc]
			     initWithQualifiers:
			       componentQualifier,
			     restriction,
			     nil];
	  [fetchQualifier autorelease];
	}
      else
	fetchQualifier = nil;
    }
  else
    fetchQualifier = componentQualifier;
    
  if (fetchQualifier)
    {
      ocsFolder = [folder ocsFolder];
      fs = [EOFetchSpecification
             fetchSpecificationWithEntityName: [ocsFolder folderName]
                                    qualifier: fetchQualifier
                                sortOrderings: sortOrderings];
      records = [ocsFolder fetchFields: fields fetchSpecification: fs];
      keys = [records objectsForKey: @"c_name"
		     notFoundMarker: nil];
    }
  else
    keys = [NSArray array];

  return keys;
}

- (NSArray *) childKeys
{
  return [self _childKeysUsingRestrictions: NO];
}

- (NSArray *) restrictedChildKeys
{
  return [self _childKeysUsingRestrictions: YES];
}

- (MAPIRestrictionState) evaluateDatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
					   intoQualifier: (EOQualifier **) qualifier
{
  struct mapi_SPropertyRestriction translatedRes;
  NSCalendarDate *dateValue;
  int32_t longDate;

  translatedRes.ulPropTag = (res->ulPropTag & 0xffff0000) | PT_LONG;
  translatedRes.relop = res->relop;
  dateValue = NSObjectFromMAPISPropValue (&res->lpProp);
  longDate = (int32_t) [dateValue timeIntervalSince1970];
  translatedRes.lpProp.ulPropTag = translatedRes.ulPropTag;
  translatedRes.lpProp.value.l = longDate;

  return [super evaluatePropertyRestriction: &translatedRes
			      intoQualifier: qualifier];
}

- (MAPIRestrictionState) evaluatePropertyRestriction: (struct mapi_SPropertyRestriction *) res
				       intoQualifier: (EOQualifier **) qualifier
{
  MAPIRestrictionState rc;

  if ((res->ulPropTag & 0x0040) == 0x0040) /* is date ? */
    rc = [self evaluateDatePropertyRestriction: res
				 intoQualifier: qualifier];
  else
    rc = [super evaluatePropertyRestriction: res intoQualifier: qualifier];

  return rc;
}

- (EOQualifier *) componentQualifier
{
  [self subclassResponsibility: _cmd];

  return nil;
}

/* sorting */

- (NSString *) sortIdentifierForProperty: (enum MAPITAGS) property
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (EOSortOrdering *) _sortOrderingFromSortOrder: (struct SSortOrder *) sortOrder
{
  EOSortOrdering *newSortOrdering;
  NSString *sortIdentifier;
  SEL orderSelector;
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
      newSortOrdering = [EOSortOrdering sortOrderingWithKey: sortIdentifier
                                                   selector: orderSelector];
    }
  else
    {
      newSortOrdering = nil;
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

@end
